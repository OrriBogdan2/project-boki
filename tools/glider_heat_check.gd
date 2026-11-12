extends "res://tools/abyss_check.gd"
## --glider-heat-check (item 63): the glide input opens the glider at ANY heat (full, nearly spent, overheated, right
## after an overheated one closed), an overheated glider lifts at half strength out of the abyss, the climb
## from deep down stays under the softened cap, and each hit kind spikes a gliding dummy or not (decision
## 0022). Prints "ACHECK ok|FAIL ..." and "ACHECK DONE, failures: N".

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
	_spike_kinds()
	m.queue_free()
	await _home(main)
	print("ACHECK DONE, failures: ", bad)
	main.get_tree().quit()

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
