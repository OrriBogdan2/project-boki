class_name ShowMarks
extends Control
## The Show Ring's result, seen: three judge marks (Look, Trick, Bond) pop over the stage one after another,
## each as a plate of filled pips (no words), then a ribbon in the placing's colour drops onto the shown
## Boki and stays on it until it walks away from the stage. Drawn flat with a dark outline, in screen px
## so the default garden camera reads it at 1280x720. The look is the "marks" block of show_ring.json.

const MARK_H := 2.3      # m above the stage's middle where the marks hang
const CHEST_Y := 0.75    # m above the Boki's feet where the ribbon sits
const LEAVE_M := 1.8     # m from the stage's middle: past this the Boki has left the ring and the ribbon goes
const PLATE_W := 112.0   # px: a mark plate's width
const PLATE_H := 30.0    # px: and its height
const PLATE_GAP := 124.0 # px between mark plates
const PIP_R := 8.0       # px: a pip's radius
const POP_S := 0.12      # s a mark takes to grow to full size
const RISE_PX := 18.0    # px a mark climbs over its life
const DROP_PX := 70.0    # px above the Boki the ribbon starts
const ROSETTE_R := 15.0  # px: the ribbon's disc radius
const INK := Color(0.06, 0.07, 0.12)   # the outline and the plates' fill, readable on any ground

var k: Dictionary         # the shown Boki's entry
var centre: Vector3       # the stage's middle
var marks: Array = []     # pips to fill on each mark, in order
var col := Color.WHITE    # the ribbon's colour
var t := 0.0              # s since the result
var rib_t := 0.0          # s after which the ribbon drops
var life := 0.0           # s each mark lasts
var drop := 0.0           # s the ribbon takes to land
var pips := 5

## scores: the shown Boki's ShowRing.score dict; placing: ShowRing.placing's id.
func _init(entry: Dictionary, stage_at: Vector3, scores: Dictionary, placing: String) -> void:
	var M: Dictionary = ShowRing.rules()["marks"]
	k = entry
	centre = stage_at
	pips = int(M["pips"])
	life = float(M["life_s"])
	drop = float(M["drop_s"])
	col = Color(String(M["colors"][placing]))
	for part in ["look", "trick", "bond"]:
		marks.append(roundi(float(scores[part]) / ShowRing.ROUND_MAX * pips))
	rib_t = marks.size() * float(M["gap_s"])
	name = "ShowMarks"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(dt: float) -> void:
	t += dt
	var n := k["node"] as Node3D
	if not is_instance_valid(n) or (t > rib_t and n.global_position.distance_to(centre) > LEAVE_M):
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var gap := rib_t / marks.size()
	var over := centre + Vector3(0, MARK_H, 0)
	if not cam.is_position_behind(over):
		var mid := cam.unproject_position(over)
		for i in marks.size():
			_mark(mid + Vector2((i - (marks.size() - 1) * 0.5) * PLATE_GAP, 0), t - i * gap, marks[i])
	var n := k["node"] as Node3D
	if t >= rib_t and n.is_visible_in_tree():
		var at := n.global_position + Vector3(0, CHEST_Y, 0)
		if not cam.is_position_behind(at):
			_ribbon(cam.unproject_position(at), (t - rib_t) / drop)

## One judge's mark: a dark plate with `filled` of the pips lit in the ribbon's colour.
func _mark(at: Vector2, age: float, filled: int) -> void:
	if age < 0.0 or age > life:
		return
	var u := age / life
	var s := minf(1.0, age / POP_S)
	var a := 1.0 - clampf((u - 0.6) / 0.4, 0.0, 1.0)
	var c := at - Vector2(0, RISE_PX * ease(u, 0.4))
	var half := Vector2(PLATE_W, PLATE_H) * 0.5 * s
	draw_rect(Rect2(c - half, half * 2.0), Color(INK, 0.8 * a))
	draw_rect(Rect2(c - half, half * 2.0), Color(col, a), false, 2.0)
	var step := PLATE_W / (pips + 0.5)
	for i in pips:
		var p := c + Vector2((i - (pips - 1) * 0.5) * step, 0)
		draw_circle(p, PIP_R * s, Color(INK, a))
		if i < filled:
			draw_circle(p, (PIP_R - 2.0) * s, Color(col.lightened(0.2), a))

## The rosette with two tails: it falls from DROP_PX above, lands with a small squash and stays.
func _ribbon(at: Vector2, u: float) -> void:
	var f := clampf(u, 0.0, 1.0)
	var p := at - Vector2(0, DROP_PX * (1.0 - ease(f, 2.2)))
	var sq := 1.0 + 0.25 * sin(f * PI) * (1.0 if f > 0.6 else 0.0)
	var r := ROSETTE_R
	for side in [-1.0, 1.0]:
		var tail := PackedVector2Array([p, p + Vector2(side * r * 0.2, r * 0.4), p + Vector2(side * r * 1.1, r * 1.9),
				p + Vector2(side * r * 0.4, r * 1.6), p + Vector2(side * r * 0.1, r * 1.9)])
		draw_colored_polygon(tail, col.darkened(0.25))
		draw_polyline(tail, INK, 2.0)
	draw_circle(p, (r + 2.5) * sq, INK)
	draw_circle(p, r * sq, col)
	draw_circle(p, r * 0.55 * sq, col.lightened(0.3))
