class_name BjornBoop
extends RefCounted
## LMB behind the raised aegis (docs/heroes/bulwark.md): a short punchy shield thrust, the "boop". The aegis draws
## back ("shield.boop.wind" s), snaps out "thrust" m ("snap" s) and settles home ("settle" s); at the snap, foes
## within "reach" m in front of it are shoved "push" m with a small pop and a clank. It does no damage: it makes room.
## The thrust moves the aegis wall itself (Verbs reads a following wall's "dist" each step), so the block and the
## look move together.

const PULL := 0.15             # m the aegis draws back in the wind-up: the anticipation before the snap
const GUARD_HOLD := 0.12       # s into bul_guard its hold starts (breaker.json hold_from): the guard resumes held

var k: BulwarkKit
var h: Hunter
var m: Node
var t := -1.0                  # s into the thrust, -1 when idle
var ready_at := 0.0
var home := 0.95               # m the wall stands off him at rest (read when the thrust starts)
var hit_done := false
var boops := 0                 # (checks) thrusts started
var booped := 0                # (checks) foes a thrust shoved

func _init(kit: BulwarkKit) -> void:
	k = kit
	h = kit.h
	m = kit.m

func bd() -> Dictionary:
	return k.rmb_def()["shield"].get("boop", {})

## LMB pressed with the aegis up: thrusts when off cooldown.
func press() -> void:
	if t >= 0.0 or m.time < ready_at or k.wall.is_empty():
		return
	t = 0.0
	hit_done = false
	home = float(k.wall["dist"])
	ready_at = m.time + float(bd().get("cd", 0.55))
	boops += 1
	k.play("bul_boop")
	m.sfx("bjorn_shield_up", h.pos, -9.0, 1.5)

func tick(dt: float) -> void:
	if t < 0.0:
		return
	if k.wall.is_empty():
		t = -1.0
		return
	var b := bd()
	var w1 := float(b.get("wind", 0.07))
	var w2 := w1 + float(b.get("snap", 0.06))
	var w3 := w2 + float(b.get("settle", 0.17))
	var out := float(b.get("thrust", 0.7))
	t += dt
	var off := 0.0
	if t < w1:
		off = -PULL * ease(t / w1, 0.5)
	elif t < w2:
		off = lerpf(-PULL, out, ease((t - w1) / (w2 - w1), 2.0))
	elif t < w3:
		off = out * (1.0 - ease((t - w2) / (w3 - w2), 0.4))
	k.wall["dist"] = home + off
	if t >= w2 and not hit_done:
		hit_done = true
		_hit(b)
	if t >= w3:
		k.wall["dist"] = home
		t = -1.0
		k.play("bul_guard")
		k.anim_at = m.time - GUARD_HOLD

## The snap lands: every foe in front of the thrust aegis within "reach" m is shoved back along the aim.
func _hit(b: Dictionary) -> void:
	var n := h.aim_dir()
	var a: Vector2 = k.wall["a"]
	var c: Vector2 = k.wall["b"]
	var reach := float(b.get("reach", 1.3))
	var any := false
	for f in m.foes_of(h.team):
		if not f.hittable():
			continue
		var p := Vector2(f.pos.x, f.pos.z)
		var q := Geometry2D.get_closest_point_to_segment(p, a, c)
		var ahead := (p - q).dot(n)
		if ahead < -f.r or p.distance_to(q) > reach + f.r or absf(f.pos.y - float(k.wall["y"])) > 2.2:
			continue
		k.pushed_at[f.get_instance_id()] = m.time
		k.shove(f, n, float(b.get("push", 2.8)), float(b.get("push_speed", 18.0)))
		m.fx.burst(f.pos + Vector3(0, 1.0, 0), Color("ffe6a8"), 8, 4.0, 0.2, 4.0, 0.9)
		booped += 1
		any = true
	var mid := (a + c) * 0.5
	if any:
		k.fx.bash(h.pos, n, reach, false)
		m.fx.ring(Vector3(mid.x, float(k.wall["y"]) + 0.3, mid.y), 0.9, Color("ffd27a"), 0.18)
		m.sfx("bjorn_boop", h.pos, -3.0)
	else:
		m.sfx("bjorn_boop", h.pos, -14.0, 1.3)
