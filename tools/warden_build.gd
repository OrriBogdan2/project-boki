extends RefCounted
## --warden-build [--warden=<id>]: builds a Warden's INTERIM 3D model from its turnaround sheet, without
## Blender, and writes it as art/wardens/<name>/<name>.glb through GLTFDocument, so the game loads it on
## the same path the Blender exports will take (WardenGlb, docs/art/wardens/RIG_CONTRACT.md).
## Each body part is a tube of rings: a ring's width comes from the figure's silhouette on the front view
## at that sheet row, its depth and how far forward it sits from the side view, and the rows are mapped
## onto the procedural rig's landmarks (soles, knees, hips, shoulders, neck, crown) so every joint bends
## where the rig bends. Faces are painted by projecting the sheet's front, back or side view onto them;
## those crops are packed into one 1024 atlas. Skinned to the contract armature (WardenSkeleton) built
## from the Warden's own rig. The per-Warden numbers live in tools/warden_build_<name>.gd.

const SPECS := {"gunslinger": preload("res://tools/warden_build_vex.gd")}
const ATLAS := 1024
const SEGS := 28                 # faces around a ring
const BG_DIST := 0.12            # colour distance from the sheet's grey ground that counts as the figure (sum of rgb)
const INSET := 0.9               # how far toward a silhouette's edge the paint is taken (1: right to the outline)
const SIDE_VIEW := 0.88          # faces turned this square to a side (cos) take the profile's paint
const DILATE := 6                # px the figure's paint is grown over the grey ground in the atlas (no grey seams)
const SHEET_BODY_Y := 0          # atlas row the whole-figure crops start at
const SHEET_HEAD_GAP := 8        # px between the figure crops and the head crops
const SOLE_BELOW_KNEE := 0.245   # m from knee to sole in the neutral rig (HunterAnim SHIN)
const KNEE_BELOW_HIP := 0.2      # m from hip to knee in the neutral rig (HunterAnim THIGH)
const HAND_LEN := 0.085          # m from the wrist to the fingertips at a leg scale of 1
const MAX_TRIS := 15000          # RIG_CONTRACT budget

var sp: Script
var img: Image
var bg: Color
var rest: Dictionary
var skel: Skeleton3D
var land := {}                   # landmark -> model y (m)
var leg_k := 1.0                 # the Warden's leg scale (its legs' length over the neutral rig's)
var atlas: Image
var crops := {}                  # "body:front" / "head:side"... -> [Rect2i on the sheet, atlas origin, scale]
var tools := {}                  # slot -> SurfaceTool
var tris := 0

func run(main: Node) -> void:
	var arch := "gunslinger"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--warden="):
			arch = a.substr(9)
	sp = SPECS[arch]
	var m := Models.hunter(Arch.weight(arch), Data.TEAM_COLORS[0], Arch.signature(arch), "", PlayerLook.neutral(), arch)
	rest = m.get_meta("rig_rest")
	skel = WardenSkeleton.build(rest)
	_landmarks(m)
	m.free()
	img = Image.load_from_file(ProjectSettings.globalize_path(sp.SHEET))
	img.convert(Image.FORMAT_RGB8)
	bg = img.get_pixel(12, 12)
	_atlas()
	_torso()
	_head()
	for sd in ["L", "R"]:
		_leg(sd)
		_arm(sd)
	_plate()
	_scarf()
	var out := WardenGlb.path(arch)
	var bones := skel.get_bone_count()
	var err := _export(out)
	print("WARDENBUILD %s: %d triangles, %d bones, %s -> %s" % [arch, tris, bones, error_string(err), out])
	print("WARDENBUILD_DONE %s" % ("PASS" if err == OK and tris <= MAX_TRIS else "FAIL"))
	main.get_tree().quit()

## Rig landmarks in model space, as the sheet rows in ROWS name them.
func _landmarks(m: Node3D) -> void:
	var y := func(b: String) -> float: return (rest[b] as Transform3D).origin.y
	leg_k = (rest["thigh.L"] as Transform3D).origin.distance_to((rest["shin.L"] as Transform3D).origin) / KNEE_BELOW_HIP
	land["knee"] = (y.call("shin.L") + y.call("shin.R")) * 0.5
	land["sole"] = float(land["knee"]) - SOLE_BELOW_KNEE * leg_k
	land["hip"] = (y.call("thigh.L") + y.call("thigh.R")) * 0.5
	land["shoulder"] = (y.call("upper_arm.L") + y.call("upper_arm.R")) * 0.5
	land["neck"] = y.call("head")
	var head := m.get_node("Rig/Torso/HeadPivot/Head") as MeshInstance3D
	land["crown"] = ((rest["head"] as Transform3D) * head.transform * head.mesh.get_aabb()).end.y

## Model height (m) of a sheet row: piecewise linear through the landmark rows (extended past the ends).
func row_y(row: float) -> float:
	var r: Array = sp.ROWS
	var i := 0
	while i < r.size() - 2 and row < float(r[i + 1][0]):
		i += 1
	var r0 := float(r[i][0])
	var r1 := float(r[i + 1][0])
	return lerpf(float(land[r[i][1]]), float(land[r[i + 1][1]]), (row - r0) / (r1 - r0))

## Metres per sheet pixel, vertically, averaged over a part's rows (its widths use one scale, so a stretch
## between two landmarks doesn't bulge it).
func part_scale(rows: Array) -> float:
	return absf(row_y(float(rows[1])) - row_y(float(rows[0]))) / absf(float(rows[1]) - float(rows[0]))

# --- the sheet ---------------------------------------------------------------------------------------

func fg(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	var c := img.get_pixel(x, y)
	return absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b) > BG_DIST

## The figure's run on a row through `guess` (the nearest figure pixel to it), at most `half` px either way.
func run_at(row: float, guess: float, half: float) -> Vector2:
	var y := int(row)
	var g := int(guess)
	for d in 30:
		if fg(g + d, y):
			g += d
			break
		if fg(g - d, y):
			g -= d
			break
	var lo := g
	while lo > guess - half and (fg(lo - 1, y) or fg(lo - 3, y)):
		lo -= 1
	var hi := g
	while hi < guess + half and (fg(hi + 1, y) or fg(hi + 3, y)):
		hi += 1
	return Vector2(lo, hi)

## A part's half-width limit at a row, from its [[row, px], ...] table.
func half_at(tab: Array, row: float) -> float:
	if row <= float(tab[0][0]):
		return float(tab[0][1])
	for i in tab.size() - 1:
		if row <= float(tab[i + 1][0]):
			var r0 := float(tab[i][0])
			var r1 := float(tab[i + 1][0])
			return lerpf(float(tab[i][1]), float(tab[i + 1][1]), (row - r0) / (r1 - r0))
	return float(tab[-1][1])

# --- the atlas ---------------------------------------------------------------------------------------

## The sheet's three views (and a sharper copy of the head from each) packed into one atlas.
func _atlas() -> void:
	atlas = Image.create(ATLAS, ATLAS, false, Image.FORMAT_RGB8)
	atlas.fill(bg)
	var mask := PackedByteArray()
	mask.resize(ATLAS * ATLAS)
	var total := 0
	for v in sp.BODY_CROPS:
		total += int(sp.BODY_CROPS[v][2])
	var k := float(ATLAS) / float(total)
	var x := 0
	for v in sp.BODY_CROPS:
		x += _blit("body:" + v, sp.BODY_CROPS[v], Vector2i(x, SHEET_BODY_Y), k, mask)
	var y := SHEET_BODY_Y + int(ceil(1240.0 * k)) + SHEET_HEAD_GAP
	x = 0
	for v in sp.HEAD_CROPS:
		x += _blit("head:" + v, sp.HEAD_CROPS[v], Vector2i(x, y), 1.0, mask) + 4
	_dilate(mask)

func _blit(key: String, c: Array, at: Vector2i, k: float, mask: PackedByteArray) -> int:
	var rect := Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3]))
	var part := img.get_region(rect)
	var w := int(round(rect.size.x * k))
	var h := int(round(rect.size.y * k))
	part.resize(w, h, Image.INTERPOLATE_CUBIC)
	atlas.blit_rect(part, Rect2i(0, 0, w, h), at)
	for yy in h:
		for xx in w:
			var p := part.get_pixel(xx, yy)
			if absf(p.r - bg.r) + absf(p.g - bg.g) + absf(p.b - bg.b) > BG_DIST:
				mask[(at.y + yy) * ATLAS + at.x + xx] = 1
	crops[key] = [rect, Vector2(at), k]
	return w

## Grows the figure's paint DILATE px over the grey ground, so a face whose edge reaches past the drawn
## silhouette still takes the figure's colour, not the sheet's background.
func _dilate(mask: PackedByteArray) -> void:
	var data := atlas.get_data()
	for _pass in DILATE:
		var grown := mask.duplicate()
		for y in range(1, ATLAS - 1):
			for x in range(1, ATLAS - 1):
				var i := y * ATLAS + x
				if mask[i] != 0:
					continue
				var n := 0
				var acc := Vector3.ZERO
				for j in [i - 1, i + 1, i - ATLAS, i + ATLAS]:
					if mask[j] != 0:
						n += 1
						acc += Vector3(data[j * 3], data[j * 3 + 1], data[j * 3 + 2])
				if n > 0:
					acc /= n
					data[i * 3] = int(acc.x)
					data[i * 3 + 1] = int(acc.y)
					data[i * 3 + 2] = int(acc.z)
					grown[i] = 1
		mask = grown
	atlas = Image.create_from_data(ATLAS, ATLAS, false, Image.FORMAT_RGB8, data)

## A sheet pixel of a view, as an atlas UV (set: "body" or "head").
func uv_of(set_name: String, view: String, p: Vector2) -> Vector2:
	var c: Array = crops["%s:%s" % [set_name, view]]
	var rect: Rect2i = c[0]
	return ((c[1] as Vector2) + (p - Vector2(rect.position)) * float(c[2])) / float(ATLAS)

func atlas_col(uv: Vector2) -> Color:
	return atlas.get_pixel(clampi(int(uv.x * ATLAS), 0, ATLAS - 1), clampi(int(uv.y * ATLAS), 0, ATLAS - 1))

## The toon slot of a face painted `c`: the nearest palette colour's.
func slot_of(c: Color, glow_ok: bool) -> String:
	if glow_ok and c.r >= sp.GLOW_MIN.x and c.g >= sp.GLOW_MIN.y and c.b <= sp.GLOW_MAX_B:
		return "glow"
	var best := "cloth"
	var bd := 9.0
	for e in sp.PALETTE:
		var p: Color = e[1]
		var d := Vector3(c.r - p.r, c.g - p.g, c.b - p.b).length()
		if d < bd:
			bd = d
			best = String(e[0])
	return best

# --- parts -------------------------------------------------------------------------------------------

## The trunk, hips to neck: front widths (clamped clear of the arms), side depth and lean.
func _torso() -> void:
	var t: Dictionary = sp.TORSO
	var rings: Array = []
	var row := float(t["rows"][0])
	while row <= float(t["rows"][1]):
		var hf := half_at(t["half"], row)
		var f := run_at(row, sp.CX["front"], hf)
		var b := run_at(row, sp.CX["back"], hf)
		var s := run_at(row, sp.CX["side"], float(t["side_half"]))
		var k := part_scale(t["rows"]) * float(t["k"])
		var ao := lerpf(0.82, 1.0, smoothstep(float(t["rows"][1]), float(t["rows"][1]) - 40.0, row))
		rings.append(_ring(Vector3(0.0, row_y(row), _depth_mid(s, k)), f, b, s, k, row, {"hips": 1.0}, ao))
		row += 12.0
	_tube(rings, "body", sp.MIRROR_BODY, false)

## The head and beret, neck up, as drawn (not mirrored: the mechanical eye stays on her right).
func _head() -> void:
	var t: Dictionary = sp.HEAD
	var rings: Array = []
	var row := float(t["rows"][0])
	var neck := float(land["neck"])
	while row <= float(t["rows"][1]):
		var hf := half_at(t["half"], row)
		var f := run_at(row, sp.CX["front"], hf)
		var b := run_at(row, sp.CX["back"], hf)
		var s := run_at(row, sp.CX["side"] + 10.0, float(t["side_half"]))
		var k := part_scale([sp.ROWS[-2][0], sp.ROWS[-1][0]]) * float(t["k"])
		var y := row_y(row)
		var wh := smoothstep(neck - 0.03, neck + 0.05, y)
		var w := {"head": wh, "hips": 1.0 - wh}
		rings.append(_ring(Vector3(0.0, y, _depth_mid(s, k)), f, b, s, k, row, w, lerpf(0.85, 1.0, wh)))
		row += 6.0
	_tube(rings, "head", false, true)

## One leg, hip to sole, on its rig leg; the boot's toe from the side view.
func _leg(sd: String) -> void:
	var t: Dictionary = sp.LEGS
	var fx := float(t["x_front"][_sheet_side(sd)])
	var thigh := "thigh." + sd
	var shin := "shin." + sd
	var cx := (rest[thigh] as Transform3D).origin.x
	var knee := float(land["knee"])
	var rings: Array = []
	var row := float(t["rows"][0])
	while row <= float(t["rows"][1]):
		var hf := half_at(t["half"], row)
		var f := run_at(row, fx, hf)
		fx = (f.x + f.y) * 0.5
		var bx := float(sp.CX["back"]) + float(sp.CX["front"]) - fx
		var b := run_at(row, bx, hf)
		var side_half := float(t["toe_half"]) if row >= float(t["toe_row"]) else float(t["side_half"])
		var s := run_at(row, sp.CX["side"], side_half)
		var k := part_scale(t["rows"]) * float(t["k"])
		var y := row_y(row)
		var ws := 1.0 - smoothstep(knee - 0.05, knee + 0.05, y)
		var ao := lerpf(0.78, 1.0, smoothstep(float(land["hip"]), float(land["hip"]) - 0.1, y))
		rings.append(_ring(Vector3(cx, y, _depth_mid(s, k)), f, b, s, k, row, {thigh: 1.0 - ws, shin: ws}, ao))
		row += 14.0
	_tube(rings, "body", sp.MIRROR_BODY, true)

## One arm along its rig arm (hanging: the contract's rest), its widths from the sheet's arm.
func _arm(sd: String) -> void:
	var a: Dictionary = sp.ARMS[_sheet_side(sd)]
	var pts: Array = a["pts"]
	var sh := (rest["upper_arm." + sd] as Transform3D).origin
	var el := (rest["forearm." + sd] as Transform3D).origin
	var hd := (rest["hand." + sd] as Transform3D).origin
	var tip := hd + (hd - el).normalized() * HAND_LEN * leg_k
	var joints := [sh, el, hd, tip]
	var rings: Array = []
	var t := -0.12
	while t <= 3.0001:
		var i := clampi(int(floor(t)), 0, 2)
		var u := t - i
		var p := (pts[i] as Vector2).lerp(pts[i + 1], u)
		var c := (joints[i] as Vector3).lerp(joints[i + 1], u)
		var seg_m := (joints[i] as Vector3).distance_to(joints[i + 1])
		var k := seg_m / (pts[i] as Vector2).distance_to(pts[i + 1]) * float(sp.ARM_K)
		var f := run_at(p.y, p.x, float(a["half"]))
		var b := run_at(p.y, float(sp.CX["back"]) + float(sp.CX["front"]) - p.x, float(a["half"]))
		var half_w := (f.y - f.x) * 0.5
		var s := Vector2(-half_w * 0.9, half_w * 0.9)       # no side view of the arms: round, a little flat
		var ring := _ring(c, f, b, s, k, p.y, _arm_w(sd, t), lerpf(0.84, 1.0, smoothstep(-0.12, 0.3, t)))
		ring["c"] = c
		rings.append(ring)
		t += 0.12 if t < 2.0 else 0.2
	_tube(rings, "body", sp.MIRROR_BODY, false)

## Which of the sheet's front-view limbs ("L": the sheet's left) a model limb takes. Facing us, her right
## (+x, "R") is drawn on the sheet's left; mirrored, the model's left is.
func _sheet_side(sd: String) -> String:
	return "L" if (sd == "L") == bool(sp.MIRROR_BODY) else "R"

## Arm skin weights along the arm (0 shoulder, 1 elbow, 2 wrist, 3 fingertips): the shoulder blends
## into the chest, each joint over a short span.
func _arm_w(sd: String, t: float) -> Dictionary:
	var up := 1.0 - smoothstep(0.85, 1.15, t)
	var hand := smoothstep(1.9, 2.1, t)
	var chest := (1.0 - smoothstep(-0.12, 0.2, t)) * 0.4
	return {"hips": chest, "upper_arm." + sd: up * (1.0 - chest), "forearm." + sd: (1.0 - up) * (1.0 - hand),
		"hand." + sd: hand}

## The ring's centre z from a side-view run (the sheet faces +x in profile: forward is -z).
func _depth_mid(s: Vector2, k: float) -> float:
	return -((s.x + s.y) * 0.5 - float(sp.CX["side"])) * k

## One ring: centre c, its front, back and side runs (px), metres per px k, its sheet row, skin weights, AO.
func _ring(c: Vector3, f: Vector2, b: Vector2, s: Vector2, k: float, row: float, w: Dictionary,
		ao: float) -> Dictionary:
	return {"c": c, "a": maxf(0.004, (f.y - f.x) * 0.5 * k), "d": maxf(0.004, (s.y - s.x) * 0.5 * k),
		"f": f, "b": b, "s": s, "row": row, "w": w, "ao": ao}

## A closed tube through the rings (rounded caps at both ends), painted from the views: front-facing
## faces from the front view, back-facing from the back, and (side_ok) faces turned square to a side
## from the profile. set_name picks the head's or the body's crops; mirrored: the sheet taken mirrored.
func _tube(rings: Array, set_name: String, mirrored: bool, side_ok: bool) -> void:
	var full: Array = [_cap(rings[0], rings[1], 0.0)]
	full.append(_cap(rings[0], rings[1], 0.6))
	full.append_array(rings)
	full.append(_cap(rings[-1], rings[-2], 0.6))
	full.append(_cap(rings[-1], rings[-2], 0.0))
	var grid: Array = []
	for r in full:
		var row: Array = []
		for j in SEGS:
			var th := TAU * j / SEGS
			row.append((r["c"] as Vector3) + Vector3(cos(th) * float(r["a"]), 0.0, sin(th) * float(r["d"])))
		grid.append(row)
	for i in full.size() - 1:
		for j in SEGS:
			var j1 := (j + 1) % SEGS
			var thm := TAU * (j + 0.5) / SEGS
			var ox := cos(thm)
			var oz := sin(thm)
			var view := "front" if oz < 0.0 else "back"
			if side_ok and absf(ox) > SIDE_VIEW:
				view = "side"
			var quad := [[i, j], [i, j1], [i + 1, j1], [i + 1, j]]
			var uvs: Array = []
			for q in quad:
				uvs.append(_uv(full[q[0]], TAU * q[1] / SEGS, view, set_name, mirrored))
			var mid := ((uvs[0] as Vector2) + (uvs[2] as Vector2)) * 0.5
			var slot := slot_of(atlas_col(mid), set_name == "head")
			var verts: Array = []
			for qi in 4:
				var q: Array = quad[qi]
				var r: Dictionary = full[q[0]]
				verts.append([grid[q[0]][q[1]], _normal(grid, full, q[0], q[1]), uvs[qi], r["w"], float(r["ao"])])
			_quad(slot, verts)

## A cap ring past the end ring `e` (away from its neighbour `n`): s = 0.6 shrinks it, 0 closes it.
func _cap(e: Dictionary, n: Dictionary, s: float) -> Dictionary:
	var out := e.duplicate()
	var away := ((e["c"] as Vector3) - (n["c"] as Vector3)).normalized()
	var reach := minf(float(e["a"]), float(e["d"])) * (0.35 if s > 0.0 else 0.5)
	out["c"] = (e["c"] as Vector3) + away * reach
	out["a"] = maxf(0.001, float(e["a"]) * s)
	out["d"] = maxf(0.001, float(e["d"]) * s)
	return out

## The sheet pixel a ring point at angle th shows in a view, as an atlas UV.
func _uv(r: Dictionary, th: float, view: String, set_name: String, mirrored: bool) -> Vector2:
	var ox := cos(th) * INSET
	var oz := sin(th) * INSET
	var u := 0.0
	var f: Vector2 = r["f"]
	var b: Vector2 = r["b"]
	var s: Vector2 = r["s"]
	match view:
		"front":
			# drawn facing us, her right (+x) is the sheet's left; mirrored, the model's -x is
			u = lerpf(f.x, f.y, 0.5 + 0.5 * ox) if mirrored else lerpf(f.y, f.x, 0.5 + 0.5 * ox)
		"back":
			u = lerpf(b.y, b.x, 0.5 + 0.5 * ox) if mirrored else lerpf(b.x, b.y, 0.5 + 0.5 * ox)
		_:
			# in profile she faces the sheet's right: her front (-z) is the run's right end
			u = lerpf(s.y, s.x, 0.5 + 0.5 * oz)
	return uv_of(set_name, view, Vector2(u, float(r["row"])))

## A smooth normal at grid point (i, j): across the ring and along the tube, pointing outward.
func _normal(grid: Array, full: Array, i: int, j: int) -> Vector3:
	var c := full[i]["c"] as Vector3
	var p := grid[i][j] as Vector3
	if i == 0 or i == grid.size() - 1:
		return (c - (full[1 if i == 0 else i - 1]["c"] as Vector3)).normalized()
	var around := (grid[i][(j + 1) % SEGS] as Vector3) - (grid[i][(j - 1 + SEGS) % SEGS] as Vector3)
	var along := (grid[i + 1][j] as Vector3) - (grid[i - 1][j] as Vector3)
	var n := around.cross(along).normalized()
	if n.dot(p - c) < 0.0:
		n = -n
	return n if n.length() > 0.5 else (p - c).normalized()

## Two triangles into the slot's surface: verts are [position, normal, uv, weights, ao], wound outward.
func _quad(slot: String, verts: Array) -> void:
	var st: SurfaceTool = tools.get(slot)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[slot] = st
	var p0: Vector3 = verts[0][0]
	var n := ((verts[1][0] as Vector3) - p0).cross((verts[2][0] as Vector3) - p0)
	var order := [0, 2, 1, 0, 3, 2] if n.dot(verts[0][1]) >= 0.0 else [0, 1, 2, 0, 2, 3]
	for k in order:
		var v: Array = verts[k]
		var bones := PackedInt32Array()
		var ws := PackedFloat32Array()
		var w: Dictionary = v[3]
		var tot := 0.0
		for bn in w:
			if float(w[bn]) > 0.001 and bones.size() < 4:
				bones.append(skel.find_bone(bn))
				ws.append(float(w[bn]))
				tot += float(w[bn])
		while bones.size() < 4:
			bones.append(0)
			ws.append(0.0)
		for q in 4:
			ws[q] /= maxf(tot, 0.0001)
		st.set_normal(v[1])
		st.set_uv(v[2])
		st.set_color(Color(float(v[4]), float(v[4]), float(v[4])))
		st.set_bones(bones)
		st.set_weights(ws)
		st.add_vertex(v[0])
	tris += 2

## The oversized slate plate over the mechanical shoulder: a domed shell (outside and in), painted from
## the side view so its eye sigil faces out.
func _plate() -> void:
	var p: Dictionary = sp.PLATE
	var sd := String(p["side"])
	var dims: Vector3 = p["size"]
	var off: Vector3 = p["offset"]
	var out_x := off.x if sd == "L" else -off.x
	var c := (rest["pauldron." + sd] as Transform3D).origin + Vector3(out_x, off.y, off.z)
	var cen: Vector2 = p["centre"]
	var rpx := float(p["radius_px"])
	var lat := 9
	for shell in [1.0, 0.93]:
		var grid: Array = []
		for i in lat + 1:
			var ph := deg_to_rad(105.0) * i / lat
			var row: Array = []
			for j in SEGS:
				var th := TAU * j / SEGS
				var dome := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
				row.append(c + dome * dims * shell)
			grid.append(row)
		for i in lat:
			for j in SEGS:
				var quad := [[i, j], [i, (j + 1) % SEGS], [i + 1, (j + 1) % SEGS], [i + 1, j]]
				var verts: Array = []
				var mid := Vector2.ZERO
				for q in quad:
					var pos: Vector3 = grid[q[0]][q[1]]
					var o := pos - c
					var uv := uv_of("body", "side", cen + Vector2(-o.z / dims.z, -o.y / dims.y) * rpx * 0.95)
					mid += uv * 0.25
					var nrm: Vector3 = (o / (dims * dims)).normalized() * shell
					if shell < 1.0:
						nrm = -nrm.normalized()
					verts.append([pos, nrm.normalized(), uv, {"pauldron." + sd: 1.0}, 0.9 if shell < 1.0 else 1.0])
				_quad(slot_of(atlas_col(mid), false), verts)

## The signal scarf's tail streaming back off the neck: a two-sided ribbon on the scarf bone.
func _scarf() -> void:
	var s: Dictionary = sp.SCARF
	var neck := float(land["neck"])
	var side := 1.0 if sp.MIRROR_BODY else -1.0
	var n := 10
	var uv := uv_of("body", "front", s["patch"])
	var path := func(u: float) -> Vector3:
		var wave := sin(u * 5.0) * 0.025 + u * 0.03
		return Vector3(side * (0.07 + u * float(s["len"])), neck - 0.05 + wave, 0.06 + u * 0.24)
	for face in [1.0, -1.0]:
		for i in n:
			var verts: Array = []
			for q in [[i, 1.0], [i, -1.0], [i + 1, -1.0], [i + 1, 1.0]]:
				var u := float(q[0]) / n
				var along: Vector3 = path.call(u)
				var nrm: Vector3 = ((path.call(u + 0.05) as Vector3) - along).cross(Vector3.UP).normalized() * face
				var wdt := float(s["width"]) * lerpf(1.0, 0.45, u) * 0.5
				var w := {"scarf": lerpf(0.5, 1.0, minf(1.0, u * 3.0)), "hips": lerpf(0.5, 0.0, minf(1.0, u * 3.0))}
				verts.append([along + Vector3(0, float(q[1]) * wdt, 0) + nrm * 0.002, nrm, uv, w, 1.0])
			_quad("cloth", verts)

# --- export ------------------------------------------------------------------------------------------

## The armature, the skinned body (one surface per slot, sharing the atlas) and the anchor empties, written
## as a .glb.
func _export(out: String) -> Error:
	var root := Node3D.new()
	root.name = String(sp.ART)
	root.add_child(skel)
	skel.owner = root
	var tex := ImageTexture.create_from_image(atlas)
	tex.resource_name = "atlas"
	var mesh := ArrayMesh.new()
	for slot in tools:
		var st: SurfaceTool = tools[slot]
		var mat := StandardMaterial3D.new()
		mat.resource_name = slot
		mat.albedo_texture = tex
		mat.vertex_color_use_as_albedo = false
		st.set_material(mat)
		st.index()
		st.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = mesh
	skel.add_child(mi)
	mi.owner = root
	mi.skin = skel.create_skin_from_rest_transforms()
	mi.skeleton = NodePath("..")
	_anchor(root, "head", "anchor_head_top", Vector3(0, float(land["crown"]) - float(land["neck"]) + 0.08, 0))
	var hips_y := (rest["hips"] as Transform3D).origin.y
	_anchor(root, "hips", "anchor_chest", Vector3(0, float(land["shoulder"]) - hips_y - 0.14, -0.12))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(out))
	root.free()
	return err

## An anchor empty riding a bone (exported as a child of the bone's joint).
func _anchor(root: Node3D, bone: String, anchor_name: String, at: Vector3) -> void:
	var ba := BoneAttachment3D.new()
	ba.name = bone + "_attach"
	skel.add_child(ba)
	ba.owner = root
	ba.bone_name = bone
	ba.transform = skel.get_bone_global_rest(skel.find_bone(bone))
	var an := Node3D.new()
	an.name = anchor_name
	ba.add_child(an)
	an.owner = root
	an.position = at
