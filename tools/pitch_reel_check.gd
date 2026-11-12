extends RefCounted
## --pitch-check: the pitch reel's scripted shots (docs/PITCH_REEL.md) play through on this build without the
## movie writer, so a game change that breaks a driver shows here and not hours later on the GPU queue. The hatch
## reaches its reveal, the evolution either plays or says why it cannot, the Hunter select lands on and saves the
## chosen Hunter with its screen still up, the kit shot runs its rota and the escape Hunter gets out. The save file
## is never written.

const CHOSEN := "mage"       # the Hunter shot 6 is asked to land on (not the default, so the pick is seen)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("PITCHCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	var real := FileAccess.get_file_as_string(Save.path_for(Save.slot))
	var rig = load("res://tools/pitch_reel.gd").new()
	rig.main = main
	for s in [2, 3, 6, 7, 10]:
		rig.shot = s
		rig.hunter = CHOSEN if s == 6 else Demo.DEFAULT_HUNTER
		rig.set_up_take()
		await rig.play()
		match s:
			2: ok(rig.marks.has("reveal") and not rig.failed, "shot 2: the egg cracks and the Boki is revealed")
			3: ok(rig.marks.has("evolve") != rig.failed, "shot 3: the evolution plays, or fails saying why")
			6: ok(_select_landed(main), "shot 6: lands on %s, saves the pick, the screen stays up" % CHOSEN)
			7: ok(rig.marks.has("kit") and not rig.failed, "shot 7: the kit rota runs")
			10: ok(rig.marks.has("escape") and not rig.failed, "shot 10: the Hunter rides out of the uplink")
	ok(FileAccess.get_file_as_string(Save.path_for(Save.slot)) == real, "the player's own save file is untouched")
	print("PITCH REEL CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _select_landed(main: Node) -> bool:
	var grid = main.current.get_meta("classes_grid", null)
	return String(Save.d.get("arch", "")) == CHOSEN and is_instance_valid(grid) and grid.is_inside_tree()
