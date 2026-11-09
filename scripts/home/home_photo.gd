class_name HomePhoto
extends RefCounted
## Photo mode at home (the "photo" key, F8, rebindable). It reuses recording mode's no-HUD level, frees the
## camera to pan and orbit inside the garden, lets you pick a Boki to look at, can caption it with its name
## and species, and saves the frame as a PNG in user://photos. Nothing is uploaded; latest() gives the newest
## file back for the race post's showcase.
##   WASD / arrows  pan        Q / E  orbit        Tab / Shift+Tab or a click  pick a Boki
##   C  caption on / off       Enter  take the photo        the photo key or Esc  leave

const DIR := "user://photos"
const PAN_SPEED := 9.0          # m/s at camera zoom 1
const TURN_SPEED := 1.6         # rad/s
const EDGE_MARGIN := 1.5        # m kept inside the coast, so the shot never frames the void
const FOLLOW_EASE := 5.0        # 1/s: how fast the focus glides to the picked Boki
const PLACEHOLDER_SKY := Color(0.55, 0.75, 0.95)      # headless frame colour
const NOTE_SECS := 4.0          # how long "saved to ..." replaces the key hints
const HINT_TEXT := "WASD pan   Q / E orbit   Tab pick a Boki   C caption   Enter photo   Esc leave"

var active := false
var focus := Vector3.ZERO       # what the camera looks at while the mode is on
var caption_on := false
var picked := -1                # index into home.kins, -1 = free camera
var bounds := Rect2()           # x/z extent of the land
var _level_before := 0
var _yaw_before := 0.0
var _layer: CanvasLayer
var _hint: Label
var _caption: Label
var _note_left := 0.0

## Turns the mode on or off.
func toggle(home: Node) -> void:
	if active:
		_leave(home)
	else:
		_enter(home)

## Every frame: pans, orbits and eases toward the picked Boki.
func tick(home: Node, dt: float) -> void:
	if not active:
		return
	var step := Input.get_vector("left", "right", "up", "down")
	home.cam.yaw_to += _turn_axis() * TURN_SPEED * dt
	if step != Vector2.ZERO:
		picked = -1
		var across: Vector3 = Vector3(step.x, 0, step.y).rotated(Vector3.UP, home.cam.yaw)
		focus += across * PAN_SPEED * home.cam.zoom * dt
	elif picked >= 0:
		var at: Vector3 = home.kins[picked]["pos"]
		focus = focus.lerp(at, 1.0 - exp(-FOLLOW_EASE * dt))
	focus = clamp_to_garden(focus)
	_refresh_labels(home, dt)

## Keys and clicks while the mode is on; true when the event was used.
func input(home: Node, event: InputEvent) -> bool:
	if not active:
		return false
	if event.is_action_pressed("photo") or event.is_action_pressed("menu"):
		_leave(home)
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit: int = home.kins.find(home.hover_k)
		if hit >= 0:
			picked = hit
		return true
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	match (event as InputEventKey).physical_keycode:
		KEY_TAB:
			pick_next(home, -1 if (event as InputEventKey).shift_pressed else 1)
		KEY_C:
			caption_on = not caption_on
		KEY_ENTER, KEY_KP_ENTER:
			take(home)
		_:
			return false
	return true

## Picks the next (dir 1) or previous (dir -1) Boki on the farm; the camera glides to it.
func pick_next(home: Node, dir: int) -> void:
	var count: int = home.kins.size()
	if count > 0:
		picked = posmod(picked + dir, count)

## The point nearest `p` that is on the land, kept EDGE_MARGIN inside the bounds.
func clamp_to_garden(p: Vector3) -> Vector3:
	var lo := bounds.position + Vector2.ONE * EDGE_MARGIN
	var hi := bounds.end - Vector2.ONE * EDGE_MARGIN
	return Vector3(clampf(p.x, lo.x, hi.x), p.y, clampf(p.z, lo.y, hi.y))

## The caption text for the picked Boki ("" with none picked): its name and its species.
func caption_text(home: Node) -> String:
	if picked < 0 or picked >= home.kins.size():
		return ""
	var rec: Dictionary = home.kins[picked]["rec"]
	return "%s the %s" % [rec["name"], Data.KIN[rec["species"]]["name"]]

## Saves what the camera sees (the hint line hidden) as a PNG; returns its path ("" if it could not be written).
func take(home: Node) -> String:
	_hint.visible = false
	await _drawn(home)
	var img := home.get_viewport().get_texture().get_image()
	_hint.visible = true
	if img == null or img.is_empty():
		img = _placeholder(home)
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := "%s/boki_%s.png" % [DIR, Time.get_datetime_string_from_system().replace(":", "-")]
	if img.save_png(path) != OK:
		return ""
	_hint.text = "Photo saved: %s" % ProjectSettings.globalize_path(path)
	_note_left = NOTE_SECS
	return path

## The newest saved photo's path, or "" when there is none.
static func latest() -> String:
	var newest := ""
	for file in DirAccess.get_files_at(DIR):
		if file.ends_with(".png") and file > newest:
			newest = file
	return "" if newest == "" else "%s/%s" % [DIR, newest]

## Waits until the frame has been drawn (a headless run never draws, so it waits one idle frame).
func _drawn(home: Node) -> void:
	if DisplayServer.get_name() == "headless":
		await home.get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw

## A headless run has nothing to draw, so it saves a flat sky-coloured frame of the window size: the folder,
## the file name and latest() still work. Real runs never use it.
func _placeholder(home: Node) -> Image:
	var dims := Vector2i(home.get_viewport().get_visible_rect().size)
	var img := Image.create(dims.x, dims.y, false, Image.FORMAT_RGB8)
	img.fill(PLACEHOLDER_SKY)
	return img

func _enter(home: Node) -> void:
	bounds = _land_bounds(home.world)
	focus = clamp_to_garden(Vector3(home.ppos.x, 0.0, home.ppos.z))
	picked = -1
	_level_before = Record.level
	_yaw_before = home.cam.yaw
	Record.set_level(2)
	_build_labels(home)
	active = true

func _leave(home: Node) -> void:
	active = false
	Record.set_level(_level_before)
	home.cam.yaw = _yaw_before
	home.cam.yaw_to = _yaw_before
	if _layer:
		_layer.queue_free()
		_layer = null

static func _turn_axis() -> float:
	return float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))

static func _land_bounds(world: World) -> Rect2:
	var lo := Vector2(world.w, world.h)
	var hi := Vector2.ZERO
	for i in world.island.size():
		if world.island[i] >= 0:
			lo = lo.min(Vector2(i % world.w, i / world.w))
			hi = hi.max(Vector2(i % world.w + 1, i / world.w + 1))
	return Rect2(lo, hi - lo)

func _build_labels(home: Node) -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	home.add_child(_layer)
	_hint = UI.label(HINT_TEXT, 14, Color(1, 1, 1, 0.8))
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 14)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_layer.add_child(_hint)
	_caption = UI.label("", 30, Color.WHITE, UI.big)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 56)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_layer.add_child(_caption)

func _refresh_labels(home: Node, dt: float) -> void:
	_note_left -= dt
	if _note_left <= 0.0:
		_hint.text = HINT_TEXT
	var text := caption_text(home) if caption_on else ""
	_caption.text = text
	_caption.visible = text != ""
