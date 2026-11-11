extends RefCounted
## --zone-next-shots --shots-dir=<dir>: the zone telegraph on the HUD (GPU, under xvfb with a renderer), at
## 1280x720 and 3440x1440 (ultrawide):
##   <w>_clock    30 s before the tide moves: the clock under the minimap, the edge and the next circle on it
##   <w>_closing  mid close: the time left
##   <w>_outside  60 m past the ring: the tint, the line and the edge arrow to the way in

const SIZES := [Vector2i(1280, 720), Vector2i(3440, 1440)]
const OUT_M := 60.0          # m past the ring the "outside" shot stands

var main: Node
var m: Match
var dir := ""

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
	await m.start({"teams": 2, "squad": 2, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true, "heart": true,
		"god": true, "length": 1e9})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
	var home: Vector3 = m.player.pos
	for sz in SIZES:
		DisplayServer.window_set_size(sz)
		m.sess_t0 = 60.0 - m.time
		await _grab("%d_clock" % sz.x)
		m.sess_t0 = Heart.r("tide_start_s") + 200.0 - m.time
		await _grab("%d_closing" % sz.x)
		var site: Vector3 = m.heart.site
		var d := Vector2(home.x - site.x, home.z - site.z).normalized()
		m.player.teleport(m.world.free_spot_near(site + Vector3(d.x, 0, d.y) * (Heart.tide_r(m) + OUT_M), [], 1.0, 0.45, 12.0))
		await _grab("%d_outside" % sz.x)
		m.player.teleport(home)
	main.get_tree().quit(0)

func _grab(file: String) -> void:
	for i in 24:
		m.step(Match.DT)
		m.cam.snap(m.player.pos)
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("%s.png" % file))
	print("ZONENEXT-SHOT %s  %s" % [file, HeartHud.zone_line(m)])
