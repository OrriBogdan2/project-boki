extends RefCounted
## SCRATCH (private, never shipped): the pitch-reel recorder's clean look. Only tools/pitch_reel.gd calls it, and
## only with `--clean-look` / `--clear=<m>`: the game itself never changes.
## - frame(): every filmed frame, after the bodies are drawn, a fighter shows its own colours: no hit flash, burn
##   tint, crowd-control or cast tint (BodyTell), ult glow or side-colour rim (hero_toon), no x-ray or occlusion
##   overlay; no Boki wisp floats beside it and no AimKit telegraph line crosses it (they read as stray balls and
##   white lines on film), no skyship passes overhead, and a hunter hidden from the player (bush, wall) leaves no
##   DepthCues shadow disc on the ground (a dark blob with no body above it).
## - clear_deco(): once, the map dressing (trees, rocks, pebbles, tall grass, camps, landmarks) near the fight spot
##   goes; short grass and flowers stay so the ground still looks like the game. The cleared blocks stop casting
##   sight shadows too (shaders/vis.gdshaderinc dims the ground behind a block: soft dark blobs with nothing there).

const KEEP_DECO := ["Grass", "Flowers"]  # World._chunked labels left standing
const XRAY_SHADERS := [
	"res://shaders/occlusion_outline.gdshader", "res://shaders/kin_aura_xray.gdshader"
]
const BODY_OFF := {
	"flash": 0.0, "ult_glow": 0.0, "side_rim": Color(0, 0, 0, 0), "tell": Color(0, 0, 0, 0)
}


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
	var cues := m.get_node_or_null("DepthCues")
	if cues != null:
		var discs: Dictionary = cues.get("_discs")
		for h in discs:
			var shown: bool = not h.unseen and h.model != null and h.model.is_visible_in_tree()
			(discs[h] as Node3D).scale = Vector3.ONE if shown else Vector3.ZERO  # DepthCues moves it, never scales it
	for s in m.ships + [m.ship]:
		var sn: Variant = (s as Dictionary).get("node")
		if is_instance_valid(sn) and sn is Node3D:
			(sn as Node3D).visible = false


static func _drop_overlays(model: Node3D) -> void:
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var sm := mi.material_overlay as ShaderMaterial
		if sm != null and sm.shader != null and sm.shader.resource_path in XRAY_SHADERS:
			mi.material_overlay = null


## Hides the dressing within `r` m (flat) of `at`; returns how many pieces went.
static func clear_deco(m: Node, at: Vector3, r: float) -> int:
	_clear_sight_blocks(m, at, r)
	var deco: Node = m.world.get_node_or_null("Deco")
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


## Swaps in a sight-block map (World.vis_texture, 1 m cells) without the blocks within `r` of `at`, and marks it
## sent so Match._update_vision keeps it.
static func _clear_sight_blocks(m: Node, at: Vector3, r: float) -> void:
	var img: Image = m.world.vis_texture().get_image()
	for z in range(maxi(0, floori(at.z - r)), mini(img.get_height(), ceili(at.z + r))):
		for x in range(maxi(0, floori(at.x - r)), mini(img.get_width(), ceili(at.x + r))):
			if _flat(Vector3(x + 0.5, 0, z + 0.5), at) < r:
				img.set_pixel(x, z, Color(0, 0, 0))
	RenderingServer.global_shader_parameter_set("vis_blocks", ImageTexture.create_from_image(img))
	RenderingServer.global_shader_parameter_set("vis_size", Vector2(m.world.w, m.world.h))
	m.set("_vis_tex_done", true)


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
