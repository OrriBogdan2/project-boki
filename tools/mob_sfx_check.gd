extends RefCounted
## --mob-sfx-check: monster death and stagger sounds (scripts/match/mob_sfx.gd).
##   1. each of the 7 voiced kinds (the v_<kind> sounds) has its own death cue, distinct, and the file plays
##   2. bosses speak with the Watcher's cue, Blight kinds with their base kind's, a Shrubling keeps the generic pop
##   3. a pack dying at once is capped: DEATH_CAP cues per DEATH_WINDOW_MS across all kinds, then room again
##   4. the stagger open tick and landed hit exist, every elite and boss can stagger, and Match plays them
##   5. every cue is positional (played at the monster, never as a UI sound)
## Reads the data and source only; never touches the save.

const VOICED := ["skitter", "spitter", "brute", "bomber", "sentinel", "glimmer", "warden"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MOBSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	var cues := {}
	for kind in VOICED:
		cues[kind] = MobSfx.death_cue(kind)
	var seen := cues.values()
	var silent := VOICED.filter(func(k): return not Sfx.ensure(cues[k]) or not Sfx.ensure("v_" + k))
	var mapped := silent.is_empty() and seen.size() == 7 and _distinct(seen)
	ok(mapped, "7 kinds -> 7 distinct cues on file %s (silent: %s)" % [cues, silent])
	var boss_ok := true
	for b in MobSfx.BOSS_PITCH:
		boss_ok = boss_ok and MobSfx.death_cue(b) == cues["warden"]
	var blight: bool = MobSfx.death_cue("bl_skitter") == cues["skitter"]
	blight = blight and MobSfx.death_cue("bl_warden") == cues["warden"]
	var generic: bool = MobSfx.death_cue("shrubling") == ""
	ok(boss_ok and blight and generic, "bosses -> Watcher cue, Blight kinds -> base kind, Shrubling -> generic")
	_cap()
	var elite_ok := true
	for kind in Data.MOBS:
		var md: Dictionary = Data.MOBS[kind]
		if md.get("boss", false) and not md.get("stag", false):
			elite_ok = false
	var stag_files: bool = Sfx.ensure("mstag_open") and Sfx.ensure("mstag_hit")
	ok(stag_files and elite_ok, "stagger open tick and landed hit exist; every boss can stagger")
	var src := FileAccess.get_file_as_string("res://scripts/match/match.gd")
	var wired := ["MobSfx.death(self, mb, big_mob)", "MobSfx.death(self, who as Mob", "MobSfx.stagger_open(self, mb)",
		"MobSfx.stagger_hit(self, mb)", "MobSfx.stagger_hit(self, smb"]
	ok(wired.all(func(w): return src.contains(w)), "Match plays them: deaths, window opening, landed stagger")
	var msrc := FileAccess.get_file_as_string("res://scripts/match/mob_sfx.gd")
	var flat: Array = Array(msrc.split("\n")).filter(func(l): return l.contains("m.sfx(") and not l.contains("mb.pos"))
	var n_cues := msrc.count("m.sfx(")
	ok(flat.is_empty() and n_cues == 4, "all %d cues are positional (at mb.pos)" % n_cues)
	print("MOBSFX DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _distinct(a: Array) -> bool:
	for i in a.size():
		if a[i] == "" or a.find(a[i]) != i:
			return false
	return true

## A burst of 12 deaths in one millisecond lets DEATH_CAP through; once the window has passed, one more fits.
func _cap() -> void:
	MobSfx.recent.clear()
	var n := 0
	for i in 12:
		if MobSfx.admit(5000):
			n += 1
	var later := MobSfx.admit(5000 + MobSfx.DEATH_WINDOW_MS + 1)
	MobSfx.recent.clear()
	var what := "a pack of 12 dying at once plays %d cues (cap %d per %d ms), then one more after the window"
	ok(n == MobSfx.DEATH_CAP and later, what % [n, MobSfx.DEATH_CAP, MobSfx.DEATH_WINDOW_MS])
