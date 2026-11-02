class_name ClassCard
extends RefCounted
## Shared pieces for the class screens: the starter pick, the Classes screen and the farm picker.
## One look for "a class and where it stands": portrait, name, weight line, its goal and progress.

const GOAL_COL := Color("ffd27a")

## "Light weight · 124 health · 1 dash" for a class.
static func weight_line(id: String) -> String:
	var cd: Dictionary = Data.CLASSES[Arch.weight(id)]
	return "%s weight  ·  %d health  ·  %d dash%s" % [String(cd["name"]), int(cd["hp"]), int(cd["dashes"]), "es" if int(cd["dashes"]) > 1 else ""]

## The class's portrait as a TextureRect; the SubViewport that renders it is a child of the rect.
static func portrait(id: String, px := 84.0) -> TextureRect:
	var vp := Portraits.make(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), Save.d.get("look", {}), id)
	var tex := TextureRect.new()
	tex.texture = vp.get_texture()
	tex.custom_minimum_size = Vector2(px, px)
	tex.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.add_child(vp)
	return tex

## The goal block for a class that is not open yet: the goal, a progress bar with its count, and the
## account level it also needs. Returns a VBox (tagged "goal_block" with the progress as meta "frac").
static func goal_block(id: String, width := 190.0) -> VBoxContainer:
	var gp := ClassUnlock.goal_progress(id)
	var lv := ClassUnlock.level_needed(id)
	var v := UI.vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_meta("goal_block", id)
	v.set_meta("frac", float(gp["frac"]))
	var g := UI.para(ClassUnlock.goal_text(id), 13, GOAL_COL if float(gp["frac"]) > 0.0 else UI.INK)
	g.custom_minimum_size.x = width
	v.add_child(g)
	var row := UI.hbox(8); row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UI.bar(float(gp["frac"]), UI.GOOD if bool(gp["done"]) else GOAL_COL, width - 56.0, 8.0))
	row.add_child(UI.label("%d/%d" % [int(gp["have"]), int(gp["need"])], 12, UI.MUTED))
	v.add_child(row)
	var ok := ClassUnlock.level() >= lv
	v.add_child(UI.label("Account level %d%s" % [lv, " (reached)" if ok else ""], 12, UI.GOOD if ok else UI.MUTED))
	return v

## A class card for the Classes screen and the starter pick. `cb` runs on click.
## Dim when locked; shows the goal when it is not open.
static func make(id: String, on: bool, cb: Callable, tag := "") -> PanelContainer:
	var open := ClassUnlock.is_open(id)
	var card := UI.tile_card(on, cb, 10, Arch.color(id))
	card.custom_minimum_size = Vector2(262, 0)
	card.set_meta("arch", id)
	card.set_meta("class_status", ClassUnlock.status(id))
	var row := UI.hbox(10)
	card.add_child(row)
	row.add_child(portrait(id))
	var col := UI.vbox(2); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(UI.label(Arch.name_of(id), 18, Arch.color(id) if open else UI.FAINT, UI.big))
	col.add_child(UI.label(weight_line(id), 12, UI.MUTED))
	var fan := UI.para(String(Arch.def(id).get("fantasy", "")), 12, UI.INK if open else UI.FAINT)
	fan.custom_minimum_size.x = 160
	col.add_child(fan)
	if tag != "":
		col.add_child(UI.label(tag, 12, UI.GOOD, UI.semi))
	elif not open:
		col.add_child(goal_block(id, 170.0))
	if not open:
		card.modulate = Color(0.62, 0.62, 0.68, 0.9) if ClassUnlock.status(id) == "locked" else Color(0.85, 0.85, 0.9, 0.95)
	return card

## The results screen's account line: XP gained, the level bar, and any class this run opened.
static func results_strip(s: Dictionary) -> Control:
	var cu: Dictionary = s.get("class_unlock", {})
	var v := UI.vbox(4)
	if cu.is_empty():
		return v
	var lv := ClassUnlock.level_of(ClassUnlock.xp())
	var row := UI.hbox(10)
	row.add_child(UI.label("Account  +%d XP" % int(cu.get("xp", 0)), UI.T_SMALL, UI.MUTED))
	row.add_child(UI.label("Level %d" % int(lv[0]), UI.T_SMALL, UI.INK, UI.semi))
	row.add_child(UI.bar(float(lv[1]) / float(lv[2]), GOAL_COL, 120.0, 8.0))
	if int(cu.get("level_after", 1)) > int(cu.get("level_before", 1)):
		row.add_child(UI.label("Level up!", UI.T_SMALL, UI.GOOD, UI.semi))
	v.add_child(row)
	for id in cu.get("unlocked", []):
		v.add_child(UI.label("New class: %s. Pick it under Hero on the farm." % Arch.name_of(String(id)), UI.T_SMALL, Arch.color(String(id)), UI.semi))
	return v
