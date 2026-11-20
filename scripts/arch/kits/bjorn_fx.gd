class_name BjornFx
extends Node3D
## Breaker's pooled meshes that follow his hammer and shield (built once when the kit starts). Every other look of
## his is HeroVfx data (content/vfx/bulwark.json): the throw's trail, plant and catch, the planted hammer's beacon,
## the dash wake, the swing and Slam crescents, the 360 Smash ring, the Mending Ground column, zone and burst, the
## aegis rise and block, Faultline.
## - the thrown hammer (tumbling) on its rope, planted head-down in the ground
## - the held swing: the hammer whirled round him at arm's length, flat over his shoulder, with a trail in
##   his ivory (Arch.color) behind its head, a glint in his colour on the head from 0.6 s that grows, burning
##   white-hot while the perfect window is open. It never stops until he lets go: the charge motion only, the damage
##   comes on the release
## - his aegis: a wall of lit plates (two rows, ribbed, a rim and a hammer boss in his ivory) leaning out
##   toward the camera, rising out of the ground, flashing on a block, darkening as it weakens and breaking
##   (the verbs wall underneath keeps the blocking; its plain slab is hidden)

const CHAIN_LINKS := 18
const CHAIN_SAG := 0.5        # m at its deepest, once the hammer is far out
var taut := false              # the rope is hauling the hammer home: drawn straight, no sag
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
## bright end rides the hammer), and its strength at the slowest turn rate and how much the fastest adds
const ORBIT_IN := 0.3
const ORBIT_OUT := 1.35
const ORBIT_PAST := 1.25
const ORBIT_ARC := 3.4
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
## the aegis: a lit slab, its plates in the palette's "slab" and the rim, ribs and boss lit in his own colour
## ("ivory", Arch.color) from content/vfx/bulwark.json; no dark edge pieces, no rivets (VFX_QUALITY row 8)
const PLATE_GLOW := 0.3        # the plates' own light (a block flashes over it)
const EDGE_GLOW := 0.9
const BROKEN_COL := Color("4a3a30")
## s the wall takes to rise out of the ground
const RISE_T := 0.2

var h: Hunter
var hammer: Node3D            # the thrown hammer
var glint: MeshInstance3D
var orbit_trail: MeshInstance3D
var aegis: Node3D              # the plated wall
var plate_mats: Array = []     # [plate, edge] materials (flash and crack)
var plate_col: Color
var edge_col: Color
var aegis_hit := 0.0
var rise_t := 0.0
var held := false              # the swing is being held: the hammer is whirling
var spin := 0.0                # the whirled hammer's angle (rad), from the kit (it counts the turns on match time)
var spin_k := 0.0              # 0..1 how far the turn rate is up (the charge)
var whirl_k := 0.0             # 0..1 how far the hammer has eased out of the hand into the circle
var hot := false               # the perfect window is open: the glint burns white-hot
var glint_k := -1.0            # the glint's size 0..1 while it shows (-1: not yet)
var fx_clock := 0.0            # the match time effects last advanced to

var own_piece: Node3D         # the model's own hammer, when it has a skinned one (WardenGlb.thrown_piece)
var own_reach := 0.0          # m from its grip to its head's far end (neutral): it stands on that, planted
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
	glint = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", AimKit.hero_col(h), true))
	KitShaders.param(glint, "white", 0.25)
	var orbit_mesh := KitMeshes.band(ORBIT_IN, ORBIT_OUT, ORBIT_ARC, 0.0, 36)
	orbit_trail = KitMeshes.inst(self, orbit_mesh, KitShaders.mat("streak", Arch.color(h.arch), true))
	_build_aegis()

## A colour of his palette (content/vfx/bulwark.json).
func _pal(key: String) -> Color:
	return Color(String((HeroVfx.data(h.arch).get("palette", {}) as Dictionary).get(key, key)))

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
	var mi := own_piece.get_child(0) as MeshInstance3D
	own_reach = -(mi.transform * mi.get_aabb()).position.z
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
		var sag := Vector3.DOWN * CHAIN_SAG * minf(a.distance_to(b) * 0.1, 1.0) * sin(u * PI) * float(not taut)
		var at := a.lerp(b, u) + sag
		var along := (b - a).normalized()
		var up := Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT
		var fix := Basis.looking_at(along, up)
		mi.global_transform = Transform3D(fix.rotated(along, PI * 0.5 * (i % 2)) * Basis(Vector3.RIGHT, PI * 0.5), at)
		mi.scale = Vector3(1.0, 1.0, 1.0) * clampf(a.distance_to(b) / chain.size() * 2.2, 0.5, 1.6)

## The wall of lit plates, built once: two rows of plates along the arc, ribs between them, a
## rim along the top and a round boss with the hammer's cross in the middle. Local space: the curve's
## centre at the origin, the apex straight ahead (-Z).
func _build_aegis() -> void:
	aegis = Node3D.new()
	aegis.top_level = true
	aegis.visible = false
	add_child(aegis)
	plate_col = _pal("slab")
	edge_col = _pal("ivory")
	var plate := Models.toon(plate_col, false, PLATE_GLOW)
	var edge := Models.toon(edge_col, false, EDGE_GLOW)
	plate.set_shader_parameter("rim_amount", 0.6)
	plate.set_shader_parameter("rim_color", edge_col)
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
	Models.part(aegis, Models.box(0.12, 0.5, 0.1), plate, stem_at, Vector3.ONE, cross_tilt)
	Models.part(aegis, Models.box(0.4, 0.12, 0.1), plate, stem_at + Vector3(0, 0.12, 0), Vector3.ONE, cross_tilt)

# ------------------------------------------------------------------ the thrown hammer
## In flight at `p` along `dir`, tumbling at `spin_rate` rad/s.
func hammer_fly(p: Vector3, dir: Vector2, spin_rate: float) -> void:
	_own_hammer()
	hammer.visible = true
	hammer.global_position = p
	hammer.rotation = Vector3(Time.get_ticks_msec() * 0.001 * spin_rate, atan2(-dir.x, -dir.y), 0.0)
	hammer.scale = Vector3.ONE

## Planted: standing head-down in the ground, leaning back along its flight (its beacon: the kit's "plant_beacon" hold).
func hammer_plant(p: Vector3, yaw: float) -> void:
	hammer.visible = true
	var plant_k := h.model.scale.x if own_piece else PLANT_SCALE
	hammer.scale = Vector3.ONE if own_piece else Vector3.ONE * PLANT_SCALE / 1.25
	# the head points down (-Z turned to -Y), leaning PLANT_LEAN off vertical
	hammer.rotation = Vector3(-PI * 0.5 - PLANT_LEAN, yaw, 0.0)
	var head_drop := (own_reach if own_piece else 0.62) * plant_k * cos(PLANT_LEAN)
	hammer.global_position = p + Vector3(0, head_drop - 0.2, 0)

func hammer_hide() -> void:
	hammer.visible = false

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
	_place_glint()

## The glint on the hammer head: it grows with the charge, and in the perfect window it burns bigger,
## whiter and pulses fast.
func _place_glint() -> void:
	if not glint.visible:
		return
	glint.global_position = _head_world()
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
	(plate_mats[0] as ShaderMaterial).set_shader_parameter("albedo", plate_col.lerp(BROKEN_COL, hurt * 0.65))
	(plate_mats[1] as ShaderMaterial).set_shader_parameter("albedo", edge_col.lerp(BROKEN_COL, hurt * 0.65))
	var pulse := 0.35 + 0.15 * sin(Time.get_ticks_msec() * 0.012) if armed else 0.0
	var glow := PLATE_GLOW * (1.0 - hurt) + aegis_hit * 1.2 + pulse
	(plate_mats[0] as ShaderMaterial).set_shader_parameter("glow", glow)

func aegis_hide() -> void:
	aegis.visible = false

## The wall comes up: it rises out of the ground in a puff of dust.
func aegis_rise(at: Vector3) -> void:
	rise_t = RISE_T
	aegis.scale = Vector3(1.0, 0.05, 1.0)
	HeroVfx.of(h.m).play(h, "aegis_up", at, Vector2.ZERO)

## A block: the whole wall flashes and ivory sparks fly off its face at `at` ("block").
func aegis_block(at: Vector3) -> void:
	aegis_hit = 1.0
	WardenMood.poke(h.model)
	var out := Vector3(at.x - h.pos.x, 0.15, at.z - h.pos.z).normalized()
	HeroVfx.of(h.m).play(h, "block", at, Vector2(out.x, out.z).normalized())

## Broken: the shared shield break (ShieldBreak) across the wall, like every other shield.
func aegis_break(at: Vector3) -> void:
	aegis.visible = false
	AimKit.hide(h, "aegis_push")
	var half := Vector2(AEGIS_R * sin(AEGIS_HALF), AEGIS_H * 0.5)
	ShieldBreak.of(h.m).play(at + Vector3(0, half.y, 0), half, Arch.color(h.arch))

func _process(_delta: float) -> void:
	if not is_instance_valid(h) or h.m == null:
		return
	# effects run on match time (a slow frame or a screenshot never skips them), long steps clamped
	var delta := clampf(float(h.m.time) - fx_clock, 0.0, 1.0 / 30.0)
	fx_clock = float(h.m.time)
	_tick_hold(delta)
	if not chain.is_empty():
		_tick_chain()
	if aegis_hit > 0.0:
		aegis_hit = maxf(0.0, aegis_hit - delta * 5.0)
	if rise_t > 0.0:
		rise_t = maxf(0.0, rise_t - delta)
		var u := 1.0 - rise_t / RISE_T
		aegis.scale = Vector3(1.0, lerpf(0.05, 1.0, 1.0 - pow(1.0 - u, 3.0)), 1.0)

func _tick_hold(delta: float) -> void:
	var pv := _pivot()
	if pv == null:
		return
	if held:
		_whirl(pv, delta)
	elif pv.transform != Transform3D.IDENTITY:
		pv.transform = Transform3D.IDENTITY
