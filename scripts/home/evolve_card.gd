class_name EvolveCard
extends RefCounted
## What a player is told after a Boki changes form at home (after the moment, EvolveMoment).
## The first form change on a save gets one centred card: old and new form side by side, one line on
## why, the stat changes as bars with the gain, and a link to the new form's Field Book page. Later
## changes get a small toast. A Boki that reached its level but waits for a form with no art yet is
## told once that it is ready and will change when its new form arrives. Plain words, no jargon.

const STATS := [["hp", "Health"], ["dmg", "Strength"], ["speed", "Speed"]]
const PORTRAIT := 96.0  # px: each form's picture on the card
const BAR := Vector2(210, 10)  # px: a stat bar
const CARD_WIDTH := 560.0


## The one line on why it changed: "Level 16: Minkee grew into Flarmink" or "The Ember Ink did it".
static func why(ev: Dictionary) -> String:
	var a := _species_name(String(ev.get("from_id", "")))
	var b := _species_name(String(ev.get("to_id", "")))
	match String(ev.get("how", "level")):
		"item":
			return "The %s did it." % Goods.name_of("good:" + String(ev.get("item", "")))
		"trade":
			return "It changed on its way to a new keeper."
	return "Level %d: %s grew into %s" % [int(ev.get("lv", 1)), a, b]


static func _species_name(id: String) -> String:
	return String(Data.KIN.get(id, {}).get("name", id))


## The stat rows between two species: [{name, old, new, max}], `max` the biggest any species has.
static func stat_rows(from_id: String, to_id: String) -> Array:
	var rows: Array = []
	for s in STATS:
		var top := 1.0
		for sp: Dictionary in Data.KIN.values():
			top = maxf(top, float(sp.get(s[0], 0.0)))
		rows.append(
			{
				"name": s[1],
				"old": float(Data.KIN[from_id].get(s[0], 0.0)),
				"new": float(Data.KIN[to_id].get(s[0], 0.0)),
				"max": top
			}
		)
	return rows


## "+12", "-3" or "same"; a fraction (speed) keeps one decimal.
static func gain_text(old: float, new: float) -> String:
	var d := snappedf(new - old, 0.1)
	if d == 0.0:
		return "same"
	var mag := absf(d)
	var digits := str(int(mag)) if is_equal_approx(mag, roundf(mag)) else "%.1f" % mag
	return ("+" if d > 0.0 else "-") + digits


## Does this event have what the card needs (an older save's queued event may not)?
static func can_card(ev: Dictionary) -> bool:
	return (
		String(ev.get("kind", "")) == "form"
		and Data.KIN.has(String(ev.get("from_id", "")))
		and Data.KIN.has(String(ev.get("to_id", "")))
	)


## Called when the moment ends. `home` is the farm screen. The first form change gets the card, later
## ones a toast; growth that isn't a new form (a part) keeps the plain panel.
static func show(home: Node, rec: Dictionary, evs: Array) -> void:
	var forms := evs.filter(func(e: Dictionary) -> bool: return can_card(e))
	var tut: Dictionary = Save.d["tutorial"]
	if forms.is_empty():
		var v: VBoxContainer = home._new_panel("%s is changing" % rec["name"], 520)
		for e: Dictionary in evs:
			v.add_child(UI.label(String(e.get("text", Evo.describe(e, rec))), 16, Evo.AFF[e["aff"]]["tint"]))
		return
	if bool(tut.get("first_evolve", false)):
		for e: Dictionary in forms:
			home._toast(String(e.get("text", Evo.describe(e, rec))))
		return
	tut["first_evolve"] = true
	Save.save_game()
	build(home, rec, forms[forms.size() - 1])


## The card itself, as a centred panel on the farm screen.
static func build(home: Node, rec: Dictionary, ev: Dictionary) -> void:
	var from_id := String(ev["from_id"])
	var to_id := String(ev["to_id"])
	var v: VBoxContainer = home._new_panel("%s evolved" % rec["name"], CARD_WIDTH)
	var forms := UI.hbox(26)
	forms.alignment = BoxContainer.ALIGNMENT_CENTER
	forms.add_child(_form(from_id, rec, "Before"))
	forms.add_child(UI.label("→", 34, UI.MUTED))
	forms.add_child(_form(to_id, rec, "Now"))
	v.add_child(forms)
	var line := UI.label(why(ev), 17, Evo.AFF[ev["aff"]]["tint"])
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(line)
	for r: Dictionary in stat_rows(from_id, to_id):
		v.add_child(_stat_row(r))
	var page := UI.button(
		"See its page",
		func() -> void:
			home._close_panel()
			Overlay.inv_tab = "Field Book"
			Overlay.open_inventory()
			Overlay.open_dex(to_id)
	)
	page.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(page)


static func _form(id: String, rec: Dictionary, caption: String) -> Control:
	var col := UI.vbox(4)
	var look := {"species": id, "level": rec.get("level", 1), "uid": "evo|" + id}
	var pic := KinPortrait.view(look, Engine.get_main_loop() as SceneTree, PORTRAIT)
	var c := CenterContainer.new()
	c.add_child(pic)
	col.add_child(c)
	var n := UI.label(_species_name(id), 16, UI.INK)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(n)
	var cap := UI.label(caption, 12, UI.MUTED)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	return col


## One stat: its name, a bar (the part it had, then the gain in green or the loss in red), the change.
static func _stat_row(r: Dictionary) -> Control:
	var row := UI.hbox(12)
	var nm := UI.label(String(r["name"]), 15, UI.INK)
	nm.custom_minimum_size.x = 84
	row.add_child(nm)
	var lo := minf(float(r["old"]), float(r["new"])) / float(r["max"])
	var hi := maxf(float(r["old"]), float(r["new"])) / float(r["max"])
	var up := float(r["new"]) >= float(r["old"])
	var bar := Control.new()
	bar.custom_minimum_size = BAR
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.draw.connect(
		func() -> void:
			UI.draw_bar(bar, Rect2(Vector2.ZERO, bar.size), hi, UI.GOOD if up else UI.BAD)
			UI.draw_bar(bar, Rect2(Vector2.ZERO, bar.size), lo, UI.ACCENT, Color(0, 0, 0, 0))
	)
	row.add_child(bar)
	var gain := gain_text(float(r["old"]), float(r["new"]))
	row.add_child(UI.label(gain, 15, UI.GOOD if gain.begins_with("+") else UI.MUTED))
	return row


## Tells the first Boki on `kins` that is ready but waits for art, once each. One per call, so a
## farm of waiting Boki isn't flooded.
static func tell_waiting(home: Node, kins: Array) -> void:
	for k: Dictionary in kins:
		var rec: Dictionary = k["rec"]
		if bool(rec.get("wait_told", false)) or Evo.waiting(rec) == "":
			continue
		rec["wait_told"] = true
		home._toast("%s is ready to change. It will once its new form arrives." % rec["name"])
		return
