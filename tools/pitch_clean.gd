extends RefCounted
## SCRATCH (private, never shipped): the pitch-reel recorder's clean look. Only tools/pitch_reel.gd calls it, and
## only with `--clean-look` / `--clear=<m>`: the game itself never changes.
## - frame(): every filmed frame, after the bodies are drawn, a fighter shows its own colours: no hit flash, burn
##   tint, crowd-control or cast tint (BodyTell), ult glow or side-colour rim (hero_toon), no x-ray or occlusion
##   overlay; no Boki wisp floats beside it and no AimKit telegraph line crosses it (they read as stray balls and
##   white lines on film).
## - clear_deco(): once, the map dressing (trees, rocks, pebbles, tall grass, camps, landmarks) near the fight spot
##   goes; short grass and flowers stay so the ground still looks like the game.

const KEEP_DECO := ["Grass", "Flowers"]  # World._chunked labels left standing
const XRAY_SHADERS := ["res://shaders/occlusion_outline.gdshader", "res://shaders/kin_aura_xray.gdshader"]
const BODY_OFF := {"flash": 0.0, "ult_glow": 0.0, "side_rim": Color(0, 0, 0, 0), "tell": Color(0, 0, 0, 0)}


static func frame(m: Node) -> void:
	for h in m.hunters:
		for mt in h.mats:
			if mt is ShaderMaterial:
				for k in BODY_OFF:
					(mt as ShaderMaterial).set_shader_parameter(k, BODY_OFF[k])
		if h.model != null:
			_drop_overlays(h.model)
	for k in m.kins:
		if k.model != null:
			k.model.visible = false
	var aim := m.get_node_or_null("AimKit") as Node3D
	if aim != null:
		aim.visible = false


static func _drop_overlays(model: Node3D) -> void:
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var sm := mi.material_overlay as ShaderMaterial
		if sm != null and sm.shader != null and sm.shader.resource_path in XRAY_SHADERS:
			mi.material_overlay = null


## Hides the dressing within `r` m (flat) of `at`; returns how many pieces went.
static func clear_deco(m: Node, at: Vector3, r: float) -> int:
	var deco := m.world.get_node_or_null("Deco")
	if deco == null:
		return 0
	var n := 0
	for c in deco.get_children():
		if c is MultiMeshInstance3D:
			n += _thin(c as MultiMeshInstance3D, at, r)
		elif c is Node3D and _flat((c as Node3D).global_position, at) < r:
			(c as Node3D).visible = false
			n += 1
	return n


## Scales to nothing every instance of a batch within `r` of `at` (the batch's other instances stay).
static func _thin(mi: MultiMeshInstance3D, at: Vector3, r: float) -> int:
	if String(mi.name).get_slice("_", 0) in KEEP_DECO or mi.multimesh == null:
		return 0
	var mm := mi.multimesh
	var n := 0
	for k in mm.instance_count:
		var t := mm.get_instance_transform(k)
		if _flat(mi.global_transform * t.origin, at) < r:
			mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), t.origin))
			n += 1
	return n


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
