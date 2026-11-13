class_name DamageDir
extends RefCounted
## Damage direction: a short red arc on a ring around your Hunter (screen space) pointing at whoever
## just hit you, so a shot from off-screen still tells you where from. It fades in LIFE seconds and is
## wider and bolder for a big hit. Only Hunters count: monsters, the Blight and hazards do not.
## Hud owns one; Match feeds it from the damage event and Hud draws it.

const LIFE := 1.0          # s an arc takes to fade out
const MAX_ARCS := 6        # arcs kept at once; the oldest goes first
const BIG_HIT := 60.0      # damage that draws a full-strength arc
const RING := 0.2          # ring radius, as a share of the shorter screen side
const MIN_SPREAD := 0.22   # rad: half-width of the arc for the smallest hit
const MAX_SPREAD := 0.42   # rad: ... and for a big hit
const MIN_WIDTH := 4.0     # px: line width for the smallest hit
const MAX_WIDTH := 10.0    # px: ... and for a big hit
const COL := Color(1.0, 0.25, 0.2)
const CHEST := 1.0         # m above the feet the ring is centred on

var hits: Array = []       # {ang (screen rad), t (s since the hit), power (0.2..1)}

## A hit on `target`: noted when a rival Hunter dealt it and the camera can place both of you.
func hit(m: Match, by: Ent, target: Ent, dmg: float) -> void:
	if not by is Hunter or by == target or m.cam == null or dmg <= 0.0:
		return
	var from := _screen(m.cam, by.pos)
	var d := from - _screen(m.cam, target.pos)
	if d.length() < 1.0:
		return
	hits.append({"ang": d.angle(), "t": 0.0, "power": clampf(dmg / BIG_HIT, 0.2, 1.0)})
	if hits.size() > MAX_ARCS:
		hits.pop_front()

func tick(delta: float) -> void:
	for h in hits:
		h["t"] = float(h["t"]) + delta
	hits = hits.filter(func(h): return float(h["t"]) < LIFE)

func draw(c: CanvasItem, m: Match, sz: Vector2) -> void:
	if hits.is_empty() or m.player == null or m.cam == null:
		return
	var ctr := _screen(m.cam, m.player.pos)
	var rad := minf(sz.x, sz.y) * RING
	for h in hits:
		var power: float = h["power"]
		var a := (1.0 - float(h["t"]) / LIFE) * lerpf(0.55, 1.0, power)
		var ang: float = h["ang"]
		var spread := lerpf(MIN_SPREAD, MAX_SPREAD, power)
		c.draw_arc(ctr, rad, ang - spread, ang + spread, 20, Color(COL, a), lerpf(MIN_WIDTH, MAX_WIDTH, power), true)

func _screen(cam: Camera3D, at: Vector3) -> Vector2:
	return cam.unproject_position(at + Vector3(0, CHEST, 0))
