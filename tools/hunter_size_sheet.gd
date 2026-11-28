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
## out, "crown" (weapon out and nothing above the head's crown: no back poles) and "bare" (weapon out, the skinned
## hammer, shield and lure shrunk away, the back poles and all above the crown cut off: the body alone). One HSIL row
## per hero and case: area in m2 and screen height in m (the view plane at the hero, so both read against the
## reference's idle silhouettes at its 66 deg camera), the mean over the facings and the facing-camera one.
## The facing-camera mask is saved as <dir>/<hero>_sil_<lean|flat>_<case>.png. Floating companions are not the hero.
## --lineup=arch,arch,...: those heroes side by side on open floor, each LINEUP_W x its drawn height wide, at its own
## match_k, idling at the match camera's widest zoom: one frame, <dir>/lineup.png (no HUD), and a LINEUP row per
## hero (feet x,y px). --lineup-zoom=<wheel factor> (default the widest) closes the camera in for more px per m, and
## --cutouts also saves each hero alone with its real materials, <dir>/<hero>_cut_look.png, and its flat mask
## <dir>/<hero>_cut_mask.png (the whole frame each; a LINEUP row gives its px per m of the view plane at the hero).

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
# glb bones that are props, not the body (bone name prefixes)
const SKIN_PROPS := ["x_weapon", "x_shield", "x_fish"]
# "bare" (Albert's glb: crown 1.2 m, back poles rooted 0.3 m behind the body's axis from 0.85 m up), in metres
const BARE_CROWN := 1.2
const BARE_DOME := 0.1  # the helmet dome stands this far above the crown
const BARE_BACK := 0.3
const BARE_ROOT := 0.85
const LINEUP_W := 0.75  # a hero's slot in the --lineup row, x its drawn height (top_h x match_k): props out to the side
const SIL_PAD := 0.6  # share of the body's screen box added all round the box the mask reads (weapons reach out)

var cutouts := false  # --cutouts: the lineup also saves each hero alone (real materials) and its flat mask
var lineup_zoom: float = PASSES[0][2]  # --lineup-zoom: the lineup camera's wheel factor


func run(main_node: Node) -> void:
	main = main_node
	var heroes: Array = Arch.ids()
	var sil := false
	var row: Array = []
	for a in OS.get_cmdline_user_args():
		if String(a) == "--silhouette":
			sil = true
		if String(a) == "--cutouts":
			cutouts = true
		if String(a).begins_with("--lineup-zoom="):
			lineup_zoom = float(String(a).substr(14))
		if String(a).begins_with("--lineup="):
			row = String(a).substr(9).split(",")
		if String(a).begins_with("--hero="):
			heroes = String(a).substr(7).split(",")
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	main.get_window().size = SIZE
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	if not row.is_empty():
		await _lineup(row)
		main.get_tree().quit(0)
		return
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
	# area, height; facing 0's area, height. "crown": weapon out, nothing above the head's crown (back poles);
	# "bare": weapon out, the skinned props (hammer, shield, lure) shrunk away, the back poles (body mesh) cut off
	var sums := {}
	for case in ["all", "body", "crown", "bare"]:
		sums[case] = [0.0, 0.0, 0.0, 0.0]
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
		for case in ["all", "body", "crown", "bare"]:
			var how: Material = flat
			if case == "bare":
				_shrink_props(p.model, true)
				var sc := (c - p.position.y) / BARE_CROWN
				how = _clip_flat(c + BARE_DOME * sc, p.position, -face, sc)
			var got: Array = await _mask(p.model, how, case != "all", cap if case == "crown" else -1e9)
			if case == "bare":
				_shrink_props(p.model, false)
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


## The flat mask colour without the back poles (they are part of the body mesh, not a node or bone): nothing above world
## height `clip_y`, nor further back than BARE_BACK crowns' worth of metres (scale `sc`) behind `feet` along `back` once
## above BARE_ROOT of it.
func _clip_flat(clip_y: float, feet: Vector3, back: Vector3, sc: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, fog_disabled;
uniform float clip_y;
uniform vec3 feet;
uniform vec3 back;
uniform float sc;
uniform vec2 lim;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 d = wp - feet;
	if (wp.y > clip_y || (d.y > lim.y * sc && dot(d, back) > lim.x * sc)) {
		discard;
	}
	ALBEDO = vec3(1.0, 0.0, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("clip_y", clip_y)
	mat.set_shader_parameter("feet", feet)
	mat.set_shader_parameter("back", back)
	mat.set_shader_parameter("sc", sc)
	mat.set_shader_parameter("lim", Vector2(BARE_BACK, BARE_ROOT))
	return mat


## The skinned props of a glb hero (SKIN_PROPS bones: hammer, shield) cannot be hidden by node: the
## bones are shrunk to a point (a persistent global pose override) or given back (`on` false).
func _shrink_props(model: Node3D, on: bool) -> void:
	for sk in model.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		for bi in skel.get_bone_count():
			var nm := skel.get_bone_name(bi)
			var prop := false
			for key in SKIN_PROPS:
				prop = prop or nm.begins_with(key)
			if not prop:
				continue
			if on:
				var t := skel.get_bone_global_pose(bi)
				t.basis = t.basis.scaled(Vector3.ONE * 0.0001)
				skel.set_bone_global_pose_override(bi, t, 1.0, true)
			else:
				skel.set_bone_global_pose_override(bi, Transform3D.IDENTITY, 0.0, false)


## [hero px, mask rows tall (both in viewport px, as unproject_position), mask image] for `model` drawn flat alone
## (`no_weapon`: the held weapon hidden; nothing above viewport row `cap_y` counts). Only the screen box round the
## body's points (plus SIL_PAD) is read. `look`: the frame drawn with the model's own materials is the 4th element.
func _mask(model: Node3D, flat: Material, no_weapon: bool, cap_y := -1e9, look := false) -> Array:
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
	var worn: Image = null
	if look:
		for row in keep:
			(row[0] as GeometryInstance3D).material_override = row[2]
		worn = await _grab()
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
	return [px / (sc * sc), maxi(low - top + 1, 0) / sc, mask, worn]


## The --lineup frame (see the header): every hero is a bot that only stands (no brain); the player stands hidden.
func _lineup(row: Array) -> void:
	await _start(String(row[0]), "cindle")
	for h in m.hunters:
		h.out = h != m.player
	var mids: Array = []  # each hero's centre along the row, from the row's left end
	var span := 0.0
	for i in row.size():
		var w := LINEUP_W * Hunter.VIS_SCALE * Arch.match_k(row[i]) * float(Arch.body(row[i]).get("top_h", 1.9))
		mids.append(span + w * 0.5)
		span += w
	var at := _row_spot(m.player.pos, span)
	_bare_floor(at)
	var spots: Array = []
	for i in row.size():
		var x: float = at.x + float(mids[i]) - span * 0.5
		spots.append(Vector3(x, m.world.ground_at(x, at.z), at.z))
	var line: Array = []
	for i in row.size():
		var h := _hunter("line%d" % i, m.player.team, String(row[i]), "cindle", spots[i])
		h.ctrl = "local"
		line.append(h)
	m.player.teleport(at)  # the player stands hidden mid-row: its drop reticle and glider stay out of the frame
	m.cam.user_zoom = lineup_zoom
	m.cam.zoom = lineup_zoom
	m.cam.zoom_to = lineup_zoom
	m.cam.snap(at)
	for i in WARM_UP:
		_purge()
		for j in line.size():
			var h: Hunter = line[j]
			if i % 20 == 0:
				h.teleport(spots[j])
				h.vel = Vector3.ZERO
			h.inp["aim"] = h.pos + Vector3(0.0, 0.9, 8.0)  # facing the camera
		m.step(STEP)
		m.cam.follow(at, STEP, false)
		for h in m.hunters:
			h.render(STEP, 1.0)
		m.player.visible = false
		for k in m.kins:
			k.model.visible = false
		_clean()
	m.hud.visible = false
	await _save("lineup.png")
	var k := float(SIZE.y) / main.get_viewport().get_visible_rect().size.y
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.albedo_color = Color(1, 0, 1)
	flat.disable_fog = true
	for h in line:
		var feet := m.cam.unproject_position(h.position) * k
		var mid: Vector3 = h.position + Vector3(0, 1.0, 0)
		var right := m.cam.global_transform.basis.x
		var ppm := (m.cam.unproject_position(mid + right) - m.cam.unproject_position(mid)).length() * k
		print(
			(
				"LINEUP %s: k %.3f, feet at %.0f,%.0f px, %.1f m off its spot, %.1f px/m"
				% [h.arch, Arch.match_k(h.arch), feet.x, feet.y, h.pos.distance_to(spots[line.find(h)]), ppm]
			)
		)
		if cutouts:
			var got: Array = await _mask(h.model, flat, false, -1e9, true)
			(got[2] as Image).save_png(dir.path_join("%s_cut_mask.png" % h.arch))
			(got[3] as Image).save_png(dir.path_join("%s_cut_look.png" % h.arch))


## The spot nearest `p` with open floor `span` m long in x and no void next to it (roomy first, then just clear),
## so no hunter in the row stands off the island.
func _row_spot(p: Vector3, span: float) -> Vector3:
	var w: World = m.world
	var half := int(ceil(span / 2.0))
	for room in [[3, 2], [1, 1], [0, 0]]:
		var best := Vector3.INF
		var best_d := 1e9
		for z in range(int(p.z) - 40, int(p.z) + 41):
			for x in range(int(p.x) - 40, int(p.x) + 41):
				var d := Vector2(x + 0.5 - p.x, z + 0.5 - p.z).length()
				if d >= best_d or not _row_open(w, x, z, half, room[0], room[1]):
					continue
				best_d = d
				best = Vector3(x + 0.5, 0.0, z + 0.5)
		if best_d < 1e9:
			print(
				(
					"ROW %d m of floor (%d m deep, %d m from the void), %.1f m from the spawn"
					% [half * 2 + 1, room[0] * 2 + 1, room[1], best_d]
				)
			)
			return _ground(best)
	print("ROW none found: the arena spot")
	return _arena_spot(p)


func _row_open(w: World, x: int, z: int, half: int, deep: int, edge: int) -> bool:
	for dz in range(-deep, deep + 1):
		for dx in range(-half, half + 1):
			if w.tile_kind(x + dx + 0.5, z + dz + 0.5) != World.T_GROUND:
				return false
			if edge > 0 and w.edge_dist(x + dx, z + dz, edge) <= edge:
				return false
	return true
