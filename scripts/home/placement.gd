class_name Placement
extends RefCounted
## What build mode on the farm and decorating in the house share beyond the catalog bar: how a held piece
## turns, when placing ends build mode, the camera's build view and the glow on a piece that is in the way.

const TURN_RATE := 18.0         # 1/s; a quarter turn settles in about a fifth of a second
const BUILD_VIEW := 0.3         # CamRig.top: 0 is the usual angle, 1 looks straight down
const SPIN_SECS := 0.2          # how long a placed piece takes to turn when its menu says Rotate
const GLOW := Color(1.0, 0.72, 0.2, 0.5)

## The turn a held piece makes each frame: it eases to its quarter turn, so Rotate never snaps.
static func turn_toward(piece: Node3D, yaw: float, delta: float) -> void:
	piece.rotation.y = lerp_angle(piece.rotation.y, yaw, minf(1.0, delta * TURN_RATE))

## A piece that was just rebuilt at its new angle starts from the old one and turns to it.
static func spin_from(piece: Node3D, old_yaw: float) -> void:
	if not is_instance_valid(piece):
		return
	var final_yaw := piece.rotation.y
	piece.rotation.y = final_yaw + wrapf(old_yaw - final_yaw, -PI, PI)
	var tween := piece.create_tween()
	tween.tween_property(piece, "rotation:y", final_yaw, SPIN_SECS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Single pieces leave build mode when they are placed; lines and brushes stay in their tool, and
## holding Shift keeps the same piece in hand.
static func leaves_build_mode(is_tool: bool, keep_in_hand: bool) -> bool:
	return not is_tool and not keep_in_hand

static func placed_text() -> String:
	return "Placed! %s to build more" % Settings.key_cap("build")

## The camera eases to the build view and back.
static func build_view(cam: CamRig, on: bool) -> void:
	cam.top_to = BUILD_VIEW if on else 0.0

## Lights a piece up (the one blocking the ghost, or the one under the cursor).
static func glow(piece: Node3D, col := GLOW) -> void:
	if not is_instance_valid(piece) or piece.get_meta("glow", Color.TRANSPARENT) == col:
		return
	piece.set_meta("glow", col)
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = col
	for mesh in piece.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = overlay

static func unglow(piece: Node3D) -> void:
	if not is_instance_valid(piece) or not piece.has_meta("glow"):
		return
	piece.remove_meta("glow")
	for mesh in piece.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = null
