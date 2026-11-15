extends RefCounted
## --squad-intro-shots --shots-dir=<dir>: the squad intro and the skyship ride (0.24.4) on a real GPU
## (jobq --needs gpu): intro_*.png at points through the intro, ride_*.png on the ride once the plan
## is over, ride_launch.png after the jump (the ship overhead), ground_*.png once the squad is down.

const INTRO_AT := [0.4, 1.4, 2.4, 3.6, 4.6]    # s into the intro
const RIDE_FRAMES := [40, 160]                  # frames into the ride
const LAUNCH_FRAME := 60                        # frames after the jump
const GROUND_FRAMES := [1, 90]                  # frames after the player lands

var main: Node

func _save(dir: String, file: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(file))
	print("INTROSHOT %s" % file)

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	var dir := "user://squad_intro_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	SquadIntro._last_lineup = ""
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1500.0, "seed": 4242, "squad_intro": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)      # the boot splash stays up when a check starts the match by hand
	var shot := 0
	while m.intro and m.intro.running() and shot < INTRO_AT.size():
		await main.get_tree().process_frame
		if m.intro.t >= float(INTRO_AT[shot]):
			_save(dir, "intro_%d.png" % shot)
			shot += 1
	if m.skydrop:
		m.skydrop.plan_t = 0.01     # the plan's map is not what these shots are for
	for f in int(RIDE_FRAMES[-1]) + 1:
		await main.get_tree().process_frame
		if f in RIDE_FRAMES:
			_save(dir, "ride_%03d.png" % f)
	m.ship_jump(m.skydrop.leader(m.player.team) if m.skydrop else m.player, true)
	for f in LAUNCH_FRAME + 1:
		await main.get_tree().process_frame
	_save(dir, "ride_launch.png")
	var waited := 0
	while m.player.dropping and waited < 3000:
		await main.get_tree().process_frame
		waited += 1
	for f in int(GROUND_FRAMES[-1]) + 1:
		await main.get_tree().process_frame
		if f in GROUND_FRAMES:
			_save(dir, "ground_%03d.png" % f)
	print("INTROSHOT DONE")
	main.get_tree().quit()
