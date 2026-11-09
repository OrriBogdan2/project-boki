class_name Unmasked
extends RefCounted
## The Empty (lore: the Wyrm stole everyone's essence, so people are born without faces): your own character.
## A person whose whole head is a void (a starfield seen with parallax), with a glowing socket shaped for a
## Relic floating on it and faint ghosts of the features that should be there, and whose body is wrapped in a
## shroud (no skin shows). The body (sex, height, build) shapes the silhouette under the shroud; the hollow
## (shape, glow, ghost features), the aura and the shroud (style, colour) are the rest.
## Relics fill you in: in a match you are the Hunter (mask_look); look["marks"] holds features a
## Relic left on you. Built by Models.hunter on the hunter rig, so every HunterAnim animation plays on it.
# "mask" in code = "Relic" in game, owner 2026-11-07 (Unmasked = the Empty, you before a Relic)

const SEXES := ["Female", "Male"]
## Per sex, in SEXES order: the face sliders (MantleLook "face_w" and "jaw", 0.5 neutral) that give her a narrower,
## shorter face and him a wider, longer jaw. With her smaller head and torso she stands about 7 cm shorter.
const SEX_FACE := [{"face_w": 0.3, "jaw": 0.4}, {"face_w": 0.7, "jaw": 0.65}]
const HEIGHTS := ["Short", "Average", "Tall"]
const HEIGHT_SCALE := [0.9, 1.0, 1.1]       # x the hunter's size: the whole body, its ring and the camera
const BUILDS := ["Slight", "Average", "Sturdy"]
const BUILD_WIDTH := [0.86, 1.0, 1.16]      # Models.hunter's body width for each build
const BUILD_BULK := [0.9, 1.0, 1.14]        # and the race bulk on top: thicker limbs, a fuller torso
const HOLLOWS := ["Oval", "Relic", "Torn", "Crescent"]
const GLOWS := [Color("8ae8ff"), Color("ff9a5a"), Color("b48cff"), Color("ff7ab0"), Color("ffd36a"), Color("7affc4")]
const GHOSTS := ["None", "Eyes", "Whole face", "Stitched"]
const AURA := ["None", "Faint", "Strong"]
const AURA_COUNT := [0, 16, 40]       # specks drifting round the head, shoulders and shroud
const SHROUDS := Shrouds.LABELS
const OLD_SHROUDS := 3                  # the first three cuts: what an outfit from before the shroud maps onto
## The shroud's colours (look["colour"]; an old save's skin colour keeps its index, so it becomes the shroud
## colour in the same slot).
const COLOURS := [Color("6b6f7a"), Color("3f4a63"), Color("2d3561"), Color("4f6b4a"), Color("2f6f73"), Color("7a2f45"),
	Color("a4552f"), Color("b58a3c"), Color("6a4a8c"), Color("d9cfbc"), Color("34343c"), Color("b8607a")]
const VOID_SKIN := Color("0b0814")    # what the head, neck and hands are made of: nothing shows but the void
## The creator's rows: look key, label, choices (colours show as a swatch), and a tooltip where the row needs
## one. The body and shroud rows come first, then the hollow's from HOLLOW_ROW on.
const ROWS := [
	["gender", "Sex", SEXES], ["height", "Height", HEIGHTS], ["build", "Build", BUILDS],
	["shroud", "Shroud", SHROUDS], ["colour", "Shroud colour", COLOURS],
	["hollow", "Hollow", HOLLOWS], ["glow", "Glow", GLOWS], ["ghost", "Ghost", GHOSTS],
	["aura", "Aura", AURA, "Glowing specks that drift around you"],
]
const HOLLOW_ROW := 5
const VOID_SHADER := preload("res://shaders/void_face.gdshader")
const AURA_RADIUS := 0.5               # m: how far from the shoulders the specks start
const AURA_SPECK := 0.024             # m: a speck's radius (the old motes were 0.012: too small to see)
const HEAD_SHELL := 1.012                 # x the head: the void's shell sits just over the head mesh

## The old face options (eyes, brows, blush) -> the closest hollow, ghost and glow.
const HOLLOW_FROM_EYES := [0, 0, 2, 1, 3, 1]
const GHOST_FROM_BROWS := [0, 1, 1, 2, 3]
## Old creator face (Models.LOOK_FACES) -> the closest old eyes.
const EYES_FROM_FACE := [0, 1, 2, 3, 4, 3, 5, 4, 1]

static func default_look() -> Dictionary:
	return {"unmasked": true, "gender": 1, "height": 1, "build": 1, "hollow": 0, "glow": 0, "ghost": 1, "aura": 1,
		"shroud": 0, "colour": 1, "marks": []}

static func random_look() -> Dictionary:
	var out := default_look()
	for row in ROWS:
		out[row[0]] = randi() % (row[2] as Array).size()
	return out

static func is_look(lk: Dictionary) -> bool:
	return bool(lk.get("unmasked", false))

## Any look (old creator or new, or none) as a complete Unmasked look with every value in its list.
## Keeps the keys that are not about the body (the glider).
static func clean(lk: Dictionary) -> Dictionary:
	var out := default_look()
	var src := lk if is_look(lk) else from_old(lk)
	out.merge(src, true)
	_hollow_from_face(out, src)
	_shroud_from_outfit(out, src)
	for row in ROWS:
		out[row[0]] = clampi(_i(out[row[0]], 0), 0, (row[2] as Array).size() - 1)
	if not out["marks"] is Array:
		out["marks"] = []
	return out

## A look from the face-marks creator (eyes, brows, blush, no hollow yet): the closest hollow, ghost and glow.
static func _hollow_from_face(out: Dictionary, src: Dictionary) -> void:
	if src.has("eyes") and not src.has("hollow"):
		out["hollow"] = HOLLOW_FROM_EYES[clampi(_i(src["eyes"], 0), 0, HOLLOW_FROM_EYES.size() - 1)]
		out["ghost"] = GHOST_FROM_BROWS[clampi(_i(src.get("brows"), 1), 0, GHOST_FROM_BROWS.size() - 1)]
		out["glow"] = 3 if _i(src.get("blush"), 0) > 0 else 0
	for k in ["eyes", "brows", "blush"]:
		out.erase(k)

## An Unmasked saved before the shroud: its outfit becomes a shroud style, its motes the aura. (The skin
## colour index in "colour" now picks the shroud colour, the same slot.)
static func _shroud_from_outfit(out: Dictionary, src: Dictionary) -> void:
	if src.has("outfit") and not src.has("shroud"):
		out["shroud"] = posmod(_i(src["outfit"], 0), OLD_SHROUDS)
	if src.has("motes") and not src.has("aura"):
		out["aura"] = _i(src["motes"], 1)
	out.erase("outfit")
	out.erase("motes")

## The closest Unmasked to an old detailed look (race, face, hair, skin...): race and hair are dropped.
## A whole number from whatever an old save held there (a string, nothing, a float), else `fallback`.
static func _i(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float or v is String else fallback

static func from_old(old: Dictionary) -> Dictionary:
	var out := default_look()
	for k in old:
		if not k in Models.default_look() and k != "race":
			out[k] = old[k]          # (the glider, and anything else the look carried)
	if old.is_empty():
		return out
	out["old"] = old.duplicate(true)      # kept for mask_look until the mask-look rules replace it
	var gender := clampi(_i(old.get("gender"), 1), 0, 1)
	var face := clampi(_i(old.get("face"), 0), 0, Models.LOOK_FACES.size() - 1)
	var race := clampi(_i(old.get("race"), 0), 0, Models.RACES.size() - 1)
	var reach := float(Models.RACES[race]["scale"])
	var outfit := clampi(_i(old.get("outfit"), 3), 0, Models.LOOK_OUTFITS.size() - 1)
	var skin := clampi(_i(old.get("skin"), 1), 0, Models.LOOK_SKIN.size() - 1)
	out["gender"] = gender
	out["build"] = clampi(_i(old.get("body"), 1), 0, 2)
	out["height"] = _height_for(reach)
	out["hollow"] = HOLLOW_FROM_EYES[EYES_FROM_FACE[face]]
	out["ghost"] = GHOST_FROM_BROWS[_brows_for(face, gender)]
	out["glow"] = 3 if gender == 0 or face == 3 else 0
	out["shroud"] = outfit % OLD_SHROUDS
	out["colour"] = skin % COLOURS.size()
	return out

## Short races read as Short, big ones as Tall.
static func _height_for(reach: float) -> int:
	if reach < 0.93:
		return 0
	return 2 if reach > 1.1 else 1

## Fierce and determined faces frown; the rest get a soft (feminine) or straight brow.
static func _brows_for(face: int, gender: int) -> int:
	if face in [4, 7]:
		return 4
	return 1 if gender == 0 else 2

## Upgrades a save's look in place (old saves hold the detailed creator's look). Safe to run twice.
static func migrate(data: Dictionary) -> void:
	if data.has("look") and data["look"] is Dictionary:
		data["look"] = clean(data["look"])

## The look the farm, town and house wear: yours, as the Unmasked.
static func worn() -> Dictionary:
	return clean(Save.d.get("look", {}))

## The look a Warden wears in a match and on hero screens, exactly as before the Unmasked: the detailed
## look the save held (a plain Warden for a new save). The mask-look rules will replace it.
static func mask_look() -> Dictionary:
	var lk: Dictionary = Save.d.get("look", {})
	var out := Models.default_look()
	out.merge(lk.get("old", {}), true)
	out["glider"] = String(lk.get("glider", "classic"))
	return out

## How much of you shows through a worn Relic (the Hunter is the rest).
const SHOW := 0.1

## The put-on blend on a built hero: your body colour tinted into every surface and your height and build
## proportions, SHOW of each. The Warden's model, outfit and weapon stay as they are.
static func blend(model: Node3D) -> void:
	var u := worn()
	var tint := colour(u)
	for m in model.get_meta("mats", []):
		var sm := m as ShaderMaterial
		var base: Variant = sm.get_shader_parameter("albedo")
		if base is Color:
			sm.set_shader_parameter("albedo", (base as Color).lerp(tint, SHOW))
	var wide := lerpf(1.0, BUILD_WIDTH[u["build"]], SHOW)
	model.scale *= Vector3(wide, lerpf(1.0, HEIGHT_SCALE[u["height"]], SHOW), wide)

## An Unmasked as the old look dictionary Models.hunter builds from: no race, no hair, no details.
static func legacy(lk: Dictionary) -> Dictionary:
	var u := clean(lk)
	return {
		"race": 0, "body": u["build"], "gender": u["gender"], "face": 1, "skin": 0, "hair": 13, "hair_v": 2,
		"hair_col": 0, "detail": 0, "outfit": 0, "glider": u.get("glider", "classic"), "sliders": SEX_FACE[u["gender"]],
	}

## The race entry Models.hunter reads: always human, sized by height.
static func race(lk: Dictionary) -> Dictionary:
	var u := clean(lk)
	return {"id": "human", "name": "Human", "scale": HEIGHT_SCALE[u["height"]],
		"head": 0.95 if int(u["gender"]) == 0 else 1.0, "bulk": BUILD_BULK[u["build"]], "skin": 1, "desc": ""}

static func colour(lk: Dictionary) -> Color:
	return COLOURS[clean(lk)["colour"]]

# ------------------------------------------------------------------------------------------ the hollow
## The void head: a shell of the head (Head's own mesh, a hair larger) that is void all the way round, with the
## hollow's socket, rim and ghost features floating on it; the aura drifting round you; any kept Relic marks.
static func face(torso: Node3D, lk: Dictionary) -> void:
	var u := clean(lk)
	var head := torso.get_node("Head") as MeshInstance3D
	var glow: Color = GLOWS[u["glow"]]
	var shell := MeshInstance3D.new()
	shell.name = "Hollow"
	shell.mesh = head.mesh
	shell.scale = Vector3.ONE * HEAD_SHELL
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.material_override = void_mat(int(u["hollow"]), int(u["ghost"]), glow)
	head.add_child(shell)
	_aura(torso, AURA_COUNT[u["aura"]], glow)
	for m in u["marks"]:
		var md: Dictionary = m
		var col := Models.toon(Color(String(md.get("col", "#ffffff"))), false)
		var at := Vector3(float(md.get("x", 0.0)), float(md.get("y", 0.85)), -0.215)
		Models.part(torso, Models.sphere(float(md.get("size", 0.02)), 10), col, at, Vector3(1.0, 1.0, 0.3))

## The void material for a head with a hollow of this shape (see shaders/void_face.gdshader), its ghost
## features and glow.
static func void_mat(shape: int, ghost: int, glow: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = VOID_SHADER
	mat.set_shader_parameter("shape", shape)
	mat.set_shader_parameter("ghost", ghost)
	mat.set_shader_parameter("glow", glow)
	return mat

## Specks of the glow drifting up and round the head, shoulders and shroud (none at 0). Big and bright enough
## to read from the farm's camera.
static func _aura(torso: Node3D, count: int, glow: Color) -> void:
	if count <= 0:
		return
	var p := CPUParticles3D.new()
	p.name = "Aura"
	p.position = Vector3(0, 0.3, 0)      # (torso space: the middle of the head and shoulders)
	p.amount = count
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = AURA_RADIUS
	p.direction = Vector3.UP
	p.spread = 30.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.25
	p.orbit_velocity_min = 0.12
	p.orbit_velocity_max = 0.3
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.7
	var fade := Gradient.new()
	fade.set_color(0, Color(glow, 0.0))
	fade.set_color(1, Color(glow, 0.0))
	fade.add_point(0.3, Color(glow.lightened(0.2), 1.0))
	p.color_ramp = fade
	var dot := SphereMesh.new()
	dot.radius = AURA_SPECK
	dot.height = AURA_SPECK * 2.0
	dot.radial_segments = 8
	dot.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dot.material = mat
	p.mesh = dot
	torso.add_child(p)

# ------------------------------------------------------------------------------------------ the shroud
## The shroud over the body (the colourway comes from the shroud colour, via Models.hunter): see Shrouds, which has
## the cuts. The body under it keeps its shape.
static func dress(c: Dictionary, lk: Dictionary) -> void:
	_shape(c, c["fem"])
	Shrouds.dress(c, clean(lk))

## Female and male read at a glance: a woman's narrower shoulders, fuller hips and a weight-on-one-hip
## stance; a man's broad shoulders and squarer, even stance (content/rules/warden_stance.json "empty_f",
## "empty_m", read by HunterAnim through the model's "stance" meta).
static func _shape(c: Dictionary, fem: bool) -> void:
	var torso: Node3D = c["torso"]
	torso.get_parent().get_parent().set_meta("stance", "empty_f" if fem else "empty_m")
	for ch in torso.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh == HeroKit.torso(fem):
			(ch as MeshInstance3D).mesh = figure(fem)
	var shoulder := 0.85 if fem else 1.1
	var limb := Vector3(0.8, 1.0, 0.8) if fem else Vector3(1.08, 1.0, 1.08)
	for sd in ["L", "R"]:
		var piv := (c["arms"][sd] as Array)[0] as Node3D
		piv.position.x *= shoulder
		piv.scale = limb
		(c["p" + sd.to_lower()] as Node3D).position.x *= shoulder
	if not fem:
		return
	var legs := torso.get_parent().get_node("Legs")
	for nm in ["LegL", "LegR"]:
		var leg := legs.get_node(nm) as Node3D
		leg.position.x *= 1.12
		leg.scale = Vector3(0.9, 1.0, 0.9)

## The Empty's torso: the hunter torso drawn into an hourglass for a woman (a slim waist, a fuller bust
## and hips) or a broad, square chest for a man.
static func figure(fem: bool) -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var p := HeroKit.torso_pt(u, v, fem)
		var front := clampf(-sin(u * TAU), 0.0, 1.0)
		var k := 1.0
		if fem:
			k -= 0.21 * exp(-pow((p.y + 0.07) / 0.1, 2.0))
			k += 0.13 * smoothstep(-0.16, -0.3, p.y)
			for sx in [-1.0, 1.0]:
				var d := Vector2(p.x - 0.08 * sx, (p.y - 0.08) * 1.1)
				p.z -= 0.04 * exp(-d.length_squared() / 0.004) * front
		else:
			k += 0.1 * smoothstep(-0.05, 0.22, p.y) - 0.04 * exp(-pow((p.y + 0.1) / 0.12, 2.0))
		return Vector3(p.x * k, p.y, p.z * lerpf(1.0, k, 0.6))
	return HeroKit.surf("empty_torso|%s" % fem, fn, 48, 26)
