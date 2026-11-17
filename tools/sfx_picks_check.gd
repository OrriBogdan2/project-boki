extends RefCounted
## --sfx-picks-check: the library picks and the in-game sound tester (docs/SFX_LIBRARY.md).
##   1. the pack manifest: every slot has a game cue file, a pick that is one of its candidates (or none), the
##      owner's 11-15 letters, and the tester slots the owner asked for (the library clips themselves never sit in git)
##   2. the tester: trying a letter swaps the cue's stream, the build's own comes back, a lock survives a restart
##      and its page lists the letters, plays the one pressed and shows what is locked
##   3. the dash is chosen by the floor under it (dash_ground / dash_air), for a Hunter with and without its own sets,
##      and a tester pick for the shared path beats the Hunter's own
##   4. every glider skin has glide cues that exist; a skin with its own material has its own wind loop
## Reads the files; never touches the save (the picks file is removed again).

const OWNER_PICKS := {
	"ghost_shot": "A",
	"ghost_reload": "B",
	"take_damage": "B",
	"hit_confirm": "D",
	"knockout": "B",
	"scan_capture": "A",
	"ui_click": "A",
	"level_up": "A",
}
const TESTER_SLOTS := ["glide_loop", "glide_start", "dash_ground", "dash_air", "ghost_shot", "ghost_reload"]

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("SFXPICKS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	_manifest()
	_tester()
	_page()
	_dash()
	_gliders()
	print("SFXPICKS DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _manifest() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SfxPicks.MANIFEST))
	var by_slot := {}
	var broken := []
	for s in doc["slots"]:
		by_slot[s["slot"]] = s
		var letters: Array = (s["candidates"] as Array).map(func(c): return c["letter"])
		if not ResourceLoader.exists("res://audio/%s.wav" % s["cue"]):
			broken.append("%s: no audio/%s.wav" % [s["slot"], s["cue"]])
		if s["pick"] != "" and not s["pick"] in letters:
			broken.append("%s: pick %s is no candidate" % [s["slot"], s["pick"]])
	ok(broken.is_empty(), "manifest: every cue has its file and every pick is a candidate %s" % [broken])
	var wrong := OWNER_PICKS.keys().filter(func(k): return not by_slot.has(k) or by_slot[k]["pick"] != OWNER_PICKS[k])
	ok(wrong.is_empty(), "manifest: the owner's letters (11-15) are the picks (wrong: %s)" % [wrong])
	var kept_live := ["glide_start", "glide_loop", "extract", "dash_ground", "dash_air"].filter(
		func(k): return by_slot.has(k) and by_slot[k]["pick"] != ""
	)
	ok(
		kept_live.is_empty(),
		"manifest: glide, extract and the dash keep the generated sounds (picked: %s)" % [kept_live]
	)
	var missing := TESTER_SLOTS.filter(func(k): return not by_slot.has(k) or not by_slot[k].get("tester", false))
	ok(missing.is_empty(), "manifest: the six tester slots are marked (missing: %s)" % [missing])
	var thin := ["glide_loop", "glide_start", "ghost_shot", "ghost_reload"].filter(
		func(k): return (by_slot[k]["candidates"] as Array).size() < 4
	)
	ok(thin.is_empty(), "manifest: those tester slots offer at least 4 candidates (thin: %s)" % [thin])


func _tester() -> void:
	var saved_clip := SfxPicks.clip
	var saved_list := SfxPicks.list
	SfxPicks.clip = "res://audio/%s%s.wav"  # stand-in clips: audio/glider_wind_leaf.wav and _fire.wav
	var slot := {
		"slot": "glider_wind",
		"label": "t",
		"cue": "glider_wind",
		"mode": "loop",
		"pick": "",
		"letters": ["_leaf", "_fire"]
	}
	SfxPicks.list = [slot]
	SfxPicks.trying = {}
	SfxPicks.locked = {}
	Sfx.ensure("glider_wind")
	var own = Sfx.streams["glider_wind"]
	SfxPicks.choose(slot, "_leaf")
	ok(
		SfxPicks.active("glider_wind") and Sfx.streams["glider_wind"] != own,
		"tester: a letter replaces the cue's stream"
	)
	SfxPicks.choose(slot, "_fire")
	SfxPicks.choose(slot, "")
	ok(
		not SfxPicks.active("glider_wind") and Sfx.streams["glider_wind"] == own,
		"tester: Default brings the build's sound back"
	)
	SfxPicks.choose(slot, "_fire")
	SfxPicks.lock(slot)
	var kept = JSON.parse_string(FileAccess.get_file_as_string(SfxPicks.FILE))
	ok(
		kept is Dictionary and kept.get("glider_wind") == "_fire",
		"tester: Lock in writes user://sfx_picks.json (%s)" % [kept]
	)
	SfxPicks.choose(slot, "")
	SfxPicks.locked = {}
	SfxPicks.load_locked()
	ok(
		SfxPicks.locked.get("glider_wind") == "_fire" and SfxPicks.active("glider_wind"),
		"tester: a locked pick plays again at the next start"
	)
	SfxPicks.choose(slot, "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SfxPicks.FILE))
	SfxPicks.clip = saved_clip
	SfxPicks.list = saved_list
	SfxPicks.trying = {}
	SfxPicks.locked = {}


func _page() -> void:
	var saved_clip := SfxPicks.clip
	var saved_list := SfxPicks.list
	SfxPicks.clip = "res://audio/%s%s.wav"
	var slot := {
		"slot": "glider_wind",
		"label": "Glider wind",
		"cue": "glider_wind",
		"mode": "loop",
		"pick": "_leaf",
		"letters": ["_leaf", "_fire"]
	}
	SfxPicks.list = [slot]
	var v := VBoxContainer.new()
	SfxTesterPage.fill(v)
	var buttons := {}
	var texts := []
	var stack := [v]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Button:
			buttons[(n as Button).text] = n
		elif n is Label:
			texts.append((n as Label).text)
	ok(
		buttons.has("_leaf \u2605") and buttons.has("_fire") and buttons.has("Default") and buttons.has("Lock in"),
		"page: Default, each letter (the build's pick starred) and Lock in are buttons (%s)" % [buttons.keys()]
	)
	(buttons["_fire"] as Button).pressed.emit()
	(buttons["Lock in"] as Button).pressed.emit()
	var shown := false
	stack = [v]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		shown = shown or (n is Label and (n as Label).text == "glider_wind: _fire")
	ok(shown and SfxPicks.active("glider_wind"), "page: pressing a letter plays it, Lock in lists it on screen")
	SfxPicks.choose(slot, "")
	SfxPicks.lock(slot)
	SfxPicks.clip = saved_clip
	SfxPicks.list = saved_list
	SfxPicks.trying = {}
	SfxPicks.locked = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SfxPicks.FILE))
	v.free()


func _dash() -> void:
	var h := Hunter.new()
	var same := []
	for arch in Arch.ids() + ["no_such_hunter"]:
		h.arch = arch
		h.grounded = false
		var air := HeroSfx.dash_name(h)
		h.grounded = true
		var ground := HeroSfx.dash_name(h)
		if air == ground or not Sfx.ensure(air) or not Sfx.ensure(ground):
			same.append(arch)
	ok(
		same.is_empty(),
		"dash: every Hunter plays a different, existing sound in the air and on the ground (%s)" % [same]
	)
	h.arch = "no_such_hunter"
	h.grounded = true
	var shared := [HeroSfx.dash_name(h)]
	h.grounded = false
	shared.append(HeroSfx.dash_name(h))
	ok(
		shared == ["dash_ground", "dash_air"],
		"dash: with no set of its own the floor picks dash_ground or dash_air (%s)" % [shared]
	)
	var slot := {"slot": "dash_air", "label": "t", "cue": "dash_air", "mode": "oneshot", "pick": "", "letters": ["_1"]}
	var saved_clip := SfxPicks.clip
	SfxPicks.clip = "res://audio/%s%s.wav"
	h.arch = "gunslinger"
	SfxPicks.choose(slot, "_1")
	ok(HeroSfx.dash_name(h) == "dash_air", "dash: a tester pick for the air dash beats the Hunter's own")
	h.grounded = true
	ok(HeroSfx.dash_name(h) == "gunslinger_dash", "dash: ...and leaves the ground dash alone")
	SfxPicks.choose(slot, "")
	SfxPicks.clip = saved_clip
	SfxPicks.trying = {}
	h.free()


func _gliders() -> void:
	var missing := []
	var plain := []
	for g in Gliders.LIST:
		for which in ["start", "loop"]:
			if not Sfx.ensure(Gliders.glide_cue(String(g["id"]), which)):
				missing.append("%s %s" % [g["id"], which])
		if String(g["sound"]) != "cloth" and Gliders.glide_cue(String(g["id"]), "loop") == Gliders.DEFAULT_WIND:
			plain.append(g["id"])
	ok(missing.is_empty(), "gliders: every skin's start and loop cue has its file (%s)" % [missing])
	ok(plain.is_empty(), "gliders: every skin that is not cloth has its own wind loop (plain: %s)" % [plain])
	ok(
		(
			Gliders.glide_cue("classic", "start") == "glider_snap"
			and Gliders.glide_cue("leaf", "loop") == "glider_wind_leaf"
		),
		"gliders: the default is the cloth wing's cues, a leaf's wind is its own"
	)
	var listed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/glider.json"))["sounds"]
	var unlisted := Gliders.LIST.filter(func(g): return g.has("glide_loop") and not listed.has(g["glide_loop"]))
	ok(
		unlisted.is_empty(),
		"gliders: every skin loop is listed in glider.json, so --sfx-set-check holds its level and seam"
	)
