class_name CarryHints
extends RefCounted
## One-line first-time hints for carrying Boki (DECISIONS 2026-11-11 "carry 2 in, 1 extra out", DECISIONS 11-08
## shorter tutorials: a hint, never a step). Each shows once per save through Match.tip_once, only while hints
## are on and not in a tutorial or arena. The pieces: the swap key (the first time the lead's summon is on
## cooldown with a second Boki along), the first claim (it rides home, it can be stolen), a full slot with a
## teammate who has room (Capture.full_note).

## Are hints wanted for this match and player?
static func wanted(m) -> bool:
	return m.player != null and Settings.get_v("tips") and not m.opts.get("autoplay", false) \
		and not m.opts.get("tutorial", false) and not m.opts.get("arena", false)

## Each frame (from Match._tips): name the swap key once the lead cannot be summoned right now.
static func swap(m) -> void:
	var p: Hunter = m.player
	var lead: Kin = p.kin
	if p.kin2 == null or lead == null or p.downed or not (lead.throw_cd > 0.0 or lead.resting()):
		return
	m.tip_once("carry_swap", "%s swaps to your second Boki while %s recovers" % [Settings.key_cap("swap_kin"),
		lead.rec.get("name", "your lead")])

## A Boki was claimed in the match: it rides home in the carry-out slot, and goes with you if you are downed.
static func claimed(m, h: Hunter, rec: Dictionary) -> void:
	if h != m.player or Capture.is_stolen(h, rec) or not wanted(m):
		return
	m.tip_once("carry_claim", "%s rides home if you get out. If you go down, it can be stolen" % rec.get("name", "It"))
