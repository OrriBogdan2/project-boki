extends "res://tools/abyss_check.gd"
## --glide-hit-check: a Hunter under the glider is shot, knocked, stunned and reeled in (docs/MOVEMENT_FEEL.md
## "Hits on the glider", decision 0055). Shot with heat left: the glider stays open, normal damage, the heat
## rule's cost. A shot that empties the heat, or lands on an overheated glider, spikes: shut, plummeting, no
## reopening in the air, the 0.7 s stun on landing. A monster's hit never spikes. Knocked: the glider stays
## open and the shove carries it. Stunned, or reeled in by Grimble's arm (which stuns): shut for the stun, a
## press reopens it once the stun ends. Then the air-knock rows ("Knocked in the air"): Lace, Kael, Vex and Albert
## hit by Kael's LMB, Kael's RMB Smash, Albert's full Crushing Blow and a stun while gliding, in an air dash or
## falling. Prints "ACHECK ok|FAIL ..." and "ACHECK DONE, failures: N".

const SHOT := 10.0          # damage of the test shot
const KNOCK := 12.0         # m/s of the test shove (a hard knock is over 4)
const STUN := 0.5           # s of the test stun

const AIR_HEROES := ["archer", "juggernaut", "gunslinger", "bulwark"]
const AIR_HIT_AT := 0.05    # s into the state the hit lands; in an air dash, the first step its i-frames are over
const AIR_RUN := 1.3        # s each air-knock run lasts; the carry is the x gap to the same run with no hit
const AIR_HIGH := 40.0      # m over the ground: nobody lands inside a run
const KNOCK_GATE := 0.4     # s a shut glider waits out a shove over 4 m/s (Hunter._update_glide, [est])

var foe: Hunter
var spot := Vector3.ZERO    # 12 m over a rim tile's ground

func _steps(t: float) -> void:
	var n := int(round(t / Match.DT))
	for i in n:
		m.step(Match.DT)

## Gliding level over the spot with glide held, `fuel` heat left, no armor or shields in the way.
func _glide(fuel: float) -> void:
	_reset(spot, Vector3.ZERO)
	h.air_t = 1.0
	h.gliding = true
	h.inp["glide"] = true
	h.armor = 0.0
	h.shield = 0.0
	h.kin_shield = 0.0
	_steps(0.1)
	h.glide_fuel = fuel

## Lets go of glide for a step, then presses it (the glide button too) for up to `t` s: true if it opens.
func _press_opens(t: float) -> bool:
	h.inp["glide"] = false
	h.inp["glide_btn"] = false
	m.step(Match.DT)
	var left := t
	while left > 0.0 and not h.gliding:
		h.inp["glide"] = true
		h.inp["glide_btn"] = true
		m.step(Match.DT)
		left -= Match.DT
	h.inp["glide_btn"] = false
	return h.gliding

## Steps with glide let go until the stun is over (at most 2 s).
func _wait_stun() -> void:
	h.inp["glide"] = false
	var t := 0.0
	while h.stun_t > 0.0 and t < 2.0:
		m.step(Match.DT)
		t += Match.DT

func _shot() -> void:
	_glide(1.0)
	var hp0 := h.hp
	h.hurt(SHOT, foe)
	var cost := 1.0 - h.glide_fuel
	var rule := SHOT * Hunter.GLIDER_HIT_HEAT / float(h.cdat.get("glide_cap", 1.0))
	ok(absf(cost - rule) < 0.002, "a %.0f shot heats the glider %.3f (3x rule: %.3f)" % [SHOT, cost, rule])
	ok(absf(hp0 - h.hp - SHOT) < 0.5, "...and deals normal damage (%.1f of %.0f)" % [hp0 - h.hp, SHOT])
	_steps(0.5)
	ok(h.gliding and not h.shot_down, "a shot with heat left keeps the glider open (0.5 s on)")

func _spike() -> void:
	_glide(1.0)
	h.glide_fuel = 0.5 * SHOT * Hunter.GLIDER_HIT_HEAT
	h.hurt(SHOT, foe)
	ok(not h.gliding and h.shot_down and h.stun_t > 0.0, "a shot that fills the heat spikes: glider shut, stunned")
	ok(h.vel.y <= -6.0, "...plummeting (%.1f m/s)" % h.vel.y)
	ok(not _press_opens(0.5), "...and a press can't reopen it in the air")
	var t := 0.0
	var landed_stun := -1.0
	while t < 4.0 and landed_stun < 0.0:
		m.step(Match.DT)
		t += Match.DT
		if h.grounded: landed_stun = h.stun_t
	var want := GlideSpike.land_stun - Match.DT
	ok(landed_stun >= want, "...it lands stunned %.2f s (source: 0.7 s)" % landed_stun)
	_glide(0.0)
	h.hurt(SHOT, foe)
	ok(not h.gliding and h.shot_down, "a shot on an overheated glider spikes it")
	_glide(0.05)
	h.hurt(SHOT, null, {"src": "mob"})
	ok(h.gliding and not h.shot_down, "a monster's shot heats the glider but never spikes it")

func _knock() -> void:
	_glide(1.0)
	var x0 := h.pos.x
	h.impulse(Vector2(KNOCK * h.mass(), 0.0))
	ok(h.knock_t > 0.0 and m.time - h.kb_t < 0.01, "the test shove is a hard knock (%.0f m/s)" % KNOCK)
	var open := true
	for i in int(round(0.5 / Match.DT)):
		m.step(Match.DT)
		open = open and h.gliding
	ok(open, "a hard knock keeps the glider open the whole 0.5 s")
	var moved := h.pos.x - x0
	ok(moved > 0.5 * Hunter.GLIDE_SPEED + 1.0, "...and the shove carries it %.1f m in 0.5 s" % moved)
	# a shut glider still waits the knock out before it opens ([est], --abyss-check section 8 on edge knocks)
	_reset(spot, Vector3(0, -2.0, 0))
	h.air_t = 1.0
	h.impulse(Vector2(KNOCK * h.mass(), 0.0))
	ok(not _press_opens(0.3), "a shut glider doesn't open in the first 0.3 s of a hard knock")

func _stun() -> void:
	_glide(1.0)
	h.stun_t = STUN
	m.step(Match.DT)
	ok(not h.gliding, "a stun shuts the glider at once")
	_steps(0.2)
	ok(h.vel.y < -2.0 * Hunter.GLIDE_SINK, "...and the body falls (%.1f m/s)" % h.vel.y)
	ok(not _press_opens(0.1), "...a press during the stun doesn't open it")
	_wait_stun()
	ok(_press_opens(Match.DT), "...a press opens it the step the stun is over")
	# Grimble's arm: stunned for the whole reel, so the glider is shut until it lets go
	_glide(1.0)
	var to := spot + Vector3(6.0, 0.0, 0.0)
	var reel := {"mode": "haul", "spd": 12.0, "gap": 1.0, "dur": 0.6, "stun": 0.2, "swing": 8.0}
	reel["to"] = [to.x, to.y, to.z]
	m.displace.tow(h, null, reel)
	_steps(0.1)
	ok(not h.gliding and h.stun_t > 0.0, "Grimble's reel (it stuns) shuts the glider")
	var t := 0.0
	while not m.displace.towing(h).is_empty() and t < 1.0:
		m.step(Match.DT)
		t += Match.DT
	_wait_stun()
	ok(_press_opens(Match.DT), "...a press opens it once the reel and its stun are over")

## The air-knock hits, from the content: Kael's LMB, his RMB Smash push, Albert's full Crushing Blow, a stun.
func _air_hits() -> Dictionary:
	var kael: Dictionary = Arch.def("juggernaut")
	var blow: Dictionary = Arch.def("bulwark")["lmb"]
	return {
		"light (Kael LMB)": {"kb": float(kael["lmb"]["kb"])},
		"heavy (Kael RMB)": {"kb": float(kael["rmb"]["slam"]["push"])},
		"heavy (Crushing Blow)": {"kb": float(blow["smash_kb"][1]), "stun": float(blow["smash_stun"])},
		"stun": {"stun": STUN},
	}

## One run in `state` (glide, dash, fall) over the open spot, hit along +x by `hit` (none when empty). Glide is
## held while the glider is open; while it is shut, a fresh press every other step once the hit has landed.
func _air_run(state: String, hit: Dictionary, at: Vector3) -> Dictionary:
	_reset(at, Vector3(0, -2.0, 0))
	h.air_t = 1.0
	h.armor = 0.0
	h.shield = 0.0
	h.dashes = h.max_dashes()
	h.ex_cd = 0.0
	if state == "glide":
		h.gliding = true
	elif state == "dash":
		h.inp["aim"] = h.pos + Vector3(0, 0.9, 8)
		h.inp["move"] = Vector2(0, 1)
		h.do_dash()
		h.inp["move"] = Vector2.ZERO
	var r := {"fold": false, "open_at": -1.0, "rolling": false, "roll_after": 0.0, "vx_after": 0.0, "knocked": false}
	var was_open := h.gliding
	var x0 := h.pos.x
	var hit_t := -1.0
	var t := 0.0
	var i := 0
	while t < AIR_RUN - 0.001:
		if hit_t < 0.0 and t >= AIR_HIT_AT - 0.001 and (h.inv_t <= 0.0 or h.roll_t <= 0.0):
			hit_t = t
			r["rolling"] = h.roll_t > 0.0
			if not hit.is_empty():
				var opts := hit.duplicate()
				opts["kb"] = Vector2(float(hit.get("kb", 0.0)), 0.0)
				h.hurt(1.0, foe, opts)
				r["knocked"] = h.knock_t > 0.0
		var press := hit_t >= 0.0 and i % 2 == 0
		h.inp["glide"] = h.gliding or press
		h.inp["glide_btn"] = not h.gliding and press
		m.step(Match.DT)
		t += Match.DT
		i += 1
		if hit_t >= 0.0 and absf(t - hit_t - Match.DT) < 0.001:
			r["roll_after"] = h.roll_t
			r["vx_after"] = h.vel.x
		if hit_t >= 0.0 and t > hit_t:
			r["fold"] = r["fold"] or (was_open and not h.gliding)
			if h.gliding and float(r["open_at"]) < 0.0 and (r["fold"] or state != "glide"):
				r["open_at"] = t - hit_t
			was_open = h.gliding
	h.inp["glide"] = false
	h.inp["glide_btn"] = false
	r["x"] = h.pos.x - x0
	return r

## Lace, Kael, Vex and Albert, each hit while gliding, in an air dash and falling (docs/MOVEMENT_FEEL.md
## "Knocked in the air"). A knock carries an open glider; a stun shuts it until a press after the stun; a knock
## or a stun past an air dash's i-frames ends the dash; a shut glider waits out a hard knock before it opens.
func _air_knocks() -> void:
	var at := marker + Vector3(0, AIR_HIGH, 0)
	var hits := _air_hits()
	for arch in AIR_HEROES:
		h.reclass(Arch.weight(arch), arch)
		var fall_carry := {}
		for state in ["fall", "glide", "dash"]:
			var base := _air_run(state, {}, at)
			for what in hits:
				var hit: Dictionary = hits[what]
				var got := _air_run(state, hit, at)
				var carry := float(got["x"]) - float(base["x"])
				if state == "fall": fall_carry[what] = carry
				var open_at := float(got["open_at"])
				var reopen := "%.2f s" % open_at if open_at >= 0.0 else "-"
				var tag := "%s %s, %s: carried %.2f m, reopen %s" % [arch, state, what, carry, reopen]
				_air_row(state, hit, got, tag, carry, float(fall_carry[what]))
	h.reclass("medium", "")

## Asserts one air-knock case (`tag` names it and carries what was measured).
func _air_row(state: String, hit: Dictionary, got: Dictionary, tag: String, carry: float, fall: float) -> void:
	var stun := float(hit.get("stun", 0.0))
	var speed := float(hit.get("kb", 0.0)) / h.mass()
	var open_at := float(got["open_at"])
	if state == "glide":
		ok(got["fold"] == (stun > 0.0), "%s: the glider %s" % [tag, "shuts (stunned)" if stun > 0.0 else "stays open"])
		if stun <= 0.0:
			ok(carry >= 0.8 * fall, "%s: ...the knock carries it as far as a fall (%.2f m)" % [tag, fall])
	elif state == "dash" and got["rolling"] and (stun > 0.0 or got["knocked"]):
		ok(float(got["roll_after"]) <= 0.0, "%s: the hit ends the air dash" % tag)
		if speed > 0.0:
			var vx := float(got["vx_after"])
			ok(vx >= 0.9 * speed, "%s: ...at the knock's full %.1f m/s (%.1f)" % [tag, speed, vx])
	print("ACHECK row %s" % tag)
	if stun > 0.0:
		# (an air dash's kit move may hold the glider a little longer: AirLimits)
		var late := open_at <= stun + 0.1 or state == "dash"
		ok(open_at >= stun and late, "%s: a press opens the glider once the %.1f s stun is over" % [tag, stun])
	elif state == "fall":
		var gate := KNOCK_GATE if speed > 4.0 else 0.0
		var in_time := open_at >= gate and open_at <= gate + 0.25
		ok(in_time, "%s: a press opens the glider %.1f s after the hit or so" % [tag, gate])

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
	foe = m.hunters[1]
	h.ctrl = "local"
	for kk in [h.kin, h.kin2]:
		if kk:
			m.kins.erase(kk)
			kk.queue_free()
	h.kin = null
	h.kin2 = null
	m.opts["god"] = true
	marker = w.random_ground()
	var edges := _edges(1)
	ok(edges.size() > 0, "found a test rim")
	var e: Dictionary = edges[0]
	spot = Vector3(e["at"].x, float(e["top"]) + 12.0, e["at"].z)
	_shot()
	_spike()
	_knock()
	_stun()
	_air_knocks()
	m.queue_free()
	print("ACHECK DONE, failures: ", bad)
	main.get_tree().quit()
