extends "res://tools/hunter_scale_shots.gd"
## --hunter-size-sheet --shots-dir=<dir> [--hero=arch,arch]: how big each hunter is at the match camera, for a size
## side-by-side. Each hero idles alone on open floor. One HSIZE row per hero and pass (match_k 1 = main's size, own
## = the archetype's body.match_k, zoom = the wheel's factor): the crown's height over the feet in m as drawn, the
## same on screen in px at 1080p, and px per m. The crown is the top of the skull: hair tips, ears, horns and the
## glider do not count
## (the highest slice of the head that is at least CROWN_KEEP as wide as the head). "top" is the highest body point
## of all (hair and ears in). Each pass is also saved whole frame, no HUD (<dir>/<hero>_<pass>.png);
## "panel" stands the hero close in a fixed camera, so every hero shares one px/m. Needs a renderer (jobq --needs gpu).
## --silhouette adds, at the base size (match_k 1), the hero's silhouette as the player sees it: drawn alone in one flat
## colour on its own render layer, at SIL_YAWS facings, with the character lean on and off, the held weapon in and
## out, and "crown" (weapon out and nothing above the head's crown: no back poles). One HSIL row per hero and case:
## area in m2 and screen height in m (the view plane at the hero, so both read against the reference's idle
## silhouettes at its 66 deg camera), the mean over the facings and the facing-camera one.
## The facing-camera mask is saved as <dir>/<hero>_sil_<lean|flat>_<case>.png. Floating companions are not the hero.

const PASSES := [  # [label, draw at the archetype's own match_k (else 1), wheel zoom]
	["main", false, 1.4572],  # main today: every hunter at the base size, the wheel starting at its widest
	["parity", true, 1.4572],
	["panel", true, 0.45],
]
const WARM_UP := 200  # match steps (1/60 s) the camera settles for before a pass is read
const SAMPLES := 12  # frames the idle is averaged over
const SAMPLE_GAP := 8  # match steps between two samples (1/60 s each): 1.6 s in all
const SIL_LAYER := 1 << 19  # render layer 20: the hero alone, for its silhouette
const SIL_YAWS := 8  # facings the silhouette is averaged over (the first faces the camera)
const SIL_TURN := 30  # match steps the hero gets to turn to a facing
const SIL_ZOOM := 0.45  # the panel's close view: more px for the mask, same metres
const SIL_DIFF := 0.2  # summed RGB step from the empty frame that counts as the hero
const SIL_WEAPONS := ["Gun", "Shield"]  # the held weapon (out for the "body" cases)
const SIL_PAD := 0.6  # share of the body's screen box added all round the box the mask reads (weapons reach out)


func run(main_node: Node) -> void:
	main = main_node
	var heroes: Array = Arch.ids()
	var sil := false
	for a in OS.get_cmdline_user_args():
		if String(a) == "--silhouette":
			sil = true
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
		if sil:
			_draw_k(hero, 1.0)
			m.cam.user_zoom = SIL_ZOOM
			m.cam.zoom = SIL_ZOOM
			m.cam.zoom_to = SIL_ZOOM
			await _settle(at)
			for lean in [1.0, 0.0]:
				m.cam.lean_scale = lean
				await _silhouette(hero, "lean" if lean > 0.0 else "flat")
			m.cam.lean_scale = 1.0
		m.queue_free()
	main.get_tree().quit(0)


## One match step with the hero idling and facing along `face` (flat; side on by default, as _settle does).
func _tick(face := Vector3.RIGHT) -> void:
	var p := m.player
	_purge()
	p.inp["aim"] = p.pos + face * 8.0 + Vector3(0.0, 0.9, 0.0)
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


## The hero's silhouette at SIL_YAWS facings (the camera's own yaw first, so facing 0 looks at the camera): HSIL rows,
## see the header. The mask is the hero's meshes drawn flat on SIL_LAYER against the same frame with nothing drawn.
func _silhouette(hero: String, lean: String) -> void:
	var p := m.player
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.albedo_color = Color(1, 0, 1)
	flat.disable_fog = true
	var to_cam := m.cam.global_position - p.position
	to_cam.y = 0.0
	to_cam = to_cam.normalized()
	# area, height; facing 0's area, height. "crown": weapon out, nothing above the head's crown (back poles)
	var sums := {"all": [0.0, 0.0, 0.0, 0.0], "body": [0.0, 0.0, 0.0, 0.0], "crown": [0.0, 0.0, 0.0, 0.0]}
	for i in SIL_YAWS:
		var face := to_cam.rotated(Vector3.UP, TAU * i / SIL_YAWS)
		for _s in SIL_TURN:
			_tick(face)
		await main.get_tree().process_frame
		var mid := p.position + Vector3(0, 1.0, 0)
		var right := m.cam.global_transform.basis.x
		var ppm := (m.cam.unproject_position(mid + right) - m.cam.unproject_position(mid)).length()
		var pts := _body_points(p.model)
		var hi := -1e9
		for wp in pts:
			hi = maxf(hi, wp.y)
		var c := HunterCrown.crown(p.model, pts, p.vis_k, hi)
		var cap := m.cam.unproject_position(p.position + m.cam.char_lean() * Vector3(0, c - p.position.y, 0)).y
		for case in ["all", "body", "crown"]:
			var got: Array = await _mask(p.model, flat, case != "all", cap if case == "crown" else -1e9)
			var area: float = got[0] / (ppm * ppm)
			var tall: float = got[1] / ppm
			sums[case][0] += area / SIL_YAWS
			sums[case][1] += tall / SIL_YAWS
			if i == 0:
				sums[case][2] = area
				sums[case][3] = tall
				(got[2] as Image).save_png(dir.path_join("%s_sil_%s_%s.png" % [hero, lean, case]))
	for case in sums:
		var r: Array = sums[case]
		print(
			(
				"HSIL %s %s %s: area %.3f m2, screen h %.3f m (mean of %d facings); facing camera %.3f m2, %.3f m"
				% [hero, lean, case, r[0], r[1], SIL_YAWS, r[2], r[3]]
			)
		)


## [hero px, mask rows tall (both in viewport px, as unproject_position), mask image] for `model` drawn flat alone
## (`no_weapon`: the held weapon hidden; nothing above viewport row `cap_y` counts). Only the screen box round the
## body's points (plus SIL_PAD) is read.
func _mask(model: Node3D, flat: Material, no_weapon: bool, cap_y := -1e9) -> Array:
	var keep := []
	var stack: Array = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name in SKIP and not (n.name in SIL_WEAPONS and not no_weapon):
			continue
		if String(n.name).begins_with(WardenCompanions.PREFIX):  # floating companions (Meeko's sun, cloud): not her
			continue
		stack.append_array(n.get_children())
		var gi := n as GeometryInstance3D
		if gi == null or not gi.is_visible_in_tree():
			continue
		keep.append([gi, gi.layers, gi.material_override, gi.cast_shadow])
		gi.layers = SIL_LAYER
		gi.material_override = flat
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var was := m.cam.cull_mask
	m.hud.visible = false
	m.cam.cull_mask = SIL_LAYER
	var lit := await _grab()
	m.cam.cull_mask = 0
	var empty := await _grab()
	m.cam.cull_mask = was
	m.hud.visible = true
	for row in keep:
		var gi: GeometryInstance3D = row[0]
		gi.layers = row[1]
		gi.material_override = row[2]
		gi.cast_shadow = row[3]
	var box := Rect2(m.cam.unproject_position(model.global_position), Vector2.ZERO)
	for wp in _body_points(model):
		box = box.expand(m.cam.unproject_position(wp))
	box = box.grow(maxf(box.size.x, box.size.y) * SIL_PAD)
	var sc := float(lit.get_width()) / main.get_viewport().get_visible_rect().size.x  # image px per viewport px
	box = Rect2(box.position * sc, box.size * sc)
	var x0 := clampi(int(box.position.x), 0, lit.get_width() - 1)
	var y0 := clampi(int(maxf(box.position.y, cap_y * sc)), 0, lit.get_height() - 1)
	var x1 := clampi(int(box.end.x), x0 + 1, lit.get_width())
	var y1 := clampi(int(box.end.y), y0 + 1, lit.get_height())
	var mask := Image.create(lit.get_width(), lit.get_height(), false, Image.FORMAT_L8)
	var px := 0
	var top := lit.get_height()
	var low := -1
	for y in range(y0, y1):
		for x in range(x0, x1):
			var a := lit.get_pixel(x, y)
			var b := empty.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > SIL_DIFF:
				px += 1
				top = mini(top, y)
				low = maxi(low, y)
				mask.set_pixel(x, y, Color.WHITE)
	return [px / (sc * sc), maxi(low - top + 1, 0) / sc, mask]
