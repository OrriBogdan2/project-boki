class_name BodyTell
extends RefCounted
## What a Hunter's own body says in a fight, with nothing added to the HUD (docs/COMBAT_CLARITY.md):
## - crowd control on it lasts on it: a stun spins a ring of stars over the head, a root grows tendrils round the
##   feet, a slow drips frost down the legs, and the body pulses in that colour (hero_toon `tell`) while it lasts;
## - a cast flashes it: an ability (not the LMB or the dash) glints the body in the Hunter's signature colour and
##   pulses a ring under the caster in the viewer's side colour (SideColor.fx), so who's doing something reads first.
## The Bola's Grounded and Vex's Dazed draw their own on the body (KitStatus). Presentation only.

const STUN_COL := Color("fff27a")
const ROOT_COL := Color("8fe0a0")
const SLOW_COL := Color("9ae8ff")
const STUN_HZ := 4.0  # body pulses a second while stunned
const ROOT_HZ := 2.0  # ... rooted
const CC_K := 0.55  # the body tint's strength under crowd control
const SLOW_K := 0.35  # ... slowed (it's the mildest)
const GLINT_T := 0.3  # s a cast's glint takes to fade
const GLINT_K := 0.7  # the glint's strength at the cast
const CAST_RING_R := 1.3  # m, the ring under a caster
const CAST_RING_T := 0.3  # s it lasts
const STUN_Y := 2.15  # m over the feet (x the Hunter's scale) the stars spin
const STUN_SPIN := 9.0  # rad/s
const ROOT_GROW := 0.15  # s the tendrils take to rise
const DRIP_T := 0.7  # s a frost drip takes to run down the legs


## Every frame, on every Hunter (Hunter.render).
static func tick(h: Hunter, delta: float) -> void:
	if h.model == null or h.m == null:
		return
	var stun := h.stun_t > 0.0 and not h.downed
	var root := h.root_t > 0.0 and not h.downed
	var slow := h.slow_t > 0.0 and h.stagger_t <= 0.0 and not h.downed  # (a big hit's stagger is a slow too)
	var props := h.get_node_or_null("BodyTell") as Node3D
	if props == null and (stun or root or slow):
		props = _props(h)
	if props:
		props.visible = h.model.visible  # (a cloak or a stand-in hides them with the body)
		_show(props, stun, root, slow, h, delta)
	var t := Color.TRANSPARENT
	var hz := 0.0
	if stun:
		t = Color(STUN_COL, CC_K)
		hz = STUN_HZ
	elif root:
		t = Color(ROOT_COL, CC_K)
		hz = ROOT_HZ
	elif slow:
		t = Color(SLOW_COL, SLOW_K)
	else:
		var since: float = h.m.time - h.cast_at
		if since < GLINT_T:
			t = Color(Arch.color(h.arch), GLINT_K * pow(1.0 - since / GLINT_T, 2.0))
	_tint(h, t, hz)
	if h.cast_at > float(h.get_meta("tell_cast", -9.0)):
		h.set_meta("tell_cast", h.cast_at)
		h.m.fx.ring(h.pos + Vector3(0, 0.05, 0), CAST_RING_R, SideColor.fx(h.m, h, Arch.color(h.arch)), CAST_RING_T)


## The body's tint now (transparent when none), for checks.
static func tint_of(h: Hunter) -> Color:
	return h.get_meta("tell_tint", Color.TRANSPARENT)


static func _tint(h: Hunter, t: Color, hz: float) -> void:
	if h.get_meta("tell_tint", Color.TRANSPARENT) == t and h.get_meta("tell_n", -1) == h.mats.size():
		return
	for mt in h.mats:
		mt.set_shader_parameter("tell", t)
		mt.set_shader_parameter("tell_hz", hz)
	h.set_meta("tell_tint", t)
	h.set_meta("tell_n", h.mats.size())


static func _show(props: Node3D, stun: bool, root: bool, slow: bool, h: Hunter, delta: float) -> void:
	var s := props.get_node("Stun") as Node3D
	s.visible = stun
	if stun:
		s.rotation.y += delta * STUN_SPIN
	var r := props.get_node("Root") as Node3D
	if root and not r.visible:
		r.set_meta("at", h.m.time)
	r.visible = root
	if root:
		r.scale.y = clampf((h.m.time - float(r.get_meta("at"))) / ROOT_GROW, 0.05, 1.0)
	var w := props.get_node("Slow") as Node3D
	w.visible = slow
	if slow:
		var drips := w.get_node("Drips")
		for i in drips.get_child_count():
			var k := fmod(h.m.time / DRIP_T + i * 0.25, 1.0)
			var d := drips.get_child(i) as Node3D
			d.position.y = lerpf(1.1, 0.1, k)
			d.scale = Vector3.ONE * (1.0 - k * 0.6)


## The stars, the tendrils and the frost, built the first time this body is held by any of them.
static func _props(h: Hunter) -> Node3D:
	var sc := float(h.cdat.get("scale", 1.0))
	var n := Node3D.new()
	n.name = "BodyTell"
	n.scale = Vector3.ONE * sc
	var stun := Node3D.new()
	stun.name = "Stun"
	stun.position.y = STUN_Y
	var star := Models.glow_mat(STUN_COL)
	for i in 3:
		var a := TAU * i / 3.0
		Models.part(stun, Models.crystal(0.07, 0.14, 4), star, Vector3(cos(a) * 0.34, 0.0, sin(a) * 0.34))
	Models.part(stun, Models.flat_quad(0.8), Models.ring_mat(Color(STUN_COL, 0.9), 0.1))
	n.add_child(stun)
	var root := Node3D.new()
	root.name = "Root"
	var vine := DJFx.solid(ROOT_COL)
	for i in 5:
		var a := TAU * i / 5.0
		# a tendril out from the feet, leaning in over them
		Models.part(
			root,
			Models.cyl(0.012, 0.05, 0.6, 5),
			vine,
			Vector3(cos(a) * 0.42, 0.28, sin(a) * 0.42),
			Vector3.ONE,
			Vector3(0.0, -a, 0.55)
		)
	Models.part(root, Models.flat_quad(1.2), Models.ring_mat(Color(ROOT_COL, 0.95), 0.14), Vector3(0, 0.05, 0))
	n.add_child(root)
	var slow := Node3D.new()
	slow.name = "Slow"
	Models.part(slow, Models.flat_quad(1.0), Models.ring_mat(Color(SLOW_COL, 0.85), 0.12), Vector3(0, 0.05, 0))
	var drips := Node3D.new()
	drips.name = "Drips"
	var ice := Models.glow_mat(Color(SLOW_COL, 0.9))
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		Models.part(
			drips,
			Models.crystal(0.04, 0.1, 4),
			ice,
			Vector3(cos(a) * 0.3, 1.0, sin(a) * 0.3),
			Vector3.ONE,
			Vector3(PI, 0, 0)
		)
	slow.add_child(drips)
	n.add_child(slow)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(n)
	return n
