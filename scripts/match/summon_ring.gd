class_name SummonRing
extends RefCounted
## The time left on a summoned Boki, read off the ground (DECISIONS 2026-11-09, per-Boki duration): a thin ring
## just outside its team ring, in the colour of whoever it rides with now (SideColor), that empties as the
## window runs out and flickers for the last WARN_S. A stolen summon wears it dimmed. It is drawn under the
## hit circles and telegraphs (lower than every ground mark, sorted first) and freed the moment the Boki
## shrinks, is knocked back or dies. Every game draws it from the snapshot's window left (KinNet); the window
## it started with is the most seen (KinSummon.win), so no new sync.

const NAME := "SummonRing"
const PAD_M := 0.35          # m the ring's diameter exceeds the Boki's team ring
const THICKNESS := 0.05      # fraction of the radius the band takes
const LIFT_M := 0.03         # m above the ground: under the team ring (0.06) and the telegraphs
const OWN_A := 0.9           # alpha of a summon that is its rider's own
const STOLEN_A := 0.45       # alpha of a stolen summon
const WARN_S := 2.0          # s left when the ring starts to flicker
const FLICKER_HZ := 6.0      # flickers per second in the warning
const FLICKER_LOW := 0.25    # x alpha at the dark half of a flicker
const PRIORITY := -2         # material render priority: under the team ring and the marks

## Every frame, on every Boki (Kin.render): draws the ring while its window runs, frees it otherwise.
static func tick(k: Kin) -> void:
	var s := k.summon
	var ring := k.get_node_or_null(NAME) as MeshInstance3D
	if s == null:
		return
	if s.left <= 0.0:
		s.win = 0.0
	if s.left <= 0.0 or k.dead or k.wisp or not k.visible:
		if ring:
			k.remove_child(ring)
			ring.queue_free()
		return
	s.win = maxf(s.win, s.left)
	if ring == null:
		ring = _make()
		k.add_child(ring)
	var d := k.r * 2.6 + 0.3 + PAD_M
	var p := k.global_position
	ring.global_position = Vector3(p.x, k.m.world.ground_at(p.x, p.z) + LIFT_M, p.z)
	ring.scale = Vector3.ONE * d
	var a := STOLEN_A if KinSteal.stolen(k) else OWN_A
	if s.left <= WARN_S and sin(k.m.time * TAU * FLICKER_HZ) < 0.0:
		a *= FLICKER_LOW
	var mat := ring.material_override as ShaderMaterial
	mat.set_shader_parameter("color", Color(SideColor.of(k.m, k), a))
	mat.set_shader_parameter("arc", clampf(s.left / s.win, 0.0, 1.0))

static func _make() -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = NAME
	ring.mesh = Models.flat_quad(1.0)
	ring.material_override = Models.ring_mat(Color.WHITE, THICKNESS)
	ring.material_override.render_priority = PRIORITY
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.top_level = true
	return ring
