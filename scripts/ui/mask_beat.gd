class_name MaskBeat
extends Node
## Putting on a Mask, staged as a short cinematic (the put-on beat in briefs/LORE_MASKS.md; times, whispers and
## each Hunter's sting key in content/rules/mask_moment.json):
##   1. build-up: the music ducks and the ambience fades, the camera eases in on you, a low swell and a heartbeat
##   2. the Mask rises to your face in slow motion while a ghostly porcelain face flickers over yours
##   3. a cut to black on contact, and a hard silence
##   4. flashes of the fallen Hunter (their painted art) and a whisper of their line, in the black
##   5. the snap back: a deep impact, a ripple of light and a small camera push (no shake); with `swap` you stand
##      as the Hunter (Unmasked.blend) in a brief pose; their name and title on screen
##   6. the music comes back under a sting in the Hunter's key
## It plays through its own camera (the scene's own is current again after). Once a player has seen one
## (Save.d.tutorial.mask_seen) interact or Esc skips it. `done` gets the body standing there at the end: the
## Hunter's model with `swap`, else the body you had (on the farm you stay yourself). `short` is the quicker
## cut for a later Mask.
##
##   MaskBeat.play(relic, you, func(body): ..., true)

signal finished(body: Node3D)

const RULES := "mask_moment"
const FACE_GAP := 0.27         # m in front of the head where the Mask settles (times the body's scale)
const CAM_BACK := 1.55         # m in front of the face the camera eases toward
const RIPPLE_M := 7.0          # m: how far the ripple of light runs out over the ground
const RIPPLE_S := 0.9          # s it takes
const POSE_S := 0.6            # s: the Hunter's cast pose (HunterAnim's "ult" cast)
const NAME_IN_S := 0.35        # s after the snap that the name comes in
const STING_AT_S := 0.25       # s after the snap that the sting starts
const HAND_BACK_S := 0.5       # s at the end that the camera eases back to the scene's own
const SOUNDS := {               # our own (tools/gen_mask_sfx.py), loaded with the script so the beat starts at once
	"mask_swell": preload("res://audio/mask_swell.wav"),
	"mask_heart": preload("res://audio/mask_heart.wav"),
	"mask_whisper": preload("res://audio/mask_whisper.wav"),
	"mask_impact": preload("res://audio/mask_impact.wav"),
	"mask_sting": preload("res://audio/mask_sting.wav"),
}

var id := ""
var mask: MaskRelic
var body: Node3D
var swap := true
var short := false
var phase := "build"           # build | rise | black | memory | reveal | done
var t := 0.0                   # s into this phase
var cam: Camera3D
var ui: CanvasLayer
var black: ColorRect
var white: ColorRect
var memory: TextureRect
var whisper_line: Label
var name_box: Control
var skip_hint: Control
var _times: Dictionary
var _rules: Dictionary
var _was_cam: Camera3D
var _from: Transform3D         # the scene camera where the beat took over
var _close: Transform3D        # the push-in framing on the face
var _look_from := Vector3.ZERO  # where the scene camera was looking, at the face's distance
var _head := Vector3.ZERO
var _front := Vector3.FORWARD
var _mask_from := Vector3.ZERO
var _ghost: MeshInstance3D
var _ripple: MeshInstance3D
var _swell: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _heart_i := 0
var _heart_wait := 0.0
var _anim: HunterAnim
var _memory_i := -1
var _amb_db := 0.0
var _fov := 70.0

static func play(relic: MaskRelic, who: Node3D, done: Callable, swap_body := true, quick := false) -> MaskBeat:
	var b := MaskBeat.new()
	b.mask = relic
	b.id = relic.id
	b.body = who
	b.swap = swap_body
	b.short = quick
	b.finished.connect(done)
	who.get_parent().add_child(b)
	return b

## Whether the player has seen a Mask go on before (then the beat can be skipped).
static func seen() -> bool:
	return bool(Save.d.get("tutorial", {}).get("mask_seen", false))

func _ready() -> void:
	_rules = Content.rules(RULES)
	_times = _rules["short" if short else "full"]
	_head = (body.get_node("Rig/Torso/HeadPivot") as Node3D).global_position
	_front = Vector3(-body.global_basis.z.x, 0.0, -body.global_basis.z.z).normalized()      # (the farm leans you)
	_mask_from = mask.global_position
	mask.bobbing = false
	mask.face_to = _head + _front * 3.0
	_take_camera()
	_build_ui()
	_quiet()
	Portraits.read_soon(Portraits.art_path(id, true))      # (the memory frames, read while the build-up plays)
	Portraits.read_soon(Portraits.art_path(id))
	WardenGlb.fetch(id)
	_swell = _player("mask_swell", -6.0)
	_heart = _player("mask_heart", -2.0)
	_swell.play()

func _take_camera() -> void:
	_was_cam = get_viewport().get_camera_3d()
	cam = Camera3D.new()
	_from = _was_cam.global_transform if _was_cam else Transform3D(Basis(), _head + _front * 4.0)
	_fov = _was_cam.fov if _was_cam else 60.0
	cam.fov = _fov
	add_child(cam)
	cam.global_transform = _from
	cam.current = true
	var eye := _head + _front * CAM_BACK * body.scale.y + Vector3.UP * 0.08
	_close = Transform3D(Basis(), eye).looking_at(_head, Vector3.UP)
	_look_from = _from.origin - _from.basis.z * _from.origin.distance_to(_head)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 70
	add_child(ui)
	memory = TextureRect.new()
	memory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	memory.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	memory.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	memory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	memory.material = _memory_look()
	black = _cover(Color(0, 0, 0, 0))
	ui.add_child(black)
	ui.add_child(memory)
	memory.visible = false
	white = _cover(Color(1, 1, 1, 0))
	ui.add_child(white)
	whisper_line = UI.label("", 26, Color(0.92, 0.9, 0.98), UI.semi)
	whisper_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	whisper_line.grow_horizontal = Control.GROW_DIRECTION_BOTH
	whisper_line.offset_top = -120
	whisper_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	whisper_line.modulate.a = 0.0
	whisper_line.add_theme_constant_override("outline_size", 10)
	whisper_line.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.04))
	ui.add_child(whisper_line)
	if seen():
		var key := Settings.key_cap("interact")
		skip_hint = UI.label("%s  Skip" % key, 13, Color(1, 1, 1, 0.55))
		skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		skip_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		skip_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
		skip_hint.offset_right = -24
		skip_hint.offset_bottom = -18
		ui.add_child(skip_hint)

func _cover(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## A memory frame's look: the painted art drained of colour and washed in the Hunter's, dark at the edges.
func _memory_look() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 tint : source_color;
uniform float dark = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	vec3 col = mix(vec3(l), tint.rgb * (l * 1.4 + 0.1), 0.55);
	float edge = smoothstep(0.75, 0.25, distance(UV, vec2(0.5)));
	col *= mix(0.25, 1.0, edge) * (1.0 - dark);
	COLOR = vec4(col, c.a);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", Arch.color(id))
	return m

## The world goes quiet: the music ducks for the whole beat, the ambience fades (its bus comes back at the end).
func _quiet() -> void:
	var total := float(_times["build_s"]) + float(_times["rise_s"]) + float(_times["black_s"])
	for s in _times["memory_s"]:
		total += float(s)
	Sfx.duck(total, float(_rules["music_duck_db"]))
	var amb := AudioServer.get_bus_index("Ambience")
	if amb >= 0:
		_amb_db = AudioServer.get_bus_volume_db(amb)
		create_tween().tween_method(func(v: float): AudioServer.set_bus_volume_db(amb, v), _amb_db, -40.0, 0.8)

func _player(sound: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = SOUNDS[sound]
	p.volume_db = db
	add_child(p)
	return p

# ------------------------------------------------------------------ the beat
func _process(dt: float) -> void:
	t += dt
	match phase:
		"build":
			_build_up(dt)
		"rise":
			_rise(dt)
		"black":
			if t >= float(_times["black_s"]):
				_next("memory")
		"memory":
			_memories()
		"reveal":
			_reveal(dt)

func _next(to: String) -> void:
	phase = to
	t = 0.0

func _build_up(dt: float) -> void:
	var k := clampf(t / float(_times["build_s"]), 0.0, 1.0)
	_ease_camera(smoothstep(0.0, 1.0, k) * float(_times["push_in"]) * 0.6)
	_heartbeat(dt)
	if k >= 1.0:
		_next("rise")

## The heartbeat: its beats come closer together as the Mask nears (heart_gaps_s, then the last gap again).
func _heartbeat(dt: float) -> void:
	_heart_wait -= dt
	if _heart_wait > 0.0:
		return
	var gaps: Array = _rules["heart_gaps_s"]
	_heart_wait = float(gaps[mini(_heart_i, gaps.size() - 1)])
	_heart_i += 1
	_heart.play()

## The Mask lifts to the face, slowly, and the ghost of a porcelain face flickers over yours.
func _rise(dt: float) -> void:
	var k := clampf(t / float(_times["rise_s"]), 0.0, 1.0)
	var e := 0.5 - 0.5 * cos(PI * k)
	var settle := _head + _front * FACE_GAP * body.scale.y
	mask.global_position = _mask_from.lerp(settle, e) + Vector3.UP * sin(PI * e) * 0.15
	mask.scale = Vector3.ONE * lerpf(MaskRelic.FLOAT_SCALE, body.scale.y * 1.1, e)
	_ease_camera(lerpf(0.6, 1.0, e) * float(_times["push_in"]))
	_heartbeat(dt)
	if k > 0.4:
		_flicker_ghost(k)
	if k >= 1.0:
		_contact()

func _flicker_ghost(k: float) -> void:
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.mesh = MaskRelic.plate_mesh()
		_ghost.material_override = Models.glow_mat(Color(0.97, 0.95, 0.9, 0.0))
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.get_parent().add_child(_ghost)
		var turn := Basis.looking_at(_front, Vector3.UP).scaled(Vector3.ONE * body.scale.y * 1.05)
		_ghost.global_transform = Transform3D(turn,
				_head + _front * 0.12 * body.scale.y)
	var on := randf() < lerpf(0.3, 0.75, k)
	var a := (0.18 + 0.35 * k) if on else 0.04
	(_ghost.material_override as ShaderMaterial).set_shader_parameter("color", Color(0.97, 0.95, 0.9, a))

## Contact: black and silence. The Hunter's model is built now, behind the black (a slow frame nobody sees).
func _contact() -> void:
	_next("black")
	black.color.a = 1.0
	_swell.stop()
	_heart.stop()
	Sfx.duck(float(_times["black_s"]) + 0.6, -60.0)
	if is_instance_valid(mask):
		mask.queue_free()
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	if swap:
		_become_hunter()

func _become_hunter() -> void:
	var model := PreviewBuild.model(id)
	Unmasked.blend(model)
	model.position = body.position
	model.rotation = body.rotation
	body.get_parent().add_child(model)
	body.queue_free()
	body = model
	_anim = HunterAnim.new(model)

## The fallen Hunter in the black: a few quick frames of their painted art, and their whisper.
func _memories() -> void:
	var lens: Array = _times["memory_s"]
	var at := 0.0
	var i := 0
	while i < lens.size() and t >= at + float(lens[i]):
		at += float(lens[i])
		i += 1
	if i >= lens.size():
		_snap_back()
		return
	if i != _memory_i:
		_memory_i = i
		_show_memory(i)
	var k := (t - at) / float(lens[i])
	memory.scale = Vector2.ONE * (1.04 + 0.05 * k)
	memory.modulate.a = minf(1.0, k * 6.0) * (1.0 - smoothstep(0.8, 1.0, k))

func _show_memory(i: int) -> void:
	var splash := i != 1
	var path := Portraits.art_path(id, splash)
	var tex := Portraits.read_soon(path)
	memory.texture = tex if tex else load(path) as Texture2D
	memory.visible = true
	memory.pivot_offset = memory.size * 0.5
	(memory.material as ShaderMaterial).set_shader_parameter("dark", 0.45 if i == 2 else 0.0)
	if i == 0:
		var p := _player("mask_whisper", -4.0)
		p.play()
		whisper_line.text = String((_rules["whispers"] as Dictionary).get(id, ""))
		create_tween().tween_property(whisper_line, "modulate:a", 0.85, 0.2)

## Back in the world, all at once: the impact, a flash and a ripple of light, the camera pushed in a little.
func _snap_back() -> void:
	_next("reveal")
	memory.visible = false
	whisper_line.visible = false
	black.color.a = 0.0
	white.color.a = 0.8
	create_tween().tween_property(white, "color:a", 0.0, 0.5)
	_player("mask_impact", 0.0).play()
	_ripple = MeshInstance3D.new()
	_ripple.mesh = Models.flat_quad(1.0)
	_ripple.material_override = Models.ring_mat(Arch.color(id).lightened(0.3), 0.06)
	body.get_parent().add_child(_ripple)
	_ripple.global_position = Vector3(body.global_position.x, body.global_position.y + 0.05, body.global_position.z)
	_restore_ambience()

func _reveal(dt: float) -> void:
	var k := clampf(t / RIPPLE_S, 0.0, 1.0)
	if is_instance_valid(_ripple):
		_ripple.scale = Vector3.ONE * (0.5 + RIPPLE_M * 2.0 * (1.0 - pow(1.0 - k, 3.0)))
		var col := Color(Arch.color(id).lightened(0.3), 1.0 - k)
		(_ripple.material_override as ShaderMaterial).set_shader_parameter("color", col)
	var punch := float(_rules["punch_fov"]) * (1.0 - smoothstep(0.0, 0.5, t))
	cam.fov = _fov - punch
	_ease_camera(float(_times["push_in"]) * lerpf(1.0, 0.7, smoothstep(0.0, 0.8, t)))
	var back := smoothstep(float(_times["reveal_s"]) - HAND_BACK_S, float(_times["reveal_s"]), t)
	if back > 0.0 and is_instance_valid(_was_cam):
		cam.global_transform = cam.global_transform.interpolate_with(_was_cam.global_transform, back)
	if _anim and is_instance_valid(body):
		_anim.update(dt, {"fired": 99.0, "face": body.rotation.y, "grounded": true, "wid": Arch.signature(id),
				"cast_slot": "ult", "cast": t if t < POSE_S else 99.0})
	if name_box == null and t >= NAME_IN_S:
		_show_name()
	if t - dt < STING_AT_S and t >= STING_AT_S:
		var semis := float((_rules["sting_semitones"] as Dictionary).get(id, 0))
		var sting := _player("mask_sting", -2.0)
		sting.pitch_scale = pow(2.0, semis / 12.0)
		sting.play()
	if t >= float(_times["reveal_s"]):
		_finish()

## "Vex, the Hired Gun" across the lower screen, in the Hunter's colour.
func _show_name() -> void:
	name_box = UI.vbox(0)
	name_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	name_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	name_box.offset_top = -170
	name_box.set_meta("mask_name", id)
	var nm := UI.title(HunterViewer.display_name(id), 46, Arch.color(id).lightened(0.15))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_constant_override("outline_size", 12)
	nm.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.06))
	name_box.add_child(nm)
	ui.add_child(name_box)
	UI.pop_in(name_box)

## The camera k of the way from where the scene had it to the face, always looking at what it moves toward.
func _ease_camera(k: float) -> void:
	var c := clampf(k, 0.0, 1.0)
	var eye := _from.origin.lerp(_close.origin, c)
	cam.global_transform = Transform3D(Basis(), eye).looking_at(_look_from.lerp(_head, c), Vector3.UP)

func _restore_ambience() -> void:
	var amb := AudioServer.get_bus_index("Ambience")
	if amb >= 0:
		var from := AudioServer.get_bus_volume_db(amb)
		create_tween().tween_method(func(v: float): AudioServer.set_bus_volume_db(amb, v), from, _amb_db, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	var skip := event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")
	if skip and seen() and phase != "done":
		get_viewport().set_input_as_handled()
		skip_now()

## Jumps to the end (the Hunter on, the scene's camera back).
func skip_now() -> void:
	if phase in ["build", "rise"]:
		_contact()
	if phase != "reveal":
		_snap_back()
	_finish()

func _finish() -> void:
	if phase == "done":
		return
	phase = "done"
	Save.d["tutorial"]["mask_seen"] = true
	if is_instance_valid(_ripple):
		_ripple.queue_free()
	if _was_cam and is_instance_valid(_was_cam):
		_was_cam.current = true
	finished.emit(body)
	queue_free()
