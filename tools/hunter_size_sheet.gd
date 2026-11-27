extends "res://tools/hunter_scale_shots.gd"
## --hunter-size-sheet --shots-dir=<dir> [--hero=arch,arch]: how big each hunter is at the match camera, for a size
## side-by-side. Each hero idles alone on open floor. One HSIZE row per hero and pass (scale = camera.json
## match_hunter_scale, zoom = the wheel's factor): the crown's height over the feet in m as drawn, the same on screen
## in px at 1080p, and px per m. The crown is the top of the skull: hair tips, ears, horns and the glider do not count
## (the highest slice of the head that is at least CROWN_KEEP as wide as the head). "top" is the highest body point
## of all (hair and ears in). The "panel" pass stands the hero close in a fixed camera, shot with no HUD
## (<dir>/<hero>_panel.png), so every hero shares one px/m. Needs a renderer (jobq --needs gpu).

const PASSES := [  # [label, match_hunter_scale, wheel zoom]
	["old_cam_1.00", 1.0, 1.6],  # before the camera parity pass: the wheel started at 1.6
	["old_cam_1.10", 1.1, 1.6],
	["cam_1.10", 1.1, 1.4572],  # the camera parity pass: the wheel starts at 1.4572
	["cam_1.00", 1.0, 1.4572],  # main now, without the hunter scale rule
	["panel", 1.1, 0.3],
]
const WARM_UP := 200  # match steps (1/60 s) the camera settles for before a pass is read
const SAMPLES := 12  # frames the idle is averaged over
const SAMPLE_GAP := 8  # match steps between two samples (1/60 s each): 1.6 s in all
const CROWN_KEEP := 0.5  # a head slice this share of the head's widest slice or more is still skull
const SLICE := 0.02  # m: crown slices' thickness
const HEAD_R := 0.3  # m (at the drawn size) round the head's axis that the crown is looked for in
const HEAD_ROOM := 0.35  # m (at the drawn size) over the head bone that the crown is looked for in


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
	var base := CamRig.match_hunter_scale
	for hero in heroes:
		await _start(hero, "cindle")
		for h in m.hunters:
			h.out = h != m.player
		for k in m.kins:
			k.model.visible = false
		var at := _arena_spot(m.player.pos)
		_bare_floor(at)
		for pass_row in PASSES:
			var ratio: float = 1.12 * float(pass_row[1]) / Hunter.VIS_SCALE
			CamRig.match_hunter_scale = pass_row[1]
			Hunter.VIS_SCALE = 1.12 * CamRig.match_hunter_scale
			m.cam.user_zoom = pass_row[2]
			m.cam.zoom = pass_row[2]
			m.cam.zoom_to = pass_row[2]
			m.player.render(0.0, 1.0)
			if m.player.model.has_meta("base_scale"):  # Kael's grow keeps the size it started at
				m.player.model.set_meta("base_scale", (m.player.model.get_meta("base_scale") as Vector3) * ratio)
			await _settle(at)
			m.player.render(0.0, 1.0)
			_clean()
			await _measure(hero, pass_row[0])
		m.queue_free()
	CamRig.match_hunter_scale = base
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
	if label == "panel":
		m.hud.visible = false
		await _save("%s_panel.png" % hero)
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
		var c := _crown(p, pts, hi)
		var feet := m.cam.unproject_position(p.position)
		var head := m.cam.unproject_position(p.position + m.cam.char_lean() * Vector3(0, c - p.position.y, 0))
		top += (hi - p.position.y) / SAMPLES
		crown += (c - p.position.y) / SAMPLES
		px += (feet.y - head.y) * k / SAMPLES
	print("HSIZE %s %s: crown %.3f m, top %.3f m, crown %.1f px, %.1f px/m" % [hero, label, crown, top, px, px / crown])


## The world y of the top of the skull: the highest 2 cm slice, in a column round the head bone, that is at least
## CROWN_KEEP as wide as the head (the middle 90% of its points, so a lone spike or ear tip does not widen it).
func _crown(p: Hunter, pts: PackedVector3Array, top: float) -> float:
	var sk := _skeleton(p.model)
	var head_i := -1
	for b in sk.get_bone_count() if sk else 0:
		if sk.get_bone_name(b).to_lower() == "head":
			head_i = b
	if head_i < 0:
		print("CROWN no head bone: top used")
		return top
	var hp := (sk.global_transform * sk.get_bone_global_pose(head_i)).origin
	var s := p.vis_k
	var slices := {}
	for wp in pts:
		var dy := wp.y - hp.y
		if dy < 0.0 or dy > HEAD_ROOM * s or Vector2(wp.x - hp.x, wp.z - hp.z).length() > HEAD_R * s:
			continue
		var key := int(dy / (SLICE * s))
		if not slices.has(key):
			slices[key] = []
		(slices[key] as Array).append(wp)
	var widths := {}
	var widest := 0.0
	for key in slices:
		var w := _width(slices[key])
		widths[key] = w
		widest = maxf(widest, w)
	var best := -1
	for key in widths:
		if widths[key] >= CROWN_KEEP * widest and key > best:
			best = key
	return hp.y + (best + 1) * SLICE * s


## How wide a slice's points are across: the bigger of its x and z spread, the middle 90% of the points.
func _width(pts: Array) -> float:
	if pts.size() < 6:
		return 0.0
	var xs := []
	var zs := []
	for wp in pts:
		xs.append(wp.x)
		zs.append(wp.z)
	xs.sort()
	zs.sort()
	var lo := int(pts.size() * 0.05)
	var hi := pts.size() - 1 - lo
	return maxf(xs[hi] - xs[lo], zs[hi] - zs[lo])


func _skeleton(model: Node3D) -> Skeleton3D:
	var stack: Array = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Skeleton3D:
			return n
		stack.append_array(n.get_children())
	return null
