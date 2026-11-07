class_name LDFx
extends Node3D
## Cinder's and Dredge's own effects, pooled (one node per match, LDFx.of(m)). Every node is made once
## and reused; nothing is created per frame. One shader (shaders/ld_fx.gdshader, a mode per look) plus
## the see-through arm shader (shaders/ld_arm.gdshader).
##
## - flame(id, parts)      the Torch Lance hose: pooled camera-facing puffs the kit simulates (immediate style)
## - ride(sd, kind, ...)   a projectile look riding on a shot: "cinder" (Cinder Shot), "slug" (scattergun)
## - place(id, kind, ...)  immediate-style looks the kit refreshes every step: "skull", "swirl", "chain",
##                         "pip", "spiral", "pilot", "anchor", "glow", "hook" (the bone hook); stop calling
##                         and they hide
## - arm(id, a, b)         Grimble's stretched arm (purple flesh, a bone ridge), drawn through walls
## - one-shots: sunburst, scorch, crescent, wave, dot, lava, orb, anchor_drop, embers, puff, wisp, volley
##   (a Broadside slug)
##
## Each look is two passes (shaders/ld_fx.gdshaderinc): an alpha-blended body, so colour and dark rims read
## on bright grass, and an additive glow chained on as next_pass for the hot cores. _param sets both.

const SHADER: Shader = preload("res://shaders/ld_fx.gdshader")
const GLOW_SHADER: Shader = preload("res://shaders/ld_fx_glow.gdshader")
const ANCHOR_SHADER: Shader = preload("res://shaders/ld_anchor.gdshader")
const ARM_SHADER: Shader = preload("res://shaders/ld_arm.gdshader")
const LAVA_SHADER: Shader = preload("res://shaders/ld_lava.gdshader")     # alpha-blended: dark rims stay dark
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
const M_SMOKE := 13
const POOL_CAP := 24           # nodes per kind at most; past it the oldest is taken back
const KEEP := 0.1              # s an immediate-style look stays without a refresh
const FLAME_CAP := 32          # hose puffs drawn at most (the kit keeps about 15)
const HANG_T := 0.3            # s a scattergun slug hangs as a dot at its stop line
## a Broadside slug's look (LDFx.volley): its dot (half width, m), the soft halo round it, the smear
## behind it in flight (m long and wide)
const VOLLEY_HEAD := 0.34
const VOLLEY_HALO := 0.8
const VOLLEY_SMEAR := 1.1
const VOLLEY_WIDTH := 0.55
const CINDER_HALO := Color("6a5aff")
const HOOK_R := 0.42          # m, the bone hook's curl
const HOOK_BITS := 7          # pieces of the curl
const ARM_SIDES := 6          # faces round the stretched arm
const ARM_STEP := 0.3          # m between the arm's rings
const ARM_BONE_FROM := 0.78   # how far along the arm (0..1) its flesh starts turning to bone
const ANCHOR_IRON := Color("3a3f48")
const ANCHOR_RIM := Color("5cffd8")     # seafoam: "harbour", and it stands off yellow-green grass
const ANCHOR_DROP := 3.2       # m the anchor falls from (times its scale)
const ANCHOR_HOLD := 0.25      # s it stays planted after it lands, before it fades
const ANCHOR_FADE := 0.3
const ANCHOR_LEAN := -0.9      # rad the anchor leans away from the camera, so its face turns to the view

var m: Node
var pools := {}                # kind -> Array of nodes made for it
var live: Array = []           # one-shot effects: {node, t, dur, kind, s0, mat}
var riders: Array = []         # looks riding on a shot: {node, sd, kind, last, on_end}
var placed := {}               # id -> {node, kind, t}
var flames := {}               # id -> {node, t}
var arms := {}                # id -> {node, mesh, t}
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
	mt.shader = LAVA_SHADER if mode == M_LAVA else SHADER
	if mode != M_LAVA:
		mt.next_pass = ShaderMaterial.new()
		(mt.next_pass as ShaderMaterial).shader = GLOW_SHADER
	_param(mt, "mode", mode)
	_param(mt, "color", col)
	_param(mt, "color2", col2)
	_param(mt, "billboard", bb)
	_param(mt, "seed", randf() * 10.0)
	return mt

## Sets a shader parameter on a look's body pass and on its glow pass.
static func _param(mt: Material, key: String, value: Variant) -> void:
	var sm := mt as ShaderMaterial
	sm.set_shader_parameter(key, value)
	if sm.next_pass:
		(sm.next_pass as ShaderMaterial).set_shader_parameter(key, value)

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
		if e["node"] == old:
			live.erase(e)
			break
	for r in riders:
		if r["node"] == old:
			riders.erase(r)
			break
	for id in placed.keys():
		if placed[id]["node"] == old:
			placed.erase(id)
			break
	return old

# ------------------------------------------------------------------ meshes
func _quad_mesh() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(2, 2)
	return _quad

func _plane_mesh() -> PlaneMesh:
	if _plane == null:
		_plane = PlaneMesh.new()
		_plane.size = Vector2(2, 2)
	return _plane

## Two crossed strips along +Z from the head (z 0, UV.x 0) to the tail (z 1).
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
		var u0 := -arc * 0.5 + arc * float(i) / n
		var u1 := -arc * 0.5 + arc * float(i + 1) / n
		var w0 := sin(PI * float(i) / n)
		var w1 := sin(PI * float(i + 1) / n)
		var o0 := Vector3(sin(u0), 0, -cos(u0))
		var o1 := Vector3(sin(u1), 0, -cos(u1))
		var c := o1 * lerpf(1.0, 0.45, w1)
		var d := o0 * lerpf(1.0, 0.45, w0)
		var ua := float(i) / n
		var ub := float(i + 1) / n
		st.set_uv(Vector2(ua, 0))
		st.add_vertex(o0)
		st.set_uv(Vector2(ub, 0))
		st.add_vertex(o1)
		st.set_uv(Vector2(ub, 1))
		st.add_vertex(c)
		st.set_uv(Vector2(ua, 0))
		st.add_vertex(o0)
		st.set_uv(Vector2(ub, 1))
		st.add_vertex(c)
		st.set_uv(Vector2(ua, 1))
		st.add_vertex(d)
	var mesh := st.commit()
	_cres[key] = mesh
	return mesh

## Dredge's anchor (2 bh tall): shank, stock, ring and two flukes in solid dark iron with a seafoam rim.
func _anchor_node() -> Node3D:
	var n := Node3D.new()
	var mt := ShaderMaterial.new()
	mt.shader = ANCHOR_SHADER
	mt.set_shader_parameter("color", ANCHOR_IRON)
	mt.set_shader_parameter("color2", ANCHOR_RIM)
	n.set_meta("mat", mt)
	var add := func(mesh: Mesh, pos: Vector3, rot := Vector3.ZERO) -> void:
		var p := _mi(mesh, mt)
		p.position = pos
		p.rotation = rot
		n.add_child(p)
	add.call(Models.box(0.36, 2.6, 0.3), Vector3(0, 1.6, 0))
	add.call(Models.box(1.7, 0.3, 0.3), Vector3(0, 2.6, 0))
	add.call(Models.cyl(0.4, 0.4, 0.22, 16), Vector3(0, 3.15, 0), Vector3(PI / 2, 0, 0))
	for sx in [-1.0, 1.0]:
		add.call(Models.box(1.3, 0.3, 0.3), Vector3(0.62 * sx, 0.55, 0), Vector3(0, 0, -0.62 * sx))
		add.call(Models.box(0.34, 0.5, 0.34), Vector3(1.2 * sx, 1.0, 0), Vector3(0, 0, 0.3 * sx))
	return n

## Grimble's bone hook, the end of the stretched arm: a knuckle, the jagged hook curling to one side, a short split
## prong on the other and two spurs on top, drawn through walls like the arm (-z is the way it reaches).
func _hook_node(_col: Color) -> Node3D:
	var n := Node3D.new()
	var mt := ShaderMaterial.new()
	mt.shader = ARM_SHADER
	var bit := func(from: Vector3, to: Vector3, r0: float, r1: float) -> void:
		var mi := _mi(Models.cyl(r1, r0, from.distance_to(to), 6), mt)
		mi.transform = Transform3D(
			Basis.looking_at(from.direction_to(to), Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2), (from + to) * 0.5)
		n.add_child(mi)
	bit.call(Vector3(0, 0, 0.2), Vector3(0, 0, -0.12), 0.24, 0.2)
	var prev := Vector3(0, 0, -0.1)
	for i in HOOK_BITS:
		var phi := 1.25 * PI * float(i + 1) / HOOK_BITS
		var at := Vector3(HOOK_R * (1.0 - cos(phi)), 0.06 * phi, -0.1 - HOOK_R * sin(phi))
		bit.call(prev, at, lerpf(0.17, 0.02, float(i) / HOOK_BITS), lerpf(0.17, 0.02, float(i + 1) / HOOK_BITS))
		prev = at
	bit.call(Vector3(-0.1, 0, -0.1), Vector3(-0.3, 0.02, -0.62), 0.11, 0.015)
	bit.call(Vector3(0.05, 0.14, 0.12), Vector3(0.1, 0.4, 0.0), 0.07, 0.01)
	bit.call(Vector3(-0.06, 0.15, 0.0), Vector3(-0.12, 0.38, -0.14), 0.06, 0.01)
	return n

# ------------------------------------------------------------------ the hose
## The Torch Lance stream this step: parts [{p, age (0..1), r, seed}]. A pool of camera-facing puffs per id
## (FLAME_CAP at most), reused every step; stop calling and they hide.
func flame(id: String, parts: Array) -> void:
	var e: Dictionary = flames.get(id, {})
	if e.is_empty():
		e = {"nodes": []}
		flames[id] = e
	e["t"] = m.time
	var nodes: Array = e["nodes"]
	var n := mini(parts.size(), FLAME_CAP)
	while nodes.size() < n:
		var mi := _mi(_quad_mesh(), _mat(M_FLAME, Color.WHITE, Color.WHITE, true))
		mi.top_level = true
		add_child(mi)
		made += 1
		nodes.append(mi)
	for i in nodes.size():
		var mi2: MeshInstance3D = nodes[i]
		if i >= n:
			mi2.visible = false
			continue
		var p: Dictionary = parts[i]
		mi2.visible = true
		mi2.global_position = p["p"]
		mi2.scale = Vector3.ONE * float(p["r"])
		var mt := mi2.material_override as ShaderMaterial
		_param(mt, "life", float(p["age"]))
		_param(mt, "seed", float(p.get("seed", 0.0)) * 10.0)

func flame_off(id: String) -> void:
	var e: Dictionary = flames.get(id, {})
	for mi in e.get("nodes", []):
		if is_instance_valid(mi): (mi as Node3D).visible = false

## How many hose puffs are showing for this id (tests).
func flame_shown(id: String) -> int:
	var c := 0
	for mi in flames.get(id, {}).get("nodes", []):
		if is_instance_valid(mi) and (mi as Node3D).visible: c += 1
	return c

# ------------------------------------------------------------------ one-shots
func _fx(kind: String, mode: int, mesh: Mesh, bb: bool) -> MeshInstance3D:
	return _take(kind, func(): return _mi(mesh, _mat(mode, Color.WHITE, Color.WHITE, bb))) as MeshInstance3D

func _play(n: Node3D, kind: String, col: Color, col2: Color, dur: float, s0: Vector3, mt: ShaderMaterial) -> Dictionary:
	if mt:
		_param(mt, "color", col)
		_param(mt, "color2", col2)
		_param(mt, "life", 0.0)
		_param(mt, "progress", 0.0)
		_param(mt, "seed", randf() * 10.0)
	n.scale = s0
	var e := {"node": n, "t": 0.0, "dur": maxf(0.05, dur), "kind": kind, "s0": s0, "mat": mt}
	live.append(e)
	return e

func _flat(
	kind: String, mode: int, at: Vector3, r: float, col: Color, col2: Color, dur: float, yaw := 0.0
) -> Dictionary:
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
func wave(at: Vector3, r: float, col: Color, dur := 0.35, col2 := Color(0, 0, 0, 0)) -> void:
	_flat("wave", M_WAVE, at, r, col, col2, dur)

## A blade arc in front of `at` facing `dir`, swept over `dur`. tilt PI/2: standing up.
func crescent(
	at: Vector3, dir: Vector2, arc_deg: float, reach: float, col: Color, col2: Color, dur := 0.25, tilt := 0.0
) -> void:
	var key := "cres%d" % int(round(arc_deg))
	var n := _take(key, func(): return _mi(_crescent_mesh(arc_deg), _mat(M_CRESCENT, col, col2))) as MeshInstance3D
	n.global_position = at
	var d3 := Vector3(dir.x, 0, dir.y)
	if d3.length() < 0.01: d3 = Vector3.FORWARD
	n.basis = Basis.looking_at(d3.normalized(), Vector3.UP) * Basis(Vector3.FORWARD, tilt)
	var e := _play(n, key, col, col2, dur, Vector3.ONE * reach, n.material_override)
	e["sweep"] = true

## A camera-facing glow (a hit flash, the pilot flare).
func orb(at: Vector3, col: Color, col2: Color, scl := 0.6, dur := 0.15) -> void:
	var n := _fx("orb", M_ORB, _quad_mesh(), true)
	n.global_position = at
	var e := _play(n, "orb", col, col2, dur, Vector3.ONE * scl, n.material_override)
	e["grow"] = 0.5

## A solid dot with a dark core left hanging in the air (a scattergun slug at its stop line).
func dot(at: Vector3, col: Color, scl := 0.16, dur := HANG_T) -> void:
	var n := _fx("dot", M_DOT, _quad_mesh(), true)
	n.global_position = at
	_play(n, "dot", col, col.darkened(0.7), dur, Vector3.ONE * scl, n.material_override)

## A Broadside slug's look, flown on the effect clock instead of riding its shot (the shot lives about
## 0.2s, too short to read): a `col` orb with a `dark` core and a smear flies from `from` to `to` over `fly`,
## then hangs there fading over `hold`, as the source's orbs do.
func volley(from: Vector3, to: Vector3, col: Color, dark: Color, fly: float, hold: float) -> void:
	var n := _take("volley", _build_volley)
	for c in n.get_children():
		var mt := (c as MeshInstance3D).material_override
		_param(mt, "color", col)
		_param(mt, "color2", Color(dark, 0.6) if c.name == "Trail" else dark)
		_param(mt, "life", 0.0)
	_param((n.get_node("Halo") as MeshInstance3D).material_override, "color2", col)
	var e := {"node": n, "t": 0.0, "dur": fly + hold, "kind": "volley", "mat": null}
	e.merge({"from": from, "to": to, "fly": maxf(0.01, fly), "hold": hold})
	live.append(e)
	_pose_volley(e, n)

func _build_volley() -> Node3D:
	var n := Node3D.new()
	n.add_child(_rider_part("Halo", Color.WHITE, Color.WHITE, VOLLEY_HALO, 0.55))
	var head := _mi(_quad_mesh(), _mat(M_DOT, Color.WHITE, Color.WHITE, true))
	head.name = "Head"
	head.scale = Vector3.ONE * VOLLEY_HEAD
	head.sorting_offset = 0.1
	n.add_child(head)
	var tr := _mi(_ribbon_mesh(), _mat(M_COMET, Color.WHITE, Color.WHITE))
	tr.name = "Trail"
	n.add_child(tr)
	return n

func _pose_volley(e: Dictionary, n: Node3D) -> void:
	var t := float(e["t"])
	var fly := float(e["fly"])
	var from: Vector3 = e["from"]
	var to: Vector3 = e["to"]
	n.global_position = from.lerp(to, clampf(t / fly, 0.0, 1.0))
	var ahead := Vector3(to.x - from.x, 0, to.z - from.z)
	if ahead.length() > 0.05:
		n.basis = Basis.looking_at(ahead.normalized(), Vector3.UP)
	var fade := clampf((t - fly) / maxf(0.01, float(e["hold"])), 0.0, 1.0)
	for c in n.get_children():
		_param((c as MeshInstance3D).material_override, "life", fade)
	var smear := maxf(0.01, VOLLEY_SMEAR * (1.0 - fade))
	(n.get_node("Trail") as Node3D).scale = Vector3(VOLLEY_WIDTH, VOLLEY_WIDTH, smear)

## A camera-facing puff that swells and fades (a dash's after-image): mode M_FLAME burns through the fire
## ramp on its own, M_ORB uses col (the rim) and col2 (the centre).
func puff(at: Vector3, mode: int, col: Color, col2: Color, scl: float, dur: float) -> void:
	var kind := "puff%d" % mode
	var n := _fx(kind, mode, _quad_mesh(), true)
	n.global_position = at
	var e := _play(n, kind, col, col2, dur, Vector3.ONE * scl, n.material_override)
	e["grow"] = 0.6

## A thin ribbon of smoke rising from `at` (camera-facing, `scl` m half-height, its foot on `at`): it wavers as it
## climbs, breaks into streaks and fades (Dredge's stack); col its top, col2 its foot, col.a its cover.
func wisp(at: Vector3, col: Color, col2: Color, scl: float, dur: float) -> void:
	var n := _fx("wisp", M_SMOKE, _quad_mesh(), true)
	n.global_position = at + Vector3(0, scl * 0.9, 0)
	_play(n, "wisp", col, col2, dur, Vector3.ONE * scl, n.material_override)

## A molten strip from a to b on the ground (the rank-3 fire trail), lasting `dur`.
func lava(a: Vector3, b: Vector3, width: float, dur: float) -> void:
	var ln := Vector2(b.x - a.x, b.z - a.z).length()
	if ln < 0.2:
		return
	var n := _fx("lava", M_LAVA, _plane_mesh(), false)
	n.global_position = (a + b) * 0.5 + Vector3(0, 0.07, 0)
	n.rotation = Vector3(0, atan2(-(b.z - a.z), b.x - a.x), 0)
	var e := _play(
		n, "lava", Color("ff8a2a"), Color("4a1238"), dur, Vector3(ln * 0.5, 1, width * 0.5), n.material_override
	)
	_param(n.material_override, "progress", ln)
	e["keep_progress"] = true

## The Anchor Drop's giant anchor falling onto `at` over `fall` seconds (0: already down), planted for
## ANCHOR_HOLD, then fading. Returns its entry; the kit may move entry["at"] while it falls.
func anchor_drop(at: Vector3, fall: float, scl := 1.2) -> Dictionary:
	var n := _take("anchor", _anchor_node)
	n.global_position = at + Vector3(0, ANCHOR_DROP * scl, 0) * signf(fall)
	n.rotation = Vector3(ANCHOR_LEAN, 0, 0)
	n.scale = Vector3.ONE * scl
	_param(n.get_meta("mat"), "fade", 1.0)
	var e := {
		"node": n, "t": 0.0, "dur": fall + ANCHOR_HOLD + ANCHOR_FADE, "fall": fall, "kind": "anchor",
		"s0": n.scale, "mat": n.get_meta("mat"), "at": at
	}
	live.append(e)
	return e

## Ends a one-shot early (an Anchor Drop whose wind-up was stunned out); it hides on the next frame.
func stop(e: Dictionary) -> void:
	if not e.is_empty(): e["t"] = float(e["dur"])

## Embers sprayed up and out of a spot for `dur` (Cinder Shot's impact).
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
		"anchor": return _anchor_node()
		"hook": return _hook_node(col)
		"skull": return _skull_node(col, col2)
	return Node3D.new()

## The Flame Skull: a wide crescent of fire lying round his front (it reads from above), a hotter inner
## crescent, a glow at the brow and ember tails streaming back.
func _skull_node(col: Color, col2: Color) -> Node3D:
	var n := Node3D.new()
	var cr := _mi(_crescent_mesh(150.0), _mat(M_CRESCENT, col, Color("8a1a10")))
	cr.name = "Cres"
	_param(cr.material_override, "progress", 1.0)
	n.add_child(cr)
	var cr2 := _mi(_crescent_mesh(110.0), _mat(M_CRESCENT, col2, col))
	cr2.name = "Cres2"
	_param(cr2.material_override, "progress", 1.0)
	cr2.position = Vector3(0, 0.05, 0.1)
	cr2.scale = Vector3.ONE * 0.78
	n.add_child(cr2)
	var g := _mi(_quad_mesh(), _mat(M_ORB, col, col2, true))
	g.name = "Glow"
	g.position = Vector3(0, 0.1, -0.7)
	g.scale = Vector3.ONE * 0.5
	g.sorting_offset = 0.2
	n.add_child(g)
	for i in 3:
		var tr := _mi(_ribbon_mesh(), _mat(M_COMET, col, Color("3a1a2a")))
		tr.name = "Tail%d" % i
		tr.position = Vector3((i - 1) * 0.45, 0.1 * (1 - absi(i - 1)), 0.0)
		tr.scale = Vector3(0.32, 0.32, 2.5)
		n.add_child(tr)
	return n

## Shows an immediate look this step. `basis` orients it (flat looks lie on XZ), scl scales it.
func place(
	id: String, kind: String, at: Vector3, col: Color, col2: Color, scl := 1.0, yaw := 0.0, strength := 1.0
) -> Node3D:
	var e: Dictionary = placed.get(id, {})
	var stale: bool = e.is_empty() or not is_instance_valid(e["node"]) or String(e["kind"]) != kind
	if stale or not (e["node"] as Node3D).visible:
		e = {"node": _take("pl_" + kind, func(): return _build_place(kind, col, col2)), "kind": kind}
		placed[id] = e
	e["t"] = m.time
	var n: Node3D = e["node"]
	n.visible = true
	n.global_position = at
	n.rotation = Vector3(ANCHOR_LEAN if kind == "anchor" else 0.0, yaw, 0)
	n.scale = Vector3.ONE * scl
	if n is MeshInstance3D:
		var mt := (n as MeshInstance3D).material_override as ShaderMaterial
		_param(mt, "color", col)
		_param(mt, "color2", col2)
		_param(mt, "strength", strength)
		_param(mt, "life", 0.0)
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
	var tail_col := col2
	match kind:
		"cinder":
			# Cinder Shot: a red-pink fireball with a yellow core inside a violet halo, a dark smoke tail
			n.add_child(_rider_part("Halo", CINDER_HALO, CINDER_HALO, 1.15, 0.6))
			n.add_child(_rider_part("Head", col, col2, 0.62, 1.0))
			tail_col = Color(Color("3a2a3a"), 0.7)
		"slug":
			n.add_child(_rider_part("Head", col, col2, 0.3, 1.0))
	var tr := _mi(_ribbon_mesh(), _mat(M_COMET, col, tail_col))
	tr.name = "Trail"
	n.add_child(tr)
	return n

## One camera-facing part of a projectile look; the head draws over the halo.
func _rider_part(part: String, col: Color, col2: Color, scl: float, cover: float) -> MeshInstance3D:
	var mi := _mi(_quad_mesh(), _mat(M_ORB, col, col2, true))
	_param(mi.material_override, "strength", cover)
	mi.name = part
	mi.scale = Vector3.ONE * scl
	if part == "Head": mi.sorting_offset = 0.1
	return mi

## Rides a look on a shot (match.gd's shot dictionary) until it ends. The plain shot node is handed
## back to the match's pool, so only this look shows. on_end(at, expired) runs when it ends.
func ride(
	sd: Dictionary, kind: String, col: Color, col2: Color, trail := 1.2, width := 0.3, on_end := Callable()
) -> void:
	var n := _take("ride_" + kind, func(): return _build_rider(kind, col, col2))
	for c in n.get_children():
		var mt := (c as MeshInstance3D).material_override as ShaderMaterial
		if c.name == "Head":
			_param(mt, "color", col)
			_param(mt, "color2", col2)
		if c.name == "Trail":
			_param(mt, "color", col)
	var sn = sd.get("node")
	if sn is Node3D and is_instance_valid(sn):
		(sn as Node3D).visible = false
		sd["node"] = null
	riders.append({
		"node": n, "sd": sd, "kind": kind, "trail": trail, "width": width, "on_end": on_end, "last": sd["pos"]
	})
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

## Grimble's arm stretched from a to b this step: a tube of purple flesh, thick at the shoulder end, thin and
## sinewy between, swelling at the forearm and turning to bone at the hook; it sags a little and its flesh
## pulses (seen through walls). Stop calling and it goes.
func arm(id: String, a: Vector3, b: Vector3, col: Color, thick := 0.32) -> void:
	var e: Dictionary = arms.get(id, {})
	if e.is_empty() or not is_instance_valid(e["node"]):
		var im := ImmediateMesh.new()
		var mt := ShaderMaterial.new()
		mt.shader = ARM_SHADER
		var mi := _mi(im, mt)
		mi.top_level = true
		add_child(mi)
		made += 1
		e = {"node": mi, "mesh": im}
		arms[id] = e
	e["t"] = m.time
	var mi2: MeshInstance3D = e["node"]
	mi2.visible = true
	mi2.global_transform = Transform3D.IDENTITY
	_param(mi2.material_override, "color", col)
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
	var n := maxi(3, int(length / ARM_STEP))
	var rings: Array = []
	for i in n + 1:
		var k := float(i) / n
		var r := thick * 0.5 * lerpf(1.0, 0.5, sin(minf(k * 1.6, 1.0) * PI * 0.5))     # thick shoulder to thin sinew
		r *= 1.0 + 0.55 * smoothstep(0.7, 1.0, k)                                      # the forearm swells at the hook
		r *= 1.0 + 0.1 * sin(k * length * 4.0 - float(m.time) * 9.0)                   # the flesh pulses
		rings.append([a.lerp(b, k) + Vector3.UP * sin(k * PI) * length * 0.035, r, k])
	for j in ARM_SIDES:
		var ang0 := TAU * j / ARM_SIDES
		var ang1 := TAU * (j + 1) / ARM_SIDES
		im2.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for ring: Array in rings:
			var k: float = ring[2]
			im2.surface_set_color(Color(1, 1, 1, smoothstep(ARM_BONE_FROM, 1.0, k)))
			for ang: float in [ang0, ang1]:
				var dir := side * cos(ang) + up * sin(ang)
				im2.surface_set_normal(dir)
				im2.surface_set_uv(Vector2(k * length, ang / TAU))
				im2.surface_add_vertex((ring[0] as Vector3) + dir * float(ring[1]))
		im2.surface_end()

func arm_shown(id: String) -> bool:
	return arms.has(id) and is_instance_valid(arms[id]["node"]) and (arms[id]["node"] as Node3D).visible

# ------------------------------------------------------------------ per step
var _tracked_at := -1.0
var _drawn_at := 0.0

## Follows the shots the looks ride on, on the match step (the kits call it from _tick, once per step
## whoever calls first): records where each is, and when one ends runs its on_end(at, expired).
func track() -> void:
	if float(m.time) == _tracked_at:
		return
	_tracked_at = float(m.time)
	for r in riders.duplicate():
		var n: Node3D = r["node"]
		var sd: Dictionary = r["sd"]
		if not _alive(sd) or not is_instance_valid(n):
			if is_instance_valid(n): n.visible = false
			riders.erase(r)
			var expired := float(sd.get("life", 0.0)) <= 0.02
			if (r["on_end"] as Callable).is_valid(): (r["on_end"] as Callable).call(sd["pos"], expired)
			continue
		r["last"] = sd["pos"]

# ------------------------------------------------------------------ per frame
## The falling anchor: an accelerating drop, a squash as it bites into the ground, planted, then faded.
func _pose_anchor(e: Dictionary, n: Node3D) -> void:
	var t := float(e["t"])
	var fall := float(e["fall"])
	var s0: Vector3 = e["s0"]
	var drop := clampf(t / fall, 0.0, 1.0) if fall > 0.0 else 1.0
	n.global_position = (e["at"] as Vector3) + Vector3(0, ANCHOR_DROP * s0.y * (1.0 - drop * drop), 0)
	var since := t - fall
	var squash := 1.0 + 0.25 * (1.0 - clampf(since / 0.15, 0.0, 1.0)) if since >= 0.0 else 1.0
	n.scale = s0 * Vector3(squash, 1.0 / squash, squash)
	_param(e["mat"], "fade", 1.0 - clampf((since - ANCHOR_HOLD) / ANCHOR_FADE, 0.0, 1.0))

func _alive(sd: Dictionary) -> bool:
	for s in m.shots:
		if is_same(s, sd): return true
	return false

## Effects age on the match clock, so they stay in step with the kit moves they dress (a slow frame or a
## hitstop holds them just as it holds the fight).
func _process(_delta: float) -> void:
	var delta := clampf(float(m.time) - _drawn_at, 0.0, 0.25)
	_drawn_at = float(m.time)
	for e in live.duplicate():
		var n: Node3D = e["node"]
		if not is_instance_valid(n):
			live.erase(e)
			continue
		e["t"] = float(e["t"]) + delta
		var u := clampf(float(e["t"]) / float(e["dur"]), 0.0, 1.0)
		var mt: ShaderMaterial = e["mat"]
		match String(e["kind"]):
			"anchor":
				_pose_anchor(e, n)
			"volley":
				_pose_volley(e, n)
			_:
				_param(mt, "life", u)
				if e.get("sweep", false): _param(mt, "progress", minf(1.0, u * 1.8))
				if e.has("grow"): n.scale = (e["s0"] as Vector3) * (1.0 + float(e["grow"]) * u)
		if u >= 1.0:
			n.visible = false
			live.erase(e)
	for em in emitters.duplicate():
		em["t"] = float(em["t"]) + delta
		em["acc"] = float(em["acc"]) + delta
		if float(em["acc"]) >= 0.07 and m.get("fx") != null:
			em["acc"] = 0.0
			m.fx.spark(
				(em["at"] as Vector3) + Vector3(0, 0.9, 0),
				Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3)), em["col"], 6, 5.0, 60.0, 0.45, 9.0, 1.3
			)
		if float(em["t"]) >= float(em["dur"]):
			emitters.erase(em)
	track()
	for r in riders:
		_pose(r["node"], r["sd"]["pos"], r["sd"]["vel"], float(r["trail"]), float(r["width"]))
	for id in placed.keys():
		var e: Dictionary = placed[id]
		if m.time - float(e.get("t", 0.0)) > KEEP:
			if is_instance_valid(e["node"]): (e["node"] as Node3D).visible = false
			placed.erase(id)
	for id in flames.keys():
		if m.time - float(flames[id].get("t", 0.0)) > KEEP:
			flame_off(id)
	for id in arms.keys():
		var e: Dictionary = arms[id]
		if m.time - float(e.get("t", 0.0)) > KEEP and is_instance_valid(e["node"]):
			(e["node"] as Node3D).visible = false
