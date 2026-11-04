class_name KinGlb
## A Boki species drawn from a 3D model (art/kin/<species>/<species>.glb, tools/meshy/kin_parts.py) instead of
## KinModels' primitives. The .glb carries the node names KinPuppet animates (Tail, Ears, Legs/Leg0..3), so walk,
## idle, naps and emotes work unchanged. Its surfaces take the Hunters' hero-toon look (ink line, rim light, the
## match-zoom read), and a shimmer or ghost tints the painted atlas the way it recolours the procedural body.
## A species without a model keeps its KinModels body.

const PATH := "res://art/kin/%s/%s.glb"
## Where the eyes and the top of the head sit (m), per species: what KinModels.build returns for the accessories.
const FRAME := {"pebbit": {"head": Vector3(0, 0.27, -0.34), "top": 0.55}}

## The painted atlas under the game's cool light reads dark, so its albedo is lifted (x) to match the art's colours.
const LIFT := 1.2
## The Hunters' match-zoom brightening (WardenGlb.PAINTED far_lift 0.35) washed a small pale creature to white.
const FAR_LIFT := 0.0
## A body rim stronger than this (a ghost's glow) carries over; the normal rim is the Hunters' own.
const GHOST_RIM := 1.5
## False draws every species from KinModels' primitives (the old-vs-new shots).
static var enabled := true

static func has(species: String) -> bool:
	return enabled and FRAME.has(species) and ResourceLoader.exists(PATH % [species, species])

## Adds the model under `flex`; `c` is KinModels' material set (body = the species' tinted body material).
static func build(species: String, flex: Node3D, c: Dictionary, mats: Array) -> Dictionary:
	var root := (load(PATH % [species, species]) as PackedScene).instantiate() as Node3D
	var holder := root.find_child("Tail", true, false).get_parent()
	for part in holder.get_children():       # KinPuppet wants Tail, Ears and Legs straight under Flex
		holder.remove_child(part)
		flex.add_child(part)
	root.free()
	var body := c["body"] as ShaderMaterial
	var base: Color = Data.KIN[species]["color"]
	var tint := body.get_shader_parameter("albedo") as Color
	tint = Color(tint.r / maxf(base.r, 0.01), tint.g / maxf(base.g, 0.01), tint.b / maxf(base.b, 0.01), 1.0)
	for mi in flex.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		for si in inst.mesh.get_surface_count():
			var src := inst.mesh.surface_get_material(si) as BaseMaterial3D
			var m := Models.toon(Color.WHITE, true)
			m.set_shader_parameter("vertex_ao", false)
			Models.hero_look(m)
			m.set_shader_parameter("albedo_tex", src.albedo_texture)
			m.set_shader_parameter("use_tex", true)
			m.set_shader_parameter("albedo", (tint * LIFT).clamp(Color(0, 0, 0), Color(1.8, 1.8, 1.8)))
			for k in WardenGlb.PAINTED:
				m.set_shader_parameter(k, WardenGlb.PAINTED[k])
			m.set_shader_parameter("far_lift", FAR_LIFT)
			m.set_shader_parameter("rim_color", body.get_shader_parameter("rim_color"))
			if float(body.get_shader_parameter("rim_amount")) > GHOST_RIM:
				m.set_shader_parameter("rim_amount", body.get_shader_parameter("rim_amount"))
			inst.set_surface_override_material(si, m)
			mats.append(m)
	return FRAME[species]
