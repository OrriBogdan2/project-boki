class_name DJFx
extends Node3D
## Sable's and Juggernaut's own effects, pooled (one node per match, DJFx.of(m)): projectile looks that
## ride on a shot (or on a kit-run projectile), four-point stars, fizzle puffs, heal pillars, two-tone
## crescents, afterimage chains, and per-frame chains (the Warchain, the Bola cord). Every node is made
## once and reused; nothing is created per frame. One set of looks (shaders/dj_fx.gdshaderinc, a mode per
## look) drawn alpha blended (dj_fx_mix.gdshader) so colour and darkness hold on bright ground; only glows
## (cores, the lightning) are additive (dj_fx.gdshader).

const SHADER: Shader = preload("res://shaders/dj_fx.gdshader")
const SHADER_MIX: Shader = preload("res://shaders/dj_fx_mix.gdshader")
const M_STAR := 0
const M_PILLAR := 1
const M_COMET := 2
const M_CRESCENT := 3
const M_PUFF := 4
const M_LINKS := 5
const M_BOLT := 6
const POOL_CAP := 24           # nodes per kind at most; past it the oldest is taken back
const CORE_W := 0.35           # of a streak's width: its bright core
const KEEP := 0.1              # s an immediate-style look (place / chain) stays without a refresh

var m: Node
var free_pools := {}           # kind -> Array of nodes made for it
var live: Array = []           # one-shot effects: {node, t, dur, kind, s0, mat}
var riders: Array = []         # looks riding on a shot: {node, sd, kind, spin, on_end}
var placed := {}               # id -> {node, kind, t}: immediate-style projectile looks (kit-run projectiles)
var chains := {}               # id -> {node, mesh, t}
var _quad: QuadMesh
var _cres := {}                # arc degrees -> crescent mesh (unit reach)
var _col: ArrayMesh
var _ribbon: ArrayMesh
var made := 0                  # nodes made so far (tests: it stops growing once warm)
var _warming: Array = []       # the loading screen's stand-ins (prewarm)
var _solids: Array = []        # kept for the match: freeing the last material of a kind frees its compiled shader

static func of(match_node: Node) -> DJFx:
	if match_node.has_meta("dj_fx"):
		var f = match_node.get_meta("dj_fx")
		if is_instance_valid(f):
			return f
	var n := DJFx.new()
	n.m = match_node
	n.name = "DJFx"
	match_node.add_child(n)
	match_node.set_meta("dj_fx", n)
	return n

func _mat(mode: int, col: Color, col2: Color, bb := false, glow := false) -> ShaderMaterial:
	var mt := ShaderMaterial.new()
	mt.shader = SHADER if glow else SHADER_MIX
	mt.set_shader_parameter("mode", mode)
	mt.set_shader_parameter("color", col)
	mt.set_shader_parameter("color2", col2)
	mt.set_shader_parameter("billboard", bb)
	return mt

## A flat colour that keeps its hue on grass and sand (projectile heads, afterimages).
static func solid(col: Color) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = col
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	if col.a < 0.999:
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mt

func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A pooled node of a kind: a hidden one, else a new one (up to POOL_CAP), else the oldest in use.
func _take(kind: String, build: Callable) -> Node3D:
	var arr: Array = free_pools.get(kind, [])
	free_pools[kind] = arr
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
		if e["node"] == old:
			live.erase(e)
			break
	for r in riders:
		if r["node"] == old:
			riders.erase(r)
			break
	return old

## The loading screen's stand-ins (Match.warm_up): each of this library's shaders on each of its mesh kinds and its two
## plain colours, drawn once so the first dash or shot of a match doesn't compile them mid-move (item 181).
func prewarm(at: Vector3) -> void:
	if _warming.is_empty():
		for mesh: Mesh in [_quad_mesh(), _ribbon_mesh(), _crescent_mesh(140.0), _column()]:
			_warming.append(_mi(mesh, _mat(0, Color.WHITE, Color.WHITE)))
			_warming.append(_mi(mesh, _mat(0, Color.WHITE, Color.WHITE, false, true)))
		_solids = [solid(Color.WHITE), solid(Color(1, 1, 1, 0.5))]
		for mesh: Mesh in [_quad_mesh(), star_mesh(4, 0.3), Models.sphere(0.1, 8), Models.capsule(0.3, 1.25)]:
			for mt: Material in _solids:
				_warming.append(_mi(mesh, mt))
		for node: MeshInstance3D in _warming:
			node.top_level = true
			add_child(node)
	for node: MeshInstance3D in _warming:
		node.global_position = at

func prewarm_end() -> void:
	for node: MeshInstance3D in _warming:
		node.queue_free()
	_warming.clear()

# ------------------------------------------------------------------ meshes
func _quad_mesh() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(2, 2)
	return _quad

## An open column 1 m tall, radius 1: UV.x round it, UV.y from the foot (0) to the top (1).
func _column() -> ArrayMesh:
	if _col:
		return _col
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 16
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		st.set_uv(Vector2(u0, 0))
		st.add_vertex(p0)
		st.set_uv(Vector2(u1, 0))
		st.add_vertex(p1)
		st.set_uv(Vector2(u1, 1))
		st.add_vertex(p1 + Vector3.UP)
		st.set_uv(Vector2(u0, 0))
		st.add_vertex(p0)
		st.set_uv(Vector2(u1, 1))
		st.add_vertex(p1 + Vector3.UP)
		st.set_uv(Vector2(u0, 1))
		st.add_vertex(p0 + Vector3.UP)
	_col = st.commit()
	return _col

## Two crossed strips along +Z from the head (z 0, UV.x 0) to the tail (z 1): a trail seen from above or the side.
func _ribbon_mesh() -> ArrayMesh:
	if _ribbon:
		return _ribbon
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ax in [Vector3.RIGHT, Vector3.UP]:
		var w: Vector3 = ax * 0.5
		st.set_uv(Vector2(0, 0))
		st.add_vertex(-w)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(w)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(w + Vector3(0, 0, 1))
		st.set_uv(Vector2(0, 0))
		st.add_vertex(-w)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(w + Vector3(0, 0, 1))
		st.set_uv(Vector2(1, 0))
		st.add_vertex(-w + Vector3(0, 0, 1))
	_ribbon = st.commit()
	return _ribbon

## A crescent in the XZ plane, centred on -Z (forward), `arc_deg` wide, outer radius 1, thickest mid-sweep.
func _crescent_mesh(arc_deg: float) -> ArrayMesh:
	var key := int(round(arc_deg))
	if _cres.has(key):
		return _cres[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 18
	var arc := deg_to_rad(arc_deg)
	for i in n:
		var u0 := -arc * 0.5 + arc * float(i) / n
		var u1 := -arc * 0.5 + arc * float(i + 1) / n
		var w0 := sin(PI * float(i) / n)
		var w1 := sin(PI * float(i + 1) / n)
		var o0 := Vector3(sin(u0), 0, -cos(u0))
		var o1 := Vector3(sin(u1), 0, -cos(u1))
		var a := o0
		var b := o1
		var c := o1 * lerpf(1.0, 0.5, w1)
		var d := o0 * lerpf(1.0, 0.5, w0)
		var ua := float(i) / n
		var ub := float(i + 1) / n
		st.set_uv(Vector2(ua, 0))
		st.add_vertex(a)
		st.set_uv(Vector2(ub, 0))
		st.add_vertex(b)
		st.set_uv(Vector2(ub, 1))
		st.add_vertex(c)
		st.set_uv(Vector2(ua, 0))
		st.add_vertex(a)
		st.set_uv(Vector2(ub, 1))
		st.add_vertex(c)
		st.set_uv(Vector2(ua, 1))
		st.add_vertex(d)
	var mesh := st.commit()
	_cres[key] = mesh
	return mesh

## A flat star with `pts` points (a chakram seen from above), radius 1, in the XZ plane.
static func star_mesh(pts: int, inner: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts * 2
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var r0 := 1.0 if i % 2 == 0 else inner
		var r1 := 1.0 if (i + 1) % 2 == 0 else inner
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a0) * r0, 0, sin(a0) * r0))
		st.add_vertex(Vector3(cos(a1) * r1, 0, sin(a1) * r1))
	return st.commit()

# ------------------------------------------------------------------ one-shot effects
func _fx(kind: String, mode: int, mesh: Mesh, bb: bool) -> MeshInstance3D:
	return _take(kind, func(): return _mi(mesh, _mat(mode, Color.WHITE, Color.WHITE, bb))) as MeshInstance3D

func _play(n: MeshInstance3D, kind: String, col: Color, col2: Color, dur: float, s0: Vector3) -> void:
	var mt := n.material_override as ShaderMaterial
	mt.set_shader_parameter("color", col)
	mt.set_shader_parameter("color2", col2)
	mt.set_shader_parameter("life", 0.0)
	mt.set_shader_parameter("progress", 0.0)
	mt.set_shader_parameter("seed", randf() * TAU)
	n.scale = s0
	live.append({"node": n, "t": 0.0, "dur": maxf(0.05, dur), "kind": kind, "s0": s0, "mat": mt})

## A camera-facing four-point star (Sable's knock, a tip hit, the bolt's impact).
func star(at: Vector3, col: Color, sz := 1.0, dur := 0.35, core := Color.WHITE) -> void:
	var n := _fx("star", M_STAR, _quad_mesh(), true)
	n.global_position = at
	_play(n, "star", col, core, dur, Vector3.ONE * sz)

## A streak lying along the ground behind `at` (pointing back from `dir`): a dash's own after-image (Sable's
## cyan, Kael's orange flame). Hot `col2` at the head, `col` down the tail; it fades over `dur`.
func streak(at: Vector3, dir: Vector2, length: float, width: float, col: Color, col2: Color, dur := 0.25) -> void:
	var n := _fx("streak", M_COMET, _ribbon_mesh(), false)
	n.global_position = at
	var back := Vector3(-dir.x, 0, -dir.y)
	if back.length() < 0.01: back = Vector3.BACK
	n.basis = Basis.looking_at(-back.normalized(), Vector3.UP)
	_play(n, "streak", col, col2, dur, Vector3(width, width, length))

## A streak from `a` to `b` in space, hot at `b` and fading over `dur`: a trail laid in short pieces follows any path
## (Sable's flip, whose hands and feet turn through the air).
func seg(a: Vector3, b: Vector3, width: float, col: Color, col2: Color, dur := 0.25) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var n := _fx("seg", M_COMET, _ribbon_mesh(), false)
	n.global_position = b
	n.basis = Basis.looking_at(d.normalized(), Vector3.RIGHT if absf(d.normalized().y) > 0.95 else Vector3.UP)
	_play(n, "seg", col, col2, dur, Vector3(width, width, d.length()))

## A soft ring that opens and fades where a bolt ran out (at the cursor).
func puff(at: Vector3, col: Color, sz := 0.6, dur := 0.3, speck := Color.WHITE) -> void:
	var n := _fx("puff", M_PUFF, _quad_mesh(), true)
	n.global_position = at
	_play(n, "puff", col, speck, dur, Vector3.ONE * sz)

## A column of light rising on someone (the knock heal).
func pillar(at: Vector3, col: Color, height := 3.2, radius := 0.55, dur := 0.7) -> void:
	var n := _fx("pillar", M_PILLAR, _column(), false)
	n.global_position = at
	_play(n, "pillar", col, Color(1, 1, 1, 1), dur, Vector3(radius, height, radius))

## A two-tone blade arc in front of `at` facing `dir` (outer edge `col`, inner fill `col2`), swept over
## `dur`. `tilt` turns it about the facing (PI/2: a vertical arc, the Cartwheel's swoosh).
func crescent(at: Vector3, dir: Vector2, arc_deg: float, reach: float, col: Color, col2: Color, dur := 0.22,
		tilt := 0.0, sweep := 1.6) -> void:
	var key := "cres%d" % int(round(arc_deg))
	var n := _take(key, func(): return _mi(_crescent_mesh(arc_deg), _mat(M_CRESCENT, col, col2))) as MeshInstance3D
	n.global_position = at
	var d3 := Vector3(dir.x, 0, dir.y)
	if d3.length() < 0.01: d3 = Vector3.FORWARD
	n.basis = Basis.looking_at(d3.normalized(), Vector3.UP) * Basis(Vector3.FORWARD, tilt)
	_play(n, key, col, col2, dur, Vector3.ONE * reach)
	live[-1]["sweep"] = sweep

## A chain of afterimages from `from` to `to` (Sable's step to the dagger): `count` copies, the
## nearest to the start fading first.
func ghosts(from: Vector3, to: Vector3, count: int, yaw: float, col: Color, scl := 1.0) -> void:
	for i in count:
		var k := float(i + 1) / float(count + 1)
		var build := func(): return _mi(Models.capsule(0.3, 1.25), solid(Color(col, 0.75)))
		var n := _take("ghost", build) as MeshInstance3D
		(n.material_override as StandardMaterial3D).albedo_color = Color(col, 0.75)
		n.global_position = from.lerp(to, k) + Vector3(0, 0.7 * scl, 0)
		n.rotation = Vector3(0, yaw, 0)
		n.scale = Vector3(1.0, 1.0, 1.25) * scl
		live.append({"node": n, "t": -0.04 * i, "dur": 0.32 + 0.05 * i, "kind": "ghost", "s0": n.scale,
				"mat": n.material_override, "col": col})

# ------------------------------------------------------------------ projectile looks
## The look of each projectile (built once per pooled node): a head that spins and a trail behind.
func _build_rider(kind: String, col: Color, col2: Color) -> Node3D:
	var n := Node3D.new()
	var head := Node3D.new()
	head.name = "Head"
	n.add_child(head)
	match kind:
		"chakram":
			# Sable's bolt: a flared four-point gold chakram about 0.45 m across with a hot centre; the
			# orange flame tail is the trail (col: the tail, col2: the head)
			head.add_child(_mi(star_mesh(4, 0.42), solid(col2)))
			head.add_child(_mi(star_mesh(4, 0.3), solid(col2.lightened(0.45))))
			var c := _mi(Models.sphere(0.3, 8), Models.glow_mat(Color(col2, 0.9)))
			head.add_child(c)
			head.scale = Vector3.ONE * 0.24
			_add_core(n, col2)
		"chakram_big":
			# the empowered shot: a big blue chakram inside a crackling gold streak
			head.add_child(_mi(star_mesh(6, 0.45), solid(col2)))
			head.add_child(_mi(Models.sphere(0.35, 8), Models.glow_mat(Color(col, 1.0))))
			head.scale = Vector3.ONE * 0.6
			var bolt := _mi(_ribbon_mesh(), _mat(M_BOLT, col, Color(1, 0.95, 0.6, 1), false, true))
			bolt.name = "Bolt"
			n.add_child(bolt)
		"bola":
			# the Bola: two glowing weights on a short crackling cord, whirling
			for sx in [-1.0, 1.0]:
				var w := _mi(Models.sphere(0.16, 8), solid(col))
				w.position = Vector3(sx * 0.42, 0, 0)
				head.add_child(w)
				var g := _mi(Models.sphere(0.08, 6), Models.glow_mat(Color(col2, 1.0)))
				g.position = Vector3(sx * 0.42, 0.0, 0)
				head.add_child(g)
			var cord := _mi(Models.box(0.84, 0.04, 0.04), solid(col2))
			head.add_child(cord)
		"dagger":
			# the Phantom Dagger: a long dark blade with a violet edge, point first
			var bl := _mi(Models.box(0.09, 0.04, 0.66), solid(Color("2a1f3a")))
			bl.position.z = -0.12
			head.add_child(bl)
			var ed := _mi(Models.box(0.03, 0.05, 0.62), solid(col))
			ed.position = Vector3(0.04, 0, -0.12)
			head.add_child(ed)
			var gd := _mi(Models.box(0.22, 0.06, 0.06), solid(col2))
			gd.position.z = 0.2
			head.add_child(gd)
		"blade":
			# an Encore blade: a small spinning star in its two colours
			head.add_child(_mi(star_mesh(3, 0.3), solid(col)))
			head.add_child(_mi(Models.sphere(0.25, 6), solid(col2)))
			head.scale = Vector3.ONE * 0.4
			_add_core(n, col2)
		"crescent_bolt":
			# Kael's Searing Wave: a flat 140-degree crescent of flame (1.4 m chord), red with an orange
			# inner edge, pushed bulge first; a red glow trail behind it
			var cr := _mi(_crescent_mesh(140.0), _mat(M_CRESCENT, col, col2))
			cr.name = "Cres"
			(cr.material_override as ShaderMaterial).set_shader_parameter("progress", 1.0)
			cr.position.z = 0.6
			cr.scale = Vector3.ONE * 0.75
			head.add_child(cr)
			var glow := _mi(_crescent_mesh(140.0), _mat(M_CRESCENT, col, col, false, true))
			(glow.material_override as ShaderMaterial).set_shader_parameter("progress", 1.0)
			glow.position = Vector3(0, -0.02, 0.62)
			glow.scale = Vector3.ONE * 0.86
			head.add_child(glow)
		"hook":
			# the Warchain's head: a barbed iron hook, its barbs glowing orange
			head.add_child(_mi(Models.box(0.14, 0.14, 0.46), solid(Color("3a2a22"))))
			for sx in [-1.0, 1.0]:
				var b := _mi(Models.box(0.08, 0.08, 0.32), solid(col))
				b.position = Vector3(sx * 0.13, 0, -0.2)
				b.rotation.y = sx * 0.75
				head.add_child(b)
	var tr := _mi(_ribbon_mesh(), _mat(M_COMET, col, col2))
	tr.name = "Trail"
	n.add_child(tr)
	return n

## A thin hot line down the middle of a streak (a bolt's or blade's bright core).
func _add_core(rider: Node3D, hot: Color) -> void:
	var core := _mi(_ribbon_mesh(), _mat(M_COMET, hot.lightened(0.6), Color.WHITE, false, true))
	core.name = "Core"
	rider.add_child(core)

func _rider(kind: String, col: Color, col2: Color) -> Node3D:
	var n := _take("ride_" + kind, func(): return _build_rider(kind, col, col2))
	var tr := n.get_node_or_null("Trail") as MeshInstance3D
	if tr:
		(tr.material_override as ShaderMaterial).set_shader_parameter("color", col)
		(tr.material_override as ShaderMaterial).set_shader_parameter("color2", col2)
		(tr.material_override as ShaderMaterial).set_shader_parameter("life", 0.0)
	return n

## Rides a look on a shot (match.gd's shot dictionary) until it ends; `on_end(at)` runs when it does.
## trail: the streak's length in m, width: its width.
func ride(sd: Dictionary, kind: String, col: Color, col2: Color, trail := 1.2, width := 0.3,
		on_end := Callable()) -> void:
	var n := _rider(kind, col, col2)
	# this look replaces the shared shot mesh (a pale streak or blob that would show through it)
	if sd.get("node") != null and is_instance_valid(sd["node"]):
		(sd["node"] as Node3D).visible = false
	riders.append({"node": n, "sd": sd, "kind": kind, "spin": randf() * TAU, "trail": trail, "width": width,
			"on_end": on_end, "last": sd["pos"]})
	_pose(n, kind, sd["pos"], sd["vel"], trail, width, 0.0)

## Shows a projectile look this step (a kit-run projectile: the Bola flying on). Stop calling and it hides.
func place(id: String, kind: String, at: Vector3, vel: Vector2, col: Color, col2: Color, trail := 1.0,
		width := 0.3) -> void:
	var e: Dictionary = placed.get(id, {})
	if (e.is_empty() or not is_instance_valid(e["node"]) or String(e["kind"]) != kind
			or not (e["node"] as Node3D).visible):
		e = {"node": _rider(kind, col, col2), "kind": kind, "spin": 0.0}
		placed[id] = e
	e["t"] = m.time
	e["spin"] = float(e["spin"]) + 0.3
	_pose(e["node"], kind, at, vel, trail, width, float(e["spin"]))

func unplace(id: String) -> void:
	var e: Dictionary = placed.get(id, {})
	if not e.is_empty() and is_instance_valid(e["node"]):
		(e["node"] as Node3D).visible = false
	placed.erase(id)

func _pose(n: Node3D, kind: String, at: Vector3, vel: Vector2, trail: float, width: float, spin: float) -> void:
	n.global_position = at
	var d3 := Vector3(vel.x, 0, vel.y)
	if d3.length() > 0.05:
		n.basis = Basis.looking_at(d3.normalized(), Vector3.UP)
	var head := n.get_node_or_null("Head") as Node3D
	if head:
		match kind:
			"chakram", "chakram_big", "blade", "bola": head.rotation.y = spin * (2.0 if kind == "bola" else 3.0)
			"dagger": head.rotation.z = sin(spin) * 0.15
	var tr := n.get_node_or_null("Trail") as Node3D
	if tr: tr.scale = Vector3(width, width, trail)
	var core := n.get_node_or_null("Core") as Node3D
	if core: core.scale = Vector3(width * CORE_W, width * CORE_W, trail * 0.8)
	var bolt := n.get_node_or_null("Bolt") as Node3D
	if bolt: bolt.scale = Vector3(width * 1.6, width * 1.6, trail * 1.4)

# ------------------------------------------------------------------ chains (immediate style)
## Draws a chain from a to b this step. wavy 0..1: 0 = a straight striped link chain, 1 = a loose
## zig-zag in flight. `bow`: how far its middle bends out. Stop calling and it goes.
func chain(id: String, a: Vector3, b: Vector3, wavy: float, col: Color, col2: Color, width := 0.12,
		bow := Vector3.ZERO) -> void:
	var e: Dictionary = chains.get(id, {})
	if e.is_empty() or not is_instance_valid(e["node"]):
		var im := ImmediateMesh.new()
		var mi := _mi(im, _mat(M_LINKS, col, col2))
		mi.top_level = true
		add_child(mi)
		made += 1
		e = {"node": mi, "mesh": im}
		chains[id] = e
	e["t"] = m.time
	var mi2: MeshInstance3D = e["node"]
	mi2.visible = true
	mi2.global_transform = Transform3D.IDENTITY
	var mt := mi2.material_override as ShaderMaterial
	mt.set_shader_parameter("color", col)
	mt.set_shader_parameter("color2", col2)
	var length := a.distance_to(b)
	mt.set_shader_parameter("stripes", 1.0)
	if wavy > 0.5:
		mt.set_shader_parameter("color2", col)      # in flight: one orange ribbon, no links yet
	var im2: ImmediateMesh = e["mesh"]
	im2.clear_surfaces()
	if length < 0.05:
		return
	var fwd := (b - a) / length
	var side := fwd.cross(Vector3.UP)
	if side.length() < 0.01: side = Vector3.RIGHT
	side = side.normalized()
	var n := maxi(8, int(length / 0.08))
	var links := length / 0.2        # a bright and a dark link every 20 cm
	im2.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n + 1:
		var k := float(i) / n
		var p := a.lerp(b, k)
		# in flight: a zig-zag of about four waves over its length, still at both ends
		var wv := sin(k * TAU * 4.0 + m.time * 14.0) * 0.28 * wavy * sin(k * PI)
		p += side * wv + bow * sin(k * PI)
		# flat to the camera above, with a little height so it reads side on too
		var across := side * width * 0.5 + Vector3.UP * width * 0.12
		im2.surface_set_uv(Vector2(k * links, 0))
		im2.surface_add_vertex(p - across)
		im2.surface_set_uv(Vector2(k * links, 1))
		im2.surface_add_vertex(p + across)
	im2.surface_end()

## A thin flat line through `pts` this step (a predicted path). Stop calling and it goes.
func path_line(id: String, pts: PackedVector3Array, col: Color, width: float) -> void:
	var e: Dictionary = chains.get(id, {})
	if e.is_empty() or not is_instance_valid(e["node"]):
		var im := ImmediateMesh.new()
		var mi := _mi(im, solid(col))
		mi.top_level = true
		add_child(mi)
		made += 1
		e = {"node": mi, "mesh": im}
		chains[id] = e
	e["t"] = m.time
	(e["node"] as Node3D).visible = true
	var mesh: ImmediateMesh = e["mesh"]
	mesh.clear_surfaces()
	if pts.size() < 2:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var fwd := pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]
		var across := fwd.cross(Vector3.UP).normalized() * width * 0.5
		mesh.surface_add_vertex(pts[i] - across)
		mesh.surface_add_vertex(pts[i] + across)
	mesh.surface_end()

func unchain(id: String) -> void:
	var e: Dictionary = chains.get(id, {})
	if not e.is_empty() and is_instance_valid(e["node"]):
		(e["node"] as Node3D).visible = false

# ------------------------------------------------------------------ per frame
## Is this shot still flying (the same dictionary, not just an equal one)?
func _alive(sd: Dictionary) -> bool:
	for s in m.shots:
		if is_same(s, sd): return true
	return false

func _process(delta: float) -> void:
	for e in live.duplicate():
		var n: Node3D = e["node"]
		if not is_instance_valid(n):
			live.erase(e)
			continue
		e["t"] = float(e["t"]) + delta
		var u := clampf(float(e["t"]) / float(e["dur"]), 0.0, 1.0)
		var mt = e["mat"]
		if float(e["t"]) < 0.0:
			n.visible = false
			continue
		n.visible = true
		match String(e["kind"]):
			"ghost":
				(n as MeshInstance3D).material_override.albedo_color = Color(e["col"], 0.75 * (1.0 - u * u))
			"pillar":
				mt.set_shader_parameter("life", u)
			_:
				mt.set_shader_parameter("life", u)
				if e.has("sweep"): mt.set_shader_parameter("progress", minf(1.0, u * float(e["sweep"])))
				elif String(e["kind"]) == "star": n.scale = (e["s0"] as Vector3) * (0.6 + 0.6 * sqrt(u))
		if u >= 1.0:
			n.visible = false
			live.erase(e)
	for r in riders.duplicate():
		var n: Node3D = r["node"]
		var sd: Dictionary = r["sd"]
		var gone: bool = sd.get("dj_end", false) or not _alive(sd)
		if gone or not is_instance_valid(n):
			if is_instance_valid(n): n.visible = false
			riders.erase(r)
			if (r["on_end"] as Callable).is_valid(): (r["on_end"] as Callable).call(r["last"])
			continue
		r["spin"] = float(r["spin"]) + delta * 9.0
		r["last"] = sd["pos"]
		_pose(n, String(r["kind"]), sd["pos"], sd["vel"], float(r["trail"]), float(r["width"]), float(r["spin"]))
	for id in placed.keys():
		var e: Dictionary = placed[id]
		if m.time - float(e.get("t", 0.0)) > KEEP:
			if is_instance_valid(e["node"]): (e["node"] as Node3D).visible = false
			placed.erase(id)
	for id in chains.keys():
		var e: Dictionary = chains[id]
		if m.time - float(e.get("t", 0.0)) > KEEP and is_instance_valid(e["node"]):
			(e["node"] as Node3D).visible = false
