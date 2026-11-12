extends RefCounted
## --ways-out-palette-shots --shots-dir=<dir>: the Ways Out under each Settings > Accessibility > Colour vision
## palette (run under xvfb with a renderer). Per palette <id>: the strip and minimap with every seat state at once
## (a: the Lair open, the Heart Gate carried by your squad, the Uplink held by a rival, the Final locked;
## b: the Lair lost, the Gate taken by a rival, the Uplink held by your squad, the Final held by a rival),
## the world at the Uplink and at the Heart ring, and the full map. Files <id>_<name>.png.

var main: Node
var m: Match
var dir := ""
var focus := Vector3.ZERO

func _frames(n: int) -> void:
	for i in n:
		m.step(Match.DT)
		m.cam.snap(focus)
		for h in m.hunters:
			h.render(Match.DT, 1.0)
		await main.get_tree().process_frame

func _grab(file: String) -> void:
	await _frames(40)
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("%s.png" % file))
	print("PALSHOT ", file)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 1, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true, "heart": true,
		"god": true, "length": 1e9})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var rival: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	for h in m.hunters:
		h.ctrl = "idle"
		h.max_hp = 5000.0
		h.hp = 5000.0
		h.teleport(m.world.random_ground())
	var x: Dictionary = m.exits.of_kind("outpost")[0]
	var H: Heart = m.heart
	var q: Dictionary = Heart.rules()["quest"]
	for id in SideColor.ORDER:
		Settings.v[SideColor.KEY] = id
		await _state_a(P, rival, x, H, q)
		focus = x["pos"] + Vector3(0, 1.5, 3.0)
		P.teleport(m.world.free_spot_near(x["pos"] + Vector3(14, 0, 10), [], 1.0, 0.45, 6.0))
		await _grab("%s_a_uplink_rival" % id)
		m.hud.full_map.open()
		await _grab("%s_a_full_map" % id)
		m.hud.full_map.close()
		await _state_b(P, rival, x, H, q)
		await _grab("%s_b_uplink_ours" % id)
		focus = H.site + Vector3(0, 1.5, 3.0)
		P.teleport(m.world.free_spot_near(H.site + Vector3(14, 0, 10), [], 1.0, 0.45, 6.0))
		await _grab("%s_b_heart_rival" % id)
		m.hud.full_map.open()
		await _grab("%s_b_full_map" % id)
		m.hud.full_map.close()
	main.get_tree().quit(0)

func _state_a(P: Hunter, rival: Hunter, x: Dictionary, H: Heart, q: Dictionary) -> void:
	m.time = float(q["lair_open_s"]) + 5.0 - m.sess_t0
	x["state"] = "charging"
	x["team"] = rival.team
	x["prog"] = 0.6
	x["taken"] = false
	H.early_team = -1
	H.carrier = P
	H._force(Heart.S.CARRIED, "shots")

func _state_b(P: Hunter, rival: Hunter, x: Dictionary, H: Heart, q: Dictionary) -> void:
	m.time = float(Heart.r("final_s")) + 5.0 - m.sess_t0
	x["team"] = P.team
	H.carrier = null
	H.early_team = rival.team
	H._force(Heart.S.FINAL, "shots")
	H.final_team = rival.team
	H.final_prog = 0.5
