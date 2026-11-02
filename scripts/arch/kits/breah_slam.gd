class_name BreahSlam
extends RefCounted
## Breah's Quakefall (RMB): hold to gather, let go to hop a short way forward and smash both fists down.
## While charging, everyone sees the big circle a hop ahead of her with its sweet spot growing from the
## centre; she can walk slowly, jump to leap forward (the circle comes with her) and punch to lunge
## further. The centre stuns, foes in the air are dunked, rocks inside fly outward, a knock or kill
## resets it, and at rank 3 each slam that catches something adds a Molten Guard shield stack.

var k: DolmKit
var leapt := false             # jumped during this charge (the leap forward)
var lunges := 0                # punches during this charge
var was_ground := true
var leaps := 0                 # (checks)
var extends_n := 0
var hops := 0

func _init(kit: DolmKit) -> void:
	k = kit

func sd() -> Dictionary: return k.slam_def()

## The charge so far, 0..1 (the press's first `hold` seconds are the tap window).
func charge_k(t: float) -> float:
	return clampf((t - float(k.rmb_def()["hold"])) / float(sd()["time"]), 0.0, 1.0)

func charging() -> bool:
	return k.rmb_down and k.rmb_t > float(k.rmb_def()["hold"]) * 0.5

func radius(c: float) -> float: return lerpf(float(sd()["radius"][0]), float(sd()["radius"][1]), c)
func core(c: float) -> float: return lerpf(float(sd()["core"][0]), float(sd()["core"][1]), c)

## Where the slam will land: a hop ahead of her toward the aim.
func center() -> Vector3:
	var d := k.h.aim_dir()
	return k.h.pos + Vector3(d.x, 0, d.y) * float(sd()["reach"])

func move_k() -> float:
	return float(sd()["walk_k"]) if charging() else 1.0

func drop() -> void:
	leapt = false
	lunges = 0

func tick(_dt: float) -> void:
	if not k.rmb_down:
		leapt = false
		lunges = 0
	was_ground = k.h.grounded

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
		looks.hold_on(
			"br_slamfist%d" % int(side), "hand", h, at, 0.5 + 0.9 * c, DolmKit.MOLTEN.lerp(Color("fff0b0"), c)
		)
	if fmod(k.m.time, 0.12) < 1.0 / 60.0:
		k.m.fx.spark(
			h.pos + Vector3(0, 0.2, 0), Vector3.UP, DolmKit.MOLTEN, int(2 + 4 * c), 2.0 + 2.0 * c, 70.0, 0.3, -2.0, 0.8
		)
	# jump while charging: leap forward, the circle rides along
	if not leapt and was_ground and not h.grounded and h.vel.y > 0.5:
		leapt = true
		leaps += 1
		k._lunge(float(sd()["leap"]), float(sd()["leap_t"]), dd)
		h.vel.y = maxf(h.vel.y, float(sd()["leap_up"]))
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
		k.anim_id = ""      # (the held pose ends)
		return
	var ck := charge_k(float(c["t"])) if c.get("hold", false) else 0.0
	if c.get("air", false) or not h.grounded:
		# in the air (pressed there, or let go mid-leap): dive, slam where you land
		k.dive = true
		k.dive_k = ck
		k.play("breah_dive")
		k.m.sfx("br_leap", h.pos, -2.0, 0.8)
		return
	# the hop into the circle's centre, then both fists down
	hops += 1
	k.play("breah_slam")
	k._lunge(float(sd()["reach"]), float(sd()["hop_t"]), h.aim_dir())
	h.vel.y = maxf(h.vel.y, float(sd()["hop_up"]))
	h.grounded = false
	k.m.later(
		float(sd()["delay"]),
		func(): if is_instance_valid(h) and not h.downed and not KinMerge.active(h): slam(ck, true)
	)

## The air dive's landing.
func land(ck: float) -> void:
	k.play("breah_slam_land")
	slam(ck, true)

func slam(c: float, at_feet: bool) -> void:
	var h := k.h
	var m := k.m
	var s := sd()
	var at := h.pos
	if not at_feet:
		var pw := HeroZones.walk(m, h.pos, k.aim(), float(s["reach"]))
		at = pw["pos"] if pw["ok"] else h.pos
	k.slams += 1
	var r := radius(c)
	var cr := core(c)
	var dmg := lerpf(float(s["dmg"][0]), float(s["dmg"][1]), c) * k.power("sec")
	m.fx.ring(at, r, Color("ff5a2a"), 0.35)
	m.fx.ring(at, cr, Color("ffe0a0"), 0.2)
	m.fx.burst(at + Vector3(0, 0.3, 0), Color("ff9a3c"), int(16 + 20 * c), 6.0 + 3.0 * c, 0.6, 8.0, 1.2)
	m.fx.spark(
		at + Vector3(0, 0.2, 0), Vector3.UP, Color("ffd24a"), int(14 + 14 * c), 9.0 + 4.0 * c, 75.0, 0.35, 14.0, 1.3
	)
	m.fx.spark(at + Vector3(0, 0.2, 0), Vector3.UP, Color("3a2a22"), 10, 7.0, 60.0, 0.45, 16.0, 1.2)
	m.fx.flash(at + Vector3(0, 0.5, 0), Color("ffd9a0"), 1.2 + c, 0.09)
	m.fx.dust(at, int(10 + 6 * c))
	KitLooks.of(m).scorch(at, r * 0.6, float(s["scorch_t"]))
	m.sfx("br_slam", at, 0.0, 1.0)
	Feel.shake(m, "t3" if c > 0.5 else "t2", h, at)
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
		k.slam_hit[f.get_instance_id()] = m.time
		f.hurt(d2, h, o)
		if in_core: KitLooks.of(m).crown(f, float(o["stun"]))
		if air:
			f.vel.y = minf(f.vel.y, -22.0)      # spiked down (after the hit, which would lift it)
		gained = true
		if f.dead or (f is Hunter and (f as Hunter).downed):
			k._reset_quake()
	for w in m.verbs.walls.duplicate():
		if not w.get("rock", false) or int(w["team"]) != h.team: continue
		var mid := k.rock_mid(w)
		var rel := Vector2(mid.x - at.x, mid.z - at.z)
		if rel.length() <= r + 1.1 and absf(mid.y - at.y) < 2.0:
			k.launch(w, rel.normalized() if rel.length() > 0.2 else h.aim_dir(), "slam")
			gained = true
	if gained and k.rank("sec") >= 3:
		k.shield_stacks = mini(int(s["shield_cap"]), k.shield_stacks + 1)
		k.shield_at = m.time
		h.shield = maxf(h.shield, float(s["shield"]) * k.shield_stacks)
		h.shield_t = float(s["shield_t"])
		m.fx.ring(h.pos + Vector3(0, 0.1, 0), 1.2, Color("ffd24a"), 0.35)
