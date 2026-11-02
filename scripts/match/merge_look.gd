class_name MergeLook
extends Node3D
## The form a merged hunter wears (MergeForm): the Boki's colour as a wrapped glow and a ground ring,
## plus silhouette parts that say which Boki it is from far away (horns, wings, a crest, plates, a
## halo...). One node under the hunter while merged; other games build it from the net state
## (KinNet). Bigger with the power tier.

const NODE_NAME := "MergeLook"
const PARTS_NAME := "MergeParts"   # the silhouette parts ride the torso in this container, freed with the look
var h: Hunter = null
var form: Dictionary = {}
var _wings: Array = []
var _halo: Node3D = null
var _tail: Array = []
var _ring: MeshInstance3D = null
var _t := 0.0

static func attach(hunter: Hunter, f: Dictionary) -> void:
	detach(hunter)
	if hunter == null or f.is_empty():
		return
	var ml := MergeLook.new()
	ml.name = NODE_NAME
	ml.h = hunter
	ml.form = f
	hunter.add_child(ml)
	ml.build()

static func detach(hunter: Hunter) -> void:
	if hunter == null:
		return
	var torso: Node3D = hunter.model.get_node_or_null("Rig/Torso") if hunter.model else null
	var box := torso.get_node_or_null(PARTS_NAME) if torso else null
	if box:
		torso.remove_child(box); box.queue_free()
	var old := hunter.get_node_or_null(NODE_NAME)
	if old:
		hunter.remove_child(old)
		old.queue_free()

func build() -> void:
	var col: Color = form["color"]
	var glow: Color = form["glow"]
	var sz := float(form["size"])
	var shell := Models.part(self, Models.capsule(0.62, 2.0), Models.aura_mat(glow, 0.7), Vector3(0, 1.0, 0), Vector3.ONE * sz)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring = Models.part(self, Models.flat_quad(3.0 * sz), Models.ring_mat(Color(glow, 0.9), 0.1), Vector3(0, 0.06, 0))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.top_level = true
	var mote := CPUParticles3D.new()
	mote.amount = 14; mote.lifetime = 0.9; mote.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; mote.emission_sphere_radius = 0.5
	mote.direction = Vector3.UP; mote.spread = 20.0; mote.gravity = Vector3(0, 1.2, 0); mote.initial_velocity_min = 0.3; mote.initial_velocity_max = 0.8
	mote.mesh = SphereMesh.new(); (mote.mesh as SphereMesh).radius = 0.04; (mote.mesh as SphereMesh).height = 0.08
	mote.material_override = Models.glow_mat(glow)
	mote.position = Vector3(0, 1.0, 0)
	add_child(mote)
	var torso: Node3D = h.model.get_node_or_null("Rig/Torso") if h.model else null
	var parent: Node3D = self
	if torso:
		var box := torso.get_node_or_null(PARTS_NAME)
		if box: box.free()
		parent = Node3D.new(); parent.name = PARTS_NAME
		torso.add_child(parent)
	var base := Vector3.ZERO if torso else Vector3(0, -0.42, 0)       # the parts are placed relative to the torso origin
	for p in form["parts"]:
		_add_part(parent, String(p), col, glow, base, sz)

func _mat(col: Color, glow: Color) -> ShaderMaterial:
	return Models.toon(col.lerp(glow, 0.35), true, 0.55)

func _cone(parent: Node3D, mat: Material, pos: Vector3, h_: float, r_: float, rot: Vector3) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0; cm.bottom_radius = r_; cm.height = h_; cm.radial_segments = 8
	return Models.part(parent, cm, mat, pos + Basis.from_euler(rot) * Vector3(0, h_ * 0.5, 0), Vector3.ONE, rot)

func _add_part(parent: Node3D, kind: String, col: Color, glow: Color, base: Vector3, sz: float) -> void:
	var mat := _mat(col, glow)
	match kind:
		"horns":
			for s in [-1.0, 1.0]:
				_cone(parent, mat, base + Vector3(0.13 * s, 1.12, -0.02), 0.5 * sz, 0.07, Vector3(0.0, 0.0, -0.45 * s))
		"fangs":
			for s in [-1.0, 1.0]:
				_cone(parent, mat, base + Vector3(0.07 * s, 1.0, -0.15), 0.2, 0.035, Vector3(PI, 0.0, 0.0))
		"crest":
			for i in 5:
				_cone(parent, mat, base + Vector3(0, 1.16 - 0.02 * i, -0.02 + 0.09 * i), (0.42 - 0.05 * i) * sz, 0.05, Vector3(0.5 + 0.1 * i, 0.0, 0.0))
		"spikes":
			for i in 4:
				_cone(parent, mat, base + Vector3(0, 0.95 - 0.2 * i, 0.2), 0.34 * sz, 0.06, Vector3(1.0, 0.0, 0.0))
		"plates":
			for s in [-1.0, 1.0]:
				var pl := Models.part(parent, BoxMesh.new(), mat, base + Vector3(0.34 * s, 0.85, 0.0), Vector3(0.26, 0.1, 0.3) * sz, Vector3(0, 0, 0.35 * s))
				pl.name = "Plate"
		"wings":
			for s in [-1.0, 1.0]:
				var w := Node3D.new()
				w.position = base + Vector3(0.14 * s, 0.7, 0.2)
				parent.add_child(w)
				for i in 3:
					var f := Models.part(w, BoxMesh.new(), mat, Vector3(0.38 * s * (0.55 + 0.4 * i) , 0.1 * i, 0.04 * i), Vector3(0.62 - 0.12 * i, 0.03, 0.14) * sz, Vector3(0, 0.25 * s * i, 0.5 * s - 0.15 * s * i))
					f.name = "Feather"
				w.set_meta("side", s)
				_wings.append(w)
		"halo":
			var tm := TorusMesh.new()
			tm.inner_radius = 0.26; tm.outer_radius = 0.31
			_halo = Models.part(parent, tm, Models.glow_mat(glow), base + Vector3(0, 1.5, 0), Vector3.ONE * sz)
			_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"antennae":
			for s in [-1.0, 1.0]:
				_cone(parent, mat, base + Vector3(0.09 * s, 1.14, -0.05), 0.5 * sz, 0.025, Vector3(-0.3, 0.0, -0.35 * s))
				Models.part(parent, Models.sphere(0.04), Models.glow_mat(glow), base + Vector3(0.09 * s + 0.2 * s, 1.62 * sz, -0.1))
		"tail":
			for i in 5:
				var seg := Models.part(parent, Models.sphere(0.11 - 0.017 * i), mat, base + Vector3(0, 0.3 + 0.1 * i, 0.3 + 0.08 * i))
				_tail.append(seg)

func _process(dt: float) -> void:
	_t += dt
	if h == null or not is_instance_valid(h):
		return
	if _ring:
		_ring.global_position = Vector3(h.global_position.x, h.global_position.y + 0.06, h.global_position.z)
		_ring.scale = Vector3.ONE * (1.0 + 0.07 * sin(_t * 6.0))
	for w in _wings:
		if not is_instance_valid(w): continue
		var s: float = w.get_meta("side")
		w.rotation.z = s * (0.15 + 0.22 * (0.5 + 0.5 * sin(_t * 7.0)))
	if _halo and is_instance_valid(_halo):
		_halo.rotation.y += dt * 2.5
		_halo.position.y += sin(_t * 4.0) * 0.1 * dt
	for i in _tail.size():
		if is_instance_valid(_tail[i]): (_tail[i] as Node3D).position.x = sin(_t * 5.0 - i * 0.6) * 0.09 * float(i)
