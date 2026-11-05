class_name DredgeCoins
extends RefCounted
## Grimble's hoard spills: a hit knocks a few coins off the heap behind his head (cosmetic, 3D model only).
## Gold discs on one CPU burst per hunter, in world space. The heap is the anchor `anchor_coins`.

const AMOUNT := 7
const GAP := 0.35             # s between spills, however fast the hits come
const COIN := Color("f5b81f")

var seen := -99.0
var last := -99.0
var burst: CPUParticles3D

## One frame; hurt_at is Hunter.hurt_at. shown: the kit's tells_visible (not for an enemy out of sight).
func tick(h: Hunter, now: float, shown: bool) -> void:
	if h.hurt_at == seen:
		return
	seen = h.hurt_at
	if not shown or now - last < GAP or now - h.hurt_at > 0.1:
		return
	var at := WardenGlb.anchor(h.model, "anchor_coins")
	if at == null or not at.is_inside_tree():
		return
	last = now
	if burst == null or not is_instance_valid(burst):
		burst = _make()
		h.model.add_child(burst)
	burst.global_position = at.global_position
	burst.restart()

func _make() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.055
	disc.bottom_radius = 0.055
	disc.height = 0.014
	disc.radial_segments = 7
	disc.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COIN
	mat.emission_enabled = true
	mat.emission = COIN
	mat.emission_energy_multiplier = 0.35
	disc.material = mat
	p.mesh = disc
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.9
	p.amount = AMOUNT
	p.lifetime = 0.8
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 2.2
	p.initial_velocity_max = 3.8
	p.gravity = Vector3(0, -11.0, 0)
	p.angular_velocity_min = 300.0
	p.angular_velocity_max = 720.0
	return p
