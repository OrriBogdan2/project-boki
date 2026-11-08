class_name FarmGuide
extends RefCounted
## The farm's guidance on screen (home.gd owns one): the Goals tracker in the top-right slot
## (GoalTracker), and while the tutorial runs, one prompt in the world over what to do next and one
## hint line at the bottom with a Skip button. The rules are FarmTutorial; none of it shows when
## visiting. Skipping puts the house down as a site if it isn't, so a skipper isn't stuck.

var h
var tracker: PanelContainer = null
var hint_box: PanelContainer = null
var hint_lbl: Label = null
var skip_row: HBoxContainer = null
var marker: Label3D = null
var crop_lbl: Label3D = null
var sig := ""
var t := 0.0
var detect_t := 0.0
var asking := false
var tree_t := 0.0
var tree_at := Vector3.INF
var tab_for := ""
var tree_what := ""

func _init(home) -> void:
	h = home

func build_ui() -> void:
	if h.root_ui == null:
		return
	refresh()

## Rebuilds the card and the hint now.
func refresh() -> void:
	if not h.visit.is_empty() or h.root_ui == null:
		return
	if is_instance_valid(tracker):
		tracker.queue_free()
	tracker = GoalTracker.build()
	sig = GoalTracker.signature()
	if tracker:
		h.root_ui.add_child(tracker)
		if is_instance_valid(h.panel_host):
			h.root_ui.move_child(tracker, h.panel_host.get_index())      # menus open on top of it
	_refresh_hint()

func tick(dt: float) -> void:
	if not h.visit.is_empty():
		return
	t += dt
	detect_t -= dt
	if h.hob:
		h.hob.tick(dt)
	if detect_t <= 0.0 and not h.npc_talk.is_open():      # the tutorial waits while someone talks
		detect_t = 0.5
		_poll()
	_update_marker(dt)
	_bubbles_under_lane(dt)
	var want_page: bool = FarmTutorial.current() == "task" and FarmTutorial.stage("task") == "go"
	FarmTaskGuide.hub_hint(h, want_page and h.panel_open == "")

func _poll() -> void:
	var was_done := bool(FarmTutorial.state()["done"])
	if FarmTutorial.active():
		FarmTutorial.detect()
		if FarmTutorial.current() == "feed":
			FarmTutorial.give_food()
		var cur := FarmTutorial.current()
		var tool := FarmTutorial.give_step_tool(cur) if cur != "" and h.panel_open == "" else ""
		if tool != "":
			h._toast(String(FarmTutorial.rules()["tool_toasts"].get(tool, "")))
		if (cur == "buy" or cur == "sell") and cur != tab_for:
			tab_for = cur      # the market opens on the tab the step wants
			h.hmk.vendor_tab = "Seeds" if cur == "buy" else "Sell"
		if cur == "buy":
			var gave := FarmTutorial.give_seed_gems()
			if gave > 0:
				h._toast(String(FarmTutorial.rules()["gems_toast"]) % gave)
				h._refresh_top()
	var st := FarmTutorial.state()
	if bool(st["done"]) and not was_done and not bool(st["skipped"]):
		var gems := str(int(FarmTutorial.option("end_gems")))
		h._toast(String(FarmTutorial.rules()["done_toast"]).replace("{gems}", gems))
		Sfx.play("unlock", null, -6.0)
		h._refresh_top()
	if GoalTracker.signature() != sig:
		refresh()
	else:
		_refresh_hint()

# ------------------------------------------------------------------ the hint line
func hint_visible() -> bool:
	return is_instance_valid(hint_box)

func _refresh_hint() -> void:
	var id := FarmTutorial.current()
	if id == "":
		_clear_hint()
		return
	if not is_instance_valid(hint_box):
		_make_hint()
	var s := FarmTutorial.hint_text(id)
	if id == "house" and FarmTutorial.stage(id) == "wait":
		s = "%s (%s)" % [s, _site_progress()]
	var voice := String(FarmTutorial.rules()["voice"])
	var grow := FarmCropGuide.growing()
	if not grow.is_empty() and id != "crop":
		s += "  (Your seed is ripe in %ds)" % int(ceil(float(grow["left"])))
	elif id == "crop" and not grow.is_empty():
		s = s.replace("{secs}", str(int(ceil(float(grow["left"])))))
	s = s.replace("{secs}", "a few")
	hint_lbl.text = "%d/%d  %s: %s" % [FarmTutorial.done_count() + 1, FarmTutorial.steps().size(), voice, s]
	# a long hint wraps at about 600 px (under the chips, clear of the Goals card) instead of running wide
	var fw := hint_lbl.get_theme_font("font").get_string_size(hint_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 6.0
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.custom_minimum_size.x = minf(fw, 600.0)

func _clear_hint() -> void:
	if is_instance_valid(hint_box):
		hint_box.queue_free()
	hint_box = null
	if is_instance_valid(marker):
		marker.queue_free()
	marker = null

func _site_progress() -> String:
	var e := FarmHob.house_entry()
	if e.is_empty() or not FarmSites.has_site(e):
		return "done"
	return "%d/%d swings" % [int(e["site"]["got"]), int(e["site"]["need"])]

func _make_hint() -> void:
	hint_box = UI.card(Color(0.06, 0.07, 0.11, 0.9), 10, 14)
	UI.set_card_border(hint_box, Color(UI.GOLD, 0.5), 1)
	hint_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_box.offset_top = 66      # under the top chips
	var row := UI.hbox(14)
	hint_box.add_child(row)
	hint_lbl = UI.label("", 16, UI.INK, UI.semi)
	row.add_child(hint_lbl)
	skip_row = UI.hbox(6)
	row.add_child(skip_row)
	_skip_buttons()
	h.root_ui.add_child(hint_box)

func _skip_buttons() -> void:
	for c in skip_row.get_children():
		c.queue_free()
	if not bool(FarmTutorial.option("skippable")):
		return
	if not asking:
		skip_row.add_child(UI.button(String(FarmTutorial.rules()["skip_label"]), func():
			asking = true
			_skip_buttons(), 0))
		return
	skip_row.add_child(UI.label(String(FarmTutorial.rules()["skip_ask"]), 14, UI.MUTED))
	skip_row.add_child(UI.button("Yes", func(): skip(), 0))
	skip_row.add_child(UI.button("No", func():
		asking = false
		_skip_buttons(), 0))

## Skips the tutorial: nothing is taken; the house is put down as a site if it isn't, with the materials it
## needs handed over so it can still be built.
func skip() -> void:
	asking = false
	FarmTutorial.skip()
	if FarmHob.house_entry().is_empty():
		place_house()
		FarmSites.refund(FarmSites.build_cost("house"))
	_clear_hint()
	h.hob.sync()
	h._refresh_top()

## The tutorial's house spot: from the landing, as the data says.
func house_spot() -> Vector3:
	var sp: Dictionary = FarmTutorial.rules()["house_spot"]
	return HomeLayout.LANDING + Vector3(float(sp["x"]), 0, float(sp["z"]))

## Puts the house down as a construction site on the free ground nearest the suggested spot (marking it
## out costs nothing; the materials are spent as it goes up).
func place_house() -> bool:
	var hb: HomeBuild = h.hb
	var was_active := hb.active
	if not was_active:
		hb.active = true
	hb.take("house")
	var found := false
	var p := house_spot()
	var sz := HomeLayout.size_of("house", 0)
	for rad in 24:
		for k in 24:
			var a := float(k) / 24.0 * TAU
			var x := int(round(p.x + cos(a) * rad - sz.x * 0.5))
			var z := int(round(p.z + sin(a) * rad - sz.y * 0.5))
			var cs := HomeLayout.cells_of([x, z, x + sz.x - 1, z + sz.y - 1])
			if hb.fits(hb.held, cs):
				hb.cells = cs
				hb._check_cells()
				found = hb.place_held()
				break
		if found:
			break
	hb._drop_held()
	hb.active = was_active
	if not was_active:
		hb.close_ui()
	return found

# ------------------------------------------------------------------ the world prompt
func _target(id: String) -> Vector3:
	match id:
		"chop":
			return _nearest_wild("tree")
		"stone":
			return _nearest_wild("rock")
		"buy", "sell":
			var stalls := HomeLayout.fixtures(Save.d, "stall")
			return HomeLayout.deco_center(stalls[0]) if not stalls.is_empty() else Vector3.INF
		"house":
			var e := FarmHob.house_entry()
			return house_spot() if e.is_empty() else HomeLayout.deco_center(e)
		"hammer":
			return HomeLayout.deco_center(FarmHob.house_entry())
		"feed":
			var fs := Econ.feeders()
			return Vector3(float(fs[0]["x"]), 0, float(fs[0]["z"])) if not fs.is_empty() else Vector3.INF
		"crop":
			if FarmTutorial.stage(id) == "patch":
				return _water_spot()      # the patch goes by the water
			var planted: bool = not h.plots.is_empty() and FarmTutorial.stage(id) != "patch_dry"
			return h.plots[0].position if planted else Vector3.INF
		"task":
			var ke: Dictionary = h._kin_entry(Save.active_kin())
			return (ke["node"] as Node3D).position if not ke.is_empty() else Vector3.INF
		"hob":
			return h.hob.pos
		"expedition":
			return h.spots["portal"]
	return Vector3.INF

## The water tile nearest the player (where the tutorial says to put the crop patch).
func _water_spot() -> Vector3:
	var c := FarmWater.nearest(Save.d, Vector2(h.ppos.x, h.ppos.z))
	return Vector3(c.x + 0.5, 0, c.y + 0.5) if c.x >= 0 else Vector3.INF

## The wild tree or boulder nearest the player (the tutorial's chop and mine markers); looked up twice a second at most.
func _nearest_wild(what: String) -> Vector3:
	if tree_t > t and tree_what == what:
		return tree_at
	tree_t = t + 0.5
	tree_what = what
	tree_at = Vector3.INF
	var best := INF
	var w: World = h.world
	for i in h.hb.wild_t:
		if String(h.hb.wild_t[i]) != what:
			continue
		var at := Vector3(int(i) % w.w + 0.5, 0, int(i) / w.w + 0.5)
		var d := Vector2(at.x - h.ppos.x, at.z - h.ppos.z).length()
		if d < best:
			best = d
			tree_at = at
	return tree_at

## A growth bar and countdown over the first patch while a seed grows, whatever step is showing.
func _update_crop_label() -> void:
	var g := FarmCropGuide.growing()
	if g.is_empty() or not FarmTutorial.active() or h.plots.size() <= int(g["plot"]):
		if is_instance_valid(crop_lbl):
			crop_lbl.visible = false
		return
	if not is_instance_valid(crop_lbl):
		crop_lbl = Label3D.new()
		crop_lbl.font_size = 48
		crop_lbl.pixel_size = 0.0095
		crop_lbl.outline_size = 14
		crop_lbl.modulate = Color("8fe0a0")
		crop_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		crop_lbl.no_depth_test = true
		h.add_child(crop_lbl)
	crop_lbl.visible = true
	crop_lbl.text = "Growing\n" + FarmCropGuide.bar_text(g)
	crop_lbl.position = (h.plots[int(g["plot"])] as Node3D).position + Vector3(0, 2.2, 0)

func _update_marker(dt: float) -> void:
	_update_crop_label()
	var id := FarmTutorial.current()
	var txt := FarmTutorial.world_text(id)
	var at := _target(id) if id != "" and txt != "" else Vector3.INF
	if at.x == INF or at.x < -100.0:
		if is_instance_valid(marker):
			marker.visible = false
		return
	if not is_instance_valid(marker):
		marker = Label3D.new()
		marker.font_size = 56
		marker.pixel_size = 0.0095
		marker.outline_size = 16
		marker.modulate = UI.GOLD
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.no_depth_test = true
		marker.render_priority = 4
		h.add_child(marker)
	marker.visible = true
	marker.text = "%s\n▼" % txt
	marker.position = at + Vector3(0, 3.6 + sin(t * 3.0) * 0.18, 0)
	_yield_to_covers(dt)

## A Boki's speech bubble fades back while a message card (MsgLane) covers it on screen.
func _bubbles_under_lane(dt: float) -> void:
	var cards := MsgLane.of(h.root_ui).rects()
	for k in h.kins:
		var say: Label3D = k.get("say")
		if say and say.visible:
			MsgLane.yield_label(say, h.cam, cards, dt)

## The marker fades back while a Boki's speech bubble or a message card covers it on screen, so two
## lines never print over each other; it comes back when the Boki is done talking and the card goes.
func _yield_to_covers(dt: float) -> void:
	var covers: Array[Rect2] = MsgLane.of(h.root_ui).rects()
	for k in h.kins:
		var say: Label3D = k.get("say")
		if say and say.visible:
			covers.append(MsgLane.label_rect(say, h.cam))
	MsgLane.yield_label(marker, h.cam, covers, dt)
