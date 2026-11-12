class_name FarmGuide
extends RefCounted
## The farm's guidance on screen (home.gd owns one): the Goals tracker in the top-right slot
## (GoalTracker, from the end of the tutorial on), and while the tutorial runs, one prompt in the world over
## what to do next and one line reminding you of the current goal, with a Skip button (Hob explains each
## step face to face: HobTalk). The rules are FarmTutorial; none of it shows when visiting. Skipping puts
## a toy down if there is none.

const DONE_TICK_S := 1.6      # s the "Done!" stays on the goal line before fading

var h
var tracker: PanelContainer = null
var hint_box: StripView = null      # the one objective strip (TutorialStrip), as on the match HUD
var skip_row: HBoxContainer = null
var marker: Label3D = null
var sig := ""
var t := 0.0
var detect_t := 0.0
var asking := false
var stay_shown := false      # the base's last step offers Stay beside Skip
var quiet := false      # set while you talk to Hob: the card, the goal line and the world prompts step aside
var done_t := 0.0     # s left of the "Done!" in front of the strip line
var done_seen := -1     # steps done when last looked at (-1: not yet), to tick one off when it goes up

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
	tracker = null if FarmTutorial.active() else GoalTracker.build()
	sig = _sig()
	if tracker:
		h.root_ui.add_child(tracker)
		tracker.visible = not quiet
		if is_instance_valid(h.panel_host):
			h.root_ui.move_child(tracker, h.panel_host.get_index())      # menus open on top of it
	_refresh_hint()

## Steps the guidance aside (quiet) or back: the Goals card, the goal line and the world prompt.
func set_quiet(on: bool) -> void:
	quiet = on
	if on:
		FarmSpotlight.close()
	for c in [tracker, hint_box, marker]:
		if is_instance_valid(c):
			c.visible = not on

## G: the Goals line opens into the whole list and back. False when there is no card (the tutorial runs).
func toggle_goals() -> bool:
	if not is_instance_valid(tracker):
		return false
	GoalTracker.all = not GoalTracker.all
	refresh()
	return true

func _sig() -> String:
	return "%s|%s" % [FarmTutorial.active(), GoalTracker.signature()]

func tick(dt: float) -> void:
	if not h.visit.is_empty():
		return
	t += dt
	done_t = maxf(0.0, done_t - dt)
	detect_t -= dt
	if h.hob:
		h.hob.tick(dt)
	if detect_t <= 0.0:
		detect_t = 0.5
		_poll()
	_update_marker(dt)
	_bubbles_under_lane(dt)

func _poll() -> void:
	var was_done := bool(FarmTutorial.state()["done"])
	if FarmTutorial.active():
		FarmTutorial.detect()
		if FarmTutorial.current() == "meet" and _near_boki():
			FarmTutorial.event("meet")
		if FarmTutorial.current() == "eat":
			FarmTutorial.give_food()
	var st := FarmTutorial.state()
	if bool(st["done"]) and not was_done and not bool(st["skipped"]):
		var gems := str(int(FarmTutorial.option("end_gems")))
		h._toast(String(FarmTutorial.rules()["done_toast"]).replace("{gems}", gems))
		Sfx.play("unlock", null, -6.0)
		h._refresh_top()
	if _sig() != sig:
		refresh()
	else:
		_refresh_hint()
	FarmSpotlight.sync(h, quiet)
	_tick_off_done()

## A green "Done!" on the strip's line for a moment when a step has just been finished.
func _tick_off_done() -> void:
	var n := FarmTutorial.done_count()
	var gained := done_seen >= 0 and n > done_seen
	done_seen = n
	if gained and is_instance_valid(hint_box):
		done_t = DONE_TICK_S
		_refresh_hint()

# ------------------------------------------------------------------ the hint line
func hint_visible() -> bool:
	return is_instance_valid(hint_box)

## Is the player next to their Boki (the base's first step)?
func _near_boki() -> bool:
	var ke: Dictionary = h._kin_entry(Save.active_kin())
	if ke.is_empty():
		return false
	var at: Vector3 = ke["node"].position
	return Vector2(h.ppos.x - at.x, h.ppos.z - at.z).length() < float(FarmTutorial.rules()["near"])

func _refresh_hint() -> void:
	var id := FarmTutorial.current()
	if id == "":
		_clear_hint()
		return
	if not is_instance_valid(hint_box):
		_make_hint()
		hint_box.visible = not quiet
	if (id == "out") != stay_shown:
		_skip_buttons()
	var txt := FarmTutorial.hint_text(id).strip_edges()
	hint_box.set_line({"text": ("\u2713 Done!  " if done_t > 0.0 else "") + txt,
			"count": "%d/%d" % [FarmTutorial.done_count() + 1, FarmTutorial.steps().size()]}, id)
	_place_skip()

## The line the strip shows now (the checks read it).
func hint_text() -> String:
	return String(hint_box.line.get("text", "")) if is_instance_valid(hint_box) else ""

func _clear_hint() -> void:
	if is_instance_valid(hint_box):
		hint_box.queue_free()
	hint_box = null
	if is_instance_valid(marker):
		marker.queue_free()
	marker = null

func _make_hint() -> void:
	hint_box = StripView.new()
	skip_row = UI.hbox(6)
	hint_box.add_child(skip_row)
	skip_row.resized.connect(_place_skip)
	_skip_buttons()
	h.root_ui.add_child(hint_box)

## Skip sits just under the strip's right end: small, and out of the way of the world.
func _place_skip() -> void:
	var r := TutorialStrip.rect(h.root_ui.get_viewport_rect().size)
	skip_row.position = Vector2(r.end.x - skip_row.size.x, r.end.y + 6.0)

func _skip_buttons() -> void:
	for c in skip_row.get_children():
		c.queue_free()
	stay_shown = FarmTutorial.current() == "out"
	if stay_shown:
		skip_row.add_child(UI.button(String(FarmTutorial.rules()["stay_label"]), func(): FarmTutorial.event("stay"), 0))
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

## Skips the tutorial: nothing is taken; a toy is put down if there is none and the food is handed over.
func skip() -> void:
	asking = false
	FarmTutorial.skip()
	FarmTutorial.give_food()
	if FarmTutorial.toy_spot().x == INF:
		place_toy()
	_clear_hint()
	h.hob.sync()
	h._refresh_top()

## The house's spot: from the landing, as the data says.
func house_spot() -> Vector3:
	var sp: Dictionary = FarmTutorial.rules()["house_spot"]
	return HomeLayout.LANDING + Vector3(float(sp["x"]), 0, float(sp["z"]))

## Puts the house down as a construction site on the free ground nearest the suggested spot (marking it
## out costs nothing; the materials are spent as it goes up).
func place_house() -> bool:
	return _place("house", house_spot())

## The skip's toy: put near the landing, from the inventory so it costs nothing.
func place_toy() -> bool:
	var id := String(FarmTutorial.rules()["skip_toy"])
	var inv: Dictionary = h.hb.L()["inv"]
	inv[id] = int(inv.get(id, 0)) + 1
	return _place(id, HomeLayout.LANDING + Vector3(3, 0, -3))

func _place(id: String, p: Vector3) -> bool:
	var hb: HomeBuild = h.hb
	var was_active := hb.active
	if not was_active:
		hb.active = true
	hb.take(id)
	var found := false
	var sz := HomeLayout.size_of(id, 0)
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
## Where a step's work is (its marker; your Boki leads there).
func target(id: String) -> Vector3:
	match id:
		"meet", "eat":
			var ke: Dictionary = h._kin_entry(Save.active_kin())
			return (ke["node"] as Node3D).position if not ke.is_empty() else Vector3.INF
		"toy":
			return FarmTutorial.toy_spot()
		"out":
			return h.spots["portal"]
	return Vector3.INF

func _update_marker(dt: float) -> void:
	if quiet:
		return
	var id := FarmTutorial.current()
	var txt := FarmTutorial.world_text(id)
	var at := target(id) if id != "" and txt != "" else Vector3.INF
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
