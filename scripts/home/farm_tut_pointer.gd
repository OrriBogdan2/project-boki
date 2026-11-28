class_name FarmTutPointer
extends RefCounted
## What points at the tutorial step's target (FarmGuide owns one; numbers: farm_tutorial.json "pointer"). Built for the
## top-down view and kept for the close third-person one (FarmCam), where the target is often behind you or out of the
## frame: a gold beam up from it (seen over the trees and from afar), the world prompt hung lower so it stays in the
## frame as you walk up, and an arrow on the edge of the safe frame pointing the way (with the metres) while the prompt
## is off screen or behind the camera.

const METRES_W_PX := 80.0  # px the distance label is centred in
const PLAYER_H_M := 1.8  # m, your height for the box the prompt keeps off
const PLAYER_W := 0.55  # that box's width as a share of its height
const PROMPT_PAD_PX := 40.0  # px round your box in which the prompt counts as sitting on you (about its half height)
const LIFT_STEP_M := 0.4  # m the prompt goes up per try to clear you

var _beam: MeshInstance3D = null
var _arrow: Control = null
var _tip: Polygon2D = null
var _metres: Label = null


static func rules() -> Dictionary:
	return FarmTutorial.rules()["pointer"]


## Metres over the target the world prompt hangs: the top-down height, lowered as the view turns third person, and
## raised a step at a time (to the top-down height) while it would sit over your own body on screen.
static func lift(h, at: Vector3) -> float:
	var r := rules()
	var top := float(r["lift_top_m"])
	var up := lerpf(top, float(r["lift_third_m"]), smoothstep(0.0, 1.0, h.farm_cam.k))
	var cam: Camera3D = h.cam
	var body := player_box(cam, h.ppos).grow(PROMPT_PAD_PX)
	while up < top and not cam.is_position_behind(at) and body.has_point(cam.unproject_position(at + Vector3.UP * up)):
		up = minf(up + LIFT_STEP_M, top)
	return up


## Your body's box on screen (feet to head), which the prompt keeps off.
static func player_box(cam: Camera3D, ppos: Vector3) -> Rect2:
	var feet := cam.unproject_position(ppos)
	var head := cam.unproject_position(ppos + Vector3.UP * PLAYER_H_M)
	var tall := absf(feet.y - head.y)
	return Rect2(Vector2(feet.x - tall * PLAYER_W * 0.5, head.y), Vector2(tall * PLAYER_W, tall))


## Which way the arrow points on screen, from the screen centre toward `at` (also when it is behind the camera).
static func screen_dir(cam: Camera3D, at: Vector3) -> Vector2:
	var local := cam.global_transform.affine_inverse() * at
	var d := Vector2(local.x, -local.y)
	return d.normalized() if d.length() > 0.001 else Vector2.DOWN


## Where the arrow sits: the line from the centre of `frame` toward `dir`, cut by the frame's edge.
static func edge_point(frame: Rect2, dir: Vector2) -> Vector2:
	var half := frame.size * 0.5
	var k := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
	return frame.get_center() + dir * k


## The part of the screen the arrow keeps to: inside the safe frame, clear of the objective strip and Skip row at the
## top (`strips`) and the hub bar at the bottom.
static func frame(h, strips: Array) -> Rect2:
	var r := rules()
	var f := HudStyle.safe_rect(h.get_viewport().get_visible_rect().size).grow(-float(r["edge_px"]))
	var top := f.position.y
	for c: Control in strips:
		if is_instance_valid(c) and c.is_visible_in_tree():
			top = maxf(top, c.get_global_rect().end.y + float(r["edge_px"]))
	f.end.y -= float(r["bottom_px"])
	f.position.y = minf(top, f.end.y - 1.0)
	return f


## Is the prompt at `at` in view inside `frame`, and far enough off that its label is not huge?
static func in_frame(cam: Camera3D, at: Vector3, frame: Rect2) -> bool:
	return (
		not cam.is_position_behind(at)
		and cam.global_position.distance_to(at) >= float(rules()["near_m"])
		and frame.has_point(cam.unproject_position(at))
	)


## Once a frame while the step's prompt is up: `at` is the target's feet, `prompt` where its world prompt hangs, `strips`
## the on-screen lines to keep off. Returns whether the world prompt itself is in view (else the arrow shows).
func sync(h, at: Vector3, prompt: Vector3, strips: Array) -> bool:
	var r := rules()
	_sync_beam(h, at, r)
	var cam: Camera3D = h.cam
	var frame := frame(h, strips)
	if in_frame(cam, prompt, frame):
		show_arrow(false)
		return true
	_make_arrow(h, float(r["arrow_px"]))
	var dir := screen_dir(cam, prompt)
	_arrow.position = edge_point(frame, dir)
	_tip.rotation = dir.angle() + PI * 0.5
	_metres.text = "%d m" % roundi(Vector2(at.x - h.ppos.x, at.z - h.ppos.z).length())
	_arrow.visible = true
	return false


## Hides both (no prompt now, or the guidance stepped aside).
func hide() -> void:
	show_arrow(false)
	if is_instance_valid(_beam):
		_beam.visible = false


func show_arrow(on: bool) -> void:
	if is_instance_valid(_arrow):
		_arrow.visible = on


func _sync_beam(h, at: Vector3, r: Dictionary) -> void:
	var tall := float(r["beam_m"])
	if not is_instance_valid(_beam):
		var mesh := CylinderMesh.new()
		mesh.top_radius = float(r["beam_w_m"])
		mesh.bottom_radius = float(r["beam_w_m"])
		mesh.height = tall
		mesh.radial_segments = 8
		mesh.rings = 1
		var mat := GardenCues.glow(UI.GOLD, 0.45)
		mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA  # gone when the camera is close
		mat.distance_fade_min_distance = float(r["beam_fade_min_m"])
		mat.distance_fade_max_distance = float(r["beam_fade_max_m"])
		_beam = GardenCues.piece(h, mesh, mat, at)
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position = at + Vector3(0.0, tall * 0.5, 0.0)
	_beam.visible = true


func _make_arrow(h, size: float) -> void:
	if is_instance_valid(_arrow):
		return
	_arrow = Control.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip = Polygon2D.new()
	_tip.polygon = PackedVector2Array(
		[Vector2(0, -size), Vector2(size * 0.7, size * 0.6), Vector2(-size * 0.7, size * 0.6)]
	)
	_tip.color = UI.GOLD
	_arrow.add_child(_tip)
	_metres = UI.label("", 16, UI.GOLD, UI.semi)
	_metres.add_theme_constant_override("outline_size", 6)
	_metres.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07, 0.9))
	_metres.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_metres.custom_minimum_size.x = METRES_W_PX
	_metres.position = Vector2(-METRES_W_PX * 0.5, size * 0.9)
	_arrow.add_child(_metres)
	h.root_ui.add_child(_arrow)
