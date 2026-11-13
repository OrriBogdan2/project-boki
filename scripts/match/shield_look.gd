class_name ShieldLook
extends RefCounted
## How a shield reads on a Hunter: one look for every source (abilities, ally areas,
## Boki moves, a Fuse release). The Hunter's own ink outline turns into a thicker line in their side colour
## (SideColor): a crisp shell that hugs the body, no bubble, nothing in front of it, no particles, no extra
## draw calls (the outline pass is swapped, not added). The amount is on the nameplate as a pale bar past
## health (HudPlate). When a hit breaks the shield before it runs out it pops with one quick ring and flash.
## The shell follows the shield's real state: it fades and thins with the amount left (against the most it held),
## and swells and brightens in one pulse over the last PULSE_S before it runs out, so both sides can play around it.
## Materials are swapped only when the shield goes up or down (a few spare ones are kept); per frame only the one
## "shell" parameter changes, and only when it moved.

const META := "shield_rim"       # on the Hunter: the colour shown, or absent while no shield is up
const INK_WIDTH_K := 2.6        # the shield outline is this much wider than the model's own ink
const POP_RING := 1.1            # m: radius of the break ring
const POP_S := 0.22              # s: how long the break ring lasts
const PULSE_S := 0.5             # s before the shield runs out that the shell pulses (once)
const PULSE_PEAK := 2.0          # the "shell" value at the middle of the pulse (above 1: brighter and thicker)
const SHELL_EPS := 0.004         # a smaller change of the shell value is not worth a parameter write
const SPARE_MAX := 16            # shield inks kept for reuse

static var _spare: Array[ShaderMaterial] = []     # shield inks no Hunter wears now

## Every frame, on every Hunter: puts the rim on while a shield is up, takes it off (and pops) when not.
static func tick(h: Hunter) -> void:
	var up := h.shield > 0.0 and not h.downed and not h.out
	var col := SideColor.of(h.m, h).lerp(Color.WHITE, 0.25) if up else Color.BLACK
	var shown_col: Color = h.get_meta(META, Color.BLACK)
	var same_body := is_same(_rim_mats(h), h.mats)
	if up == h.has_meta(META) and (not up or (shown_col == col and same_body)):
		if up:
			_fade(h)
		return
	if up:
		_rim_on(h, col)
		_fade(h)
	else:
		_rim_off(h)
		if h.shield_t > 0.0:
			_pop(h)

## The shell value for a shield of `amount` out of the most it held (`peak`) with `secs_left` to run: the share left,
## lifted to PULSE_PEAK and back over the last PULSE_S.
static func shell_value(amount: float, peak: float, secs_left: float) -> float:
	var k := clampf(amount / maxf(peak, 0.001), 0.0, 1.0)
	if secs_left > 0.0 and secs_left < PULSE_S:
		k += (PULSE_PEAK - k) * sin(PI * (1.0 - secs_left / PULSE_S))
	return k

## The shell value shown on `h` now (1 when there is no rim).
static func shell_of(h: Hunter) -> float:
	return h.get_meta("shield_shell", 1.0)

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
	return mat != null and mat.shader in [Models.GLOW, Models.RING, SideRings.RING, Models.AURA]

static func _rim_on(h: Hunter, col: Color) -> void:
	if h.has_meta(META):
		_rim_off(h)
	var saved := {}
	var inks: Array[ShaderMaterial] = []
	for mt in h.mats:
		var own := (mt as Material).next_pass as ShaderMaterial if mt is Material else null
		if own == null or own.get_shader_parameter("glow_shell") == true:
			continue
		saved[mt] = own
		var ink := _ink(own, col)
		inks.append(ink)
		(mt as Material).next_pass = ink
	h.set_meta("shield_rim_saved", saved)
	h.set_meta("shield_rim_inks", inks)
	h.set_meta(META, col)
	h.set_meta("shield_rim_mats", h.mats)

static func _rim_off(h: Hunter) -> void:
	var saved: Dictionary = h.get_meta("shield_rim_saved", {})
	for mt in saved:
		if is_instance_valid(mt):
			(mt as Material).next_pass = saved[mt]
	for ink in h.get_meta("shield_rim_inks", []):
		if _spare.size() < SPARE_MAX:
			_spare.append(ink)
	for key in ["shield_rim_saved", "shield_rim_inks", "shield_rim_mats", "shield_peak", "shield_shell", META]:
		if h.has_meta(key):
			h.remove_meta(key)

## Puts the shell value for this frame on the Hunter's shield inks, when it moved.
static func _fade(h: Hunter) -> void:
	var peak := maxf(h.get_meta("shield_peak", 0.0), h.shield)
	h.set_meta("shield_peak", peak)
	var k := shell_value(h.shield, peak, h.shield_t)
	if absf(k - shell_of(h)) < SHELL_EPS and h.has_meta("shield_shell"):
		return
	h.set_meta("shield_shell", k)
	for ink in h.get_meta("shield_rim_inks"):
		(ink as ShaderMaterial).set_shader_parameter("shell", k)

## The shield version of a model's ink outline: the side colour, wider, kept at every distance, fading back into the
## model's own ink as the shell value drops. A spare one is reused when there is one.
static func _ink(own: ShaderMaterial, col: Color) -> ShaderMaterial:
	var ink: ShaderMaterial = _spare.pop_back() if not _spare.is_empty() else ShaderMaterial.new()
	ink.shader = own.shader
	var w: Variant = own.get_shader_parameter("width")
	var own_col: Variant = own.get_shader_parameter("color")
	ink.set_shader_parameter("color", col)
	ink.set_shader_parameter("shell_from", own_col if own_col != null else Color(0.08, 0.065, 0.12))
	ink.set_shader_parameter("ink_mask", own.get_shader_parameter("ink_mask") == true)
	ink.set_shader_parameter("width", (float(w) if w != null else 0.00125) * INK_WIDTH_K)
	ink.set_shader_parameter("far_cut", 0.0)
	ink.set_shader_parameter("far_thin", 0.0)
	ink.set_shader_parameter("shell", 1.0)
	return ink

static func _rim_mats(h: Hunter) -> Variant:
	return h.get_meta("shield_rim_mats") if h.has_meta("shield_rim_mats") else null

static func _pop(h: Hunter) -> void:
	var col := SideColor.of(h.m, h).lerp(Color.WHITE, 0.5)
	h.m.fx.ring(h.pos + Vector3(0, 0.9, 0), POP_RING, col, POP_S)
	h.m.fx.flash(h.pos + Vector3(0, 1.0, 0), col, 0.5, 0.08)
	h.m.sfx("ab_shield_hit", h.pos, -8.0, 1.3)
