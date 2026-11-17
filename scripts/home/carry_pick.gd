class_name CarryPick
extends RefCounted
## Home side of the carry rule (docs/decisions/0061-carry-pick.md): at the expedition portal you pick
## a lead Boki (Save "active") and an optional second (Save "active2", empty unless you pick one).
## One selectable Boki means you go with one. Cards show the carry passive in one plain line, and say
## so when both Boki give the same passive, because it counts once.

## The carry passive of a Boki as one plain line.
static func passive_line(rec: Dictionary) -> String:
	var ks := KinLib.kin(String(rec.get("species", "")))
	if ks == null or ks.carry_passives.is_empty():
		return "Carry: no passive"
	return "Carry: " + KinText.passives(ks.carry_passives)

## The passives two Boki both give (same stat), as plain words; empty when none.
static func shared(a: Dictionary, b: Dictionary) -> String:
	var ka := KinLib.kin(String(a.get("species", "")))
	var kb := KinLib.kin(String(b.get("species", "")))
	if ka == null or kb == null: return ""
	var out := PackedStringArray()
	for pa in ka.carry_passives:
		for pb in kb.carry_passives:
			if pa["stat"] == pb["stat"]: out.append(KinText.owner_stat(String(pa["stat"]), float(pa["amount"])))
	return ", ".join(out)

## Boki you can take: not held for ransom or lost (KinLoss.selectable).
static func choices() -> Array:
	return (Save.d["roster"] as Array).filter(func(r): return KinLoss.selectable(r))

## Can the player bring a second at all (two Boki or more to choose from)?
static func has_second_slot() -> bool:
	return choices().size() > 1

## Make `uid` the lead. If it was the second, the two swap.
static func set_lead(uid: String) -> void:
	if str(Save.d.get("active2", "")) == uid: Save.d["active2"] = str(Save.d.get("active", ""))
	Save.d["active"] = uid

## Make `uid` the second ("" for none). The lead can't be the second.
static func set_second(uid: String) -> void:
	if uid != str(Save.d.get("active", "")): Save.d["active2"] = uid

## The uid `dir` steps from the current one in the slot's choices (the second also cycles through "none").
static func step(key: String, dir: int) -> String:
	var lead := str(Save.d.get("active", ""))
	var ids: Array = choices().map(func(r): return String(r["uid"]))
	if key == "active2":
		ids = ids.filter(func(u): return u != lead)
		ids.append("")
	var i := ids.find(str(Save.d.get(key, "")))
	return ids[(i + dir + ids.size()) % ids.size()] if not ids.is_empty() else ""

## One portal card: ‹ › to change who, the Boki's line, and its carry passive.
static func card(label_t: String, rec: Dictionary, key: String, on_change: Callable, note := "") -> Control:
	var card := UI.card(UI.CARD, 10, 10)
	var row := UI.hbox(10)
	card.add_child(row)
	var go := func(dir: int) -> void:
		var uid := step(key, dir)
		if key == "active": set_lead(uid)
		else: set_second(uid)
		Save.save_game()
		on_change.call()
	var prev_b := UI.icon_button("back", func(): go.call(-1), "Previous Boki", 12.0)
	prev_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(prev_b)
	var info := UI.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if rec.is_empty():
		info.add_child(UI.label("%s: none" % label_t, 16, UI.MUTED, UI.big))
		info.add_child(UI.label("Go with one Boki. Only it is at risk.", 12, UI.MUTED))
	else:
		var sp: Dictionary = Data.KIN[rec["species"]]
		var kcol: Color = Color(sp["color"]).lerp(Color.WHITE, 0.25)
		var dot := UI.badge("paw", kcol, 36.0)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var nl := UI.label(Data.kin_title(String(rec["name"]), String(sp["name"])), 17, UI.INK, UI.big)
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.clip_text = true
		info.add_child(nl)
		var boxed := KinBox.is_boxed(rec)
		var asleep := "  ·  asleep in the Boki Burrow: comes out to go with you" if boxed else ""
		var stats := "%s  ·  level %d  ·  trust %d" % [label_t, int(rec.get("level", 1)), int(rec["trust"])]
		var sl := UI.label(stats + asleep, 12, Color("cdb8ff") if boxed else UI.MUTED)
		sl.autowrap_mode = TextServer.AUTOWRAP_OFF
		info.add_child(sl)
		var pl := UI.label(passive_line(rec), 12, UI.MUTED)
		pl.autowrap_mode = TextServer.AUTOWRAP_OFF
		pl.clip_text = true
		info.add_child(pl)
		if note != "": info.add_child(UI.label(note, 12, UI.GOOD))
	row.add_child(info)
	var next_b := UI.icon_button("next", func(): go.call(1), "Next Boki", 12.0)
	next_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(next_b)
	return card

## The lead and second cards for the portal; the second shows only with two or more Boki to choose from.
static func add_cards(into: Control, on_change: Callable) -> void:
	var lead := Save.active_kin()
	if lead.is_empty(): return
	var second := Save.second_kin() if has_second_slot() else {}
	var note := "" if second.is_empty() else _same_note(lead, second)
	into.add_child(card("Lead", lead, "active", on_change, note))
	if has_second_slot(): into.add_child(card("Second", second, "active2", on_change, note))

static func _same_note(lead: Dictionary, second: Dictionary) -> String:
	var same := shared(lead, second)
	return "" if same == "" else "Both give %s: it counts once" % same
