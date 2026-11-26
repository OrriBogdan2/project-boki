extends RefCounted
## --tutorial-boki-video --shots-dir=<dir>: the tutorial's Boki beat on film, for the owner. The real tutorial course is
## played by TutorialDrive up to the summon step, then to END_S after the Boki is out, the HUD showing (the one line
## that names the Boki key, the Boki's slot, the Boki going at the monster). Recorded like tools/gameplay_media.gd
## (a child Godot under the movie writer, 30 fps, <dir>/clip1.avi); run it on a GPU worker (jobq --needs gpu).
## Prints MEDIA_TUTBOKI lines with the seconds. --kin=<species> picks the Boki (default cindle).

const END_S := 5.0  # s of film after the Boki is out
const MAX_S := 240.0  # s of course before giving up

var main: Node
var gm
var out_t := -1.0
var acted_t := -1.0
var kin := "cindle"


func run(main_node: Node) -> void:
	main = main_node
	gm = load("res://tools/gameplay_media.gd").new()
	gm.main = main
	var child := false
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		child = child or arg == "--media-child"
		if arg.begins_with("--kin="):
			kin = arg.substr(6)
		if arg.begins_with("--shots-dir="):
			gm.dir = arg.substr(12)
	if String(gm.dir).is_relative_path():
		gm.dir = ProjectSettings.globalize_path("res://").path_join(gm.dir)
	DirAccess.make_dir_recursive_absolute(gm.dir)
	if not child:
		gm._record("1920x1080")
		return
	Save.no_write = true
	Save.d = Save.fresh()
	await _film()
	print("MEDIA_DONE clip=1")
	main.get_tree().quit(0)


func _film() -> void:
	var m := Match.new()
	main.add_child(m)
	m.start(
		{
			"tutorial": true,
			"teams": 1,
			"squad": 1,
			"tier": 0,
			"length": 1500.0,
			"demo_kin": kin,
			"arch": "gunslinger",
			"cls": Arch.weight("gunslinger")
		}
	)
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	gm.m = m
	gm.mobs_on = true
	var each := func(_t: float) -> void:
		TutorialDrive.drive(m)
		var k: Kin = m.player.kin
		if m.tut.id() == "summon" and m.tut.sm.phase == TutorialSummon.OUT and out_t < 0.0:
			out_t = m.time
			print("MEDIA_TUTBOKI line '%s' out at %.1f s" % [m.tut.text, m.time])
		if out_t >= 0.0 and acted_t < 0.0 and (k.target != null or k.st_hits + k.st_skills > 0):
			acted_t = m.time
			print("MEDIA_TUTBOKI Boki goes at a monster %.1f s after it is out" % (m.time - out_t))
	var t := 0.0
	while t < MAX_S and (out_t < 0.0 or m.time - out_t < END_S):
		await gm._go(0.5, each, func(_t): return m.player.pos, true)
		t += 0.5
