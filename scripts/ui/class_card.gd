class_name ClassCard
extends RefCounted
## Shared pieces for the Hunter screens: the Hunters screen, the practice picker and the results line.
## One look for "a Hunter and where it stands": portrait, its unlock challenge and its mastery goals.

const GOAL_COL := Color("ffd27a")

## The Hunter's portrait, `px` square: its Warden's painted face (Portraits.Pic), or with `body` its
## splash (the reveal). A Warden with no painted art shows its rendered model instead: a TextureRect
## with the SubViewport that renders it as its child (`body`: the whole standing hunter).
static func portrait(id: String, px := 84.0, body := false) -> Control:
	if Portraits.has_art(id):
		var pic := Portraits.Pic.new(id, Vector2(px, px), Arch.color(id), body)
		pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		return pic
	var vp := Portraits.make(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), Unmasked.mask_look(), id,
			body, int(px * 2.0) if body else Portraits.SIZE)
	var tex := TextureRect.new()
	tex.texture = vp.get_texture()
	tex.custom_minimum_size = Vector2(px, px)
	tex.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.add_child(vp)
	return tex

## The challenge block for a Hunter that is not open yet: the challenge, a progress bar with its count, and
## its tier. Returns a VBox (tagged "challenge_block" with the progress as meta "frac").
static func challenge_block(id: String, width := 190.0) -> VBoxContainer:
	var gp := ClassUnlock.challenge_progress(id)
	var v := UI.vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_meta("challenge_block", id)
	v.set_meta("frac", float(gp["frac"]))
	var g := UiText.para(ClassUnlock.challenge_text(id), 13, GOAL_COL if float(gp["frac"]) > 0.0 else UI.INK)
	g.custom_minimum_size.x = width
	v.add_child(g)
	var row := UI.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiWidgets.bar(float(gp["frac"]), UI.GOOD if bool(gp["done"]) else GOAL_COL, width - 56.0, 8.0))
	row.add_child(UiText.label("%d/%d" % [int(gp["have"]), int(gp["need"])], 12, UI.MUTED))
	v.add_child(row)
	var needed := ClassUnlock.open_needed(id)
	var tier_line := "%s challenge" % ClassUnlock.tier(id).capitalize()
	if needed > ClassUnlock.open_ids().size():
		tier_line += "  ·  opens once %d Relics are open" % needed
	v.add_child(UiText.label(tier_line, 12, UI.MUTED))
	return v

## A Hunter's mastery: its level, then each goal with its counter and the cosmetic it gives. Tagged
## "mastery_list" (meta "level").
static func mastery_list(id: String, width := 330.0) -> VBoxContainer:
	var goals := ClassUnlock.mastery(id)
	var v := UI.vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_meta("mastery_list", id)
	v.set_meta("level", ClassUnlock.mastery_level(id))
	var head := UI.hbox(8)
	head.add_child(UiText.label("Mastery", 12, UI.MUTED, UI.caps))
	head.add_child(UiText.label("level %d / %d" % [ClassUnlock.mastery_level(id), goals.size()], 12, GOAL_COL, UI.semi))
	v.add_child(head)
	for i in goals.size():
		v.add_child(_mastery_row(id, i, width))
	return v

static func _mastery_row(id: String, i: int, width: float) -> Control:
	var g: Dictionary = ClassUnlock.mastery(id)[i]
	var gp := ClassUnlock.mastery_progress(id, i)
	var done := bool(gp["done"])
	var row := UI.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta("mastery_goal", i)
	var gl := UiText.label(String(g["text"]), 12, UI.GOOD if done else UI.INK)
	gl.custom_minimum_size.x = width * 0.5
	gl.clip_text = true
	row.add_child(gl)
	row.add_child(UiText.label("%d/%d" % [int(gp["have"]), int(gp["need"])], 11, UI.MUTED))
	var rw: Dictionary = g["reward"]
	var reward := "%s: %s" % [ClassUnlock.reward_kind_name(String(rw["kind"])), String(rw["name"])]
	var reward_label := UiText.label(reward, 11, GOAL_COL if done else UI.FAINT)
	if done:
		reward_label.add_theme_font_override("font", UI.semi)
	row.add_child(reward_label)
	row.tooltip_text = "%s\nReward: %s%s" % [String(g["text"]), reward, " (earned)" if done else ""]
	return row

## A Hunter's kit in one tooltip: its name, then dash, passive, RMB, E and R.
static func kit_tip(id: String) -> String:
	var adf := Arch.def(id)
	var names := [Arch.name_of(id)]
	for slot in ["dash", "passive", "rmb", "e"]:
		names.append(String(adf[slot]["name"]))
	names.append(Settings.key_cap("ultimate"))
	return "%s\nDash: %s  ·  Passive: %s\nRMB: %s  ·  E: %s  ·  %s: Boki Fusion" % names

## The results screen's Hunter line: mastery goals this expedition finished, and a Hunter unlock that
## became ready.
static func results_strip(s: Dictionary) -> Control:
	var cu: Dictionary = s.get("class_unlock", {})
	var v := UI.vbox(4)
	for m in cu.get("mastered", []):
		var rw: Dictionary = m["reward"]
		var ml := UiText.label("%s mastery: %s  ·  %s %s" % [Arch.name_of(String(m["id"])), String(m["text"]),
				ClassUnlock.reward_kind_name(String(rw["kind"])), String(rw["name"])], UI.T_SMALL, GOAL_COL, UI.semi)
		ml.set_meta("mastery_done", String(m["id"]))
		v.add_child(ml)
	if int(cu.get("new", 0)) > 0:
		var nl := UiText.label("Relic challenge done! Hold to unlock it on the Relics screen at home.", UI.T_SMALL,
				GOAL_COL, UI.semi)
		nl.set_meta("hunter_unlock_ready", int(cu["new"]))
		v.add_child(nl)
	return v
