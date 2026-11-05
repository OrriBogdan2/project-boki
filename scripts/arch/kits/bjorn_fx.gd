class_name BjornFx
extends Node3D
## Breaker's own pieces that stay on him or his hammer, built once when the kit starts (the moments, the sea
## spray, sweeps and the Faultline's path, are HeroVfx's: content/vfx/bulwark.json). The coloured ones are
## layered (KitShaders): an alpha-blended body with the glow on top, so they keep their colour on bright grass.
## - the thrown hammer (tumbling), planted head-down in the ground under an upright sea-green beacon
## - the held swing: the hammer whirled round him at arm's length, flat over his shoulder, with a sea-green
##   trail behind its head, a pale aqua glint on the head from 0.6 s that grows; at full charge a short
##   ring-free flash on it, the glint burning white-hot while the perfect window is open. It never stops until
##   he lets go: the charge motion only, the damage comes on the release
## - his aegis: a wall of forged plates (two rows, riveted, ribbed, a rim and a hammer boss) leaning out
##   toward the camera, rising out of the ground, flashing on a block and darkening as it weakens (the verbs
##   wall underneath keeps the blocking; its plain slab is hidden), with a pulsing double chevron in front of
##   it showing its push
## - Mending Ground: the green light column coming down over the 1 s delay

const GOLD := Color("ffc94a")
const AEGIS := Color("ffcb4f")
const GREEN := Color("7dffb0")
## his sea palette (content/vfx/bulwark.json): the beacon, and the glint and flash on the hammer head
const SEA := Color("1fb5a6")
const SEA_HOT := Color("9ffcea")
## s the full-charge flare shows (the sheet: one bright frame)
const FLARE_T := 0.12
## the whirled hammer: how far above the hand the circle runs (m), its tilt (rad, the head a little up) and the
## s it eases out of the hand into the circle
const ORBIT_RISE := 0.45
const ORBIT_TILT := 0.12
const WHIRL_IN := 0.12
## the whirl's trail ribbon: inner and outer radius (m at scale 1), how far past the head's circle its outer
## edge runs, how far it reaches back behind the head (rad; the arc runs from there to the head, so the streak's
## bright end rides the hammer), its colour, and its strength at the slowest turn rate and how much the fastest adds
const ORBIT_IN := 0.3
const ORBIT_OUT := 1.35
const ORBIT_PAST := 1.25
const ORBIT_ARC := 3.4
const ORBIT_COL := Color(0.12, 0.72, 0.66)
const ORBIT_POWER := 3.4
const ORBIT_FAST := 1.4
## the planted hammer's size, and its lean off vertical (rad)
const PLANT_SCALE := 1.9
const PLANT_LEAN := 0.25
## the aegis wall: radius (m), half its arc (rad), height (m) and how far its top leans out (m); its chord is
## about the wall's 4.2 m, its height 30% over the old slab's
const AEGIS_R := 2.6
const AEGIS_HALF := 0.92
const AEGIS_H := 1.7
const AEGIS_LEAN := 1.2
const PLATE_N := 7
const PLATE_COL := Color("c9953a")
const PLATE_EDGE := Color("8a6428")
const RIVET_COL := Color("f0d27a")
const BROKEN_COL := Color("4a3a30")
## s the wall takes to rise out of the ground, and how long a push flashes its chevron
const RISE_T := 0.2
const PUSH_FLASH_T := 0.2

var h: Hunter
var hammer: Node3D            # the thrown hammer (HeroVfx trails it)
var beacon: MeshInstance3D
var glint: MeshInstance3D
var flare: MeshInstance3D
var flare_t := 0.0
var orbit_trail: MeshInstance3D
var aegis: Node3D              # the plated wall
var plate_mats: Array = []     # [plate, edge] materials (flash and crack)
var aegis_hit := 0.0
var rise_t := 0.0
var push_flash := 0.0
var column: MeshInstance3D
var held := false              # the swing is being held: the hammer is whirling
var spin := 0.0                # the whirled hammer's angle (rad), from the kit (it counts the turns on match time)
var spin_k := 0.0              # 0..1 how far the turn rate is up (the charge)
var whirl_k := 0.0             # 0..1 how far the hammer has eased out of the hand into the circle
var hot := false               # the perfect window is open: the glint burns white-hot
var glint_k := -1.0            # the glint's size 0..1 while it shows (-1: not yet)
var fx_clock := 0.0            # the match time effects last advanced to

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
	beacon = KitMeshes.inst(self, KitMeshes.pillar(0.22, 0.4, 5.0), KitShaders.mat("beam", SEA, true))
	glint = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", SEA_HOT, true))
	flare = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", SEA_HOT, true))
	for star in [glint, flare]:
		KitShaders.param(star, "white", 0.25)
	var orbit_mesh := KitMeshes.band(ORBIT_IN, ORBIT_OUT, ORBIT_ARC, 0.0, 36)
	orbit_trail = KitMeshes.inst(self, orbit_mesh, KitShaders.mat("streak", ORBIT_COL, true))
	_build_aegis()
	column = KitMeshes.inst(self, KitMeshes.pillar(0.9, 1.4, 9.0), KitShaders.mat("beam", GREEN))
	column.material_override.set_shader_parameter("speed", -1.2)

## The wall of forged plates, built once: two rows of riveted plates along the arc, ribs between them, a
## rim along the top and a round boss with the hammer's cross in the middle. Local space: the curve's
## centre at the origin, the apex straight ahead (-Z).
func _build_aegis() -> void:
	aegis = Node3D.new()
	aegis.top_level = true
	aegis.visible = false
	add_child(aegis)
	var plate := Models.toon(PLATE_COL, true, 0.0)
	var edge := Models.toon(PLATE_EDGE, true, 0.0)
	var rivet := Models.toon(RIVET_COL, false, 0.2)
	plate_mats = [plate, edge]
	var tilt := atan2(AEGIS_LEAN, AEGIS_H)
	var seg := AEGIS_HALF * 2.0 / PLATE_N
	var width := 2.0 * AEGIS_R * sin(seg * 0.5)
	for i in PLATE_N:
		var b := lerpf(-AEGIS_HALF, AEGIS_HALF, (float(i) + 0.5) / PLATE_N)
		var facing := Vector3(-tilt, -b, 0.0)
		for row in 2:
			var y := AEGIS_H * (0.25 + 0.5 * float(row))
			var r := AEGIS_R + AEGIS_LEAN * (y / AEGIS_H)
			var at := Vector3(sin(b) * r, y, -cos(b) * r)
			Models.part(aegis, Models.box(width * 0.92, AEGIS_H * 0.45, 0.16), plate, at, Vector3.ONE, facing)
			for cx in [-0.38, 0.38]:
				var side := Vector3(cos(b), 0, sin(b)) * width * float(cx)
				var out := Vector3(sin(b), 0, -cos(b)) * 0.1
				Models.part(aegis, Models.box(0.09, 0.09, 0.07), rivet, at + side + out, Vector3.ONE, facing)
		var top_r := AEGIS_R + AEGIS_LEAN
		var rim_at := Vector3(sin(b) * top_r, AEGIS_H + 0.05, -cos(b) * top_r)
		Models.part(aegis, Models.box(width, 0.14, 0.34), edge, rim_at, Vector3.ONE, Vector3(0, -b, 0))
		var rb := b - seg * 0.5
		var rib_r := AEGIS_R + AEGIS_LEAN * 0.5
		var rib_at := Vector3(sin(rb) * rib_r, AEGIS_H * 0.5, -cos(rb) * rib_r)
		Models.part(aegis, Models.box(0.13, AEGIS_H * 1.02, 0.24), edge, rib_at, Vector3.ONE, Vector3(-tilt, -rb, 0))
	var boss_r := AEGIS_R + AEGIS_LEAN * 0.5 + 0.12
	var boss_at := Vector3(0, AEGIS_H * 0.5, -boss_r)
	Models.part(aegis, Models.box(0.55, 0.55, 0.14), edge, boss_at, Vector3.ONE, Vector3(-tilt, 0, PI * 0.25))
	var cross_tilt := Vector3(-tilt, 0, 0)
	var stem_at := boss_at + Vector3(0, 0, -0.06)
	Models.part(aegis, Models.box(0.12, 0.5, 0.1), rivet, stem_at, Vector3.ONE, cross_tilt)
	Models.part(aegis, Models.box(0.4, 0.12, 0.1), rivet, stem_at + Vector3(0, 0.12, 0), Vector3.ONE, cross_tilt)

# ------------------------------------------------------------------ the thrown hammer
## In flight at `p` along `dir`, tumbling at `spin_rate` rad/s.
func hammer_fly(p: Vector3, dir: Vector2, spin_rate: float) -> void:
	hammer.visible = true
	hammer.global_position = p
	hammer.rotation = Vector3(Time.get_ticks_msec() * 0.001 * spin_rate, atan2(-dir.x, -dir.y), 0.0)
	hammer.scale = Vector3.ONE
	beacon.visible = false

## Planted: standing head-down in the ground, leaning back along its flight, the beacon over it.
func hammer_plant(p: Vector3, yaw: float) -> void:
	hammer.visible = true
	hammer.scale = Vector3.ONE * PLANT_SCALE / 1.25
	# the head points down (-Z turned to -Y), leaning PLANT_LEAN off vertical
	hammer.rotation = Vector3(-PI * 0.5 - PLANT_LEAN, yaw, 0.0)
	var head_drop := 0.62 * PLANT_SCALE * cos(PLANT_LEAN)
	hammer.global_position = p + Vector3(0, head_drop - 0.2, 0)
	beacon.visible = true
	beacon.global_position = p

func hammer_hide() -> void:
	hammer.visible = false
	beacon.visible = false

# ------------------------------------------------------------------ the held swing
## While LMB is held (k = the charge 0..1): the hammer whirls round him at the kit's angle `turn` (rad); the glint
## on its head shows from 0.6 s and grows, white-hot while `window` (perfect) is open.
func hold(held_t: float, k: float, window: bool, turn: float) -> void:
	held = true
	spin = turn
	spin_k = k
	glint_k = k if held_t >= 0.6 else -1.0
	glint.visible = glint_k >= 0.0
	hot = window

## Full charge: the big gold star on the hammer head.
func full_flare() -> void:
	flare_t = FLARE_T

func hold_end() -> void:
	held = false
	whirl_k = 0.0
	hot = false
	glint_k = -1.0
	glint.visible = false
	orbit_trail.visible = false

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
	if pv:
		pv.visible = on

## The whirl: the hammer eases out of the hand into a flat circle over his shoulder, its head at arm's length,
## the trail ribbon following the head.
func _whirl(pv: Node3D, delta: float) -> void:
	whirl_k = minf(1.0, whirl_k + delta / WHIRL_IN)
	var gun := pv.get_parent() as Node3D
	var orbit_size := gun.global_basis.get_scale().x
	var centre := gun.global_position + Vector3(0, ORBIT_RISE, 0)
	var turn := Basis(Vector3.UP, spin)
	var at := Transform3D(turn * Basis(Vector3.RIGHT, ORBIT_TILT).scaled(Vector3.ONE * orbit_size), centre)
	pv.transform = Transform3D.IDENTITY.interpolate_with(gun.global_transform.affine_inverse() * at, whirl_k)
	orbit_trail.visible = true
	orbit_trail.global_position = centre
	orbit_trail.rotation = Vector3(0, spin, 0)
	var head := _head_world() - centre
	orbit_trail.scale = Vector3.ONE * Vector2(head.x, head.z).length() * ORBIT_PAST / ORBIT_OUT
	KitShaders.param(orbit_trail, "power", ORBIT_POWER * lerpf(1.0, ORBIT_FAST, spin_k) * whirl_k)
	_place_glint(pv)

## The glint on the hammer head: it grows with the charge, and in the perfect window it burns bigger,
## whiter and pulses fast.
func _place_glint(pv: Node3D) -> void:
	if not glint.visible:
		return
	glint.global_position = pv.to_global(Vector3(0, 0, -0.62))
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * (0.06 if hot else 0.025))
	glint.scale = Vector3.ONE * lerpf(0.55, 1.2, glint_k) * pulse * (1.35 if hot else 1.0)
	KitShaders.param(glint, "power", lerpf(0.8, 1.5, glint_k) * (1.4 if hot else 1.0))
	KitShaders.param(glint, "white", 0.7 if hot else 0.25)

# ------------------------------------------------------------------ the aegis
## Follows the raised shield (the verbs wall dict): its node is hidden, ours drawn in its place.
func aegis_show(w: Dictionary, hurt: float, armed: bool) -> void:
	var nd: Node3D = w.get("node")
	if nd and is_instance_valid(nd):
		nd.visible = false
	var a: Vector2 = w["a"]
	var b: Vector2 = w["b"]
	var mid := (a + b) * 0.5
	var dir := Vector2(mid.x - h.pos.x, mid.y - h.pos.z).normalized()
	aegis.visible = true
	# the curve's centre sits behind the wall's midpoint so its apex is the wall line
	var c := Vector2(mid.x, mid.y) - dir * AEGIS_R
	aegis.global_position = Vector3(c.x, float(w["y"]) + 0.02, c.y)
	aegis.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
	(plate_mats[0] as ShaderMaterial).set_shader_parameter("albedo", PLATE_COL.lerp(BROKEN_COL, hurt * 0.65))
	(plate_mats[1] as ShaderMaterial).set_shader_parameter("albedo", PLATE_EDGE.lerp(BROKEN_COL, hurt * 0.65))
	var glow := aegis_hit * 1.2 + (0.35 + 0.15 * sin(Time.get_ticks_msec() * 0.012) if armed else 0.0)
	(plate_mats[0] as ShaderMaterial).set_shader_parameter("glow", glow)

func aegis_hide() -> void:
	aegis.visible = false
	AimKit.hide(h, "aegis_push")

## The wall comes up: it rises out of the ground (the spray at its foot is the kit's "aegis_up").
func aegis_rise() -> void:
	rise_t = RISE_T
	aegis.scale = Vector3(1.0, 0.05, 1.0)

## A block: the whole wall flashes (the spray off its face is the kit's "aegis_block").
func aegis_flash() -> void:
	aegis_hit = 1.0

## The push the raised wall gives, shown in front of it to everyone: a double chevron pointing outward that
## pulses along its reach (a gameplay area: foes that touch the wall are pushed this far); `flash` on a push.
func push_hint(w: Dictionary, n: Vector2, push: float, flash: bool) -> void:
	if flash:
		push_flash = PUSH_FLASH_T
		aegis_hit = 1.0
	var a: Vector2 = w["a"]
	var b: Vector2 = w["b"]
	var mid := (a + b) * 0.5
	var t := float(h.m.time)
	var hot := clampf(push_flash / PUSH_FLASH_T, 0.0, 1.0)
	AimKit.lane(h, "aegis_push", {
		"from": Vector3(mid.x + n.x * 0.5, h.pos.y, mid.y + n.y * 0.5), "dir": n, "len": push,
		"width": float(w["len"]) * 0.7, "chevrons": 2, "fill": fmod(t * 1.5, 1.0), "col": GOLD, "col2": AEGIS,
		"alpha": 1.1 + 0.4 * (0.5 + 0.5 * sin(t * 7.0)) + hot, "hot": 0.3 + hot, "lw": 0.1, "all": true})

# ------------------------------------------------------------------ Purify
## The column coming down over the delay (u 0 -> 1); it is gone once the zone opens.
func purify(at: Vector3, r: float, u: float) -> void:
	column.visible = u < 1.0
	if column.visible:
		var g := AimMode.ground(h.m, at)
		column.global_position = g + Vector3(0, lerpf(9.0, 0.0, minf(1.0, u * 1.6)), 0)
		column.scale = Vector3(r / 1.4, 1.0, r / 1.4) * lerpf(0.5, 1.0, u)
		column.material_override.set_shader_parameter("power", 0.4 + 0.6 * u)

func _process(_delta: float) -> void:
	if not is_instance_valid(h) or h.m == null:
		return
	# effects run on match time (a slow frame or a screenshot never skips them), long steps clamped
	var delta := clampf(float(h.m.time) - fx_clock, 0.0, 1.0 / 30.0)
	fx_clock = float(h.m.time)
	_tick_hold(delta)
	_tick_flare(delta)
	if aegis_hit > 0.0:
		aegis_hit = maxf(0.0, aegis_hit - delta * 5.0)
	push_flash = maxf(0.0, push_flash - delta)
	if rise_t > 0.0:
		rise_t = maxf(0.0, rise_t - delta)
		var u := 1.0 - rise_t / RISE_T
		aegis.scale = Vector3(1.0, lerpf(0.05, 1.0, 1.0 - pow(1.0 - u, 3.0)), 1.0)
	if beacon.visible:
		_stand_beacon()

func _tick_hold(delta: float) -> void:
	var pv := _pivot()
	if pv == null:
		return
	if held:
		_whirl(pv, delta)
	elif pv.transform != Transform3D.IDENTITY:
		pv.transform = Transform3D.IDENTITY

func _tick_flare(delta: float) -> void:
	if flare_t <= 0.0:
		flare.visible = false
		return
	flare_t -= delta
	var head := _head_world()
	flare.visible = head != Vector3.INF and flare_t > 0.0
	if flare.visible:
		var u := 1.0 - flare_t / FLARE_T
		flare.global_position = head + Vector3(0, 0.15, 0)
		flare.scale = Vector3.ONE * lerpf(1.6, 2.3, sqrt(u))
		KitShaders.param(flare, "power", 1.8 * (1.0 - u * 0.6))

## The beacon stands along the camera's up so it reads as a vertical ray on screen wherever it is, and
## pulses.
func _stand_beacon() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		beacon.global_basis = Basis(Quaternion(Vector3.UP, cam.global_basis.y))
	KitShaders.param(beacon, "power", 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006))
