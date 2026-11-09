extends RefCounted
## --hatch-check: hatching is a small, personal moment (docs/POSITIONING.md). An egg (EggHatch)
## cracks; the shell shrinks away within a second of the top coming off, and the Boki hops out, looks
## around, turns to look at you and bounces, all inside 2.5 s after the pop, and the shell throws no bursts, rings or flashes. The closer look after
## it (KinReveal) has no flash, rays, fanfare or rarity colours: the Boki finds you and calls to you,
## and only then can it be named. A shimmer shows as a faint sparkle on the Boki itself, a rare one
## gets a plain provenance line. Then the first Relic (MaskMoment): after naming the Boki, with no pick, Vex's
## Relic drifts to you, "Put on the Relic" (the interact key) puts it on and you become her; a short look at her
## ability clips fits a 1280x720 screen (1920x1080 scales to the same layout). Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("HATCH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## Records what the egg asks the effects layer for.
class FxSpy extends Fx:
	var got_bursts: Array = []
	var got_rings := 0
	func _ready() -> void:
		pass
	func burst(at: Vector3, col: Color, amount := 14, speed := 4.0, life := 0.5, grav := 12.0, size := 1.0, dir := Vector3.UP, spread := 180.0) -> void:
		got_bursts.append([col, amount])
	func ring(at: Vector3, radius: float, col: Color, dur := 0.35) -> void:
		got_rings += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	var tree := main.get_tree()
	# ---------------------------------------------------------------- 1. the egg
	var holder := Node3D.new()
	main.add_child(holder)
	var cam := Camera3D.new(); cam.position = Vector3(0, 2.0, 5.0)
	holder.add_child(cam)
	cam.make_current()
	cam.look_at(Vector3(0, 0.4, 0))
	var spy := FxSpy.new()
	holder.add_child(spy)
	var sp := "cindle"
	var egg := EggHatch.new(sp, spy, 0.32, 0.42, 1.0, {"species": sp})
	holder.add_child(egg)
	var seen := {"t_pop": -1.0, "t_shell": -1.0, "t_done": -1.0, "ymin": 1e9, "ymax": -1e9, "popped": false, "done": false, "face_err": 9.0, "looked_away": false}
	egg.popped.connect(func(k: Node3D):
		seen["popped"] = true
		var want := EggHatch._yaw_to(k.global_position, cam.global_position)
		seen["face_err"] = absf(wrapf(k.rotation.y - want, -PI, PI)))
	egg.done.connect(func():
		seen["done"] = true
		seen["t_done"] = float(Time.get_ticks_msec()))
	egg.start()
	var t0 := Time.get_ticks_msec()
	while not seen["done"] and Time.get_ticks_msec() - t0 < 30000:
		await tree.process_frame
		if is_instance_valid(egg.kin_node):
			if seen["t_pop"] < 0.0: seen["t_pop"] = float(Time.get_ticks_msec())
			seen["ymin"] = minf(float(seen["ymin"]), egg.kin_node.global_position.y)
			seen["ymax"] = maxf(float(seen["ymax"]), egg.kin_node.global_position.y)
			if seen["t_shell"] < 0.0 and egg.cap.scale.x < 0.02 and egg.cup.scale.x < 0.02:
				seen["t_shell"] = float(Time.get_ticks_msec())
			if not seen["popped"]:
				var want2 := EggHatch._yaw_to(egg.kin_node.global_position, cam.global_position)
				if absf(wrapf(egg.kin_node.rotation.y - want2, -PI, PI)) > 0.8: seen["looked_away"] = true
	ok(seen["done"], "the egg hatches all the way through (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var shell_s: float = (float(seen["t_shell"]) - float(seen["t_pop"])) / 1000.0
	ok(seen["t_shell"] > 0.0 and shell_s < 1.0, "the shell is gone %.2f s after the pop (want under 1 s)" % shell_s)
	var beat_s: float = (float(seen["t_done"]) - float(seen["t_pop"])) / 1000.0
	ok(beat_s > 0.0 and beat_s < 2.5, "the whole hop-look-face-bounce beat takes %.2f s (want under 2.5 s)" % beat_s)
	ok(float(seen["ymax"]) - float(seen["ymin"]) > 0.15, "the Boki hops (%.2f m of height)" % (float(seen["ymax"]) - float(seen["ymin"])))
	ok(seen["looked_away"], "it looks around before it finds you")
	ok(seen["popped"] and float(seen["face_err"]) < 0.25, "then it looks right at you (off by %.2f rad)" % float(seen["face_err"]))
	ok(spy.got_rings == 0, "no ring bursts round the egg (%d)" % spy.got_rings)
	var big := spy.got_bursts.filter(func(b): return int(b[1]) > 8)
	var gold := spy.got_bursts.filter(func(b): return (b[0] as Color).is_equal_approx(Color("fff6c0")) or (b[0] as Color).is_equal_approx(UI.GOLD))
	ok(big.is_empty() and gold.is_empty(), "only a few flakes of shell, no sparkle showers (%d bursts, largest %d)" % [spy.got_bursts.size(), spy.got_bursts.map(func(b): return int(b[1])).max() if not spy.got_bursts.is_empty() else 0])
	holder.queue_free()
	await tree.process_frame
	# ---------------------------------------------------------------- 2. the closer look
	var rec := Save.new_kin(sp, "Ember")
	rec["shimmer"] = true
	rec["rare"] = true
	var rv := KinReveal.new(sp, rec)
	main.add_child(rv)
	var named := {"go": false}
	rv.proceed.connect(func(): named["go"] = true)
	for i in 4: await tree.process_frame
	ok(not ("rays" in rv) and not ("flash" in rv) and not rv.has_method("_jingle"), "no light rays, flash or fanfare")
	ok(rv.name_btn.disabled and not rv.met, "it can't be named before it has met you")
	var hot: Array = []
	for n in rv.find_children("*", "ColorRect", true, false):
		var c := (n as ColorRect).color
		if c.a > 0.7 and c.get_luminance() > 0.5: hot.append(n.name)
	ok(hot.is_empty(), "nothing flashes white (%s)" % [hot])
	t0 = Time.get_ticks_msec()
	while not rv.met and Time.get_ticks_msec() - t0 < 15000:
		await tree.process_frame
	ok(rv.met and not rv.name_btn.disabled, "after it looks at you, you can name it (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var face := wrapf(rv.kin.rotation.y + rv.turn.rotation.y - PI, -PI, PI)
	ok(absf(face) < 0.2, "it faces you (off by %.2f rad)" % face)
	ok(rv.sub_lbl.text.to_lower().contains("looking at you") and not rv.title_lbl.text.contains("!") and not rv.title_lbl.text.contains("RARE"),
		"quiet words: \"%s\" / \"%s\"" % [rv.title_lbl.text, rv.sub_lbl.text])
	var sparkle := rv.kin.get_node_or_null("FurSparkle") as CPUParticles3D
	ok(sparkle != null and sparkle.amount <= 8, "a shimmer is a faint sparkle in its coat")
	var labels: Array = rv.info.find_children("*", "Label", true, false)
	var golden := labels.filter(func(l): return (l as Label).get_theme_color("font_color").is_equal_approx(UI.GOLD))
	ok(golden.is_empty(), "no gold rarity text on its card (%d)" % golden.size())
	ok(labels.any(func(l): return (l as Label).text.contains("Its egg was guarded by")), "a rare one gets a line of provenance")
	rv._go()
	t0 = Time.get_ticks_msec()
	while not named["go"] and Time.get_ticks_msec() - t0 < 3000:
		await tree.process_frame
	ok(named["go"], "Name it hands over to naming")
	await _creator_rows(tree)
	await _first_mask(tree)
	print("HATCH CHECK DONE, failures: %d" % bad)
	tree.quit()

# ---------------------------------------------------------------- 3. the creator
## A new player sees Sex, Shroud colour and Glow; "More looks..." opens the other rows; the menu's creator has them all.
func _creator_rows(tree: SceneTree) -> void:
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"intro": true}
	var hx = load("res://scripts/ui/hatch.gd").new()
	main.add_child(hx)
	for i in 4: await tree.process_frame
	ok(hx.stage == "create", "a new game opens the creator (stage %s)" % hx.stage)
	var shown := func(): return Unmasked.ROWS.filter(func(r): return _texts(hx.create_box).has(r[1]))
	var first: Array = Unmasked.FIRST_ROWS.map(func(r): return Unmasked.ROWS[r])
	ok(shown.call() == first and first.size() == 3, "first it shows 3 rows: body, colour, glow")
	var more := _find_button(hx.create_box, "More looks...")
	ok(more != null, "with a More looks... button")
	if more == null:
		hx.queue_free()
		return
	more.pressed.emit()
	for i in 4: await tree.process_frame
	ok(shown.call() == Unmasked.ROWS and _find_button(hx.create_box, "More looks...") == null,
		"it opens all %d rows and the button goes" % Unmasked.ROWS.size())
	await _polish(tree, hx)
	hx.queue_free()
	await tree.process_frame
	var menu = load("res://scripts/ui/hatch.gd").new()
	menu.edit_only = true
	main.add_child(menu)
	for i in 4: await tree.process_frame
	ok(Unmasked.ROWS.all(func(r): return _texts(menu.create_box).has(r[1])), "the menu's creator has every row")
	menu.queue_free()
	await tree.process_frame

## Dice, undo and redo, starter presets, and the wheel zoom.
func _polish(tree: SceneTree, hx) -> void:
	var card: CreatorCard = hx.create_box
	var dice := _all(card, func(n): return n is Button and n.has_meta("die"))
	ok(dice.size() == Unmasked.ROWS.size(), "every row has its own die (%d)" % dice.size())
	var before: Dictionary = card.look.duplicate(true)
	(dice[3] as Button).pressed.emit()
	var key: String = Unmasked.ROWS[3][0]
	var moved := Unmasked.ROWS.filter(func(r): return card.look[r[0]] != before[r[0]])
	ok(moved.size() == 1 and moved[0][0] == key, "a die changes only its own row")
	ok(hx.look[key] == card.look[key], "and the preview follows")
	card.undo()
	ok(card.look == before, "Undo puts the row back")
	card.redo()
	ok(card.look[key] != before[key], "Redo takes it forward again")
	card.undo()
	card.undo()
	ok(card.look == before, "undo is one step: a second Undo does nothing")
	var names: Array = CreatorCard.PRESETS.keys()
	ok(names.size() == 6 and names.all(func(nm): return _find_button(card, nm) != null), "6 starter presets in More")
	var sex: int = card.look["gender"]
	_find_button(card, names[2]).pressed.emit()
	var want: Dictionary = CreatorCard.PRESETS[names[2]]
	var same := want.keys().all(func(k): return card.look[k] == want[k])
	ok(same and card.look["gender"] == sex, "a preset sets the look and keeps Sex")
	ok(card.look == Unmasked.clean(card.look), "every preset value is in its list")
	await tree.process_frame
	var vis: Rect2 = card.get_viewport_rect()
	ok(vis.encloses(card.get_global_rect()) and card.size.y <= 660.0,
		"with every row open the card fits a 1280x720 screen (%d tall)" % card.size.y)
	hx.zoom = 0.0
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	for i in 8: hx._unhandled_input(wheel)
	for i in 30: await tree.process_frame
	ok(hx.zoom == 1.0 and hx.cam_to.z < CreatorCam.FAR_CAM.z - 1.0, "the wheel zooms in to the face")

func _all(n: Node, pred: Callable) -> Array:
	var out: Array = [n] if pred.call(n) else []
	for ch in n.get_children():
		out.append_array(_all(ch, pred))
	return out

func _find_button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null

# ---------------------------------------------------------------- 4. the first Relic
func _first_mask(tree: SceneTree) -> void:
	tree.root.size = Vector2i(1280, 720)      # (the smallest screen we lay out for; 1920x1080 scales to it)
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"intro": true}
	Save.d["look"] = Unmasked.default_look()
	var hx = load("res://scripts/ui/hatch.gd").new()
	main.add_child(hx)
	for i in 4: await tree.process_frame
	hx._looks_good()
	ok(hx.stage == "pick" and ClassUnlock.needs_starters(), "the eggs come before any Relic (stage %s)" % hx.stage)
	var kin := Models.kin("cindle", {"level": 1})
	hx.add_child(kin)
	hx.kin_node = kin
	hx.chosen = 0
	hx._finish("cindle", "Ember", "Orri", true)
	var moments: Array = hx.get_children().filter(func(c): return c is MaskMoment)
	ok(hx.stage == "mask" and moments.size() == 1, "naming the Boki leads into the Relic moment, not the match")
	if moments.is_empty():
		hx.queue_free()
		return
	var moment: MaskMoment = moments[0]
	ok(Arch.of_save() == "gunslinger" and ClassUnlock.open_ids() == ["gunslinger"] and Save.d["roster"].size() == 1,
		"your first Relic is Vex, with your new Boki (%s)" % Arch.of_save())
	var t0 := Time.get_ticks_msec()
	while moment.phase != "wait" and Time.get_ticks_msec() - t0 < 10000:
		await tree.process_frame
	var head := (moment.you.get_node("Rig/Torso/HeadPivot") as Node3D).global_position
	ok(moment.phase == "wait" and moment.relic.global_position.distance_to(head) < 1.5,
		"Vex's Relic drifts in from the crystal and waits by your face")
	ok(absf(moment.kin.global_position.y) < 0.05 and moment.kin.position.distance_to(MaskMoment.BOKI_AT) < 0.1,
		"your Boki stands beside you")
	var words := _texts(moment.prompt)
	ok(words.has(MaskMoment.BUTTON) and words.has(Settings.key_cap("interact")) and not str(words).contains("Take"),
		"one button: Put on the Relic, with the interact key (%s)" % str(words))
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	moment._unhandled_input(press)
	t0 = Time.get_ticks_msec()
	while moment.phase != "intro" and Time.get_ticks_msec() - t0 < 12000:
		await tree.process_frame
	for i in 6: await tree.process_frame
	ok(moment.phase == "intro" and String(moment.you.get_meta("arch")) == "gunslinger",
		"the Relic goes on and you become Vex")
	var viewer := moment.intro.find_children("*", "HunterViewer", true, false)
	var clips := moment.intro.find_children("*", "AbilityClip", true, false)
	ok(viewer.size() == 1 and _texts(moment.intro).has(HunterViewer.display_name("gunslinger"))
		and HunterViewer.display_name("gunslinger") == "Vex the Hired Gun", "then Vex the Hired Gun")
	ok(clips.size() == HunterViewer.CLIP_SLOTS.size(), "with a clip for each ability (%d)" % clips.size())
	var gender := RegEx.create_from_string("(?i)\\b(female|male|she|her|he|his|woman|man)\\b")
	var said: Array = _texts(moment.intro).filter(func(t): return gender.search(String(t)) != null)
	ok(said.is_empty(), "no gender or pronouns in the Relic's info (%s)" % str(said))
	await tree.create_timer(0.6).timeout      # (the panel's pop-in has settled)
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	screen = screen.intersection(moment.intro.get_viewport().get_visible_rect())
	var panel_r: Rect2 = (viewer[0] as Control).get_global_rect().merge(moment.go_button.get_global_rect())
	ok(screen.encloses(panel_r), "the intro fits on a 1280x720 screen (%s)" % str(panel_r))
	ok(moment.go_button.text == MaskMoment.GO, "and goes on: %s" % moment.go_button.text)
	hx.queue_free()
	for i in 3: await tree.process_frame

func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label: out.append((n as Label).text)
	elif n is Button: out.append((n as Button).text)
	for c in n.get_children(): out.append_array(_texts(c))
	return out
