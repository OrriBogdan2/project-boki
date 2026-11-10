extends RefCounted
## --summon-ring-shots --shots-dir=<dir> (needs a renderer): the match-zoom picture --summon-ring-check proves.
## Three of your squad's summons at full, half and 1 s of their window (the last one flickers), and a rival's
## stolen summon dimmed. Writes <dir>/summon_ring.png (the screen) and <dir>/summon_ring_crop.png (the fight).

const DT := 1.0 / 60.0
const SPOTS := [Vector3(0, 0, 0), Vector3(3.4, 0, 0.8), Vector3(-3.0, 0, 3.6), Vector3(-5.8, 0, 3.0),
	Vector3(2.2, 0, 5.4), Vector3(5.2, 0, 5.0)]
const LEFT := [10.0, 5.0, 1.0]   # s of the window left on three summons (of 10)

var m: Match
var main: Node

func run(main_node: Node) -> void:
	main = main_node
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var base: Vector3 = m.player.pos
	for i in m.hunters.size():
		var h: Hunter = m.hunters[i]
		h.ctrl = "idle"
		h.teleport(m.world.free_spot_near(base + SPOTS[i], [], 0.6, 0.5, 3.0))
	var mate: Hunter = m.hunters.filter(func(h: Hunter): return h.team == m.player.team and h != m.player)[0]
	var thief: Hunter = m.hunters.filter(func(h: Hunter): return h.team != m.player.team)[0]
	await _play(0.3, base)
	m.knock(mate, thief, {})
	await _play(0.2, base)
	thief.teleport(mate.kin.pos + Vector3(0.5, 0, 0))
	KinSteal.grab(mate.kin, thief)
	var own := [m.player.kin, m.hunters.filter(func(h: Hunter): return h.team != m.player.team and h != thief)[0].kin]
	own.append(thief.kin)
	for i in own.size():
		own[i].summon.burst(LEFT[0])
	mate.kin.summon.burst(LEFT[0])
	await _play(0.1, base)
	for i in own.size():
		own[i].summon.left = LEFT[i]
	mate.kin.summon.left = LEFT[1]
	await _play(0.01, base)
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("summon_ring.png"))
	var vp := main.get_viewport()
	var c := vp.get_camera_3d().unproject_position(base + Vector3(-1.0, 0.5, 3.2)) * Vector2(img.get_size()) \
		/ vp.get_visible_rect().size
	var box := Rect2i(Vector2i(c) - Vector2i(520, 330), Vector2i(1040, 660))
	var crop := img.get_region(box.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	crop.save_png(dir.path_join("summon_ring_crop.png"))
	print("SUMMONRINGSHOTS ", dir)
	main.get_tree().quit(0)

func _play(secs: float, base: Vector3) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters:
			h.render(DT, 1.0)
		for k in m.kins:
			k.render(DT, 1.0)
		m.cam.snap(base + Vector3(-1.0, 0, 2.6))
		await main.get_tree().process_frame
		t += DT
