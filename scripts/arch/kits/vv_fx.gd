class_name VVFx
extends Node3D
## Sparkle's and Vex's own effects, pooled (one node per match, VVFx.of(m)). Every node is made once
## and reused; nothing is created per frame or per shot. One shader, shaders/vv_fx.gdshader, a mode per
## look: each draws an alpha-blended body in the hero's colour and adds glow only on its hot core, so
## nothing washes out on bright ground. Kinds:
##   arc      a jagged lightning ribbon between two points (Sparkle's bolts, the Surge streak, orb zaps)
##   crackle  a burst of short arcs out of one point (the fingertip on every finger bolt)
##   ride     a look riding on a match shot until it ends, then its impact (the finger bolt, the rifle round)
##   smear    a fading hot-headed streak (the grenade's flight)
##   pillar   a column of light that narrows over its life (the drag disc's countdown, the refund column)
##   ring     an expanding ring with spark needles (arrivals, shock rings, the slide's start ring)
##   disc     a dark filled disc with a crackling rim and veins (Skycall's area, the slide's scrape)
##   star     a camera-facing 4-point crackle (fingertip, muzzle)
##   fan      a flat blast sector (the grenade's cone)
##   swirl    spinning comma arcs riding on a target (Dazed)
##   shackle  crackling rings spinning round a target (Grounded by the drag)
##   trail    immediate style: a swoosh following a moving point (a hand through its move)
##   echo     a fading after-image in the hunter's own pose and silhouette, flat in one colour
##   marker   immediate style: Sparkle's Static marker over a head (pips, a count, sparks that grow)

const SHADER: Shader = preload("res://shaders/vv_fx.gdshader")
const M_ARC := 0
const M_PILLAR := 1
const M_RING := 2
const M_DISC := 3
const M_STAR := 4
const M_TRACER := 5
const M_FAN := 6
const M_SWIRL := 7
const M_BEAM := 8
const POOL_CAP := 28           # nodes per kind at most; past it the oldest is taken back
const ECHO_PUSH := 0.4          # m a see-through echo sits behind the live body, along the camera ray
const ECHO_CLEAR := 1.4         # m he must be off a trailing echo before it shows fully
const ECHO_CAP := 10           # after-images per hunter at most (each copies the whole model)
const KEEP := 0.12             # s a marker or a trail stays without a refresh
const MARK_RAISE := 1.0        # m the marker rides up the screen past the HP bar
const NO_EDGE := Color(0, 0, 0, 0)

var m: Node
var pools := {}                # kind -> Array of nodes made for it
var live: Array = []           # one-shot effects: {node, t, dur, kind, s0, follow, spin}
var riders: Array = []         # looks riding on a shot: {node, sd, kind, len, width, on_end, last, vel}
var markers := {}              # id -> {node, t, n}
var trails := {}               # id -> {last, t}: hand trails being drawn
# cosmetic jitter only: never draws on the global RNG (seeded sims stay the same)
var rng := RandomNumberGenerator.new()
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

## A pooled node of a kind: a hidden one, else a new one (up to `cap`), else the oldest in use.
func _take(kind: String, build: Callable, cap := POOL_CAP) -> Node3D:
	var arr: Array = pools.get(kind, [])
	pools[kind] = arr
	for n in arr:
		if is_instance_valid(n) and not (n as Node3D).visible:
			(n as Node3D).visible = true
			return n
	if arr.size() < cap:
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

func _look(n: Node3D, col: Color, col2: Color, edge := NO_EDGE) -> ShaderMaterial:
	var mt := (n as MeshInstance3D).material_override as ShaderMaterial
	mt.set_shader_parameter("color", col)
	mt.set_shader_parameter("color2", col2)
	mt.set_shader_parameter("color3", edge)
	mt.set_shader_parameter("life", 0.0)
	mt.set_shader_parameter("seed", rng.randf() * 10.0)
	mt.set_shader_parameter("strength", 1.0)
	return mt

func _play(n: Node3D, kind: String, dur: float, extra := {}) -> void:
	var e := {"node": n, "t": 0.0, "dur": maxf(0.02, dur), "kind": kind, "s0": n.scale}
	e.merge(extra, true)
	live.append(e)

# ------------------------------------------------------------------ meshes
## Two crossed strips along +Z from the head (z 0, UV.x 0) to the tail (z 1), width 1: reads from above and the side.
func _ribbon_mesh() -> ArrayMesh:
	if _ribbon:
		return _ribbon
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ax in [Vector3.RIGHT, Vector3.UP]:
		var w: Vector3 = ax * 0.5
		var tail := Vector3(0, 0, 1)
		_tri(st, [-w, w, w + tail], [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)])
		_tri(st, [-w, w + tail, -w + tail], [Vector2(0, 0), Vector2(1, 1), Vector2(1, 0)])
	_ribbon = st.commit()
	return _ribbon

static func _tri(st: SurfaceTool, pts: Array, uvs: Array) -> void:
	for i in 3:
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])

## An open column 1 m tall, radius 1: UV.x round it, UV.y foot to top.
func _column() -> ArrayMesh:
	if _col:
		return _col
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 18
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		_tri(st, [p0, p1, p1 + Vector3.UP], [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1)])
		_tri(st, [p0, p1 + Vector3.UP, p0 + Vector3.UP], [Vector2(u0, 0), Vector2(u1, 1), Vector2(u0, 1)])
	_col = st.commit()
	return _col

func _quad_mesh() -> PlaneMesh:
	if _quad == null:
		_quad = PlaneMesh.new()
		_quad.size = Vector2(2, 2)
	return _quad

## A flat sector in XZ along -Z, `deg` wide, radius 1: UV.x across, UV.y apex (0) to rim (1).
func _fan_mesh(deg: float) -> ArrayMesh:
	var key := int(round(deg))
	if _fans.has(key):
		return _fans[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 16
	var sweep := deg_to_rad(deg)
	for i in n:
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		var a0 := -sweep * 0.5 + sweep * u0
		var a1 := -sweep * 0.5 + sweep * u1
		var rim0 := Vector3(sin(a0), 0, -cos(a0))
		var rim1 := Vector3(sin(a1), 0, -cos(a1))
		_tri(st, [Vector3.ZERO, rim0, rim1], [Vector2(0.5, 0), Vector2(u0, 1), Vector2(u1, 1)])
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
func arc(a: Vector3, b: Vector3, col: Color, col2: Color, width := 0.5, dur := 0.16) -> void:
	var n := _take("arc", func(): return _mi(_ribbon_mesh(), _mat(M_ARC)))
	_look(n, col, col2)
	_lay(n, a, b, width)
	_play(n, "arc", dur)

## `count` short arcs flung out of `at` in every direction, `reach` long: a crackle at a fingertip.
func crackle(at: Vector3, col: Color, col2: Color, reach := 0.5, count := 4, dur := 0.08) -> void:
	for i in count:
		var yaw := TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / float(count)
		var out := Vector3(cos(yaw), rng.randf_range(-0.5, 0.7), sin(yaw)).normalized()
		arc(at, at + out * reach * rng.randf_range(0.7, 1.15), col, col2, reach * 0.45, dur)

## A straight beam from a to b, `width` wide, thinning and fading over `dur`; `edge` shimmers along its sides.
func beam(a: Vector3, b: Vector3, col: Color, col2: Color, width := 0.9, dur := 0.75, edge := NO_EDGE) -> void:
	var n := _take("beam", func(): return _mi(_ribbon_mesh(), _mat(M_BEAM)))
	_look(n, col, col2, edge)
	_lay(n, a, b, width)
	_play(n, "beam", dur)

## A hot head and a cooling tail laid from a back to b, fading over `dur` (a thrown thing's smear).
func smear(a: Vector3, b: Vector3, col: Color, col2: Color, width := 0.3, dur := 0.18) -> void:
	var n := _take("smear", func(): return _mi(_ribbon_mesh(), _mat(M_TRACER)))
	_look(n, col, col2)
	_lay(n, b, a, width)
	_play(n, "smear", dur)

## Immediate style: call every step with where the point is now; a fading smear joins it to where
## it was last step, so a hand sweeping through a move leaves a swoosh in the hero's colour.
func trail(id: String, at: Vector3, col: Color, col2: Color, width := 0.22, dur := 0.2) -> void:
	var e: Dictionary = trails.get(id, {})
	if not e.is_empty() and (e["last"] as Vector3).distance_to(at) > 0.02:
		smear(e["last"], at, col, col2, width, dur)
	trails[id] = {"last": at, "t": 0.0}

## A column of light at `at`, `height` tall, narrowing from `radius` to a thread over `dur` (a countdown).
func pillar(at: Vector3, col: Color, col2: Color, height := 6.0, radius := 0.9, dur := 0.8, narrow := true) -> void:
	var n := _take("pillar", func(): return _mi(_column(), _mat(M_PILLAR)))
	_look(n, col, col2)
	n.global_position = at
	n.scale = Vector3(radius, height, radius)
	_play(n, "pillar", dur, {"narrow": narrow})

## An expanding ring with spark needles, flat on the ground at `at`, out to radius `r`.
func ring(at: Vector3, r: float, col: Color, col2: Color, dur := 0.35) -> void:
	var n := _take("ring", func(): return _mi(_quad_mesh(), _mat(M_RING)))
	_look(n, col, col2)
	n.global_position = at + Vector3(0, 0.09, 0)
	n.scale = Vector3(r, 1.0, r)
	_play(n, "ring", dur)

## A dark filled disc on the ground, radius r: a jagged crackling rim in `rim`, veins of col2 inside.
## `hollow` drops the dark fill and the veins for a glowing centre: a big range ring, not a dome. `hold` keeps it
## at full strength until the last fifth, for a countdown (it otherwise fades from the first frame).
## Returns the node, so a long one can be ended early with cut().
func disc(at: Vector3, r: float, col: Color, col2: Color, dur := 0.5, rim := NO_EDGE, hollow := false,
		hold := false) -> Node3D:
	var n := _take("disc", func(): return _mi(_quad_mesh(), _mat(M_DISC)))
	var mt := _look(n, col, col2, rim)
	mt.set_shader_parameter("hollow", 1.0 if hollow else 0.0)
	mt.set_shader_parameter("hold", 1.0 if hold else 0.0)
	n.global_position = at + Vector3(0, 0.08, 0)
	n.scale = Vector3(r, 1.0, r)
	_play(n, "disc", dur)
	return n

## Ends a running one-shot now (it is hidden on the next frame and goes back to its pool).
func cut(n: Node3D) -> void:
	for e in live:
		if e["node"] == n:
			e["t"] = float(e["dur"])

## A camera-facing 4-point crackle.
func star(at: Vector3, col: Color, col2: Color, across := 0.4, dur := 0.12) -> void:
	var n := _take("star", func(): return _mi(_quad_mesh(), _mat(M_STAR, true)))
	_look(n, col, col2)
	n.global_position = at
	n.scale = Vector3.ONE * across
	n.rotation = Vector3(PI * 0.5, 0, 0)
	_play(n, "star", dur)

## A flat blast sector from `at` along `dir`, `length` long and `deg` wide; the front runs out over `dur`.
func fan(at: Vector3, dir: Vector2, length: float, deg: float, col: Color, col2: Color, dur := 0.3) -> void:
	var n := _take("fan%d" % int(round(deg)), func(): return _mi(_fan_mesh(deg), _mat(M_FAN)))
	_look(n, col, col2)
	n.global_position = at + Vector3(0, 0.12, 0)
	n.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
	n.scale = Vector3(length, 1.0, length)
	_play(n, "fan", dur)

## Spinning comma arcs on the ground round a target, for `dur` (Dazed).
func swirl(target: Ent, col: Color, col2: Color, dur := 1.2, r := 0.9) -> void:
	var n := _take("swirl", func(): return _mi(_quad_mesh(), _mat(M_SWIRL)))
	_look(n, col, col2)
	n.scale = Vector3(r, 1.0, r)
	n.global_position = target.position + Vector3(0, 0.12, 0)
	_play(n, "swirl", dur, {"follow": target, "oy": 0.12})

## Crackling rings spinning round a target's body for `dur` (shackles).
func shackle(target: Ent, col: Color, col2: Color, dur := 1.5) -> void:
	for i in 2:
		var n := _take("shackle", func():
			var tm := TorusMesh.new()
			tm.inner_radius = 0.92
			tm.outer_radius = 1.0
			tm.rings = 28
			tm.ring_segments = 6
			return _mi(tm, _mat(M_ARC)))
		_look(n, col, col2)
		n.scale = Vector3.ONE * 0.62
		var spin := 6.0 if i == 0 else -7.5
		var tilt := 0.35 if i == 0 else -0.3
		_play(n, "shackle", dur, {"follow": target, "oy": 0.55 + 0.5 * i, "spin": spin, "tilt": tilt})

## A fading after-image of `who` in its pose right now, flat in `col`: the hero's own silhouette
## (its visible meshes, copied once into a pooled node per hunter), even while the model is hidden.
## alpha: its starting opacity. back: metres it sits behind him along his travel. A see-through echo
## (alpha under 0.5) writes no depth, so stacked echoes stay a soft trail and the live body hides them.
func echo(who: Hunter, col: Color, dur := 0.35, alpha := 0.75, back := 0.0) -> void:
	var model: Node3D = who.model
	if model == null or not is_instance_valid(model):
		return
	var n := _take("echo%d" % who.get_instance_id(), _build_echo.bind(model), ECHO_CAP)
	if n.get_meta("model") != model:
		_fill_echo(n, model)          # the model was rebuilt (a new weapon, a respawn): copy it again
	var shift := _behind(who) * back
	var soft := alpha < 0.5
	var push := _push_back(who, shift) if soft else Transform3D.IDENTITY
	for pair in n.get_meta("pairs") as Array:
		var src: MeshInstance3D = pair[0]
		var dst: MeshInstance3D = pair[1]
		dst.visible = is_instance_valid(src) and _shown_under(src, model)
		if dst.visible:
			dst.global_transform = push * src.global_transform.translated(shift)
	var mat: StandardMaterial3D = n.get_meta("mat")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if soft else BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED if soft else BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	mat.render_priority = -1 if soft else 0
	mat.albedo_color = Color(col, 0.0 if soft else alpha)
	var trail := {"col": col, "a0": alpha}
	if soft:
		trail["who"] = who                  # a soft echo shows only once he has moved off it
		trail["at"] = who.global_position + shift
	_play(n, "echo", dur, trail)

## Scales the echo about the camera so it lands ECHO_PUSH m deeper with the same outline on screen: the
## live body is then always in front of it and hides it, whichever way he slides.
func _push_back(who: Hunter, shift: Vector3) -> Transform3D:
	var cam := who.get_viewport().get_camera_3d() if who.is_inside_tree() else null
	if cam == null:
		return Transform3D.IDENTITY
	var eye := cam.global_position
	var depth := eye.distance_to(who.global_position + shift + Vector3(0, 1.0, 0))
	if depth < 0.5:
		return Transform3D.IDENTITY
	var k := (depth + ECHO_PUSH) / depth
	return Transform3D(Basis.from_scale(Vector3.ONE * k), eye * (1.0 - k))

## 0 while a trailing echo still sits on its hunter, 1 once he is ECHO_CLEAR m away: it never covers him.
static func _clear_of(e: Dictionary) -> float:
	var who = e.get("who")
	if who == null or not is_instance_valid(who):
		return 1.0
	var at: Vector3 = e["at"]
	var away := Vector2(at.x - (who as Hunter).global_position.x, at.z - (who as Hunter).global_position.z).length()
	return smoothstep(ECHO_CLEAR * 0.6, ECHO_CLEAR, away)

## The flat direction opposite to where `who` is going (its travel, else its dash, else its facing).
static func _behind(who: Hunter) -> Vector3:
	var flat := Vector3(who.vel.x, 0.0, who.vel.z)
	if flat.length() < 0.5:
		flat = Vector3(who.roll_dir.x, 0.0, who.roll_dir.y)
	if flat.length() < 0.1:
		return Vector3.ZERO
	return -flat.normalized()

func _build_echo(model: Node3D) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	root.set_meta("mat", mat)
	_fill_echo(root, model)
	return root

func _fill_echo(root: Node3D, model: Node3D) -> void:
	for ch in root.get_children():
		ch.queue_free()
	var pairs: Array = []
	for src in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (src as MeshInstance3D).mesh
		if mesh == null or mesh is PlaneMesh or mesh is QuadMesh or mesh.get_aabb().size.length() > 2.0:
			continue          # the body only: no ground cards, rings or big flat props
		var dst := _mi(mesh, root.get_meta("mat") as Material)
		root.add_child(dst)
		pairs.append([src, dst])
	root.set_meta("pairs", pairs)
	root.set_meta("model", model)

## Visible below the model root (the root itself may be hidden: the Wirerun streak hides the body).
static func _shown_under(node: Node3D, model: Node3D) -> bool:
	var at: Node = node
	while at != null and at != model:
		if at is Node3D and not (at as Node3D).visible:
			return false
		at = at.get_parent()
	return at == model

# ------------------------------------------------------------------ riders
## A look riding on a match shot (the dictionary in m.shots) until it ends; then on_end(at, hit) runs.
## kind: "bolt" (a jagged arc ribbon), "tracer" (a hot needle and a cooling tail).
func ride(sd: Dictionary, kind: String, col: Color, col2: Color, length := 1.2, width := 0.3,
		on_end := Callable()) -> void:
	var n: Node3D
	if kind == "tracer":
		n = _take("tracer", func(): return _mi(_ribbon_mesh(), _mat(M_TRACER)))
	else:
		n = _take("arc", func(): return _mi(_ribbon_mesh(), _mat(M_ARC)))
	_look(n, col, col2)
	var mi := sd.get("node") as Node3D
	if mi != null and is_instance_valid(mi):
		mi.visible = false            # the stock orb goes: this look is the round
	var rider := {"node": n, "sd": sd, "kind": kind, "len": length, "width": width, "on_end": on_end}
	rider["last"] = sd["pos"]
	rider["vel"] = sd["vel"]
	riders.append(rider)

func _alive(sd: Dictionary) -> bool:
	for s in m.get("shots"):
		if s == sd:
			return true
	return false

# ------------------------------------------------------------------ marker (immediate style)
## Sparkle's Static marker at height `top` over `target`: `max_n` pips round a bold count on a dark
## backing (lit pips in col, all of them in col2 when full), and sparks on the body, 2 per stack.
## Call every step while it should show; it goes KEEP s after the last call.
func marker(id: String, target: Ent, n: int, max_n: int, col: Color, col2: Color, top: float) -> void:
	var e: Dictionary = markers.get(id, {})
	if e.is_empty() or not is_instance_valid(e.get("node")):
		var node := _take("marker", _build_marker.bind(max_n))
		e = {"node": node, "n": -1}
		markers[id] = e
	e["t"] = 0.0
	var nd: Node3D = e["node"]
	nd.visible = target.visible
	var up := screen_up()
	nd.global_position = target.position + Vector3(0, top, 0) + up * MARK_RAISE
	var full := n >= max_n
	var lit_col := col2 if full else col
	var tm := float(Time.get_ticks_msec()) / 1000.0
	var pips: Node3D = nd.get_node("Pips")
	for i in pips.get_child_count():
		var p := pips.get_child(i) as MeshInstance3D
		var on := i < n
		var pulse := 1.0 + 0.25 * sin(tm * 14.0 + i) if full else 1.0
		p.scale = Vector3.ONE * (1.15 * pulse if on else 0.85)
		p.global_position = nd.global_position + Vector3((i - (max_n - 1) * 0.5) * 0.26, 0, 0) + up * 0.5
		var pm := p.material_override as StandardMaterial3D
		pm.albedo_color = lit_col if on else Color(0.12, 0.1, 0.2, 0.9)
	var lbl: Label3D = nd.get_node("Count")
	lbl.text = "%d" % n
	lbl.modulate = lit_col
	lbl.scale = Vector3.ONE * (1.3 if full else 1.0)
	var sp: CPUParticles3D = nd.get_node("Sparks")
	if int(e["n"]) != n:
		e["n"] = n
		sp.amount = maxi(1, 2 * n)
		sp.initial_velocity_max = 1.4 + 0.9 * n
		sp.scale_amount_max = 0.8 + 0.3 * n
		sp.color = lit_col
		sp.emitting = n > 0
	sp.global_position = target.position + Vector3(0, 1.0, 0)
	sp.emission_sphere_radius = 0.25 + 0.08 * n

## The world direction that reads as "up the screen" (the camera's up), so a tag rides above a head.
func screen_up() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_basis.y if cam != null else Vector3.UP

func unmark(id: String) -> void:
	var e: Dictionary = markers.get(id, {})
	if not e.is_empty() and is_instance_valid(e.get("node")):
		(e["node"] as Node3D).visible = false
		((e["node"] as Node3D).get_node("Sparks") as CPUParticles3D).emitting = false
	markers.erase(id)

## An unlit flat colour that keeps its colour on any ground (not added glow).
static func _flat_mat(c: Color, over := false) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.albedo_color = c
	mt.no_depth_test = over
	return mt

func _build_marker(max_n: int) -> Node3D:
	var nd := Node3D.new()
	nd.add_child(_mark_label("Back", "\u25CF", 100, Color(0.07, 0.05, 0.14, 0.88), 1))
	var lbl := _mark_label("Count", "", 80, Color.WHITE, 3)
	lbl.outline_size = 18
	lbl.outline_modulate = Color(0.05, 0.03, 0.1)
	nd.add_child(lbl)
	var pips := Node3D.new()
	pips.name = "Pips"
	nd.add_child(pips)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	for i in max_n:
		var pm := _flat_mat(Color.BLACK, true)
		pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		pm.render_priority = 4
		var pip := _mi(quad, pm)
		pip.top_level = true
		pips.add_child(pip)
	nd.add_child(_build_sparks())
	return nd

## A billboard text that draws over everything (the marker's count and its dark round backing).
static func _mark_label(label_name: String, text: String, font: int, col: Color, priority: int) -> Label3D:
	var l := Label3D.new()
	l.name = label_name
	l.text = text
	l.font_size = font
	l.pixel_size = 0.01
	l.outline_size = 0
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = priority
	return l

## The body sparks: coloured flecks (alpha-blended, so they keep their colour on bright ground).
func _build_sparks() -> CPUParticles3D:
	var sp := CPUParticles3D.new()
	sp.name = "Sparks"
	sp.top_level = true
	sp.amount = 2
	sp.lifetime = 0.35
	sp.explosiveness = 0.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.13, 0.13)
	sp.mesh = qm
	var sm := _flat_mat(Color.WHITE)
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sp.material_override = sm
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.3
	sp.direction = Vector3.UP
	sp.spread = 180.0
	sp.gravity = Vector3.ZERO
	sp.initial_velocity_min = 0.6
	sp.initial_velocity_max = 2.0
	sp.scale_amount_min = 0.6
	sp.scale_amount_max = 1.0
	sp.local_coords = false
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sp

# ------------------------------------------------------------------ per frame
var _last_t := -1.0
func _process(_delta: float) -> void:
	# effects run on match time (they freeze with the match and replay frame-exact in screenshots)
	var now := float(m.get("time"))
	var delta := clampf(now - _last_t, 0.0, 0.1) if _last_t >= 0.0 else 0.0
	_last_t = now
	for e in live.duplicate():
		_tick_effect(e, delta)
	for r in riders.duplicate():
		_tick_rider(r)
	for id in markers.keys():
		var e2: Dictionary = markers[id]
		e2["t"] = float(e2["t"]) + delta
		if float(e2["t"]) > KEEP:
			unmark(id)
	for id in trails.keys():
		var tr: Dictionary = trails[id]
		tr["t"] = float(tr["t"]) + delta
		if float(tr["t"]) > KEEP:
			trails.erase(id)

func _tick_effect(e: Dictionary, delta: float) -> void:
	e["t"] = float(e["t"]) + delta
	var n: Node3D = e["node"]
	var u := clampf(float(e["t"]) / float(e["dur"]), 0.0, 1.0)
	if not is_instance_valid(n) or u >= 1.0:
		if is_instance_valid(n):
			n.visible = false
		live.erase(e)
		return
	var kind := String(e["kind"])
	if kind == "echo":
		var em: StandardMaterial3D = n.get_meta("mat")
		em.albedo_color = Color(e["col"], float(e.get("a0", 0.75)) * (1.0 - u) * (1.0 - u) * _clear_of(e))
		return
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
			_tick_follow(e, n, mt, u)

func _tick_follow(e: Dictionary, n: Node3D, mt: ShaderMaterial, u: float) -> void:
	var f = e.get("follow")
	if f == null or not is_instance_valid(f) or (f as Ent).dead:
		n.visible = false
		live.erase(e)
		return
	n.global_position = (f as Ent).position + Vector3(0, float(e.get("oy", 0.1)), 0)
	if String(e["kind"]) == "shackle":
		n.rotation = Vector3(float(e["tilt"]), float(e["t"]) * float(e["spin"]), 0)
		mt.set_shader_parameter("life", 0.0)
		mt.set_shader_parameter("strength", 1.0 - smoothstep(0.75, 1.0, u))
	else:
		mt.set_shader_parameter("strength", 1.0 - smoothstep(0.8, 1.0, u))

func _tick_rider(r: Dictionary) -> void:
	var n: Node3D = r["node"]
	var sd: Dictionary = r["sd"]
	if not is_instance_valid(n):
		riders.erase(r)
		return
	if _alive(sd):
		var p: Vector3 = sd["pos"]
		var v: Vector2 = sd["vel"]
		r["last"] = p
		r["vel"] = v
		var back := Vector3(-v.x, 0, -v.y).normalized() if v.length() > 0.1 else Vector3.BACK
		var travelled := p.distance_to(sd.get("start", p))
		var trail := minf(float(r["len"]), travelled + 0.2)
		_lay(n, p, p + back * trail, float(r["width"]))
		return
	n.visible = false
	riders.erase(r)
	var cb: Callable = r["on_end"]
	if cb.is_valid():
		cb.call(r["last"] as Vector3, r["vel"] as Vector2)
