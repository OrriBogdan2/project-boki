class_name EggModels
## The eggs' 3D shells (docs/art/EGGS.md): one Meshy model per egg family in art/eggs/<kind>.glb, baked
## by tools/meshy/bake_egg.py to 1 m tall and cut at half height into "Cap" and "Cup" so EggHatch can
## split it. A kin's egg is its type's (its Data.KIN "theme": plates, glowing seams and an emblem);
## eggs from a boss are "rare" (gold, a teal seam round the middle); the hatch scene's basket egg is
## "mystery" (void black, oil-slick bands, a "?" cracked into the shell). Drawn with the toon light and
## the house ink, like the Boki.

const PATH := "res://art/eggs/%s.glb"
const KINDS := ["ember", "frost", "venom", "stone", "spore", "shadow", "titan", "gravity", "echo", "bloom",
	"swarm", "storm", "lunar", "prism", "tempest", "rare", "mystery"]
## Each shell's main colour (its plates, measured off the model's front, a touch lighter): the hatch's
## broken rim teeth and falling chips.
const TINT := {
	"ember": Color("513f38"), "frost": Color("88adc0"), "venom": Color("5d4155"), "stone": Color("8a7568"),
	"spore": Color("8e7c74"), "shadow": Color("3e364b"), "titan": Color("6d777b"), "gravity": Color("4a4b7a"),
	"echo": Color("5d85b5"), "bloom": Color("808b58"), "swarm": Color("c18b49"), "storm": Color("697680"),
	"lunar": Color("b4b2bb"), "prism": Color("cba4b0"), "tempest": Color("a0b7c1"), "rare": Color("ae8948"),
	"mystery": Color("3c3b54"),
}

const RARE_SEAM_HUE := 0.48    # 0..1: the teal of the Rare Egg's seam ring, repainted in the kin's own glow
const RARE_SEAM_WIDTH := 0.07  # half-width of that hue band (the gold sits far off at ~0.12)
const IDLE_SPIN := 0.35        # rad/s: an egg sitting out turns slowly, so its emblem comes round
const IDLE_BOB := 0.015        # m per metre of egg: its gentle float

static var _halves := {}       # kind -> {"Cap": Mesh, "Cup": Mesh, "tex": Texture2D}

## The egg family a kin hatches from: its type (an old save's egg with no kin known: stone).
static func kind_of(species: String) -> String:
	return String(Data.KIN.get(species, {}).get("theme", "stone"))

## A new toon material for one egg (its own, so warming one egg does not warm the rest).
static func material(kind: String) -> ShaderMaterial:
	var m := Models.toon(Color.WHITE, false)
	m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("albedo_tex", _load(kind)["tex"])
	var ink := ShaderMaterial.new()
	ink.shader = Models.OUTLINE
	ink.set_shader_parameter("width", BokiRig.INK_WIDTH)
	ink.set_shader_parameter("far_thin", BokiRig.INK_FAR_THIN)
	m.next_pass = ink
	return m

## One half of the shell ("Cap" or "Cup"), its bottom at y = 0 and `height` tall when put together.
static func half(kind: String, part: String, mat: ShaderMaterial, height: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part
	mi.mesh = _load(kind)[part]
	mi.material_override = mat
	mi.scale = Vector3.ONE * height
	return mi

## The whole egg as a "Shell" node (both halves), standing at `y`, `height` tall, turning and floating
## gently. A Rare Egg's seam ring takes the colour of the kin inside (`seam`).
static func shell(kind: String, height: float, y := 0.0, glow := 0.0, seam := Color(0, 0, 0, 0)) -> Node3D:
	var n := Node3D.new()
	n.name = "Shell"
	n.position.y = y
	var mat := material(kind)
	mat.set_shader_parameter("glow", glow)
	if seam.a > 0.0:
		mat.set_shader_parameter("recolor", 1.0)
		mat.set_shader_parameter("recolor_to", seam)
		mat.set_shader_parameter("recolor_hue", RARE_SEAM_HUE)
		mat.set_shader_parameter("recolor_width", RARE_SEAM_WIDTH)
	for part in ["Cap", "Cup"]:
		n.add_child(half(kind, part, mat, height))
	PropAnim.on(n, IDLE_SPIN, IDLE_BOB * height)
	return n

static func _load(kind: String) -> Dictionary:
	if _halves.has(kind):
		return _halves[kind]
	var root := (load(PATH % kind) as PackedScene).instantiate()
	var d := {}
	for part in ["Cap", "Cup"]:
		var mi := root.find_child(part, true, false) as MeshInstance3D
		d[part] = mi.mesh
		d["tex"] = (mi.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture
	root.free()
	_halves[kind] = d
	return d
