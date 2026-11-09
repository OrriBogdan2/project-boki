class_name ComboMark
extends RefCounted
## The overhead tag on a rival that carries your combo state (the owner's combo-clarity rule): the
## state's icon in your ability colour, a ring that shrinks with the time left, pips for the stacks, and
## a white flash on the tag and the body when the payoff lands. Sable's Marks, Vex's Daze and Sparkle's
## Static all read through ArchKit.combo_read(), so it only ever shows what the viewer's own kit applied.

const R := 11.0                 # px radius of the icon disc
const RING_W := 3.0             # px width of the time ring
const PIP_R := 2.6              # px radius of one stack pip
const PIP_GAP := 7.0            # px between pip centres
const LOW_FRAC := 0.25          # the ring turns red under this much of the time left
const FLASH_BODY := 0.12 + 2.0 / 60.0   # s on Ent.flash_t: full white for 2 frames, then the usual fade
const FLASH_TAG := 0.05         # s the tag stays white after a payoff
const SND_GAP := 0.2            # s between two payoff sounds on one body (a rifle pays off every shot)
const PAY_KEY := "cm_pay"       # meta on the body: match time of the last payoff

## Called by a kit when its payoff lands on `t`: the body flashes white and the combo sound plays.
static func payoff(m: Node, h: Hunter, t: Ent) -> void:
	var gap: float = float(m.time) - float(t.get_meta(PAY_KEY, -9.0))
	t.set_meta(PAY_KEY, m.time)
	t.flash_t = FLASH_BODY
	m.fx.flash(t.pos + Vector3(0, 1.1, 0), h.ak.res_col().lerp(Color.WHITE, 0.6), 1.4, 0.1)
	if gap > SND_GAP:
		m.sfx("combo", t.pos, -1.0, 1.15)

## Draws the tag centred on `at` for `e`, if `viewer`'s kit has combo state on it.
static func draw(c: Control, at: Vector2, viewer: Hunter, e: Ent, time: float) -> void:
	if viewer == null or viewer.ak == null or e == null:
		return
	var d: Dictionary = viewer.ak.combo_read(e)
	if d.is_empty():
		return
	at.y -= float(d.get("lift", 0.0))     # a kit with its own marker in that spot (Sparkle's Static)
	var col: Color = viewer.ak.res_col()
	var hot := time - float(e.get_meta(PAY_KEY, -9.0)) < FLASH_TAG
	var frac := clampf(float(d["left"]) / maxf(0.01, float(d["total"])), 0.0, 1.0)
	c.draw_circle(at, R + 2.0, Color(0, 0, 0, 0.7))
	c.draw_circle(at, R - 2.0, Color.WHITE if hot else Color(col, 0.22))
	var ring_col := Color("ff5a4a") if frac < LOW_FRAC else col
	c.draw_arc(at, R, -PI * 0.5, -PI * 0.5 + TAU * frac, 28, ring_col, RING_W, true)
	Icons.draw(c, String(d["icon"]), at, R * 0.5, Color.WHITE if hot else col)
	var pips := int(d["max"])
	var lit := int(d["n"])
	for i in pips:
		var p := at + Vector2((i - (pips - 1) * 0.5) * PIP_GAP, -R - 7.0)
		c.draw_circle(p, PIP_R + 1.0, Color(0, 0, 0, 0.7))
		c.draw_circle(p, PIP_R, col if i < lit else Color(1, 1, 1, 0.2))
	HudStyle.ctext(c, at + Vector2(R + 16.0, 4.0), "%.1f" % float(d["left"]), 11, ring_col)
