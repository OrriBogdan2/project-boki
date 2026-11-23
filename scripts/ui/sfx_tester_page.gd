class_name SfxTesterPage
extends RefCounted
## Settings > Audio > Sound tester: for each slot in SfxPicks (glider wind and start, dash on the ground and in the
## air, Vex's rifle shot and reload) the candidate sounds as lettered buttons. A letter plays at once and stays in
## place of the game's sound, so it can be heard in a match too; "Lock in" keeps it, and every locked letter is
## listed at the bottom for the owner to read out. A build with no clips (a dev checkout) says so.

const LOOP_KEY := "sfx_tester"
const LOOP_SECS := 4.0  # a loop candidate plays this long, then stops
const PLAY_DB := -3.0  # dB, the audition's level
const HINT := (
	"Press a letter to hear it. It replaces the game's sound until you press Default, so you can fly, dash or shoot "
	+ "with it. Lock in keeps your pick (tell us the letters at the bottom). \u2605 marks what this build plays."
)

static var _loop_gen := 0

var _rows := {}  # slot -> {"letters": {letter: Button}, "default": Button, "state": Label}
var _picks: Label


static func fill(v: VBoxContainer) -> void:
	var page := SfxTesterPage.new()
	v.set_meta("page", page)  # the buttons call back into it: the container keeps it alive
	page._build(v)


func _build(v: VBoxContainer) -> void:
	v.add_child(UI.para(HINT))
	var any := false
	for s in SfxPicks.slots():
		if s["letters"].is_empty():
			continue
		any = true
		_slot(v, s)
	if not any:
		v.add_child(UI.para("No candidate clips in this build: they are only in the itch build."))
		return
	v.add_child(UI.spacer(4))
	v.add_child(UI.section("Your picks"))
	_picks = UI.label("", UI.T_BODY)
	v.add_child(_picks)
	v.add_child(UI.ghost("Clear all picks", _clear))
	_refresh()


func _slot(v: VBoxContainer, s: Dictionary) -> void:
	var slot := String(s["slot"])
	v.add_child(UI.spacer(4))
	v.add_child(UI.section(String(s["label"])))
	var letters := UI.hbox(6)
	var row := {"letters": {}}
	row["default"] = UI.choice("Default", false, _hear.bind(s, ""))
	letters.add_child(row["default"])
	for l in s["letters"]:
		var text: String = l + (" ★" if l == s["pick"] else "")
		var b := UI.choice(text, false, _hear.bind(s, l), 56)
		row["letters"][l] = b
		letters.add_child(b)
	v.add_child(letters)
	var acts := UI.hbox(8)
	row["state"] = UI.label("", UI.T_SMALL)
	row["state"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acts.add_child(row["state"])
	acts.add_child(UI.ghost("Play again", _play.bind(s)))
	acts.add_child(UI.primary("Lock in", _lock.bind(s)))
	v.add_child(acts)
	_rows[slot] = row


func _hear(s: Dictionary, letter: String) -> void:
	SfxPicks.choose(s, letter)
	_play(s)
	_refresh()


func _play(s: Dictionary) -> void:
	_loop_gen += 1
	Sfx.loop_stop(LOOP_KEY)
	if s["mode"] == "loop":
		Sfx.loop_start(LOOP_KEY, s["cue"], null, PLAY_DB)
		var gen := _loop_gen
		Sfx.get_tree().create_timer(LOOP_SECS).timeout.connect(
			func():
				if gen == _loop_gen:
					Sfx.loop_stop(LOOP_KEY)
		)
	else:
		Sfx.play(s["cue"], null, PLAY_DB, 0.0)


func _lock(s: Dictionary) -> void:
	SfxPicks.lock(s)
	_refresh()


func _clear() -> void:
	for s in SfxPicks.slots():
		SfxPicks.choose(s, "")
		SfxPicks.lock(s)
	_refresh()


func _refresh() -> void:
	var lines := []
	for s in SfxPicks.slots():
		var row: Dictionary = _rows.get(s["slot"], {})
		if row.is_empty():
			continue
		var heard := String(SfxPicks.trying.get(s["slot"], ""))
		var kept := String(SfxPicks.locked.get(s["slot"], ""))
		row["default"].theme_type_variation = "Chosen" if heard == "" else ""
		for l in row["letters"]:
			row["letters"][l].theme_type_variation = "Chosen" if l == heard else ""
		var playing := heard if heard != "" else "Default"
		row["state"].text = "Playing: %s    Locked: %s" % [playing, kept if kept != "" else "none"]
		if kept != "":
			lines.append("%s: %s" % [s["slot"], kept])
	_picks.text = "\n".join(lines) if not lines.is_empty() else "none locked yet"
