extends RefCounted
## --clarity-shots --shots-dir=<dir>: the combat-clarity picture (run under xvfb with a renderer). A 2v2 at
## match zoom: you, a downed teammate whose Boki is beside them, two rivals and every Boki out. Writes
## <dir>/clarity_2v2.png (the whole screen) and <dir>/clarity_2v2_crop.png (the fight), then
## <dir>/clarity_cues.png: the same Vex ring, lane and shot from your teammate and a rival (same fill, side
## edge). Only uses the match's own setup calls, so the same scene can be taken on an older build for a
## before/after.

const DT := 1.0 / 60.0
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
	var foe0: Hunter = null
	var fi := 0
	for h in m.hunters:
		if h == P:
			continue
		var key := "ally" if h.team == P.team else "foe%d" % fi
		if h.team != P.team: fi += 1
		if h.team == P.team: ally = h
		elif foe0 == null: foe0 = h
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
	await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("clarity_2v2.png"))
	var vp := main.get_viewport()
	var c := vp.get_camera_3d().unproject_position(base + Vector3(0, 0.5, 1.8)) * Vector2(img.get_size()) \
		/ vp.get_visible_rect().size
	var box := Rect2i(Vector2i(c) - Vector2i(520, 330), Vector2i(1040, 660))
	var crop := img.get_region(box.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	crop.save_png(dir.path_join("clarity_2v2_crop.png"))
	await _cues(main, m, ally, foe0)
	img = main.get_viewport().get_texture().get_image()
	img.get_region(box.intersection(Rect2i(Vector2i.ZERO, img.get_size()))).save_png(dir.path_join("clarity_cues.png"))
	print("CLARITYSHOTS ", dir)
	main.get_tree().quit(0)

## Vex's ring, lane and a shot from the teammate and from a rival, held a few frames for the picture.
func _cues(main: Node, m: Match, ally: Hunter, foe: Hunter) -> void:
	var vex := Arch.color("gunslinger")
	for h: Hunter in [ally, foe]:
		h.ak.tele_circle(h.pos, 1.6, vex, 0.6)
		h.ak.tele_lane(h.pos, Vector2(0, -1), 3.0, 0.9, vex, 0.6)
		m.spawn_shot(h, h.pos + Vector3(0.8, 1.0, 0), Vector2(0.4, 0), 0.0, 3.0, 0.2, vex, {"cos": true})
	for i in 20:
		m.step(DT)
		await main.get_tree().process_frame
