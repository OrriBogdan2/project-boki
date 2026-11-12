class_name AbilityText
extends RefCounted
## The one place an archetype's ability words are read (content/archetypes/*.json): the HUD slot and
## its tooltip, the kit card and its strip, the hero pick and the first-time hints all call these, so
## a slot says the same name and the same numbers everywhere.
##   name_of / short_name  the full and the one-word name (the dash and E fx words, the strip)
##   line                  one line (kit card rows, pick, hints); the JSON "card" text, else the description
##   full                  the whole description (HUD tooltip, card detail page)
## Texts may hold `{key:ACTION}` (the player's own key through Settings.key_cap, never a letter) and
## `{slot.field}` (a number from the same JSON, e.g. {e.time}), both filled here.

## A slot, however the caller spells it ("sec" for the HUD, "rmb" for the card), to its JSON block.
const BLOCK := {"dash": "dash", "dodge": "dash", "rmb": "rmb", "sec": "rmb", "utility": "rmb",
	"e": "e", "k1": "e", "kin": "e", "r": "r", "ult": "r", "x": "x", "passive": "passive"}
## The right-click variants in the order they are told, and how a row is headed.
const VARIANTS := {"tap": "Tap", "hold": "Hold", "air": "In the air", "during_e": "During {key:signature}",
	"full": "Resource full"}
const DECIMALS := 2      # digits a number keeps ({e.every} 0.35 stays 0.35)

static var _token: RegEx

## The text with its `{key:...}` and `{slot.field}` tokens filled in for this archetype.
static func fill(arch: String, text: String) -> String:
	if not text.contains("{"):
		return text
	if _token == null:
		_token = RegEx.create_from_string("\\{([^}]+)\\}")
	var d := Arch.def(arch)
	var out := text
	for m in _token.search_all(text):
		var tok := m.get_string(1)
		if tok.begins_with("key:"):
			out = out.replace(m.get_string(), Settings.key_cap(tok.substr(4)))
			continue
		var v: Variant = d
		for part in tok.split("."):
			v = (v as Dictionary).get(part, 0.0) if v is Dictionary else 0.0
		out = out.replace(m.get_string(), String.num(float(v), DECIMALS))
	return out

static func block(arch: String, slot: String) -> Dictionary:
	return Arch.def(arch).get(BLOCK.get(slot, slot), {})

## "Heavy Shot", "Hawk Sense", the signature weapon's name for the attack.
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
	var sd := block(arch, slot)
	return fill(arch, String(card.get(BLOCK.get(slot, slot), sd.get("desc", ""))))

## The signature weapon's (or any of the kit's weapons') card line.
static func weapon_line(arch: String, weapon: String) -> String:
	var wl: Dictionary = Arch.def(arch).get("card", {}).get("weapons", {})
	return fill(arch, String(wl.get(weapon, Data.weapon_stats(weapon).get("desc", ""))))

## The whole description; the right click has no single one: its variants, one per line.
static func full(arch: String, slot: String) -> String:
	var sd := block(arch, slot)
	if BLOCK.get(slot, slot) != "rmb":
		return fill(arch, String(sd.get("desc", "")))
	return "\n".join(variant_rows(arch).map(func(r): return "%s: %s" % r))

## The right click's variants as [heading, text] rows.
static func variant_rows(arch: String) -> Array:
	var vs: Dictionary = block(arch, "rmb").get("variants", {})
	var rows: Array = []
	for v in VARIANTS:
		if vs.has(v):
			rows.append([fill(arch, VARIANTS[v]), fill(arch, String(vs[v]))])
	return rows

## The role in a sentence (the hero pick, the arena toast).
static func loop(arch: String) -> String:
	return fill(arch, String(Arch.def(arch).get("card", {}).get("loop", "")))
