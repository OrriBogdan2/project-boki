class_name MergeLook
extends Node3D
## The form a merged hunter wears (MergeForm): the model itself grows into the form's silhouette (scale pops in with an
## ease-out-back overshoot), the Boki's colour wraps it as a glow with a ground ring in the form's colour and a few motes,
## and silhouette parts ride the torso (MergeParts). One node under the hunter while merged; other games build it from the
## net state (KinNet). Separation reverses it: peel() shrinks it back over PEEL_S and frees it.

const NODE_NAME := "MergeLook"
const PARTS_NAME := "MergeParts"   # the silhouette parts ride the torso in this container, freed with the look
const POP_S := 0.28                # s: the silhouette pops in
const PEEL_S := 0.25               # s: and peels off
const OVERSHOOT := 1.70158
static var WASH: Shader = preload("res://shaders/merge_wash.gdshader")         # ease-out-back
var h: Hunter = null
var form: Dictionary = {}
var rec: Dictionary = {}
var _ring: MeshInstance3D = null
var _aura: MeshInstance3D = null
var _box: Node3D = null
var _t := 0.0
var _pop_t := 99.0
var _leave := -1.0                 # >= 0 while peeling
var _crack := 0.0                  # seconds of cracking left (a Shatter tell)
var _base_scale := Vector3.ONE
var _model: Node3D = null
var _wash: Array = []              # the meshes wearing the colour wash (an overlay material, removed with the look)

static func attach(hunter: Hunter, f: Dictionary, pop := false) -> void:
	detach(hunter)
	if hunter == null or f.is_empty():
		return
	var ml := MergeLook.new()
	ml.name = NODE_NAME
	ml.h = hunter
	ml.form = f
	hunter.add_child(ml)
	ml.build()
	ml._pop_t = 0.0 if pop else POP_S

## Gone at once (a new match, a respawn, a model swap).
static func detach(hunter: Hunter) -> void:
	if hunter == null:
		return
	var old := hunter.get_node_or_null(NODE_NAME)
	if old:
		hunter.remove_child(old)
		(old as MergeLook)._restore()
		old.queue_free()
	else:
		_free_orphan_parts(hunter)

## The merge ended: the look shrinks back and peels away (a beat), then frees itself.
static func peel(hunter: Hunter) -> void:
	var old := hunter.get_node_or_null(NODE_NAME) as MergeLook
	if old == null:
		return
	old.name = "MergeLookLeaving"       # (so a new merge never finds it)
	if old._box != null:
		old._box.name = "MergePartsLeaving"
	old._leave = 0.0

## The Shatter tell: the shell flickers and shakes for `secs`.
static func crackle(hunter: Hunter, secs: float) -> void:
	var ml := hunter.get_node_or_null(NODE_NAME) as MergeLook
	if ml:
		ml._crack = secs

func _parts_box() -> Node3D:
	var torso: Node3D = h.model.get_node_or_null("Rig/Torso") if h and h.model else null
	return (torso.get_node_or_null(PARTS_NAME) if torso else null) as Node3D

static func _free_orphan_parts(hunter: Hunter) -> void:
	var torso: Node3D = hunter.model.get_node_or_null("Rig/Torso") if hunter.model else null
	var box := torso.get_node_or_null(PARTS_NAME) if torso else null
	if box:
		torso.remove_child(box)
		box.queue_free()

func _restore() -> void:
	for pr in _wash:
		if is_instance_valid(pr[0]):
			(pr[0] as MeshInstance3D).material_overlay = pr[1]          # (back to whatever it wore: the outline)
	_wash.clear()
	if _model != null and is_instance_valid(_model):
		_model.scale = _base_scale
	if _box != null and is_instance_valid(_box):
		var p := _box.get_parent()
		if p:
			p.remove_child(_box)
		_box.queue_free()
		_box = null

func build() -> void:
	var glow: Color = form["glow"]
	var sz := float(form["size"])
	_model = h.model
	if _model != null:
		_base_scale = _model.get_meta("merge_base_scale", _model.scale)
		_model.set_meta("merge_base_scale", _base_scale)
		_wash_model(_model, glow)
	_aura = Models.part(self, Models.capsule(0.62, 2.0), Models.aura_mat(glow, 0.7), Vector3(0, 1.0 * sz, 0), Vector3.ONE * sz, Vector3.ZERO, "Aura")
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring = Models.part(self, Models.flat_quad(float(form.get("ring", 3.0))), Models.ring_mat(Color(glow, 1.0), 0.12), Vector3(0, 0.06, 0))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.top_level = true
	var mote := CPUParticles3D.new()
	mote.amount = 14
	mote.lifetime = 0.9
	mote.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mote.emission_sphere_radius = 0.5 * sz
	mote.direction = Vector3.UP
	mote.spread = 20.0
	mote.gravity = Vector3(0, 1.2, 0)
	mote.initial_velocity_min = 0.3
	mote.initial_velocity_max = 0.8
	mote.mesh = Models.sphere(0.04, 6)
	mote.material_override = Models.glow_mat(glow)
	mote.position = Vector3(0, 1.0 * sz, 0)
	add_child(mote)
	var torso: Node3D = h.model.get_node_or_null("Rig/Torso") if h.model else null
	var parent: Node3D = self
	if torso:
		var old := torso.get_node_or_null(PARTS_NAME)
		if old:
			old.free()
		parent = Node3D.new()
		parent.name = PARTS_NAME
		parent.scale = Vector3.ONE * float(form.get("part_k", 1.0))       # bigger and bolder than the hunter: the silhouette reads from above
		torso.add_child(parent)
		_box = parent
	var base := Vector3.ZERO if torso else Vector3(0, -0.42, 0)       # the parts are placed relative to the torso origin
	rec = MergeParts.build(parent, form, base)

## A colour wash and bright rim in the form's colour over every mesh of the hunter (one shared overlay material).
func _wash_model(root: Node, glow: Color) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			if String(c.name).begins_with("Merge"):
				continue
			stack.append(c)
		if n is MeshInstance3D and (n as MeshInstance3D).visible:
			var mi := n as MeshInstance3D
			var mat := ShaderMaterial.new()
			mat.shader = WASH
			mat.set_shader_parameter("color", Color(glow, 1.0))
			mat.set_shader_parameter("strength", 1.0)
			var old := mi.material_overlay
			mat.next_pass = old          # (the outline some meshes already wear still draws after the wash)
			_wash.append([mi, old])
			mi.material_overlay = mat

static func _ease_back(u: float) -> float:
	var c3 := OVERSHOOT + 1.0
	var v := u - 1.0
	return 1.0 + c3 * v * v * v + OVERSHOOT * v * v

func _process(dt: float) -> void:
	_t += dt
	if h == null or not is_instance_valid(h):
		queue_free()
		return
	var sz := float(form["size"])
	# the silhouette: the whole model grows into the form (squash and stretch while it pops)
	var k := 1.0
	var tall := 0.0
	if _leave >= 0.0:
		_leave += dt
		var u := clampf(_leave / PEEL_S, 0.0, 1.0)
		k = 1.0 - u * u
		tall = -0.08 * sin(u * PI)
		if _leave >= PEEL_S:
			_restore()
			queue_free()
			return
	elif _pop_t < POP_S:
		_pop_t += dt
		var u2 := clampf(_pop_t / POP_S, 0.0, 1.0)
		k = _ease_back(u2)
		tall = 0.18 * sin(u2 * PI) * (1.0 - u2)
	if _model != null and is_instance_valid(_model):
		var s := lerpf(1.0, sz, clampf(k, 0.0, 1.4))
		_model.scale = _base_scale * Vector3(s * (1.0 - tall * 0.5), s * (1.0 + tall), s * (1.0 - tall * 0.5))
	if _aura:
		var pulse := 1.0 + 0.04 * sin(_t * 5.0)
		if _crack > 0.0:
			_crack -= dt
			pulse += 0.08 * sin(_t * 70.0)
		_aura.scale = Vector3.ONE * sz * pulse * clampf(k, 0.0, 1.2)
	if _ring:
		_ring.global_position = Vector3(h.global_position.x, h.global_position.y + 0.06, h.global_position.z)
		_ring.scale = Vector3.ONE * (1.0 + 0.07 * sin(_t * 6.0)) * clampf(k, 0.0, 1.2)
	# the last seconds of the window: the aura and the parts flicker, faster as it runs out
	var wl := MergeAugment.warn_left(h)
	var on := wl <= 0.0 or fmod(_t * (6.0 + (3.0 - minf(wl, 3.0)) * 4.0), 1.0) < 0.62
	if _aura:
		_aura.visible = on
	var box := _parts_box()
	if box:
		box.visible = on
	var moving := Vector2(h.vel.x, h.vel.z).length() > 2.0
	MergeParts.animate(rec, _t, dt, moving)
