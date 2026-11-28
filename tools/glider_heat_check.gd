extends "res://tools/abyss_check.gd"
## --glider-heat-check (item 63): the glide input opens the glider at ANY heat (full, nearly spent, overheated, right
## after an overheated one closed), an overheated glider lifts out of the abyss like a cool one, the climb
## from deep down stays under the softened cap, a level glide sinks at HunterMove.glide_sink and
## overheats HunterMove.glide_heat_s after it opens, each hit kind spikes a gliding dummy or not
## (decision 0022), and the other heat rows in hunter_move.json (heat_doc) do what they say: a real glide
## press 8 m deep spends the footage's quarter to a third of the bar, an overheated glider flies
## at overheat_speed (only slower sideways: its height and heading match a cool glide held on the same keys)
## and burns overheat_burn of your health a second in 20-damage ticks. Your own glider (not another
## player's) ticks once as the bar drops under GliderSfx.TICK_FROM, whatever the tank's length, and crackles
## on a loop while the tank is empty until it folds.
## Prints "ACHECK ok|FAIL ..." and "ACHECK DONE, failures: N".

const MoveSpeedCheck := preload("res://tools/move_speed_check.gd")
const GLIDE_RUN_UP := 30.0     # m above the lane the overheat glide starts
const GLIDE_LANE_M := 30       # m of flat lane under it (5 s at cruise is 25 m)

## Fastest climb and time to the lip when the glider opens `dp` m under the lip with `fuel` heat left.
func _climb(e: Dictionary, dp: float, fuel: float) -> Array:
	var dir: Vector2 = e["dir"]
	var top: float = e["top"]
	_reset(Vector3(e["ex"] + dir.x * 4.0, top - dp, e["ez"] + dir.y * 4.0), Vector3(0, -4.0, 0))
	h.last_gy = top
	h.air_t = 1.0
	h.gliding = true
	h.glide_fuel = fuel
	var peak := -99.0
	var t_up := -1.0
	var t := 0.0
	while t < 5.0:
		h.inp["glide"] = true
		h.glide_fuel = fuel if fuel > 0.0 else 0.0
		m.step(Match.DT)
		t += Match.DT
		if h.pos.distance_to(marker) < 0.01: break
		peak = maxf(peak, h.vel.y)
		if t_up < 0.0 and h.pos.y >= top - 0.5:
			t_up = t
			break
	h.inp["glide"] = false
	return [peak, t_up]

## A level glide 6 m over the rim (under glide_height, above the lip: no lift): [its sink in m/s after 2 s,
## s from the open to overheat]. The height is pinned so it never lands before the heat runs out.
func _level_glide(e: Dictionary) -> Array:
	var y: float = float(e["top"]) + 6.0
	_reset(Vector3(e["at"].x, y, e["at"].z), Vector3(0, -HunterMove.glide_sink, 0))
	h.last_gy = e["top"]
	h.air_t = 1.0
	h.gliding = true
	var sink := 0.0
	var t := 0.0
	while t < 30.0 and h.glide_fuel > 0.001:
		h.inp["glide"] = true
		m.step(Match.DT)
		t += Match.DT
		if absf(t - 2.0) < Match.DT * 0.5: sink = -h.vel.y
		h.pos.y = y
	h.inp["glide"] = false
	return [sink, t]

## 5 s of glide held on one direction from `fuel` heat: [horizontal speeds, vertical speeds, heading errors in degrees].
func _glide_run(lane: Vector3, fuel: float, dir: Vector2) -> Array:
	_reset(lane + Vector3(0, GLIDE_RUN_UP, 0), Vector3(0, -HunterMove.glide_sink, 0))
	h.last_gy = lane.y
	h.air_t = 1.0
	h.gliding = true
	var speeds := []
	var vys := []
	var errs := []
	for i in int(5.0 / Match.DT):
		h.inp["glide"] = true
		h.inp["move"] = dir
		h.glide_fuel = fuel
		m.step(Match.DT)
		speeds.append(Vector2(h.vel.x, h.vel.z).length())
		vys.append(h.vel.y)
		errs.append(rad_to_deg(Vector2(h.vel.x, h.vel.z).angle_to(dir)))
	h.inp["glide"] = false
	h.inp["move"] = Vector2.ZERO
	return [speeds, vys, errs]

## Overheated vs cool, same keys, 5 s over one flat lane (both fly the same ground): sideways speed x
## overheat_speed, the vertical speed curve unchanged.
func _overheat_glide(e: Dictionary) -> void:
	var lane := MoveSpeedCheck.flat_lane(w, e["at"], GLIDE_LANE_M)
	var dir := Vector2(1.0, 0.25).normalized()
	var cool: Array = _glide_run(lane, 1.0, dir)
	var hot: Array = _glide_run(lane, 0.0, dir)
	var ratio: float = float(hot[0][-1]) / float(cool[0][-1])
	var want := HunterMove.overheat_speed
	ok(absf(ratio - want) <= 0.03, "overheated glide speed is %.2f of cool after 5 s (want %.2f)" % [ratio, want])
	var worst := 0.0
	var heading := 0.0
	for i in cool[1].size():
		worst = maxf(worst, absf(float(hot[1][i]) - float(cool[1][i])))
		heading = maxf(heading, absf(float(hot[2][i])))
	var vy_max := 0.0
	for vy in cool[1]:
		vy_max = maxf(vy_max, absf(float(vy)))
	ok(worst <= vy_max * 0.02, "vertical speed matches a cool glide (worst gap %.3f m/s of %.2f)" % [worst, vy_max])
	ok(heading < 1.0, "overheated heading follows the keys (worst off by %.2f degrees)" % heading)

## Presses glide (a fresh press) in the air at the given heat/cooldown; true if the glider opens within 0.4s.
func _opens(e: Dictionary, fuel: float, cd: float, btn: bool) -> bool:
	var top: float = e["top"]
	_reset(Vector3(e["at"].x, top + 12.0, e["at"].z), Vector3(0, -2.0, 0))
	h.last_gy = top
	h.air_t = 1.0
	h.glide_fuel = fuel
	h.glide_cd = cd
	var t := 0.0
	while t < 0.4:
		h.inp["glide"] = true
		h.inp["glide_btn"] = btn
		m.step(Match.DT)
		t += Match.DT
		h.glide_fuel = minf(h.glide_fuel, fuel)
		if h.gliding: break
	var r := h.gliding
	h.inp["glide"] = false
	h.inp["glide_btn"] = false
	return r

func run(main: Node) -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	w = m.world
	h = m.hunters[0]
	h.set_arch("")
	for o in m.hunters:
		o.ctrl = "idle"
		if o != h: o.teleport(w.random_ground())
	h.ctrl = "local"
	# no kins: their carry passives (damage_reduction, ...) would skew the heat and landing numbers
	for o in m.hunters:
		for kk in [o.kin, o.kin2]:
			if kk:
				m.kins.erase(kk)
				kk.queue_free()
		o.kin = null
		o.kin2 = null
	m.opts["god"] = true
	marker = w.random_ground()
	h.ai["land"] = marker
	var edges := _edges(6)
	ok(edges.size() > 0, "found test rims (%d)" % edges.size())
	var e: Dictionary = edges[0]
	for fuel in [1.0, 0.5, 0.05, 0.02, 0.0]:
		for btn in [false, true]:
			var pct := int((1.0 - fuel) * 100.0)
			var what := "glide %s at %d%% heat opens the glider" % ["button" if btn else "press", pct]
			ok(_opens(e, fuel, 0.0, btn), what)
	# let go while overheated and press again: it comes out again
	_reset(Vector3(e["at"].x, float(e["top"]) + 12.0, e["at"].z), Vector3(0, -2.0, 0))
	h.air_t = 1.0
	h.glide_fuel = 0.0
	var reopened := false
	for i in 90:
		h.inp["glide"] = (i < 20) or (i > 40)
		h.glide_fuel = 0.0
		m.step(Match.DT)
		if i == 35 and h.gliding: ok(false, "the glider folds when glide is let go")
		if i > 45 and h.gliding:
			reopened = true
			break
	h.inp["glide"] = false
	ok(reopened, "overheated: let go, press again within a second: it opens again")
	# half lift
	var full: Array = _climb(e, 12.0, 1.0)
	var hot: Array = _climb(e, 12.0, 0.0)
	print("ACHECK 12m deep: full heat peak %.1f up in %.2fs
	overheated peak %.1f up in %.2fs" % [full[0], full[1], hot[0], hot[1]])
	ok(float(hot[1]) > 0.0, "an overheated glider still lifts you back to the lip from 12m")
	var ratio: float = float(hot[0]) / maxf(0.01, float(full[0]))
	ok(absf(ratio - 1.0) < 0.02, "the overheated lift is the normal lift (%.2f of it)" % ratio)
	# the softened cap
	var deep_peak := 0.0
	for dp in [8.0, 10.0, 12.0]:
		deep_peak = maxf(deep_peak, float((_climb(e, dp, 1.0))[0]))
	print("ACHECK deepest climb speed from 8/10/12m: %.1f m/s (old cap 26)" % deep_peak)
	var cap_txt := "the climb from deep down stays under the new cap (%.1f m/s <= %.1f)" % [deep_peak, 26.0 * 0.7]
	ok(deep_peak <= 26.0 * 0.7 + 0.3, cap_txt)
	ok(deep_peak >= 12.0, "...and is still a real lift (%.1f m/s)" % deep_peak)
	var level: Array = _level_glide(e)
	var gear_k: float = 1.0 + h.gear_stat("heat")      # worn gear's heat stat (the save's armory boots) stretches it
	var heat_s: float = HunterMove.glide_heat_s * float(h.cdat.get("glide_cap", 1.0)) * gear_k
	var sink_txt := "a level glide sinks at %.2f m/s (hunter_move.json glide_sink %.2f)"
	ok(absf(float(level[0]) - HunterMove.glide_sink) < 0.02, sink_txt % [level[0], HunterMove.glide_sink])
	var heat_txt := "a level glide overheats %.2f s after it opens (glide_heat_s x glide_cap x gear heat %.2f)"
	ok(absf(float(level[1]) - heat_s) <= Match.DT * 2.0, heat_txt % [level[1], heat_s])
	_heat_rows(e, heat_s)
	_spike_kinds()
	_burn_hint(e)
	_overheat_glide(e)
	_warning_cues(e)
	m.queue_free()
	await _home(main)
	print("ACHECK DONE, failures: ", bad)
	main.get_tree().quit()

## lift_heat, overheat_speed and overheat_burn, from what the glider does. `heat_s`: this hunter's level glide time.
func _heat_rows(e: Dictionary, heat_s: float) -> void:
	# [footage] ~1 s of falling (8 m deep), a glide press, back at the lip ~1 s later for a quarter to a third
	# of the bar
	var lift: Array = _lift_cost(e, 8.0)
	var lift_txt := "a press 8 m deep is back at the lip in %.2f s for %.0f%% of the %.1f s bar (lift_heat %.1f)"
	ok(float(lift[0]) < 3.0 and float(lift[1]) > 0.22 and float(lift[1]) < 0.36,
		lift_txt % [lift[0], float(lift[1]) * 100.0, heat_s, HunterMove.lift_heat])
	# under the 8.5 m height hold, so no lift or swoop
	var cool := _glide_speed(e, 1.0)
	var hot := _glide_speed(e, 0.0)
	var speed_txt := "overheated glide speed %.2f is overheat_speed %.2f of %.2f"
	ok(absf(hot / maxf(0.01, cool) - HunterMove.overheat_speed) < 0.06,
		speed_txt % [hot, HunterMove.overheat_speed, cool])
	_glide_at(Vector3(e["at"].x, float(e["top"]) + 30.0, e["at"].z), 0.0)
	h.heat_burn = 0.0
	for i in int(4.0 / Match.DT):
		h.inp["glide"] = true
		h.glide_fuel = 0.0
		m.step(Match.DT)
	h.inp["glide"] = false
	var burnt := h.max_hp - h.hp
	var burn_want := floorf(HunterMove.overheat_burn * h.max_hp * 4.0 / 20.0) * 20.0
	var burn_txt := "4 s overheated burns %.0f of %.0f health (want %.0f)" % [burnt, h.max_hp, burn_want]
	ok(is_equal_approx(burnt, burn_want), burn_txt)

## [s to the lip, heat spent] when glide is pressed (a real press) `dp` m under the lip, falling.
func _lift_cost(e: Dictionary, dp: float) -> Array:
	var dir: Vector2 = e["dir"]
	var top: float = e["top"]
	_reset(Vector3(e["ex"] + dir.x * 4.0, top - dp, e["ez"] + dir.y * 4.0), Vector3(0, -10.0, 0))
	h.last_gy = top
	h.air_t = 1.0
	var t := 0.0
	while t < 4.0 and h.pos.y < top - 0.5:
		h.inp["glide"] = true
		h.inp["glide_btn"] = true
		m.step(Match.DT)
		t += Match.DT
	h.inp["glide"] = false
	h.inp["glide_btn"] = false
	return [t, 1.0 - h.glide_fuel]

## Opens the glider in the air at `fuel` heat, with no swoop speed left over.
func _glide_at(at: Vector3, fuel: float) -> void:
	_reset(at, Vector3.ZERO)
	h.air_t = 1.0
	h.gliding = true
	h.glide_fuel = fuel
	h.inp["glide"] = true
	h.glide_lift.swoop = 0.0

## Horizontal glide speed after 0.8 s of steering inland at `fuel` heat, 7.5 m over the island.
func _glide_speed(e: Dictionary, fuel: float) -> float:
	_glide_at(Vector3(e["at"].x, float(e["top"]) + 7.5, e["at"].z), fuel)
	var dir: Vector2 = e["dir"]
	for i in int(0.8 / Match.DT):
		h.inp["move"] = -dir
		h.inp["glide"] = true
		if fuel <= 0.0:
			h.glide_fuel = 0.0
		m.step(Match.DT)
	h.inp["move"] = Vector2.ZERO
	h.inp["glide"] = false
	return Vector2(h.vel.x, h.vel.z).length()

## The first overheat over the abyss says one plain line once per save (Match._tip): the live glide key,
## no input block, one line in the lane; hot over solid ground, or a second time, says nothing.
func _burn_hint(e: Dictionary) -> void:
	var stub := GDScript.new()
	stub.source_code = "extends Node\nvar lines: Array = []\nfunc tip(t, _near = \"\"): lines.append(t)\n"
	stub.reload()
	var hud: Node = stub.new()
	m.hud = hud
	m.opts["autoplay"] = false
	Save.d["tutorial"].erase("overheat_lift")
	Save.d["tutorial"]["move"] = true      # (the first hint would show on its own)
	m._tip_t = 2.0
	var top: float = e["top"]
	_reset(Vector3(e["at"].x, top + 12.0, e["at"].z), Vector3.ZERO)
	h.gliding = true
	h.glide_fuel = 0.0
	m._tips()
	ok(hud.lines.is_empty(), "overheated over solid ground: no hint")
	_reset(Vector3(e["ex"] + e["dir"].x * 4.0, top - 6.0, e["ez"] + e["dir"].y * 4.0), Vector3.ZERO)
	h.gliding = true
	h.glide_fuel = 0.5
	m._tips()
	ok(hud.lines.is_empty(), "gliding cool over the abyss: no hint")
	h.glide_fuel = 0.0
	m._tips()
	var want := TipText.overheat_lift()
	ok(hud.lines == [want], "first overheat over the abyss: the one line, live key cap (%s)" % str(hud.lines))
	ok(want.length() <= 70 and not want.contains("\n"), "the line is one short line (%d chars)" % want.length())
	ok(Save.d["tutorial"].get("overheat_lift", false), "...and it is marked seen in the save")
	h.glide_fuel = 1.0
	m._tips()
	h.glide_fuel = 0.0
	m._tips()
	ok(hud.lines.size() == 1, "a second overheat says nothing (%d lines)" % hud.lines.size())
	m.hud = null
	hud.free()

## A gliding dummy 12 m over the ground at this heat (1 = cool), the attacker gliding at 0.2 to see it cool.
func _glider(o: Hunter, fuel: float) -> void:
	o.teleport(marker + Vector3(0, 12.0, 0))
	o.grounded = false
	o.vel = Vector3(4.0, -1.0, 0)
	o.gliding = true
	o.inp["glide"] = true
	o.glide_fuel = fuel
	o.glide_cd = 0.0
	o.stun_t = 0.0
	o.shot_down = false
	o.kb_t = -9.0
	o.hp = o.max_hp
	o.inv_t = 0.0
	h.gliding = true
	h.glide_fuel = 0.2

## One hit of each kind on a gliding dummy (GlideSpike): heat and slam spike, CC alone does not.
func _spike_kinds() -> void:
	var o: Hunter = m.hunters[1]
	var kinds := {
		"a hit that fills the heat": [0.05, func(): o.hurt(30.0, h, {}), true],
		"any hit on an overheated glider": [0.0, func(): o.hurt(1.0, h, {}), true],
		"a slam (dunk) at full heat": [1.0, func(): m.displace.spike(o, -16.0, h), true],
		"a hit on a cool glider": [1.0, func(): o.hurt(30.0, h, {}), false],
		"a slam under slam_min": [1.0, func(): m.displace.spike(o, -0.5 * GlideSpike.slam_min, h), false],
		"a stun": [1.0, func(): o.hurt(1.0, h, {"stun": 1.0}), false],
		"a knock-up": [1.0, func(): o.impulse(Vector2.ZERO, 8.0), false],
		"a big knockback": [1.0, func(): o.impulse(Vector2(20.0, 0.0), 2.0), false],
		"a monster's hit on an overheated glider": [0.0, func(): o.hurt(5.0, null, {"src": "mob"}), false],
	}
	for what in kinds:
		var row: Array = kinds[what]
		_glider(o, float(row[0]))
		(row[1] as Callable).call()
		var want: bool = row[2]
		ok(o.shot_down == want, "%s %s a glider" % [what, "spikes" if want else "does not spike"])
		if want:
			ok(not o.gliding and o.glide_fuel <= 0.001, "...the glider folds overheated")
			ok(is_equal_approx(h.glide_fuel, 0.2 + GlideSpike.cool_by), "...and the spiker's glider cools")
	h.gliding = false
	# the fall after a slam and the landing stun
	_glider(o, 1.0)
	m.displace.spike(o, -16.0, h)
	ok(o.vel.y <= -16.0, "a slam drives the spiked glider down at its own speed (%.1f m/s)" % o.vel.y)
	var hp0 := o.hp
	var t := 0.0
	while not o.grounded and t < 4.0:
		o.inp["glide"] = true
		m.step(Match.DT)
		t += Match.DT
	ok(o.grounded and not o.gliding, "the spiked glider can't reopen on the way down (landed in %.2fs)" % t)
	ok(o.stun_t >= GlideSpike.land_stun - Match.DT * 1.5, "it lands stunned (%.2fs left)" % o.stun_t)
	ok(hp0 - o.hp >= GlideSpike.land_dmg - 0.01, "...and takes the landing damage (%.1f)" % (hp0 - o.hp))
	o.inp["glide"] = false


## One tick of the hunter's GliderSfx at `fuel` heat left; true if the warning tick played.
func _ticks(o: Hunter, fuel: float) -> bool:
	Sfx.last_played.erase("glider_tick")
	o.glide_fuel = fuel
	o.glider_snd.tick(o)
	return Sfx.last_played.has("glider_tick")

## The warning cues of an open glider (GliderSfx): one rising tick as the bar passes under 25%, a quiet ember
## loop while the tank is empty that ends when it folds; read from the bar's fraction (a longer tank, as ext/move-
## parity-glider-1127 makes, changes nothing); another player's glider makes neither.
func _warning_cues(e: Dictionary) -> void:
	var ember := "glider_ember%d" % h.get_instance_id()
	_reset(Vector3(e["at"].x, float(e["top"]) + 12.0, e["at"].z), Vector3.ZERO)
	Sfx.listener = h.pos      # (a cue out of earshot never plays)
	h.glider_snd = GliderSfx.new()
	h.gliding = true
	h.glide_fuel = 1.0
	h.glider_snd.tick(h)
	var tank := h.glide_max
	for k in [1.0, 3.0]:
		h.glider_snd.ticked = false
		h.glide_max = tank * k
		var at_edge := _ticks(h, GliderSfx.TICK_FROM + 0.01)
		var under := _ticks(h, GliderSfx.TICK_FROM - 0.01)
		var again := _ticks(h, GliderSfx.TICK_FROM - 0.05)
		var tick_txt := "tank x%.0f: no tick over 25%% (%s), one under it (%s), not again (%s)"
		ok(not at_edge and under and not again, tick_txt % [k, at_edge, under, again])
	h.glide_max = tank
	ok(not Sfx.loop_on(ember), "a tank with heat left has no ember crackle")
	_ticks(h, 0.0)
	ok(Sfx.loop_on(ember), "an empty tank crackles on a loop")
	h.gliding = false
	h.glider_snd.tick(h)
	ok(not Sfx.loop_on(ember), "...stopped as the glider folds on landing")
	h.gliding = true
	h.glider_snd.tick(h)
	h.glide_fuel = 1.0
	h.glider_snd.tick(h)
	ok(not Sfx.loop_on(ember), "...and when the glider cools")
	h.gliding = false
	h.glider_snd.tick(h)
	var mine := h.ctrl
	h.ctrl = "remote"
	h.remote = true
	h.gliding = true
	ok(not _ticks(h, 0.1), "another player's glider does not tick")
	h.glider_snd.net_hot = true
	h.glider_snd.tick(h)
	ok(not Sfx.loop_on(ember), "...nor crackle on a loop")
	h.glider_snd.net_hot = false
	h.remote = false
	h.ctrl = mine
	h.gliding = false
	h.glider_snd.tick(h)
