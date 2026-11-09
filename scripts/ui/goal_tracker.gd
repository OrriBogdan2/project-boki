class_name GoalTracker
extends RefCounted
## The "Goals" card at the top right of the farm: what you are working towards, never the tutorial.
## Rows come from four sources, caps and the title in content/rules/farm_tutorial.json "tracker":
##   unlock    a Hunter's unlock challenge (ClassUnlock), for every Hunter not open yet
##   mastery   the goals of the Hunter you play that are not done
##   milestone a farm milestone not reached (FarmUnlocks)
##   level     the next farm level, always last
## A row: {text, have, need, frac, ready, source}. Ready-to-claim rows lead; inside a source the
## closest to done comes first. The card is hidden when there are no rows.

const SOURCE_ORDER := ["unlock", "mastery", "milestone", "level"]

static func cfg() -> Dictionary:
	return FarmTutorial.rules()["tracker"]

static func lines() -> Array:
	var by_source := {"unlock": _unlocks(), "mastery": _mastery(), "milestone": _milestones(), "level": _level()}
	var caps: Dictionary = cfg()["per_source"]
	var picked: Array = []
	for src in SOURCE_ORDER:
		var rows: Array = by_source[src]
		rows.sort_custom(func(a, b): return _closer(a, b))
		picked.append_array(rows.slice(0, int(caps.get(src, 1))))
	picked.sort_custom(func(a, b):
		if bool(a["ready"]) != bool(b["ready"]):
			return bool(a["ready"])
		return SOURCE_ORDER.find(a["source"]) < SOURCE_ORDER.find(b["source"]))
	return picked.slice(0, int(cfg()["max"]))

static func _closer(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a["frac"]), float(b["frac"])):
		return float(a["frac"]) > float(b["frac"])
	return String(a["text"]) < String(b["text"])

static func _row(text: String, prog: Dictionary, source: String, ready := false) -> Dictionary:
	return {"text": text, "have": int(prog["have"]), "need": int(prog["need"]), "frac": float(prog["frac"]),
			"ready": ready, "source": source}

static func _unlocks() -> Array:
	var out: Array = []
	if ClassUnlock.needs_starters() or ClassUnlock.all_open():
		return out
	for id in Arch.ids():
		var hid := String(id)
		if ClassUnlock.status(hid) == "open":
			continue
		var prog := ClassUnlock.challenge_progress(hid)
		out.append(_row(ClassUnlock.challenge_text(hid), prog, "unlock", ClassUnlock.can_unlock(hid)))
	return out

static func _mastery() -> Array:
	var out: Array = []
	var id := Arch.of_save()
	var goals := ClassUnlock.mastery(id)
	for i in goals.size():
		var prog := ClassUnlock.mastery_progress(id, i)
		if not bool(prog["done"]):
			out.append(_row(String(goals[i]["text"]), prog, "mastery"))
	return out

static func _milestones() -> Array:
	var out: Array = []
	if not FarmUnlocks.gated():
		return out
	var ms: Dictionary = FarmUnlocks.rules()["milestones"]
	for id in ms:
		if FarmUnlocks.milestone_done(String(id)):
			continue
		var need := int(ms[id]["n"])
		var have := mini(FarmUnlocks.stat(String(ms[id]["stat"])), need)
		out.append(_row(String(ms[id]["text"]), _prog(have, need), "milestone"))
	return out

static func _level() -> Array:
	var p := FarmUnlocks.progress()
	if not FarmUnlocks.gated() or float(p[1]) <= 0.0:
		return []
	var need := int(ceil(float(p[1])))
	var have := mini(int(float(p[0])), need)
	return [_row("Reach farm level %d" % (FarmUnlocks.level() + 1), _prog(have, need), "level")]

static func _prog(have: int, need: int) -> Dictionary:
	return {"have": have, "need": need, "frac": float(have) / float(need)}

## A short string that changes when what the card shows changes (to know when to rebuild it).
static func signature() -> String:
	return "|".join(lines().map(func(r): return "%s:%d/%d:%s" % [r["text"], r["have"], r["need"], r["ready"]]))

## The card, or null when there is nothing to show.
static func build() -> PanelContainer:
	var rows := lines()
	if rows.is_empty():
		return null
	var box := UI.glass(12, 14, 0.5)
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -316
	box.offset_right = -16
	box.offset_top = 14
	var v := UI.vbox(7)
	box.add_child(v)
	v.add_child(UI.section(String(cfg()["title"])))
	for r in rows:
		v.add_child(_row_ui(r))
	return box

static func _row_ui(r: Dictionary) -> Control:
	var col := UI.vbox(3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := UI.hbox(8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(r["ready"]):
		head.add_child(Icons.Glyph.new("gem", UI.GOLD, 12.0))
	var text := UI.label(String(r["text"]), 14, UI.GOLD if bool(r["ready"]) else UI.INK)
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.clip_text = true
	text.custom_minimum_size.x = 190
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(text)
	head.add_child(UI.label("%d/%d" % [r["have"], r["need"]], 12, UI.MUTED, UI.caps))
	col.add_child(head)
	col.add_child(UI.bar(float(r["frac"]), UI.GOLD if bool(r["ready"]) else UI.GOOD, 270.0, 4.0))
	return col
