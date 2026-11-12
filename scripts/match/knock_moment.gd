class_name KnockMoment
extends RefCounted
## The step a Hunter is knocked (Match.knock): everything the knock interrupts stops on that step, and
## nothing pressed before or during it goes off afterwards. Source (briefs/supervive-data): a knock
## cancels a held channel outright, it never completes; and the knocked body moves under its own rule
## from that moment (a knocked movement multiplier), so the Wisp answers the keys on the next step.
## docs/MOVEMENT_FEEL.md "The knock moment"; checked by --knock-moment-check.

static func cut(m: Match, h: Hunter) -> void:
	m.cancel_abilities(h)        # a sword charge, a sniper wind-up, a strike waiting on a lunge
	h.draw_t = -1.0              # a bow draw is dropped: its release never looses
	h.swing_buf = 0.0            # a tap buffered mid-swing is forgotten
	h.dash_buf = 0.0             # a Shift waiting for a move to end is forgotten
	h.jump_buf = 0.0             # so is a jump waiting for the ground
	if h.roll_t > 0.0:
		# a dash in flight ends where the knock lands it; only the hit's own knockback still carries
		h.roll_t = 0.0
		if h.knock_t <= 0.0:
			h.vel.x = 0.0
			h.vel.z = 0.0
	if h.ak:
		h.ak.rmb_down = false      # a held RMB is dropped, never released into its cast; its aim ring shuts
		h.ak.flow.held.clear()     # presses waiting for a dash's end never replay
		h.ak.flow.landing.clear()
