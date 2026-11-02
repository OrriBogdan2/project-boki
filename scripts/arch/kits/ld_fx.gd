class_name LDFx
extends Node3D
## Linwick's and Dredge's own effects, pooled (one node per match, LDFx.of(m)). Every node is made once
## and reused; nothing is created per frame. One shader (shaders/ld_fx.gdshader, a mode per look) plus
## the see-through rope shader (shaders/ld_rope.gdshader).
##
## - flame(id, parts)      the Flamethrower hose: one MultiMesh of puffs the kit simulates (immediate style)
## - ride(sd, kind, ...)   a projectile look riding on a shot: "cinder" (Fire Bolt), "slug" (Buckshot), "claw" (Grapnel head)
## - place(id, kind, ...)  immediate-style looks the kit refreshes every step: "skull", "swirl", "chain",
##                         "pip", "spiral", "pilot", "anchor", "glow"; stop calling and they hide
## - rope(id, a, b)        the braided Grapnel rope, drawn through walls
## - one-shots: sunburst, scorch, crescent, wave, dot, lava, orb, anchor_drop, embers

const SHADER: Shader = preload("res://shaders/ld_fx.gdshader")
const ROPE_SHADER: Shader = preload("res://shaders/ld_rope.gdshader")
const M_FLAME := 0
const M_ORB := 1
const M_COMET := 2
const M_CRESCENT := 3
const M_SUNBURST := 4
const M_LAVA := 5
const M_SCORCH := 6
const M_SWIRL := 7
const M_LINKS := 8
const M_PIP := 9
const M_SPIRAL := 10
const M_WAVE := 11
const M_DOT := 12
const POOL_CAP := 24           # nodes per kind at most; past it the oldest is taken back
const KEEP := 0.1              # s an immediate-style look stays without a refresh
const FLAME_CAP := 64          # hose puffs drawn at most (the kit keeps fewer)
const HANG_T := 0.3            # s a Buckshot slug hangs as a dot at its stop line

var m: Node
var pools := {}                # kind -> Array of nodes made for it
var live: Array = []           # one-shot effects: {node, t, dur, kind, s0, mat}
var riders: Array = []         # looks riding on a shot: {node, sd, kind, last, on_end}
var placed := {}               # id -> {node, kind, t}
var flames := {}               # id -> {node, t}
var ropes := {}                # id -> {node, mesh, t}
var emitters: Array = []       # ember fountains: {at, t, dur, acc, col}
var made := 0                  # nodes made so far (tests: it stops growing once warm)
var _quad: QuadMesh
var _plane: PlaneMesh
var _ribbon: ArrayMesh
var _cres := {}

static func of(match_node: Node) -> LDFx:
	if match_node.has_meta("ld_fx"):
		var f = match_node.get_meta("ld_fx")
		if is_instance_valid(f):
			return f
	var n := LDFx.new()
	n.m = match_node
	n.name = "LDFx"
	match_node.add_child(n)
	match_node.set_meta("ld_fx", n)
	return n

func _mat(mode: int, col: Color, col2: Color, bb := false) -> ShaderMaterial:
	var mt := ShaderMaterial.new()
	mt.shader = SHADER
	mt.set_shader_parameter("mode", mode)
	mt.set_shader_parameter("color", col)
	mt.set_shader_parameter("color2", col2)
	mt.set_shader_parameter("billboard", bb)
	mt.set_shader_parameter("seed", randf() * 10.0)
	return mt

func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A pooled node of a kind: a hidden one, else a new one (up to POOL_CAP), else the oldest in use.
func _take(kind: String, build: Callable) -> Node3D:
	var arr: Array = pools.get(kind, [])
	pools[kind] = arr
	for n in arr:
		if is_instance_valid(n) and not (n as Node3D).visible:
			(n as Node3D).visible = true
			return n
	if arr.size() < POOL_CAP:
		var nn: Node3D = build.call()
		nn.top_level = true
		add_child(nn)
		arr.append(nn)
		made += 1
		return nn
	var old: Node3D = arr.pop_front()
	arr.append(old)
	for e in live:
		if e["node"] == old: live.erase(e); break
	for r in riders:
		if r["node"] == old: riders.erase(r); break
	for id in placed.keys():
		if placed[id]["node"] == old: placed.erase(id); break
	return old

# ------------------------------------------------------------------ meshes
func _quad_mesh() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new(); _quad.size = Vector2(2, 2)
	return _quad

func _plane_mesh() -> PlaneMesh:
	if _plane == null:
		_plane = PlaneMesh.new(); _plane.size = Vector2(2, 2)
	return _plane

## Two crossed strips along +Z from the head (z 0, UV.x 0) to the tail (z 1).
func _ribbon_mesh() -> ArrayMesh:
	if _ribbon:
		return _ribbon
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ax in [Vector3.RIGHT, Vector3.UP]:
		var w: Vector3 = ax * 0.5
		st.set_uv(Vector2(0, 0)); st.add_vertex(-w)
		st.set_uv(Vector2(0, 1)); st.add_vertex(w)
		st.set_uv(Vector2(1, 1)); st.add_vertex(w + Vector3(0, 0, 1))
		st.set_uv(Vector2(0, 0)); st.add_vertex(-w)
		st.set_uv(Vector2(1, 1)); st.add_vertex(w + Vector3(0, 0, 1))
		st.set_uv(Vector2(1, 0)); st.add_vertex(-w + Vector3(0, 0, 1))
	_ribbon = st.commit()
	return _ribbon

## A crescent in the XZ plane centred on -Z, `arc_deg` wide, outer radius 1, thickest mid-sweep.
func _crescent_mesh(arc_deg: float) -> ArrayMesh:
	var key := int(round(arc_deg))
	if _cres.has(key):
		return _cres[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 18
	var arc := deg_to_rad(arc_deg)
	for i in n:
		var u0 := -arc * 0.5 + arc * float(i) / n; var u1 := -arc * 0.5 + arc * float(i + 1) / n
		var w0 := sin(PI * float(i) / n); var w1 := sin(PI * float(i + 1) / n)
		var o0 := Vector3(sin(u0), 0, -cos(u0)); var o1 := Vector3(sin(u1), 0, -cos(u1))
		var c := o1 * lerpf(1.0, 0.45, w1); var d := o0 * lerpf(1.0, 0.45, w0)
		var ua := float(i) / n; var ub := float(i + 1) / n
		st.set_uv(Vector2(ua, 0)); st.add_vertex(o0); st.set_uv(Vector2(ub, 0)); st.add_vertex(o1); st.set_uv(Vector2(ub, 1)); st.add_vertex(c)
		st.set_uv(Vector2(ua, 0)); st.add_vertex(o0); st.set_uv(Vector2(ub, 1)); st.add_vertex(c); st.set_uv(Vector2(ua, 1)); st.add_vertex(d)
	var mesh := st.commit()
	_cres[key] = mesh
	return mesh

## Dredge's anchor as a translucent ghost of light (2 bh tall): shank, stock, ring and two flukes.
func _anchor_node(col: Color) -> Node3D:
	var n := Node3D.new()
	var mt := Models.glow_mat(Color(col, 0.55))
	n.set_meta("mat", mt)
	var add := func(mesh: Mesh, pos: Vector3, rot := Vector3.ZERO) -> void:
		var p := _mi(mesh, mt); p.position = pos; p.rotation = rot; n.add_child(p)
	add.call(Models.box(0.36, 2.6, 0.3), Vector3(0, 1.6, 0))
	add.call(Models.box(1.7, 0.3, 0.3), Vector3(0, 2.6, 0))
	add.call(Models.cyl(0.4, 0.4, 0.22, 16), Vector3(0, 3.15, 0), Vector3(PI / 2, 0, 0))
	for sx in [-1.0, 1.0]:
		add.call(Models.box(1.3, 0.3, 0.3), Vector3(0.62 * sx, 0.55, 0), Vector3(0, 0, -0.62 * sx))
		add.call(Models.box(0.34, 0.5, 0.34), Vector3(1.2 * sx, 1.0, 0), Vector3(0, 0, 0.3 * sx))
	return n

## The Grapnel's head: a brass three-pronged claw, drawn through walls like the rope.
func _claw_node(col: Color) -> Node3D:
	var n := Node3D.new()
	var mt := ShaderMaterial.new()
	mt.shader = ROPE_SHADER
	mt.set_shader_parameter("color", col)
	mt.set_shader_parameter("color2", Color(1, 1, 1, 1))
	mt.set_shader_parameter("twist", 0.0)
	var add := func(mesh: Mesh, pos: Vector3, rot := Vector3.ZERO) -> void:
		var p := _mi(mesh, mt); p.position = pos; p.rotation = rot; n.add_child(p)
	add.call(Models.box(0.2, 0.2, 0.34), Vector3(0, 0, 0.05))
	for k in 3:
		var a := TAU * k / 3.0
		var o := Vector3(cos(a), sin(a), 0) * 0.17
		add.call(Models.box(0.08, 0.08, 0.36), o + Vector3(0, 0, -0.2), Vector3(-sin(a) * 0.5, cos(a) * 0.5, 0))
		add.call(Models.box(0.07, 0.07, 0.18), o * 1.7 + Vector3(0, 0, -0.38), Vector3(sin(a) * 0.9, -cos(a) * 0.9, 0))
	return n

# ------------------------------------------------------------------ the hose
## The Flamethrower stream this step: parts [{p, age (0..1), r}]. One MultiMesh node per id.
func flame(id: String, parts: Array) -> void:
	var e: Dictionary = flames.get(id, {})
	if e.is_empty() or not is_instance_valid(e["node"]):
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _quad_mesh()
		mm.instance_count = FLAME_CAP
		mm.visible_instance_count = 0
		mmi.multimesh = mm
		mmi.material_override = _mat(M_FLAME, Color.WHITE, Color.WHITE, true)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.top_level = true
		mmi.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 100, 400))
		add_child(mmi)
		made += 1
		e = {"node": mmi}
		flames[id] = e
	e["t"] = m.time
	var node: MultiMeshInstance3D = e["node"]
	node.visible = true
	node.global_transform = Transform3D.IDENTITY
	var mm2 := node.multimesh
	var n := mini(parts.size(), FLAME_CAP)
	mm2.visible_instance_count = n
	for i in n:
		var p: Dictionary = parts[i]
		var r := float(p["r"])
		mm2.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r), p["p"]))
		mm2.set_instance_custom_data(i, Color(float(p["age"]), float(p.get("seed", 0.0)), 0, 0))

func flame_off(id: String) -> void:
	var e: Dictionary = flames.get(id, {})
	if not e.is_empty() and is_instance_valid(e["node"]):
		(e["node"] as Node3D).visible = false

func flame_node(id: String) -> Node3D:
	var e: Dictionary = flames.get(id, {})
	return e["node"] if not e.is_empty() and is_instance_valid(e["node"]) else null

# ------------------------------------------------------------------ one-shots
func _fx(kind: String, mode: int, mesh: Mesh, bb: bool) -> MeshInstance3D:
	return _take(kind, func(): return _mi(mesh, _mat(mode, Color.WHITE, Color.WHITE, bb))) as MeshInstance3D

func _play(n: Node3D, kind: String, col: Color, col2: Color, dur: float, s0: Vector3, mt: ShaderMaterial) -> Dictionary:
	if mt:
		mt.set_shader_parameter("color", col)
		mt.set_shader_parameter("color2", col2)
		mt.set_shader_parameter("life", 0.0)
		mt.set_shader_parameter("progress", 0.0)
		mt.set_shader_parameter("seed", randf() * 10.0)
	n.scale = s0
	var e := {"node": n, "t": 0.0, "dur": maxf(0.05, dur), "kind": kind, "s0": s0, "mat": mt}
	live.append(e)
	return e

func _flat(kind: String, mode: int, at: Vector3, r: float, col: Color, col2: Color, dur: float, yaw := 0.0) -> Dictionary:
	var n := _fx(kind, mode, _plane_mesh(), false)
	n.global_position = at + Vector3(0, 0.06, 0)
	n.rotation = Vector3(0, yaw, 0)
	return _play(n, kind, col, col2, dur, Vector3(r, 1, r), n.material_override)

## A spiky sunburst lying on the ground (the Furnace Cloak's blast), or standing up facing the camera.
func sunburst(at: Vector3, r: float, col: Color, col2: Color, dur := 0.4, upright := false) -> void:
	if upright:
		var n := _fx("sunburst_bb", M_SUNBURST, _quad_mesh(), true)
		n.global_position = at
		_play(n, "sunburst_bb", col, col2, dur, Vector3.ONE * r, n.material_override)
	else:
		_flat("sunburst", M_SUNBURST, at, r, col, col2, dur, randf() * TAU)

## A cracked scorch mark that cools over `dur`.
func scorch(at: Vector3, r: float, dur := 1.0, col := Color("ff7a2a"), col2 := Color("3a1a2a")) -> void:
	_flat("scorch", M_SCORCH, at, r, col, col2, dur, randf() * TAU)

## A thin ring that opens out to `r` (a landing ring, a fizzle).
func wave(at: Vector3, r: float, col: Color, dur := 0.35, col2 := Color(0, 0, 0, 1)) -> void:
	_flat("wave", M_WAVE, at, r, col, col2, dur)

## A blade arc in front of `at` facing `dir`, swept over `dur`. tilt PI/2: standing up.
func crescent(at: Vector3, dir: Vector2, arc_deg: float, reach: float, col: Color, col2: Color, dur := 0.25, tilt := 0.0) -> void:
	var key := "cres%d" % int(round(arc_deg))
	var n := _take(key, func(): return _mi(_crescent_mesh(arc_deg), _mat(M_CRESCENT, col, col2))) as MeshInstance3D
	n.global_position = at
	var d3 := Vector3(dir.x, 0, dir.y)
	if d3.length() < 0.01: d3 = Vector3.FORWARD
	n.basis = Basis.looking_at(d3.normalized(), Vector3.UP) * Basis(Vector3.FORWARD, tilt)
	var e := _play(n, key, col, col2, dur, Vector3.ONE * reach, n.material_override)
	e["sweep"] = true

## A camera-facing glow (a hit flash, the pilot flare).
func orb(at: Vector3, col: Color, col2: Color, size := 0.6, dur := 0.15) -> void:
	var n := _fx("orb", M_ORB, _quad_mesh(), true)
	n.global_position = at
	var e := _play(n, "orb", col, col2, dur, Vector3.ONE * size, n.material_override)
	e["grow"] = 0.5

## A soft dot left hanging in the air (a Buckshot slug at its stop line).
func dot(at: Vector3, col: Color, size := 0.16, dur := HANG_T) -> void:
	var n := _fx("dot", M_DOT, _quad_mesh(), true)
	n.global_position = at
	_play(n, "dot", col, Color(1, 1, 1, 1), dur, Vector3.ONE * size, n.material_override)

## A molten strip from a to b on the ground (the rank-3 fire trail), lasting `dur`.
func lava(a: Vector3, b: Vector3, width: float, dur: float) -> void:
	var ln := Vector2(b.x - a.x, b.z - a.z).length()
	if ln < 0.2:
		return
	var n := _fx("lava", M_LAVA, _plane_mesh(), false)
	n.global_position = (a + b) * 0.5 + Vector3(0, 0.07, 0)
	n.rotation = Vector3(0, atan2(-(b.z - a.z), b.x - a.x), 0)
	var e := _play(n, "lava", Color("ff8a2a"), Color("4a1238"), dur, Vector3(ln * 0.5, 1, width * 0.5), n.material_override)
	(n.material_override as ShaderMaterial).set_shader_parameter("progress", ln)
	e["keep_progress"] = true

## The Anchor Drop's giant ghost anchor dropping onto `at` (lands at 35% of `dur`, then fades).
func anchor_drop(at: Vector3, dir: Vector2, col: Color, dur := 0.5, scl := 1.0) -> void:
	var n := _take("anchor", func(): return _anchor_node(col))
	n.global_position = at + Vector3(0, 3.2, 0)
	n.rotation = Vector3(0, atan2(-dir.x, -dir.y) + PI / 2.0, 0)
	n.scale = Vector3.ONE * scl
	((n.get_meta("mat")) as ShaderMaterial).set_shader_parameter("color", Color(col, 0.55))
	live.append({"node": n, "t": 0.0, "dur": dur, "kind": "anchor", "s0": n.scale, "mat": n.get_meta("mat"), "at": at, "col": col})

## Embers sprayed up and out of a spot for `dur` (Fire Bolt's impact).
func embers(at: Vector3, dur := 0.6, col := Color("ff5a3a")) -> void:
	emitters.append({"at": at, "t": 0.0, "dur": dur, "acc": 0.0, "col": col})

# ------------------------------------------------------------------ immediate looks
func _build_place(kind: String, col: Color, col2: Color) -> Node3D:
	match kind:
		"swirl": return _mi(_plane_mesh(), _mat(M_SWIRL, col, col2))
		"chain": return _mi(_plane_mesh(), _mat(M_LINKS, col, col2))
		"pip": return _mi(_quad_mesh(), _mat(M_PIP, col, col2, true))
		"spiral": return _mi(_quad_mesh(), _mat(M_SPIRAL, col, col2, true))
		"pilot", "glow": return _mi(_quad_mesh(), _mat(M_ORB, col, col2, true))
		"anchor": return _anchor_node(col)
		"claw": return _claw_node(col)
		"skull":
			# the Flame Skull: a standing crescent of fire wrapped round the front, a hot glow inside it
			var n := Node3D.new()
			var cr := _mi(_crescent_mesh(150.0), _mat(M_CRESCENT, col, col2)); cr.name = "Cres"
			(cr.material_override as ShaderMaterial).set_shader_parameter("progress", 1.0)
			cr.rotation = Vector3(0, 0, PI / 2.0)
			n.add_child(cr)
			var cr2 := _mi(_crescent_mesh(110.0), _mat(M_CRESCENT, col2, col)); cr2.name = "Cres2"
			(cr2.material_override as ShaderMaterial).set_shader_parameter("progress", 1.0)
			cr2.position = Vector3(0, 0, 0.12); cr2.scale = Vector3.ONE * 0.75
			n.add_child(cr2)
			var g := _mi(_quad_mesh(), _mat(M_ORB, col, col2, true)); g.name = "Glow"; g.position = Vector3(0, 0, -0.55); g.scale = Vector3.ONE * 0.55
			n.add_child(g)
			for i in 3:
				var tr := _mi(_ribbon_mesh(), _mat(M_COMET, col, Color("3a1a2a"))); tr.name = "Tail%d" % i
				tr.position = Vector3((i - 1) * 0.32, 0.15 * (1 - absi(i - 1)), 0.1); tr.scale = Vector3(0.28, 0.28, 1.6)
				n.add_child(tr)
			return n
	return Node3D.new()

## Shows an immediate look this step. `basis` orients it (flat looks lie on XZ), scl scales it.
func place(id: String, kind: String, at: Vector3, col: Color, col2: Color, scl := 1.0, yaw := 0.0, strength := 1.0) -> Node3D:
	var e: Dictionary = placed.get(id, {})
	if e.is_empty() or not is_instance_valid(e["node"]) or String(e["kind"]) != kind or not (e["node"] as Node3D).visible:
		e = {"node": _take("pl_" + kind, func(): return _build_place(kind, col, col2)), "kind": kind}
		placed[id] = e
	e["t"] = m.time
	var n: Node3D = e["node"]
	n.visible = true
	n.global_position = at
	n.rotation = Vector3(0, yaw, 0)
	n.scale = Vector3.ONE * scl
	if n is MeshInstance3D:
		var mt := (n as MeshInstance3D).material_override as ShaderMaterial
		mt.set_shader_parameter("color", col)
		mt.set_shader_parameter("color2", col2)
		mt.set_shader_parameter("strength", strength)
		mt.set_shader_parameter("life", 0.0)
	return n

func unplace(id: String) -> void:
	var e: Dictionary = placed.get(id, {})
	if not e.is_empty() and is_instance_valid(e["node"]):
		(e["node"] as Node3D).visible = false
	placed.erase(id)

func shown(id: String) -> bool:
	return placed.has(id) and is_instance_valid(placed[id]["node"]) and (placed[id]["node"] as Node3D).visible

# ------------------------------------------------------------------ projectile looks
func _build_rider(kind: String, col: Color, col2: Color) -> Node3D:
	var n := Node3D.new()
	match kind:
		"cinder":
			# Fire Bolt: a red-pink fireball with a yellow core inside a cool violet halo, a smoky comet tail
			var halo := _mi(_quad_mesh(), _mat(M_ORB, Color("6a5aff"), Color(0, 0, 0, 1), true)); halo.name = "Halo"; halo.scale = Vector3.ONE * 0.85; n.add_child(halo)
			var head := _mi(_quad_mesh(), _mat(M_ORB, col, col2, true)); head.name = "Head"; head.scale = Vector3.ONE * 0.55; n.add_child(head)
		"slug":
			var head2 := _mi(_quad_mesh(), _mat(M_ORB, col, col2, true)); head2.name = "Head"; head2.scale = Vector3.ONE * 0.2; n.add_child(head2)
	var tr := _mi(_ribbon_mesh(), _mat(M_COMET, col, Color("3a2a3a") if kind == "cinder" else col2)); tr.name = "Trail"; n.add_child(tr)
	return n

## Rides a look on a shot (match.gd's shot dictionary) until it ends. The plain shot node is handed
## back to the match's pool, so only this look shows. on_end(at, expired) runs when it ends.
func ride(sd: Dictionary, kind: String, col: Color, col2: Color, trail := 1.2, width := 0.3, on_end := Callable()) -> void:
	var n := _take("ride_" + kind, func(): return _build_rider(kind, col, col2))
	for c in n.get_children():
		var mt := (c as MeshInstance3D).material_override as ShaderMaterial
		if c.name == "Head": mt.set_shader_parameter("color", col); mt.set_shader_parameter("color2", col2)
		if c.name == "Trail": mt.set_shader_parameter("color", col)
	var sn = sd.get("node")
	if sn is Node3D and is_instance_valid(sn):
		(sn as Node3D).visible = false
		sd["node"] = null
	riders.append({"node": n, "sd": sd, "kind": kind, "trail": trail, "width": width, "on_end": on_end, "last": sd["pos"]})
	_pose(n, sd["pos"], sd["vel"], trail, width)

func _pose(n: Node3D, at: Vector3, vel: Vector2, trail: float, width: float) -> void:
	n.global_position = at
	var d3 := Vector3(vel.x, 0, vel.y)
	if d3.length() > 0.05:
		n.basis = Basis.looking_at(d3.normalized(), Vector3.UP)
	var tr := n.get_node_or_null("Trail") as Node3D
	if tr:
		var sp := clampf(vel.length() / 20.0, 0.15, 1.0)
		tr.scale = Vector3(width, width, trail * sp)

## The braided Grapnel rope from a to b this step (seen through walls). Stop calling and it goes.
func rope(id: String, a: Vector3, b: Vector3, col: Color, thick := 0.22) -> void:
	var e: Dictionary = ropes.get(id, {})
	if e.is_empty() or not is_instance_valid(e["node"]):
		var im := ImmediateMesh.new()
		var mt := ShaderMaterial.new()
		mt.shader = ROPE_SHADER
		var mi := _mi(im, mt)
		mi.top_level = true
		add_child(mi)
		made += 1
		e = {"node": mi, "mesh": im}
		ropes[id] = e
	e["t"] = m.time
	var mi2: MeshInstance3D = e["node"]
	mi2.visible = true
	mi2.global_transform = Transform3D.IDENTITY
	(mi2.material_override as ShaderMaterial).set_shader_parameter("color", col)
	var im2: ImmediateMesh = e["mesh"]
	im2.clear_surfaces()
	var length := a.distance_to(b)
	if length < 0.1:
		return
	var fwd := (b - a) / length
	var side := fwd.cross(Vector3.UP)
	if side.length() < 0.01: side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(fwd).normalized()
	var n := maxi(4, int(length / 0.15))
	var w := thick * 0.42
	for s in 3:
		im2.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in n + 1:
			var k := float(i) / n
			var ph := k * length * 4.2 + TAU * s / 3.0 - m.time * 3.0
			var c := a.lerp(b, k) + (side * cos(ph) + up * sin(ph)) * thick * 0.32
			im2.surface_set_uv(Vector2(k * length, 0)); im2.surface_add_vertex(c - up * w)
			im2.surface_set_uv(Vector2(k * length, 1)); im2.surface_add_vertex(c + up * w)
		im2.surface_end()

func rope_shown(id: String) -> bool:
	return ropes.has(id) and is_instance_valid(ropes[id]["node"]) and (ropes[id]["node"] as Node3D).visible

# ------------------------------------------------------------------ per frame
func _alive(sd: Dictionary) -> bool:
	for s in m.shots:
		if is_same(s, sd): return true
	return false

func _process(delta: float) -> void:
	for e in live.duplicate():
		var n: Node3D = e["node"]
		if not is_instance_valid(n):
			live.erase(e); continue
		e["t"] = float(e["t"]) + delta
		var u := clampf(float(e["t"]) / float(e["dur"]), 0.0, 1.0)
		var mt: ShaderMaterial = e["mat"]
		match String(e["kind"]):
			"anchor":
				var fall := clampf(u / 0.35, 0.0, 1.0)
				n.global_position = (e["at"] as Vector3) + Vector3(0, 3.2 * (1.0 - fall * fall), 0)
				var sq := 1.0 + (0.25 * (1.0 - clampf((u - 0.35) / 0.2, 0.0, 1.0)) if u >= 0.35 else 0.0)
				n.scale = (e["s0"] as Vector3) * Vector3(sq, 1.0 / sq, sq)
				mt.set_shader_parameter("color", Color(e["col"], 0.55 * (1.0 - smoothstep(0.55, 1.0, u))))
			_:
				mt.set_shader_parameter("life", u)
				if e.get("sweep", false): mt.set_shader_parameter("progress", minf(1.0, u * 1.8))
				if e.has("grow"): n.scale = (e["s0"] as Vector3) * (1.0 + float(e["grow"]) * u)
		if u >= 1.0:
			n.visible = false
			live.erase(e)
	for em in emitters.duplicate():
		em["t"] = float(em["t"]) + delta
		em["acc"] = float(em["acc"]) + delta
		if float(em["acc"]) >= 0.07 and m.get("fx") != null:
			em["acc"] = 0.0
			m.fx.spark((em["at"] as Vector3) + Vector3(0, 0.9, 0), Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3)), em["col"], 6, 5.0, 60.0, 0.45, 9.0, 1.3)
		if float(em["t"]) >= float(em["dur"]):
			emitters.erase(em)
	for r in riders.duplicate():
		var n: Node3D = r["node"]
		var sd: Dictionary = r["sd"]
		if not _alive(sd) or not is_instance_valid(n):
			if is_instance_valid(n): n.visible = false
			riders.erase(r)
			var expired := float(sd.get("life", 0.0)) <= 0.02
			if (r["on_end"] as Callable).is_valid(): (r["on_end"] as Callable).call(r["last"], expired)
			continue
		r["last"] = sd["pos"]
		_pose(n, sd["pos"], sd["vel"], float(r["trail"]), float(r["width"]))
	for id in placed.keys():
		var e: Dictionary = placed[id]
		if m.time - float(e.get("t", 0.0)) > KEEP:
			if is_instance_valid(e["node"]): (e["node"] as Node3D).visible = false
			placed.erase(id)
	for id in flames.keys():
		var e: Dictionary = flames[id]
		if m.time - float(e.get("t", 0.0)) > KEEP and is_instance_valid(e["node"]):
			(e["node"] as Node3D).visible = false
	for id in ropes.keys():
		var e: Dictionary = ropes[id]
		if m.time - float(e.get("t", 0.0)) > KEEP and is_instance_valid(e["node"]):
			(e["node"] as Node3D).visible = false
