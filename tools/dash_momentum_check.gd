extends "res://tools/dash_flow_check.gd"
## --dash-momentum-check[=<id>,<id>] (docs/decisions/0061, a jump dash on Vex flew far): for every Hunter, the
## Shift dash covers the same distance on the ground, in the air (high up, so it never lands mid-dash), off a jump
## at its apex, within LIMIT of the ground dash's; with no charge left the long dash does the same on the ground,
## high up and off a jump. Once any of them ends the speed it hands over is never above the hunter's own run speed
## (HunterMove.dash_exit), checked for CARRY_S after; a jump out of a ground dash carries no more either. No keys
## are held, so the dash goes toward the cursor and nothing but the dash moves the hunter.
## Prints "DASHMOM ok|FAIL ..." and "DASHMOM DONE, failures: N".

const LIMIT := 0.1              # share of the ground dash's distance any other dash may differ by
## Heroes whose air Shift is a move of its own by design (its distance is the kit's data, not the ground dash's);
## its hand-over is still capped. hero -> why
const OWN_AIR := {
	"ashwick": "the air Shift is the Bellows Poof, a long launch (air_dist 6.8 m, the ram is 3.4 m)",
	"tender": "the air Shift is the Lunar Air Dash glide, airborne only (dash.air, the source's measured curve)",
	"dredge": "the air Shift is the pounce (air_k x the barge, its own slot: source Brute Dash (Air))",
	"rimewright": "Rink Run is a hold: its length is how long the key is held, not a set distance",
	"gil": "the air Shift is the class long dash (ex_dist 5.0 m): no ground to swim through (his swim dash is 6 m)",
}
const SPEED_SLACK := 0.05       # share over the run speed the hand-over may read (one step of air control)
const CARRY_S := 0.5            # s after the dash its speed is watched
const AIM := Vector3(40, 0, 0)  # the cursor, from the hunter: every dash goes +x
const MIN_DASH := 0.2           # m: a Shift that moves less than this was refused (no charge, no slot): n/a
## Trials: kind -> the ground trial its distance is held to ("" : none, a jump cuts the dash short)
const TRIALS := {"ground": "ground", "air": "ground", "jump": "ground", "ground_ex": "ground_ex",
		"air_ex": "ground_ex", "jump_ex": "ground_ex", "dash_jump": ""}

func ok(cond: bool, what: String) -> void:
	print("DASHMOM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node, _part := "") -> void:
	Save.no_write = true
	for hero in _heroes():
		var m := _match(main, hero)
		_hero_dashes(m, hero)
		m.queue_free()
		await main.get_tree().process_frame
	for hero in OWN_AIR:
		print("DASHMOM own air dash %s: %s" % [hero, OWN_AIR[hero]])
	print("DASHMOM DONE, failures: %d" % bad)
	main.get_tree().quit()

func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dash-momentum-check=") and arg.length() > 22:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

func _hero_dashes(m: Match, hero: String) -> void:
	var got := {}
	for kind in TRIALS:
		got[kind] = _dash(m, kind)
	if float(got["ground"]["dist"]) < MIN_DASH:
		print("DASHMOM skip %s: its Shift moved %.2fm" % [hero, got["ground"]["dist"]])
		return
	for kind in TRIALS:
		var r: Dictionary = got[kind]
		var d := float(r["dist"])
		var what := "%s %s dash: %.2fm, then at most %d%% over the run, %.2fm to landing" % [
				hero, kind, d, int(round(float(r["over"]) * 100.0)), r["landed"]]
		if d < MIN_DASH:
			print("DASHMOM n/a  %s (refused)" % what)
			continue
		ok(float(r["over"]) <= SPEED_SLACK, what + ": hands over at most the run speed")
		var base := String(TRIALS[kind])
		var own_air: bool = OWN_AIR.has(hero) and not kind.begins_with("ground")
		if base == "" or own_air or float(got[base]["dist"]) < MIN_DASH:
			continue
		var bd := float(got[base]["dist"])
		ok(absf(d - bd) <= bd * LIMIT, "%s: within %d%% of the %s dash's %.2fm" % [what, int(LIMIT * 100), base, bd])

## One Shift of `kind`: {"dist": m covered while the dash runs, "over": the most the speed ran over the run
## speed (a share of it) in the CARRY_S after,
## "landed": m from the press to where the hunter is back on the ground}.
func _dash(m: Match, kind: String) -> Dictionary:
	_fresh(m)
	if kind in ["air", "air_ex"]:
		_lift()
		_lift()           # 14 m up: the dash and CARRY_S after it never reach the ground
	if kind.ends_with("_ex"):
		hunter.dashes = 0.0
	if kind in ["jump", "jump_ex"]:
		hunter.inp["jump"] = true
		m.step(Match.DT)
		hunter.inp["jump"] = false
		var n := 0
		while hunter.vel.y > 0.0 and n < 120:
			m.step(Match.DT)
			n += 1
	var start := hunter.pos
	hunter.inp["aim"] = hunter.pos + AIM
	hunter.inp["dash"] = true
	m.step(Match.DT)
	hunter.inp["dash"] = false
	if kind == "dash_jump":
		_steps(m, 3)
		hunter.inp["jump"] = true
		m.step(Match.DT)
		hunter.inp["jump"] = false
	var n := 0
	while (hunter.roll_t > 0.0 or hunter.ak.dash_left() > 0.0) and n < 300:
		m.step(Match.DT)
		n += 1
	var dist := Vector2(hunter.pos.x - start.x, hunter.pos.z - start.z).length()
	var over := 0.0
	for i in int(CARRY_S / Match.DT):
		m.step(Match.DT)
		var run_v := maxf(0.1, hunter.run_speed)        # (a buff the dash gives raises it: it's still a run)
		over = maxf(over, Vector2(hunter.vel.x, hunter.vel.z).length() / run_v - 1.0)
	var n_fall := 0
	while not hunter.grounded and n_fall < 300:
		m.step(Match.DT)
		n_fall += 1
	var landed := Vector2(hunter.pos.x - start.x, hunter.pos.z - start.z).length()
	return {"dist": dist, "over": over, "landed": landed}
