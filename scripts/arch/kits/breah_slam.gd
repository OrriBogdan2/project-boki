class_name BreahSlam
extends RefCounted
## Tarek's Quakefall (RMB), owner item 61. Tap: no hop, an instant slam just ahead, in a slightly smaller
## circle. Short hold (capped; at the cap it goes by itself): he hops forward and up, keeping part of his run's
## speed, the move keys nudge the landing, and he slams on landing with the full circle. While charging,
## everyone sees the circle where the hop will land with its sweet spot growing from the centre; he can walk
## slowly, jump to leap forward (the circle comes with him) and punch to lunge further. The centre stuns,
## foes in the air are dunked, rocks inside fly outward, and at rank 3 each slam that catches something
## adds a Molten Guard shield stack (DolmKit.guard_stack).
## Owner 11-08 (the hop read as too fast and glitchy): the held hop now winds up first (planted in a deep
## crouch for `windup`), leaves the ground fast and eases its ground speed to nil at the landing, falls harder
## than it rose (a thrown stone), and stops short at the first body in its path (a swept test each step) instead
## of shoving it along. Its feel numbers are in content/rules/tuning.json (tenzo.rmb).

const SWEEP_PAD := 1.2         # m past the step's length a foe's centre may lie and still be tested (body radii)

var k: DolmKit
var leapt := false             # jumped during this charge (the leap forward)
var lunges := 0                # punches during this charge
var was_ground := true
var leaps := 0                 # (checks)
var extends_n := 0
var hops := 0
var taps := 0
var hop_on := false            # the hold's hop is in the air (the move keys nudge it)
var hop_v := Vector2.ZERO      # ...its average speed along the ground (eased, before the nudge)
var hop_t := 0.0               # ...how long it has flown
var wind_t := -1.0             # the held hop's wind-up so far (-1: none)
var wind_dir := Vector2.ZERO   # ...the hop's aim and charge, fixed at the release
var wind_run := Vector2.ZERO   # ...and the run it keeps
var wind_k := 0.0
var stops := 0                 # hops stopped short at a body (checks)

func _init(kit: DolmKit) -> void:
	k = kit

func sd() -> Dictionary: return k.slam_def()
func feel() -> Dictionary: return Tuning.of("tenzo")["rmb"]

## The charge so far, 0..1 (the press's first `hold` seconds are the tap window).
func charge_k(t: float) -> float:
	return clampf((t - float(k.rmb_def()["hold"])) / float(sd()["time"]), 0.0, 1.0)

func charging() -> bool:
	return k.rmb_down and k.rmb_t > float(k.rmb_def()["hold"]) * 0.5

func radius(c: float) -> float: return lerpf(float(sd()["radius"][0]), float(sd()["radius"][1]), c)
func core(c: float) -> float: return lerpf(float(sd()["core"][0]), float(sd()["core"][1]), c)

## Where the slam will land: a hop ahead of him toward the aim, plus what the hop keeps of his run.
func center() -> Vector3:
	var h := k.h
	var d := h.aim_dir()
	var c := h.pos + Vector3(d.x, 0, d.y) * float(sd()["hop"])
	if h.grounded:
		c += Vector3(h.vel.x, 0, h.vel.z) * float(feel()["carry"]) * flight()
	return c

## The tap's spot: just in front of him.
func tap_spot() -> Vector3:
	var d := k.h.aim_dir()
	return k.h.pos + Vector3(d.x, 0, d.y) * float(sd()["reach"])

func _flight(up: float) -> float: return 2.0 * up / Hunter.H_GRAV

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

func tick(dt: float) -> void:
	if not k.rmb_down:
		leapt = false
		lunges = 0
	was_ground = k.h.grounded
	_tick_wind(dt)
	_tick_hop(dt)

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
	var ease := float(feel()["ease"])
	var u := clampf(hop_t / flight(), 0.0, 1.0)
	var v := hop_v * ease * (1.0 - pow(u, 1.0 / (ease - 1.0)))
	v += (h.inp["move"] as Vector2).limit_length(1.0) * float(feel()["nudge"])
	if _blocked(v * dt):
		hop_v = Vector2.ZERO
		v = Vector2.ZERO
		stops += 1
	h.vel.x = v.x
	h.vel.z = v.y
	if h.vel.y < 0.0:
		h.vel.y -= Hunter.H_GRAV * (float(feel()["fall_k"]) - 1.0) * dt

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
	if k.anim_id != "breah_crouch" and not leapt: k.play("breah_crouch")
	AimKit.sweet(
		h, "rmb",
		{
			"at": center(), "r": radius(c), "k": c, "fill": c, "core0": float(sd()["core"][0]),
			"core1": float(sd()["core"][1]), "all": true, "col": Color("ff5a2a"), "col2": Color("ffd24a")
		}
	)
	AimKit.charge(h, c, {"col": DolmKit.MOLTEN, "col2": Color("ffe2a0")})
	var looks := KitLooks.of(k.m)
	var dd := h.aim_dir()
	for side in [-1.0, 1.0]:
		var at := h.pos + Vector3(dd.x * 0.3 - dd.y * 0.32 * side, 0.75, dd.y * 0.3 + dd.x * 0.32 * side)
		var hot := DolmKit.MOLTEN.lerp(Color("ffc23a"), c)
		looks.hold_on("br_slamfist%d" % int(side), "mote", h, at, 0.8 + 1.0 * c, hot)
	if fmod(k.m.time, 0.12) < 1.0 / 60.0:
		k.m.fx.spark(
			h.pos + Vector3(0, 0.2, 0), Vector3.UP, DolmKit.MOLTEN, int(2 + 4 * c), 2.0 + 2.0 * c, 70.0, 0.3, -2.0, 0.8
		)
	# jump while charging: leap forward, the circle rides along
	if not leapt and was_ground and not h.grounded and h.vel.y > 0.5:
		leapt = true
		leaps += 1
		arc(float(sd()["leap"]), maxf(h.vel.y, float(sd()["leap_up"])), dd)
		k.play("breah_leap")
		k.m.sfx("br_leap", h.pos, -3.0, 1.0)
		k.m.fx.dust(h.pos, 8)

## A punch pressed during the charge: a lunge forward (the source's "punch to extend").
func extend() -> void:
	if lunges >= int(sd()["lunges"]):
		return
	lunges += 1
	extends_n += 1
	k._lunge(float(sd()["lunge"]), 0.12, k.h.aim_dir())
	k.play("breah_lunge")
	k.m.sfx("br_shove", k.h.pos, -5.0, 1.2)
	k.m.fx.dust(k.h.pos, 6)

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
	var air: bool = c.get("air", false) or not h.grounded
	if not air and not c.get("hold", false):
		taps += 1
		k.dive = false
		k.play("breah_slam_land")
		slam(0.0, false)
		return
	k.dive = true
	k.dive_k = ck
	if air:
		# pressed in the air: dive and slam where you land; let go mid-leap: the leap's arc carries on
		k.dive_fall = h.fly_t <= 0.0
		k.dive_t = 0.0
		k.play("breah_dive" if k.dive_fall else "breah_leap")
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
	k.m.fx.dust(h.pos, 5)
	k.m.sfx("br_crack", h.pos, -8.0, 0.8)

## The hop into the circle's centre, both fists coming down as he lands there.
func _take_off() -> void:
	var h := k.h
	hops += 1
	k.dive = true
	k.dive_k = wind_k
	k.dive_fall = false
	k.play("breah_slam")
	k.m.fx.dust(h.pos, 8)                # the push-off kicks up the ground he leaves
	k.m.sfx("br_leap", h.pos, -6.0, 1.15)
	var up := float(feel()["hop_up"])
	var t := flight()
	var v := wind_dir.normalized() * float(sd()["hop"]) / t + wind_run
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
	var flight := _flight(up)
	var v := dir.normalized() * dist / flight
	h.vel = Vector3(v.x, up, v.y)
	h.grounded = false
	h.fly_t = flight

## The air dive's landing.
func land(ck: float) -> void:
	if k.anim_id != "breah_slam":
		k.play("breah_slam_land")
	slam(ck, true)

func slam(c: float, at_feet: bool) -> void:
	var h := k.h
	var m := k.m
	var s := sd()
	var at := h.pos
	if not at_feet:
		var pw := HeroZones.walk(m, h.pos, tap_spot(), float(s["reach"]))
		at = pw["pos"] if pw["ok"] else h.pos
	k.slams += 1
	var r := radius(c)
	var cr := core(c)
	var dmg := lerpf(float(s["dmg"][0]), float(s["dmg"][1]), c) * k.power("sec")
	m.fx.ring(at, cr, Color("ffb020"), 0.22)
	m.fx.burst(at + Vector3(0, 0.3, 0), Color(1.0, 0.45, 0.1, 0.9), int(16 + 20 * c), 6.0 + 3.0 * c, 0.6, 8.0, 1.3)
	m.fx.spark(
		at + Vector3(0, 0.2, 0), Vector3.UP, Color("ffb347"), int(10 + 10 * c), 9.0 + 4.0 * c, 75.0, 0.35, 14.0, 1.3
	)
	m.fx.flash(at + Vector3(0, 0.5, 0), Color("ff8a2c"), 0.6 + 0.3 * c, 0.08)
	KitLooks.of(m).impact(at, r, c, float(s["scorch_t"]))
	m.sfx("br_slam", at, 0.0, 1.0)
	k.net_ring(at, r, Color("ff5a2a"))
	var gained := false
	for f in k.foes_in(at, r, 3.2):
		var away := Vector2(f.pos.x - at.x, f.pos.z - at.z)
		away = away.normalized() if away.length() > 0.05 else h.aim_dir()
		var in_core: bool = Vector2(f.pos.x - at.x, f.pos.z - at.z).length() <= cr + f.r
		var d2 := dmg * (float(s["core_k"]) if in_core else 1.0)
		var air := f is Hunter and (not (f as Hunter).grounded or (f as Hunter).gliding)
		var o := {"src": "abil", "ab": "rmb", "kb": away * float(s["kb"]), "lift": 2.0, "heavy": true}
		if in_core:
			o["stun"] = lerpf(float(s["stun"][0]), float(s["stun"][1]), c)
			o["dr"] = true
		if air:
			d2 *= 1.0 + float(s["dunk_k"])
			if m.world.is_void(f.pos.x, f.pos.z): d2 += float(s["dunk_void"])
			o.erase("lift")
			k.dunks += 1
			m.fx.word(f.pos + Vector3(0, 2.0, 0), "DUNKED", Color("ffb36a"), true)
			m.fx.beam(f.pos, f.pos + Vector3(0, 6.0, 0), Color("ffe08a"), 0.5, 0.3)
		f.hurt(d2, h, o)
		if in_core: KitLooks.of(m).crown(f, float(o["stun"]))
		if air:
			m.displace.spike(f, -22.0)      # spiked down (after the hit, which would lift it)
		gained = true
	for w in m.verbs.walls.duplicate():
		if not k.launchable(w): continue
		var mid := k.rock_mid(w)
		var rel := Vector2(mid.x - at.x, mid.z - at.z)
		if rel.length() <= r + 1.1 and HeroZones.rock_in_reach(mid.y, at.y):
			k.launch(w, rel.normalized() if rel.length() > 0.2 else h.aim_dir(), "slam")
			gained = true
	if gained and k.rank("sec") >= 3:
		k.guard_stack()
