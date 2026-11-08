class_name HobModel
extends Node3D
## Hob Brackenridge, the farm's builder, as a person (FarmHob places and drives him): a stocky, friendly builder
## in the game's toon style, built from shapes: rolled shirt sleeves, a leather apron, a tool belt with a hammer,
## a pouch and a folding rule, a flat cap with a pencil behind his ear, and a grey beard. Like the rest of the
## Empty his face is a few simple marks (eyes and brows, no nose). He faces -Z.
## Poses (pose): "idle" (breathing, a slow look around), "wave", "talk" (hand gestures), "point" (the right arm
## toward point_at), "hammer" (tapping with the hammer out). Over him: his name until you have talked to him,
## a "!" when he has something for you, and a speech bubble for calling out (shout).
## (No free character pack could be downloaded where this was made; the CC0 swap is in docs/DEBT.md.)

const HEIGHT := 1.0            # x the model's own size (about 1.8 m tall)
const SHIRT := Color("b8432c")
const TROUSERS := Color("3d3a48")
const APRON := Color("8a5a36")
const LEATHER := Color("4a3220")
const SKIN := Color("e3b48c")
const BEARD := Color("d8d4cc")
const CAP := Color("5b6a4a")
const WAVE_HZ := 2.2           # waves of the hand a second
const HAMMER_HZ := 1.6         # taps a second
const TURN_RATE := 6.0         # 1/s: how fast he turns to face someone
const SHOUT_S := 2.6           # s a called-out line stays over him

var pose := "idle"
var point_at := Vector3.INF    # world point the "point" pose aims at
var face_to := Vector3.INF     # world point he turns to face (INF: keeps his heading)
var tag: Label3D
var mark: Label3D
var bubble: Label3D
var _t := 0.0
var _shout_t := 0.0
var _torso: Node3D
var _head: Node3D
var _arm_r: Node3D
var _arm_l: Node3D
var _elbow_r: Node3D
var _elbow_l: Node3D
var _hammer: Node3D
var _belt_hammer: Node3D

func _init() -> void:
	name = "Hob"
	_build()

## Calls a line out over his head for a moment ("Hey! Over here!").
func shout(line: String) -> void:
	bubble.text = line
	bubble.visible = true
	_shout_t = SHOUT_S

func _process(dt: float) -> void:
	_t += dt
	_turn(dt)
	_animate()
	mark.position.y = 2.45 + sin(_t * 3.0) * 0.08
	if _shout_t > 0.0:
		_shout_t -= dt
		bubble.visible = _shout_t > 0.0
		tag.modulate.a = 0.0 if bubble.visible else 1.0      # (one line over him at a time)

func _turn(dt: float) -> void:
	if face_to.x == INF:
		return
	var d := face_to - global_position
	if Vector2(d.x, d.z).length() < 0.1:
		return
	var want := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-TURN_RATE * dt))

# ------------------------------------------------------------------ poses
func _animate() -> void:
	var breathe := sin(_t * 1.6)
	_torso.scale = Vector3(1.0, 1.0 + 0.012 * breathe, 1.0 + 0.02 * breathe)
	_head.rotation = Vector3(0.0, 0.25 * sin(_t * 0.35), 0.0)
	_arm_r.rotation = Vector3(0.0, 0.0, 0.12)
	_arm_l.rotation = Vector3(0.0, 0.0, -0.12)
	_elbow_r.rotation = Vector3(0.25, 0.0, 0.0)
	_elbow_l.rotation = Vector3(0.25, 0.0, 0.0)
	_hammer.visible = pose == "hammer"
	_belt_hammer.visible = pose != "hammer"
	match pose:
		"wave":
			_arm_r.rotation = Vector3(0.0, 0.0, 2.6)
			_elbow_r.rotation = Vector3(0.0, 0.0, 0.45 * sin(_t * TAU * WAVE_HZ))
			_head.rotation.z = 0.08 * sin(_t * TAU * WAVE_HZ * 0.5)
		"talk":
			var g := sin(_t * 3.4)
			_arm_r.rotation = Vector3(0.5 + 0.25 * g, 0.0, 0.25)
			_elbow_r.rotation = Vector3(0.9 + 0.3 * g, 0.0, 0.0)
			_arm_l.rotation = Vector3(0.3 - 0.15 * g, 0.0, -0.2)
			_elbow_l.rotation = Vector3(0.7, 0.0, 0.0)
			_head.rotation = Vector3(0.06 * sin(_t * 5.0), 0.0, 0.0)
		"point":
			_aim_arm()
		"hammer":
			var k := maxf(0.0, sin(_t * TAU * HAMMER_HZ))
			_arm_r.rotation = Vector3(1.4 - 0.9 * k, 0.0, 0.1)
			_elbow_r.rotation = Vector3(0.6 - 0.5 * k, 0.0, 0.0)
			_head.rotation.x = 0.25

## The right arm straight out toward point_at.
func _aim_arm() -> void:
	if point_at.x == INF:
		return
	var dir := _torso.to_local(point_at) - _arm_r.position
	if dir.length() > 0.01:
		_arm_r.quaternion = Quaternion(Vector3.DOWN, dir.normalized())
	_elbow_r.rotation = Vector3.ZERO

# ------------------------------------------------------------------ the model
func _build() -> void:
	var cloth := Models.toon(SHIRT)
	var dark := Models.toon(TROUSERS)
	var leather := Models.toon(LEATHER)
	var skin := Models.toon(SKIN)
	for sx in [-1.0, 1.0]:
		Models.part(self, Models.cyl(0.1, 0.09, 0.72), dark, Vector3(0.13 * sx, 0.38, 0.0))
		Models.part(self, Models.box(0.17, 0.12, 0.28), leather, Vector3(0.13 * sx, 0.06, -0.04))
	_torso = Node3D.new()
	_torso.position = Vector3(0.0, 0.74, 0.0)
	add_child(_torso)
	Models.part(_torso, Models.sphere(0.36, 18), cloth, Vector3(0.0, 0.34, 0.0), Vector3(1.05, 1.05, 0.82))
	Models.part(_torso, Models.cyl(0.3, 0.33, 0.3), cloth, Vector3(0.0, 0.16, 0.0), Vector3(1.0, 1.0, 0.85))
	_apron(_torso)
	_belt(_torso)
	_head = _make_head(_torso)
	_arm_r = _make_arm(_torso, 1.0)
	_arm_l = _make_arm(_torso, -1.0)
	_elbow_r = _arm_r.get_child(_arm_r.get_child_count() - 1)
	_elbow_l = _arm_l.get_child(_arm_l.get_child_count() - 1)
	_hammer = _make_hammer()
	_hammer.position = Vector3(0.0, -0.3, -0.04)
	_hammer.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_elbow_r.add_child(_hammer)
	_labels()

func _apron(torso: Node3D) -> void:
	var apron := Models.toon(APRON)
	Models.part(torso, Models.box(0.46, 0.62, 0.04), apron, Vector3(0.0, 0.08, -0.29))
	Models.part(torso, Models.box(0.3, 0.2, 0.04), apron, Vector3(0.0, 0.44, -0.3))
	Models.part(torso, Models.box(0.18, 0.12, 0.03), Models.toon(APRON.darkened(0.25)), Vector3(0.08, 0.16, -0.32))
	for sx in [-1.0, 1.0]:      # the neck straps
		Models.part(torso, Models.box(0.04, 0.32, 0.04), apron, Vector3(0.11 * sx, 0.6, -0.2), Vector3.ONE,
				Vector3(-0.5, 0.0, 0.0))

func _belt(torso: Node3D) -> void:
	var leather := Models.toon(LEATHER)
	Models.part(torso, Models.cyl(0.35, 0.35, 0.09), leather, Vector3(0.0, 0.02, 0.0), Vector3(1.0, 1.0, 0.86))
	Models.part(torso, Models.box(0.09, 0.08, 0.03), Models.shiny(Color("c9a24a"), 0.7), Vector3(0.0, 0.02, -0.31))
	Models.part(torso, Models.box(0.14, 0.16, 0.1), leather, Vector3(-0.28, -0.06, -0.12))      # the pouch
	Models.part(torso, Models.box(0.05, 0.22, 0.03), Models.toon(Color("e2c25a")), Vector3(-0.32, -0.04, 0.12))
	_belt_hammer = _make_hammer()
	_belt_hammer.position = Vector3(0.33, -0.12, -0.02)
	torso.add_child(_belt_hammer)

func _make_hammer() -> Node3D:
	var h := Node3D.new()
	Models.part(h, Models.cyl(0.02, 0.022, 0.34), Models.toon(Color("8a6238")), Vector3(0.0, -0.1, 0.0))
	Models.part(h, Models.box(0.06, 0.07, 0.17), Models.shiny(Color("8a8f98"), 0.6), Vector3(0.0, 0.07, 0.0))
	return h

func _make_head(torso: Node3D) -> Node3D:
	var head := Node3D.new()
	head.position = Vector3(0.0, 0.72, 0.0)
	torso.add_child(head)
	var skin := Models.toon(SKIN)
	var beard := Models.toon(BEARD)
	var ink := Models.toon(Color("2b2230"), false)
	Models.part(head, Models.cyl(0.09, 0.1, 0.12), skin, Vector3(0.0, -0.04, 0.0))
	Models.part(head, Models.sphere(0.2, 18), skin, Vector3(0.0, 0.16, 0.0), Vector3(1.0, 1.05, 0.98))
	Models.part(head, Models.sphere(0.17, 16), beard, Vector3(0.0, 0.04, -0.09), Vector3(1.15, 0.9, 0.8))
	Models.part(head, Models.box(0.2, 0.04, 0.05), beard, Vector3(0.0, 0.1, -0.19))      # the moustache
	for sx in [-1.0, 1.0]:
		Models.part(head, Models.sphere(0.026, 10), ink, Vector3(0.075 * sx, 0.2, -0.185), Vector3(1.0, 1.25, 0.5))
		Models.part(head, Models.box(0.07, 0.018, 0.02), Models.toon(BEARD.darkened(0.2), false),
				Vector3(0.075 * sx, 0.26, -0.18), Vector3.ONE, Vector3(0.0, 0.0, -0.15 * sx))
		Models.part(head, Models.sphere(0.045, 10), skin, Vector3(0.2 * sx, 0.16, 0.0), Vector3(0.5, 1.0, 0.8))
	var cap := Models.toon(CAP)
	Models.part(head, Models.cyl(0.2, 0.215, 0.09), cap, Vector3(0.0, 0.33, 0.01))
	Models.part(head, Models.box(0.3, 0.025, 0.14), cap, Vector3(0.0, 0.3, -0.2), Vector3.ONE, Vector3(0.18, 0.0, 0.0))
	var pencil := Node3D.new()      # behind his right ear
	pencil.position = Vector3(0.215, 0.24, 0.02)
	pencil.rotation = Vector3(0.5, 0.0, 0.35)
	head.add_child(pencil)
	Models.part(pencil, Models.cyl(0.012, 0.012, 0.16, 6), Models.toon(Color("f0c33c")), Vector3.ZERO)
	var wood := Models.toon(Color("e8cfa0"), false)
	Models.part(pencil, Models.cyl(0.004, 0.012, 0.03, 6), wood, Vector3(0.0, -0.095, 0.0),
			Vector3.ONE, Vector3(PI, 0.0, 0.0))
	Models.part(pencil, Models.cyl(0.012, 0.012, 0.02, 6), Models.toon(Color("e58a9a"), false), Vector3(0.0, 0.09, 0.0))
	return head

## An arm hanging from its shoulder: the shirt sleeve rolled up to a cuff, the forearm and hand on an elbow pivot.
func _make_arm(torso: Node3D, side: float) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(0.38 * side, 0.52, 0.0)
	torso.add_child(shoulder)
	var cloth := Models.toon(SHIRT)
	var skin := Models.toon(SKIN)
	Models.part(shoulder, Models.sphere(0.12, 12), cloth, Vector3.ZERO)
	Models.part(shoulder, Models.cyl(0.09, 0.085, 0.24), cloth, Vector3(0.0, -0.13, 0.0))
	Models.part(shoulder, Models.cyl(0.1, 0.1, 0.06), Models.toon(SHIRT.lightened(0.15)), Vector3(0.0, -0.25, 0.0))
	var elbow := Node3D.new()
	elbow.position = Vector3(0.0, -0.27, 0.0)
	shoulder.add_child(elbow)
	Models.part(elbow, Models.cyl(0.075, 0.065, 0.24), skin, Vector3(0.0, -0.12, 0.0))
	Models.part(elbow, Models.sphere(0.075, 12), skin, Vector3(0.0, -0.27, 0.0), Vector3(1.0, 1.1, 0.9))
	return shoulder

func _labels() -> void:
	tag = _label(FarmBuilder.full_name(), 40, Color.WHITE)
	tag.position = Vector3(0.0, 2.15, 0.0)
	mark = _label("!", 90, UI.GOLD)
	mark.visible = false
	bubble = _label("", 44, Color("fff4d8"))
	bubble.position = Vector3(0.0, 2.75, 0.0)
	bubble.visible = false

func _label(text: String, px: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = px
	l.pixel_size = 0.0085
	l.outline_size = 14
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	return l

# ------------------------------------------------------------------ his portrait
## His face for the talk box: a TextureRect drawn once from the model (its SubViewport rides as its child).
static func portrait(px: float) -> TextureRect:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(px * 2.0), int(px * 2.0))
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8a93b8")
	env.environment.ambient_light_energy = 0.9
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, 160, 0)
	key.light_energy = 1.2
	vp.add_child(key)
	var hob := HobModel.new()
	hob.set_process(false)
	vp.add_child(hob)
	hob.tag.visible = false
	var cam := Camera3D.new()
	cam.fov = 24.0
	vp.add_child(cam)
	var face := Vector3(0.0, 1.6, 0.0)
	cam.transform = Transform3D(Basis(), face + Vector3(-0.35, 0.05, -1.45)).looking_at(face + Vector3(0, -0.04, 0))
	cam.current = true
	var tex := TextureRect.new()
	tex.texture = vp.get_texture()
	tex.custom_minimum_size = Vector2(px, px)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.add_child(vp)
	return tex
