class_name ArchText
extends RefCounted
## The one formatter for ability text. A hero's tooltip strings (content/archetypes/<id>.json) carry no
## typed numbers: each is a token, "{rmb.pin.dmg.0}" a number at that path in the same file, "{e.slow%}"
## the same as a percent (x100), "{dash.walk_k-1%}" a multiplier's gain as a percent, "{weapon.primary.rate}"
## from the signature weapon's file, "{cd2.sec}" / "{cd3.sec}" the cooldown at rank 2 / 3 and "{dmg2.sec%}"
## the damage gain, both from rank_cd / rank_dmg with the game's default steps (ArchKit.cd_k, Effects.level_k).
## Content loads archetypes through fill() once, so every reader (kit card, HUD tip, pick screen, practice,
## viewer) gets the filled text. A figure the kit code uses lives in this file and the code reads it from here.

const SLOT_BASE := {"sec": ["rmb", "cooldown"], "dash": ["dash", "cd"], "kin": ["e", "cooldown"]}
# default cooldown cut per rank past the first (rank_cd overrides)
const CD_STEP := {"sec": 0.1, "kin": 0.1, "dash": 0.15}
static var _token := RegEx.create_from_string("\\{([a-z0-9_.]+)(-1)?(%?)\\}")

## Replace every token in every string under `node` (a Dictionary or Array), in place; `kit` is the whole file.
static func fill(kit: Dictionary, node: Variant = null) -> void:
	var cur: Variant = kit if node == null else node
	for k in (cur.keys() if cur is Dictionary else range(cur.size())):
		var v: Variant = cur[k]
		if v is String and "{" in v:
			cur[k] = text(v, kit)
		elif v is Dictionary or v is Array:
			fill(kit, v)

## `s` with its tokens replaced by numbers from `kit`. A token with no number stays visible as {?path}.
static func text(s: String, kit: Dictionary) -> String:
	var out := s
	for m in _token.search_all(s):
		var v := number(kit, m.get_string(1))
		var shown := "{?%s}" % m.get_string(1)
		if not is_nan(v):
			v -= 1.0 if m.get_string(2) == "-1" else 0.0
			shown = fmt(v * 100.0 if m.get_string(3) == "%" else v, m.get_string(1).begins_with("cd"))
		out = out.replace(m.get_string(), shown)
	return out

## The number at a dotted path; NAN when there is none. Array steps are numbers ("pin.dmg.0").
static func number(kit: Dictionary, path: String) -> float:
	var seg := path.split(".")
	if seg[0] in ["cd", "cd2", "cd3", "dmg2", "dmg3"] and seg.size() == 2:
		return rank_value(kit, seg[0], seg[1])
	var cur: Variant = kit
	if seg[0] == "weapon":
		cur = {"weapon": weapon(String(kit.get("signature", "")))}
	for s in seg:
		if cur is Dictionary and cur.has(s):
			cur = cur[s]
		elif cur is Array and s.is_valid_int() and int(s) < cur.size():
			cur = cur[int(s)]
		else:
			return NAN
	return float(cur) if (cur is float or cur is int) else NAN

## The signature weapon's file (content/weapons/<id>.json), for "{weapon.primary.range}" tokens.
static func weapon(id: String) -> Dictionary:
	var path := "res://content/weapons/%s.json" % id
	var w: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return w if w is Dictionary else {}

## "cd": the slot's base cooldown, "cd2"/"cd3": at that rank; "dmg2"/"dmg3": the damage gained (a fraction).
static func rank_value(kit: Dictionary, what: String, slot: String) -> float:
	if not SLOT_BASE.has(slot):
		return NAN
	var rank := int(what.right(1)) if what != "cd" else 1
	var cd := what.begins_with("cd")
	var row: Array = kit.get("rank_cd" if cd else "rank_dmg", {}).get(slot, [])
	var step: float = 1.0 - float(CD_STEP[slot]) * (rank - 1) if cd else Effects.PER_LEVEL * (rank - 1) + 1.0
	var k: float = float(row[rank - 1]) if row.size() >= rank else step
	if cd:
		var base: Array = SLOT_BASE[slot]
		return float(kit[base[0]][base[1]]) * k
	return k - 1.0

## A figure as text: whole numbers bare, else two decimals (one for a cooldown).
static func fmt(v: float, coarse := false) -> String:
	var q := 10.0 if coarse else 100.0
	var r := floorf(v * q + 0.5 + 1e-6) / q
	return str(int(roundf(r))) if is_equal_approx(r, roundf(r)) else str(r)
