extends RefCounted
## --drop-clean-shots --shots-dir=<dir>: the game camera through the drop, one PNG per 1/30 s (f_0000.png ...):
## RIDE_S seconds aboard the sky ship with the squad, the jump, then AIR_S seconds of the launch and glide.
## Encode with ffmpeg -framerate 30 -i f_%04d.png. Run on a real GPU (jobq --needs gpu).

const RIDE_S := 3.0       # s aboard shown before the jump
const AIR_S := 5.0        # s after the jump
const FPS := 30.0         # frames a second of the clip

var main: Node

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	var dir := "user://drop_clean"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 3, "tier": 0, "length": 1500.0, "seed": 4242, "demo_kin": "zapple"})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	m.set_process(false)
	m.skydrop.planning = false
	var jump_t := float(m.ship["dur"]) * 0.5
	m.time = jump_t - RIDE_S
	var n := 0
	var air := 0.0
	while air < AIR_S:
		if m.player.riding and m.time >= jump_t:
			m.ship_jump(m.skydrop.leader(m.player.team), true)
		m._process(1.0 / FPS)
		await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("f_%04d.png" % n))
		n += 1
		if not m.player.riding:
			air += 1.0 / FPS
	print("DROPSHOT DONE frames=%d" % n)
	main.get_tree().quit()
