class_name ShieldFx
extends RefCounted
## The one shield shell on a Hunter, for every source (abilities, ally areas, Boki moves, a Fuse release).
## The Hunter's own ink outline turns into a thin line in their side colour (SideColor): a crisp shell that hugs
## the body, no bubble, nothing in front of it, no particles, no extra draw calls (the outline pass is swapped,
## not added). It is thickest with the shield full and thins in steps as the shield runs down. A hit it
## absorbs ripples it on the side the hit came from (absorb); a hit that breaks it cracks the body and sheds
## shards in the shield's colour, the armour's break language (Juice.armor_break) in the team colour instead
## of the armour's blue. The amount is on the nameplate as a pale bar past health (HudPlate).
## Materials only change when the shield goes up or down or steps, never per frame.

const META := "shield_rim"       # on the Hunter: the colour shown, or absent while no shield is up
const PEAK := "shield_peak"      # on the Hunter: the most shield it had this time up (what "left" is a share of)
const STEP := "shield_rim_step"  # on the Hunter: which width the rim is drawn at
const STEPS := 4                 # widths between the thinnest rim (nearly spent) and the full one
const INK_WIDTH_FULL := 2.6      # the full shield's outline is this much wider than the model's own ink
const INK_WIDTH_MIN := 1.3       # ... and the nearly spent one
const RIPPLE_SIZE := 0.7         # m: the flash an absorbed hit leaves on the shell
const RIPPLE_GAP := 0.12         # s: soonest the next absorbed hit ripples (a burst of ticks is one ripple)
const BREAK_SHARDS := 14         # shards a break sheds (the armour sheds the same count)

static var _inks := {}           # [the model's own ink material, colour, step] -> its shield version (shared)

## Every frame, on every Hunter: puts the rim on while a shield is up (thinner as it runs down), takes it off
## (and cracks, if a hit broke it) when not.
static func tick(h: Hunter) -> void:
	var up := h.shield > 0.0 and not h.downed and not h.out
	if not up:
		h.remove_meta(PEAK)
		if h.has_meta(META):
			_rim_off(h)
			if h.shield_t > 0.0:
				_crack(h)
		return
	var peak := maxf(float(h.get_meta(PEAK, 0.0)), h.shield)
	h.set_meta(PEAK, peak)
	var step := clampi(ceili(h.shield / peak * STEPS), 1, STEPS)
	var col := SideColor.of(h.m, h).lerp(Color.WHITE, 0.25)
	if h.has_meta(META) and h.get_meta(META) == col and h.get_meta(STEP) == step and is_same(_rim_mats(h), h.mats):
		return
	_rim_on(h, col, step)

## A hit the shield took (Hunter._mitigate), `by` the attacker: a flash and a few sparks on the shell where it
## struck (no ground ring: that means gameplay).
static func absorb(h: Hunter, by: Ent) -> void:
	var m: Match = h.m
	if m == null or m.fx == null or h.shield <= 0.0 or float(h.get_meta("shield_ripple_t", -1.0)) > m.time - RIPPLE_GAP:
		return
	h.set_meta("shield_ripple_t", m.time)
	var side := Vector3.ZERO
	if by != null and is_instance_valid(by) and by != h:
		side = Vector3(by.pos.x - h.pos.x, 0.0, by.pos.z - h.pos.z).normalized()
	var col := SideColor.of(m, h).lerp(Color.WHITE, 0.5)
	var at := h.pos + Vector3(0, 1.0, 0) + side * 0.5
	m.fx.flash(at, col, RIPPLE_SIZE, 0.1)
	m.fx.spark(at, side + Vector3.UP * 0.3, col, 5, 4.0, 60.0, 0.2, 10.0, 0.8)

## Whether the shield rim is on `h`.
static func shown(h: Hunter) -> bool:
	return h.has_meta(META)

## Whether any opaque piece of a shield (a wall's posts, a reflect window) stands between the camera and
## the Hunter's body, which would hide them.
static func occludes(m: Node, h: Hunter) -> bool:
	var cam := m.get_viewport().get_camera_3d() if m.is_inside_tree() else null
	if cam == null:
		return false
	var from := cam.global_position
	var to := h.position + Vector3(0, 1.0, 0)
	var nodes: Array = []
	for w in m.verbs.walls:
		nodes.append(w["node"])
	for mr in m.verbs.mirrors:
		nodes.append(mr["node"])
	for n in nodes:
		if not is_instance_valid(n):
			continue
		for mi in (n as Node).find_children("*", "MeshInstance3D", true, false):
			if _see_through(mi as MeshInstance3D):
				continue
			var box := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			if box.intersects_segment(from, to):
				return true
	return false

static func _see_through(mi: MeshInstance3D) -> bool:
	if not mi.is_visible_in_tree():
		return true
	var mat := mi.material_override as ShaderMaterial
	return mat != null and mat.shader in [Models.GLOW, Models.RING, Models.AURA]

static func _rim_on(h: Hunter, col: Color, step: int) -> void:
	if h.has_meta(META):
		_rim_off(h)
	var saved := {}
	for mt in h.mats:
		var own := (mt as Material).next_pass as ShaderMaterial if mt is Material else null
		if own == null or own.get_shader_parameter("glow_shell") == true:
			continue
		saved[mt] = own
		(mt as Material).next_pass = _ink(own, col, step)
	h.set_meta("shield_rim_saved", saved)
	h.set_meta(META, col)
	h.set_meta(STEP, step)
	h.set_meta("shield_rim_mats", h.mats)

static func _rim_off(h: Hunter) -> void:
	var saved: Dictionary = h.get_meta("shield_rim_saved", {})
	for mt in saved:
		if is_instance_valid(mt):
			(mt as Material).next_pass = saved[mt]
	for key in ["shield_rim_saved", "shield_rim_mats", META, STEP]:
		if h.has_meta(key):
			h.remove_meta(key)

## The shield version of a model's ink outline: the side colour, wider, kept at every distance; `step` of STEPS
## is how much of the shield is left.
static func _ink(own: ShaderMaterial, col: Color, step: int) -> ShaderMaterial:
	var key := [own, col, step]
	if not _inks.has(key):
		var ink := own.duplicate() as ShaderMaterial
		ink.set_shader_parameter("color", col)
		var w: Variant = own.get_shader_parameter("width")
		ink.set_shader_parameter("width", (float(w) if w != null else 0.00125) * lerpf(INK_WIDTH_MIN, INK_WIDTH_FULL, float(step) / STEPS))
		ink.set_shader_parameter("far_cut", 0.0)
		ink.set_shader_parameter("far_thin", 0.0)
		_inks[key] = ink
	return _inks[key]

static func _rim_mats(h: Hunter) -> Variant:
	return h.get_meta("shield_rim_mats") if h.has_meta("shield_rim_mats") else null

## A hit broke the shield: the body cracks (it holds its flash, then fades) and the shell falls off it in
## shards, with a sound; no ring.
static func _crack(h: Hunter) -> void:
	var col := SideColor.of(h.m, h).lerp(Color.WHITE, 0.5)
	h.flash_t = maxf(h.flash_t, Juice.BREAK_FLASH_T)
	h.m.fx.spark(h.pos + Vector3(0, 0.6, 0), Vector3.UP, col, BREAK_SHARDS, 3.0, 120.0, 0.5, 18.0, 1.3)
	h.m.sfx("ab_shield_hit", h.pos, -8.0, 1.3)
