class_name NookRules
## The Nesting Nook's gate and preview (docs: briefs/design/GARDEN.md section 6). A base-only player can
## meet every gate: both Grown, both friends, both rested since their last egg, one egg in the nest.

const GROWN_LV: int = Care.STAGES[2][0]     # the level a Boki is Grown
const REST_SEC := 1200.0                    # seconds a parent rests after laying an egg
const FRIEND_BOND := 50.0                   # a bond (or, with none recorded, trust) that counts as friends

## Why this one Boki can't be paired right now ("" when it can).
static func can_pair(rec: Dictionary) -> String:
	if not Save.d.get("egg", {}).is_empty(): return "There's already an egg in the nest"
	if int(rec["level"]) < GROWN_LV: return "Needs to be Grown (level %d)" % GROWN_LV
	var since_egg := Time.get_unix_time_from_system() - float(rec.get("bred_t", 0.0))
	if since_egg < REST_SEC: return "Needs a rest after its last egg"
	if KinBox.full(): return "Your farm and the Boki Burrow are full"
	return ""

## Friends: a bond of 50 or more either way. rec["bonds"] (uid -> bond) is not on every build yet; with
## none recorded on either, trust 50 or more on both stands in.
static func friends(a: Dictionary, b: Dictionary) -> bool:
	var ba: Dictionary = a.get("bonds", {})
	var bb: Dictionary = b.get("bonds", {})
	if ba.is_empty() and bb.is_empty():
		return float(a["trust"]) >= FRIEND_BOND and float(b["trust"]) >= FRIEND_BOND
	return float(ba.get(b["uid"], 0.0)) >= FRIEND_BOND or float(bb.get(a["uid"], 0.0)) >= FRIEND_BOND

## Why these two can't be paired ("" when they can).
static func pair_why(a: Dictionary, b: Dictionary) -> String:
	var why := can_pair(a)
	if why == "": why = can_pair(b)
	if why == "" and not friends(a, b): why = "%s and %s need to be friends" % [a["name"], b["name"]]
	return why

## The Nook's side panel for a pair: the two possible species, the lean head start, the unstable note.
static func preview(dv: VBoxContainer, a: Dictionary, b: Dictionary) -> void:
	var na: String = Data.KIN[a["species"]]["name"]
	var nb: String = Data.KIN[b["species"]]["name"]
	var kinds := na if na == nb else "%s or a %s" % [na, nb]
	dv.add_child(UI.para("The egg will be a %s, with a blend of their personalities." % kinds, 12, UI.MUTED))
	var lean: Dictionary = Care.stronger(a, b).get("lean", {})
	if not lean.is_empty():
		var top: String = lean.keys().reduce(func(x, y): return x if float(lean[x]) >= float(lean[y]) else y)
		var line := "Head start: it takes after %s's lean toward %s." % [Care.stronger(a, b)["name"], top]
		dv.add_child(UI.para(line, 12, UI.MUTED))
	var unstable := UnstableMix.preview_line(a, b)
	if unstable != "": dv.add_child(UI.para(unstable, 12, UI.MUTED))
	var why := pair_why(a, b)
	if why != "": dv.add_child(UI.para(why, 12, UI.BAD))
