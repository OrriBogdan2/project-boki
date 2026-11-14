class_name HeroScarf
extends RefCounted
## The cloth ends a Hero's look trails off the body (content/vfx/<arch>.json "scarf": Claire's two frost-scarf
## tails). Each tail is a short rope of points pinned beside a bone anchor and drawn as one lit ribbon mesh: at rest
## it hangs behind the body with a slow ripple; moving, the air's drag streams it back against the motion and it
## flutters harder the faster she goes. HeroVfx runs it for every Hero on the map, local or not. A wearer keeps its
## pair of meshes while it plays and a gone wearer's pair goes back to the pool; the tails are off at the Low preset,
## past the far LOD and while the wearer is hidden.

const SHADER: Shader = preload("res://shaders/scarf_ribbon.gdshader")
const POINTS := 8              # rope points per tail, root to tip
const KEEP := 0.9              # the velocity kept per 1/60 s: the drag that streams a tail behind a run
const GRAVITY := 9.8           # m/s^2
const PULL := 0.12             # share of the way to the rest shape per 1/60 s at the root
const PULL_TIP := 0.02         # and at the tip (loose: it swings and lags)
const STREAM_SPEED := 7.0      # m/s at which the rest shape lies out furthest behind (a skate's glide)
const STREAM_MAX := 0.8        # the most it lifts toward level (a cloth end never stands out stiff)
const SPEED_RATE := 8.0        # 1/s: how fast the measured speed follows the body's (it smooths net jitter)
const BODY_R := 0.24           # m: tails stay this far out from the body's axis at her skirt and puff tail
const BODY_R_TOP := 0.12       # m: and at her shoulders (they lie on her back there)
const SKIRT_TOP := 0.95        # m up (model space) where the skirt's flare starts
const BACK_TOP := 1.2          # m up where her back is narrowest under the wrap
const FLOOR_UP := 0.05         # m a tail stays over her feet
const RIPPLE := 0.04           # m a tip wanders at rest
const RIPPLE_HZ := 0.3         # its slow sway
const FLUTTER := 0.8           # rad a tail twists about its length at full stream
const FLUTTER_HZ := 2.2        # how fast that twist runs down it
const SNAP := 1.5              # m the anchor moves in a frame that counts as a teleport (the rope starts over)
const OFF_PRESET := "low"      # the quality preset with no tails

var fx: HeroVfx
var wearers: Array[Wearer] = []
var made := 0                  # meshes made so far (tests: a returning wearer reuses its pool's)
var _free: Array[MeshInstance3D] = []
var _checked := {}             # hunter instance id -> the arch it was checked as
var _warm: MeshInstance3D      # the one drawn while the match loads, so the shader compiles then

## One Hero wearing a scarf: its data, its two tails and how fast it moves.
class Wearer:
	var h: Hunter
	var id := 0                # h's instance id (kept: a freed Hero's is gone with it)
	var arch := ""
	var cfg: Dictionary
	var tails: Array[Tail] = []
	var vel := Vector3.ZERO
	var last := Vector3.INF
	var t := 0.0

## One cloth end: its mesh and its rope (positions now and a step ago, world space).
class Tail:
	var node: MeshInstance3D
	var side := 1.0            # -1 her left, 1 her right
	var pts := PackedVector3Array()
	var prev := PackedVector3Array()

func _init(owner_fx: HeroVfx) -> void:
	fx = owner_fx

## A frame: picks up new wearers, lets go of gone ones, and moves and draws every shown tail.
func tick(dt: float) -> void:
	for h: Hunter in fx.m.get("hunters"):
		if String(_checked.get(h.get_instance_id(), "")) != h.arch:
			_check(h)
	var on := Settings.quality() != OFF_PRESET
	for i in range(wearers.size() - 1, -1, -1):
		var w := wearers[i]
		if not is_instance_valid(w.h) or w.h.arch != w.arch:
			_release(w)
			wearers.remove_at(i)
		elif on and _shown(w.h):
			_step(w, dt)
		else:
			_hide(w)

## The tails' root points now (tests: where a rope is pinned).
func roots(w: Wearer) -> Array[Vector3]:
	var anchor := fx.anchor_pos(w.h, String(w.cfg.get("at", "scarf")))
	var right := w.h.model.global_basis.x.normalized()
	var gap := float(w.cfg.get("gap", 0.07))
	return [anchor - right * gap, anchor + right * gap]

## While the match loads (HeroVfx.prewarm): one small ribbon drawn at `at`, so no Hero's first sight compiles it.
func prewarm(at: Vector3) -> void:
	if _warm == null:
		_warm = _node()
	var mesh: ImmediateMesh = _warm.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 4:
		var u := 1.0 if i >= 2 else 0.0
		var v := float(i % 2)
		mesh.surface_set_normal(Vector3.BACK)
		mesh.surface_set_uv(Vector2(u, v))
		mesh.surface_add_vertex(at + Vector3(0.1 * v, -0.1 * u, 0.0))
	mesh.surface_end()
	_warm.visible = true

## The match is in: the warm-up ribbon goes back to the pool.
func prewarm_end() -> void:
	if _warm != null:
		_warm.visible = false
		_free.append(_warm)
		_warm = null

func _check(h: Hunter) -> void:
	_checked[h.get_instance_id()] = h.arch
	var cfg: Dictionary = HeroVfx.data(h.arch).get("scarf", {})
	if cfg.is_empty() or wearers.any(func(w: Wearer): return w.h == h):
		return
	var w := Wearer.new()
	w.h = h
	w.id = h.get_instance_id()
	w.arch = h.arch
	w.cfg = cfg
	for side in [-1.0, 1.0]:
		var tail := Tail.new()
		tail.side = side
		tail.node = _take(h, cfg)
		w.tails.append(tail)
	wearers.append(w)

func _shown(h: Hunter) -> bool:
	if h.model == null or not h.model.is_visible_in_tree():
		return false
	# your own scarf always shows (the LOD listener is the camera's focus, which can lag behind a fast skate)
	if h == fx.m.get("player"):
		return true
	return not h.unseen and fx.lod_at(h.pos) > 0.0

func _node() -> MeshInstance3D:
	if not _free.is_empty():
		return _free.pop_back()
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.material_override = ShaderMaterial.new()
	(mi.material_override as ShaderMaterial).shader = SHADER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.extra_cull_margin = 4.0
	fx.add_child(mi)
	made += 1
	return mi

func _take(h: Hunter, cfg: Dictionary) -> MeshInstance3D:
	var mi := _node()
	var mt: ShaderMaterial = mi.material_override
	mt.set_shader_parameter("root_col", fx._pal(h, cfg.get("c"), "hot"))
	mt.set_shader_parameter("tip_col", fx._pal(h, cfg.get("c2"), "main"))
	mt.set_shader_parameter("seed", randf() * HeroVfx.SEED_MAX)
	mt.set_shader_parameter("gain", fx.view_k(h))
	mi.visible = false
	return mi

func _release(w: Wearer) -> void:
	_checked.erase(w.id)
	for tail in w.tails:
		tail.node.visible = false
		tail.pts.clear()
		_free.append(tail.node)

func _hide(w: Wearer) -> void:
	for tail in w.tails:
		tail.node.visible = false
		tail.pts.clear()        # (shown again, it starts from its rest shape, not from where it was)

func _step(w: Wearer, dt: float) -> void:
	var here := w.h.model.global_position
	if w.last != Vector3.INF and dt > 0.0 and here.distance_to(w.last) < SNAP:
		w.vel = w.vel.lerp((here - w.last) / dt, 1.0 - exp(-dt * SPEED_RATE))
	w.last = here
	w.t += dt
	var rs := roots(w)
	for i in w.tails.size():
		var tail := w.tails[i]
		_move(w, tail, rs[i], dt)
		_draw(w, tail)
		tail.node.visible = true

## The shape a tail hangs in now, root to tip: down and a little back and out, lifted back against the motion
## the faster the body moves, with a slow ripple toward the tip.
func _rest(w: Wearer, tail: Tail, root: Vector3) -> PackedVector3Array:
	var b := w.h.model.global_basis.orthonormalized()
	var flat := Vector3(w.vel.x, 0.0, w.vel.z)
	var stream := minf(flat.length() / STREAM_SPEED, 1.0) * STREAM_MAX
	var behind := -flat.normalized() if flat.length() > 0.1 else b.z
	var out_k := tail.side * float(w.cfg.get("splay", 0.06))
	var hang := Vector3.DOWN + b.z * float(w.cfg.get("back", 0.15)) + b.x * out_k
	var lie := hang.normalized().lerp(behind + Vector3.DOWN * 0.25, stream).normalized()
	var seg := float(w.cfg.get("len", 0.8)) / float(POINTS - 1)
	var out := PackedVector3Array()
	out.resize(POINTS)
	for i in POINTS:
		var u := float(i) / float(POINTS - 1)
		var ripple := sin(TAU * RIPPLE_HZ * w.t * (1.0 + 0.2 * tail.side) - u * 2.5) * RIPPLE * u * u
		out[i] = root + lie * seg * float(i) + b.x * ripple
	return out

## Verlet: momentum with the air's drag, gravity, a pull toward the rest shape (firm at the root, loose at the tip),
## then the links kept at length and the points kept out of her body and over the ground.
func _move(w: Wearer, tail: Tail, root: Vector3, dt: float) -> void:
	var want := _rest(w, tail, root)
	if tail.pts.size() != POINTS or tail.pts[0].distance_to(root) > SNAP:
		tail.pts = want.duplicate()
		tail.prev = want.duplicate()
	var k := clampf(dt * 60.0, 0.0, 3.0)
	var keep := pow(KEEP, k)
	var fall := Vector3.DOWN * GRAVITY * dt * dt
	for i in range(1, POINTS):
		var p := tail.pts[i]
		var v := (p - tail.prev[i]) * keep
		tail.prev[i] = p
		var pull := lerpf(PULL, PULL_TIP, float(i) / float(POINTS - 1))
		tail.pts[i] = (p + v + fall).lerp(want[i], 1.0 - pow(1.0 - pull, k))
	tail.pts[0] = root
	tail.prev[0] = root
	var seg := float(w.cfg.get("len", 0.8)) / float(POINTS - 1)
	var axis := w.h.model.global_position
	var body_k := w.h.model.global_basis.get_scale().y
	for i in range(1, POINTS):
		var d := tail.pts[i] - tail.pts[i - 1]
		var p := tail.pts[i - 1] + (d.normalized() * seg if d.length() > 1e-5 else want[i] - want[i - 1])
		var flat := Vector2(p.x - axis.x, p.z - axis.z)
		var up := (p.y - axis.y) / body_k
		var r := lerpf(BODY_R, BODY_R_TOP, smoothstep(SKIRT_TOP, BACK_TOP, up)) * body_k
		if flat.length() < r:
			var out := flat.normalized() if flat.length() > 1e-4 else Vector2(tail.side, 0.0)
			p = Vector3(axis.x + out.x * r, p.y, axis.z + out.y * r)
		p.y = maxf(p.y, axis.y + FLOOR_UP)
		tail.pts[i] = p

## The band through the rope's points: its width across her shoulders' line, twisting about its length as it
## flutters (the faster she goes, the more), lit with a real normal on both faces.
func _draw(w: Wearer, tail: Tail) -> void:
	var mesh: ImmediateMesh = tail.node.mesh
	mesh.clear_surfaces()
	var across := w.h.model.global_basis.x.normalized()
	var stream := minf(Vector2(w.vel.x, w.vel.z).length() / STREAM_SPEED, 1.0)
	var half := float(w.cfg.get("w", 0.13)) * 0.5
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in POINTS:
		var u := float(i) / float(POINTS - 1)
		var along := (tail.pts[mini(i + 1, POINTS - 1)] - tail.pts[maxi(i - 1, 0)]).normalized()
		var flat_side := (across - along * across.dot(along)).normalized()
		var twist := sin(TAU * FLUTTER_HZ * w.t - u * 4.0 + tail.side) * FLUTTER * stream * u
		var side := flat_side.rotated(along, twist) if along.length() > 0.5 else across
		var width := half * (1.0 + 0.25 * u)
		mesh.surface_set_normal(along.cross(side))
		mesh.surface_set_uv(Vector2(u, 0.0))
		mesh.surface_add_vertex(tail.pts[i] - side * width)
		mesh.surface_set_normal(along.cross(side))
		mesh.surface_set_uv(Vector2(u, 1.0))
		mesh.surface_add_vertex(tail.pts[i] + side * width)
	mesh.surface_end()
