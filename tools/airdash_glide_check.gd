extends RefCounted
## --airdash-glide-check: Shift into the glider is smooth, for every hunter (items 4 and 8, owner playtest 11-11
## "a weird hitch when i shift->glider"). Each hunter dashes in the air and presses glide (a second Space, as a
## player does) at three moments: mid-dash, the step after the dash's last step, and LATE steps after it (still
## inside DashGlide's grace). Per press:
##   - the glider opens on the press step (no wait for a kit's wind-down);
##   - per-frame continuity: from the dash's last step (or the step before the press) to STEADY_F steps after the
##     open, the horizontal speed
##     (measured from the body's own travel) never changes by more than STEP_DV m/s in one step (the old cut lost
##     10-17 in one);
##   - mid-dash and the step after, the glider opens with at least KEEP of the dash's exit speed.
## A hunter whose dash tuning gives no grace (Loco.dash_glide_grace 0: the source's wind-down) is only pressed
## mid-dash; one whose air Shift is not a dash (a hop, a skate, Joule's Wirerun streak) is skipped.

const KEEP := 0.7
const STEP_DV := 4.0
const STEP_DV_OWN := {"mage": 8.5}      # Sparkle: a press cancels her 40 m/s streak, which hands over at run speed (_cut_run, source patch 05.03.25)
const STEADY_F := 30
const LATE := 6
const HEIGHT := 40.0

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("AIRGLIDE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A fresh match as `arch`, high above a flat, empty patch of ground.
func _match(main: Node, arch: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch),
	})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var hunter: Hunter = m.player
	hunter.set_arch(arch)
	hunter.unlock_all()
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(60, 0, 60))
	for i in 20:
		m.step(Match.DT)
	return m

## One step with a player's keys: east held, glide pressed on `press` (a second Space) and held after.
func _step(m: Match, f: int, press: int) -> float:
	var hunter: Hunter = m.player
	hunter.inp["move"] = Vector2(1, 0)
	hunter.inp["aim"] = hunter.pos + Vector3(8, 0.9, 0)
	hunter.inp["jump"] = f == press
	hunter.inp["glide"] = f >= press
	hunter.inp["glide_btn"] = f >= press      # the raw key: a fresh press cancels Sparkle's Wirerun (_tick_glide_cancel)
	var p0 := hunter.pos
	m.step(Match.DT)
	return Vector2(hunter.pos.x - p0.x, hunter.pos.z - p0.z).length() / Match.DT

## Dashes east in the air; `when` = "none" (no press), "mid", "after" or "late" (timed on `base`, a "none" run).
## Returns {dash_0, dash_f (its first and last steps; -1: this hunter's air Shift is not a dash), exit (the speed on
## its last step before the glide), press, open (the step the glider opened, -1 never), open_v, worst}.
func _air_dash(m: Match, when: String, base := {}) -> Dictionary:
	var hunter: Hunter = m.player
	hunter.teleport(hunter.pos + Vector3(0, HEIGHT, 0))
	hunter.inp["glide_press_only"] = true
	for i in 12:
		_step(m, i, 9999)
	hunter.dashes = hunter.max_dashes()
	hunter.ex_cd = 0.0
	hunter.do_dash()
	var press := 9999
	if when == "mid":
		press = (int(base["dash_0"]) + int(base["dash_f"]) + 1) / 2
	elif when != "none":
		press = int(base["dash_f"]) + (1 if when == "after" else LATE)
	var r := {"dash_0": -1, "dash_f": -1, "exit": 0.0, "press": press, "open": -1, "open_v": 0.0, "worst": 0.0}
	var speeds: Array[float] = []
	for f in 150:
		var v := _step(m, f, press)
		speeds.append(v)
		if hunter.roll_t > 0.0 and hunter.loco.state == Loco.S.DASHING and not hunter.gliding:
			r["dash_0"] = f if int(r["dash_0"]) < 0 else int(r["dash_0"])
			r["dash_f"] = f
			r["exit"] = v
		if hunter.gliding and int(r["open"]) < 0:
			r["open"] = f
			r["open_v"] = v
		if (int(r["open"]) >= 0 and f >= int(r["open"]) + STEADY_F) or (when == "none" and f > 60):
			break
	if int(r["open"]) >= 0:
		for f in range(maxi(1, mini(press, int(base.get("dash_f", press)) + 1)), speeds.size()):
			r["worst"] = maxf(float(r["worst"]), absf(speeds[f] - speeds[f - 1]))
	return r

func run(main: Node) -> void:
	Save.no_write = true
	for arch in Arch.ORDER:
		var m := _match(main, arch)
		var base := _air_dash(m, "none")
		m.queue_free()
		await main.get_tree().process_frame
		if int(base["dash_f"]) < 0:
			print("AIRGLIDE (%s: the air Shift is not a dash, skipped)" % arch)
			continue
		print("AIRGLIDE base %s %s" % [arch, base])
		var whens := ["mid"]
		if Loco.dash_glide_grace(arch) >= (LATE + 0.5) * Match.DT:
			whens = ["mid", "after", "late"]
		for when in whens:
			m = _match(main, arch)
			var r := _air_dash(m, when, base)
			m.queue_free()
			await main.get_tree().process_frame
			var tag := "%s %s: press @%d opens @%d" % [arch, when, int(r["press"]), int(r["open"])]
			ok(int(r["open"]) >= 0 and int(r["open"]) <= int(r["press"]), tag + " (the press step)")
			ok(float(r["worst"]) <= float(STEP_DV_OWN.get(arch, STEP_DV)), "%s, worst step %.1f m/s" % [tag, float(r["worst"])])
			if when != "late":
				var exit_v := float(r["exit"])
				ok(float(r["open_v"]) >= exit_v * KEEP, "%s at %.1f m/s, dash exit %.1f m/s (%.0f%%)" % [tag,
						float(r["open_v"]), exit_v, 100.0 * float(r["open_v"]) / maxf(0.01, exit_v)])
	print("AIRGLIDE DONE, failures: %d" % bad)
	main.get_tree().quit()
