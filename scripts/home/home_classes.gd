class_name HomeClasses
extends RefCounted
## The Hunters screen on the farm (J or the Hunters button; docs/decisions/0005). On the left every
## Hunter as a small tile: open, ready to unlock, in progress or locked, with its goal's progress. On
## the right the Hunter viewer (HunterViewer) for the one you clicked: the big model playing its
## abilities, and under it what you can do with it: play it, hold to unlock it (HoldUnlock, then the
## reveal), or the goal it still needs. Your account level, its XP and the next free pick sit on top.
## Rules and numbers: content/rules/class_unlock.json, logic: ClassUnlock. (Internal names keep
## "class": the file, the save key and the ids.)

const TITLE := "Hunters"
const RANK := ["ready", "open", "progress", "locked"]
const TILE_W := 176.0          # px, one Hunter tile (two per row)
const STAGE := Vector2(290, 330)

static func open(home: Node, sel := "") -> void:
	if sel == "" or not Arch.exists(sel):
		sel = String(home.get_meta("hunters_sel", ""))
	if sel == "" or not Arch.exists(sel):
		sel = _first_ready()
	if sel == "":
		sel = Arch.of_save()
	home.set_meta("hunters_sel", sel)
	home.set_meta("hero_hover", sel)          # (K opens its kit card)
	var v: VBoxContainer = home._new_panel(TITLE, 1210, true)
	UI.subtitle(v,
			"Who you play. New Hunters open as you play; when one is ready, hold to unlock it. K: the full kit card.")
	var top := UI.hbox(12)
	top.add_child(_account_row())
	var note := _pick_note()
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(note)
	v.add_child(top)
	var cols := UI.hbox(16)
	v.add_child(cols)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cols.add_child(grid)
	for id in ordered():
		grid.add_child(_tile(home, String(id), String(id) == sel))
	home.set_meta("classes_grid", grid)
	home.set_meta("hero_grid", grid)
	var right := UI.vbox(10)
	cols.add_child(right)
	var viewer := HunterViewer.make(sel, STAGE)
	right.add_child(_actions(home, sel, viewer))      # (above the viewer: the hold is the first thing you see)
	right.add_child(viewer)
	home.set_meta("hunter_viewer", viewer)
	UI.footer_left(v).add_child(UI.ghost("Kit card (K)", func(): HomeHero.kit(home, sel), 0))

## Every Hunter: ready ones first, then open, in progress and locked; each group in the usual order.
static func ordered() -> Array:
	var out: Array = []
	for rank in RANK:
		for a in Arch.ids():
			if ClassUnlock.status(String(a)) == rank: out.append(a)
	return out

static func _first_ready() -> String:
	for a in Arch.ids():
		if ClassUnlock.status(String(a)) == "ready": return String(a)
	return ""

## One small tile: portrait, name, and where it stands.
static func _tile(home: Node, id: String, on: bool) -> PanelContainer:
	var st := ClassUnlock.status(id)
	var col := Arch.color(id)
	var card := UI.tile_card(on, func(): _show(home, id), 6, col)
	card.custom_minimum_size = Vector2(TILE_W, 0)
	card.set_meta("arch", id)
	card.set_meta("class_status", st)
	var row := UI.hbox(8)
	card.add_child(row)
	row.add_child(ClassCard.portrait(id, 48.0))
	var c := UI.vbox(1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c)
	c.add_child(UI.label(Arch.name_of(id), 15, col if st in ["open", "ready"] else UI.FAINT, UI.big))
	var cur := id == Arch.of_save()
	match st:
		"open": c.add_child(UI.label("Playing" if cur else "Unlocked", 11, UI.GOOD, UI.semi))
		"ready": c.add_child(UI.label("Ready: hold to unlock", 11, ClassCard.GOAL_COL, UI.semi))
		_:
			var gp := ClassUnlock.goal_progress(id)
			c.add_child(UI.label("%d / %d" % [int(gp["have"]), int(gp["need"])] if st == "progress" else "Locked", 11,
					ClassCard.GOAL_COL if st == "progress" else UI.FAINT))
			var gb := UI.bar(float(gp["frac"]), ClassCard.GOAL_COL, 100.0, 5.0)
			gb.set_meta("goal_block", id)
			c.add_child(gb)
	card.tooltip_text = ClassCard.kit_tip(id)
	if st != "open": card.tooltip_text = ("Locked: %s\n" % ClassUnlock.requirement(id)) + card.tooltip_text
	if st == "locked": card.modulate = Color(0.62, 0.62, 0.68, 0.9)
	elif st == "progress": card.modulate = Color(0.82, 0.82, 0.88, 0.96)
	return card

## Under the viewer: Play it, hold to unlock it, or what it still needs.
static func _actions(home: Node, id: String, viewer: HunterViewer) -> Control:
	var box := UI.vbox(6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	match ClassUnlock.status(id):
		"open":
			if id == Arch.of_save():
				var pl := UI.label("You're playing %s. Your expeditions start with it." % Arch.name_of(id),
						UI.T_SMALL, UI.GOOD, UI.semi)
				pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				box.add_child(pl)
			else:
				var b := UI.primary("Play %s" % Arch.name_of(id), func(): HomeHero.pick(home, id), 260)
				b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				box.add_child(b)
		"ready":
			var hu := HoldUnlock.make(id, viewer)
			hu.done.connect(func(_id): _revealed(home, id))
			box.add_child(hu)
			home.set_meta("hold_unlock", hu)
			var why := "A free pick: any Hunter you like." if not ClassUnlock.earned(id) else "Its goal is done."
			var wl := UI.label(why, 12, UI.MUTED)
			wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(wl)
		_:
			var gb := ClassCard.goal_block(id, 300.0)
			gb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box.add_child(gb)
			var ne := ClassUnlock.next_early()
			if not ne.is_empty():
				var el := UI.label("Or: %s (%d/%d) for a free pick of any Hunter." % [String(ne["text"]),
						int(ne["have"]), int(ne["need"])], 12, UI.MUTED)
				el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				box.add_child(el)
	return box

## The hold finished: the burst plays on the viewer, then the reveal steps in over the farm.
static func _revealed(home: Node, id: String) -> void:
	if not is_instance_valid(home) or not home.is_inside_tree(): return
	var t: SceneTreeTimer = home.get_tree().create_timer(0.55)
	t.timeout.connect(func():
		if not is_instance_valid(home): return
		var rv := ClassReveal.show_for(home, id)
		rv.closed.connect(func(played): if not played and is_instance_valid(home): open(home, id)))

static func _show(home: Node, id: String) -> void:
	Sfx.play("hover", null, -6.0)
	open(home, id)

## A line for the free picks: one waiting, or the next early goal.
static func _pick_note() -> Label:
	var n := ClassUnlock.free_picks()
	if ClassUnlock.all_open():
		return UI.label("" if Game.modding() else "Every Hunter is open on this save.", 13, UI.GOOD)
	if n > 0:
		return UI.label("%d free pick%s: hold to unlock any locked Hunter." % [n, "" if n == 1 else "s"], 14,
				ClassCard.GOAL_COL, UI.semi)
	var ne := ClassUnlock.next_early()
	if ne.is_empty():
		return UI.label("Each Hunter opens with its own goal and account level.", 12, UI.MUTED)
	return UI.label("Next free pick: %s (%d/%d)" % [String(ne["text"]), int(ne["have"]), int(ne["need"])], 13, UI.INK)

## "Account level 3" with the XP bar to the next level.
static func _account_row() -> Control:
	var lv := ClassUnlock.level_of(ClassUnlock.xp())
	var card := UI.card(Color(ClassCard.GOAL_COL, 0.08), 10, 8)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := UI.hbox(12)
	card.add_child(row)
	row.add_child(UI.label("Account level %d" % int(lv[0]), 16, ClassCard.GOAL_COL, UI.big))
	row.add_child(UI.bar(float(lv[1]) / float(lv[2]), ClassCard.GOAL_COL, 200.0, 9.0))
	row.add_child(UI.label("%d / %d XP" % [int(lv[1]), int(lv[2])], 12, UI.MUTED))
	card.set_meta("account_level", int(lv[0]))
	return card

## Clicking a Hunter from elsewhere: play it if open, else show it here.
static func _click(home: Node, id: String) -> void:
	if ClassUnlock.is_open(id):
		HomeHero.pick(home, id)
	else:
		open(home, id)
