class_name ShieldBreak
extends Node3D
## The one shield break, the same for every shield (an ability or heal shield, Cinder's Furnace Cloak, Tenzo's
## Molten Guard, a Boki's or a Fuse's shield, Albert's raised aegis): when a hit breaks it before it runs out, a
## jagged crack runs across the shell and is gone in CRACK_S, and a few shards drop off it, all in the owner's
## ability colour and sized to read from 30 m. No burst, ring or disc; every quality preset keeps it (the particle
## setting doesn't thin it). Pooled: nodes are made once, with the match. The game that owns the body plays it and
## sends it to the others ("fx" "sbrk").

const CRACK_S := 0.25       # s the crack shows: it runs across in RUN_S, holds, then fades out
const RUN_S := 0.06         # s the crack takes to run from one side of the shell to the other
const SHARD_S := 0.6        # s a shard falls before it is gone (fading over its last FADE_K of that)
const FADE_K := 0.35
const CRACK_W := 0.08       # m: crack line width (about 3 px at 30 m)
const SHARD_SIZE := Vector3(0.18, 0.22, 0.03)    # m: one shard, a thin triangle
const SEGS := 5             # straight pieces in the crack across the shell
const BRANCH := 2           # pieces in the short crack that forks off it
const SHARDS := 5           # shards per break
const JAG := 0.18           # the crack's side-to-side jag, times the shell's half width
const GRAVITY := 9.8        # m/s^2 on the shards
const BODY_LIFT := 0.9      # m above the feet (times the Hunter's scale): the body shell's centre
const BODY_HALF := Vector2(0.45, 0.8)    # m: the body shell's half width and half height (times the Hunter's scale)
const POOL_BREAKS := 6      # breaks that can show at once before the oldest pieces are reused
const SEG_POOL := POOL_BREAKS * (SEGS + BRANCH)
const SHARD_POOL := POOL_BREAKS * SHARDS

var m: Match
var played := 0                       # breaks shown so far (checks)
var live := 0                         # pieces showing (checks)
var last_col := Color.BLACK           # the colour of the last break (checks)
var _segs: Array[MeshInstance3D] = []
var _shards: Array[MeshInstance3D] = []
var _seg_age := PackedFloat32Array()      # s since its break; -1 = free
var _seg_delay := PackedFloat32Array()    # s after its break that it shows (the crack running across)
var _shard_age := PackedFloat32Array()    # s since dropped; -1 = free
var _shard_vel: Array[Vector3] = []
var _shard_spin: Array[Vector3] = []      # rotation axis times rad/s
var _next_seg := 0
var _next_shard := 0
var _rng := RandomNumberGenerator.new()

## The match's shield break, made with the match (Match._start).
static func of(match_node: Match) -> ShieldBreak:
	if match_node.has_meta("shield_break"):
		return match_node.get_meta("shield_break")
	var n := ShieldBreak.new()
	n.m = match_node
	n.name = "ShieldBreak"
	match_node.add_child(n)
	match_node.set_meta("shield_break", n)
	return n

## `h`'s body shield broke: cracks its shell in their ability colour.
static func body(h: Hunter) -> void:
	var s := float(h.cdat["scale"])
	of(h.m).play(h.position + Vector3(0, BODY_LIFT * s, 0), BODY_HALF * s, Arch.color(h.arch))

## A shell centred on `at` with half width / half height `half` breaks; `send`: tell the other games.
func play(at: Vector3, half: Vector2, col: Color, send := true) -> void:
	played += 1
	last_col = col
	if send:
		m.net_fx(["sbrk", at.x, at.y, at.z, half.x, half.y, col.to_html()])
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var n := (cam.global_position - at).normalized() if cam else Vector3.BACK
	var right := Vector3.UP.cross(n)
	right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT
	var up := n.cross(right)
	var face := at + n * half.x       # the shell's near face
	var a0 := _rng.randf_range(0.6, 1.0) * PI    # the crack starts high on one side and ends low on the other
	var pts: Array[Vector3] = []
	for i in SEGS + 1:
		var k := float(i) / SEGS
		var jag := 0.0 if i == 0 or i == SEGS else _rng.randf_range(-JAG, JAG)
		var p := Vector2(lerpf(cos(a0), -cos(a0), k) + jag, lerpf(sin(a0), -sin(a0), k) * 0.95)
		pts.append(face + right * p.x * half.x + up * p.y * half.y)
	for i in SEGS:
		_lay(pts[i], pts[i + 1], n, col, RUN_S * i / SEGS)
	var fork := pts[2]
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var dir := (pts[3] - pts[2]).normalized().rotated(n, _rng.randf_range(0.7, 1.0) * side)
	for i in BRANCH:
		var to := fork + dir * half.x * 0.45
		_lay(fork, to, n, col, RUN_S * (2 + i) / SEGS)
		fork = to
		dir = dir.rotated(n, _rng.randf_range(-0.5, 0.5))
	for i in SHARDS:
		var along := pts[1 + i % (SEGS - 1)]
		_drop(along, n * _rng.randf_range(0.6, 1.4) + right * _rng.randf_range(-1.3, 1.3)
			+ Vector3.UP * _rng.randf_range(0.5, 1.5), col)

## A break another game sent: ["sbrk", x, y, z, half_w, half_h, colour].
func net_in(x: Array) -> void:
	play(Vector3(x[2], x[3], x[4]), Vector2(x[5], x[6]), Color.html(String(x[7])), false)

func _ready() -> void:
	var quad := QuadMesh.new()
	var prism := PrismMesh.new()
	prism.size = SHARD_SIZE
	for i in SEG_POOL:
		_segs.append(_piece(quad))
		_seg_age.append(-1.0)
		_seg_delay.append(0.0)
	for i in SHARD_POOL:
		_shards.append(_piece(prism))
		_shard_age.append(-1.0)
		_shard_vel.append(Vector3.ZERO)
		_shard_spin.append(Vector3.ZERO)

func _piece(mesh: Mesh) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi

## One straight piece of crack from a to b on the plane facing `n`, shown after `delay` s.
func _lay(a: Vector3, b: Vector3, n: Vector3, col: Color, delay: float) -> void:
	var i := _next_seg
	_next_seg = (_next_seg + 1) % SEG_POOL
	if _seg_age[i] < 0.0:
		live += 1
	_seg_age[i] = 0.0
	_seg_delay[i] = delay
	var along := b - a
	var mi := _segs[i]
	mi.transform = Transform3D(Basis(along, n.cross(along.normalized()) * CRACK_W, n), (a + b) * 0.5)
	mi.visible = false
	(mi.material_override as StandardMaterial3D).albedo_color = col.lerp(Color.WHITE, 0.35)

func _drop(at: Vector3, vel: Vector3, col: Color) -> void:
	var i := _next_shard
	_next_shard = (_next_shard + 1) % SHARD_POOL
	if _shard_age[i] < 0.0:
		live += 1
	_shard_age[i] = 0.0
	_shard_vel[i] = vel
	_shard_spin[i] = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized() \
		* _rng.randf_range(8.0, 16.0)
	var mi := _shards[i]
	mi.transform = Transform3D(Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0.0)), at)
	mi.visible = true
	(mi.material_override as StandardMaterial3D).albedo_color = col

func _process(delta: float) -> void:
	step(delta)

func step(dt: float) -> void:
	if live == 0:
		return
	for i in SEG_POOL:
		if _seg_age[i] < 0.0:
			continue
		_seg_age[i] += dt
		var t := _seg_age[i]
		if t >= CRACK_S:
			_seg_age[i] = -1.0
			_segs[i].visible = false
			live -= 1
			continue
		_segs[i].visible = t >= _seg_delay[i]
		var mat := _segs[i].material_override as StandardMaterial3D
		mat.albedo_color.a = 1.0 - smoothstep(CRACK_S * 0.5, CRACK_S, t)
	for i in SHARD_POOL:
		if _shard_age[i] < 0.0:
			continue
		_shard_age[i] += dt
		var k := _shard_age[i] / SHARD_S
		if k >= 1.0:
			_shard_age[i] = -1.0
			_shards[i].visible = false
			live -= 1
			continue
		_shard_vel[i].y -= GRAVITY * dt
		var mi := _shards[i]
		mi.position += _shard_vel[i] * dt
		var spin := _shard_spin[i]
		mi.rotate(spin.normalized(), spin.length() * dt)
		(mi.material_override as StandardMaterial3D).albedo_color.a = clampf((1.0 - k) / FADE_K, 0.0, 1.0)
