class_name PrologueBoki
extends Node3D
## THE BOKI, the prologue's fourth shot: morning on a lone isle. The Boki bound out of the grass one by one,
## the lead one hops up to greet the hunter, he kneels to it, it hops up to the relic in his hand and the
## relic wakes in his Relic's colour. Built at the set's centre; the prologue calls play() each frame.

## the hunter takes up Vex's Relic, so the relic wakes in that colour
const MANTLE := "gunslinger"
const HUNTER_AT := Vector3(0.9, 0, -0.3)        # m from the set's centre
const HUNTER_LOOKOUT := -0.93                   # rad: his yaw at first, looking out to the sunrise
## each Boki: species, where it comes from (the far side of the island), where it settles (m from the centre).
## The lead one stops an arm's length in front of the hunter, the pair side by side across the close-up; the
## rest sit well behind and to the sides, clear of the hunter's silhouette.
const BOKI_SPOTS := [
	["cindle", Vector3(-1.6, 0, -2.6), Vector3(-0.1, 0, -0.3)],
	["burrlet", Vector3(-3.0, 0, -4.0), Vector3(-1.2, 0, -2.4)],
	["zapple", Vector3(3.4, 0, -4.6), Vector3(2.4, 0, -2.8)],
	["puddlet", Vector3(-3.4, 0, -3.0), Vector3(-1.9, 0, -1.3)],
]
const BOKI_OUT := 0.4          # s into the shot the first one bounds out, then one every BOKI_STAGGER s
const BOKI_STAGGER := 0.45
const TURN_AT := 1.2           # s: the hunter turns from the sunrise to the lead Boki
const KNEEL_AT := 2.1          # s: he kneels to it
const TOUCH_AT := 3.5          # s: it reaches up to the relic, which wakes
const RISE_AT := 4.1           # s: the woken relic lifts out of his hands and hangs glowing between the pair
const HANG_AT := Vector3(0.25, 1.6, -0.3)      # m from the set's centre: where it hangs, above both, against the sky
const DULL := Color("6c6a78")  # the relic asleep

var kin_nodes: Array = []
var kin_hunter: Node3D
var kin_anim: HunterAnim
var relic: MeshInstance3D
var relic_halo: MeshInstance3D
var relic_ring: MeshInstance3D   # a ring round the woken relic, facing the close-up camera, pulsing
var relic_light: OmniLight3D
var lifted := false              # the relic has left his hands
var relic_k := 0.0              # 0 a dull stone, 1 awake
var mantle_rise: CPUParticles3D

## The isle, a blossom tree, the hunter with the relic, and the Boki waiting out of sight.
## `rise`: the specks that rise off the hunter once the relic wakes (made by the prologue, off until then).
func build(rng: RandomNumberGenerator, rise: CPUParticles3D) -> void:
	add_child(Scenery.island(rng, 6.5, false, true))
	var tr := Models.tree(rng, Color("5a9a4f"), "blossom")
	tr.position = Vector3(-3.6, 0, -3.0)
	tr.scale *= 1.3
	add_child(tr)
	var look := {"gender": rng.randi() % 2}
	kin_hunter = Models.hunter(Arch.weight(MANTLE), Data.TEAM_COLORS[0], Arch.signature(MANTLE), "sage", look, MANTLE)
	kin_hunter.position = HUNTER_AT
	kin_hunter.rotation.y = HUNTER_LOOKOUT
	(kin_hunter.get_node("TeamRing") as Node3D).visible = false
	kin_hunter.get_node("Rig/Torso/Aim/Gun").free()      # a survivor, not yet a Hunter: no weapon in his hands
	add_child(kin_hunter)
	kin_anim = HunterAnim.new(kin_hunter)
	_relic(Arch.color(MANTLE))
	mantle_rise = rise
	for spot in BOKI_SPOTS:
		var k := Models.kin(String(spot[0]), {"level": 5})
		k.set_meta("home", spot[2])
		k.position = spot[1]
		k.visible = false
		add_child(k)
		kin_nodes.append(k)

## The relic: a dull stone held in both his hands until the lead Boki touches it; then it lights in the Relic's
## colour. A solid outlined stone with a hot core (an additive glow alone washes out to white against the morning
## sky), a soft halo, a pulsing ring and a warm light spilling on the pair. Kept between his hands in play().
func _relic(col: Color) -> void:
	relic = Models.part(self, Models.sphere(0.1, 12), Models.toon(DULL), Vector3.ZERO, Vector3(1, 1.3, 1))
	var hot := Models.glow_mat(Color(1.0, 0.95, 0.75))
	var core := Models.part(relic, Models.sphere(0.05, 10), hot, Vector3(0, 0, 0.07))      # toward the close-up camera
	core.visible = false
	core.name = "Core"
	relic_halo = Models.part(relic, Models.sphere(0.3, 16), Models.glow_mat(Color(col, 0.3)))
	relic_halo.visible = false
	relic_ring = Models.part(relic, Models.flat_quad(2.0), Models.ring_mat(col, 0.14), Vector3.ZERO, Vector3.ONE * 0.2,
		Vector3(PI / 2, 0, 0))
	relic_ring.visible = false
	relic_light = OmniLight3D.new()
	relic_light.light_color = col
	relic_light.omni_range = 3.0
	relic_light.light_energy = 0.0
	relic_light.position = Vector3(0, 0, 0.25)      # a touch toward the camera, so the faces turned to it catch it
	relic.add_child(relic_light)

## st: seconds into the shot.
func play(st: float, delta: float) -> void:
	var to_lead := (kin_nodes[0] as Node3D).position - kin_hunter.position
	var face := lerp_angle(HUNTER_LOOKOUT, atan2(-to_lead.x, -to_lead.z), clampf((st - TURN_AT) / 0.6, 0.0, 1.0))
	kin_hunter.rotation.y = face
	# down on one knee, the relic held out in both hands at his chest
	kin_anim.update(delta, {"face": face, "fired": 99.0, "act": "offer" if st > KNEEL_AT else ""})
	if not lifted:
		relic.global_position = (kin_anim.hand_l.global_position + kin_anim.hand_r.global_position) * 0.5
	for i in kin_nodes.size():
		_boki_step(kin_nodes[i], i, st, delta)
	if st > TOUCH_AT and relic_k == 0.0:
		_wake_relic()
	if st > RISE_AT and not lifted:
		_lift_relic()
	if relic_k > 0.0:
		var pulse := 0.5 + 0.5 * sin(st * 5.0)
		relic_ring.scale = Vector3.ONE * lerpf(0.22, 0.32, pulse) * relic_k
		relic_light.light_energy = lerpf(6.0, 9.0, pulse) * relic_k

## One Boki: out of the grass, bounding to its spot, then facing the hunter with a bob; the lead one hops up
## to the relic, and every one jumps for joy as it wakes.
func _boki_step(k: Node3D, i: int, st: float, delta: float) -> void:
	var out_at := BOKI_OUT + i * BOKI_STAGGER
	if st < out_at:
		return
	if not k.visible:
		k.visible = true
		Sfx.play("pickup", null, -12.0, 0.05, 1.2 + i * 0.1)
	var body := k.get_node("Body") as Node3D
	var d: Vector3 = k.get_meta("home") - k.position
	if d.length() > 0.05:
		k.position += d.normalized() * minf(d.length(), delta * 3.4)
		k.rotation.y = lerp_angle(k.rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * 10.0))
		body.position.y = absf(sin((st - out_at) * 8.5)) * 0.32
		return
	var to_h := kin_hunter.position - k.position
	k.rotation.y = lerp_angle(k.rotation.y, atan2(-to_h.x, -to_h.z), minf(1.0, delta * 5.0))
	k.set_meta("happy", true)
	var hop := absf(sin(st * 3.2 + i)) * 0.08
	if i == 0:
		hop = _lead_hop(st)
		var rear := _lead_rear(st)
		body.rotation.x = 0.75 * rear      # up on its hind legs, nose raised
		hop += 0.22 * rear
		body.position.z = -0.25 * rear
	elif relic_k > 0.0:
		var since := st - TOUCH_AT - 0.15 * i
		if since > 0.0 and since < 1.4:
			hop = absf(sin(since * 6.5)) * 0.4 * (1.0 - since / 1.4)
	body.position.y = hop

## The lead Boki's hops: quick ones to greet the hunter, still while it noses the relic, then bouncing for joy
## once it has risen clear.
func _lead_hop(st: float) -> float:
	if st < KNEEL_AT + 0.4:
		return absf(sin(st * 7.0)) * 0.3
	if st < RISE_AT + 0.6:
		return 0.03 * sin(st * 4.0)
	return absf(sin(st * 5.0)) * 0.18

## 0..1: the lead Boki rearing up on its hind legs to nose the relic in his hands, down again as it lifts away.
func _lead_rear(st: float) -> float:
	return sin(clampf((st - TOUCH_AT + 0.7) / 1.6, 0.0, 1.0) * PI)

## The woken relic lifts out of his hands and hangs between him and the Boki, clear of both.
func _lift_relic() -> void:
	lifted = true
	var tw := create_tween().set_parallel()
	tw.tween_property(relic, "position", HANG_AT, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(relic, "scale", Vector3(1.3, 1.6, 1.3), 1.0)

## The touch: the relic lights in the Relic's colour, light floods the hunter, specks rise round him and a ring
## sweeps out over the grass.
func _wake_relic() -> void:
	relic_k = 0.001
	var col := Arch.color(MANTLE)
	relic_halo.visible = true
	relic_halo.scale = Vector3.ONE * 0.1
	relic_ring.visible = true
	(relic.get_node("Core") as Node3D).visible = true
	mantle_rise.emitting = true
	Sfx.play("bond", null, -2.0, 0.0, 1.0)
	var mat := relic.material_override as ShaderMaterial
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "relic_k", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(c: Color): mat.set_shader_parameter("albedo", c), DULL, col.darkened(0.15), 0.5)
	tw.tween_method(func(g: float): mat.set_shader_parameter("glow", g), 0.0, 0.35, 0.5)
	tw.tween_property(relic_halo, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var ring := Models.part(self, Models.flat_quad(2.0), Models.ring_mat(col, 0.1), HUNTER_AT + Vector3(0, 0.1, 0))
	ring.scale = Vector3.ONE * 0.2
	var ring_mat := ring.material_override as ShaderMaterial
	tw.tween_property(ring, "scale", Vector3.ONE * 4.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float): ring_mat.set_shader_parameter("color", Color(col, a)), 1.0, 0.0, 1.2)
	tw.chain().tween_callback(ring.queue_free)
