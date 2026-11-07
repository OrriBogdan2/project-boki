class_name MaskMoment
extends Node
## Your first Relic, after you name your Boki and before the tutorial (no pick: Vex is the only one). An
## in-world beat on the hatch island: the camera frames you, one of the Empty, with your new Boki; the light
## goes down and Vex's Relic drifts out of the heart-crystal toward you, glowing and trailing motes; your Boki
## hops and looks up at it. "Put on the Relic" (the interact key): it lifts to your hollow face, flickers, a
## flash, and you are mostly Vex (Unmasked.blend). Then a short look at what Vex does (HunterViewer: her
## ability clips) and `finished` sends you on to the tutorial.
# "mask" in code = "Relic" in game, owner 2026-11-07

signal finished

const YOU_AT := Vector3(-0.45, 0.0, 1.0)
const BOKI_AT := Vector3(0.55, 0.0, 1.35)
const FROM_AT := Vector3(0.0, 2.6, -5.2)         # the heart-crystal in the broken arch
const HOVER := Vector3(0.55, -0.12, 0.6)          # m from your head: where the Relic waits, beside your face
const CAM_YOU := Vector3(0.15, 1.35, 4.6)        # framing you, the Boki and the Relic's path
const LOOK_YOU := Vector3(0.05, 1.0, 0.6)
const CAM_INTRO := Vector3(1.2, 1.35, 5.6)       # framing the new you on the left of the intro panel
const LOOK_INTRO := Vector3(1.15, 0.85, 0.9)
const BOKI_INTRO := Vector3(-1.25, 0.0, 1.45)     # your Boki at your side while you look at the clips
const DRIFT_S := 3.4                             # s the Relic takes to reach you
const DIM := 0.45                                # x the island's lights while the Relic comes
const CLIP := Vector2(250, 140)                  # px: each ability clip in the intro
const TEXT := "This Relic is the mask of a fallen Hero. Put it on, and you fight as that Hunter."
const BUTTON := "Put on the Relic"
const GO := "Into the portal"

var hunter_id := "gunslinger"
var host: Node3D                                 # the island scene (the hatch)
var cam: Camera3D
var kin: Node3D                                  # your new Boki
var you: Node3D
var relic: MaskRelic
var phase := ""                                  # arrive | wait | put | intro
var ui: CanvasLayer
var prompt: Control
var intro: Control
var flash: ColorRect
var go_button: Button
var _anim: HunterAnim
var _cam_to := CAM_YOU
var _look_to := LOOK_YOU
var _look := LOOK_YOU
var _lights: Array = []                          # [light, its own energy]
var _env: Environment
var _env_energy := Vector2.ONE                   # the island's ambient and sky energy before the dim
var _t := 0.0

static func make(scene: Node3D, camera: Camera3D, boki: Node3D, id := "gunslinger") -> MaskMoment:
	var m := MaskMoment.new()
	m.host = scene
	m.cam = camera
	m.kin = boki
	m.hunter_id = id
	return m

func _ready() -> void:
	you = Models.hunter(Data.class_of_save(), Data.TEAM_COLORS[0], "", "", Unmasked.worn())
	you.get_node("Rig/Torso/Aim/Gun").free()      # (empty-handed: the Relic brings the weapon)
	you.position = YOU_AT
	you.rotation.y = PI
	host.add_child(you)
	_anim = HunterAnim.new(you)
	if kin:
		var tw := create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(kin, "position", BOKI_AT, 0.8)
	for l in host.find_children("*", "Light3D", true, false):
		_lights.append([l, (l as Light3D).light_energy])
	for w in host.find_children("*", "WorldEnvironment", false, false):
		_env = (w as WorldEnvironment).environment
		_env_energy = Vector2(_env.ambient_light_energy, _env.background_energy_multiplier)
	_build_ui()
	_arrive()

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash)

## The light goes down and the Relic leaves the crystal, drifting to wait in front of your face.
func _arrive() -> void:
	phase = "arrive"
	relic = MaskRelic.make(hunter_id)
	relic.position = FROM_AT
	host.add_child(relic)
	relic.face_to = cam.position          # (it shows you its face as it comes)
	relic.drift_to(_head() + HOVER, DRIFT_S, 1.2).finished.connect(_wait)
	Sfx.play("whoosh", null, -10.0)
	get_tree().create_timer(DRIFT_S * 0.7).timeout.connect(_boki_looks)

## Your Boki sees it coming: it turns to it and hops twice.
func _boki_looks() -> void:
	if kin == null or not is_instance_valid(kin):
		return
	var tw := create_tween()
	var to := relic.global_position - kin.global_position
	tw.tween_property(kin, "rotation:y", atan2(to.x, to.z), 0.3).set_trans(Tween.TRANS_SINE)
	for k in 2:
		tw.tween_property(kin, "position:y", 0.22, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(kin, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Sfx.play("hover", null, -6.0)

func _wait() -> void:
	phase = "wait"
	var box := UI.vbox(12)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -170
	box.offset_bottom = -40
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := UI.title(TEXT, 24, UI.INK)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_constant_override("outline_size", 10)
	line.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.07))
	box.add_child(line)
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UI.keycap(Settings.key_cap("interact"), 16))
	var b := UI.primary(BUTTON, put_on, 260)
	b.set_meta("put_on", true)
	row.add_child(b)
	box.add_child(row)
	ui.add_child(box)
	prompt = box
	UI.pop_in(box)

func _unhandled_input(event: InputEvent) -> void:
	if phase == "wait" and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		put_on()
		get_viewport().set_input_as_handled()
	elif phase == "intro" and go_button and event.is_action_pressed("ui_accept"):
		_go()

## The put-on beat: the Relic lifts to your hollow face, flickers, a flash, and the Hunter settles in.
func put_on() -> void:
	if phase != "wait":
		return
	phase = "put"
	if prompt:
		prompt.queue_free()
	Sfx.play("whoosh")
	beat(relic, you, flash, func(model: Node3D):
		you = model
		_anim = HunterAnim.new(you)
		get_tree().create_timer(1.0).timeout.connect(_show_intro))

## The put-on beat on any body in the world (also the farm's second Relic): the relic flies to the face and
## settles on it, flickers like a ghostly face over yours, the screen flashes white, and `body` becomes the
## Hunter (about 90%: Unmasked.blend). done(new_model) gets the Hunter's model, standing where you stood. With
## `swap` off (the farm, where you stay yourself) the body stays and done gets it back.
static func beat(mask: MaskRelic, body: Node3D, white: ColorRect, done: Callable, swap := true) -> void:
	var head := (body.get_node("Rig/Torso/HeadPivot") as Node3D).global_position
	var front := -body.global_basis.z.normalized()
	mask.bobbing = false
	mask.face_to = head + front * 3.0
	var tw := mask.create_tween()
	tw.tween_property(mask, "global_position", head + front * 0.27 * body.scale.y, 0.45)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mask, "scale", Vector3.ONE * body.scale.y * 1.1, 0.45)
	for k in 4:
		tw.tween_callback(func(): mask.plate.visible = not mask.plate.visible)
		tw.tween_interval(0.07)
	tw.tween_callback(func():
		white.color.a = 0.85
		white.create_tween().tween_property(white, "color:a", 0.0, 0.6)
		Sfx.play("unlock")
		mask.queue_free()
		if not swap:
			done.call(body)
			return
		var hunter: String = mask.id
		var model := Models.hunter(Arch.weight(hunter), Data.TEAM_COLORS[0], Arch.signature(hunter), "",
				Unmasked.mask_look(), hunter)
		Unmasked.blend(model)
		var ring := model.get_node_or_null("TeamRing")
		if ring: (ring as Node3D).visible = false
		model.position = body.position
		model.rotation = body.rotation
		var settle := model.scale
		model.scale = settle * 1.08
		body.get_parent().add_child(model)
		body.queue_free()
		model.create_tween().tween_property(model, "scale", settle, 0.5)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		done.call(model))

## What Vex does: her ability clips beside her, and on to the tutorial.
func _show_intro() -> void:
	phase = "intro"
	_cam_to = CAM_INTRO
	_look_to = LOOK_INTRO
	if kin and is_instance_valid(kin):
		create_tween().tween_property(kin, "position", BOKI_INTRO, 0.9).set_trans(Tween.TRANS_SINE)
	var panel := HunterViewer.make(hunter_id, Vector2.ZERO, CLIP, 3)
	panel.set_meta("mask_intro", hunter_id)
	var col := UI.vbox(12)
	col.add_child(panel)
	go_button = UI.primary(GO, _go, 260)
	go_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(go_button)
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	holder.add_theme_constant_override("margin_right", 24)
	holder.add_theme_constant_override("margin_top", 20)
	holder.add_theme_constant_override("margin_bottom", 20)
	holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var center := CenterContainer.new()
	center.add_child(col)
	holder.add_child(center)
	ui.add_child(holder)
	intro = holder
	UI.pop_in(col)

func _go() -> void:
	if phase != "intro":
		return
	phase = "done"
	Sfx.play("click")
	finished.emit()

func _head() -> Vector3:
	return (you.get_node("Rig/Torso/HeadPivot") as Node3D).global_position

func _process(dt: float) -> void:
	_t += dt
	var k := 1.0 - exp(-2.0 * dt)
	cam.position = cam.position.lerp(_cam_to, k)
	_look = _look.lerp(_look_to, k)
	cam.look_at(_look)
	var dim := lerpf(1.0, DIM, clampf(_t / 1.5, 0.0, 1.0))
	for pair in _lights:
		var light := pair[0] as Light3D
		if is_instance_valid(light) and not light.get_parent() is MaskRelic:
			light.light_energy = float(pair[1]) * dim
	if _env:
		_env.ambient_light_energy = _env_energy.x * dim
		_env.background_energy_multiplier = _env_energy.y * lerpf(1.0, 0.6, 1.0 - dim)
		_env.adjustment_brightness = lerpf(1.0, 0.72, (1.0 - dim) / (1.0 - DIM))
	if is_instance_valid(you) and _anim:
		_anim.update(dt, {"fired": 99.0, "face": you.rotation.y, "grounded": true})
