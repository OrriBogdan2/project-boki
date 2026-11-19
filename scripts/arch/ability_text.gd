class_name AbilityText
extends RefCounted
## The one reader of an archetype's ability words (content/archetypes/*.json): the HUD slot and its tooltip,
## the kit card and strip, the viewer, the E hint and the hero pick all call these, so a slot says the same
## name and the same numbers everywhere. Numbers are filled at load by ArchText; `{action}` tokens
## ("{dash}", "{fire}") are filled here from the player's own bindings (Settings.fill_keys), so a rebind shows.
##   name_of / short_name  the full and the one-word name
##   line                  one line (kit card rows, pick, hints): the JSON "card" text, else the description
##   full                  the whole description (HUD tooltip, card detail page)

## A slot, however the caller spells it ("sec" for the HUD, "rmb" for the card), to its JSON block.
const BLOCK := {
	"dash": "dash",
	"dodge": "dash",
	"rmb": "rmb",
	"sec": "rmb",
	"utility": "rmb",
	"e": "e",
	"k1": "e",
	"kin": "e",
	"r": "r",
	"ult": "r",
	"x": "x",
	"passive": "passive"
}
## The right-click variants in the order they are told, and how a row is headed.
const VARIANTS := {
	"tap": "Tap", "hold": "Hold", "air": "In the air", "during_e": "During {signature}", "full": "Resource full"
}


static func block(arch: String, slot: String) -> Dictionary:
	return Arch.def(arch).get(BLOCK.get(slot, slot), {})


## "Heavy Shot", "Hawk Sense"; for the attack, the signature weapon's name.
static func name_of(arch: String, slot: String) -> String:
	if slot == "lmb":
		var ws: Array = Arch.weapons(arch)
		return String(Data.weapon_stats(String(ws[0])).get("name", ws[0])) if not ws.is_empty() else ""
	return String(block(arch, slot).get("name", ""))


## The JSON "short" word ("Heavy"), else the name's first word. (The Bulwark dash's "short" is a distance.)
static func short_name(arch: String, slot: String) -> String:
	var s: Variant = block(arch, slot).get("short", "")
	return String(s) if s is String and s != "" else name_of(arch, slot).split(" ")[0]


## One line: the JSON "card" text for the slot, else its description (the attack: the weapon's line).
static func line(arch: String, slot: String) -> String:
	if slot == "lmb":
		var ws: Array = Arch.weapons(arch)
		return weapon_line(arch, String(ws[0])) if not ws.is_empty() else ""
	var card: Dictionary = Arch.def(arch).get("card", {})
	var text := String(card.get(BLOCK.get(slot, slot), block(arch, slot).get("desc", "")))
	return _keys(text)


## A kit weapon's card line.
static func weapon_line(arch: String, weapon: String) -> String:
	var wl: Dictionary = Arch.def(arch).get("card", {}).get("weapons", {})
	return _keys(String(wl.get(weapon, Data.weapon_stats(weapon).get("desc", ""))))


## The whole description; the right click has no single one: its variants, one per line.
static func full(arch: String, slot: String) -> String:
	if BLOCK.get(slot, slot) != "rmb":
		return _keys(String(block(arch, slot).get("desc", "")))
	return "\n".join(variant_rows(arch).map(func(r): return "%s: %s" % r))


## The right click's variants as [heading, text] rows.
static func variant_rows(arch: String) -> Array:
	var vs: Dictionary = block(arch, "rmb").get("variants", {})
	var rows: Array = []
	for v in VARIANTS:
		if vs.has(v):
			rows.append([_keys(VARIANTS[v]), _keys(String(vs[v]))])
	return rows


## The role in a sentence (the hero pick, the arena toast).
static func loop(arch: String) -> String:
	return _keys(String(Arch.def(arch).get("card", {}).get("loop", "")))


## `s` with the player's keys in it; most texts have no key token, and the HUD asks every frame.
static func _keys(s: String) -> String:
	return Settings.fill_keys(s) if "{" in s else s
