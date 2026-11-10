extends RefCounted
## --summon-ring-shots --shots-dir=<dir> (needs a renderer): the match-zoom picture --summon-ring-check proves.
## Three of your squad's summons at full, half and 1 s of their window (the last one flickers), and a rival's
## stolen summon dimmed. Writes <dir>/summon_ring.png (the screen), <dir>/summon_ring_crop.png (the fight) and
## <dir>/summon_ring_close.png (the four set apart in a row, sim paused, camera pulled in, no HUD).

const DT := 1.0 / 60.0
const SPOTS := [Vector3(0, 0, 0), Vector3(3.4, 0, 0.8), Vector3(-3.0, 0, 3.6), Vector3(-5.8, 0, 3.0),
	Vector3(2.2, 0, 5.4), Vector3(5.2, 0, 5.0)]
const LEFT := [10.0, 5.0, 1.0]   # s of the window left on three summons (of 10)

var m: Match
var main: Node
var focus := Vector3.ZERO      # where the camera sits: the summoned Boki's middle once they are out

func run(main_node: Node) -> void:
	main = main_node
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	for key in ["hatched", "intro", "home", "day1_done", "match", "kit_drill", "ivs_seen", "tut_intro"]:
		Save.d["tutorial"][key] = true          # no tutorial tips over the fight
	Save.d["first_guide"] = 99
	Settings.v["tips"] = false
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
	focus = base
	for i in m.hunters.size():
		var h: Hunter = m.hunters[i]
		h.ctrl = "idle"
		h.teleport(m.world.free_spot_near(base + SPOTS[i], [], 0.6, 0.5, 3.0))
	var mate: Hunter = m.hunters.filter(func(h: Hunter): return h.team == m.player.team and h != m.player)[0]
	var thief: Hunter = m.hunters.filter(func(h: Hunter): return h.team != m.player.team)[0]
	await _play(0.3)
	m.knock(mate, thief, {})
	await _play(0.2)
	thief.teleport(mate.kin.pos + Vector3(0.5, 0, 0))
	KinSteal.break_loose(mate.kin, mate.pos)    # (a downed mate keeps its Boki: shake it loose for the thief)
	print("SUMMONRINGSHOTS grab=", KinSteal.grab(mate.kin, thief))
	var own := [m.player.kin, m.hunters.filter(func(h: Hunter): return h.team != m.player.team and h != thief)[0].kin]
	own.append(thief.kin)
	for i in own.size():
		own[i].summon.burst(LEFT[0])
	mate.kin.summon.burst(LEFT[0])
	var rung: Array = own + [mate.kin]
	await _play(0.1)
	for i in own.size():
		own[i].summon.left = LEFT[i]
	mate.kin.summon.left = LEFT[1]
	focus = Vector3.ZERO
	for k in rung:
		focus += k.global_position / rung.size()
	await _play(0.3)                              # the camera settles on them; the 1 s one shows its flicker
	if m.hud:
		m.hud.guide_hidden = true
	await _play(0.01)
	var vp := main.get_viewport()
	var img := vp.get_texture().get_image()
	if img:          # (headless: no picture, the log only)
		img.save_png(dir.path_join("summon_ring.png"))
	var sc := Vector2(img.get_size() if img else Vector2i(vp.get_visible_rect().size)) / vp.get_visible_rect().size
	var lo := Vector2(1e9, 1e9)
	var hi := -lo
	for k in rung:
		var ring := k.get_node_or_null(SummonRing.NAME) as MeshInstance3D
		var q := vp.get_camera_3d().unproject_position(k.global_position) * sc
		lo = lo.min(q)
		hi = hi.max(q)
		print("SUMMONRINGSHOTS kin ", k.name, " left=", snappedf(k.summon.left, 0.01),
			" ring=", ring != null and ring.visible, " arc=",
			ring.material_override.get_shader_parameter("arc") if ring else -1.0, " px=", Vector2i(q),
			" stolen=", KinSteal.stolen(k), " col=", SideColor.of(m, k).to_html(false), " rider_team=",
			k.owner_h.team if k.owner_h else -1)
	var c := (lo + hi) * 0.5
	var half := Vector2i(((hi - lo) * 0.5 + Vector2(260, 200)).max(Vector2(420, 260)))
	var box := Rect2i(Vector2i(c) - half, half * 2)
	if img == null:
		print("SUMMONRINGSHOTS ", dir)
		main.get_tree().quit(0)
		return
	var crop := img.get_region(box.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	crop.save_png(dir.path_join("summon_ring_crop.png"))
	# Close-up: full, half, 1 s (flickering) and stolen, left to right, with the sim paused so nothing fights.
	for i in rung.size():
		rung[i].teleport(m.world.free_spot_near(focus + Vector3(-4.5 + 3.0 * i, 0, 0), [], 0.6, 0.5, 2.0))
	if m.hud:
		m.hud.visible = false
	m.cam.dist_mul = 0.4
	for f in 20:
		for k in rung:
			k.render(DT, 1.0)
		m.cam.snap(focus)
		await main.get_tree().process_frame
	vp.get_texture().get_image().save_png(dir.path_join("summon_ring_close.png"))
	print("SUMMONRINGSHOTS ", dir)
	main.get_tree().quit(0)

func _play(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters:
			h.render(DT, 1.0)
		for k in m.kins:
			k.render(DT, 1.0)
		m.cam.snap(focus)
		await main.get_tree().process_frame
		t += DT
