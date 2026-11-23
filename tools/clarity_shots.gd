extends RefCounted
## --clarity-shots --shots-dir=<dir>: the combat-clarity picture (run under xvfb with a renderer). A 2v2 at
## match zoom: you, a downed teammate whose Boki is beside them, two rivals and every Boki out. Writes
## <dir>/clarity_2v2_<palette>.png (the whole screen) and ..._crop.png (the fight), once for each Settings >
## Accessibility > Colour vision palette (SideColor.ORDER). Then each ClarityFight fight (a bot 3v3 of the slice Hunters
## on the Hollow Crown): <dir>/fight<f>_<i>.png for its 10 frames (1920x1080) and <dir>/clarity_fight.tsv, every
## element over or within one body width of a Hunter on each frame (fight, frame, kind, what, Hunters it sits on);
## the ranking (frames covered per element) is printed as CLARITYTOP lines.

const ClarityFight := preload("res://tools/clarity_fight.gd")
const DT := 1.0 / 60.0
const FIGHT_FRAMES := 10
const FIGHT_PX := Vector2i(1920, 1080)  # the fight frames' size (the window: stretch is off)
const TOASTS := ["Fever is lit", "Bond full!  R: Venom Fusion"]  # the two the baseline found over the top centre
const RUN_S := 1.6         # s the scene plays before the picture (the downed teammate's Boki reacts)

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var P: Hunter = m.player
	var base := P.pos
	var spots := {"ally": Vector3(3.2, 0, 0.6), "foe0": Vector3(-2.6, 0, 3.4), "foe1": Vector3(2.0, 0, 4.6)}
	var ally: Hunter = null
	var fi := 0
	for h in m.hunters:
		if h == P:
			continue
		var key := "ally" if h.team == P.team else "foe%d" % fi
		if h.team != P.team: fi += 1
		if h.team == P.team: ally = h
		h.teleport(m.world.free_spot_near(base + spots.get(key, Vector3(6, 0, 6)), [], 0.6, 0.5, 3.0))
		h.ctrl = "idle"
	P.ctrl = "idle"
	P.inp["aim"] = base + Vector3(0, 0.9, 4.0)
	for k in m.kins:
		if k.owner_h == null:
			k.dead = true
			k.visible = false
			continue
		k.teleport((k.owner_h as Hunter).pos + Vector3(1.6, 0, 1.2))
		k.state = "active"
		k.fly = {}
		k.grounded = true
	if ally:
		m.knock(ally, null, {})
	var t := 0.0
	while t < RUN_S:
		m.step(DT)
		for h in m.hunters: h.render(DT, 1.0)
		m.cam.snap(base + Vector3(0, 0, 1.8))
		await main.get_tree().process_frame
		t += DT
	var vp := main.get_viewport()
	for id in SideColor.ORDER:      # the same fight in each Settings > Colour vision palette
		Settings.v[SideColor.KEY] = id
		for i in 3:
			m.step(DT)
			for h in m.hunters: h.render(DT, 1.0)
			await main.get_tree().process_frame
		var img := vp.get_texture().get_image()
		if img == null:
			continue  # headless: no picture (the fights below still count)
		img.save_png(dir.path_join("clarity_2v2_%s.png" % id))
		var c := vp.get_camera_3d().unproject_position(base + Vector3(0, 0.5, 1.8)) * Vector2(img.get_size()) \
			/ vp.get_visible_rect().size
		var box := Rect2i(Vector2i(c) - Vector2i(520, 330), Vector2i(1040, 660))
		var crop := img.get_region(box.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		crop.save_png(dir.path_join("clarity_2v2_%s_crop.png" % id))
	m.queue_free()
	await _fights(main, dir)
	print("CLARITYSHOTS ", dir)
	main.get_tree().quit(0)


## Each fight's frames and counts; then the elements ranked by frames covered (the most first).
func _fights(main: Node, dir: String) -> void:
	var rows := PackedStringArray(["fight\tframe\tkind\twhat\thunters"])
	var frames := {}  # "kind what" -> frames it was on a Hunter
	var toasts := [0, 0]  # frames with a toast card on show, and of those in the top-centre third of the screen
	main.get_window().size = FIGHT_PX
	for f in ClarityFight.FIGHTS.size():
		var on_frame := func(fm: Match, i: int) -> void:
			var lane: MsgLane = fm.hud.msgs
			lane.clear()
			fm.hud.toast(TOASTS[i % TOASTS.size()], Color("ffd23f"))      # a toast is up on every frame
			var sz: Vector2 = fm.hud.c.size
			var third := Rect2(sz.x / 3.0, 0.0, sz.x / 3.0, sz.y / 3.0)
			if not lane.rects().is_empty():
				toasts[0] += 1
				if lane.rects().any(func(r: Rect2) -> bool: return r.intersects(third)):
					toasts[1] += 1
			for _k in 12:      # the card fades in
				await fm.get_tree().process_frame
			var img := fm.get_viewport().get_texture().get_image()
			if img:
				img.save_png(dir.path_join("fight%d_%d.png" % [f, i]))
			var seen := {}
			for e in ClarityFight.tally(fm):
				rows.append("%d\t%d\t%s\t%s\t%d" % [f, i, e[0], e[1], e[2]])
				seen["%s %s" % [e[0], e[1]]] = true
			for k: String in seen:
				frames[k] = int(frames.get(k, 0)) + 1
		var fm: Match = await ClarityFight.play(main, ClarityFight.FIGHTS[f], FIGHT_FRAMES, on_frame)
		fm.queue_free()
		await main.get_tree().process_frame
	var tsv := FileAccess.open(dir.path_join("clarity_fight.tsv"), FileAccess.WRITE)
	tsv.store_string("\n".join(rows) + "\n")
	var keys := frames.keys()
	keys.sort_custom(func(a, b): return frames[a] > frames[b])
	for k: String in keys.slice(0, 40):
		print("CLARITYTOP %d/%d %s" % [frames[k], FIGHT_FRAMES * ClarityFight.FIGHTS.size(), k])
	var total := FIGHT_FRAMES * ClarityFight.FIGHTS.size()
	print("CLARITYTOAST %d/%d frames with a toast in the top-centre third (%d up)" % [toasts[1], total, toasts[0]])
