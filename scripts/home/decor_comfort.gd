class_name DecorComfort
extends RefCounted
## Decor with a purpose (briefs/design/GARDEN_MODERN.md section 5 rank 7). Every decoration in the build
## catalog has one comfort tag (HomeLayout.CATALOG "comfort": cosy, bright, wild or quiet). A zone holding
## `need` of one tag gets that tag's small named effect (content/rules/decor_comfort.json), listed on its
## zone card (ZoneCards). The effects read here: cosy in BaseLife naps, bright in SnackPatch.ripe, wild in
## GardenVisitor's looks, quiet in BaseLife squabbles. No scores: an effect is on or off.

static var _key := []          # [zone, deco count, layout uid] the cached tags were counted for
static var _on := []           # the tags whose effect is on for _key

static func rules() -> Dictionary:
	return Content.rules("decor_comfort")

static func tag_of(id: String) -> String:
	return String(HomeLayout.CATALOG.get(id, {}).get("comfort", ""))

## The tags whose effect is on in `zone`, in the rules' order. Cached until the zone's decorations change
## (a new piece raises the layout's uid, a removed one shrinks the list), so per-tick callers stay cheap.
static func active(zone: String) -> Array:
	var deco := _deco(zone)
	var key := [zone, deco.size(), int(_layout().get("uid", 0))]
	if key != _key:
		_key = key
		var count := {}
		for d in deco:
			var tag := tag_of(String(d[0]) if d is Array else String(d["id"]))
			count[tag] = int(count.get(tag, 0)) + 1
		_on = rules()["effects"].keys().filter(func(t): return int(count.get(t, 0)) >= int(rules()["need"]))
	return _on

## True when `tag`'s effect is on in the zone you are in.
static func on(tag: String) -> bool:
	return active(GardenZones.current()).has(tag)

## `tag`'s effect number (`key` in its rules) when it is on in the zone you are in, else `off`.
static func value(tag: String, key: String, off: float) -> float:
	return float(rules()["effects"][tag][key]) if on(tag) else off

## The zone card's lines: each effect on in `zone`, its name and what it does.
static func card_lines(zone: String) -> Array:
	var fx: Dictionary = rules()["effects"]
	return active(zone).map(func(t): return "%s: %s" % [fx[t]["name"], fx[t]["does"]])

## The decorations `zone` holds: a built zone's fixed pieces ([id, x, z, r], garden_zones.json build),
## else the save's own island, which every unbuilt zone shows (HomeLayout.of).
static func _deco(zone: String) -> Array:
	if ZoneLayout.built(zone):
		return GardenZones.info(zone)["build"]["deco"]
	return _layout().get("deco", [])

static func _layout() -> Dictionary:
	var L = Save.d.get("layout")
	return L if typeof(L) == TYPE_DICTIONARY else {}
