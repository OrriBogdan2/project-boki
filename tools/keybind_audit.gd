extends RefCounted
## The "every action the game uses is rebindable" audit behind --keybind-check (DECISIONS 2026-11-08).
## problems() lists what breaks it: an input action the game registers or reads that is not in
## Settings.ACTIONS (so not in Settings > Controls), an action that ships without a key, and a physical
## key read straight from an event in a file that is not on the fixed-key list below.

## Actions the game registers and reads but keeps off the Controls page: Esc always opens the menu (it is also
## the rebind cancel); swap_kin is the retired second-Boki swap (Match.TWO_KIN is false, nothing presses it).
const NOT_LISTED := ["menu", "swap_kin"]
## Controls actions that ship with no key on purpose (a new player sees only G for the Boki).
const SHIPS_UNBOUND := ["kin_summon", "kin_chase", "kin_guard", "kin_return", "kin_follow"]
## Files that may name a physical key, and why: dev rigs, list picks by number, menu conventions.
const FIXED_KEYS := {
	"scripts/match/arena.gd": "Arena test rig: its own debug keys",
	"scripts/match/duel.gd": "Duel test rig: its own debug keys",
	"scripts/home/base_tumble.gd": "1-3 pick one of the cards on screen",
	"scripts/home/home.gd": "1-9 pick the n-th hub entry",
	"scripts/ui/build_catalog.gd": "Esc and Enter in the open catalog",
	"scripts/ui/loadout_panel.gd": "Enter and Delete on the hovered card",
	"scripts/ui/overlay.gd": "Esc cancels a rebind",
	"scripts/ui/title.gd": "W and S walk the menu like the arrow keys",
	"scripts/main.gd": "test code that sends F9 and F10 on purpose",
	"scripts/core/settings.gd": "the Controls page itself", "scripts/core/game.gd": "the shipped defaults",
}

static func problems() -> Array:
	var out: Array = []
	var listed := {}
	for a in Settings.ACTIONS:
		var id := String(a[0])
		if listed.has(id) or String(a[1]).is_empty():
			out.append("%s: duplicate or unnamed row in Settings.ACTIONS" % id)
		listed[id] = true
		if not InputMap.has_action(id): out.append("%s: listed in Controls but not an input action" % id)
		elif InputMap.action_get_events(id).is_empty() and not id in SHIPS_UNBOUND:
			out.append("%s: ships with no key" % id)
	for id in InputMap.get_actions():
		var s := String(id)
		if not (s.begins_with("ui_") or s.begins_with("kf_") or listed.has(s) or s in NOT_LISTED):
			out.append("%s: an input action that Settings > Controls does not list" % s)
	var keys := ClassDB.class_get_integer_constant_list("@GlobalScope")
	var act := RegEx.create_from_string("is_action(?:_just)?(?:_pressed|_released)?\\(\"(\\w+)\"")
	var key := RegEx.create_from_string("\\bKEY_[A-Z0-9_]+\\b")
	for f: String in _scripts("res://scripts"):
		var src: String = FileAccess.get_file_as_string(f)
		for m in act.search_all(src):
			var s := m.get_string(1)
			if not (s.begins_with("ui_") or s.begins_with("kf_") or listed.has(s) or s in NOT_LISTED):
				out.append("%s reads the action '%s', which Controls does not list" % [f, s])
		var rel: String = f.trim_prefix("res://")
		if FIXED_KEYS.has(rel) or rel.begins_with("scripts/feel/"): continue
		for m in key.search_all(src):
			if m.get_string() in keys:
				out.append("%s names %s directly: make it a Controls action" % [rel, m.get_string()])
				break
	return out

static func _scripts(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"): out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
