class_name DashFlow
extends RefCounted
## How a hero's dash and its abilities flow into each other (briefs/OWNER_REVIEW_1103.md #32). One small table
## per hero in content/dash_interactions/<arch>.json lists each pair with its rule: "buffer" (the press waits
## for the dash to end, BUFFER_T), "fire" (it works during the dash) or "cancel" (it ends the other move).
## A hero without a table is untouched. Inputs pressed during a dash are never silently dropped.

const BUFFER_T := 0.15
const BUF_KEY := "dash_buf_lmb"
const PREV_KEY := "dash_prev_lmb"
static var _tables := {}

static func table(arch: String) -> Dictionary:
	if not _tables.has(arch):
		var path := "res://content/dash_interactions/%s.json" % arch
		var parsed: Variant = null
		if FileAccess.file_exists(path):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		_tables[arch] = parsed if parsed is Dictionary else {}
	return _tables[arch]

## The rule for a pair ("dash_ground" -> "lmb"), or "" when the hero has none.
static func rule(arch: String, from: String, to: String) -> String:
	for p in (table(arch).get("pairs", []) as Array):
		if String(p["from"]) == from and String(p["to"]) == to:
			return String(p["rule"])
	return ""

## The attack key as the weapon should see it: a press that came in during a dash is carried for
## BUFFER_T past the dash's end when the hero's table says "buffer".
static func held(h: Hunter, down: bool, dt: float) -> bool:
	if rule(h.arch, "dash_ground", "lmb") != "buffer":
		return down
	var buf := float(h.get_meta(BUF_KEY, 0.0))
	var pressed := down and not bool(h.get_meta(PREV_KEY, false))
	h.set_meta(PREV_KEY, down)
	if h.roll_t > 0.0:
		h.set_meta(BUF_KEY, BUFFER_T if pressed else buf)
		return down
	if buf > 0.0:
		h.set_meta(BUF_KEY, buf - dt)
		return true
	return down
