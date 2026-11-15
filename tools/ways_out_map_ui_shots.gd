extends RefCounted
## --ways-out-map-ui-shots --shots-dir=<dir>: the Ways Out seats on the real maps (GPU, under xvfb with a renderer).
##   mini_*: the ground minimap (the smallest map) beside the Heart Gate, early and late; full_*: the full map
##   at 0:30, mid-match and late (dashed next ring); watching: a dead player's line over the open full map and
##   on the HUD.

var main: Node
var m: Match
var dir := ""

func _frames(n: int) -> void:
	for i in n:
		m.step(Match.DT)
		m.cam.snap(m.player.pos)
		for h in m.hunters:
			h.render(Match.DT, 1.0)
		await main.get_tree().process_frame

func _grab(file: String) -> void:
	await _frames(20)
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("%s.png" % file))
	print("WAYSMAP-SHOT ", file)

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
	await m.start({"teams": 4, "squad": 2, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true, "heart": true,
		"god": true, "length": 1e9})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var H: Heart = m.heart
	var q: Dictionary = Heart.rules()["quest"]
	for h in m.hunters:
		h.ctrl = "idle"
	var foe: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	P.teleport(m.world.free_spot_near(H.gate + Vector3(10, 0, 6), [], 1.0, 0.45, 6.0))
	m.sess_t0 = 30.0 - m.time
	await _grab("mini_1_start")
	m.hud.full_map.open()
	await _grab("full_1_start")
	m.hud.full_map.close()
	m.sess_t0 = float(q["lair_open_s"]) + 60.0 - m.time
	H.charge = 40.0
	H._force(Heart.S.CHARGING, "shots")
	m.hud.full_map.open()
	await _grab("full_2_lair_open")
	m.hud.full_map.close()
	m.sess_t0 = Heart.r("tide_start_s") + 200.0 - m.time
	H.charge = Heart.r("charge_s")
	H._force(Heart.S.READY, "charged")
	H.carrier = foe
	H._force(Heart.S.CARRIED, "shots")
	await _grab("mini_2_in_use")
	m.hud.full_map.open()
	await _grab("full_3_mid")
	m.hud.full_map.close()
	H.carrier = null
	H.early_team = foe.team
	m.sess_t0 = float(q["uplink_shut_s"]) + 60.0 - m.time
	P.out = true
	await _grab("watching_hud")
	m.hud.full_map.open()
	await _grab("watching_full")
	main.get_tree().quit(0)
