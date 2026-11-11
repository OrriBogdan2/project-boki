class_name WaterFx
extends Node3D
## A Hunter in shallow water (HomeWater): a splash on landing in it, a spray along a dash and a short
## wake while running. Droplets only: no ring or disc decals (DECISIONS bans them on dashes and
## landings). Every effect restarts an emitter from a fixed pool made once, sized by the Hunter
## (size_of), and on the Low preset no pool is made and nothing shows.

const POOL := {"splash": 2, "spray": 6, "wake": 4}     # emitters per kind, made once (the oldest is reused)
const SPLASH_N := 22         # droplets in a splash for a size-1 Hunter (a hard fall adds up to as many again)
const SPRAY_N := 9           # droplets per spray puff for a size-1 Hunter
const WAKE_N := 5            # droplets per wake puff for a size-1 Hunter
const SPRAY_DT := 0.045      # s between spray puffs along a dash
const WAKE_DT := 0.09        # s between wake puffs while running
const WAKE_MIN_SPEED := 1.5  # m/s: slower wading leaves no wake
const SIZE_MAX := 1.3        # the biggest Hunter's splash grows to (so the pool stays in BUDGET)
const BUDGET := 220          # droplets the whole pool can hold at once on High (the check holds it to this)
const COL := Color(1, 1, 1, 0.95)      # white: it reads on the pale water

var pools := {"splash": [], "spray": [], "wake": []}     # kind -> its emitters
var next := {"splash": 0, "spray": 0, "wake": 0}         # kind -> the emitter the next puff reuses
var counts := {"splash": 0, "spray": 0, "wake": 0}       # puffs started per kind (checks read them)
var body_k := 1.0            # the Hunter's size (size_of), set as they step in
var spray_t := 0.0
var wake_t := 0.0

## The Hunter's size for the water: their hit radius over the Medium body's (the ring under your
## feet), so a bigger Hunter throws a bigger splash.
static func size_of(arch: String, cls: String) -> float:
	var cdat: Dictionary = Data.CLASSES[cls]
	return minf(SIZE_MAX, Arch.hit_r(arch, cdat) / float(Data.CLASSES["medium"]["hit_r"]))

func _ready() -> void:
	if Settings.quality() == "low":
		return
	var dot := QuadMesh.new()
	dot.size = Vector2(0.22, 0.22)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fx_dot.gdshader")
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.6, Color(1, 1, 1, 0.9))      # (held, then a quick fade)
	for kind in POOL:
		for i in int(POOL[kind]):
			var p := CPUParticles3D.new()
			p.one_shot = true
			p.emitting = false
			p.explosiveness = 0.9
			p.mesh = dot
			p.material_override = mat
			p.color = COL
			p.color_ramp = ramp
			p.local_coords = false
			p.damping_min = 1.0
			p.damping_max = 2.5
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			if kind == "splash": p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_height = 0.0
			add_child(p)
			pools[kind].append(p)
	set_body(1.0)

## Size the droplets for this Hunter (amounts change only here and on a splash: resizing reallocates).
func set_body(k: float) -> void:
	body_k = k
	var q := float(Settings.q("fx"))
	for p in pools["splash"]:
		p.emission_ring_radius = 0.6 * k      # (wide enough to show round the Hunter seen from above)
		p.emission_ring_inner_radius = 0.42 * k
	var n_spray := maxi(3, roundi(SPRAY_N * k * q))
	var n_wake := maxi(2, roundi(WAKE_N * k * q))
	for p in pools["spray"]:
		if p.amount != n_spray: p.amount = n_spray
		p.emission_sphere_radius = 0.3 * k
	for p in pools["wake"]:
		if p.amount != n_wake: p.amount = n_wake
		p.emission_sphere_radius = 0.12 * k

## Droplets in a splash: more for a harder fall (hard 0..1) and a bigger Hunter.
func _splash_n(hard: float) -> int:
	return maxi(4, roundi(SPLASH_N * (1.0 + hard) * body_k * float(Settings.q("fx"))))

## Every droplet the pool can have alive at once (splashes counted at their hardest).
func capacity() -> int:
	var n: int = pools["splash"].size() * _splash_n(1.0)
	for p in pools["spray"] + pools["wake"]: n += p.amount
	return n

## Landing in the water (or stepping in): a crown of droplets thrown up round the feet, higher from a
## harder fall (hard 0..1).
func splash(at: Vector3, hard: float) -> void:
	var p := _take("splash")
	if p == null: return
	var na := _splash_n(hard)
	if p.amount != na: p.amount = na
	_fire(p, at, Vector3.UP, 35.0, (3.2 + hard * 2.4) * sqrt(body_k), 0.6, 12.0)

## Each step in shallow water on the ground: a spray along a dash, a wake while running.
func move(at: Vector3, vel: Vector2, dashing: bool, d: float) -> void:
	var spd := vel.length()
	var back := Vector3(-vel.x, 0, -vel.y) / maxf(spd, 0.01)
	if dashing:
		spray_t -= d
		if spray_t <= 0.0:
			spray_t = SPRAY_DT
			var p := _take("spray")
			if p:
				_fire(p, at, (Vector3.UP + back * 0.5).normalized(), 60.0, 3.6 * sqrt(body_k), 0.45, 11.0)
		return
	spray_t = 0.0
	if spd < WAKE_MIN_SPEED:
		wake_t = 0.0
		return
	wake_t -= d
	if wake_t <= 0.0:
		wake_t = WAKE_DT
		var p := _take("wake")
		if p:
			var dir := (Vector3.UP * 0.8 + back).normalized()
			_fire(p, at + back * 0.2 * body_k, dir, 45.0, 1.6 * sqrt(body_k), 0.4, 7.0)

func _take(kind: String) -> CPUParticles3D:
	var pool: Array = pools[kind]
	if pool.is_empty():
		return null
	var p: CPUParticles3D = pool[next[kind]]
	next[kind] = (int(next[kind]) + 1) % pool.size()
	counts[kind] += 1
	return p

func _fire(p: CPUParticles3D, at: Vector3, dir: Vector3, spread: float, speed: float, life: float, grav: float) -> void:
	p.global_position = at
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.55
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -grav, 0)
	p.lifetime = life
	p.scale_amount_min = 0.6 * body_k
	p.scale_amount_max = 1.3 * body_k
	p.restart()
	p.emitting = true
