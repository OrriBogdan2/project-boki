extends RefCounted
## --ride-shots --shots-dir=<dir>: item 163's camera. Frames of the skyship ride (the whole ship in frame with the
## squad aboard) and of the launch (the camera follows the squad down and the ship recedes overhead):
## ride_*.png. Run on a real GPU (jobq --needs gpu).

const RIDE_FRAMES := [30, 120]          # frames into the ride
const LAUNCH_FRAMES := [20, 70, 160]    # frames after the jump

var main: Node

func _save(dir: String, file: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(file))
	print("RIDESHOT %s" % file)

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	var dir := "user://ride_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1500.0, "seed": 4242})
	var frame := 0
	while frame < int(RIDE_FRAMES[-1]) + 1:
		if m.skydrop:
			m.skydrop.planning = false
		await main.get_tree().process_frame
		frame += 1
		if frame in RIDE_FRAMES:
			_save(dir, "ride_%03d.png" % frame)
	m.ship_jump(m.skydrop.leader(m.player.team) if m.skydrop else m.player, true)
	frame = 0
	while frame < int(LAUNCH_FRAMES[-1]) + 1:
		await main.get_tree().process_frame
		frame += 1
		if frame in LAUNCH_FRAMES:
			_save(dir, "ride_launch_%03d.png" % frame)
	print("RIDESHOT DONE")
	main.get_tree().quit()
