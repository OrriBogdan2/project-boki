class_name BjornFx
extends Node3D
## Bjorn's own effects, every one pooled (built once when the kit starts):
## - the thrown hammer (tumbling, a gold-orange glow and trail), planted tilted in the ground with a tall
##   gold beacon ray and rising chevrons over it
## - the held swing: the hammer spinning in his hand (the gun model's "Hammer" pivot), a glint on its head
##   from 0.6 s that grows, a flare at full charge
## - the slam's flaming crescent (180 degrees in front), the 360 Smash's swirl ring
## - his aegis: a curved gold slab with ribs, a hammer sigil and a bright rim, flashing on a block,
##   cracking as it weakens (the verbs wall underneath keeps the blocking; its plain slab is hidden)
## - Purify: the green light column coming down over the 1 s delay, then the rings

const GOLD := Color("ffc94a")
const EMBER := Color("ff8a2a")
const AEGIS := Color("ffe08a")
const GREEN := Color("7dffb0")

var h: Hunter
var hammer: Node3D            # the thrown hammer
var hammer_glow: MeshInstance3D
var trail: MeshInstance3D
var beacon: MeshInstance3D
var glint: MeshInstance3D
var flare: MeshInstance3D
var flare_t := 0.0
var crescent: MeshInstance3D
var cres_t := 0.0
var swirl: MeshInstance3D
var swirl_t := 0.0
var aegis: MeshInstance3D
var aegis_hit := 0.0
var column: MeshInstance3D
var disc: MeshInstance3D
var disc_t := 0.0
var disc_r := 1.0
var spin := 0.0               # the held hammer's spin (rad), and its speed
var spin_v := 0.0
var spin_on := false

func _init(hunter: Hunter) -> void:
	h = hunter
	top_level = true
	name = "BjornFx"

func _ready() -> void:
	hammer = Node3D.new()
	hammer.top_level = true
	hammer.visible = false
	add_child(hammer)
	PinBjornWeapons.hammer(hammer, 1.25)
	hammer_glow = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", Color(GOLD, 0.9)))
	trail = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("streak", Color(1.0, 0.7, 0.3, 0.9)))
	beacon = KitMeshes.inst(self, KitMeshes.pillar(0.18, 0.42, 7.0), KitShaders.mat("beam", GOLD))
	glint = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", Color("fff2c0")))
	flare = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", Color("ffd27a")))
	crescent = KitMeshes.inst(self, KitMeshes.band(0.9, 2.9, -PI * 0.5, PI * 0.5, 36), KitShaders.mat("crescent", Color(1.0, 0.62, 0.18)))
	swirl = KitMeshes.inst(self, KitMeshes.band(1.2, 2.3, 0.0, TAU, 48), KitShaders.mat("swirl", Color("ff4a2a")))
	swirl.material_override.set_shader_parameter("color2", Color("ffd25a"))
	aegis = KitMeshes.inst(self, KitMeshes.wall(1.6, -1.05, 1.05, 2.1, 28), KitShaders.mat("aegis", AEGIS))
	column = KitMeshes.inst(self, KitMeshes.pillar(0.9, 1.4, 9.0), KitShaders.mat("beam", GREEN))
	column.material_override.set_shader_parameter("speed", -1.2)
	disc = KitMeshes.inst(self, KitMeshes.band(0.2, 1.0, 0.0, TAU, 48), KitShaders.mat("swirl", GREEN))
	disc.material_override.set_shader_parameter("color2", Color("e8fff0"))

# ------------------------------------------------------------------ the thrown hammer
func hammer_fly(p: Vector3, dir: Vector2, spin_rate: float) -> void:
	hammer.visible = true
	hammer.global_position = p
	hammer.rotation = Vector3(Time.get_ticks_msec() * 0.001 * spin_rate, atan2(-dir.x, -dir.y), 0.0)
	beacon.visible = false
	hammer_glow.visible = true
	hammer_glow.global_position = p
	hammer_glow.scale = Vector3.ONE * 1.1
	trail.visible = true
	trail.global_position = p - Vector3(dir.x, 0, dir.y) * 1.0
	trail.rotation = Vector3(-PI * 0.5, atan2(-dir.x, -dir.y) + PI * 0.5, 0)
	trail.scale = Vector3(2.0, 0.45, 1.0)

## Planted: tilted in the ground, the beacon ray standing over it.
func hammer_plant(p: Vector3, yaw: float) -> void:
	hammer.visible = true
	hammer.global_position = p + Vector3(0, 0.75, 0)
	hammer.rotation = Vector3(-2.3, yaw, 0.25)
	hammer_glow.visible = false
	trail.visible = false
	beacon.visible = true
	beacon.global_position = p

func hammer_hide() -> void:
	hammer.visible = false
	hammer_glow.visible = false
	trail.visible = false
	beacon.visible = false

# ------------------------------------------------------------------ the held swing
## While LMB is held: the hammer spins in the hand faster as it charges; the glint on its head shows from
## 0.6 s and grows (k = the charge 0..1).
func hold(held_t: float, k: float) -> void:
	spin_on = true
	spin_v = lerpf(9.0, 22.0, k)
	var head := _head_world()
	glint.visible = held_t >= 0.6 and head != Vector3.INF
	if glint.visible:
		glint.global_position = head
		var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.025)
		glint.scale = Vector3.ONE * lerpf(0.35, 0.95, k) * pulse
		glint.material_override.set_shader_parameter("power", lerpf(0.6, 1.4, k))

func full_flare() -> void:
	flare_t = 0.28

func hold_end() -> void:
	spin_on = false
	glint.visible = false

## The hand's hammer pivot on the hunter's weapon model (PinBjornWeapons builds it), or null.
func _pivot() -> Node3D:
	if h.model == null:
		return null
	var gun := h.model.find_child("Gun", true, false)
	if gun == null:
		return null
	for c in gun.get_children():
		if c.has_meta("hammer_pivot") and not c.is_queued_for_deletion():
			return c as Node3D
	return null

func _head_world() -> Vector3:
	var pv := _pivot()
	if pv == null or not pv.is_inside_tree():
		return Vector3.INF
	return pv.to_global(Vector3(0, 0, -0.62))

## Shows or hides the hammer in his hand (it's out while thrown).
func in_hand(on: bool) -> void:
	var pv := _pivot()
	if pv: pv.visible = on

# ------------------------------------------------------------------ slam crescent and smash swirl
func slam(at: Vector3, dir: Vector2, k: float) -> void:
	crescent.visible = true
	crescent.global_position = at + Vector3(0, 0.55, 0)
	crescent.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
	crescent.scale = Vector3.ONE * lerpf(0.8, 1.05, k)
	cres_t = 0.26

func smash_ring(at: Vector3) -> void:
	swirl.visible = true
	swirl.global_position = at + Vector3(0, 0.35, 0)
	swirl_t = 0.38

# ------------------------------------------------------------------ the aegis
## Follows the raised shield (the verbs wall dict): its node is hidden, ours drawn in its place.
func aegis_show(w: Dictionary, hurt: float, armed: bool) -> void:
	var nd: Node3D = w.get("node")
	if nd and is_instance_valid(nd): nd.visible = false
	var a: Vector2 = w["a"]; var b: Vector2 = w["b"]
	var mid := (a + b) * 0.5
	var dir := Vector2(mid.x - h.pos.x, mid.y - h.pos.z).normalized()
	aegis.visible = true
	# the curve's centre sits behind the slab's midpoint so its apex is the wall line
	var c := Vector2(mid.x, mid.y) - dir * 1.6
	aegis.global_position = Vector3(c.x, float(w["y"]), c.y)
	aegis.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
	aegis.material_override.set_shader_parameter("hurt", hurt)
	aegis.material_override.set_shader_parameter("armed", 1.0 if armed else 0.0)

func aegis_hide() -> void:
	aegis.visible = false

func aegis_block(at: Vector3) -> void:
	aegis_hit = 1.0
	h.m.fx.spark(at, (at - h.pos).normalized(), Color("fff1a0"), 10, 8.0, 60.0, 0.22, 10.0, 1.0)

func aegis_break(at: Vector3) -> void:
	aegis.visible = false
	h.m.fx.burst(at + Vector3(0, 1.0, 0), GOLD, 26, 8.0, 0.55, 12.0, 1.3)
	h.m.fx.spark(at + Vector3(0, 1.0, 0), Vector3.UP, Color("fff1a0"), 16, 10.0, 160.0, 0.35, 14.0, 1.2)
	h.m.fx.ring(at, 2.0, GOLD, 0.3)

# ------------------------------------------------------------------ Purify
## The column coming down over the delay (u 0 -> 1), then the disc's rings.
func purify(at: Vector3, r: float, u: float) -> void:
	column.visible = u < 1.0
	if column.visible:
		var g := AimMode.ground(h.m, at)
		column.global_position = g + Vector3(0, lerpf(9.0, 0.0, minf(1.0, u * 1.6)), 0)
		column.scale = Vector3(r / 1.4, 1.0, r / 1.4) * lerpf(0.5, 1.0, u)
		column.material_override.set_shader_parameter("power", 0.4 + 0.6 * u)

func purify_burst(at: Vector3, r: float) -> void:
	column.visible = false
	disc.visible = true
	disc.global_position = AimMode.ground(h.m, at) + Vector3(0, 0.07, 0)
	disc_r = r
	disc.scale = Vector3.ONE * r * 0.4
	disc_t = 0.9

func _process(delta_in: float) -> void:
	var delta := minf(delta_in, 1.0 / 30.0)      # long frames are clamped (a hitch never skips a whole effect)
	if not is_instance_valid(h):
		return
	var pv := _pivot()
	if spin_on:
		spin += spin_v * delta
		if pv: pv.rotation = Vector3(0, spin, 0)      # round the grip, flat: reads from the top-down camera
	elif pv and absf(pv.rotation.y) > 0.001:
		spin = 0.0
		pv.rotation = Vector3.ZERO
	if flare_t > 0.0:
		flare_t -= delta
		var head := _head_world()
		flare.visible = head != Vector3.INF and flare_t > 0.0
		if flare.visible:
			var u := 1.0 - flare_t / 0.28
			flare.global_position = head
			flare.scale = Vector3.ONE * lerpf(0.6, 2.2, sqrt(u))
			flare.material_override.set_shader_parameter("ring", 1.0)
			flare.material_override.set_shader_parameter("power", 1.8 * (1.0 - u))
	else:
		flare.visible = false
	if cres_t > 0.0:
		cres_t -= delta
		crescent.material_override.set_shader_parameter("life", clampf(cres_t / 0.26, 0.0, 1.0))
		crescent.visible = cres_t > 0.0
	if swirl_t > 0.0:
		swirl_t -= delta
		swirl.rotation.y += delta * 14.0
		swirl.material_override.set_shader_parameter("life", clampf(swirl_t / 0.38, 0.0, 1.0))
		swirl.scale = Vector3.ONE * lerpf(1.15, 0.85, clampf(swirl_t / 0.38, 0.0, 1.0))
		swirl.visible = swirl_t > 0.0
	if aegis_hit > 0.0:
		aegis_hit = maxf(0.0, aegis_hit - delta * 5.0)
	aegis.material_override.set_shader_parameter("hit", aegis_hit)
	if disc_t > 0.0:
		disc_t -= delta
		var u2 := 1.0 - disc_t / 0.9
		disc.scale = Vector3.ONE * disc_r * lerpf(0.4, 1.0, sqrt(u2))
		disc.material_override.set_shader_parameter("life", 1.0 - u2)
		disc.visible = disc_t > 0.0
	if beacon.visible:
		beacon.material_override.set_shader_parameter("power", 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006))
