class_name BodyTell
extends RefCounted
## What a Hunter's own body says in a fight, with nothing added to the HUD (docs/COMBAT_CLARITY.md):
## - crowd control on it lasts on it: the body pulses in that colour (hero_toon `tell`) while it lasts, under the
##   status's own look on the body (StatusLooks: stars over the head, stakes at the feet, rings down the legs);
## - a cast flashes it: an ability (not the LMB or the dash) glints the body in the Hunter's signature colour and
##   pulses a ring under the caster in the viewer's side colour (SideColor.fx), so who's doing something reads first.
## Presentation only.

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


## Every frame, on every Hunter (Hunter.render).
static func tick(h: Hunter, _delta: float) -> void:
	if h.model == null or h.m == null:
		return
	var stun := h.stun_t > 0.0 and not h.downed
	var root := h.root_t > 0.0 and not h.downed
	var slow := h.slow_t > 0.0 and h.stagger_t <= 0.0 and not h.downed  # (a big hit's stagger is a slow too)
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
		var col := SideColor.fx(h.m, h, Arch.color(h.arch))
		h.m.fx.ring(h.pos + Vector3(0, 0.05, 0), CAST_RING_R, col, CAST_RING_T, SideColor.order(h.m, h))


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
