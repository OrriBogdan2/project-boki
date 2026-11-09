class_name HomeClasses
extends RefCounted
## The Hunters screen on the farm (J or the Hunters button; docs/decisions/0005). On the left every
## Hunter as a small tile: open, ready to unlock, in progress or locked, with its challenge's progress;
## under the tiles the picked Hunter's mastery goals and your glider. On the right the Hunter viewer
## (HunterViewer) and what you can do with it: play it, hold to unlock it (HoldUnlock, then the reveal),
## or the challenge it still needs. Rules and numbers: content/rules/class_unlock.json, logic:
## ClassUnlock. (Internal names keep "class": the file, the save key and the ids.)

const TITLE := "Relics"
const RANK := ["ready", "open", "progress", "locked"]
const TILE_W := 140.0          # px, one Hunter tile
const TILE_COLS := 3
const LEFT_W := TILE_W * TILE_COLS + 16.0      # px, the tiles with their gaps: mastery and the glider pick match it
const STAGE := Vector2(180, 240)
const CLIP := Vector2(150, 84)        # px: each ability clip beside the turntable

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
	UI.subtitle(v, "Who you play. Every Hunter opens with its own challenge, then hold to unlock it. "
			+ "K: the full kit card.")
	var cols := UI.hbox(16)
	v.add_child(cols)
	var left := UI.vbox(10)
	cols.add_child(left)
	var grid := GridContainer.new()
	grid.columns = TILE_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left.add_child(grid)
	for id in ordered():
		grid.add_child(_tile(home, String(id), String(id) == sel))
	home.set_meta("classes_grid", grid)
	home.set_meta("hero_grid", grid)
	var details := UI.vbox(10)
	left.add_child(details)
	var right := UI.vbox(10)
	cols.add_child(right)
	var acts := UI.vbox(0)      # (above the viewer: the hold is the first thing you see)
	right.add_child(acts)
	var viewer := HunterViewer.make(sel, STAGE, CLIP, 3)
	right.add_child(viewer)
	home.set_meta("hunter_viewer", viewer)
	home.set_meta("hunters_parts", [details, acts])
	_fill(home, sel, viewer)
	var kit := func(): HomeHero.kit(home, String(home.get_meta("hunters_sel")))
	UI.footer_left(v).add_child(UI.ghost("Kit card (K)", kit, 0))

## The picked Hunter's mastery goals and glider (left) and what you can do with it (over the viewer).
static func _fill(home: Node, id: String, viewer: HunterViewer) -> void:
	var details: Control = home.get_meta("hunters_parts")[0]
	var acts: Control = home.get_meta("hunters_parts")[1]
	for c in details.get_children() + acts.get_children():
		c.queue_free()
	details.add_child(ClassCard.mastery_list(id, LEFT_W))
	details.add_child(_glider_pick(home, id))
	acts.add_child(_actions(home, id, viewer))

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
	var card := UI.tile_card(on, func(): _show.call_deferred(home, id), 6, col)      # (deferred: it swaps this tile)
	card.custom_minimum_size = Vector2(TILE_W, 0)
	card.set_meta("arch", id)
	card.set_meta("class_status", st)
	var row := UI.hbox(8)
	card.add_child(row)
	row.add_child(ClassCard.portrait(id, 36.0))
	var c := UI.vbox(1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c)
	var name_label := UI.label(Arch.hunter_name(id), 14, col if st in ["open", "ready"] else UI.FAINT, UI.big)
	name_label.clip_text = true
	c.add_child(name_label)
	var cur := id == Arch.of_save()
	match st:
		"open": c.add_child(UI.label("Playing" if cur else "Unlocked", 11, UI.GOOD, UI.semi))
		"ready": c.add_child(UI.label("Hold to unlock", 11, ClassCard.GOAL_COL, UI.semi))
		_:
			var gp := ClassUnlock.challenge_progress(id)
			c.add_child(UI.label("%d / %d" % [int(gp["have"]), int(gp["need"])] if st == "progress" else "Locked", 11,
					ClassCard.GOAL_COL if st == "progress" else UI.FAINT))
			var gb := UI.bar(float(gp["frac"]), ClassCard.GOAL_COL, TILE_W - 56.0, 5.0)
			gb.set_meta("tile_bar", id)
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
				var pl := UI.label("You're playing %s. Your expeditions start with it." % Arch.name_of(id, true),
						UI.T_SMALL, UI.GOOD, UI.semi)
				pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				box.add_child(pl)
			else:
				var b := UI.primary("Play %s" % Arch.name_of(id, true), func(): HomeHero.pick(home, id), 260)
				b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				box.add_child(b)
		"ready":
			var hu := HoldUnlock.make(id, viewer)
			hu.done.connect(func(_id): _revealed(home, id))
			box.add_child(hu)
			home.set_meta("hold_unlock", hu)
			var wl := UI.label("Challenge done: %s" % ClassUnlock.challenge_text(id), 12, UI.MUTED)
			wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(wl)
		_:
			var gb := ClassCard.challenge_block(id, 300.0)
			gb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box.add_child(gb)
	return box

## The hold finished: the burst plays on the viewer, then the reveal steps in over the farm.
static func _revealed(home: Node, id: String) -> void:
	if not is_instance_valid(home) or not home.is_inside_tree(): return
	var t: SceneTreeTimer = home.get_tree().create_timer(0.55)
	t.timeout.connect(func():
		if not is_instance_valid(home): return
		var rv := ClassReveal.show_for(home, id)
		rv.closed.connect(func(played): if not played and is_instance_valid(home): open(home, id)))

## Picks another Hunter on the open screen: only its two tiles, the viewer and the details change (the rest
## stays, so a click never rebuilds the whole screen).
static func _show(home: Node, id: String) -> void:
	Sfx.play("hover", null, -6.0)
	var viewer = home.get_meta("hunter_viewer", null)
	var grid = home.get_meta("classes_grid", null)
	if home.panel_open != TITLE or not is_instance_valid(viewer) or not is_instance_valid(grid):
		open(home, id)
		return
	var was := String(home.get_meta("hunters_sel", ""))
	home.set_meta("hunters_sel", id)
	home.set_meta("hero_hover", id)
	for old in (grid as GridContainer).get_children():
		var aid := String(old.get_meta("arch"))
		if aid == id or aid == was:
			var at := old.get_index()
			grid.remove_child(old)
			old.queue_free()
			var tile := _tile(home, aid, aid == id)
			(grid as GridContainer).add_child(tile)
			(grid as GridContainer).move_child(tile, at)
	_fill(home, id, viewer)
	home.get_tree().process_frame.connect(func():      # (the viewer next frame: one frame doesn't do both)
		if is_instance_valid(viewer): (viewer as HunterViewer).set_hunter(id), CONNECT_ONE_SHOT)

## Your glider: every skin you own as a chip (a click glides on it from now on), and the one this
## Hunter's mastery gives, with how to earn it. Gliders are looks only (Gliders).
static func _glider_pick(home: Node, id: String) -> Control:
	var v := UI.vbox(4)
	v.set_meta("glider_pick", true)
	v.add_child(UI.label("Glider", 12, UI.MUTED, UI.caps))
	var flow := HFlowContainer.new()
	flow.custom_minimum_size.x = LEFT_W
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	for g in Gliders.LIST:
		var gid := String(g["id"])
		var from_here: bool = ClassUnlock.reward_source("glider", gid).get("id", "") == id
		if not Gliders.owned(gid) and not from_here:
			continue
		var b := UI.choice(String(g["name"]), gid == Gliders.equipped(), func(): _glide_on(home, id, gid), 0)
		b.set_meta("glider", gid)
		b.disabled = not Gliders.owned(gid)
		b.tooltip_text = String(g["desc"]) if not b.disabled else "Earned by %s" % Gliders.how(gid)
		flow.add_child(b)
	return v

static func _glide_on(home: Node, id: String, glider_id: String) -> void:
	if not Gliders.equip(glider_id):
		return
	Save.save_game()
	Sfx.play("whoosh", null, -10.0, 0.0, 1.2)
	open(home, id)

## Clicking a Hunter from elsewhere: play it if open, else show it here.
static func _click(home: Node, id: String) -> void:
	if ClassUnlock.is_open(id):
		HomeHero.pick(home, id)
	else:
		open(home, id)
