class_name BreahSlam
extends RefCounted
## Tarek's Quakefall (RMB), owner item 61. Tap: no hop, an instant slam just ahead, in a slightly smaller
## circle. Short hold (capped; at the cap it goes by itself): he hops forward and up, keeping part of his run's
## speed, the move keys nudge the landing, and he slams on landing with the full circle. While charging,
## everyone sees the circle where the hop will land with its sweet spot growing from the centre; he can walk
## slowly, jump to leap forward (the circle comes with him) and punch to lunge further. The centre stuns,
## the tap slam dunks foes in the air (GlideSpike.dunks; the hop and the dive are leaps and do not), rocks
## inside fly outward, and at rank 3 each slam that catches something adds a Shardskin shield stack
## (DolmKit.guard_stack).
## Owner 11-08 (the hop read as too fast and glitchy): the held hop now winds up first (planted in a deep
## crouch for `windup`), leaves the ground fast and eases its ground speed to nil at the landing, falls harder
## than it rose (a thrown stone), and stops short at the first body in its path (a swept test each step) instead
## of shoving it along. Its feel numbers are in content/rules/tuning.json (tenzo.rmb).
## Owner 11-26 (the air press read as buggy, an insta-dunk): pressed in the air over ground he no longer plunges
## straight down; he pops up a little and falls along a thrown stone's arc onto the cursor's spot (clamped to
## `air_reach`, short of walls and ground higher than the arc), the circle showing there all the way down; out of a
## glide the same arc falls at the glider's plunge. Only with no ground under him does he still plunge straight
## (DolmKit._tick_dive, the abyss rescue).

const SWEEP_PAD := 1.2  # m past the step's length a foe's centre may lie and still be tested (body radii)
const ARC_CLEAR := 0.1  # m: the air press's arc passes at least this far over the ground on its way
const ARC_STEP := 0.25  # m: the air press's landing spot and the ground under its arc are tested this often

var k: DolmKit
var leapt := false  # jumped during this charge (the leap forward)
var lunges := 0  # punches during this charge
var was_ground := true
var leaps := 0  # (checks)
var extends_n := 0
var hops := 0
var taps := 0
var hop_on := false  # the hold's hop is in the air (the move keys nudge it)
var hop_v := Vector2.ZERO  # ...its average speed along the ground (eased, before the nudge)
var hop_t := 0.0  # ...how long it has flown
var wind_t := -1.0  # the held hop's wind-up so far (-1: none)
var wind_dir := Vector2.ZERO  # ...the hop's aim and charge, fixed at the release
var wind_run := Vector2.ZERO  # ...and the run it keeps
var wind_k := 0.0
var stops := 0  # hops stopped short at a body (checks)
var air_to := Vector3.INF  # the air press's landing spot while its arc runs (INF: none)
var air_v := Vector2.ZERO  # ...its ground speed, fixed at the press so it lands there
var air_vy := 0.0  # ...and its vertical speed at the press (m/s: air_up, or a glide's own fall)


func _init(kit: DolmKit) -> void:
	k = kit


func sd() -> Dictionary:
	return k.slam_def()


func feel() -> Dictionary:
	return Loco.T["tenzo"]["rmb"]


## The charge so far, 0..1 (the press's first `hold` seconds are the tap window).
func charge_k(t: float) -> float:
	return clampf((t - float(k.rmb_def()["hold"])) / float(sd()["time"]), 0.0, 1.0)


func charging() -> bool:
	return k.rmb_down and k.rmb_t > float(k.rmb_def()["hold"]) * 0.5


func radius(c: float) -> float:
	return lerpf(float(sd()["radius"][0]), float(sd()["radius"][1]), c)


func core(c: float) -> float:
	return lerpf(float(sd()["core"][0]), float(sd()["core"][1]), c)


## Where the slam will land: a hop ahead of him toward the aim, plus what the hop keeps of his run.
func center() -> Vector3:
	var h := k.h
	var d := h.aim_dir()
	var off := d * float(sd()["hop"])
	if h.grounded:
		off = _hop_room(off + Vector2(h.vel.x, h.vel.z) * float(feel()["carry"]) * flight())
	return h.pos + Vector3(off.x, 0, off.y)


## The top of what stands at (x, z): the ground, or a wall block's top (its ground_at is the floor under it).
func _top(x: float, z: float) -> float:
	var w: World = k.m.world
	return w.block_top_of(w.idx(floori(x), floori(z))) if w.is_block(x, z) else w.ground_at(x, z)


## The held hop's landing offset `off` cut short of the first ground its peak can't clear (a wall), a body radius
## before it, so the circle never shows past a wall the hop stops at.
func _hop_room(off: Vector2) -> Vector2:
	var h := k.h
	var up := float(feel()["hop_up"])
	var top := h.pos.y + up * up / (2.0 * Hunter.H_GRAV) - ARC_CLEAR
	var dir := off.normalized()
	var d := ARC_STEP
	while d <= off.length() + h.r:
		if _top(h.pos.x + dir.x * d, h.pos.z + dir.y * d) > top:
			return dir * clampf(d - h.r - 0.5 * ARC_STEP, 0.0, off.length())
		d += ARC_STEP
	return off


## The tap's spot: just in front of him.
func tap_spot() -> Vector3:
	var d := k.h.aim_dir()
	return k.h.pos + Vector3(d.x, 0, d.y) * float(sd()["reach"])


func _flight(up: float) -> float:
	return 2.0 * up / Hunter.H_GRAV


## The held hop's time in the air: up at hop_up, down under fall_k times the gravity.
func flight() -> float:
	var up := float(feel()["hop_up"]) / Hunter.H_GRAV
	return up * (1.0 + 1.0 / sqrt(float(feel()["fall_k"])))


func move_k() -> float:
	if wind_t >= 0.0:
		return 0.0
	return float(sd()["walk_k"]) if charging() else 1.0


func drop() -> void:
	leapt = false
	lunges = 0
	hop_on = false
	wind_t = -1.0
	air_to = Vector3.INF


func tick(dt: float) -> void:
	if not k.rmb_down:
		leapt = false
		lunges = 0
	was_ground = k.h.grounded
	_tick_wind(dt)
	_tick_hop(dt)
	_tick_air(dt)


## The wind-up: planted, sinking into the crouch, then the take-off.
func _tick_wind(dt: float) -> void:
	if wind_t < 0.0:
		return
	var h := k.h
	if h.downed or h.stun_t > 0.0:
		wind_t = -1.0
		return
	wind_t += dt
	h.vel.x = 0.0
	h.vel.z = 0.0
	_wind_circle()
	if wind_t >= float(feel()["windup"]):
		wind_t = -1.0
		_take_off()


## The hop's flight: its ground speed leaves at `ease` times the average and eases to nil at the landing
## (a curve whose average is exactly the average, so it lands where the circle showed), the move keys bend it
## by up to `nudge` m/s, the way down pulls harder (fall_k), and a body in the way stops it short.
func _tick_hop(dt: float) -> void:
	var h := k.h
	if not hop_on:
		return
	if not k.dive or h.grounded or h.fly_t <= 0.0:
		hop_on = false
		return
	hop_t += dt
	var ease_v := float(feel()["ease"])
	var u := clampf(hop_t / flight(), 0.0, 1.0)
	var v := hop_v * ease_v * (1.0 - pow(u, 1.0 / (ease_v - 1.0)))
	v += (h.inp["move"] as Vector2).limit_length(1.0) * float(feel()["nudge"])
	if _blocked(v * dt):
		hop_v = Vector2.ZERO
		v = Vector2.ZERO
		stops += 1
	h.vel.x = v.x
	h.vel.z = v.y
	if h.vel.y < 0.0:
		h.vel.y -= Hunter.H_GRAV * (float(feel()["fall_k"]) - 1.0) * dt
	# the circle stays on the ground to the landing: where the eased hop comes down if the keys let go
	var left := hop_v * flight() * _left(u, ease_v)
	_circle(h.pos + Vector3(left.x, 0, left.y), k.dive_k)


## The share of the hop's ground distance still ahead at flight share u, for its eased speed curve
## (curve * (1 - u^p), p = 1 / (curve - 1), whose average over the flight is 1).
static func _left(u: float, curve: float) -> float:
	var p := 1.0 / (curve - 1.0)
	return curve * ((1.0 - u) - (1.0 - pow(u, p + 1.0)) / (p + 1.0))


## The circle everyone sees: the slam's outer ring and its sweet spot growing with the charge `c`.
func _circle(at: Vector3, c: float) -> void:
	var cores: Array = sd()["core"]
	var ring := {"at": at, "r": radius(c), "k": c, "fill": c, "core0": cores[0], "core1": cores[1]}
	ring.merge({"all": true, "col": Color("3a7cff"), "col2": Color("d8ecff")})
	AimKit.sweet(k.h, "rmb", ring)


## Swept test: does this step's move along the ground run into a foe's body (circle against circle, so no
## speed passes through one)? A body already touching only stops a move toward it.
func _blocked(step: Vector2) -> bool:
	var h := k.h
	var p := Vector2(h.pos.x, h.pos.z)
	for f in k.foes_in(h.pos, step.length() + SWEEP_PAD, 2.0):
		var c := Vector2(f.pos.x, f.pos.z)
		var near := Geometry2D.get_closest_point_to_segment(c, p, p + step)
		if near.distance_to(c) < f.r + h.r and step.dot(c - p) > 0.0:
			return true
	return false


func hold_tick(t: float) -> void:
	var h := k.h
	if t <= float(k.rmb_def()["hold"]):
		return
	var c := charge_k(t)
	if k.anim_id != "breah_crouch" and not leapt:
		k.play("breah_crouch")
		k.vfx("eye_flare")
	_circle(center(), c)
	AimKit.charge(h, c, {"col": DolmKit.COBALT, "col2": Color("d8ecff")})
	var looks := KitLooks.of(k.m)
	var dd := h.aim_dir()
	for side in [-1.0, 1.0]:
		var at := h.pos + Vector3(dd.x * 0.3 - dd.y * 0.32 * side, 0.75, dd.y * 0.3 + dd.x * 0.32 * side)
		var hot := DolmKit.COBALT.lerp(Color("9ad0ff"), c)
		looks.hold_on("br_slamfist%d" % int(side), "mote", h, at, 0.8 + 1.0 * c, hot)
	HeroVfx.of(k.m).hold(h, "slam_charge", c)
	# jump while charging: leap forward, the circle rides along
	if not leapt and was_ground and not h.grounded and h.vel.y > 0.5:
		leapt = true
		leaps += 1
		arc(float(sd()["leap"]), maxf(h.vel.y, float(sd()["leap_up"])), dd)
		k.play("breah_leap")
		k.m.sfx("br_leap", h.pos, -3.0, 1.0)
		k.vfx("leap")


## A punch pressed during the charge: a lunge forward (the source's "punch to extend").
func extend() -> void:
	if lunges >= int(sd()["lunges"]):
		return
	lunges += 1
	extends_n += 1
	k._lunge(float(sd()["lunge"]), 0.12, k.h.aim_dir())
	k.play("breah_lunge")
	k.m.sfx("br_shove", k.h.pos, -5.0, 1.2)
	k.vfx("dust_step")


func fire(c: Dictionary) -> void:
	var h := k.h
	k.last_variant = String(c["variant"])
	AimKit.hide(h, "rmb")
	if not k.spend_rmb():
		k.anim_id = ""
		return
	k.dive_glide = h.gliding
	if h.gliding:
		# the source's slam out of a glide: the glider folds at once and she plunges at its dive speed
		h.gliding = false
		h.fly_t = 0.0
		h.vel = Vector3(h.vel.x * 0.25, minf(h.vel.y, 0.0), h.vel.z * 0.25)
		k.m.sfx("glide", h.pos, -6.0, 0.7)
	var ck := charge_k(float(c["t"])) if c.get("hold", false) else 0.0
	# a jump pressed on the release's own step counts as released on the ground: the jump goes on, the slam
	# lands at the feet (a tap) or hops into the circle (a charge), not an air dive that eats the jump
	var jumped_now := was_ground and not h.grounded and h.vel.y > 0.5
	var air: bool = c.get("air", false) or (not h.grounded and not jumped_now)
	if not air and not c.get("hold", false):
		taps += 1
		k.dive = false
		k.play("breah_slam_land")
		slam(0.0, false)
		return
	k.dive = true
	k.dive_k = ck
	if air:
		# pressed in the air: the arc onto the cursor's spot (or, with no ground under him, the plunge); let go
		# mid-leap: the leap's arc carries on
		k.dive_fall = h.fly_t <= 0.0 and not _air_arc()
		k.dive_t = 0.0
		k.play("breah_dive" if h.fly_t <= 0.0 or air_on() else "breah_leap")
		k.m.sfx("br_leap", h.pos, -2.0, 0.8)
		return
	# the wind-up: planted in a deep crouch, the fists drawn back, then the hop (_take_off)
	k.dive = false
	wind_t = 0.0
	wind_k = ck
	wind_dir = h.aim_dir()
	wind_run = Vector2(h.vel.x, h.vel.z) * float(feel()["carry"])
	h.vel.x = 0.0
	h.vel.z = 0.0
	k.play("breah_windup")
	_wind_circle()
	k.m.fx.dust(h.pos, 5)
	k.m.sfx("br_crack", h.pos, -8.0, 0.8)


## The circle held through the wind-up where the hop will land (_take_off's flight), so the tell never drops out.
func _wind_circle() -> void:
	var land_v := _hop_room(wind_dir.normalized() * float(sd()["hop"]) + wind_run * flight())
	_circle(k.h.pos + Vector3(land_v.x, 0, land_v.y), wind_k)


## The hop into the circle's centre, both fists coming down as he lands there.
func _take_off() -> void:
	var h := k.h
	hops += 1
	k.dive = true
	k.dive_k = wind_k
	k.dive_fall = false
	k.play("breah_slam")
	k.vfx("dust_step")  # the push-off kicks up the ground he leaves
	k.m.sfx("br_leap", h.pos, -6.0, 1.15)
	var up := float(feel()["hop_up"])
	var t := flight()
	var v := _hop_room(wind_dir.normalized() * float(sd()["hop"]) + wind_run * t) / t
	h.vel = Vector3(v.x, up, v.y)
	h.grounded = false
	h.fly_t = t
	hop_v = v
	hop_t = 0.0
	hop_on = true


## The leap's jump arc (not a dash, which holds your height): `dist` along `dir`, leaving the ground at `up` m/s,
## so the glider can still open from it (DolmKit._tick hands the arc over when glide is held).
func arc(dist: float, up: float, dir: Vector2) -> void:
	var h := k.h
	var flight_v := _flight(up)
	var v := dir.normalized() * dist / flight_v
	h.vel = Vector3(v.x, up, v.y)
	h.grounded = false
	h.fly_t = flight_v


func air_on() -> bool:
	return air_to != Vector3.INF


## The air press's arc: toward the cursor, up to `air_reach`, the furthest spot (in ARC_STEP steps) whose arc clears
## the ground on the way and that his body fits on (no wall just past it), his ground speed set so the fall ends
## there. False with no ground under him (the plunge).
func _air_arc() -> bool:
	var h := k.h
	var g: float = k.m.world.ground_at(h.pos.x, h.pos.z)
	if g <= World.VOID + 1.0 or g > h.pos.y:
		return false
	air_vy = minf(h.vel.y, 0.0) if k.dive_glide else float(feel()["air_up"])
	var aim: Vector3 = h.inp["aim"]
	var dir := h.aim_dir()
	var s := minf(Vector2(aim.x - h.pos.x, aim.z - h.pos.z).length(), float(feel()["air_reach"]))
	s = floorf(s / ARC_STEP) * ARC_STEP
	while s > 0.0 and not _arc_clears(dir, s):
		s -= ARC_STEP
	var spot := Vector3(h.pos.x + dir.x * s, 0.0, h.pos.z + dir.y * s)
	spot.y = k.m.world.ground_at(spot.x, spot.z) if s > 0.0 else g
	var t := air_time(h.pos.y - spot.y)
	air_to = spot
	air_v = Vector2(spot.x - h.pos.x, spot.z - h.pos.z) / t
	h.vel = Vector3(air_v.x, air_vy, air_v.y)
	h.grounded = false
	h.fly_t = t
	return true


## Does the arc to the spot `s` m along `dir` stay over the ground on its way (gaps may pass under it), land on
## ground under its peak, and leave his body room there (no step taller than World.STEP a body radius past it)?
func _arc_clears(dir: Vector2, s: float) -> bool:
	var h := k.h
	var at := func(d: float) -> float: return _top(h.pos.x + dir.x * d, h.pos.z + dir.y * d)
	var gs: float = at.call(s)
	if gs <= World.VOID + 1.0 or at.call(s + h.r) > gs + World.STEP:
		return false
	var t := air_time(h.pos.y - gs)
	var d := ARC_STEP
	while d < s:
		if at.call(d) > arc_y(t * d / s) - ARC_CLEAR:
			return false
		d += ARC_STEP
	return arc_y(t) >= gs - ARC_CLEAR


## How hard the arc falls (m/s^2): out of a glide the glider's plunge (`dive_acc`, the owner's 23:00 source rule),
## otherwise a thrown stone's `air_fall_k` times the gravity.
func _g_dn() -> float:
	return float(feel()["dive_acc"]) if k.dive_glide else Hunter.H_GRAV * float(feel()["air_fall_k"])


## The arc's height `t` s after the press: up at air_vy under the gravity, then down under _g_dn (the plunge cap
## only slows the fall, so this never sits above the real arc).
func arc_y(t: float) -> float:
	var t_up := maxf(air_vy, 0.0) / Hunter.H_GRAV
	var top := k.h.pos.y + maxf(air_vy, 0.0) * t_up * 0.5
	var tf := t - t_up
	if tf < 0.0:
		return k.h.pos.y + air_vy * t - 0.5 * Hunter.H_GRAV * t * t
	return top + minf(air_vy, 0.0) * tf - 0.5 * _g_dn() * tf * tf


## The arc's flight time down `drop` metres from its press: up at air_vy, down under _g_dn, no faster than _cap.
func air_time(drop: float) -> float:
	var up := maxf(air_vy, 0.0)
	var s0 := -minf(air_vy, 0.0)
	var g_dn := _g_dn()
	var cap := maxf(_cap(), s0)
	var fall_h := maxf(0.0, drop + up * up / (2.0 * Hunter.H_GRAV))
	var cap_h := (cap * cap - s0 * s0) / (2.0 * g_dn)
	var down := (cap - s0) / g_dn + (fall_h - cap_h) / cap
	if fall_h <= cap_h:
		down = (sqrt(s0 * s0 + 2.0 * g_dn * fall_h) - s0) / g_dn
	return maxf(up / Hunter.H_GRAV + down, 0.1)


## The arc in flight: its ground speed held (a body in the way stops it short, as the hop), the fall pulled at
## _g_dn, the circle on the landing spot; it ends on the ground (DolmKit._tick_dive).
func _tick_air(dt: float) -> void:
	if not air_on():
		return
	var h := k.h
	if not k.dive or h.grounded:
		air_to = Vector3.INF
		return
	if _blocked(air_v * dt):
		air_v = Vector2.ZERO
		stops += 1
	h.vel.x = air_v.x
	h.vel.z = air_v.y
	h.fly_t = maxf(h.fly_t, 2.0 * dt)
	if h.vel.y <= 0.0:
		h.vel.y = maxf(h.vel.y - (_g_dn() - Hunter.H_GRAV) * dt, -_cap())
	_circle(air_to, k.dive_k)


## The fastest the arc falls (m/s): the glider's dive speed out of a glide, the plunge's otherwise.
func _cap() -> float:
	return float(sd()["glide_dive_speed" if k.dive_glide else "dive_speed"])


## The air dive's landing: the arc's ground speed stops there (it slams on its spot, no slide past it).
func land(ck: float) -> void:
	if air_on():
		air_to = Vector3.INF
		k.h.vel.x = 0.0
		k.h.vel.z = 0.0
	if k.anim_id != "breah_slam":
		k.play("breah_slam_land")
	slam(ck, true)


func slam(c: float, at_feet: bool) -> void:
	var h := k.h
	var m := k.m
	var s := sd()
	AimKit.hide(h, "rmb")
	var at := h.pos
	if not at_feet:
		var pw := HeroZones.walk(m, h.pos, tap_spot(), float(s["reach"]))
		at = pw["pos"] if pw["ok"] else h.pos
	k.slams += 1
	var r := radius(c)
	var cr := core(c)
	var dmg := lerpf(float(s["dmg"][0]), float(s["dmg"][1]), c) * k.power("sec")
	k.vfx("quakefall", at, h.aim_dir(), {"r": r, "k": c})
	m.sfx("br_slam", at, 0.0, 1.0)
	var gained := false
	var spike: Dictionary = {} if at_feet else s["spike"]  # only the tap slam: a hop or dive is a leap
	for f in k.foes_in(at, r, 3.2):
		var in_core: bool = Vector2(f.pos.x - at.x, f.pos.z - at.z).length() <= cr + f.r
		var d2 := dmg * (float(s["core_k"]) if in_core else 1.0)
		var air := GlideSpike.dunks(f, spike)
		var o := {"src": "abil", "ab": "rmb", "heavy": true}  # no knock: the card has a stun and a spike
		if in_core:
			o["stun"] = lerpf(float(s["stun"][0]), float(s["stun"][1]), c)
			o["dr"] = true
		if air:
			d2 *= 1.0 + float(spike["bonus"])
			k.dunks += 1
			m.fx.beam(f.pos, f.pos + Vector3(0, 6.0, 0), Color("d8ecff"), 0.5, 0.3)
			k.vfx("dunk", f.pos)
		f.hurt(d2, h, o)
		if air:
			m.displace.spike(f, -float(spike["vy"]), h)  # spiked down (after the hit, which would lift it)
		gained = true
	for w in m.verbs.walls.duplicate():
		if not k.launchable(w):
			continue
		var mid := k.rock_mid(w)
		var rel := Vector2(mid.x - at.x, mid.z - at.z)
		if rel.length() <= r + 1.1 and HeroZones.rock_in_reach(mid.y, at.y):
			k.launch(w, rel.normalized() if rel.length() > 0.2 else h.aim_dir(), "slam")
			gained = true
	if gained and k.rank("sec") >= 3:
		k.guard_stack()
