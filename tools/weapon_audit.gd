extends "res://tools/rig_shots.gd"
## --weapon-audit --shots-dir=<dir> [--wardens=a,b] [--refs=<dir/>]: item 137. Each Hero in its idle clip: the weapon's
## length from its skinned vertices (longest span, m) over the head top, printed and saved as line_<id>.json, plus
## ingame_, weapon_ and match_<id>.png. --compose [--verdicts=<json>] lays what is in the folder beside the refs as
## weapon_audit_sheet.png (run per branch, compose once). Needs a renderer.

## arch -> [[item, bones, surface names left out]]
const ITEMS := {
	"ashwick": [["spear", ["hand.R"], ["skin"]]],
	"rimewright": [["spear", ["hand.R"], ["skin", "fur", "cloth"]]],
	"juggernaut": [["sword", ["hand.R"], ["skin"]]],
	"thief": [["pistol", ["hand.R"], ["skin", "cloth"]]],
	"gunslinger": [["cannon", ["forearm.R", "upper_arm.R", "gatling", "launcher"], ["skin"]]],
	"dredge": [["hook", ["hook"], []], ["gun", ["gun"], []]],
	"archer": [["bow", ["bow", "bow_t", "bow_b"], []]],
	"bulwark": [["hammer", ["x_weapon"], []]],
	"tender": [["lantern", ["spring_hanglantern_0"], []]],
	"dolm": [["gauntlet", ["forearm.R", "hand.R"], ["cloth"]]],
	"mage": [],
	"ostra": [["orb", ["x_weapon"], []]],
}
const LABEL := {"ashwick": "Cinder", "rimewright": "Neve",
	"juggernaut": "Kael", "thief": "Sable", "gunslinger": "Vex",
	"dredge": "Grimble", "archer": "Lace", "bulwark": "Mossy", "tender": "Meeko", "dolm": "Tenzo", "mage": "Sparkle",
	"ostra": "Motley"}
## arch -> [body ref file, rect (orig px)], [weapon ref file, rect]
const REFS := {
	"ashwick": [["cinder_weapons.png", [1630, 1460, 390, 560]],
		["cinder_weapons.png", [360, 70, 1100, 470]]],
	"rimewright": [["claire_weapons.png", [1740, 1490, 280, 550]], ["claire_weapons.png", [60, 40, 210, 1960]]],
	"juggernaut": [["kael_weapons.png", [1450, 1200, 560, 800]], ["kael_weapons.png", [130, 70, 260, 1220]]],
	"thief": [["sable_weapons.png", [1600, 1400, 330, 610]], ["sable_weapons.png", [1190, 480, 810, 400]]],
	"gunslinger": [["vex_FINAL_sheet.png", [20, 90, 760, 1830]], ["vex_weapons.png", [20, 80, 710, 1220]]],
	"dredge": [["grimble_FINAL_sheet.png", [120, 20, 980, 790]], ["grimble_weapons.png", [60, 30, 310, 590]]],
	"archer": [["hem_FINAL_sheet.png", [0, 250, 920, 1720]], ["hem_v4_needlebow.png", []]],
	"bulwark": [["breaker_FINAL_sheet.png", [60, 150, 1020, 840]], ["breaker_weapons.png", [70, 80, 580, 960]]],
	"tender": [["pip_FINAL_sheet.png", [90, 130, 1060, 1340]], ["pip_props.png", []]],
	"dolm": [["tarek_FINAL_sheet.png", [20, 80, 990, 1820]], ["tarek_FINAL_sheet.png", [740, 680, 220, 500]]],
	"mage": [["ryzz_FINAL_sheet.png", [20, 60, 800, 1820]], []],
	"ostra": [["ostra_FINAL_sheet.png", [70, 40, 610, 1380]], []],
}
const ORDER := ["ashwick", "rimewright", "juggernaut", "thief", "gunslinger", "dredge", "archer", "bulwark", "tender",
	"dolm", "mage", "ostra"]
const CW := 1000
const CH := 600

var verdict := {}
var R := "/home/boki/briefs-wt/briefs/art-refs/"    # --refs=<dir/> (the art refs on ext/agent-briefs)

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var wardens: Array = ORDER
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): wardens = Array(a.substr(10).split(","))
		if a.begins_with("--refs="): R = a.substr(7)
		if a.begins_with("--verdicts="):
			verdict = JSON.parse_string(FileAccess.get_file_as_string(a.substr(11)))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_stage(main)
	for id in wardens:
		WardenGlb.set_model(String(id), true)
	var cells := {}
	if "--compose" in OS.get_cmdline_user_args():
		for id in wardens:
			cells[id] = {"body": Image.load_from_file(out.path_join("ingame_%s.png" % id)),
				"weapon": Image.load_from_file(out.path_join("weapon_%s.png" % id)),
				"match": Image.load_from_file(out.path_join("match_%s.png" % id))}
		await _compose(cells, wardens, out)
	else:
		for id in wardens:
			await _audit(String(id), out)
	print("WEAPON_AUDIT_DONE")
	tree.quit()

func _spans(h: Node3D, skel: Skeleton3D, bones: Array, drop: Array) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for n in h.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.skin == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var skin := mi.skin
		var want := {}
		for b in skin.get_bind_count():
			var bi := skin.get_bind_bone(b)
			var nm := String(skin.get_bind_name(b))
			if bi < 0 and nm != "":
				bi = skel.find_bone(nm)
			if bi >= 0 and skel.get_bone_name(bi) in bones:
				want[b] = skel.global_transform * skel.get_bone_global_pose(bi) * skin.get_bind_pose(b)
		if want.is_empty():
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			var mn := mat.resource_name if mat else ""
			var skip := false
			for d in drop:
				skip = skip or String(d) in mn
			if skip:
				continue
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bn = arr[Mesh.ARRAY_BONES]
			var wt: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if bn == null or bn.is_empty():
				continue
			var k: int = bn.size() / vs.size()
			for v in vs.size():
				var best := 0
				for j in k:
					if wt[v * k + j] > wt[v * k + best]:
						best = j
				var b: int = bn[v * k + best]
				if want.has(b):
					pts.append(want[b] * vs[v])
	return pts

## Longest span of a point set (two sweeps from the far end).
func _diameter(pts: PackedVector3Array) -> Array:
	if pts.is_empty():
		return [0.0, Vector3.ZERO, Vector3.ZERO]
	var a := pts[0]
	var b := a
	for i in 3:
		var far := 0.0
		for p in pts:
			var d := a.distance_squared_to(p)
			if d > far:
				far = d
				b = p
		var t := a
		a = b
		b = t
	return [a.distance_to(b), a, b]

func _audit(id: String, out: String) -> Dictionary:
	var row := _row(id, 1)
	var h := row[0] as Node3D
	h.position = Vector3.ZERO
	h.rotation.y = PI * 0.78
	_state(anims[0][0], h, {})
	await tree.process_frame
	_state(anims[0][0], h, {})
	await tree.process_frame
	var skels := h.find_children("*", "Skeleton3D", true, false)
	var skel: Skeleton3D = null
	for sk in skels:
		if skel == null or (sk as Skeleton3D).get_bone_count() > skel.get_bone_count():
			skel = sk
	var line := {"id": id, "root_scale": snappedf(h.scale.y, 0.001)}
	var head := -1.0
	var top_an = WardenGlb.anchor(h, "anchor_head_top")
	if top_an:
		head = (top_an as Node3D).global_position.y
	line["head_y"] = snappedf(head, 0.001)
	line["top_y"] = snappedf(_top([h]), 0.001)
	var focus := Vector3(0, 1, 0)
	var flen := 1.0
	if skel:
		line["bones"] = skel.get_bone_count()
		var crown := -1.0
		for p in _spans(h, skel, ["head"], ["flame", "horn", "feather", "card", "glow", "wing"]):
			crown = maxf(crown, p.y)
		line["crown_y"] = snappedf(crown, 0.001)
		head = crown
		var hb := skel.find_bone("hand.R")
		if hb >= 0:
			line["hand_scale"] = snappedf(skel.get_bone_global_pose(hb).basis.get_scale().y, 0.001)
		for it in ITEMS.get(id, []):
			var pts := _spans(h, skel, it[1], it[2])
			var dia := _diameter(pts)
			var ratio := snappedf(dia[0] / maxf(head, 0.1), 0.001)
			line[it[0]] = {"len": snappedf(dia[0], 0.001), "n": pts.size(), "ratio": ratio,
				"a": [snappedf(dia[1].x, 0.01), snappedf(dia[1].y, 0.01), snappedf(dia[1].z, 0.01)],
				"b": [snappedf(dia[2].x, 0.01), snappedf(dia[2].y, 0.01), snappedf(dia[2].z, 0.01)]}
			if it == ITEMS[id][0]:
				focus = (dia[1] + dia[2]) * 0.5
				flen = maxf(dia[0], 0.3)
	print("AUDIT ", JSON.stringify(line))
	var lf := FileAccess.open(out.path_join("line_%s.json" % id), FileAccess.WRITE)
	lf.store_string(JSON.stringify(line))
	lf.close()
	# full body, close
	var tall := maxf(line["top_y"], 2.0)
	var wide := 0.0
	for vi in h.find_children("*", "MeshInstance3D", true, false):
		var v := vi as MeshInstance3D
		if v.is_visible_in_tree():
			var ab := v.global_transform * v.get_aabb()
			wide = maxf(wide, maxf(absf(ab.position.x), absf(ab.end.x)))
	cam.fov = 30.0
	cam.position = Vector3(0, tall * 0.5, maxf(tall * 0.56, wide * 1.45) / tan(deg_to_rad(15.0)))
	cam.rotation = Vector3(-0.0, 0, 0)
	var img := await _grab()
	var w := img.get_height() * 3 / 4
	var body := img.get_region(Rect2i((img.get_width() - w) / 2, 0, w, img.get_height()))
	body.save_png(out.path_join("ingame_%s.png" % id))
	# the weapon, close
	var side := Vector3(focus.x, 0, focus.z).normalized() * 0.8 + Vector3(0, 0.25, 0.6)
	cam.position = focus + side.normalized() * (flen * 0.62) / tan(deg_to_rad(15.0))
	cam.look_at(focus)
	var wimg := await _grab()
	var w2 := wimg.get_height()
	var wc := wimg.get_region(Rect2i((wimg.get_width() - w2) / 2, 0, w2, w2))
	wc.save_png(out.path_join("weapon_%s.png" % id))
	# the match camera, true pixels
	var p := deg_to_rad(CAM_PITCH)
	var mid := Vector3(0, 1.0, 0)
	cam.fov = CAM_FOV
	cam.position = mid + Vector3(0, sin(p), cos(p)) * CAM_DIST
	cam.rotation = Vector3(-p, 0, 0)
	var m := await _grab()
	var c := cam.unproject_position(mid)
	var mc := m.get_region(Rect2i(int(c.x) - 70, int(c.y) - 70, 140, 140))
	mc.save_png(out.path_join("match_%s.png" % id))
	_clear()
	await tree.process_frame
	return {"body": body, "weapon": wc, "match": mc, "line": line}

func _load_ref(spec: Array) -> Image:
	if spec.is_empty():
		return null
	var path: String = R + String(spec[0])
	if not FileAccess.file_exists(path):
		return null
	var im := Image.load_from_file(path)
	if spec[1].size() == 4:
		var r: Array = spec[1]
		im = im.get_region(Rect2i(r[0], r[1], r[2], r[3]))
	im.convert(Image.FORMAT_RGBA8)
	return im

func _put(sheet: Image, im: Image, at: Rect2i, nearest := false) -> void:
	if im == null:
		return
	var i := im.duplicate() as Image
	i.convert(Image.FORMAT_RGBA8)
	var k := minf(float(at.size.x) / i.get_width(), float(at.size.y) / i.get_height())
	var sz := Vector2i(maxi(int(i.get_width() * k), 1), maxi(int(i.get_height() * k), 1))
	i.resize(sz.x, sz.y, Image.INTERPOLATE_NEAREST if nearest else Image.INTERPOLATE_LANCZOS)
	sheet.blit_rect(i, Rect2i(Vector2i.ZERO, sz), at.position + (at.size - sz) / 2)

func _compose(cells: Dictionary, wardens: Array, out: String) -> void:
	await tree.process_frame
	var cols := 3
	var rows := int(ceil(wardens.size() / float(cols)))
	var sheet := Image.create(CW * cols, CH * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1c1a24"))
	var vp := SubViewport.new()
	vp.size = Vector2i(sheet.get_width(), sheet.get_height())
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(vp)
	var hdr := 44
	for n in wardens.size():
		var id: String = wardens[n]
		var o := Vector2i((n % cols) * CW, (n / cols) * CH)
		var c: Dictionary = cells[id]
		var sp: Array = REFS[id]
		_put(sheet, _load_ref(sp[0]), Rect2i(o + Vector2i(6, hdr), Vector2i(300, CH - hdr - 6)))
		_put(sheet, c["body"], Rect2i(o + Vector2i(312, hdr), Vector2i(300, CH - hdr - 6)))
		_put(sheet, c["match"], Rect2i(o + Vector2i(618, hdr), Vector2i(180, 180)), true)
		_put(sheet, _load_ref(sp[1]), Rect2i(o + Vector2i(618, hdr + 186), Vector2i(180, CH - hdr - 192)))
		_put(sheet, c["weapon"], Rect2i(o + Vector2i(804, hdr), Vector2i(190, 190)))
		var l := Label.new()
		l.position = Vector2(o) + Vector2(8, 2)
		l.add_theme_font_size_override("font_size", 22)
		l.text = String(verdict.get(id, LABEL[id]))
		l.add_theme_color_override("font_color", Color("ffe9c8"))
		var note := Label.new()
		note.position = Vector2(o) + Vector2(804, hdr + 200)
		note.size = Vector2(190, CH - hdr - 210)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 16)
		var how := "ref (left), in-game idle (right), match camera, weapon ref, weapon close"
		note.text = String(verdict.get(id + "_note", how))
		note.add_theme_color_override("font_color", Color("c8c4d4"))
		vp.add_child(l)
		vp.add_child(note)
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(sheet)
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	vp.move_child(bg, 0)
	await tree.process_frame
	await tree.process_frame
	for k in 6:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out.path_join("weapon_audit_sheet.png"))
	vp.queue_free()
