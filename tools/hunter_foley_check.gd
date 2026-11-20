extends RefCounted
## --hunter-foley-check: each Hunter's foley layer (HunterFoley, content/rules/hunter_foley.json, docs/AUDIO.md).
##   1. every Hunter has a row and both of its sounds (<arch>_foley steps, <arch>_foley_dash dashes) exist
##   2. a step's foley is quieter at a standstill and full at the base run speed (walk_db)
##   3. at most voice_cap foley sounds start inside one voice_window_ms, whoever they are
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HUNTERFOLEY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var rows: Dictionary = HunterFoley.rules()["rows"]
	var missing: Array = []
	for id in Arch.ids():
		var arch := String(id)
		if not rows.has(arch) or not Sfx.ensure(arch + "_foley") or not Sfx.ensure(arch + "_foley_dash"):
			missing.append(arch)
	ok(missing.is_empty(), "every Hunter has a foley row and both sounds (missing: %s)" % str(missing))
	var quiet := float(HunterFoley.rules()["walk_db"])
	ok(quiet < 0.0, "a standstill step's foley is trimmed %.1f dB under the run's" % quiet)
	var cap := int(HunterFoley.rules()["voice_cap"])
	HunterFoley._started_ms.clear()
	var started := 0
	for i in cap + 4:
		if HunterFoley._room():
			started += 1
	ok(started == cap, "%d foley sounds start in one window, the cap is %d" % [started, cap])
	HunterFoley._started_ms.clear()
	print("HUNTERFOLEY CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
