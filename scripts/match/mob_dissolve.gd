class_name MobDissolve
extends RefCounted
## How a camp creature and a lair boss die: the body is eaten away on a noise field (feet first,
## a hot rim on the edge) while a little ash drifts up, then the drops spill out where it stood.
## Shared by all seven monsters and the three bosses. No blast: only things that truly explode
## (the puffbomb's fuse, the boss finale in Juice) get one. Shader: shaders/mob_dissolve.gdshader.

const SHADER: Shader = preload("res://shaders/mob_dissolve.gdshader")
const DUR_MIN := 0.3            # s, the smallest monster (radius <= R_SMALL)
const DUR_MAX := 0.6            # s, a lair boss (radius >= R_BIG)
const R_SMALL := 0.45           # m
const R_BIG := 1.35             # m
const SPILL_AT := 0.8           # share of the dissolve gone before the drops spill
const LOW_FX := 0.5             # Settings fx below this (the Low preset): no shader swap, no ash
const LOW_DUR_K := 0.7          # a Low-preset dissolve is this much shorter
const STAGGER_S := 0.12         # s of lag per creature already dying nearby
const STAGGER_MAX := 3          # at most this many queued behind each other
const STAGGER_NEAR := 8.0       # m, how close counts as the same wipe
const STAGGER_WINDOW := 0.5     # s, how recent a nearby death counts
const ASH_PER_M := 8.0          # ash particles per metre of radius (before the quality factor)

static var _pool: Array[ShaderMaterial] = []      # dissolve materials free for the next death
static var made := 0                              # materials ever built: the most dying at once (checks read it)

static func _low() -> bool:
	return float(Settings.q("fx")) < LOW_FX

static func duration(r: float) -> float:
	var d := lerpf(DUR_MIN, DUR_MAX, clampf((r - R_SMALL) / (R_BIG - R_SMALL), 0.0, 1.0))
	return d * LOW_DUR_K if _low() else d

## Called once as it dies: queues it behind others dying beside it (the staggered kill) and returns
## the seconds until its drops should spill.
static func begin(m: Match, mb: Mob) -> float:
	var queued := 0
	for o in m.mobs:
		if o == mb or not o.dead or not o.has_meta("dis_at") or mb.flat_dist(o) >= STAGGER_NEAR:
			continue
		if float(o.get_meta("dis_at")) > m.time - STAGGER_WINDOW:
			queued += 1
	var lag := minf(queued, STAGGER_MAX) * STAGGER_S
	mb.set_meta("dis_lag", lag)
	mb.set_meta("dis_at", m.time + lag)
	return lag + duration(mb.r) * SPILL_AT

## Every dead frame: advances the dissolve. Returns false once nothing of it is left to draw.
static func step(mb: Mob, delta: float) -> bool:
	mb.death_t += delta
	var dur := duration(mb.r)
	var t := mb.death_t - float(mb.get_meta("dis_lag", 0.0))
	if t >= dur:
		if mb.has_meta("dis_mat") and not mb.has_meta("dis_done"):
			mb.set_meta("dis_done", true)
			_pool.append(mb.get_meta("dis_mat"))
		return false
	var u := maxf(t, 0.0) / dur
	if t >= 0.0 and not mb.has_meta("dis_on"):
		_start(mb)
	if mb.model:
		var body := mb.model.get_node("Body") as Node3D
		body.scale = Vector3(1.0 + 0.15 * u, 1.0 - 0.4 * u * u, 1.0 + 0.15 * u)
	if mb.has_meta("dis_mat"):
		(mb.get_meta("dis_mat") as ShaderMaterial).set_shader_parameter("k", u)
	return true

static func _start(mb: Mob) -> void:
	mb.set_meta("dis_on", true)
	var col: Color = mb.md.get("color", Color.WHITE)
	if not _low():
		var mat := _take()
		mat.set_shader_parameter("tint", col)
		mat.set_shader_parameter("edge", col.lerp(Color(1.0, 0.9, 0.6), 0.6))
		mat.set_shader_parameter("height", 2.4 * mb.r + 0.6)
		mat.set_shader_parameter("origin", mb.pos)
		mat.set_shader_parameter("k", 0.0)
		mb.set_meta("dis_mat", mat)
		for mi in mb.model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
		mb.m.fx.motes(mb.pos + Vector3(0, mb.r + 0.2, 0), col, int(ASH_PER_M * mb.r) + 4)
	else:
		for mt in mb.mats:
			if mt is ShaderMaterial: mt.set_shader_parameter("flash", 0.6)

static func _take() -> ShaderMaterial:
	if not _pool.is_empty():
		return _pool.pop_back()
	made += 1
	var mt := ShaderMaterial.new()
	mt.shader = SHADER
	return mt
