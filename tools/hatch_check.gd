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
	await _egg_cards(tree)
	await _first_mask(tree)
	print("HATCH CHECK DONE, failures: %d" % bad)
	tree.quit()

# ---------------------------------------------------------------- 3. the egg pick: who is in each egg
func _card_text(card: Node, node_name: String) -> String:
	var n: Node = card.find_child(node_name, true, false)
	if n is Label: return (n as Label).text
	return " ".join(n.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)) if n else ""

func _egg_cards(tree: SceneTree) -> void:
	tree.root.size = Vector2i(1280, 720)
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"intro": true}
	Save.d["look"] = Unmasked.default_look()
	var hx = load("res://scripts/ui/hatch.gd").new()
	main.add_child(hx)
	for i in 4: await tree.process_frame
	hx._looks_good()
	var secret: String = hx.egg_defs[3]["species"]
	ok(hx.stage == "pick" and secret != "mystery" and Data.KIN.has(secret),
		"the mystery egg's species is rolled when the pick opens (%s)" % secret)
	var cards: Array = hx.bottom.get_child(0).get_children()
	ok(cards.size() == 4, "four egg cards, each with its Boki's name line (%d)" % cards.size())
	for i in mini(cards.size(), 4):
		var sp: String = hx.egg_defs[i]["species"]
		var type_line := "%s type" % DexView.type_name(DexView.type_of(sp))
		var card: Node = cards[i]
		var pic: CanvasItem = card.find_child("Picture", true, false)
		var all_text := " ".join(card.find_children("*", "Label", true, false).map(func(l): return (l as Label).text))
		ok(_card_text(card, "TypeChip") == type_line, "card %d shows its type '%s'" % [i, type_line])
		if i < 3:
			var boki_name := String(Data.KIN[sp]["name"])
			ok(_card_text(card, "BokiName") == boki_name, "starter card %d shows its Boki's name (%s)" % [i, sp])
			ok(pic != null and pic.modulate.get_luminance() > 0.5, "starter card %d's picture is in full colour" % i)
		else:
			var secret_name := String(Data.KIN[sp]["name"])
			var shown_name := _card_text(card, "BokiName")
			ok(shown_name == "???" and not all_text.contains(secret_name), "the mystery card has no name")
			ok(pic != null and pic.modulate.is_equal_approx(DexView.SILHOUETTE), "the mystery card shows a silhouette")
	hx._pick(3)
	hx._pick(3)
	ok(hx.stage == "warm" and hx.egg_defs[3]["species"] == secret and (hx.eggs[3]["egg"] as EggHatch).species == secret,
		"the egg that hatches is the species the card showed (%s)" % secret)
	hx.queue_free()
	await tree.process_frame

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
