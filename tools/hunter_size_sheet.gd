extends "res://tools/hunter_scale_shots.gd"
## --hunter-size-sheet --shots-dir=<dir> [--hero=arch,arch]: how big each hunter is at the match camera, for a size
## side-by-side. Each hero idles alone on open floor. One HSIZE row per hero and pass (match_k 1 = main's size, own
## = the archetype's body.match_k, zoom = the wheel's factor): the crown's height over the feet in m as drawn, the
## same on screen in px at 1080p, and px per m. The crown is the top of the skull: hair tips, ears, horns and the
## glider do not count
## (the highest slice of the head that is at least CROWN_KEEP as wide as the head). "top" is the highest body point
## of all (hair and ears in). Each pass is also saved whole frame, no HUD (<dir>/<hero>_<pass>.png);
## "panel" stands the hero close in a fixed camera, so every hero shares one px/m. Needs a renderer (jobq --needs gpu).

const PASSES := [  # [label, draw at the archetype's own match_k (else 1), wheel zoom]
	["main", false, 1.4572],  # main today: every hunter at the base size, the wheel starting at its widest
	["parity", true, 1.4572],
	["panel", true, 0.45],
]
const WARM_UP := 200  # match steps (1/60 s) the camera settles for before a pass is read
const SAMPLES := 12  # frames the idle is averaged over
const SAMPLE_GAP := 8  # match steps between two samples (1/60 s each): 1.6 s in all


func run(main_node: Node) -> void:
	main = main_node
	var heroes: Array = Arch.ids()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--hero="):
			heroes = String(a).substr(7).split(",")
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	main.get_window().size = SIZE
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	for hero in heroes:
		await _start(hero, "cindle")
		for h in m.hunters:
			h.out = h != m.player
		for k in m.kins:
			k.model.visible = false
		var at := _arena_spot(m.player.pos)
		_bare_floor(at)
		var own_k := Arch.match_k(hero)
		for pass_row in PASSES:
			_draw_k(hero, own_k if pass_row[1] else 1.0)
			m.cam.user_zoom = pass_row[2]
			m.cam.zoom = pass_row[2]
			m.cam.zoom_to = pass_row[2]
			m.player.render(0.0, 1.0)
			await _settle(at)
			m.player.render(0.0, 1.0)
			_clean()
			await _measure(hero, pass_row[0])
		m.queue_free()
	main.get_tree().quit(0)


## One match step with the hero idling side on, as _settle does.
func _tick() -> void:
	var p := m.player
	_purge()
	p.inp["aim"] = p.pos + Vector3(8.0, 0.9, 0.0)
	m.step(STEP)
	m.cam.follow(p.pos, STEP, false)
	for h in m.hunters:
		h.render(STEP, 1.0)
	_clean()


func _measure(hero: String, label: String) -> void:
	var p := m.player
	for _i in WARM_UP:  # the camera's springs reach their rest
		_tick()
	m.hud.visible = false  # every pass is shot with no HUD (<dir>/<hero>_<main|parity|panel>.png, the whole frame)
	await _save("%s_%s.png" % [hero, label])
	m.hud.visible = true
	var top := 0.0
	var crown := 0.0
	var px := 0.0
	var k := float(SIZE.y) / main.get_viewport().get_visible_rect().size.y  # viewport px to 1080p px
	for i in SAMPLES:  # the idle breathes: the mean over a few frames
		for _s in SAMPLE_GAP:
			_tick()
		var pts := _body_points(p.model)
		var hi := -1e9
		for wp in pts:
			hi = maxf(hi, wp.y)
		var c := HunterCrown.crown(p.model, pts, p.vis_k, hi)
		var feet := m.cam.unproject_position(p.position)
		var head := m.cam.unproject_position(p.position + m.cam.char_lean() * Vector3(0, c - p.position.y, 0))
		top += (hi - p.position.y) / SAMPLES
		crown += (c - p.position.y) / SAMPLES
		px += (feet.y - head.y) * k / SAMPLES
	var at := m.cam.unproject_position(p.position) * k
	print(
		(
			"HSIZE %s %s: crown %.3f m, top %.3f m, crown %.1f px, %.1f px/m, feet at %.0f,%.0f"
			% [hero, label, crown, top, px, px / crown, at.x, at.y]
		)
	)
