class_name ModelsLook
## Hunter looks, races, outfits and class marks. Moved out of Models; callers still use the Models facade.


# ---------------------------------------------------------------- hunters
## Looks a player can pick for their hunter. Purely visual: the body's size never changes the hitbox.
# Natural tones first, then the wild ones (sky, moss, lilac, gold, stone...). New entries only ever
# go on the end, so saved looks keep their colours.
const LOOK_SKIN := [Color("f6d3b0"), Color("f1c9a0"), Color("e0ac7e"), Color("c68a5c"), Color("9a6440"), Color("6e4428"), Color("4a2e1e"),
	Color("fff0e6"), Color("3a2216"), Color("8ab4ff"), Color("4a6ad8"), Color("8ad07a"), Color("4f8f45"), Color("c4a2f0"), Color("7a4ab8"),
	Color("ff9ab8"), Color("e8c050"), Color("5ac8c0"), Color("d8604a"), Color("9a9aa8"), Color("e8eef8"), Color("ff8a3a")]
const LOOK_HAIR := [Color("2b2124"), Color("5a3a26"), Color("9a6a3a"), Color("e8c87a"), Color("d8d2c8"), Color("c4462e"), Color("6a8aff"), Color("ff8ac8"),
	Color("f6efd8"), Color("8a2e2a"), Color("3ac8c0"), Color("8a4ad8"), Color("5ac85a"), Color("ff8a2a"), Color("c8a8ff"), Color("9af0c8"),
	Color("d81e3c"), Color("2a3a7a"), Color("fbfbfb"), Color("ffd84a")]
const LOOK_BODIES := ["Slim", "Average", "Sturdy"]
const LOOK_GENDERS := ["Female", "Male"]
const LOOK_FACES := ["Bright eyes", "Calm", "Sleepy", "Cheerful", "Fierce", "Wink", "Starry", "Determined", "Smug"]
const LOOK_HAIRS := ["Short", "Long", "Ponytail", "Bun", "Spiky", "Buzzed", "Bob", "Pigtails", "Braid", "Mohawk", "Afro", "Curly", "Swoop", "Bald"]
## What grows on each race's head: every race has its own styles (all take the hair colour). The
## look's "hair" is an index into its race's list (looks saved before this, without "hair_v", held an
## index into LOOK_HAIRS for every race, and are mapped to the closest style with HAIR_FROM_OLD).
const HAIR_STYLES := {
	"human": LOOK_HAIRS,
	"vulpin": ["Fluffy tuft", "Mane", "Long fur", "Brush tail", "Spiky fur", "Sleek", "Fringe"],
	"stoneborn": ["Crystal crown", "Crystal ridge", "Stone ridge", "Moss cap", "Geode"],
	"sprig": ["Leaf crown", "Flower bud", "Vine locks", "Sprout", "Petal bob", "Toadstool"],
	"scalefolk": ["Crest", "Frills", "Horns", "Spines", "Twin crest"],
	"owlet": ["Ear tufts", "Feather crest", "Plume", "Fluffy crown", "Swept back", "Long plumes"],
}
## Old shared-list index (Short, Long, Ponytail, Bun, Spiky, Buzzed, Bob, Pigtails, Braid, Mohawk,
## Afro, Curly, Swoop, Bald) to the closest style of each race.
const HAIR_FROM_OLD := {
	"vulpin": [0, 2, 3, 0, 4, 5, 6, 3, 3, 1, 1, 0, 6, 5],
	"stoneborn": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	"sprig": [3, 2, 2, 1, 0, 3, 4, 2, 2, 0, 5, 0, 4, 3],
	"scalefolk": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	"owlet": [0, 5, 2, 3, 1, 0, 4, 5, 2, 1, 3, 3, 4, 0],
}

## The head styles a race can pick from (by race index).
static func hair_styles(race: int) -> Array:
	return HAIR_STYLES[String(RACES[clampi(race, 0, RACES.size() - 1)]["id"])]
## Outfits: a player's own colourway (their clothes at home; in a match it only tints the Warden's
## palette, MantleLook). A caller can name one by key to dress any hunter in it (galleries). The keys
## stay as they were so saved looks keep their colours.
const LOOK_OUTFITS := ["Lilac", "Nightshade", "Glacier", "Sage", "Saddle", "Ember", "Ivory", "Tusk", "Gilded"]
const OUTFIT_KEYS := ["veil", "nyx", "kestrel", "sage", "marlow", "pyra", "bastion", "tusk", "halo"]
const OUTFIT_COLS := [Color("c9bcff"), Color("b06ae0"), Color("6ad0e0"), Color("9ee2a0"), Color("e0b05a"), Color("ff7a5a"), Color("e6dbc4"), Color("c08a5a"), Color("f2d47a")]
const LOOK_DETAILS := ["None", "Freckles", "Scar", "Face paint", "Stubble", "Beard", "Moustache", "Beauty mark"]

## Races: each one changes the whole silhouette (size, head, build and features), so hunters read as
## different people at a glance from the high match camera. Purely visual: the hitbox comes from the
## class, never the race. "skin": the skin colour picked when you switch to it.
const RACES := [
	{"id": "human", "name": "Human", "scale": 1.0, "head": 1.0, "bulk": 1.0, "skin": 1,
		"desc": "Adaptable folk from every corner of the Skylands."},
	{"id": "vulpin", "name": "Vulpin", "scale": 0.95, "head": 1.06, "bulk": 0.94, "skin": 2,
		"desc": "Fox-eared and quick, with a big brush of a tail."},
	{"id": "stoneborn", "name": "Stoneborn", "scale": 1.17, "head": 0.86, "bulk": 1.3, "skin": 19,
		"desc": "Huge, slow-spoken folk of living rock, with crystals growing out of them."},
	{"id": "sprig", "name": "Sprig", "scale": 0.8, "head": 1.26, "bulk": 0.86, "skin": 11,
		"desc": "Tiny forest sprites with leaf wings and far too much nerve."},
	{"id": "scalefolk", "name": "Scalefolk", "scale": 1.06, "head": 0.96, "bulk": 1.02, "skin": 12,
		"desc": "Sun-loving lizardfolk with a crest and a long tail."},
	{"id": "owlet", "name": "Owlet", "scale": 0.92, "head": 1.18, "bulk": 1.06, "skin": 2,
		"desc": "Wide-eyed bird folk with ear tufts and a feather tail."},
]
const LOOK_RACES := ["Human", "Vulpin", "Stoneborn", "Sprig", "Scalefolk", "Owlet"]

static func default_look() -> Dictionary:
	return {"race": 0, "body": 1, "gender": 1, "face": 0, "skin": 1, "hair": 0, "hair_v": 2, "hair_col": 0, "detail": 0, "outfit": 3}

## A random look for bots and background hunters: any race, any style, the race's own colouring
## most of the time.
static func random_look(rng: RandomNumberGenerator = null) -> Dictionary:
	var R := func(n: int) -> int: return (rng.randi() if rng else randi()) % n
	var race := int(R.call(RACES.size()))
	var skin: int = int(RACES[race]["skin"]) if int(R.call(3)) > 0 else int(R.call(LOOK_SKIN.size()))
	if race == 0: skin = int(R.call(8))
	var gl := "classic" if int(R.call(5)) < 3 else String(Gliders.LIST[int(R.call(Gliders.LIST.size()))]["id"])
	return {"glider": gl, "race": race, "body": R.call(3), "gender": R.call(2), "face": R.call(LOOK_FACES.size()), "skin": skin,
		"hair": R.call(hair_styles(race).size()), "hair_v": 2, "hair_col": R.call(LOOK_HAIR.size()), "detail": R.call(LOOK_DETAILS.size()),
		"outfit": R.call(LOOK_OUTFITS.size())}

## A saved look with every value inside its list (older saves had a third gender option).
static func clean_look(lk: Dictionary) -> Dictionary:
	var out := default_look()
	out.merge(lk, true)
	var lists := {"race": LOOK_RACES, "body": LOOK_BODIES, "gender": LOOK_GENDERS, "face": LOOK_FACES, "skin": LOOK_SKIN, "hair_col": LOOK_HAIR, "detail": LOOK_DETAILS, "outfit": LOOK_OUTFITS}
	for k in lists:
		out[k] = clampi(int(out[k]), 0, (lists[k] as Array).size() - 1)
	var rid := String(RACES[int(out["race"])]["id"])
	if not lk.has("hair_v") and HAIR_FROM_OLD.has(rid):
		out["hair"] = HAIR_FROM_OLD[rid][clampi(int(out["hair"]), 0, LOOK_HAIRS.size() - 1)]
	out["hair_v"] = 2
	out["hair"] = clampi(int(out["hair"]), 0, hair_styles(int(out["race"])).size() - 1)
	return out

## How each class reads at a glance from the match camera, whatever the race or outfit (purely
## visual): overall size on top of the class scale (about 0.88 / 1.0 / 1.18 in all), build, boots,
## weapon size, and the class emblem on the pack (light: a chevron, medium: a diamond, heavy: a shield).
## Stylized like a hero brawler: big heads and hands, small tidy feet, tapered limbs, and a strong
## shoulder line per class ("pad_l"/"pad_r": pauldron size each side, "hands": glove size).
const CLASS_LOOK := {
	"light": {"size": 0.95, "build": 0.84, "boots": 0.84, "weapon": 0.98, "pad_l": 0.78, "pad_r": 0.78, "hands": 1.14},
	"medium": {"size": 1.0, "build": 1.0, "boots": 0.92, "weapon": 1.15, "pad_l": 1.32, "pad_r": 0.86, "hands": 1.2},
	"heavy": {"size": 1.035, "build": 1.14, "boots": 1.06, "weapon": 1.42, "pad_l": 1.85, "pad_r": 1.85, "hands": 1.5},
}

## The class's own marks: its emblem on top of the pack in the class colour (seen from above), a
## trailing scarf for lights, a plated collar and back plate for heavies.
## The class colour, made vivid enough to read on a badge (its own material: hits flash per hunter).
static func class_mat(cls: String) -> ShaderMaterial:
	var cc: Color = Data.CLASSES.get(cls, {}).get("color", Color.WHITE)
	cc = Color.from_hsv(cc.h, maxf(cc.s, 0.6), maxf(cc.v, 0.95))
	var m := ModelsBase.toon(cc, true, 0.35)
	m.set_shader_parameter("gloss", 0.5)
	return m

## A named pivot on the torso that parts hang from (skirt, cape, scarf), made once and shared.
static func _pivot(torso: Node3D, nm: String, at: Vector3) -> Node3D:
	var n := torso.get_node_or_null(nm) as Node3D
	if n == null:
		n = Node3D.new(); n.name = nm; n.position = at
		torso.add_child(n)
	return n

static func _class_marks(torso: Node3D, cls: String, bw: float, m_acc: Material, m_trim: Material) -> void:
	var m_cls := class_mat(cls)
	var at := Vector3(0, 0.655, 0.27 * bw)
	var tilt := Vector3(-1.05, 0, 0)          # lying back on the rolled wing, facing up and back
	match cls:
		"light":
			for sx in [-1.0, 1.0]:
				ModelsBase.part(torso, ModelsBase.box(0.035, 0.15, 0.025), m_cls, at + Vector3(0.045 * sx, 0.0, 0.0), Vector3.ONE, tilt + Vector3(0, 0, 0.6 * sx))
		"medium":
			ModelsBase.part(torso, ModelsBase.box(0.12, 0.12, 0.025), m_cls, at, Vector3.ONE, tilt + Vector3(0, 0, PI * 0.25))
		"heavy":
			ModelsBase.part(torso, ModelsBase.box(0.2, 0.16, 0.03), m_cls, at + Vector3(0, 0.01, 0.0), Vector3.ONE, tilt)
			ModelsBase.part(torso, ModelsBase.box(0.08, 0.06, 0.032), m_trim, at + Vector3(0, 0.012, 0.005), Vector3.ONE, tilt)

## The hunter's chest and back as one smooth sculpted shape: narrow at the waist, full through the
## ribs, broad at the shoulders and rounded over into the neck. About 0.62 tall, centred.
static func torso_mesh() -> ArrayMesh:
	var key := "torso"
	if ModelsBase._lathes.has(key):
		return ModelsBase._lathes[key]
	var pts := PackedVector2Array([Vector2(0.0, -0.31), Vector2(0.13, -0.305), Vector2(0.2, -0.27), Vector2(0.218, -0.17), Vector2(0.205, -0.05),
		Vector2(0.212, 0.05), Vector2(0.236, 0.14), Vector2(0.248, 0.205), Vector2(0.236, 0.255), Vector2(0.19, 0.293), Vector2(0.11, 0.312), Vector2(0.0, 0.318)])
	var am := ModelsBase.lathe(ModelsBase.smooth_curve(pts, 4), 56)
	ModelsBase._lathes[key] = am
	return am
