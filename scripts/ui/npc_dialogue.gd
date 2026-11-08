class_name NpcDialogue
extends Control
## The box any NPC talks through (content/rules/npc_talk.json): along the bottom of the screen, a large
## front-facing portrait framed in the line's mood colour, a name plate, and text that types out letter by
## letter with a voice blip every few letters, after a short '...' bubble. A click, a tap, interact or
## Enter finishes the line, then moves on; after the last line it emits `finished` (two frames later, so
## the same key press can't start the talk again). It covers the screen to catch clicks anywhere.

signal finished

const PORTRAIT_PX := 176         # px: the portrait's side on screen
const PORTRAIT_RENDER := 256     # px: the rendered close-up's side
const BOX_W := 860.0             # px: the box's width (it stays inside narrow windows)
const BOX_BOTTOM := 22.0         # px between the box and the bottom of the screen
const TEXT_SIZE := 19            # px: the spoken line
const BLIP_S := 0.05             # s: one voice blip
const BLIP_RATE := 22050         # Hz: the blip's sample rate
const BLIP_PITCH_VAR := 0.08     # each blip this much higher or lower, so a line doesn't drone

static var _blips: Dictionary = {}     # voice Hz -> AudioStreamWAV

var speaker_id := ""
var pages: Array = []            # [{text, mood}]
var page := -1
var shown := 0.0                 # letters typed so far on this page
var hold := 0.0                  # s the typing waits (after punctuation)
var dots_left := 0.0             # s of the '...' bubble left
var done_frame := -1             # the frame the last line was dismissed on
var _sp: Dictionary = {}
var _box: PanelContainer
var _frame: PanelContainer
var _portrait: TextureRect
var _render: SubViewport = null
var _text: Label
var _dots: Label
var _more: Label
var _choice: Button = null
var _voice: AudioStreamPlayer
var _letters := 0

static func rules() -> Dictionary:
	return Content.rules("npc_talk")

static func speaker(id: String) -> Dictionary:
	return rules()["speakers"][id]

## A box for `speaker_id` saying `lines` ([{text, mood}], mood one of npc_talk.json's moods). `model` is the
## speaker's node in the world; its front close-up stands in for a painted portrait until one lands.
static func make(id: String, lines: Array, model: Node3D) -> NpcDialogue:
	var d := NpcDialogue.new()
	d.speaker_id = id
	d.pages = lines
	d._sp = speaker(id)
	d._build(model)
	d.dots_left = float(rules()["dots_s"])
	d._show_page(0)
	return d

## A button on the last line (after it has typed out), as Hob's "Open the build menu".
func add_choice(text: String, on_press: Callable) -> void:
	_choice = UI.primary(text, on_press)
	_choice.visible = false
	_more.get_parent().add_child(_choice)

func is_typing() -> bool:
	return dots_left > 0.0 or int(shown) < _letters

func _ready() -> void:
	UI.pop_in(_box)

func _process(dt: float) -> void:
	if done_frame >= 0:
		if Engine.get_process_frames() > done_frame + 1:
			done_frame = -1
			finished.emit()
		return
	_more.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
	if dots_left > 0.0:
		dots_left -= dt
		_dots.text = ".".repeat(1 + int(Time.get_ticks_msec() / 220) % 3)
		_dots.visible = dots_left > 0.0
		return
	if hold > 0.0:
		hold -= dt
		return
	if int(shown) < _letters:
		_type(dt)
	var typed := int(shown) >= _letters
	_more.visible = typed and not (_choice and page == pages.size() - 1)
	if _choice:
		_choice.visible = typed and page == pages.size() - 1

## Click, tap, interact or Enter: finish typing the line, else go on to the next.
func advance() -> void:
	if done_frame >= 0:
		return
	if is_typing():
		dots_left = 0.0
		_dots.visible = false
		shown = _letters
		_text.visible_characters = -1
		return
	if page + 1 < pages.size():
		_show_page(page + 1)
		return
	done_frame = Engine.get_process_frames()

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	var click: bool = mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if click or (event is InputEventScreenTouch and event.pressed):
		advance()
		accept_event()

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ typing
func _type(dt: float) -> void:
	var before := int(shown)
	shown = minf(shown + dt * float(rules()["type_cps"]), _letters)
	var line := _text.text
	var pause: Dictionary = rules()["pause_s"]
	for i in range(before, int(shown)):
		var ch := line[i]
		if ch.strip_edges() != "" and not ch in ".,!?;:'\"-":
			_blip(i)
		if pause.has(ch) and i + 1 < _letters and line[i + 1] == " ":
			hold = float(pause[ch])
			shown = i + 1
			break
	_text.visible_characters = int(shown)

func _blip(i: int) -> void:
	if i % int(rules()["blip_every"]) != 0:
		return
	_voice.pitch_scale = 1.0 + randf_range(-BLIP_PITCH_VAR, BLIP_PITCH_VAR)
	_voice.play()

func _show_page(i: int) -> void:
	page = i
	var p: Dictionary = pages[i]
	_text.text = String(p["text"])
	_letters = _text.text.length()
	shown = 0.0
	hold = 0.0
	_text.visible_characters = 0
	_more.visible = false
	_set_mood(String(p.get("mood", "neutral")))

func _set_mood(mood: String) -> void:
	var moods: Dictionary = rules()["moods"]
	UI.set_card_border(_frame, Color(String(moods.get(mood, moods["neutral"]))), 3)
	var painted := String(_sp.get("portrait", "")).replace("{mood}", mood)
	if painted != "" and ResourceLoader.exists(painted):
		_portrait.texture = load(painted)
	elif _render:
		_portrait.texture = _render.get_texture()

# ------------------------------------------------------------------ building it
func _build(model: Node3D) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := UI.card(UI.SURFACE, 16, UI.R_PANEL)
	_box = box
	UI.set_card_border(box, Color(UI.GOLD, 0.45), 1)
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -BOX_BOTTOM
	box.custom_minimum_size.x = BOX_W
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var row := UI.hbox(18)
	box.add_child(row)
	row.add_child(_portrait_frame(model))
	row.add_child(_words())
	_voice = AudioStreamPlayer.new()
	_voice.bus = "SFX"
	_voice.volume_db = float(rules()["blip_db"])
	_voice.stream = _blip_stream(float(_sp["voice_hz"]))
	add_child(_voice)

func _portrait_frame(model: Node3D) -> PanelContainer:
	_frame = UI.card(Color(0.07, 0.06, 0.09, 1.0), 4)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_frame.add_child(_portrait)
	if model:
		_render = _close_up(model)
		add_child(_render)
	return _frame

func _words() -> VBoxContainer:
	var col := UI.vbox(8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var plate := UI.hbox(10)
	plate.add_child(UI.label(String(_sp["name"]), UI.T_HEAD + 3, UI.GOLD, UI.big))
	plate.add_child(UI.label(String(_sp.get("role", "")), UI.T_SMALL, UI.MUTED))
	col.add_child(plate)
	_text = UI.para("", TEXT_SIZE, UI.INK)
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size.y = 84
	col.add_child(_text)
	_dots = UI.label("...", TEXT_SIZE + 10, UI.MUTED, UI.big)
	_text.add_child(_dots)
	var foot := UI.hbox(10)
	foot.alignment = BoxContainer.ALIGNMENT_END
	_more = UI.label("▼", UI.T_BODY, UI.ACCENT)
	foot.add_child(_more)
	col.add_child(foot)
	return col

## A front close-up of the speaker, rendered once: a copy of the model (without its tags) in a world of
## its own, lit from the front. NPC models face -Z.
func _close_up(model: Node3D) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(PORTRAIT_RENDER, PORTRAIT_RENDER)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var copy := model.duplicate() as Node3D
	for tag in copy.find_children("*", "Label3D", true, false):
		tag.free()
	var beacon := copy.get_node_or_null(NpcBeacon.NODE_NAME)
	if beacon:
		beacon.free()
	copy.transform = Transform3D(Basis.from_scale(model.scale), Vector3.ZERO)
	vp.add_child(copy)
	var at := float(_sp["portrait_at"])
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, at + 0.15, -float(_sp["portrait_dist"]))
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, at, 0), Vector3.UP)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(160.0), 0)
	vp.add_child(sun)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.72, 0.8)
	cam.environment = env
	return vp

## A short soft voice blip at `hz` (a sine with a little third harmonic, falling off fast), made once per voice.
static func _blip_stream(hz: float) -> AudioStreamWAV:
	if _blips.has(hz):
		return _blips[hz]
	var n := int(BLIP_S * BLIP_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / BLIP_RATE
		var env := minf(1.0, t * 400.0) * exp(-t * 60.0)
		var v := (sin(TAU * hz * t) + 0.3 * sin(TAU * hz * 3.0 * t)) * env * 0.6
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = BLIP_RATE
	wav.data = data
	_blips[hz] = wav
	return wav
