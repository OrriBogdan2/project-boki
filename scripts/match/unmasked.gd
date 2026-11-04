class_name Unmasked
extends RefCounted
## The Unmasked: your own character. A smooth, near-faceless person with no nose and no race or species
## features: a body (gender, height, build), a few marks for a face (eyes, brows, blush), an outfit and one
## body colour. Masks fill you in: in a match you are the Warden (mask_look), and look["marks"] holds
## features a mask left on you (drawn here, empty for now).
## Built by Models.hunter on the hunter rig, so every HunterAnim animation plays on it as it is.

const GENDERS := ["Feminine", "Masculine"]
const HEIGHTS := ["Short", "Average", "Tall"]
const HEIGHT_SCALE := [0.92, 1.0, 1.08]     # x the hunter's size
const BUILDS := ["Slight", "Average", "Sturdy"]       # body width in Models.hunter: 0.88 / 1.0 / 1.15
const EYES := ["Round", "Calm", "Sleepy", "Happy", "Narrow", "Starry"]
const BROWS := ["None", "Soft", "Straight", "Raised", "Furrowed"]
const BLUSH := ["None", "Soft", "Rosy"]
const OUTFITS := ["Traveller", "Scholar", "Smith", "Sailor", "Festival"]
const OUTFIT_COL := [3, 1, 4, 2, 5]      # each outfit's colourway: an index into Models.OUTFIT_COLS
const COLOURS := [Color("f1e6d6"), Color("e3c9a8"), Color("d2a77f"), Color("b27c58"), Color("86573a"), Color("5a3b2a"),
	Color("a9c7e8"), Color("b9d8b0"), Color("c9b8e8"), Color("f0b8c8"), Color("c4c8d2"), Color("e8d27a")]
## The creator's rows: look key, label, choices (colours show as a swatch).
const ROWS := [
	["gender", "Gender", GENDERS], ["height", "Height", HEIGHTS], ["build", "Build", BUILDS],
	["eyes", "Eyes", EYES], ["brows", "Brows", BROWS], ["blush", "Blush", BLUSH],
	["outfit", "Outfit", OUTFITS], ["colour", "Colour", COLOURS],
]

## Old creator face (Models.LOOK_FACES) -> the closest eyes.
const EYES_FROM_FACE := [0, 1, 2, 3, 4, 3, 5, 4, 1]
## Old outfit (Models.LOOK_OUTFITS) -> the closest new one.
const OUTFIT_FROM_OLD := [4, 1, 0, 0, 2, 2, 3, 2, 4]

static func default_look() -> Dictionary:
	return {"unmasked": true, "gender": 1, "height": 1, "build": 1, "eyes": 0, "brows": 2, "blush": 0,
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
	for row in ROWS:
		out[row[0]] = clampi(_i(out[row[0]], 0), 0, (row[2] as Array).size() - 1)
	if not out["marks"] is Array:
		out["marks"] = []
	return out

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
	var gender := clampi(_i(old.get("gender"), 1), 0, 1)
	var face := clampi(_i(old.get("face"), 0), 0, Models.LOOK_FACES.size() - 1)
	var race := clampi(_i(old.get("race"), 0), 0, Models.RACES.size() - 1)
	var reach := float(Models.RACES[race]["scale"])
	var outfit := clampi(_i(old.get("outfit"), 3), 0, Models.LOOK_OUTFITS.size() - 1)
	var skin := clampi(_i(old.get("skin"), 1), 0, Models.LOOK_SKIN.size() - 1)
	out["gender"] = gender
	out["build"] = clampi(_i(old.get("body"), 1), 0, 2)
	out["height"] = _height_for(reach)
	out["eyes"] = EYES_FROM_FACE[face]
	out["brows"] = _brows_for(face, gender)
	out["blush"] = 1 if gender == 0 or face == 3 else 0
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

## The look a Warden wears in a match and on hero screens: never your own face (the mask-look rules
## decide what shows; for now a plain Warden). Only the glider is yours.
static func mask_look() -> Dictionary:
	var out := Models.default_look()
	out["glider"] = String(Save.d.get("look", {}).get("glider", "classic"))
	return out

## An Unmasked as the old look dictionary Models.hunter builds from: no race, no hair, no details.
static func legacy(lk: Dictionary) -> Dictionary:
	var u := clean(lk)
	return {
		"race": 0, "body": u["build"], "gender": u["gender"], "face": 1, "skin": 0, "hair": 13, "hair_v": 2,
		"hair_col": 0, "detail": 0, "outfit": OUTFIT_COL[u["outfit"]], "glider": u.get("glider", "classic"),
	}

## The race entry Models.hunter reads: always human, sized by height.
static func race(lk: Dictionary) -> Dictionary:
	return {"id": "human", "name": "Human", "scale": HEIGHT_SCALE[clean(lk)["height"]],
		"head": 1.0, "bulk": 1.0, "skin": 1, "desc": ""}

static func colour(lk: Dictionary) -> Color:
	return COLOURS[clean(lk)["colour"]]

# ------------------------------------------------------------------------------------------ face
## The face marks on the smooth head: flat eyes, brows, blush, and any kept mask marks. No nose, no mouth.
static func face(torso: Node3D, lk: Dictionary, skin: Color) -> void:
	var u := clean(lk)
	var fem := int(u["gender"]) == 0
	var mark := Models.toon(_ink(skin), false)
	for sx in [-1.0, 1.0]:
		_eye(torso, int(u["eyes"]), sx, 1.25 if fem else 1.1, mark, skin)
		_brow(torso, int(u["brows"]), sx, fem, mark)
	if int(u["blush"]) > 0:
		var blush := Models.toon(skin.lerp(Color("ff6a7a"), 0.35 + 0.2 * int(u["blush"])), false)
		for sx in [-1.0, 1.0]:
			_dot(torso, 0.03, blush, Vector3(0.14 * sx, 0.815, -0.185), Vector3(1.1, 0.6, 0.4))
	for m in u["marks"]:
		var md: Dictionary = m
		var col := Models.toon(Color(String(md.get("col", "#ffffff"))), false)
		var at := Vector3(float(md.get("x", 0.0)), float(md.get("y", 0.85)), -0.215)
		_dot(torso, float(md.get("size", 0.02)), col, at, Vector3(1.0, 1.0, 0.3))

static func _ink(skin: Color) -> Color:
	return Color("2b2a33") if skin.get_luminance() > 0.3 else Color("f4efe6")

static func _dot(torso: Node3D, r: float, mat: Material, at: Vector3, squash: Vector3, rot := Vector3.ZERO) -> void:
	Models.part(torso, Models.sphere(r, 10), mat, at, squash, rot)

## One eye on the side `sx` (-1 left, 1 right); `es` sizes it (a little larger for the feminine face).
static func _eye(torso: Node3D, kind: int, sx: float, es: float, mark: Material, skin: Color) -> void:
	var ex: float = 0.095 * sx
	var y := 0.868
	var shine := Models.toon(Color.WHITE, false, 1.0)
	match kind:
		0:   # round
			_dot(torso, 0.036 * es, mark, Vector3(ex, y, -0.211), Vector3(0.85, 1.15, 0.3))
			_dot(torso, 0.011 * es, shine, Vector3(ex + 0.012, y + 0.016, -0.226), Vector3.ONE)
		1:   # calm
			_dot(torso, 0.03 * es, mark, Vector3(ex, y, -0.212), Vector3(0.9, 1.0, 0.3))
		2:   # sleepy
			var lid := Models.box(0.062 * es, 0.014, 0.014)
			Models.part(torso, lid, mark, Vector3(ex, y - 0.006, -0.214), Vector3.ONE, Vector3(0, 0, 0.12 * sx))
		3:   # happy: a smiling arc (the lower half of a ring is covered by a patch of body)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.022 * es
			ring.outer_radius = 0.034 * es
			ring.rings = 28
			ring.ring_segments = 10
			Models.part(torso, ring, mark, Vector3(ex, y - 0.01, -0.213), Vector3(1.0, 1.0, 0.4), Vector3(PI / 2, 0, 0))
			Models.part(torso, Models.box(0.08, 0.032, 0.03), Models.toon(skin, false), Vector3(ex, y - 0.032, -0.215))
		4:   # narrow
			_dot(torso, 0.034 * es, mark, Vector3(ex, y, -0.212), Vector3(1.0, 0.45, 0.3), Vector3(0, 0, -0.22 * sx))
		5:   # starry
			_dot(torso, 0.04 * es, mark, Vector3(ex, y, -0.21), Vector3(0.85, 1.15, 0.3))
			_dot(torso, 0.014 * es, shine, Vector3(ex + 0.013, y + 0.018, -0.227), Vector3.ONE)
			_dot(torso, 0.007 * es, shine, Vector3(ex - 0.012, y - 0.02, -0.226), Vector3.ONE)

static func _brow(torso: Node3D, style: int, sx: float, fem: bool, mat: Material) -> void:
	if style == 0:
		return
	var tilt: float = {1: 0.15, 2: 0.0, 3: 0.35, 4: -0.4}[style] * sx
	var bar := Models.box(0.062, 0.014, 0.014) if fem else Models.box(0.08, 0.024, 0.014)
	var at := Vector3(0.095 * sx, 0.943 + (0.012 if style == 3 else 0.0), -0.208)
	Models.part(torso, bar, mat, at, Vector3.ONE, Vector3(0, 0, tilt))

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
