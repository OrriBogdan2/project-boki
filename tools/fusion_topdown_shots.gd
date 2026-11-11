extends RefCounted
## --fusion-topdown-shots --shots-dir=<dir> (a renderer): each Fusion at the match camera, the wearer's own copy
## and a remote copy (built the way another game builds it: the form string of the snapshot through KinNet), each
## walking up the screen and toward it, at two moments of the wing beat. One strip per form
## (topdown_<form>.png) and topdown_all.png stacks them; the draw numbers print as FUSIONTOPDOWN lines.
## --fusion-topdown-check (headless): every hero wears the Stormwing, and a depth raster down the match camera
## (CamRig's default pitch, no renderer needed) measures how much of the wings the hero's own body and hat hide,
## facing up, across and down the screen at both ends of the wing beat, and that the wings start at the head and
## the halo just over it (the form's part_top). Prints FUSIONTOPDOWN ok/FAIL lines.

const DT := 1.0 / 60.0
const FORMS := [["pebbit", "titan"], ["zephyrak", "stormwing"], ["puddlet", "tidal_shell"]]
const CROP := Vector2i(210, 150)          # px round the hunter for a frame
const ZOOM := 1.4
const SPACING := 3.2          # m between the wearer and the remote copy
const CELL := 0.03            # m: one depth-raster cell (about a pixel of a hunter at the match zoom)
const SHOWN_MIN := 0.9        # of the wings' cells in front of the body, every view (wings at the neck: ~0.83)
const AREA_MIN := 0.7         # wing cells per body cell, every view: they carry the silhouette (Tender: 0.92)
const ROOT_MAX := 0.0         # m the wing roots may sit over the head top (hips anchor: +0.25-0.79, float)
const HALO_MAX := 1.0         # m from the head top up to the halo, clear of the hat (hips anchor: 1.39-1.78)

func run(main: Node, mode := "shots") -> void:
	if mode == "check":
		await _check(main)
		return
	var dir := "shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var chk = load("res://tools/merge_form_check.gd").new()
	chk.main = main
	Save.no_write = true
	var strips: Array = []
	for pair in FORMS:
		var strip: Image = await _strip(chk, main, pair[0], pair[1])
		strip.save_png(dir.path_join("topdown_%s.png" % pair[1]))
		strips.append(strip)
	var w0: Image = strips[0]
	var sheet := Image.create(w0.get_width(), w0.get_height() * strips.size(), false, w0.get_format())
	for i in strips.size():
		sheet.blit_rect(strips[i], Rect2i(Vector2i.ZERO, strips[i].get_size()), Vector2i(0, i * strips[0].get_height()))
	sheet.save_png(dir.path_join("topdown_all.png"))
	print("FUSIONTOPDOWN %d strips in %s" % [strips.size(), dir])
	main.get_tree().quit(0)

func _strip(chk, main: Node, species: String, form_id: String) -> Image:
	var P: Hunter = chk.merged(species)
	var m: Match = chk.m
	var R: Hunter = chk.foe(P.pos + Vector3(SPACING, 0, 0))
	R.ctrl = "idle"
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var extra: Array = KinNet.hunter_extra(P)
	var it: Array = []
	it.resize(KinNet.HUNTER_AT)
	it.append_array(extra)
	R.remote = true
	KinNet.apply_hunter(R, it)
	var frames: Array = []
	for face in [0.0, PI]:
		for who in [P, R]:
			who.face = face
		for phase in 2:
			for i in 40 if phase == 0 else 9:
				m.step(DT)
				for x in [P, R]:
					x.face = face
					x.render(DT, 1.0)
				m.cam.snap((P.pos + R.pos) * 0.5)
				await main.get_tree().process_frame
			for who in [P, R]:
				frames.append(_crop(main, who))
	print("FUSIONTOPDOWN %s draws %d objects %d" % [form_id,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	m.queue_free()
	await main.get_tree().process_frame
	var fw := int(CROP.x * ZOOM)
	var out := Image.create(fw * frames.size(), int(CROP.y * ZOOM), false, (frames[0] as Image).get_format())
	for i in frames.size():
		out.blit_rect(frames[i], Rect2i(Vector2i.ZERO, (frames[i] as Image).get_size()), Vector2i(i * fw, 0))
	return out

func _crop(main: Node, h: Hunter) -> Image:
	var img := main.get_viewport().get_texture().get_image()
	var c := main.get_viewport().get_camera_3d().unproject_position(h.position + Vector3(0, 0.9, 0))
	var corner := Vector2i(int(c.x) - CROP.x / 2, int(c.y) - CROP.y / 2)
	var rg := Rect2i(corner, CROP).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(rg)
	crop.resize(int(CROP.x * ZOOM), int(CROP.y * ZOOM), Image.INTERPOLATE_BILINEAR)
	return crop

# ------------------------------------------------------------------ the check
func _check(main: Node) -> void:
	var form := MergeForm.kit_form("stormwing", 10.0)
	var pitch := deg_to_rad(float(CamRig.STYLES["supervive"]["pitch"]))
	var holder := Node3D.new()
	main.add_child(holder)
	var bad := 0
	var worst := 1.0
	var remote := KinNet.decode_form(KinNet.encode_form(form))
	var same: bool = remote["parts"] == form["parts"]
	same = same and is_equal_approx(float(remote["part_k"]), float(form["part_k"]))
	same = same and is_equal_approx(float(remote["size"]), float(form["size"]))
	bad += 0 if same else 1
	print("FUSIONTOPDOWN %s the remote copy rebuilds the same parts, part_k and size" % ("ok  " if same else "FAIL"))
	for a in Arch.ids():
		var mdl := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", {}, a)
		mdl.set_meta("anim_seed", 45)
		HunterAnim.rest_pose(mdl)
		holder.add_child(mdl)
		var sync := mdl.get_node_or_null("Warden/Sync") as WardenGlb.Sync
		if sync:
			sync.orbits.pivots.clear()
		mdl.scale = Vector3.ONE * float(form["size"])
		var dressed := MergeLook.dress(mdl, form, mdl)
		var rec: Dictionary = dressed[1]
		await main.get_tree().process_frame
		var top := _top(mdl, dressed[0])
		var root: float = (rec["wings"][0] as Node3D).global_position.y - top
		var halo: float = (rec["halo"] as Node3D).global_position.y - top
		var low := 1.0
		var area := INF
		for face in [0.0, PI * 0.5, PI]:
			mdl.rotation.y = face
			for beat in [-1.0, 1.0]:
				MergeParts.animate(rec, beat * PI * 0.5 / 15.0, 0.0, false)
				var v := _shown(mdl, rec["wings"], pitch)
				low = minf(low, v.x)
				area = minf(area, v.y)
		worst = minf(worst, low)
		var good := low >= SHOWN_MIN and area >= AREA_MIN
		good = good and root <= ROOT_MAX and halo > 0.0 and halo <= HALO_MAX
		bad += 0 if good else 1
		print("FUSIONTOPDOWN %s %s: at least %d%% of the Stormwing wings in front of the body, %.2f wing/body cells"
			% ["ok  " if good else "FAIL", a, int(low * 100.0), area]
			+ ", root %+.2f m and halo %+.2f m from the head top" % [root, halo])
		mdl.queue_free()
	print("FUSIONTOPDOWN DONE worst %d%%, failures: %d" % [int(worst * 100.0), bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## The highest point of the hunter's own meshes (hat included), m.
func _top(mdl: Node3D, parts: Node3D) -> float:
	var top := 0.0
	for mi: MeshInstance3D in mdl.find_children("*", "MeshInstance3D", true, false):
		var skip := mi.has_meta("halo") or mi.has_meta("glb_hidden")
		if mi.mesh == null or not mi.is_visible_in_tree() or skip or parts.is_ancestor_of(mi):
			continue
		var bb := mi.global_transform * mi.get_aabb()
		top = maxf(top, bb.end.y)
	return top

## A depth raster of every mesh under `mdl`: (the share of the wings' cells that are nearest the camera,
## the wings' cells per cell the rest of the hunter shows).
func _shown(mdl: Node3D, wings: Array, pitch: float) -> Vector2:
	var up := Vector3(0, cos(pitch), -sin(pitch))        # screen up, for a camera looking down from +z
	var near := Vector3(0, sin(pitch), cos(pitch))       # toward the camera
	var depth := {}
	var wing_cells := {}
	for mi in mdl.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if g.mesh == null or not g.is_visible_in_tree() or g.has_meta("halo") or g.has_meta("glb_hidden"):
			continue
		var is_wing := wings.any(func(w): return (w as Node).is_ancestor_of(g))
		var xf := g.global_transform
		var f := g.mesh.get_faces()
		for i in range(0, f.size(), 3):
			var pts: Array = []
			var zs: Array = []
			for j in 3:
				var w: Vector3 = xf * f[i + j]
				pts.append(Vector2(w.x, -w.dot(up)) / CELL)
				zs.append(w.dot(near))
			_raster(pts, zs, depth, wing_cells, is_wing)
	var front := 0
	for c in wing_cells:
		if bool(depth[c][1]):
			front += 1
	var n := float(wing_cells.size())
	return Vector2(float(front) / maxf(1.0, n), n / maxf(1.0, float(depth.size() - front)))

func _raster(pts: Array, zs: Array, depth: Dictionary, wing_cells: Dictionary, is_wing: bool) -> void:
	var lo: Vector2 = (pts[0] as Vector2).min(pts[1]).min(pts[2])
	var hi: Vector2 = (pts[0] as Vector2).max(pts[1]).max(pts[2])
	for y in range(floori(lo.y), ceili(hi.y) + 1):
		for x in range(floori(lo.x), ceili(hi.x) + 1):
			var q := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.point_is_inside_triangle(q, pts[0], pts[1], pts[2]):
				continue
			var bc := _bary(q, pts[0], pts[1], pts[2])
			var z := bc.x * float(zs[0]) + bc.y * float(zs[1]) + bc.z * float(zs[2])
			var c := Vector2i(x, y)
			if is_wing:
				wing_cells[c] = true
			if not depth.has(c) or z > float(depth[c][0]):
				depth[c] = [z, is_wing]

static func _bary(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var d := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
	if absf(d) < 1e-9:
		return Vector3(1, 0, 0)
	var u := ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / d
	var v := ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / d
	return Vector3(u, v, 1.0 - u - v)
