extends RefCounted
## --farm-sound-check: the farm no longer plays the bare "unlock" chime for its reactions (SFX_AUDIT row 22).
##   1. no script under scripts/home or scripts/ui plays "unlock" (it is left to real unlocks in a match)
##   2. the four FarmCue sounds are distinct from "unlock" and from each other, sit in the UI sound set and load
##   3. every FarmCue sound has at least one call in the farm scripts
## Reads the sources and the sound set only; never touches the save.

const DIRS := ["res://scripts/home", "res://scripts/ui"]
const CUES := [FarmCue.APPEAR, FarmCue.BUY, FarmCue.LEVEL, FarmCue.GOAL]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("FARMSOUND %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	var bare := 0
	var uses := {}
	for d in DIRS:
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string("%s/%s" % [d, f])
			if src.contains("Sfx.play(\"unlock\"") or src.contains("\"unlock\" if"):
				bare += 1
				print("FARMSOUND bare unlock in %s/%s" % [d, f])
			for c in CUES:
				var needle := "Sfx.play(FarmCue.%s" % String(c).trim_prefix("farm_").to_upper()
				uses[c] = int(uses.get(c, 0)) + src.count(needle)
	ok(bare == 0, "no farm script plays the bare unlock (%d files do)" % bare)
	var set_d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/ui.json"))
	var seen := {}
	for c in CUES:
		ok(c != "unlock" and not seen.has(c), "%s is its own cue" % c)
		seen[c] = true
		ok((set_d["sounds"] as Dictionary).has(c) and Sfx.ensure(c), "%s is in the UI set and loads" % c)
		ok(int(uses.get(c, 0)) > 0, "%s is played by the farm (%d calls)" % [c, int(uses.get(c, 0))])
	print("FARMSOUND DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
