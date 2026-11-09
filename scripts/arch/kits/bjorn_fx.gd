class_name BjornFx
extends Node3D
## Breaker's own effects, every one pooled (built once when the kit starts). The coloured ones are layered
## (KitShaders): an alpha-blended body in his palette (content/vfx/bulwark.json: deep gold, ivory, its hot white)
## with the glow on top, so they keep their colour on bright grass. No orange or red: those are Cinder's and Kael's.
## - the thrown hammer (tumbling, a gold glow and trail), planted head-down in the ground under an
##   upright gold beacon with rising chevrons
## - the held swing: the hammer whirled round him at arm's length, flat over his shoulder, with a
##   gold trail behind its head, a gold glint on the head from 0.6 s that grows; at full charge a short
##   ring-free flash on it, the glint burning white-hot while the perfect window is open. It never stops until
##   he lets go: the charge motion only, the damage comes on the release
## - the slam's flaming 180 degree crescent in front, the 360 Smash's gold and ivory spiral ring
## - the dash's gold chevron wake (his own after-image)
## - his aegis: an ivory dome over the raised wall (HeroVfx "aegis", a shell), rising out of the ground, flashing on
##   a block or a push, cracking as it weakens (the verbs wall underneath keeps the blocking; its plain slab is
##   hidden), with a pulsing double chevron in front of it showing its push
## The aegis's moments, the Shield Slam, Mending Ground and Faultline are HeroVfx data (content/vfx/bulwark.json).

const GOLD := Color("e8c96a")        # content/vfx/bulwark.json "deep": the body of his hammer looks
const IVORY := Color("fff0b0")       # "main", his signature: the bright edge
const STAR_GOLD := Color("fffbe6")   # "hot": glints and flashes
## s the full-charge flare shows (the sheet: one bright frame)
const FLARE_T := 0.12
## s the slam's crescent stays at full strength, then s it burns away over
const CRES_HOLD := 0.1
const CRES_FADE := 0.2
## m: the crescent's band (inner, outer radius) and its height over his feet
const CRES_IN := 1.1
const CRES_OUT := 2.9
const CRES_Y := 0.45
const SWIRL_T := 0.45
## the dash's after-image: a gold chevron wake left behind at chest height, how long each lasts (s), how
## many are pooled and how often one is left (s)
const WAKE_T := 0.28
const WAKE_POOL := 6
const WAKE_EVERY := 0.06
## the Bash's gold fan: half its angle (rad) and its reach scale over the Bash's radius
const CHAIN_LINKS := 18
const CHAIN_SAG := 0.5        # m at its deepest, once the hammer is far out
const WRIST := "Rig/Torso/ArmRPivot/Elbow/Hand"
## the whirled hammer: the 3D model's size over the one in the hand (it reads at the match camera; the procedural
## hammer is drawn big enough as it is), how far above the hand the circle runs (m), its tilt (rad, the head a
## little up) and the s it eases out of the hand into the circle
const ORBIT_SCALE := 1.4
const ORBIT_RISE := 0.45
const WHIRL_HEAD_R := 0.95     # the skinned hammer's head from his axis in the whirl (m, neutral)
const ORBIT_TILT := 0.12
const WHIRL_IN := 0.12
## the whirl's trail ribbon: inner and outer radius (m at scale 1), how far past the head's circle its outer
## edge runs, how far it reaches back behind the head (rad; the arc runs from there to the head, so the streak's
## bright end rides the hammer), its colour, and its strength at the slowest turn rate and how much the fastest adds
const ORBIT_IN := 0.3
const ORBIT_OUT := 1.35
const ORBIT_PAST := 1.25
const ORBIT_ARC := 3.4
const ORBIT_COL := GOLD
const ORBIT_POWER := 3.4
const ORBIT_FAST := 1.4
## the planted hammer's size, and its lean off vertical (rad)
const PLANT_SCALE := 1.9
const PLANT_LEAN := 0.25
## the aegis wall: radius (m), half its arc (rad), height (m) and how far its top leans out (m); its chord is
## about the wall's 4.2 m, its height 30% over the old slab's
const RISE_T := 0.2
const AEGIS_OUT := 0.3         # m the dome's foot stands past the wall line (his body hid it)
const PUSH_FLASH_T := 0.2

var h: Hunter
var hammer: Node3D            # the thrown hammer
var hammer_glow: MeshInstance3D
var trail: MeshInstance3D
var beacon: MeshInstance3D
var glint: MeshInstance3D
var flare: MeshInstance3D
var flare_t := 0.0
var orbit_trail: MeshInstance3D
var crescent: MeshInstance3D
var cres_t := 0.0
var swirl: MeshInstance3D
var swirl_t := 0.0
var aegis: MeshInstance3D      # the dome over the raised wall (HeroVfx shell, made on the first raise)
var aegis_size := Vector3.ONE  # its radius and height from the data (m)
var rise_k := 1.0              # 0..1 how far it has risen out of the ground
var aegis_hit := 0.0
var rise_t := 0.0
var push_flash := 0.0
var wakes: Array[MeshInstance3D] = []
var wake_life: Array[float] = []
var wake_next := 0
var wake_at := -1.0
var held := false              # the swing is being held: the hammer is whirling
var spin := 0.0                # the whirled hammer's angle (rad), from the kit (it counts the turns on match time)
var spin_k := 0.0              # 0..1 how far the turn rate is up (the charge)
var whirl_k := 0.0             # 0..1 how far the hammer has eased out of the hand into the circle
var hot := false               # the perfect window is open: the glint burns white-hot
var glint_k := -1.0            # the glint's size 0..1 while it shows (-1: not yet)
var fx_clock := 0.0            # the match time effects last advanced to

var own_piece: Node3D         # the model's own hammer, when it has a skinned one (WardenGlb.thrown_piece)
var chain: Array = []         # the links to the thrown hammer (_build_chain)

func _init(hunter: Hunter) -> void:
	h = hunter
	top_level = true
	name = "BjornFx"

func _ready() -> void:
	hammer = Node3D.new()
	hammer.top_level = true
	hammer.visible = false
	add_child(hammer)
	# (the skinned hammer's own mesh on a 3D model, else the procedural one)
	if not _own_hammer():
		PinBjornWeapons.hammer(hammer, 1.25)
	hammer_glow = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", Color(GOLD, 0.9), true))
	trail = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("streak", GOLD, true))
	beacon = KitMeshes.inst(self, KitMeshes.pillar(0.22, 0.4, 5.0), KitShaders.mat("beam", GOLD, true))
	glint = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", STAR_GOLD, true))
	flare = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", STAR_GOLD, true))
	for star in [hammer_glow, glint, flare]:
		KitShaders.param(star, "white", 0.25)
	var orbit_mesh := KitMeshes.band(ORBIT_IN, ORBIT_OUT, ORBIT_ARC, 0.0, 36)
	orbit_trail = KitMeshes.inst(self, orbit_mesh, KitShaders.mat("streak", ORBIT_COL, true))
	var cres_mesh := KitMeshes.band(CRES_IN, CRES_OUT, -PI * 0.5, PI * 0.5, 40)
	crescent = KitMeshes.inst(self, cres_mesh, KitShaders.mat("crescent", GOLD, true))
	var swirl_mesh := KitMeshes.band(1.0, 2.4, 0.0, TAU, 48)
	swirl = KitMeshes.inst(self, swirl_mesh, KitShaders.mat("swirl", GOLD, true))
	KitShaders.param(swirl, "color2", IVORY)
	KitShaders.param(swirl, "twist", 2.2)
	KitShaders.param(swirl, "spin", 5.0)
	var wake_mesh := KitMeshes.band(0.35, 0.8, -1.3, 1.3, 14)
	for i in WAKE_POOL:
		var wake := KitMeshes.inst(self, wake_mesh, KitShaders.mat("swirl", GOLD, true))
		KitShaders.param(wake, "color2", IVORY)
		KitShaders.param(wake, "twist", 0.0)
		wakes.append(wake)
		wake_life.append(0.0)
## The model's own hammer on the thrown piece, once the model wears it (an Arena swap dresses him after the kit starts).
func _own_hammer() -> bool:
	if own_piece:
		return true
	own_piece = WardenGlb.thrown_piece(h.model, "hammer") if h.model else null
	if own_piece == null:
		return false
	for c in hammer.get_children():
		c.queue_free()
	hammer.add_child(own_piece)
	own_piece.scale = Vector3.ONE * h.model.scale.x
	_build_chain()
	return true

## The chain from his wrist to the thrown hammer: pooled iron links, shown only while it is out of the hand.
func _build_chain() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.09
	torus.outer_radius = 0.17
	torus.rings = 8
	torus.ring_segments = 4
	var iron := Models.toon(Color("4a4038"))
	for i in CHAIN_LINKS:
		var mi := MeshInstance3D.new()
		mi.mesh = torus
		mi.material_override = iron
		mi.top_level = true
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		chain.append(mi)

func _tick_chain() -> void:
	var wrist := h.model.get_node_or_null(WRIST) as Node3D if h.model else null
	var on := hammer.visible and wrist != null and wrist.is_inside_tree()
	for i in chain.size():
		var mi: MeshInstance3D = chain[i]
		mi.visible = on
		if not on:
			continue
		var a := wrist.global_position
		var b := hammer.global_position
		var u := (i + 0.5) / chain.size()
		var sag := Vector3.DOWN * CHAIN_SAG * minf(a.distance_to(b) * 0.1, 1.0) * sin(u * PI)
		var at := a.lerp(b, u) + sag
		var along := (b - a).normalized()
		var up := Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT
		var fix := Basis.looking_at(along, up)
		mi.global_transform = Transform3D(fix.rotated(along, PI * 0.5 * (i % 2)) * Basis(Vector3.RIGHT, PI * 0.5), at)
		mi.scale = Vector3(1.0, 1.0, 1.0) * clampf(a.distance_to(b) / chain.size() * 2.2, 0.5, 1.6)

# ------------------------------------------------------------------ the thrown hammer
## In flight at `p` along `dir`, tumbling at `spin_rate` rad/s.
func hammer_fly(p: Vector3, dir: Vector2, spin_rate: float) -> void:
	_own_hammer()
	hammer.visible = true
	hammer.global_position = p
	hammer.rotation = Vector3(Time.get_ticks_msec() * 0.001 * spin_rate, atan2(-dir.x, -dir.y), 0.0)
	hammer.scale = Vector3.ONE
	beacon.visible = false
	hammer_glow.visible = true
	hammer_glow.global_position = p
	hammer_glow.scale = Vector3.ONE * 1.1
	trail.visible = true
	trail.global_position = p - Vector3(dir.x, 0, dir.y) * 1.0
	trail.rotation = Vector3(-PI * 0.5, atan2(-dir.x, -dir.y) + PI * 0.5, 0)
	trail.scale = Vector3(2.0, 0.45, 1.0)

## Planted: standing head-down in the ground, leaning back along its flight, the beacon over it.
func hammer_plant(p: Vector3, yaw: float) -> void:
	hammer.visible = true
	var plant_k := h.model.scale.x if own_piece else PLANT_SCALE
	hammer.scale = Vector3.ONE if own_piece else Vector3.ONE * PLANT_SCALE / 1.25
	# the head points down (-Z turned to -Y), leaning PLANT_LEAN off vertical
	hammer.rotation = Vector3(-PI * 0.5 - PLANT_LEAN, yaw, 0.0)
	var head_drop := 0.62 * plant_k * cos(PLANT_LEAN)
	hammer.global_position = p + Vector3(0, head_drop - 0.2, 0)
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
## While LMB is held (k = the charge 0..1): the hammer whirls round him at the kit's angle `turn` (rad); the glint
## on its head shows from 0.6 s and grows, white-hot while `window` (perfect) is open.
func hold(held_t: float, k: float, window: bool, turn: float) -> void:
	held = true
	spin = turn
	spin_k = k
	if _own_hammer():
		# (the skinned hammer whirls in the clip: its loop runs on the kit's angle. The clip's a = 0 is his right, the
		# kit's 0 his front, so a quarter turn on.)
		h.model.set_meta(WardenClips.PHASE, fposmod((turn - h.model.rotation.y + PI * 0.5) / TAU, 1.0))
	glint_k = k if held_t >= 0.6 else -1.0
	glint.visible = glint_k >= 0.0
	hot = window

## Full charge: the big gold star on the hammer head.
func full_flare() -> void:
	flare_t = FLARE_T

func hold_end() -> void:
	held = false
	if h.model:
		h.model.remove_meta(WardenClips.PHASE)
		h.model.remove_meta(WardenClips.WEAPON_K)
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
	var at := WardenGlb.anchor(h.model, "anchor_hammer_head") if h.model else null
	if at and at.is_inside_tree():
		if held:      # (whirling: on the kit's own angle, the clip seeks to it; the anchor gives the height)
			var out := Basis(Vector3.UP, spin) * Vector3(0, 0, -WHIRL_HEAD_R * h.model.scale.x)
			var c := h.model.global_position
			return Vector3(c.x + out.x, at.global_position.y, c.z + out.z)
		return at.global_position
	var pv := _pivot()
	if pv == null or not pv.is_inside_tree():
		return Vector3.INF
	return pv.to_global(Vector3(0, 0, -0.62))

## Shows or hides the hammer in his hand (it's out while thrown).
func in_hand(on: bool) -> void:
	if h.model:
		h.model.set_meta(WardenClips.WEAPON_OUT, not on)
	var pv := _pivot()
	if pv:
		pv.visible = on

## The whirl: the hammer eases out of the hand into a flat circle over his shoulder, its head at arm's length,
## the trail ribbon following the head.
func _whirl(pv: Node3D, delta: float) -> void:
	whirl_k = minf(1.0, whirl_k + delta / WHIRL_IN)
	var gun := pv.get_parent() as Node3D
	var orbit_size := gun.global_basis.get_scale().x
	if pv.has_node(WardenGlb.WEAPON):
		orbit_size *= ORBIT_SCALE
	var centre := gun.global_position + Vector3(0, ORBIT_RISE, 0)
	if own_piece:      # (the head you see runs round his body, at its own height)
		centre = Vector3(h.model.global_position.x, _head_world().y, h.model.global_position.z)
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
	glint.global_position = _head_world()
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * (0.06 if hot else 0.025))
	glint.scale = Vector3.ONE * lerpf(0.55, 1.2, glint_k) * pulse * (1.35 if hot else 1.0)
	KitShaders.param(glint, "power", lerpf(0.8, 1.5, glint_k) * (1.4 if hot else 1.0))
	KitShaders.param(glint, "white", 0.7 if hot else 0.25)

# ------------------------------------------------------------------ slam crescent and smash swirl
## The Crushing Blow's crescent: 180 degrees in front of him toward `dir` (the blow's hit area), bigger with the
## charge k. It rides with him through the slam's carry, so it stays in front instead of being left behind.
func slam(dir: Vector2, k: float) -> void:
	crescent.visible = true
	crescent.global_position = _cres_at()
	crescent.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
	crescent.scale = Vector3.ONE * lerpf(0.85, 1.0, k)
	cres_t = CRES_HOLD + CRES_FADE

## Where the crescent is drawn this frame: on him, so it rides through the carry.
func _cres_at() -> Vector3:
	return h.pos + Vector3(0, CRES_Y, 0)

## Where the crescent's area centres on the ground as drawn now (the centroid of its half band), for checks.
func crescent_centre() -> Vector3:
	var r3 := pow(CRES_OUT, 3) - pow(CRES_IN, 3)
	var r2 := CRES_OUT * CRES_OUT - CRES_IN * CRES_IN
	var reach := 4.0 / (3.0 * PI) * r3 / r2 * crescent.scale.x
	var ahead := -crescent.basis.z.normalized()
	return _cres_at() + ahead * reach - Vector3(0, CRES_Y, 0)

func smash_ring(at: Vector3) -> void:
	swirl.visible = true
	swirl.global_position = at + Vector3(0, 0.3, 0)
	swirl_t = SWIRL_T

## The dash's after-image: a gold chevron wake at his chest, pointing the way he faces (pooled, one every
## WAKE_EVERY s).
func afterimage(at: Vector3, yaw: float, body_scale: float) -> void:
	var now := float(h.m.time)
	if now - wake_at < WAKE_EVERY and now >= wake_at:
		return
	wake_at = now
	var wake := wakes[wake_next]
	wake_life[wake_next] = WAKE_T
	wake_next = (wake_next + 1) % WAKE_POOL
	wake.visible = true
	wake.global_position = at + Vector3(0, 1.0 * body_scale, 0)
	wake.rotation = Vector3(0, yaw, 0)
	wake.scale = Vector3.ONE * body_scale

# ------------------------------------------------------------------ the aegis
## Follows the raised shield (the verbs wall dict): its node is hidden and his dome drawn over it, the curve's
## centre behind the wall's midpoint so its apex stands AEGIS_OUT past the wall line. `hurt` 0..1 cracks it;
## `armed` pulses it.
func aegis_show(w: Dictionary, hurt: float, armed: bool) -> void:
	var nd: Node3D = w.get("node")
	if nd and is_instance_valid(nd):
		nd.visible = false
	var a: Vector2 = w["a"]
	var b: Vector2 = w["b"]
	var mid := (a + b) * 0.5
	var dir := Vector2(mid.x - h.pos.x, mid.y - h.pos.z).normalized()
	var dome := _aegis()
	var c := mid + dir * (AEGIS_OUT - aegis_size.x)
	dome.visible = true
	var extent := Vector3(aegis_size.x, aegis_size.y * rise_k, aegis_size.z)
	dome.global_transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)) * Basis.from_scale(extent),
		Vector3(c.x, float(w["y"]) + 0.02, c.y))
	KitShaders.param(dome, "life", hurt)
	var pulse := 0.3 + 0.2 * sin(Time.get_ticks_msec() * 0.012) if armed else 0.0
	KitShaders.param(dome, "shine", aegis_hit * 1.5 + pulse)

## The dome, made on first use: a HeroVfx shell, kept with these effects so it goes when they do.
func _aegis() -> MeshInstance3D:
	if aegis == null:
		aegis = HeroVfx.of(h.m).shell(h, "aegis")
		aegis_size = aegis.scale
		aegis.reparent(self)
		aegis.top_level = true
		aegis.visible = false
	return aegis

func aegis_hide() -> void:
	if aegis:
		aegis.visible = false
	AimKit.hide(h, "aegis_push")

## The wall comes up: the dome rises out of the ground in a puff of dust.
func aegis_rise(at: Vector3) -> void:
	rise_t = RISE_T
	rise_k = 0.05
	_aegis()
	h.m.fx.dust(at, 14)
	HeroVfx.of(h.m).play(h, "aegis_rise", at, h.aim_dir())

## A block: the whole dome flashes and sparks fly off its face at `at`.
func aegis_block(at: Vector3) -> void:
	aegis_hit = 1.0
	WardenMood.poke(h.model)
	HeroVfx.of(h.m).play(h, "aegis_block", at, Vector2(at.x - h.pos.x, at.z - h.pos.z).normalized())

## Broken: the dome shatters into shards and dust.
func aegis_break(at: Vector3) -> void:
	aegis_hide()
	h.m.fx.dust(at, 16)
	HeroVfx.of(h.m).play(h, "aegis_break", at, h.aim_dir())

## The push the raised wall gives, shown in front of it to everyone: a double chevron pointing outward that
## pulses along its reach (a gameplay area: foes that touch the wall are pushed this far); `flash` on a push.
func push_hint(w: Dictionary, n: Vector2, push: float, flash: bool) -> void:
	var a: Vector2 = w["a"]
	var b: Vector2 = w["b"]
	var mid := (a + b) * 0.5
	if flash:
		push_flash = PUSH_FLASH_T
		aegis_hit = 1.0
		HeroVfx.of(h.m).play(h, "aegis_push", Vector3(mid.x, h.pos.y, mid.y), n)
	var t := float(h.m.time)
	var hot := clampf(push_flash / PUSH_FLASH_T, 0.0, 1.0)
	AimKit.lane(h, "aegis_push", {
		"from": Vector3(mid.x + n.x * 0.5, h.pos.y, mid.y + n.y * 0.5), "dir": n, "len": push,
		"width": float(w["len"]) * 0.7, "chevrons": 2, "fill": fmod(t * 1.5, 1.0), "col": HeroVfx.pal(h.arch, "deep"),
		"col2": HeroVfx.pal(h.arch, "hot"), "alpha": 1.1 + 0.4 * (0.5 + 0.5 * sin(t * 7.0)) + hot, "hot": 0.3 + hot,
		"lw": 0.1, "all": true})

func _process(_delta: float) -> void:
	if not is_instance_valid(h) or h.m == null:
		return
	# effects run on match time (a slow frame or a screenshot never skips them), long steps clamped
	var delta := clampf(float(h.m.time) - fx_clock, 0.0, 1.0 / 30.0)
	fx_clock = float(h.m.time)
	_tick_hold(delta)
	if not chain.is_empty():
		_tick_chain()
	_tick_flare(delta)
	_tick_slam(delta)
	if aegis_hit > 0.0:
		aegis_hit = maxf(0.0, aegis_hit - delta * 5.0)
	push_flash = maxf(0.0, push_flash - delta)
	if rise_t > 0.0:
		rise_t = maxf(0.0, rise_t - delta)
		var u := 1.0 - rise_t / RISE_T
		rise_k = lerpf(0.05, 1.0, 1.0 - pow(1.0 - u, 3.0))
	if beacon.visible:
		_stand_beacon()
	_tick_wakes(delta)

func _tick_wakes(delta: float) -> void:
	for i in WAKE_POOL:
		if wake_life[i] <= 0.0:
			continue
		wake_life[i] -= delta
		var life := clampf(wake_life[i] / WAKE_T, 0.0, 1.0)
		KitShaders.param(wakes[i], "life", life)
		wakes[i].scale = Vector3.ONE * wakes[i].scale.x * (1.0 + delta * 1.5)
		wakes[i].visible = wake_life[i] > 0.0

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

func _tick_slam(delta: float) -> void:
	if cres_t > 0.0:
		cres_t -= delta
		crescent.global_position = _cres_at()
		KitShaders.param(crescent, "life", clampf(cres_t / CRES_FADE, 0.0, 1.0))
		crescent.visible = cres_t > 0.0
	if swirl_t > 0.0:
		swirl_t -= delta
		var life := clampf(swirl_t / SWIRL_T, 0.0, 1.0)
		swirl.rotation.y += delta * 12.0
		KitShaders.param(swirl, "life", minf(1.0, life * 1.6))
		swirl.scale = Vector3.ONE * lerpf(1.12, 0.88, life)
		swirl.visible = swirl_t > 0.0

## The beacon stands along the camera's up so it reads as a vertical ray on screen wherever it is, and
## pulses.
func _stand_beacon() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		beacon.global_basis = Basis(Quaternion(Vector3.UP, cam.global_basis.y))
	KitShaders.param(beacon, "power", 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006))
