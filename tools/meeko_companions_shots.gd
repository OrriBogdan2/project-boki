extends "res://tools/gameplay_media.gd"
## --meeko-companions-shots --shots-dir=<dir> [--hero=tender] [--face] [--eye=<m>]: Meeko alone in a real match, her sun and cloud
## in game view (zoom 1.0), mid (0.5) and close (zoom --close=<z>, default 0.2), over 4 orbit phases, as
## <dir>/<tag>_<phase>_<view>.png. Needs a renderer (jobq --needs gpu).

const SIZE := Vector2i(1600, 900)
const FACE_CAM := Vector3(0, 0.9, 3.0)
const PHASES := 4
const STATES := [  # [name, held inputs, s held before the shot]
	["run", {"move": Vector2(1, 0.4)}, 1.0], ["fire", {"fire": true}, 0.25], ["ult", {"ult": true}, 0.4],
	["dash", {"dash": true, "move": Vector2(1, 0)}, 0.2], ["jump", {"jump": true}, 0.35], ["crouch", {"crouch": true}, 0.8],
]
const PHASE_SECS := 1.0
var face := false
var close := 0.2
var eye := -1.0  # --eye=<m>: the game camera dropped to this height above her feet, level, three-quarter front; each state also writes game_<state>.png at the game camera
const EYE_OFF := Vector2(2.4, 3.8)  # m: where it stands (x, z) from her
const EYE_STATES := [["idle", {}, 1.5], ["run", {"move": Vector2(1, 0.4)}, 1.0], ["fire", {"fire": true}, 0.25]]


func run(main_node: Node) -> void:
	main = main_node
	var hero := "tender"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--hero="):
			hero = String(a).substr(7)
		if String(a) == "--face":
			face = true
		if String(a).begins_with("--eye="):
			eye = float(String(a).substr(6))
		if String(a).begins_with("--close="):
			close = float(String(a).substr(8))
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	main.get_window().size = SIZE
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	await _start(hero, "cindle")
	m.player.ctrl = "idle"
	m.player.teleport(_ground(m.player.pos))
	if eye >= 0.0:
		for st in EYE_STATES:
			await _take(st[2], 1.0, "eye%03d_%s.png" % [int(eye * 100), st[0]], st[1])
			var keep := eye  # (and the same beat at the game camera, so an eye-level sheet always has its game-view row)
			eye = -1.0
			await _take(0.05, 1.0, "game_%s.png" % st[0], st[1])
			eye = keep
			for _i in 40:
				m.step(STEP)
		print("MEEKOSHOTS done in %s" % dir)
		main.get_tree().quit(0)
		return
	for i in PHASES:
		await _take(1.5 if i == 0 else PHASE_SECS, 1.0, "p%d_game.png" % i)
		await _take(0.05, 0.5, "p%d_mid.png" % i)
		await _take(0.05, close, "p%d_close.png" % i)
	for st in STATES:  # her moves: each held for a beat, then shot mid (zoom 0.5) and close
		await _take(st[2], 0.5, "%s_mid.png" % st[0], st[1])
		await _take(0.05, close, "%s_close.png" % st[0], st[1])
		for _i in 40:  # (back to idle between moves)
			m.step(STEP)
	print("MEEKOSHOTS done in %s" % dir)
	main.get_tree().quit(0)


func _take(secs: float, zoom_v: float, file: String, held := {}) -> void:
	var p := m.player
	_zoom(zoom_v)
	m.cam.snap(p.pos)
	var t := 0.0
	while t < secs:
		_purge()
		if eye >= 0.0:
			p.inp["aim"] = p.pos + Vector3(EYE_OFF.x, 0.0, EYE_OFF.y)
		elif face:
			p.inp["aim"] = p.pos + FACE_CAM
		for k in held:
			p.inp[k] = held[k]
		for _i in 2:
			m.step(STEP)
		m.cam.follow(p.pos, FRAME, false)
		if eye >= 0.0:  # (still the game camera and lens, just at her height)
			m.cam.global_position = p.pos + Vector3(EYE_OFF.x, eye, EYE_OFF.y)
			m.cam.look_at(p.pos + Vector3(0.0, eye, 0.0), Vector3.UP)
		for h in m.hunters:
			h.render(FRAME, 1.0)
		await main.get_tree().process_frame
		t += FRAME
	for k in held:
		p.inp[k] = Vector2.ZERO if k == "move" else false
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
