class_name CarryHints
extends RefCounted
## One-line first-time hints for carrying Boki ("carry 2 in, 1 extra out"; a hint, never a step). Each
## shows once per save through Match.tip_once, only while hints are on and not in a tutorial or arena: the swap
## key (the first time the lead cannot be summoned with a second Boki along), the first claim (it rides home and
## can be stolen), and a full slot with a teammate who has room (Capture.full_note).

const SWAP_KEY := "carry_swap"
const CLAIM_KEY := "carry_claim"
const FULL_KEY := "carry_full"


## Are hints wanted for this match and player?
static func wanted(m: Match) -> bool:
	return (
		m.player != null
		and Settings.get_v("tips")
		and not m.opts.get("autoplay", false)
		and not m.opts.get("tutorial", false)
		and not m.opts.get("arena", false)
	)


## The swap hint when it is due, as [save key, line], or [] (Match._tips shows it).
static func swap(m: Match) -> Array:
	var p := m.player
	var lead: Kin = p.kin
	if p.kin2 == null or lead == null or p.downed or not (lead.throw_cd > 0.0 or lead.resting()):
		return []
	var lead_name := String(lead.rec.get("name", "your lead"))
	return [SWAP_KEY, "%s swaps to your second Boki while %s recovers" % [Settings.key_cap("swap_kin"), lead_name]]


## A Boki was claimed in the match: it rides home in the carry-out slot, and can be stolen if you are downed.
static func claimed(m: Match, h: Hunter, rec: Dictionary) -> void:
	if h == m.player and not Capture.is_stolen(h, rec) and wanted(m) and m.tip_once(CLAIM_KEY):
		var line := "%s rides home if you get out. If you go down, it can be stolen"
		m.hud.tip(line % rec.get("name", "It"))


## The first blocked claim that has a teammate with room shows its line as a hint; true if it did.
static func full(m: Match, line: String) -> bool:
	if not wanted(m) or not m.tip_once(FULL_KEY):
		return false
	m.hud.tip(line)
	return true
