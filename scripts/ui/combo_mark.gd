class_name ComboMark
extends RefCounted
## The payoff of a combo state on a foe (the owner's combo-clarity rule): the body flashes white and the combo
## sound plays when the payoff lands. The state itself shows in the foe's plate status row (HudPlate.row), from
## the kit's ArchKit.combo_marks, so only the hunter whose kit applied it sees it.

const FLASH_BODY := 0.12 + 2.0 / 60.0   # s on Ent.flash_t: full white for 2 frames, then the usual fade
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
