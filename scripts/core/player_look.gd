class_name PlayerLook
extends RefCounted
## The player's own person, saved as Save.d["look"]: body and face sliders as normalised values
## (0..1, 0.5 = neutral; the keys are content/rules/mantle_look.json "sliders") and picks (gender,
## folk, expression, skin, hair style and colour, eye colour, markings, outfit colour, glider).
## Purely visual. MantleLook turns it into a model: the player at home, or a Bearer of a Mantle in a
## match. See docs/decisions/0011-mantle-look.md.

## Eye colours a player can pick (new entries only ever go on the end, so saved looks keep theirs).
const EYES := [Color("4a3a2a"), Color("6a4a2a"), Color("5a6a3a"), Color("2a6a4a"), Color("3a5a8a"), Color("5a7a9a"),
	Color("7a6a9a"), Color("7a2a4a"), Color("e8c050"), Color("9a9aa8")]
const EYE_NAMES := ["Dark brown", "Brown", "Hazel", "Green", "Blue", "Grey-blue", "Violet", "Wine", "Amber", "Grey"]
## The picks and the list each one indexes.
const PICKS := ["race", "gender", "face", "skin", "hair_col", "eyes", "detail", "outfit"]
const NEUTRAL := 0.5
const SLIDER_STEP := 0.001      # sliders are saved to this step (a saved look loads back exactly)

## A neutral person: every slider in the middle, the first face, the default colours.
static func neutral() -> Dictionary:
	return {"race": 0, "gender": 1, "face": 0, "skin": 1, "hair": 0, "hair_v": 2, "hair_col": 0, "eyes": 0,
		"detail": 0, "outfit": 3, "sliders": neutral_sliders()}

static func neutral_sliders() -> Dictionary:
	var out := {}
	for k in slider_keys():
		out[k] = NEUTRAL
	return out

## The slider keys, in the order the creator shows them.
static func slider_keys() -> Array:
	return (MantleLook.rules()["sliders"] as Dictionary).keys()

## A random person (bots and background hunters): any folk and style, the folk's own colouring most
## of the time, every slider anywhere.
static func random(rng: RandomNumberGenerator = null) -> Dictionary:
	var roll := func(n: int) -> int: return (rng.randi() if rng else randi()) % n
	var race := int(roll.call(Models.RACES.size()))
	var skin := int(Models.RACES[race]["skin"])
	if int(roll.call(3)) == 0:
		skin = int(roll.call(Models.LOOK_SKIN.size()))
	if race == 0:
		skin = int(roll.call(8))
	var glider := "classic"
	if int(roll.call(5)) >= 3:
		glider = String(Gliders.LIST[int(roll.call(Gliders.LIST.size()))]["id"])
	var out := {"glider": glider, "race": race, "gender": roll.call(2), "face": roll.call(Models.LOOK_FACES.size()),
		"skin": skin, "hair": roll.call(Models.hair_styles(race).size()), "hair_v": 2,
		"hair_col": roll.call(Models.LOOK_HAIR.size()), "eyes": roll.call(EYES.size()),
		"detail": roll.call(Models.LOOK_DETAILS.size()), "outfit": roll.call(Models.LOOK_OUTFITS.size())}
	# the sliders never draw on the global random stream: a seeded match must play out the same
	# whatever its bots look like (the picks above take as many draws as the looks before sliders)
	var slider_rng := rng
	if slider_rng == null:
		slider_rng = RandomNumberGenerator.new()
		slider_rng.seed = hash(out)
	var sliders := {}
	for k in slider_keys():
		sliders[k] = slider_rng.randf()
	out["sliders"] = sliders
	return out

## A saved look with every pick inside its list and every slider in 0..1 (missing ones neutral).
## Older looks: a third gender option, hair indexed into the shared list (no "hair_v"), the Slim /
## Average / Sturdy "body" pick the build slider replaced.
static func clean(lk: Dictionary) -> Dictionary:
	var out := neutral()
	out.merge(lk, true)
	out.erase("body")
	for k in PICKS:
		out[k] = clampi(int(out[k]), 0, pick_list(k).size() - 1)
	var rid := String(Models.RACES[int(out["race"])]["id"])
	if not lk.has("hair_v") and Models.HAIR_FROM_OLD.has(rid):
		out["hair"] = Models.HAIR_FROM_OLD[rid][clampi(int(out["hair"]), 0, Models.LOOK_HAIRS.size() - 1)]
	out["hair_v"] = 2
	out["hair"] = clampi(int(out["hair"]), 0, Models.hair_styles(int(out["race"])).size() - 1)
	var given = lk.get("sliders", {})
	var sliders := neutral_sliders()
	if typeof(given) == TYPE_DICTIONARY:
		for k in sliders:
			sliders[k] = snappedf(clampf(float(given.get(k, NEUTRAL)), 0.0, 1.0), SLIDER_STEP)
	out["sliders"] = sliders
	return out

## The list a pick indexes (the outfit pick: its colourway names; Models.OUTFIT_COLS holds the colours).
static func pick_list(key: String) -> Array:
	match key:
		"race": return Models.LOOK_RACES
		"gender": return Models.LOOK_GENDERS
		"face": return Models.LOOK_FACES
		"skin": return Models.LOOK_SKIN
		"hair_col": return Models.LOOK_HAIR
		"eyes": return EYES
		"detail": return Models.LOOK_DETAILS
	return Models.LOOK_OUTFITS

## Save v7 -> v8: the look gets its sliders, all neutral (so a Bearer looks exactly like the Warden
## until the player opens the creator), and keeps every pick it had; the old "body" pick goes.
static func migrate(data: Dictionary) -> void:
	if typeof(data.get("look")) == TYPE_DICTIONARY:
		data["look"] = clean(data["look"])
