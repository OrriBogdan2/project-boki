extends "res://tools/abyss_check.gd"
## --glider-heat-check (item 63): the glide input opens the glider at ANY heat (full, nearly spent, overheated, right
## after an overheated one closed), an overheated glider lifts at half strength out of the abyss, and the climb from
## deep down stays under the softened cap. Then each heat number in content/rules/hunter_move.json
## (source parity, tags in its heat_doc) and what it does: glide time, lift cost, hit heat, burn, speed.
## Prints "ACHECK ok|FAIL ..." and "ACHECK DONE, failures: N".

## Fastest climb, time to the lip and the heat it cost when the glider opens `dp` m under the lip with `fuel`
## heat left (an overheated glider is held at 0).
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
		if fuel <= 0.0: h.glide_fuel = 0.0
		m.step(Match.DT)
		t += Match.DT
		if h.pos.distance_to(marker) < 0.01: break
		peak = maxf(peak, h.vel.y)
		if t_up < 0.0 and h.pos.y >= top - 0.5:
			t_up = t
			break
	h.inp["glide"] = false
	return [peak, t_up, fuel - h.glide_fuel]

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
	for kk in [h.kin, h.kin2]:
		if kk:
			m.kins.erase(kk)
			kk.queue_free()
	h.kin = null
	h.kin2 = null
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
	var half := "the overheated lift is about half the normal lift (%.2f of it)" % ratio
	ok(ratio > 0.4 and ratio < 0.62, half)
	# the softened cap
	var deep_peak := 0.0
	for dp in [8.0, 10.0, 12.0]:
		deep_peak = maxf(deep_peak, float((_climb(e, dp, 1.0))[0]))
	print("ACHECK deepest climb speed from 8/10/12m: %.1f m/s (old cap 26)" % deep_peak)
	var cap_txt := "the climb from deep down stays under the new cap (%.1f m/s <= %.1f)" % [deep_peak, 26.0 * 0.7]
	ok(deep_peak <= 26.0 * 0.7 + 0.3, cap_txt)
	ok(deep_peak >= 12.0, "...and is still a real lift (%.1f m/s)" % deep_peak)
	_heat_values(e)
	m.queue_free()
	await _home(main)
	print("ACHECK DONE, failures: ", bad)
	main.get_tree().quit()

## Each glider heat number and what it does. Source: briefs/supervive-data/supervive_physics.md (heat values
## locked), SUPERVIVE_FEEL.md footage, DECISIONS (overheated lift).
func _heat_values(e: Dictionary) -> void:
	var want := {"glide_heat_s": 14.0, "lift_heat": 4.0, "lift_tap_heat": 1.0, "hit_heat": 3.0,
		"overheat_burn": 0.035, "overheat_speed": 0.5, "overheat_lift": 0.5}
	for k in want:
		var v: float = HunterMove.get(k)
		ok(is_equal_approx(v, want[k]), "%s = %s (%s)" % [k, want[k], v])
	var cap := float(h.cdat.get("glide_cap", 1.0))
	ok(is_equal_approx(h.glide_max, 14.0 * cap), "glide_max is 14 s x glide_cap (%.2f)" % h.glide_max)
	# [F] ~14 s of level glide over the abyss before the ring turns hot
	var top: float = e["top"]
	var dir: Vector2 = e["dir"]
	_reset(Vector3(e["ex"] + dir.x * 4.0, top + 0.2, e["ez"] + dir.y * 4.0), Vector3.ZERO)
	h.air_t = 1.0
	h.gliding = true
	var t := 0.0
	while t < 30.0 and h.glide_fuel > 0.001 and h.gliding:
		h.inp["glide"] = true
		m.step(Match.DT)
		t += Match.DT
	h.inp["glide"] = false
	ok(absf(t - 14.0 * cap) < 0.5, "a level glide over the abyss overheats in ~14 s x glide_cap (%.2f s)" % t)
	# [F] a ~1 s lift from ~8 m deep burns a quarter to a third of the glider
	var lift: Array = _climb(e, 8.0, 1.0)
	var cost := float(lift[2]) / cap
	ok(float(lift[1]) > 0.0 and cost > 0.22 and cost < 0.36,
		"a lift from 8 m deep (%.2f s) costs a quarter to a third of the heat (%.0f%%)" % [lift[1], cost * 100.0])
	# hits heat it: hit_heat x the damage's share of a knock
	_glide_at(Vector3(e["at"].x, top + 12.0, e["at"].z), 1.0)
	h.hurt(5.0, null, {})
	var hit := 1.0 - h.glide_fuel
	var hit_want := 3.0 * 5.0 * 0.30 / 34.5 / cap
	ok(absf(hit - hit_want) < 0.005, "a 5-damage hit heats the glider %.3f (want %.3f)" % [hit, hit_want])
	# overheated: half the glide speed, and it burns ~3.5% of max health a second
	var cool := _glide_speed(e, 1.0)
	var hp0 := h.hp
	var hot := _glide_speed(e, 0.0)
	var burn := (hp0 - h.hp) / (h.max_hp * 2.0)
	ok(absf(hot / maxf(0.01, cool) - 0.5) < 0.06, "overheated glide speed %.2f is half of %.2f" % [hot, cool])
	ok(absf(burn - 0.035) < 20.0 / (h.max_hp * 2.0) + 0.002, "an overheated glider burns %.1f%%/s" % (burn * 100.0))

## Opens the glider high over the ground at `fuel` heat.
func _glide_at(at: Vector3, fuel: float) -> void:
	_reset(at, Vector3.ZERO)
	h.air_t = 1.0
	h.gliding = true
	h.glide_fuel = fuel
	h.inp["glide"] = true

## Horizontal glide speed after 2 s of steering one way at `fuel` heat, high over the island (health not reset).
func _glide_speed(e: Dictionary, fuel: float) -> float:
	var hp := h.hp
	_glide_at(Vector3(e["at"].x, float(e["top"]) + 20.0, e["at"].z), fuel)
	h.hp = hp
	var dir: Vector2 = e["dir"]
	for i in int(2.0 / Match.DT):
		h.inp["move"] = -dir
		h.inp["glide"] = true
		if fuel <= 0.0: h.glide_fuel = 0.0
		m.step(Match.DT)
	h.inp["move"] = Vector2.ZERO
	h.inp["glide"] = false
	return Vector2(h.vel.x, h.vel.z).length()
