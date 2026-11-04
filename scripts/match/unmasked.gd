class_name Unmasked
extends RefCounted
## The Empty (lore: the Wyrm stole everyone's essence, so people are born without faces): your own character.
## A readable person whose face is a hollow, a glowing socket shaped for a Mask with a starfield inside
## and faint ghosts of the features that should be there, and a small glowing void where the heart is.
## The body (sex, height, build), the hollow (shape, glow, ghost features, motes), an outfit and one body
## colour. Masks fill you in: in a match you are the Hunter (mask_look); look["marks"] holds features a
## Mask left on you. Built by Models.hunter on the hunter rig, so every HunterAnim animation plays on it.

const SEXES := ["Female", "Male"]
const HEIGHTS := ["Short", "Average", "Tall"]
const HEIGHT_SCALE := [0.9, 1.0, 1.1]       # x the hunter's size: the whole body, its ring and the camera
const BUILDS := ["Slight", "Average", "Sturdy"]
const BUILD_WIDTH := [0.86, 1.0, 1.16]      # Models.hunter's body width for each build
const BUILD_BULK := [0.9, 1.0, 1.14]        # and the race bulk on top: thicker limbs, a fuller torso
const HOLLOWS := ["Oval", "Mask", "Torn", "Crescent"]
const GLOWS := [Color("8ae8ff"), Color("ff9a5a"), Color("b48cff"), Color("ff7ab0"), Color("ffd36a"), Color("7affc4")]
const GHOSTS := ["None", "Eyes", "Whole face", "Stitched"]
const MOTES := ["None", "A few", "A swarm"]
const MOTE_COUNT := [0, 6, 18]
const OUTFITS := ["Traveller", "Scholar", "Smith", "Sailor", "Festival"]
const OUTFIT_COL := [3, 1, 4, 2, 5]      # each outfit's colourway: an index into Models.OUTFIT_COLS
const COLOURS := [Color("f1e6d6"), Color("e3c9a8"), Color("d2a77f"), Color("b27c58"), Color("86573a"), Color("5a3b2a"),
	Color("a9c7e8"), Color("b9d8b0"), Color("c9b8e8"), Color("f0b8c8"), Color("c4c8d2"), Color("e8d27a")]
## The creator's rows: look key, label, choices (colours show as a swatch). The body rows come first, then
## the hollow's from HOLLOW_ROW on.
const ROWS := [
	["gender", "Sex", SEXES], ["height", "Height", HEIGHTS], ["build", "Build", BUILDS],
	["outfit", "Outfit", OUTFITS], ["colour", "Colour", COLOURS],
	["hollow", "Hollow", HOLLOWS], ["glow", "Glow", GLOWS], ["ghost", "Ghost", GHOSTS], ["motes", "Motes", MOTES],
]
const HOLLOW_ROW := 5
const VOID_SHADER := preload("res://shaders/void_face.gdshader")
const HEAD_SHELL := 1.012                 # x the head: the hollow's shell sits just over the skin

## The old face options (eyes, brows, blush) -> the closest hollow, ghost and glow.
const HOLLOW_FROM_EYES := [0, 0, 2, 1, 3, 1]
const GHOST_FROM_BROWS := [0, 1, 1, 2, 3]
## Old creator face (Models.LOOK_FACES) -> the closest old eyes.
const EYES_FROM_FACE := [0, 1, 2, 3, 4, 3, 5, 4, 1]
## Old outfit (Models.LOOK_OUTFITS) -> the closest new one.
const OUTFIT_FROM_OLD := [4, 1, 0, 0, 2, 2, 3, 2, 4]

static func default_look() -> Dictionary:
	return {"unmasked": true, "gender": 1, "height": 1, "build": 1, "hollow": 0, "glow": 0, "ghost": 1, "motes": 1,
		"outfit": 0, "colour": 1, "marks": []}

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
	out["outfit"] = OUTFIT_FROM_OLD[outfit]
	out["colour"] = _nearest_colour(Models.LOOK_SKIN[skin])
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

static func _nearest_colour(c: Color) -> int:
	var best := 0
	var bd := 1e9
	for i in COLOURS.size():
		var p: Color = COLOURS[i]
		var d := (p.r - c.r) * (p.r - c.r) + (p.g - c.g) * (p.g - c.g) + (p.b - c.b) * (p.b - c.b)
		if d < bd:
			bd = d
			best = i
	return best

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

## How much of you shows through a worn Mask (the Hunter is the rest).
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
		"hair_col": 0, "detail": 0, "outfit": OUTFIT_COL[u["outfit"]], "glider": u.get("glider", "classic"),
	}

## The race entry Models.hunter reads: always human, sized by height.
static func race(lk: Dictionary) -> Dictionary:
	var u := clean(lk)
	return {"id": "human", "name": "Human", "scale": HEIGHT_SCALE[u["height"]],
		"head": 0.93 if int(u["gender"]) == 0 else 1.0, "bulk": BUILD_BULK[u["build"]], "skin": 1, "desc": ""}

static func colour(lk: Dictionary) -> Color:
	return COLOURS[clean(lk)["colour"]]

# ------------------------------------------------------------------------------------------ the hollow
## The hollow face: a shell of the head (Head's own mesh, a hair larger) that shows only the socket, its
## starfield, rim and ghost features; motes drifting round the head; and any kept Mask marks.
static func face(torso: Node3D, lk: Dictionary, skin: Color) -> void:
	var u := clean(lk)
	var head := torso.get_node("Head") as MeshInstance3D
	var glow: Color = GLOWS[u["glow"]]
	var shell := MeshInstance3D.new()
	shell.name = "Hollow"
	shell.mesh = head.mesh
	shell.scale = Vector3.ONE * HEAD_SHELL
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.material_override = void_mat(int(u["hollow"]), int(u["ghost"]), glow, skin)
	head.add_child(shell)
	_motes(head, MOTE_COUNT[u["motes"]], glow)
	for m in u["marks"]:
		var md: Dictionary = m
		var col := Models.toon(Color(String(md.get("col", "#ffffff"))), false)
		var at := Vector3(float(md.get("x", 0.0)), float(md.get("y", 0.85)), -0.215)
		Models.part(torso, Models.sphere(float(md.get("size", 0.02)), 10), col, at, Vector3(1.0, 1.0, 0.3))

## The void material for a hollow of this shape (see shaders/void_face.gdshader), its ghost features and
## glow. The deep colour leans a little toward the body colour so the socket belongs to the face.
static func void_mat(shape: int, ghost: int, glow: Color, skin := Color.BLACK) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = VOID_SHADER
	mat.set_shader_parameter("shape", shape)
	mat.set_shader_parameter("ghost", ghost)
	mat.set_shader_parameter("glow", glow)
	mat.set_shader_parameter("deep", Color(0.02, 0.015, 0.05).lerp(skin.darkened(0.85), 0.25))
	return mat

## A few specks of the glow drifting up round the head (none at 0).
static func _motes(head: Node3D, count: int, glow: Color) -> void:
	if count <= 0:
		return
	var p := CPUParticles3D.new()
	p.name = "Motes"
	p.amount = count
	p.lifetime = 3.2
	p.preprocess = 3.2
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.32
	p.direction = Vector3.UP
	p.spread = 35.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.04
	p.initial_velocity_max = 0.12
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(glow, 0.0))
	fade.set_color(1, Color(glow, 0.0))
	fade.add_point(0.4, Color(glow.lightened(0.3), 1.0))
	p.color_ramp = fade
	var dot := SphereMesh.new()
	dot.radius = 0.012
	dot.height = 0.024
	dot.radial_segments = 6
	dot.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dot.material = mat
	p.mesh = dot
	head.add_child(p)

# ------------------------------------------------------------------------------------------ outfits
## What the outfit adds over the plain tunic (the colourway comes from OUTFIT_COL): no hunter gear.
static func dress(c: Dictionary, lk: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var torso: Node3D = c["torso"]
	var bw: float = c["bw"]
	var rz := 0.214 * bw + 0.01
	var rx := 0.222 * maxf(c["cw"], bw) + 0.01
	var belt := HeroKit.band("ubelt|%.3f|%.3f" % [rx, rz], rx, rz, 0.05, 0.014)
	Models.part(torso, belt, m["leather"], Vector3(0, 0.1, 0))
	var front := Vector3(0.0, 0.33, -0.2 * bw)
	_shape(c, int(clean(lk)["gender"]) == 0)
	_heart(torso, bw, GLOWS[clean(lk)["glow"]])
	match int(clean(lk)["outfit"]):
		1:   # Scholar: a long coat skirt
			Models.part(c["skirt"], Models.cyl(0.2 * bw, 0.3 * bw, 0.38, 20), m["body"], Vector3(0, -0.17, 0))
		2:   # Smith: an apron and its strap
			Models.part(torso, Models.box(0.26 * bw, 0.36, 0.02), m["leather"], Vector3(0, 0.12, -rz - 0.004))
			Models.part(torso, Models.box(0.05, 0.2, 0.02), m["leather"], Vector3(0, 0.45, -rz + 0.01))
		3:   # Sailor: a scarf
			Models.part(torso, Models.cyl(0.11, 0.13, 0.06, 18), m["trim"], Vector3(0, 0.6, 0))
			Models.part(torso, Models.box(0.06, 0.2, 0.02), m["trim"], Vector3(0.06, 0.5, -0.1))
		4:   # Festival: a sash across the chest
			Models.part(torso, Models.box(0.07, 0.5, 0.025), m["gold"], front, Vector3.ONE, Vector3(0, 0, 0.7))
		_:   # Traveller: a satchel strap
			Models.part(torso, Models.box(0.04, 0.5, 0.02), m["leather"], front, Vector3.ONE, Vector3(0, 0, -0.7))

## Female and male read at a glance: a woman's narrower shoulders, fuller hips and a weight-on-one-hip
## stance; a man's broad shoulders and squarer, even stance (content/rules/warden_stance.json "empty_f",
## "empty_m", read by HunterAnim through the model's "stance" meta).
static func _shape(c: Dictionary, fem: bool) -> void:
	var torso: Node3D = c["torso"]
	var m: Dictionary = c["m"]
	var bw: float = c["bw"]
	torso.get_parent().get_parent().set_meta("stance", "empty_f" if fem else "empty_m")
	for ch in torso.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh == HeroKit.torso(fem):
			(ch as MeshInstance3D).mesh = figure(fem)
	var shoulder := 0.88 if fem else 1.06
	var limb := Vector3(0.8, 1.0, 0.8) if fem else Vector3.ONE
	for sd in ["L", "R"]:
		var piv := (c["arms"][sd] as Array)[0] as Node3D
		piv.position.x *= shoulder
		piv.scale = limb
		(c["p" + sd.to_lower()] as Node3D).position.x *= shoulder
	if not fem:
		return
	var peplum := HeroKit.drape("empty_peplum|%.3f" % bw, 0.215 * bw, 0.3 * bw, 0.2, 0.0, 1.0, 10.0, 0.025)
	Models.part(c["skirt"], peplum, m["body"], Vector3(0, 0.02, 0))
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
			k -= 0.17 * exp(-pow((p.y + 0.07) / 0.1, 2.0))
			k += 0.1 * smoothstep(-0.16, -0.3, p.y)
			for sx in [-1.0, 1.0]:
				var d := Vector2(p.x - 0.08 * sx, (p.y - 0.08) * 1.1)
				p.z -= 0.04 * exp(-d.length_squared() / 0.004) * front
		else:
			k += 0.07 * smoothstep(-0.05, 0.22, p.y) - 0.03 * exp(-pow((p.y + 0.1) / 0.12, 2.0))
		return Vector3(p.x * k, p.y, p.z * lerpf(1.0, k, 0.6))
	return HeroKit.surf("empty_torso|%s" % fem, fn, 48, 26)

## The heart's hollow: a small glowing void on the chest, where the essence was taken.
static func _heart(torso: Node3D, bw: float, glow: Color) -> void:
	var heart := MeshInstance3D.new()
	heart.name = "Heart"
	var disc := SphereMesh.new()
	disc.radius = 0.075
	disc.height = 0.15
	disc.radial_segments = 16
	disc.rings = 8
	heart.mesh = disc
	heart.scale = Vector3(1.0, 1.0, 0.25)
	heart.position = Vector3(-0.085, 0.48, -0.228 * bw)      # (the left of the chest, clear of the strap)
	heart.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := void_mat(4, 0, glow)
	mat.set_shader_parameter("planar", true)
	mat.set_shader_parameter("extent", Vector2(0.06, 0.06))
	mat.set_shader_parameter("pulse", 1.0)
	mat.set_shader_parameter("halo", 0.5)
	heart.material_override = mat
	torso.add_child(heart)
