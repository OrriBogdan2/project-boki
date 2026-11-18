extends "res://tools/dash_flow_check.gd"
## --input-release-check: holds are holds. For every hero and LMB, RMB, E, R, Shift, Space and Mouse 5 (glide), a
## real press (InputEventMouseButton, or the key the action is bound to), held 0.5 s and let go: the match's held state
## for that key (Hunter.inp, Match.aim_hold) is off on the first frame after the release, and LMB starts no attack
## after the weapon's own let-go (TAIL_S: Neve's heavy darts). Then, per hero: LMB let go while the full map is up
## stops with the map closed again, and a focus loss mid-hold with no release at all (FocusRelease) lets go of every
## key. Once: a map drag whose release went to a window over the map ends when the mouse next moves, and a map you
## opened on the ship closes when you land. Frames run for real (Match._process), so the input path is the game's.
## --input-release-check=<id>,<id> picks the heroes. Never touches the save.

const HOLD_S := 0.5  # s a key is held
const TAIL_S := 0.75  # s after the release a weapon may still finish (Neve: 3 heavy darts at 0.18 s)
const WATCH_S := 1.5  # s an LMB release is watched for attacks
const KEYS := {
	"lmb": ["fire", MOUSE_BUTTON_LEFT],
	"rmb": ["secondary", MOUSE_BUTTON_RIGHT],
	"e": ["signature", 0],
	"r": ["hunter_ult", 0],
	"dash": ["dash", 0],
	"jump": ["jump", 0],
	"glide": ["glide", 0],
}
## The Hunter.inp flag each key's hold sets (E and R hold through Match.aim_hold instead).
const FLAG := {"lmb": "fire", "rmb": "sec_hold", "dash": "dash_down", "jump": "glide", "glide": "glide_btn"}

var m: Match
var at := Vector2.ZERO


func ok(cond: bool, what: String) -> void:
	print("INREL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	CombatBus.ability_used.connect(_on_used)
	var tree := main.get_tree()
	at = main.get_viewport().get_visible_rect().size * Vector2(0.6, 0.5)
	for hero in _hero_ids():
		m = _match(main, hero)
		ok(m.hud != null, "%s: the match has its HUD" % hero)
		for key in KEYS:
			await _hold_release(tree, hero, key)
		await _release_under_map(tree, hero)
		for key in KEYS:
			await _focus_out(tree, hero, key)
		if hero == _hero_ids()[0]:
			await _map_drag(tree)
			_map_on_landing()
		m.queue_free()
		await tree.process_frame
	CombatBus.ability_used.disconnect(_on_used)
	print("INREL DONE, failures: %d" % bad)
	tree.quit()


func _hero_ids() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input-release-check=") and arg.length() > 22:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER


## The key's hold is still on in the match: its Hunter.inp flag, or an aimed E/R waiting for its release.
func _held(key: String) -> bool:
	if FLAG.has(key):
		return bool(hunter.inp.get(FLAG[key], false))
	return m.aim_hold == String(KEYS[key][0])


func _send(key: String, down: bool) -> void:
	var button: int = KEYS[key][1]
	if button != 0:
		var e := InputEventMouseButton.new()
		e.button_index = button as MouseButton
		e.pressed = down
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		return
	var ev := (InputMap.action_get_events(String(KEYS[key][0]))[0] as InputEvent).duplicate() as InputEvent
	if ev is InputEventKey:
		(ev as InputEventKey).pressed = down
	elif ev is InputEventMouseButton:  # (glide: Mouse 5)
		(ev as InputEventMouseButton).pressed = down
	Input.parse_input_event(ev)


## Real frames for `secs` of match time; returns how many LMB attacks started and when the last one did.
func _frames(tree: SceneTree, secs: float) -> Array:
	var t0 := m.time
	var n := 0
	var last := -1.0
	var before := _snap()
	while m.time - t0 < secs:
		await tree.process_frame
		if _went_off(before, "lmb"):
			n += 1
			last = m.time - t0
		before = _snap()
	return [n, last]


## One whole frame: process_frame resumes before that frame's Match._process, so the second one is after it.
func _one_frame(tree: SceneTree) -> void:
	await tree.process_frame
	await tree.process_frame


func _start(tree: SceneTree) -> void:
	m.set_process(false)
	_ready_up(m)
	m.set_process(true)
	await tree.process_frame


func _hold_release(tree: SceneTree, hero: String, key: String) -> void:
	await _start(tree)
	_send(key, true)
	await _frames(tree, HOLD_S)
	_send(key, false)
	await _one_frame(tree)
	ok(not _held(key), "%s %s: held 0.5 s, off the frame after the release" % [hero, key])
	if key == "lmb":
		var after: Array = await _frames(tree, WATCH_S)
		ok(
			float(after[1]) <= TAIL_S,
			(
				"%s lmb: no attack starts %.2f s after the release (%d after it, last at %.2f s)"
				% [hero, TAIL_S, after[0], after[1]]
			)
		)
	m.set_process(false)


## LMB held, the map comes up, the button comes up under it, the map closes: no firing.
func _release_under_map(tree: SceneTree, hero: String) -> void:
	await _start(tree)
	_send("lmb", true)
	await _frames(tree, 0.2)
	m.hud.full_map.open()
	await _frames(tree, 0.1)
	_send("lmb", false)
	await _frames(tree, 0.1)
	m.hud.close_map()
	await _one_frame(tree)
	ok(not _held("lmb"), "%s lmb: let go under the map, off once it closes" % hero)
	var after: Array = await _frames(tree, 1.0)
	ok(float(after[1]) <= TAIL_S, "%s lmb: no firing after the map closes (last at %.2f s)" % [hero, after[1]])
	m.set_process(false)


## The window loses focus mid-hold and the release never comes: the key is let go anyway.
func _focus_out(tree: SceneTree, hero: String, key: String) -> void:
	await _start(tree)
	_send(key, true)
	await _frames(tree, 0.2)
	m.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _one_frame(tree)
	var action := String(KEYS[key][0])
	ok(not _held(key) and not Input.is_action_pressed(action), "%s %s: a focus loss mid-hold lets it go" % [hero, key])
	if key == "lmb":
		var after: Array = await _frames(tree, 1.0)
		ok(float(after[1]) <= TAIL_S, "%s lmb: no firing after the focus loss (last at %.2f s)" % [hero, after[1]])
	_send(key, false)
	m.set_process(false)


## A press on the zoomed map whose release a window over the map took: the next mouse move ends the drag.
func _map_drag(tree: SceneTree) -> void:
	var fm: FullMap = m.hud.full_map
	fm.open()
	await tree.process_frame
	fm.zoom = 2.0
	var on_map := fm.rect.get_center()
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = on_map
	fm.input(e)
	var up := e.duplicate() as InputEventMouseButton
	up.pressed = false
	m.hud.set_process_unhandled_input(false)  # the Input state sees the release, the map's input() does not
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	m.hud.set_process_unhandled_input(true)
	var mv := InputEventMouseMotion.new()
	mv.position = on_map + Vector2(80, 0)
	var center := fm.center
	fm.input(mv)
	ok(fm.center == center, "map: a drag whose release went elsewhere ends on the next move")
	fm.close()


## A map opened by hand on the ship (it stays up through the ride) closes when the drop lands.
func _map_on_landing() -> void:
	m.hud.full_map.open()
	DropFeel.land(m, hunter)
	ok(not m.hud.map_open(), "map: opened on the ship, closed on landing")
