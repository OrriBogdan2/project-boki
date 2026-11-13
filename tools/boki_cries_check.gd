extends RefCounted
## --boki-cries-check: the Boki cries (docs/AUDIO.md, tools/gen_boki_cries.py).
##   1. the manifest audio/cries/cries.json loads and every entry's file exists and is one short call (CRY_S)
##   2. a line's stages are numbered 1..n without gaps, and a branch form has a parent stage
##   3. every species in Data.KIN resolves to a cry (BokiCry.path), so the Bokidex never plays silence
## Reads the files only; never touches the save. The loudness and family numbers are tools/cries_stats.py.

const CRY_S := Vector2(0.35, 1.45)    # s: the generator's 0.4-1.4 s range plus the import's rounding

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CRIES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	var man = JSON.parse_string(FileAccess.get_file_as_string("res://audio/cries/cries.json"))
	ok(man is Dictionary and man.has("cries") and man.has("lines"), "the manifest loads")
	var cries: Dictionary = man.get("cries", {}) if man is Dictionary else {}
	var missing := 0
	var odd_len := 0
	for fid in cries:
		var e: Dictionary = cries[fid]
		var p := "res://" + String(e["file"])
		if not ResourceLoader.exists(p):
			missing += 1
			continue
		var st: AudioStream = load(p)
		var s := st.get_length()
		if s < CRY_S.x or s > CRY_S.y:
			odd_len += 1
	ok(cries.size() >= 250 and missing == 0, "%d cries listed, %d files missing" % [cries.size(), missing])
	ok(odd_len == 0, "%d cries outside %.2f-%.2f s" % [odd_len, CRY_S.x, CRY_S.y])
	var gaps := 0
	for line in man.get("lines", {}):
		var stages := {}
		for fid in man["lines"][line]:
			stages[int(cries[fid]["stage"])] = true
		for s in range(1, stages.size() + 1):
			if not stages.has(s):
				gaps += 1
	ok(gaps == 0, "every line's stages run 1..n (%d gaps)" % gaps)
	var silent: Array = []
	for sp in Data.KIN:
		if BokiCry.path(sp) == "":
			silent.append(sp)
	ok(silent.is_empty(), "every species has a cry (silent: %s)" % ", ".join(silent))
	print("CRIES DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
