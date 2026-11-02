class_name VVFx
extends Node3D
## Vireo's and Venator's own effects, pooled (one node per match, VVFx.of(m)). Every node is made once
## and reused; nothing is created per frame or per shot. One shader, shaders/vv_fx.gdshader, a mode per
## look. Kinds:
##   arc      a jagged lightning ribbon between two points (Vireo's bolts, the Surge streak, orb zaps)
##   ride     a look riding on a match shot until it ends, then its impact (the finger-gun bolt, the rifle round)
##   pillar   a column of light that narrows over its life (the drag disc's countdown, the refund column)
##   ring     an expanding ring with spark needles (arrivals, shock rings, the slide's start ring)
##   disc     a dark disc with a crackling rim (the strike's scorch)
##   star     a camera-facing 4-point crackle (fingertip, muzzle)
##   fan      a flat blast sector (the grenade's cone)
##   swirl    spinning comma arcs riding on a target (Dazed)
##   shackle  crackling rings spinning round a target (Grounded by the drag)
##   ghost    a fading glow silhouette (the slide's afterimage, the Surge silhouette)
##   marker   immediate style: Vireo's Static marker over a head (pips, a count, sparks that grow)

const SHADER: Shader = preload("res://shaders/vv_fx.gdshader")
const M_ARC := 0
const M_PILLAR := 1
const M_RING := 2
const M_DISC := 3
const M_STAR := 4
const M_TRACER := 5
const M_FAN := 6
const M_SWIRL := 7
const POOL_CAP := 28           # nodes per kind at most; past it the oldest is taken back
const KEEP := 0.12             # s a marker stays without a refresh

var m: Node
var pools := {}                # kind -> Array of nodes made for it
var live: Array = []           # one-shot effects: {node, t, dur, kind, s0, follow, spin}
var riders: Array = []         # looks riding on a shot: {node, sd, kind, len, width, on_end, last, vel}
var markers := {}              # id -> {node, t, n}
var made := 0                  # nodes made so far (tests: it stops growing once warm)
var _ribbon: ArrayMesh
var _col: ArrayMesh
var _quad: PlaneMesh
var _fans := {}

static func of(match_node: Node) -> VVFx:
	if match_node.has_meta("vv_fx"):
		var f = match_node.get_meta("vv_fx")
		if is_instance_valid(f):
			return f
	var n := VVFx.new()
	n.m = match_node
	n.name = "VVFx"
	match_node.add_child(n)
	match_node.set_meta("vv_fx", n)
	return n

# ------------------------------------------------------------------ pool
func _mat(mode: int, bb := false) -> ShaderMaterial:
	var mt := ShaderMaterial.new()
	mt.shader = SHADER
	mt.set_shader_parameter("mode", mode)
	mt.set_shader_parameter("billboard", bb)
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
	return old

func _set(n: Node3D, col: Color, col2: Color, life := 0.0) -> ShaderMaterial:
	var mt := (n as MeshInstance3D).material_override as ShaderMaterial
	mt.set_shader_parameter("color", col)
	mt.set_shader_parameter("color2", col2)
	mt.set_shader_parameter("life", life)
	mt.set_shader_parameter("seed", randf() * 10.0)
	mt.set_shader_parameter("strength", 1.0)
	return mt

func _play(n: Node3D, kind: String, dur: float, extra := {}) -> void:
	var e := {"node": n, "t": 0.0, "dur": maxf(0.02, dur), "kind": kind, "s0": n.scale}
	e.merge(extra, true)
	live.append(e)

# ------------------------------------------------------------------ meshes
## Two crossed strips along +Z from the head (z 0, UV.x 0) to the tail (z 1), width 1: reads from above and the side.
func _ribbon_mesh() -> ArrayMesh:
	if _ribbon: return _ribbon
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

## An open column 1 m tall, radius 1: UV.x round it, UV.y foot to top.
func _column() -> ArrayMesh:
	if _col: return _col
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 18
	for i in n:
		var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0), 0, sin(a0)); var p1 := Vector3(cos(a1), 0, sin(a1))
		var u0 := float(i) / n; var u1 := float(i + 1) / n
		st.set_uv(Vector2(u0, 0)); st.add_vertex(p0)
		st.set_uv(Vector2(u1, 0)); st.add_vertex(p1)
		st.set_uv(Vector2(u1, 1)); st.add_vertex(p1 + Vector3.UP)
		st.set_uv(Vector2(u0, 0)); st.add_vertex(p0)
		st.set_uv(Vector2(u1, 1)); st.add_vertex(p1 + Vector3.UP)
		st.set_uv(Vector2(u0, 1)); st.add_vertex(p0 + Vector3.UP)
	_col = st.commit()
	return _col

func _quad_mesh() -> PlaneMesh:
	if _quad == null:
		_quad = PlaneMesh.new(); _quad.size = Vector2(2, 2)
	return _quad

## A flat sector in XZ along -Z, `deg` wide, radius 1: UV.x across, UV.y apex (0) to rim (1).
func _fan_mesh(deg: float) -> ArrayMesh:
	var key := int(round(deg))
	if _fans.has(key): return _fans[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 16
	var arc := deg_to_rad(deg)
	for i in n:
		var u0 := float(i) / n; var u1 := float(i + 1) / n
		var a0 := -arc * 0.5 + arc * u0; var a1 := -arc * 0.5 + arc * u1
		st.set_uv(Vector2(0.5, 0)); st.add_vertex(Vector3.ZERO)
		st.set_uv(Vector2(u0, 1)); st.add_vertex(Vector3(sin(a0), 0, -cos(a0)))
		st.set_uv(Vector2(u1, 1)); st.add_vertex(Vector3(sin(a1), 0, -cos(a1)))
	var mesh := st.commit()
	_fans[key] = mesh
	return mesh

## Lays a ribbon node from a to b, `width` wide.
static func _lay(n: Node3D, a: Vector3, b: Vector3, width: float) -> void:
	var v := b - a
	var ln := v.length()
	if ln < 0.01:
		n.visible = false
		return
	var z := v / ln
	var up := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	n.global_transform = Transform3D(Basis(x * width, y * width, z * ln), a)

# ------------------------------------------------------------------ one-shots
## A jagged lightning ribbon from a to b (re-strikes on its own), gone over `dur`.
func arc(a: Vector3, b: Vector3, col: Color, col2 := Color.WHITE, width := 0.5, dur := 0.16) -> void:
	var n := _take("arc", func(): return _mi(_ribbon_mesh(), _mat(M_ARC)))
	_set(n, col, col2)
	_lay(n, a, b, width)
	_play(n, "arc", dur)

## A column of light at `at`, `height` tall, narrowing from `radius` to a thread over `dur` (a countdown).
func pillar(at: Vector3, col: Color, col2: Color, height := 6.0, radius := 0.9, dur := 0.8, narrow := true) -> void:
	var n := _take("pillar", func(): return _mi(_column(), _mat(M_PILLAR)))
	_set(n, col, col2)
	n.global_position = at
	n.scale = Vector3(radius, height, radius)
	_play(n, "pillar", dur, {"narrow": narrow})

## An expanding ring with spark needles, flat on the ground at `at`, out to radius `r`.
func ring(at: Vector3, r: float, col: Color, col2 := Color.WHITE, dur := 0.35) -> void:
	var n := _take("ring", func(): return _mi(_quad_mesh(), _mat(M_RING)))
	_set(n, col, col2)
	n.global_position = at + Vector3(0, 0.09, 0)
	n.scale = Vector3(r, 1.0, r)
	_play(n, "ring", dur)

## A dark disc with a crackling rim on the ground (the scorch, a placed area), radius r.
func disc(at: Vector3, r: float, col: Color, col2: Color, dur := 0.5) -> void:
	var n := _take("disc", func(): return _mi(_quad_mesh(), _mat(M_DISC)))
	_set(n, col, col2)
	n.global_position = at + Vector3(0, 0.08, 0)
	n.scale = Vector3(r, 1.0, r)
	_play(n, "disc", dur)

## A camera-facing 4-point crackle.
func star(at: Vector3, col: Color, col2 := Color.WHITE, size := 0.4, dur := 0.12) -> void:
	var n := _take("star", func(): return _mi(_quad_mesh(), _mat(M_STAR, true)))
	_set(n, col, col2)
	n.global_position = at
	n.scale = Vector3.ONE * size
	n.rotation = Vector3(PI * 0.5, 0, 0)
	_play(n, "star", dur)

## A flat blast sector from `at` along `dir`, `len` long and `deg` wide; the front runs out over `dur`.
func fan(at: Vector3, dir: Vector2, length: float, deg: float, col: Color, col2: Color, dur := 0.3) -> void:
	var n := _take("fan%d" % int(round(deg)), func(): return _mi(_fan_mesh(deg), _mat(M_FAN)))
	_set(n, col, col2)
	n.global_position = at + Vector3(0, 0.12, 0)
	n.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
	n.scale = Vector3(length, 1.0, length)
	_play(n, "fan", dur)

## Spinning comma arcs on the ground round a target, for `dur` (Dazed).
func swirl(target: Ent, col: Color, col2: Color, dur := 1.2, r := 0.9) -> void:
	var n := _take("swirl", func(): return _mi(_quad_mesh(), _mat(M_SWIRL)))
	_set(n, col, col2)
	n.scale = Vector3(r, 1.0, r)
	n.global_position = target.position + Vector3(0, 0.12, 0)
	_play(n, "swirl", dur, {"follow": target, "oy": 0.12})

## Crackling rings spinning round a target's body for `dur` (shackles).
func shackle(target: Ent, col: Color, col2: Color, dur := 1.5) -> void:
	for i in 2:
		var n := _take("shackle", func():
			var tm := TorusMesh.new(); tm.inner_radius = 0.92; tm.outer_radius = 1.0; tm.rings = 28; tm.ring_segments = 6
			return _mi(tm, _mat(M_ARC)))
		_set(n, col, col2)
		n.scale = Vector3.ONE * 0.62
		_play(n, "shackle", dur, {"follow": target, "oy": 0.55 + 0.5 * i, "spin": 6.0 if i == 0 else -7.5, "tilt": 0.35 if i == 0 else -0.3})

## A fading glow silhouette standing at `at` (an afterimage), facing yaw.
func ghost(at: Vector3, yaw: float, col: Color, scl := 1.0, dur := 0.4) -> void:
	var n := _take("ghost", func():
		var g := Node3D.new()
		var cap := CapsuleMesh.new(); cap.radius = 0.28; cap.height = 1.2
		Models.part(g, cap, Models.glow_mat(Color.WHITE), Vector3(0, 0.75, 0), Vector3(1.0, 1.0, 0.7))
		Models.part(g, Models.sphere(0.2, 10), Models.glow_mat(Color.WHITE), Vector3(0, 1.55, 0))
		for ch in g.get_children(): (ch as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return g)
	for ch in n.get_children():
		((ch as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("color", Color(col, 0.6))
	n.global_position = at
	n.rotation = Vector3(0, yaw, 0)
	n.scale = Vector3.ONE * scl
	_play(n, "ghost", dur, {"col": col})

# ------------------------------------------------------------------ riders
## A look riding on a match shot (the dictionary in m.shots) until it ends; then on_end(at, hit) runs.
## kind: "bolt" (a jagged arc ribbon), "tracer" (a hot needle and a cooling tail).
func ride(sd: Dictionary, kind: String, col: Color, col2: Color, length := 1.2, width := 0.3, on_end := Callable()) -> void:
	var n: Node3D
	if kind == "tracer":
		n = _take("tracer", func(): return _mi(_ribbon_mesh(), _mat(M_TRACER)))
	else:
		n = _take("arc", func(): return _mi(_ribbon_mesh(), _mat(M_ARC)))
	_set(n, col, col2)
	var mi := sd.get("node") as Node3D
	if mi != null and is_instance_valid(mi):
		mi.visible = false            # the stock orb goes: this look is the round
	riders.append({"node": n, "sd": sd, "kind": kind, "len": length, "width": width, "on_end": on_end, "last": sd["pos"], "vel": sd["vel"]})

func _alive(sd: Dictionary) -> bool:
	for s in m.get("shots"):
		if s == sd: return true
	return false

# ------------------------------------------------------------------ marker (immediate style)
## Vireo's Static marker over `target`: `max_n` pips on a ring (n lit), the count, and sparks on the
## body that grow with n. Call every step while it should show; it goes KEEP s after the last call.
func marker(id: String, target: Ent, n: int, max_n: int, col: Color, col2: Color, top: float) -> void:
	var e: Dictionary = markers.get(id, {})
	if e.is_empty() or not is_instance_valid(e.get("node")):
		var node := _take("marker", _build_marker.bind(max_n))
		e = {"node": node, "n": -1}
		markers[id] = e
	e["t"] = 0.0
	var nd: Node3D = e["node"]
	nd.visible = target.visible
	nd.global_position = target.position + Vector3(0, top, 0)
	var full := n >= max_n
	var tm := float(Time.get_ticks_msec()) / 1000.0
	var pips: Node3D = nd.get_node("Pips")
	pips.rotation.y = tm * (6.0 if full else 1.6)
	for i in pips.get_child_count():
		var p := pips.get_child(i) as MeshInstance3D
		p.visible = i < n
		p.scale = Vector3.ONE * ((1.45 + 0.2 * sin(tm * 14.0 + i)) if full else 1.0)
		(p.material_override as ShaderMaterial).set_shader_parameter("color", col2 if full else col)
	var lbl: Label3D = nd.get_node("Count")
	lbl.text = "%d" % n
	lbl.modulate = col2 if full else col
	lbl.scale = Vector3.ONE * (1.35 if full else 1.0)
	var sp: CPUParticles3D = nd.get_node("Sparks")
	if int(e["n"]) != n:
		e["n"] = n
		sp.amount = 3 + 5 * n
		sp.initial_velocity_max = 1.4 + 0.9 * n
		sp.scale_amount_max = 0.6 + 0.35 * n
		sp.color = col2 if full else col
		sp.emitting = n > 0
	sp.global_position = target.position + Vector3(0, 1.0, 0)
	sp.emission_sphere_radius = 0.25 + 0.08 * n

func unmark(id: String) -> void:
	var e: Dictionary = markers.get(id, {})
	if not e.is_empty() and is_instance_valid(e.get("node")):
		(e["node"] as Node3D).visible = false
		((e["node"] as Node3D).get_node("Sparks") as CPUParticles3D).emitting = false
	markers.erase(id)

func _build_marker(max_n: int) -> Node3D:
	var nd := Node3D.new()
	var pips := Node3D.new(); pips.name = "Pips"; nd.add_child(pips)
	for i in max_n:
		var a := TAU * i / float(max_n)
		var p := Models.part(pips, Models.crystal(0.07, 0.13, 4), Models.glow_mat(Color.WHITE), Vector3(cos(a) * 0.4, 0, sin(a) * 0.4))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := Label3D.new(); l.name = "Count"
	l.font_size = 40; l.pixel_size = 0.01; l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true
	l.position = Vector3(0, 0.28, 0)
	nd.add_child(l)
	var sp := CPUParticles3D.new(); sp.name = "Sparks"
	sp.top_level = true
	sp.amount = 8; sp.lifetime = 0.35; sp.explosiveness = 0.0
	var qm := QuadMesh.new(); qm.size = Vector2(0.07, 0.07)
	sp.mesh = qm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sp.material_override = sm
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.3
	sp.direction = Vector3.UP; sp.spread = 180.0
	sp.gravity = Vector3.ZERO
	sp.initial_velocity_min = 0.6; sp.initial_velocity_max = 2.0
	sp.scale_amount_min = 0.5; sp.scale_amount_max = 1.0
	sp.local_coords = false
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nd.add_child(sp)
	return nd

# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	for e in live.duplicate():
		e["t"] = float(e["t"]) + delta
		var n: Node3D = e["node"]
		var u := clampf(float(e["t"]) / float(e["dur"]), 0.0, 1.0)
		if not is_instance_valid(n) or u >= 1.0:
			if is_instance_valid(n): n.visible = false
			live.erase(e)
			continue
		var kind := String(e["kind"])
		if kind == "ghost":
			for ch in n.get_children():
				((ch as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("color", Color(e["col"], 0.6 * (1.0 - u)))
			n.scale = (e["s0"] as Vector3) * (1.0 + 0.15 * u)
			continue
		var mt := (n as MeshInstance3D).material_override as ShaderMaterial
		mt.set_shader_parameter("life", u)
		match kind:
			"pillar":
				if bool(e.get("narrow", true)):
					var s0: Vector3 = e["s0"]
					n.scale = Vector3(s0.x * (1.0 - 0.85 * u), s0.y, s0.z * (1.0 - 0.85 * u))
			"arc":
				mt.set_shader_parameter("strength", 1.0 - u * u)
			"swirl", "shackle":
				var f = e.get("follow")
				if f == null or not is_instance_valid(f) or (f as Ent).dead:
					n.visible = false
					live.erase(e)
					continue
				n.global_position = (f as Ent).position + Vector3(0, float(e.get("oy", 0.1)), 0)
				if kind == "shackle":
					n.rotation = Vector3(float(e["tilt"]), float(e["t"]) * float(e["spin"]), 0)
					mt.set_shader_parameter("life", 0.0)
					mt.set_shader_parameter("strength", 1.0 - smoothstep(0.75, 1.0, u))
				else:
					mt.set_shader_parameter("strength", 1.0 - smoothstep(0.8, 1.0, u))
	for r in riders.duplicate():
		var n: Node3D = r["node"]
		var sd: Dictionary = r["sd"]
		if not is_instance_valid(n):
			riders.erase(r)
			continue
		if _alive(sd):
			var p: Vector3 = sd["pos"]
			var v: Vector2 = sd["vel"]
			r["last"] = p
			r["vel"] = v
			var back := Vector3(-v.x, 0, -v.y).normalized() if v.length() > 0.1 else Vector3.BACK
			var travelled := p.distance_to(sd.get("start", p))
			var L := minf(float(r["len"]), travelled + 0.2)
			_lay(n, p, p + back * L, float(r["width"]))
			continue
		n.visible = false
		riders.erase(r)
		var cb: Callable = r["on_end"]
		if cb.is_valid():
			cb.call(r["last"] as Vector3, r["vel"] as Vector2)
	for id in markers.keys():
		var e2: Dictionary = markers[id]
		e2["t"] = float(e2["t"]) + delta
		if float(e2["t"]) > KEEP:
			unmark(id)
