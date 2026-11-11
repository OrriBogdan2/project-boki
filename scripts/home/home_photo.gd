class_name HomePhoto
extends RefCounted
## Photo mode on the farm (pause menu, More links): the HUD goes away, time stands still, and the
## camera orbits and pans round the Boki you were facing, or you. One Capture button saves the view as
## a PNG in the user folder. Leaving puts the HUD, the camera and the clock back.

const SAVE_DIR := "user://photos"
const ORBIT_PER_PIXEL := 0.005     # rad of turn per pixel dragged
const PAN_PER_PIXEL := 0.02        # m of pan per pixel dragged, at zoom 1
const ZOOM_STEP := 0.08            # per wheel notch
const ZOOM_RANGE := Vector2(0.3, 2.0)
const PITCH_RANGE := Vector2(deg_to_rad(12.0), deg_to_rad(80.0))      # the camera's up vector flips at 85
const PAN_LIMIT := 12.0            # m the view may drift from the subject

var active := false
var yaw_turned := 0.0              # the orbit so far (the check reads it)
var _home: Node3D
var _layer: CanvasLayer
var _bar: Control
var _subject: Node3D
var _pan := Vector3.ZERO
var _saved := {}

func _init(home: Node3D) -> void:
	_home = home

## Starts photo mode round the Boki being faced (else you). False when the farm is busy.
func enter() -> bool:
	if active or _home.hb.active or _home.panel_open != "" or not _home.train.is_empty():
		return false
	var cam: CamRig = _home.cam
	_saved = {"yaw": cam.yaw, "yaw_to": cam.yaw_to, "pitch": cam.pitch, "zoom": cam.zoom, "zoom_to": cam.zoom_to}
	_subject = _home.player
	var faced: Dictionary = _home.interact
	if String(faced.get("kind", "")) == "kin":
		_subject = faced["k"]["node"]
	_pan = Vector3.ZERO
	yaw_turned = 0.0
	_home.ui.visible = false
	_build_bar()
	active = true
	return true

## Puts the HUD and the camera back as they were.
func exit() -> void:
	if not active:
		return
	active = false
	var cam: CamRig = _home.cam
	cam.yaw = _saved["yaw"]
	cam.yaw_to = _saved["yaw_to"]
	cam.pitch = _saved["pitch"]
	cam.zoom = _saved["zoom"]
	cam.zoom_to = _saved["zoom_to"]
	_home.ui.visible = true
	_layer.queue_free()

## Every frame while active (the farm's own update is skipped): keeps the camera on the subject.
func tick(delta: float) -> void:
	if not is_instance_valid(_subject):
		_subject = _home.player
	_home.cam.follow(_subject.global_position + _pan, delta, false)

## Drag to orbit, right or middle drag to pan, wheel to zoom, Esc to leave. True when used.
func input(event: InputEvent) -> bool:
	var cam: CamRig = _home.cam
	if event.is_action_pressed("menu"):
		exit()
		return true
	if event is InputEventMouseMotion:
		return _drag(event as InputEventMouseMotion)
	if event is InputEventMouseButton and event.pressed:
		var step := 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			step = -ZOOM_STEP
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step = ZOOM_STEP
		cam.zoom_to = clampf(cam.zoom_to + step, ZOOM_RANGE.x, ZOOM_RANGE.y)
	return false

## Hides the photo controls for two frames, saves the view, and shows them again with a toast.
## Returns the file's path ("" if the image could not be written).
func capture() -> String:
	_bar.visible = false
	var tree := _home.get_tree()
	await tree.process_frame
	await tree.process_frame
	var image := _home.get_viewport().get_texture().get_image()
	if is_instance_valid(_bar):
		_bar.visible = true
	var path := ""
	if image != null and not image.is_empty():
		path = _file_path()
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if image.save_png(path) != OK:
			path = ""
	if is_instance_valid(_bar):
		var text := "Photo saved: %s" % path.get_file() if path != "" else "The photo could not be saved"
		UI.toast(_bar, text, UI.GOLD, 80.0)
	return path

func _drag(motion: InputEventMouseMotion) -> bool:
	var cam: CamRig = _home.cam
	var buttons := motion.button_mask
	if buttons & MOUSE_BUTTON_MASK_LEFT:
		cam.yaw -= motion.relative.x * ORBIT_PER_PIXEL
		cam.yaw_to = cam.yaw
		yaw_turned += motion.relative.x * ORBIT_PER_PIXEL
		cam.pitch = clampf(cam.pitch + motion.relative.y * ORBIT_PER_PIXEL, PITCH_RANGE.x, PITCH_RANGE.y)
		return true
	if buttons & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
		var across := Vector3(-motion.relative.x, 0, -motion.relative.y) * PAN_PER_PIXEL * cam.zoom_to
		_pan = (_pan + across.rotated(Vector3.UP, cam.yaw)).limit_length(PAN_LIMIT)
		return true
	return false

func _file_path() -> String:
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	return "%s/boki_%s.png" % [SAVE_DIR, stamp]

func _build_bar() -> void:
	_layer = CanvasLayer.new()
	_home.add_child(_layer)
	_bar = Control.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bar)
	var panel := UI.glass(8, 12)
	var row := UI.hbox(14)
	panel.add_child(row)
	row.add_child(UI.primary("Capture", func(): capture(), 140))
	row.add_child(UI.label("Drag: orbit   Right drag: pan   Wheel: zoom   Esc: leave", 13, UI.MUTED))
	_bar.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
