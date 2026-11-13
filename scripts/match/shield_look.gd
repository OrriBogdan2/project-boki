class_name ShieldLook
extends RefCounted
## How a shield reads on a Hunter: one look for every source (abilities, ally areas,
## Boki moves, a Fuse release). The Hunter's own ink outline turns into a thicker line in their side colour
## (SideColor): a crisp shell that hugs the body, no bubble, nothing in front of it, no particles, no extra
## draw calls (the outline pass is swapped, not added). The amount is on the nameplate as a pale bar past
## health (HudPlate). When a hit breaks the shield before it runs out it pops with one quick ring and flash.
## Materials only change when the shield goes up or down, never per frame.

const META := "shield_rim"       # on the Hunter: the colour shown, or absent while no shield is up
const INK_WIDTH_K := 2.6        # the shield outline is this much wider than the model's own ink
const POP_RING := 1.1            # m: radius of the break ring
const POP_S := 0.22              # s: how long the break ring lasts

static var _inks := {}           # [the model's own ink material, colour] -> its shield version (shared)

## Every frame, on every Hunter: puts the rim on while a shield is up, takes it off (and pops) when not.
static func tick(h: Hunter) -> void:
	var up := h.shield > 0.0 and not h.downed and not h.out
	var col := SideColor.of(h.m, h).lerp(Color.WHITE, 0.25) if up else Color.BLACK
	var shown_col: Color = h.get_meta(META, Color.BLACK)
	var same_body := is_same(_rim_mats(h), h.mats)
	if up == h.has_meta(META) and (not up or (shown_col == col and same_body)):
		return
	if up:
		_rim_on(h, col)
	else:
		_rim_off(h)
		if h.shield_t > 0.0:
			_pop(h)

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

static func _rim_on(h: Hunter, col: Color) -> void:
	if h.has_meta(META):
		_rim_off(h)
	var saved := {}
	for mt in h.mats:
		var own := (mt as Material).next_pass as ShaderMaterial if mt is Material else null
		if own == null or own.get_shader_parameter("glow_shell") == true:
			continue
		saved[mt] = own
		(mt as Material).next_pass = _ink(own, col)
	h.set_meta("shield_rim_saved", saved)
	h.set_meta(META, col)
	h.set_meta("shield_rim_mats", h.mats)

static func _rim_off(h: Hunter) -> void:
	var saved: Dictionary = h.get_meta("shield_rim_saved", {})
	for mt in saved:
		if is_instance_valid(mt):
			(mt as Material).next_pass = saved[mt]
	for key in ["shield_rim_saved", "shield_rim_mats", META]:
		if h.has_meta(key):
			h.remove_meta(key)

## The shield version of a model's ink outline: the side colour, wider, kept at every distance.
static func _ink(own: ShaderMaterial, col: Color) -> ShaderMaterial:
	var key := [own, col]
	if not _inks.has(key):
		var ink := own.duplicate() as ShaderMaterial
		ink.set_shader_parameter("color", col)
		var w: Variant = own.get_shader_parameter("width")
		ink.set_shader_parameter("width", (float(w) if w != null else 0.00125) * INK_WIDTH_K)
		ink.set_shader_parameter("far_cut", 0.0)
		ink.set_shader_parameter("far_thin", 0.0)
		_inks[key] = ink
	return _inks[key]

static func _rim_mats(h: Hunter) -> Variant:
	return h.get_meta("shield_rim_mats") if h.has_meta("shield_rim_mats") else null

static func _pop(h: Hunter) -> void:
	var col := SideColor.of(h.m, h).lerp(Color.WHITE, 0.5)
	h.m.fx.ring(h.pos + Vector3(0, 0.9, 0), POP_RING, col, POP_S)
	h.m.fx.flash(h.pos + Vector3(0, 1.0, 0), col, 0.5, 0.08)
	h.m.sfx("ab_shield_hit", h.pos, -8.0, 1.3)
