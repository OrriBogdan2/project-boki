extends RefCounted
## --pitch-check: the pitch reel's scripted shots (docs/PITCH_REEL.md) play through on this build without the
## movie writer, so a game change that breaks a driver shows here and not hours later on the GPU queue. The hatch
## reaches its reveal, the evolution either plays or says why it cannot, the Hunter select lands on and saves the
## chosen Hunter with its screen still up, the kit shot runs its rota with neither Hunter down or fallen off the
## island, and the escape Hunter gets out. The take watchdog kills a child that writes no frames and passes one that
## ends. The save file is never written.

const CHOSEN := "mage"       # the Hunter shot 6 is asked to land on (not the default, so the pick is seen)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("PITCHCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	var real := FileAccess.get_file_as_string(Save.path_for(Save.slot))
	_watchdog()
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
			7: ok(rig.marks.has("kit") and not rig.failed and _kit_standing(rig), "shot 7: the rota runs, both up")
			10: ok(rig.marks.has("escape") and not rig.failed, "shot 10: the Hunter rides out of the uplink")
	ok(FileAccess.get_file_as_string(Save.path_for(Save.slot)) == real, "the player's own save file is untouched")
	print("PITCH REEL CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## tools/pitch_take_filter.sh on a child that hangs (sleep, no movie) and one that ends at once.
func _watchdog() -> void:
	var filter := ProjectSettings.globalize_path("res://tools/pitch_take_filter.sh")
	var movie := OS.get_cache_dir().path_join("pitch_check_none.avi")
	OS.set_environment("PITCH_POLL_S", "1")
	var out: Array = []
	var rc := OS.execute("bash", [filter, movie, "2", "10", "sleep", "60"], out)
	ok(rc == 124 and String(out[0]).contains("PITCH_STALL"), "watchdog: a take with no new frames is killed (rc %d)" % rc)
	out.clear()
	rc = OS.execute("bash", [filter, movie, "2", "10", "echo", "PITCH_DONE"], out)
	ok(rc == 0 and String(out[0]).contains("PITCH_DONE"), "watchdog: a take that ends passes its rc and lines")
	OS.unset_environment("PITCH_POLL_S")

func _select_landed(main: Node) -> bool:
	var grid = main.current.get_meta("classes_grid", null)
	return String(Save.d.get("arch", "")) == CHOSEN and is_instance_valid(grid) and grid.is_inside_tree()

func _kit_standing(rig) -> bool:
	for h in rig.squad_a + rig.squad_b:
		if not is_instance_valid(h) or h.dead or h.downed or h.out or h.over_void():
			return false
	return true
