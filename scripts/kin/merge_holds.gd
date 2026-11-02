class_name MergeHolds
extends RefCounted
## The hold on a merged form's RMB, and the swept blink on E (docs/decisions/0003). One shape for all:
## press starts it, it fills (a rising tick, a "full" tick at fill_s), and letting go (or running out)
## ends it. What it does is the kind:
##   bulldoze  an armoured roll that carries foes and shrugs off knockback; release slams (grows with the fill)
##   hover     a slow fall that holds at island level over the abyss, so a gap can be crossed; drains
##   prism     a reflect window toward the cursor (Verbs mirror); what it catches flies back harder the longer you held
## Hunter.gd asks hovering() / hover_vy() from its fall code (three lines), nothing else of the hunter changes.

const BLINK_STEP := 0.5        # m: the blink is swept in steps this long, so walls stop it and nobody is skipped
const HOLD_REFRESH := 0.2      # s: the hunter fields a hold sets (roll, guard, reflect) last this long and are refreshed every step
const TICK_EVERY := 0.2        # s between the rising ticks of a fill
const HOVER_LIFT_HOLD := 12.0  # m/s^2 a hover decelerates a rise with (soft apex)
const HOVER_SINK_RATE := 40.0  # m/s^2 the fall is eased into the hover's slow sink

static func begin(k: MergeKit) -> void:
	var d: Dictionary = k.fd["rmb"]
	var kind := String(d["kind"])
	k.hold = {"kind": kind, "t": 0.0, "fill": 0.0, "full": false, "tick": 0.0, "left": 1.0, "hit": 0.0, "mirror": {}, "dir": k.h.aim_dir(), "carried": []}
	var h := k.h
	h.m.sfx("ab_charge", h.pos, -8.0 if h.is_local() else -14.0, 0.8)
	match kind:
		"bulldoze":
			var mv: Vector2 = h.inp.get("move", Vector2.ZERO)
			k.hold["dir"] = mv.normalized() if mv.length() > 0.2 else h.aim_dir()
			h.move_kind = "rush"
			h.roll_dir = k.hold["dir"]
			h.roll_speed = float(d["speed"])
			h.roll_t = HOLD_REFRESH
			k.play("mf_roll")
		"hover":
			if h.grounded:
				h.vel.y = float(d["lift"])
				h.grounded = false
			k.play("mf_hover")
		"prism":
			k.hold["mirror"] = h.m.verbs.add_mirror(h, {"arc": float(d["arc"]), "radius": float(d["radius"]), "time": HOLD_REFRESH, "dmg_k": float((d["dmg_k"] as Array)[0]),
				"color": (k.form["glow"] as Color).to_html(false)})
			k.play("mf_prism")
	k.announce("rmb", h.pos, float(d.get("radius", d.get("range", 2.0))), 0.0)

## Let go, run out, or get cut off. `silent` = no release effect (the ultimate took over, the merge ended, you were controlled).
static func end(k: MergeKit, silent := false) -> void:
	if k.hold.is_empty():
		return
	var d: Dictionary = k.fd["rmb"]
	var hold := k.hold
	k.hold = {}
	var h := k.h
	match String(hold["kind"]):
		"bulldoze":
			h.roll_t = 0.0
			h.fortify_t = 0.0
			if not silent and float(hold["t"]) >= 0.25:
				var ctx := k._ctx("rmb")
				ctx["charge"] = clampf(float(hold["t"]) / float(d["fill_s"]), 0.0, 1.0)
				Effects.run(d["release"], h, ctx)
				h.m.fx.dust(h.pos, 8)
				h.m.shake(0.3 + 0.4 * float(ctx["charge"]), h.pos)
				h.m.sfx("ab_slam", h.pos, -2.0, 0.8)
				k.play("mf_slam_b")
		"prism":
			var mr: Dictionary = hold["mirror"]
			mr["t"] = 0.0
		"hover":
			pass
	k.cd["rmb"] = float(d["cooldown"])
	k.announce("rmb_end", h.pos, 0.0, 0.0)
	if k.anim_id in ["mf_roll", "mf_hover", "mf_prism"]:
		k.anim_id = ""

static func hovering(h: Hunter) -> bool:
	var k := MergeKit.live_of(h)
	if k == null or h.grounded:
		return false
	return not k.rise.is_empty() or (not k.hold.is_empty() and String(k.hold["kind"]) == "hover")

## Hunter._physics: the vertical speed of a hover this step (a slow sink; over the abyss it holds at island level).
static func hover_vy(h: Hunter, vy: float, dt: float) -> float:
	var k := MergeKit.live_of(h)
	if k == null:
		return vy
	if not k.rise.is_empty():
		# the ultimate's climb: up to the marked height and hold there
		return clampf((float(k.rise["base"]) + float(k.rise["h"]) - h.pos.y) * 6.0, -4.0, 6.0)
	var d: Dictionary = k.fd["rmb"]
	if vy > 0.0:
		vy = maxf(0.0, vy - HOVER_LIFT_HOLD * dt)
	else:
		vy = move_toward(vy, -float(d["fall"]), HOVER_SINK_RATE * dt)
	if h.over_void() and vy < 0.0 and h.pos.y + vy * dt < h.lip_y:
		vy = minf(0.0, (h.lip_y - h.pos.y) / dt)
	return vy

static func tick(k: MergeKit, dt: float) -> void:
	var hold := k.hold
	var d: Dictionary = k.fd["rmb"]
	var h := k.h
	var kind := String(hold["kind"])
	hold["t"] = float(hold["t"]) + dt
	hold["fill"] = clampf(float(hold["t"]) / float(d["fill_s"]), 0.0, 1.0)
	# cut off: control effects end it with no release; letting go ends it with one
	if h.stun_t > 0.0 or h.root_t > 0.0 or h.downed or h.out or KitStatus.grounded(h):
		end(k, true)
		return
	if kind == "bulldoze" and h.roll_t > 0.0 and h.move_kind == "dash":
		end(k, true)               # a dash cancels it (Shift stays yours)
		return
	var held := k.held_rmb()
	if not held and float(hold["t"]) > 0.08:
		end(k)
		return
	_fill_feedback(k, hold)
	match kind:
		"bulldoze":
			_bulldoze(k, hold, d, dt)
		"hover":
			hold["left"] = float(hold["left"]) - dt / float(d["drain_s"])
			if h.grounded and float(hold["t"]) > 0.3:
				end(k, true)
				return
			if float(hold["left"]) <= 0.0:
				end(k, true)
				return
		"prism":
			hold["left"] = float(hold["left"]) - dt / float(d["drain_s"])
			var mr: Dictionary = hold["mirror"]
			mr["t"] = HOLD_REFRESH
			var ks: Array = d["dmg_k"]
			mr["k"] = minf(lerpf(float(ks[0]), float(ks[1]), float(hold["fill"])), KinRules.REFLECT_MAX)
			h.slow_t = maxf(h.slow_t, HOLD_REFRESH)
			h.slow_k = maxf(h.slow_k, 1.0 - float(d["slow"]))
			if float(hold["left"]) <= 0.0:
				end(k)

static func _fill_feedback(k: MergeKit, hold: Dictionary) -> void:
	var h := k.h
	hold["tick"] = float(hold["tick"]) - 1.0 / 60.0
	if float(hold["tick"]) <= 0.0 and not bool(hold["full"]):
		hold["tick"] = TICK_EVERY
		h.m.sfx("click", h.pos, -12.0 if h.is_local() else -20.0, 0.9 + 0.8 * float(hold["fill"]))
	if float(hold["fill"]) >= 1.0 and not bool(hold["full"]):
		hold["full"] = true
		var col: Color = k.form["glow"]
		h.m.sfx("ab_ready", h.pos, -4.0 if h.is_local() else -12.0, 1.3)
		h.m.fx.ring(h.pos, 1.6, col, 0.25)
		h.m.fx.flash(h.pos + Vector3(0, 1.0, 0), col, 0.9, 0.08)

static func _bulldoze(k: MergeKit, hold: Dictionary, d: Dictionary, dt: float) -> void:
	var h := k.h
	if float(hold["t"]) >= float(d["max_s"]):
		end(k)
		return
	# steer toward the keys (never straight back) and keep the roll alive
	var mv: Vector2 = h.inp.get("move", Vector2.ZERO)
	var dir: Vector2 = hold["dir"]
	if mv.length() > 0.2:
		var want := mv.normalized()
		var a := dir.angle_to(want)
		var step := float(d["turn"]) * dt
		dir = dir.rotated(clampf(a, -step, step))
	hold["dir"] = dir
	h.move_kind = "rush"
	h.roll_dir = dir
	h.roll_speed = float(d["speed"])
	h.roll_t = HOLD_REFRESH
	h.fortify_t = maxf(h.fortify_t, HOLD_REFRESH)
	h.guard_t = maxf(h.guard_t, HOLD_REFRESH)
	h.guard_k = maxf(h.guard_k, float(d["guard"]))
	hold["hit"] = float(hold["hit"]) - dt
	var tick_now := float(hold["hit"]) <= 0.0
	if tick_now:
		hold["hit"] = float(d["tick_every"])
	for f in h.m.foes_of(h.team):
		if not f.hittable() or f.flat_dist(h) > h.r + f.r + 1.1:
			continue
		var to: Vector2 = h.dir_to(f)
		if to.dot(dir) < 0.2:
			continue
		# carried: pushed at (nearly) your own speed along the roll
		var ms: float = f.mass() if f.has_method("mass") else 1.0
		f.impulse(dir * float(d["speed"]) * float(d["carry"]) * ms)
		if tick_now:
			f.hurt(float(d["tick_dmg"]) * h.m.dmg_mult(h), h, {"src": "abil", "ab": "bulldoze", "tags": ["form"], "dr": true})
			h.m.fx.dust(f.pos, 2)
	if int(h.m.time * 10.0) % 3 == 0:
		h.m.fx.dust(h.pos, 1)

# ------------------------------------------------------------------ the blink
## Stormwing's E: a swept dash with no travel time. Steps of BLINK_STEP up to the distance; stops short of a wall or the abyss.
## Everything the path touches is shocked once. Spends a charge; false when none is left or the path is blocked at once.
static func blink(k: MergeKit) -> bool:
	if k.charges < 1.0:
		return false
	var e: Dictionary = k.fd["e"]
	var h := k.h
	var aim: Vector3 = h.inp.get("aim", h.pos)
	var dir := Vector2(aim.x - h.pos.x, aim.z - h.pos.z)
	if dir.length() < 0.3:
		dir = h.aim_dir()
	dir = dir.normalized()
	var best := h.pos
	var hit: Dictionary = {}
	var dist := float(e["distance"])
	var width := float(e["width"])
	var s := BLINK_STEP
	var col := Color(String(e.get("color", "#fff27a")))
	var d := 0.0
	var m := h.m
	while d < dist:
		d = minf(dist, d + s)
		var q := h.pos + Vector3(dir.x, 0, dir.y) * d
		var airborne := not h.grounded
		if m.world.is_block(q.x, q.z) or (m.world.is_void(q.x, q.z) and not airborne):
			break
		if not airborne and absf(m.world.ground_at(q.x, q.z) - h.pos.y) > World.LEVEL + 0.6:
			break
		best = Vector3(q.x, h.pos.y if airborne else m.world.ground_at(q.x, q.z), q.z)
		for f in m.foes_of(h.team):
			if hit.has(f) or not f.hittable():
				continue
			if Vector2(f.pos.x - q.x, f.pos.z - q.z).length() <= width + f.r:
				hit[f] = true
	if best.distance_to(h.pos) < 1.0:
		return false
	k.charges -= 1.0
	if k.recharge <= 0.0:
		k.recharge = float(e["recharge"])
	var from := h.pos
	m.fx.bolt(from + Vector3(0, 1.0, 0), best + Vector3(0, 1.0, 0), col)
	m.fx.burst(from + Vector3(0, 0.9, 0), col, 12, 3.0, 0.3)
	h.teleport(best)
	m.fx.burst(best + Vector3(0, 0.9, 0), col, 12, 3.0, 0.3)
	m.fx.ring(best, 1.8, col, 0.25)
	h.inv_t = maxf(h.inv_t, float(e["iframes"]))
	h.vel.x = dir.x * 4.0
	h.vel.z = dir.y * 4.0
	h.phase_t = maxf(h.phase_t, 0.15)
	for f in hit:
		var ff: Ent = f
		ff.hurt(float(e["dmg"]) * m.dmg_mult(h), h, {"src": "abil", "ab": "blink", "tags": ["form", "blink"], "stun": float(e["stun"]), "dr": true})
		m.fx.bolt(ff.pos + Vector3(0, 2.5, 0), ff.pos + Vector3(0, 0.8, 0), col)
	m.sfx("zap", best, -2.0, 1.5)
	m.sfx("ab_blink", from, -4.0, 1.2)
	k.play("mf_e")
	k.announce("blink", best, 0.0, 0.0)
	k.h.cast_at = m.time
	k.h.cast_slot = "kin"
	CombatBus.ability_used.emit(h, "%s_e" % k.form["id"], "kin")
	return true
