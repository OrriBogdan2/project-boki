class_name KinTypeTrail
extends Node3D
## A light trail behind every Boki that is moving, in its type's colour (KinTypeFx.LOOKS): embers climb
## off Fire, drips fall off Water, leaves flutter off Grass, Electric crackles. Summoned and wild Boki
## alike. The capture pop takes the same colour (colour()).
## Cheap on purpose: four GPUParticles3D shared by all Boki (one per GROUPS entry), fed one particle at
## a time with emit_particle, so a crowd costs the same four draw calls as one Boki. Nothing is emitted
## for a Boki that is hidden, parked, knocked out or far from the local player.

## Per group: the types in it and how its particles move. life = seconds, rise = m/s up (negative falls),
## drift = random sideways m/s, grav = m/s² down (negative floats up), size = particle scale, streak =
## drawn as a velocity-aligned spark (shaders/spark.gdshader) instead of a soft dot.
const GROUPS := {
	"rise": {"types": ["fire", "spore", "psychic", "fairy", "dark", "poison", "dragon"],
		"life": 0.9, "rise": 0.9, "drift": 0.3, "grav": -0.5, "size": 1.0, "streak": false},
	"drip": {"types": ["water", "ice", "rock"],
		"life": 0.5, "rise": -0.5, "drift": 0.4, "grav": 9.0, "size": 1.1, "streak": false},
	"flutter": {"types": ["grass", "bug", "normal", "flying"],
		"life": 1.0, "rise": 0.4, "drift": 1.1, "grav": 1.2, "size": 1.0, "streak": false},
	"zap": {"types": ["electric", "steel", "crystal", "sound"],
		"life": 0.16, "rise": 0.0, "drift": 4.5, "grav": 0.0, "size": 1.0, "streak": true},
}
const INTERVAL := 0.12        # s between particles of one moving Boki at full quality
const MIN_SPEED := 0.5        # m/s: slower than this is standing still
const MAX_RANGE := 45.0       # m from the local player: further Boki leave no trail
const POOL := 64              # live particles per group
const WORLD_BOX := AABB(Vector3(-400, -50, -400), Vector3(800, 150, 800))   # particles are never culled by a tiny box
const HIDDEN_STATES := ["shoulder", "bench", "away", "fused", "downed", "dazed"]

var emitted := 0              # particles emitted so far (checks read it)
var _group_of := {}           # type -> group name
var _emitters := {}           # group name -> GPUParticles3D

static func of(fx: Fx) -> KinTypeTrail:
	var t := fx.get_node_or_null("KinTypeTrail") as KinTypeTrail
	if t == null:
		t = KinTypeTrail.new()
		t.name = "KinTypeTrail"
		fx.add_child(t)
	return t

## The colour of a Boki's type, `fallback` for one with none.
static func colour(type: String, fallback: Color) -> Color:
	var look: Dictionary = KinTypeFx.LOOKS.get(type, {})
	return Color(String(look["col"])) if not look.is_empty() else fallback

func _ready() -> void:
	var dot := QuadMesh.new(); dot.size = Vector2(0.12, 0.12)
	var dot_mat := ShaderMaterial.new(); dot_mat.shader = load("res://shaders/fx_dot.gdshader")
	var streak := QuadMesh.new(); streak.size = Vector2(1, 1)
	var streak_mat := ShaderMaterial.new(); streak_mat.shader = load("res://shaders/spark.gdshader")
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1)); ramp.set_color(1, Color(1, 1, 1, 0))
	var fade := GradientTexture1D.new(); fade.gradient = ramp
	for g: String in GROUPS:
		var def: Dictionary = GROUPS[g]
		var pm := ParticleProcessMaterial.new()
		pm.gravity = Vector3(0, -float(def["grav"]), 0)
		pm.color_ramp = fade
		pm.particle_flag_align_y = def["streak"]
		var sz := float(def["size"])
		pm.scale_min = (0.03 if def["streak"] else 0.6) * sz
		pm.scale_max = (0.05 if def["streak"] else 1.2) * sz
		var p := GPUParticles3D.new()
		p.emitting = false
		p.amount = POOL
		p.lifetime = float(def["life"])
		p.local_coords = false
		p.process_material = pm
		p.draw_pass_1 = streak if def["streak"] else dot
		p.material_override = streak_mat if def["streak"] else dot_mat
		p.visibility_aabb = WORLD_BOX
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_emitters[g] = p
		for t: String in def["types"]:
			_group_of[t] = g

## Called every frame by a Boki (Kin.render). `t` is its running timer: returns it advanced or reset.
func tick(k: Kin, t: float, delta: float, quality: float) -> float:
	var v := Vector2(k.vel.x, k.vel.z)
	if not k.visible or k.unseen or k.state in HIDDEN_STATES or v.length() < MIN_SPEED:
		return 0.0
	t += delta
	if t < INTERVAL / maxf(quality, 0.1):
		return t
	var group := String(_group_of.get(String(k.sp.get("type", "")), ""))
	var player: Hunter = k.m.player
	if group != "" and (player == null or player.pos.distance_to(k.pos) < MAX_RANGE):
		_emit(group, k, v)
	return 0.0

func _emit(group: String, k: Kin, v: Vector2) -> void:
	var def: Dictionary = GROUPS[group]
	var p: GPUParticles3D = _emitters[group]
	var drift := float(def["drift"])
	var back := -v.normalized() * 0.3 * k.r
	var at := k.pos + Vector3(back.x + randf_range(-0.2, 0.2), 0.15 + randf() * 0.4, back.y + randf_range(-0.2, 0.2))
	var vel := Vector3(randf_range(-drift, drift), float(def["rise"]), randf_range(-drift, drift))
	var col := colour(String(k.sp.get("type", "")), Color.WHITE)
	p.emit_particle(Transform3D(Basis.IDENTITY, p.to_local(at)), vel, col, Color.WHITE,
		GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR)
	emitted += 1
