class_name BjornBoop
extends RefCounted
## LMB behind the raised aegis (docs/heroes/bulwark.md): a short punchy shield thrust, the "boop", and the only
## way the aegis moves foes (walking into it pushes nobody). The aegis draws back ("shield.boop.wind"
## s), snaps out "thrust" m ("snap" s) and settles home ("settle" s); at the snap, foes within "reach" m in front
## of it are shoved "push" m with a pop and a clank. No damage: it makes room. The thrust moves the aegis wall
## itself (Verbs reads a following wall's "dist" each step), so the block and the look move together.

const PULL := 0.15             # m the aegis draws back in the wind-up: the anticipation before the snap
const BODY_Y := 2.2            # m: a foe further above or below the wall's base than this is out of reach
const POP_COL := Color("ffe6a8")
const RING_COL := Color("ffd27a")

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
	return k.rmb_def()["shield"]["boop"]

## LMB pressed with the aegis up: thrusts when off cooldown.
func press() -> void:
	if t >= 0.0 or m.time < ready_at or k.wall.is_empty():
		return
	t = 0.0
	hit_done = false
	home = float(k.wall["dist"])
	ready_at = m.time + float(bd()["cd"])
	boops += 1
	m.sfx("bjorn_shield_up", h.pos, -9.0, 1.5)

func tick(dt: float) -> void:
	if t < 0.0:
		return
	if k.wall.is_empty():
		t = -1.0
		return
	var b := bd()
	var w1 := float(b["wind"])
	var w2 := w1 + float(b["snap"])
	var w3 := w2 + float(b["settle"])
	var out := float(b["thrust"])
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

## The snap lands: every foe in front of the thrust aegis within "reach" m is shoved back along the aim.
func _hit(b: Dictionary) -> void:
	var n := h.aim_dir()
	var a: Vector2 = k.wall["a"]
	var c: Vector2 = k.wall["b"]
	var reach := float(b["reach"])
	var any := false
	for f in m.foes_of(h.team):
		if not f.hittable():
			continue
		var p := Vector2(f.pos.x, f.pos.z)
		var q := Geometry2D.get_closest_point_to_segment(p, a, c)
		if (p - q).dot(n) < -f.r or p.distance_to(q) > reach + f.r or absf(f.pos.y - float(k.wall["y"])) > BODY_Y:
			continue
		k.shove(f, n, float(b["push"]), float(b["push_speed"]))
		m.fx.burst(f.pos + Vector3(0, 1.0, 0), POP_COL, 8, 4.0, 0.2, 4.0, 0.9)
		booped += 1
		any = true
	var mid := (a + c) * 0.5
	if any:
		k.fx.aegis_hit = 1.0
		m.fx.ring(Vector3(mid.x, float(k.wall["y"]) + 0.3, mid.y), 0.9, RING_COL, 0.18)
		m.sfx("bjorn_bash", h.pos, -3.0, 1.4)
	else:
		m.sfx("bjorn_bash", h.pos, -14.0, 1.6)
