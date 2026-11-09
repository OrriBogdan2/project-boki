class_name HeroVfx
extends Node3D
## The shared Hero ability looks and sounds: one pooled node per match (HeroVfx.of(m)), driven by one data file per
## Hero (content/vfx/<arch>.json; docs/HERO_VFX.md is the recipe guide). A kit calls play(h, "move", at, dir) for a
## moment and hold(h, "move", k) every tick for something that lasts while it asks; the data says which layers
## (shader meshes, mesh trails, GPU particles) and sounds that move is made of.
##
## Budget: nodes are pooled per kind, GPU particles alive at once are capped at MAX_LIVE, the quality
## preset thins them, and past LOD_NEAR from the camera focus the "near" layers drop and the rest thin out (nothing
## draws past LOD_FAR). Colour rule: looks stay in the Hero's palette; allies' effects sit at ALLY_K.
## Telegraph lanes and discs are AimKit's: this adds the body and weapon tells around them, never the danger shapes.

const SURFACE: Shader = preload("res://shaders/hero_vfx.gdshader")
const MOTES: Shader = preload("res://shaders/hero_vfx_motes.gdshader")
const MOTE: Shader = preload("res://shaders/hero_vfx_mote.gdshader")
const MODES := {"sweep": 0, "scorch": 1, "skirt": 2, "flare": 3, "ribbon": 4, "thread": 5, "bolt": 6, "vortex": 7}
const LOOKS := {"ember": 0, "smoke": 1, "chunk": 2, "shard": 3, "card": 4, "coin": 5, "star": 6, "drop": 7}
const SHAPES := {"ball": 0, "line": 1, "disc": 2, "gather": 3, "arc": 4}
const SCORCH_SHAPES := {"disc": 0, "lane": 1, "cone": 2}
const POOL := {"sweep": 10, "scorch": 10, "skirt": 8, "flare": 14, "ribbon": 10, "thread": 18, "bolt": 12, "vortex": 4,
	"ember": 12, "smoke": 6, "chunk": 4, "shard": 6, "card": 4, "coin": 4, "star": 6, "drop": 6}
const AMOUNT := {"ember": 48, "smoke": 14, "chunk": 18, "shard": 24, "card": 12, "coin": 24, "star": 24, "drop": 32}
const TRAIL_MAX := 2.0         # s a projectile's trail may follow it
const MAX_LIVE := 420          # GPU particles alive at once across the match
const LOD_NEAR := 20.0         # m from the camera focus: full detail
const LOD_FAR := 34.0          # m: nothing is drawn beyond this
const LOD_MID_K := 0.5         # share of the particles between the two
const ALLY_K := 0.6            # an ally's effects, so yours and the enemy's stay on top
const HOLD_LINGER := 0.15      # s a hold outlives its last ask
const RIBBON_SAMPLES := 18     # points a mesh trail keeps
const RIBBON_WAVES := 11.0     # rad along a trail's "wave" (a thread trailing in the air)
const ARC_SEGS := 24           # segments of a sweep's arc mesh
const SWEEP_INNER := 0.35      # the arc mesh's inner radius, as a share of its outer one
const SCORCH_LIFT := 0.06       # m a ground look floats, clear of the ground mesh
const PREWARM_LIFE := 30.0     # s a loading-screen stand-in particle lives (it must outlast the slowest loading frames)
const SEED_MAX := 8.0          # a look's noise offset (small: the sine hash loses precision on big inputs)

static var _data := {}         # arch -> its content/vfx data ({} when the Hero has none yet)

var m: Node
var pools := {}                # kind -> nodes made for it
var live: Array = []           # shader looks running: {node, mat, t, dur, s0, s1, kind}
var ribbons: Array = []        # mesh trails running: {node, mat, h, anchor, t, dur, tail, width, pts}
var motes: Array = []          # one-shot emitters running: {node, t, dur, n}
var holds := {}                # "<hunter id>/<move>" -> {h, move, last, layers: [{node, layer, n}]}
var live_n := 0                # GPU particles alive (asked for) now
var made := 0                  # nodes made so far (tests: it stops growing once warm)
var plays := {}                # (tests) move -> times played
var _arcs := {}                # arc degrees -> arc mesh
var _cyl: ArrayMesh
var _warming: Array = []       # the loading screen's stand-ins (prewarm)
var _anchors := {}             # "<model id>/<anchor>" -> the node found for it (null: none)

static func of(match_node: Node) -> HeroVfx:
	if match_node.has_meta("hero_vfx"):
		var f = match_node.get_meta("hero_vfx")
		if is_instance_valid(f):
			return f
	var n := HeroVfx.new()
	n.m = match_node
	n.name = "HeroVfx"
	match_node.add_child(n)
	match_node.set_meta("hero_vfx", n)
	return n

## A Hero's data (empty until it has a content/vfx file).
static func data(arch: String) -> Dictionary:
	if not _data.has(arch):
		var path := "res://content/vfx/%s.json" % arch
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
		_data[arch] = parsed if parsed is Dictionary else {}
	return _data[arch]

## Swaps in a Hero's data (checks and the reel: a synthetic recipe set); an empty dictionary reloads the file.
static func set_data(arch: String, d: Dictionary) -> void:
	if d.is_empty():
		_data.erase(arch)
	else:
		_data[arch] = d

## Every Hero that has a data file.
static func heroes() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at("res://content/vfx"):
		if f.ends_with(".json"):
			out.append(f.get_basename())
	return out

## The viewer's share of an effect: yours and enemies' at full, allies' dimmer.
func view_k(h: Hunter) -> float:
	var viewer: Variant = m.get("player")
	if viewer == null or viewer == h or (viewer as Ent).team != h.team:
		return 1.0
	return ALLY_K

## The detail share at a spot from the camera focus: 1 near, LOD_MID_K further, 0 past LOD_FAR.
func lod_at(at: Vector3) -> float:
	var dist := Vector2(at.x - Sfx.listener.x, at.z - Sfx.listener.z).length()
	if dist > LOD_FAR:
		return 0.0
	return 1.0 if dist <= LOD_NEAR else LOD_MID_K

## Where a named FX anchor is now. In order: a node on the model (the .glb's anchor empties; the first of the data's
## "nodes" that exists), a point in the Gun's space ("gun": any model holds its weapon there), else an offset from
## the body along the aim ("body": [side, up, forward]), so a Hero's looks work before its model has the anchors.
func anchor_pos(h: Hunter, anchor_name: String) -> Vector3:
	var a: Dictionary = (data(h.arch).get("anchors", {}) as Dictionary).get(anchor_name, {})
	var node := _anchor_node(h, anchor_name, a)
	if node != null:
		return node.global_position
	if a.has("bone"):
		var on_bone := _bone_pos(h, String(a["bone"]), _vec(a.get("off", [0.0, 0.0, 0.0])))
		if on_bone != Vector3.INF:
			return on_bone
	var gun: Node3D = h.model.get_node_or_null("Rig/Torso/Aim/Gun") if h.model else null
	if gun != null and gun.is_inside_tree() and a.has("gun"):
		return gun.global_transform * _vec(a["gun"])
	if a.has("hand") and h.ak != null:
		return h.ak.hand_pos(String(a["hand"]) == "r")
	var body := _vec(a.get("body", [0.0, 1.0, 0.0]))
	var aim := h.aim_dir()
	return h.pos + Vector3(aim.x * body.z - aim.y * body.x, body.y, aim.y * body.z + aim.x * body.x)

func _anchor_node(h: Hunter, anchor_name: String, a: Dictionary) -> Node3D:
	if h.model == null or not h.model.is_inside_tree():
		return null
	# looked up once per model (a miss too: today's models have none of these, and this runs every frame)
	var key := "%d/%s" % [h.model.get_instance_id(), anchor_name]
	if _anchors.has(key):
		return _anchors[key] if is_instance_valid(_anchors[key]) else null
	_anchors[key] = null
	for n in a.get("nodes", []):
		var an := WardenGlb.anchor(h.model, String(n))
		if an != null:
			_anchors[key] = an
			return an
	return null

## A point on one of the model's contract bones (docs/RIG_STANDARD.md: "hand.R", "head", ...), `off` in the bone's
## own space; INF on a model without a skeleton or that bone (the bone index is looked up once per model).
func _bone_pos(h: Hunter, bone: String, off: Vector3) -> Vector3:
	if h.model == null or not h.model.is_inside_tree():
		return Vector3.INF
	var key := "%d/bone/%s" % [h.model.get_instance_id(), bone]
	if not _anchors.has(key):
		var sk := WardenGlb.skeleton(h.model.get_node_or_null("Warden"))
		var bi := WardenSkeleton.find(sk, bone) if sk else -1
		_anchors[key] = [sk, bi] if bi >= 0 else null
	var hit: Variant = _anchors[key]
	if hit == null or not is_instance_valid(hit[0]):
		return Vector3.INF
	var sk2: Skeleton3D = hit[0]
	return sk2.global_transform * (sk2.get_bone_global_pose(int(hit[1])) * off)

static func _vec(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2]))

func _rec(h: Hunter, move: String) -> Dictionary:
	return (data(h.arch).get("moves", {}) as Dictionary).get(move, {})

## A moment of a Hero's kit: its sounds and its looks. `o` fills the sizes the data leaves to the kit (see _num:
## "r", "len", "w"), "k" is the move's charge 0..1, "flip" mirrors a sweep, a true key in `o` turns on the layers
## that name it with "when" (a move's "full" or "hit" version).
func play(h: Hunter, move: String, at: Vector3, dir: Vector2, o := {}) -> void:
	var rec := _rec(h, move)
	if rec.is_empty():
		return
	plays[move] = int(plays.get(move, 0)) + 1
	if bool(rec.get("net", true)) and m.get("net_on") and not h.remote:
		m.net_fx(["hvfx", h.nid, move, m._r(at.x), m._r(at.y), m._r(at.z), snappedf(dir.x, 0.01), snappedf(dir.y, 0.01),
				snappedf(float(o.get("k", 0.0)), 0.01), snappedf(float(o.get("len", 0.0)), 0.1),
				snappedf(float(o.get("r", 0.0)), 0.1)])
	_sounds(rec, h, at, o)
	var lod := lod_at(at)
	if lod <= 0.0 or (h.unseen and h != m.get("player")):
		return
	for layer: Dictionary in rec.get("fx", []):
		if not _wanted(layer, o) or (lod < 1.0 and bool(layer.get("near", false))):
			continue
		var delay := float(layer.get("delay", 0.0))
		if delay > 0.0:
			m.later(delay, _layer.bind(layer, h, at, dir, o, lod))
		else:
			_layer(layer, h, at, dir, o, lod)

## The same moment arriving from another game (["fx", "hvfx", ...]: other players' games don't run this kit).
func net_in(x: Array) -> void:
	var who: Variant = m.ents_by_id.get(String(x[2]), null)
	if who is Hunter:
		play(who, String(x[3]), Vector3(x[4], x[5], x[6]), Vector2(x[7], x[8]),
				{"k": float(x[9]), "len": float(x[10]), "r": float(x[11])})

## Only the move's sounds (a grunt, a step of a move that draws nothing).
func _sounds(rec: Dictionary, h: Hunter, at: Vector3, o: Dictionary) -> void:
	var k := float(o.get("k", 0.0))
	for s: Dictionary in rec.get("sfx", []):
		if not _wanted(s, o):
			continue
		var vol := float(s.get("db", 0.0)) + (0.0 if h.is_local() else float(s.get("other", -4.0)))
		var pitch := float(s.get("pitch", 1.0)) + float(s.get("pitch_k", 0.0)) * k + float(o.get("pitch", 0.0))
		var pos: Variant = h.pos if s.get("at") == "h" else at
		if s.get("at") == "all":
			pos = null          # heard anywhere on the map
		var delay := float(s.get("delay", 0.0))
		if delay > 0.0:
			m.later(delay, Sfx.play.bind(String(s["n"]), pos, vol, float(s.get("var", 0.05)), pitch))
		else:
			Sfx.play(String(s["n"]), pos, vol, float(s.get("var", 0.05)), pitch)

static func _wanted(entry: Dictionary, o: Dictionary) -> bool:
	if entry.has("when") and not o.get(String(entry["when"]), false):
		return false
	return not (entry.has("unless") and o.get(String(entry["unless"]), false))

## A size in the data: a number, or the name of what the kit passed in `o`, scaled by "<key>_x" and by the charge
## with "<key>_k" (1.5: half as big again at full).
func _num(layer: Dictionary, key: String, o: Dictionary, fallback := 1.0) -> float:
	var v: Variant = layer.get(key, fallback)
	var n := float(o.get(v, fallback)) if v is String else float(v)
	n *= float(layer.get(key + "_x", 1.0))
	if layer.has(key + "_k"):
		n *= 1.0 + float(layer[key + "_k"]) * float(o.get("k", 0.0))
	return n

func _pal(h: Hunter, name_or_hex: Variant, fallback: String) -> Color:
	var pal: Dictionary = data(h.arch).get("palette", {})
	var key := String(name_or_hex) if name_or_hex != null else fallback
	return Color(String(pal.get(key, key)))

func _where(layer: Dictionary, h: Hunter, at: Vector3, dir: Vector2, o := {}) -> Vector3:
	var from := String(layer.get("at", "here"))
	var p := at
	if from == "h":
		p = h.pos
	elif from != "here":
		p = anchor_pos(h, from)
	var fwd := _num(layer, "fwd", o, 0.0)
	return p + Vector3(dir.x * fwd, float(layer.get("y", 0.0)), dir.y * fwd)

func _layer(layer: Dictionary, h: Hunter, at: Vector3, dir: Vector2, o: Dictionary, lod: float) -> void:
	if not is_instance_valid(h):
		return
	var kind := String(layer["p"])
	if MODES.has(kind):
		if kind == "ribbon":
			_ribbon(layer, h, o)
		elif kind == "bolt":
			var from := _where(layer, h, at, dir, o)
			_bolt(layer, h, from, _bolt_end(layer, h, from, dir, o), o)
		else:
			_surface(kind, layer, h, _where(layer, h, at, dir, o), dir, o)
	else:
		_burst(kind, layer, h, _where(layer, h, at, dir, o), dir, o, lod)

# ------------------------------------------------------------------ pooled nodes
func _take(kind: String, build: Callable) -> Node3D:
	var arr: Array = pools.get(kind, [])
	pools[kind] = arr
	for n in arr:
		if not (n as Node3D).visible:
			(n as Node3D).visible = true
			return n
	if arr.size() < int(POOL[kind]):
		var fresh: Node3D = build.call()
		fresh.top_level = true
		add_child(fresh)
		arr.append(fresh)
		made += 1
		return fresh
	var old: Node3D = arr.pop_front()
	arr.append(old)
	_drop_entry(old)
	return old

func _drop_entry(node: Node3D) -> void:
	for list: Array in [live, ribbons]:
		for e in list:
			if e["node"] == node:
				list.erase(e)
				return
	for e in motes:
		if e["node"] == node:
			live_n -= int(e["n"])
			motes.erase(e)
			return
	for key: String in holds:
		for lay: Dictionary in holds[key]["layers"]:
			if lay["node"] == node:
				live_n -= int(lay["n"])
				(holds[key]["layers"] as Array).erase(lay)
				return

func _surface_node(kind: String) -> Node3D:
	var mi := MeshInstance3D.new()
	var mt := ShaderMaterial.new()
	mt.shader = SURFACE
	mt.set_shader_parameter("mode", MODES[kind])
	mi.material_override = mt
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match kind:
		"scorch", "thread":
			var plane := PlaneMesh.new()
			plane.size = Vector2.ONE
			mi.mesh = plane
		"skirt":
			mi.mesh = _cylinder()
		"flare":
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE
			mi.mesh = quad
			mt.set_shader_parameter("billboard", true)
		"bolt":
			var strip := QuadMesh.new()
			strip.size = Vector2.ONE
			strip.center_offset = Vector3(0.5, 0, 0)          # from the origin along +X: A at 0, B at 1
			mi.mesh = strip
		"vortex":
			var disc := PlaneMesh.new()
			disc.size = Vector2.ONE
			mi.mesh = disc
		"ribbon":
			mi.mesh = ImmediateMesh.new()
			mi.extra_cull_margin = 16.0
	return mi

## A unit arc in the ground plane centred on +Z: UV.x along it, UV.y from the outer edge to the inner.
func _arc(deg: float) -> ArrayMesh:
	var key := int(deg)
	if _arcs.has(key):
		return _arcs[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in ARC_SEGS + 1:
		var u := float(i) / ARC_SEGS
		var a := deg_to_rad(deg) * (u - 0.5)
		var way := Vector3(sin(a), 0, cos(a))
		st.set_uv(Vector2(u, 0))
		st.add_vertex(way)
		st.set_uv(Vector2(u, 1))
		st.add_vertex(way * SWEEP_INNER)
	_arcs[key] = st.commit()
	return _arcs[key]

## An open unit cylinder: UV.x round it, UV.y from the foot to the top.
func _cylinder() -> ArrayMesh:
	if _cyl:
		return _cyl
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in ARC_SEGS * 2 + 1:
		var u := float(i) / (ARC_SEGS * 2)
		var a := TAU * u
		var way := Vector3(sin(a), 0, cos(a))
		st.set_uv(Vector2(u, 0))
		st.add_vertex(way)
		st.set_uv(Vector2(u, 1))
		st.add_vertex(way + Vector3.UP)
	_cyl = st.commit()
	return _cyl

## One of every kind held up at `at` on the loading screen (Match.warm_up, once per view, then prewarm_end), so the
## first cast compiles nothing. Particles have to run and a trail needs a surface, or their shaders are never built.
func prewarm(at: Vector3) -> void:
	if _warming.is_empty():
		for kind: String in POOL:
			_warming.append(_prewarm_node(kind))
	for node: Node3D in _warming:
		node.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO if node.get_meta("strip", false) else at)

func prewarm_end() -> void:
	for node: Node3D in _warming:
		node.visible = false
		if node is GPUParticles3D:
			(node as GPUParticles3D).emitting = false
	_warming.clear()

func _prewarm_node(kind: String) -> Node3D:
	if not MODES.has(kind):
		var p: GPUParticles3D = _take(kind, _mote_node.bind(kind))
		p.amount_ratio = 2.0 / float(AMOUNT[kind])
		p.lifetime = PREWARM_LIFE
		p.one_shot = false
		p.emitting = true          # (a finished one-shot isn't drawn, and a loading frame can outlast its life)
		return p
	var mi: MeshInstance3D = _take(kind, _surface_node.bind(kind))
	if kind == "sweep":
		mi.mesh = _arc(120.0)
	elif kind == "ribbon":
		_prewarm_strip(mi.mesh)
		mi.set_meta("strip", true)
	return mi

func _prewarm_strip(mesh: ImmediateMesh) -> void:
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 3:
		mesh.surface_set_uv(Vector2(float(i) * 0.5, 0.0))
		mesh.surface_add_vertex(Vector3(float(i), 0.0, float(i % 2)) * 0.01)
	mesh.surface_end()

func _surface(kind: String, layer: Dictionary, h: Hunter, p: Vector3, dir: Vector2, o: Dictionary) -> void:
	var mi: MeshInstance3D = _take(kind, _surface_node.bind(kind))
	var mt: ShaderMaterial = mi.material_override
	var yaw := atan2(dir.x, dir.y) + deg_to_rad(float(layer.get("yaw", 0.0)))
	var extent := _num(layer, "size", o)
	var b := Basis(Vector3.UP, yaw)
	var s0 := Vector3.ONE * extent
	var s1 := s0
	match kind:
		"sweep":
			mi.mesh = _arc(float(layer.get("arc", 120.0)))
			b = b * Basis(Vector3(0, 0, 1), deg_to_rad(float(layer.get("tilt", 0.0))))
			var flip: bool = o.get("flip", false) != bool(layer.get("flip", false))
			s0 = Vector3(-extent if flip else extent, extent, extent)
			s1 = s0
		"scorch":
			var sh := String(layer.get("shape", "disc"))
			mt.set_shader_parameter("shape", SCORCH_SHAPES[sh])
			mt.set_shader_parameter("stitch", bool(layer.get("stitch", false)))
			if sh == "lane":
				var ln := _num(layer, "len", o, 4.0)
				var w := _num(layer, "w", o, 1.5)
				s0 = Vector3(w, 1.0, ln)
				p += Vector3(dir.x, 0, dir.y) * ln * 0.5
				mt.set_shader_parameter("aspect", ln / maxf(w, 0.1))
			else:
				s0 = Vector3(extent * 2.0, 1.0, extent * 2.0)
				mt.set_shader_parameter("arc", deg_to_rad(float(layer.get("arc", 60.0))) * 0.5)
			s1 = s0
			p.y += SCORCH_LIFT
		"thread":
			var ln := _num(layer, "len", o, 1.6)
			var w := _num(layer, "w", o, 0.5)
			s0 = Vector3(w, 1.0, ln)
			s1 = s0
			p += Vector3(dir.x, 0, dir.y) * ln * 0.5
			p.y += SCORCH_LIFT
		"skirt":
			var tall := _num(layer, "tall", o, 1.2)
			s0 = Vector3(extent * float(layer.get("from", 0.35)), tall, extent * float(layer.get("from", 0.35)))
			s1 = Vector3(extent, tall * 0.6, extent)
			mt.set_shader_parameter("arc", float(layer.get("arc", 1.0)))
		"flare":
			s0 = Vector3.ONE * extent
			s1 = s0 * float(layer.get("grow", 1.2))
		"vortex":
			s0 = Vector3(extent * 2.0, 1.0, extent * 2.0)
			s1 = s0 * float(layer.get("grow", 1.0))
			p.y += SCORCH_LIFT
			mt.set_shader_parameter("spin", float(layer.get("spin", 1.0)))
	mi.global_position = p
	mi.global_transform.basis = b * Basis.from_scale(s0)
	_paint(mt, layer, h)
	live.append({"node": mi, "mat": mt, "t": 0.0, "dur": _num(layer, "life", o, 0.4), "b": b, "s0": s0, "s1": s1})

func _paint(mt: ShaderMaterial, layer: Dictionary, h: Hunter) -> void:
	mt.set_shader_parameter("col", _pal(h, layer.get("c"), "main"))
	mt.set_shader_parameter("col2", _pal(h, layer.get("c2"), "hot"))
	mt.set_shader_parameter("col3", _pal(h, layer.get("c3"), "char"))
	mt.set_shader_parameter("seed", randf() * SEED_MAX)
	mt.set_shader_parameter("life", 0.0)
	mt.set_shader_parameter("gain", view_k(h))

func _ribbon(layer: Dictionary, h: Hunter, o: Dictionary) -> void:
	var mi: MeshInstance3D = _take("ribbon", _surface_node.bind("ribbon"))
	var mt: ShaderMaterial = mi.material_override
	_paint(mt, layer, h)
	mi.global_transform = Transform3D.IDENTITY
	(mi.mesh as ImmediateMesh).clear_surfaces()
	ribbons.append({"node": mi, "mat": mt, "h": h, "anchor": String(layer.get("at", "chest")), "t": 0.0,
			"dur": _num(layer, "life", o, 0.3), "tail": float(layer.get("tail", 0.2)),
			"width": _num(layer, "size", o, 0.4), "wave": float(layer.get("wave", 0.0)),
			"follow": o.get("follow") if layer.get("follow", false) else null, "pts": []})

## Where a bolt ends: the kit's `o.to`, else a named anchor ("to"), else `len` metres along the aim.
func _bolt_end(layer: Dictionary, h: Hunter, from: Vector3, dir: Vector2, o: Dictionary) -> Vector3:
	if o.get("to") is Vector3:
		return o["to"]
	if layer.has("to"):
		return anchor_pos(h, String(layer["to"]))
	var ln := _num(layer, "len", o, 3.0)
	return from + Vector3(dir.x, 0, dir.y) * ln

## A strip from `a` to `b` turned to face the camera: lightning (the layer's "jag") or a taut thread.
func _bolt(layer: Dictionary, h: Hunter, a: Vector3, b: Vector3, o: Dictionary) -> void:
	var span := b - a
	if span.length() < 0.05:
		return
	var mi: MeshInstance3D = _take("bolt", _surface_node.bind("bolt"))
	var mt: ShaderMaterial = mi.material_override
	_paint(mt, layer, h)
	mt.set_shader_parameter("jag", float(layer.get("jag", 0.0)))
	var cam := get_viewport().get_camera_3d()
	var view := -cam.global_basis.z if cam else Vector3.DOWN
	var side := span.cross(view).normalized()
	if side.length() < 0.5:
		side = Vector3.RIGHT
	var width := _num(layer, "size", o, 0.25)
	var b0 := Basis(span, side * width, span.cross(side).normalized() * width)
	mi.global_transform = Transform3D(b0, a)
	live.append({"node": mi, "mat": mt, "t": 0.0, "dur": _num(layer, "life", o, 0.25), "b": b0,
			"s0": Vector3.ONE, "s1": Vector3.ONE})

## A mesh trail that follows a projectile (its node) until it is gone, hidden, or TRAIL_MAX runs out: tracers,
## needles, thrown charges. The move's "ribbon" layers give its look; nothing else of the move plays.
func trail(h: Hunter, move: String, follow: Node3D, o := {}) -> void:
	var rec := _rec(h, move)
	if rec.is_empty() or follow == null or lod_at(follow.global_position) <= 0.0:
		return
	if h.unseen and h != m.get("player"):
		return
	plays[move] = int(plays.get(move, 0)) + 1
	for layer: Dictionary in rec.get("fx", []):
		if String(layer.get("p", "")) != "ribbon":
			continue
		_ribbon(layer, h, o)
		var e: Dictionary = ribbons[-1]
		e["follow"] = follow
		e["dur"] = minf(float(layer.get("life", TRAIL_MAX)), TRAIL_MAX)

func _mote_node(kind: String) -> Node3D:
	var p := GPUParticles3D.new()
	p.amount = AMOUNT[kind]
	p.local_coords = false
	p.one_shot = true
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-24, -6, -24), Vector3(48, 18, 48))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ShaderMaterial.new()
	pm.shader = MOTES
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mt := ShaderMaterial.new()
	mt.shader = MOTE
	mt.set_shader_parameter("look", LOOKS[kind])
	quad.material = mt
	p.draw_pass_1 = quad
	return p

## Sets an emitter up from a layer; returns how many particles it was allowed.
func _aim_emitter(p: GPUParticles3D, kind: String, layer: Dictionary, h: Hunter, way: Vector3, o: Dictionary,
		lod: float) -> int:
	var pm: ShaderMaterial = p.process_material
	var mt: ShaderMaterial = (p.draw_pass_1 as QuadMesh).material
	var form := String(layer.get("shape", "ball"))
	pm.set_shader_parameter("shape", SHAPES[form])
	pm.set_shader_parameter("radius", _num(layer, "radius", o, 0.2))
	pm.set_shader_parameter("span", way * _num(layer, "len", o, 1.0))
	if form == "arc":
		pm.set_shader_parameter("span", Vector3(deg_to_rad(_num(layer, "arc", o, 120.0)) * 0.5,
				atan2(float(o.get("dir_x", 0.0)), float(o.get("dir_y", 1.0))), _num(layer, "w", o, 1.0)))
	pm.set_shader_parameter("dir", way if form != "line" else Vector3.UP)
	pm.set_shader_parameter("spread", float(layer.get("spread", 0.5)))
	pm.set_shader_parameter("speed", _num(layer, "speed", o, 3.0))
	pm.set_shader_parameter("gravity", float(layer.get("grav", 0.0)))
	pm.set_shader_parameter("drag", float(layer.get("drag", 1.0)))
	pm.set_shader_parameter("curl", float(layer.get("curl", 1.0)))
	pm.set_shader_parameter("size", _num(layer, "size", o, 0.08))
	mt.set_shader_parameter("col", _pal(h, layer.get("c"), "main"))
	mt.set_shader_parameter("col2", _pal(h, layer.get("c2"), "hot"))
	mt.set_shader_parameter("col3", _pal(h, layer.get("c3"), "smoke" if kind == "smoke" else "char"))
	mt.set_shader_parameter("stretch", float(layer.get("stretch", 0.05)))
	mt.set_shader_parameter("gain", view_k(h))
	var want := _num(layer, "n", o, 12.0) * float(Settings.q("fx")) * lod * view_k(h)
	var room := maxi(0, MAX_LIVE - live_n)
	var n := mini(mini(int(want), int(AMOUNT[kind])), room)
	p.amount_ratio = float(n) / float(AMOUNT[kind])
	p.lifetime = _num(layer, "life", o, 0.5)
	return n

func _way(layer: Dictionary, dir: Vector2) -> Vector3:
	var flat := Vector3(dir.x, 0, dir.y)
	var up := Vector3(0, float(layer.get("lift", 0.15)), 0)
	if flat.length() <= 0.01:
		return Vector3.UP
	match String(layer.get("way", "up")):
		"fwd": return (flat + up).normalized()
		"back": return (-flat + up).normalized()
		"along": return flat.normalized()
	return Vector3.UP

func _burst(kind: String, layer: Dictionary, h: Hunter, p: Vector3, dir: Vector2, o: Dictionary, lod: float) -> void:
	var node: GPUParticles3D = _take(kind, _mote_node.bind(kind))
	var n := _aim_emitter(node, kind, layer, h, _way(layer, dir), o, lod)
	if n < 1:
		node.visible = false
		return
	node.global_transform = Transform3D(Basis.IDENTITY, p)
	node.one_shot = true
	node.explosiveness = float(layer.get("burst", 1.0))
	node.restart()
	live_n += n
	motes.append({"node": node, "t": 0.0, "dur": node.lifetime * 1.1, "n": n})

## A look that stays on the Hero until the kit hides it (the first "skirt" layer of `move`, seated on the body and
## not pooled: one per hunter, freed with the kit's nodes).
func shell(h: Hunter, move: String) -> MeshInstance3D:
	var layer: Dictionary = _rec(h, move)["fx"][0]
	var mi: MeshInstance3D = _surface_node("skirt")
	var mt: ShaderMaterial = mi.material_override
	_paint(mt, layer, h)
	mt.set_shader_parameter("arc", 1.0)
	mt.set_shader_parameter("life", float(layer.get("life", 0.0)))
	mt.set_shader_parameter("gain", float(layer.get("gain", 1.0)) * view_k(h))
	mi.scale = Vector3(float(layer["size"]), float(layer["tall"]), float(layer["size"]))
	h.add_child(mi)
	return mi

# ------------------------------------------------------------------ holds
## Something that lasts while the kit keeps asking, once per tick: a blade heating, a body burning. It follows its
## anchors, and it stops by itself within HOLD_LINGER when the asks stop, whichever way the move ended.
func hold(h: Hunter, move: String, k := 0.0, extra := {}) -> void:
	var key := "%d/%s" % [h.get_instance_id(), move]
	if holds.has(key):
		holds[key]["last"] = m.time
		holds[key]["k"] = k
		return
	var rec := _rec(h, move)
	var lod := lod_at(h.pos)
	if rec.is_empty() or lod <= 0.0 or (h.unseen and h != m.get("player")):
		return
	plays[move] = int(plays.get(move, 0)) + 1
	var layers: Array = []
	var o := {"k": k}
	var aim := h.aim_dir()
	o["dir_x"] = aim.x
	o["dir_y"] = aim.y
	o.merge(extra, true)
	for layer: Dictionary in rec.get("fx", []):
		if lod < 1.0 and bool(layer.get("near", false)):
			continue
		var kind := String(layer["p"])
		if kind == "string":
			if not _model_has(h, String(layer.get("skip_if", ""))):
				layers.append({"node": _string_node(layer, h), "layer": layer, "n": 0})
			continue
		var node: GPUParticles3D = _take(kind, _mote_node.bind(kind))
		var n := _aim_emitter(node, kind, layer, h, _way(layer, aim), o, lod)
		if n < 1:
			node.visible = false
			continue
		node.global_transform = Transform3D(Basis.IDENTITY, _where(layer, h, o.get("at", h.pos), aim))
		node.one_shot = false
		node.explosiveness = 0.0
		node.emitting = true
		live_n += n
		layers.append({"node": node, "layer": layer, "n": n})
	holds[key] = {"h": h, "last": m.time, "k": k, "layers": layers, "at": o.get("at")}

func _tick_holds() -> void:
	for key: String in holds.keys():
		var e: Dictionary = holds[key]
		var h: Variant = e["h"]
		if not is_instance_valid(h) or m.time - float(e["last"]) > HOLD_LINGER:
			_end_hold(e)
			holds.erase(key)
			continue
		var hunter: Hunter = h
		var aim := hunter.aim_dir()
		for lay: Dictionary in e["layers"]:
			if lay["node"] is GPUParticles3D:
				var node := lay["node"] as GPUParticles3D
				var base: Vector3 = hunter.pos if e["at"] == null else e["at"]
				node.global_position = _where(lay["layer"], hunter, base, aim)
				_reaim(node, lay["layer"], aim)
			else:
				_draw_string(lay, hunter)

## A hold's emitter turned to the aim now, so a stream along it follows a sweep (the particles already out keep
## their own way, as a hose's fire does).
func _reaim(p: GPUParticles3D, layer: Dictionary, aim: Vector2) -> void:
	if String(layer.get("way", "up")) == "up" or layer.get("shape") == "arc":
		return
	var way := _way(layer, aim)
	var pm: ShaderMaterial = p.process_material
	pm.set_shader_parameter("span", way * _num(layer, "len", {}, 1.0))
	if String(layer.get("shape", "ball")) != "line":
		pm.set_shader_parameter("dir", way)

func _end_hold(e: Dictionary) -> void:
	for lay: Dictionary in e["layers"]:
		var node: Node3D = lay["node"]
		if node is GPUParticles3D:
			(node as GPUParticles3D).emitting = false
			motes.append({"node": node, "t": 0.0, "dur": (node as GPUParticles3D).lifetime * 1.1, "n": lay["n"]})
		else:
			node.visible = false

## A thin glowing line through named anchors (a bowstring): a mesh trail node drawn fresh from them each frame.
func _string_node(layer: Dictionary, h: Hunter) -> Node3D:
	var mi: MeshInstance3D = _take("ribbon", _surface_node.bind("ribbon"))
	_paint(mi.material_override, layer, h)
	mi.global_transform = Transform3D.IDENTITY
	return mi

func _draw_string(lay: Dictionary, h: Hunter) -> void:
	var mesh: ImmediateMesh = (lay["node"] as MeshInstance3D).mesh
	mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var layer: Dictionary = lay["layer"]
	var half := float(layer.get("size", 0.05)) * 0.5
	var view := -cam.global_basis.z
	var pts: Array = (layer["through"] as Array).map(func(a): return anchor_pos(h, String(a)))
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var along: Vector3 = pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]
		var side := along.cross(view).normalized() * half
		mesh.surface_set_uv(Vector2(0.0, 0.0))
		mesh.surface_add_vertex(pts[i] + side)
		mesh.surface_set_uv(Vector2(0.0, 1.0))
		mesh.surface_add_vertex(pts[i] - side)
	mesh.surface_end()

## True when the Hero's model has this node ("" is never there): a look can stand down for one built in.
func _model_has(h: Hunter, node_name: String) -> bool:
	return node_name != "" and h.model != null and WardenGlb.anchor(h.model, node_name) != null

# ------------------------------------------------------------------ the running looks
func _process(delta: float) -> void:
	_tick_holds()
	for i in range(live.size() - 1, -1, -1):
		var e: Dictionary = live[i]
		e["t"] = float(e["t"]) + delta
		var u := float(e["t"]) / float(e["dur"])
		if u >= 1.0:
			(e["node"] as Node3D).visible = false
			live.remove_at(i)
			continue
		(e["mat"] as ShaderMaterial).set_shader_parameter("life", u)
		if e["s0"] != e["s1"]:
			var ease_out := 1.0 - (1.0 - u) * (1.0 - u)
			var now_scale: Vector3 = (e["s0"] as Vector3).lerp(e["s1"], ease_out)
			(e["node"] as Node3D).global_transform.basis = (e["b"] as Basis) * Basis.from_scale(now_scale)
	for i in range(motes.size() - 1, -1, -1):
		var e: Dictionary = motes[i]
		e["t"] = float(e["t"]) + delta
		if float(e["t"]) >= float(e["dur"]):
			(e["node"] as Node3D).visible = false
			live_n -= int(e["n"])
			motes.remove_at(i)
	for i in range(ribbons.size() - 1, -1, -1):
		if not _tick_ribbon(ribbons[i], delta):
			(ribbons[i]["node"] as Node3D).visible = false
			ribbons.remove_at(i)

## One mesh trail's frame: it samples its anchor while it runs, then the tail runs out. False once it's gone.
func _tick_ribbon(e: Dictionary, delta: float) -> bool:
	var h: Variant = e["h"]
	e["t"] = float(e["t"]) + delta
	var now := float(e["t"])
	var pts: Array = e["pts"]
	var follow: Variant = e["follow"]
	if follow != null and (not is_instance_valid(follow) or not (follow as Node3D).visible):
		e["dur"] = minf(float(e["dur"]), now)      # what it follows is gone: the tail runs out
	elif now <= float(e["dur"]) and is_instance_valid(h):
		var followed: Node3D = follow
		pts.push_front([followed.global_position if followed else anchor_pos(h, String(e["anchor"])), now])
		if pts.size() > RIBBON_SAMPLES:
			pts.pop_back()
	var tail := float(e["tail"])
	while not pts.is_empty() and now - float(pts[-1][1]) > tail:
		pts.pop_back()
	if pts.is_empty() and now > float(e["dur"]):
		return false
	_draw_ribbon(e, pts, now, tail)
	return true

func _draw_ribbon(e: Dictionary, pts: Array, now: float, tail: float) -> void:
	var mesh: ImmediateMesh = (e["node"] as MeshInstance3D).mesh
	mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if pts.size() < 2 or cam == null:
		return
	var view := -cam.global_basis.z
	var width := float(e["width"])
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var p: Vector3 = pts[i][0]
		var q: Vector3 = pts[mini(i + 1, pts.size() - 1)][0]
		var r: Vector3 = pts[maxi(i - 1, 0)][0]
		var along := (q - r).normalized()
		var side := along.cross(view).normalized()
		var age := clampf((now - float(pts[i][1])) / tail, 0.0, 1.0)
		var half := width * (1.0 - age) * 0.5
		p += side * float(e["wave"]) * age * sin(age * RIBBON_WAVES + float(pts[i][1]) * 9.0)
		mesh.surface_set_uv(Vector2(age, 0.0))
		mesh.surface_add_vertex(p + side * half)
		mesh.surface_set_uv(Vector2(age, 1.0))
		mesh.surface_add_vertex(p - side * half)
	mesh.surface_end()
