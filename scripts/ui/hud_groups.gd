class_name HudGroups
extends RefCounted
## The match HUD's separately placed blocks ("groups"), counted the way docs/UI_FIRST15.md counts them, and the
## reveal rule for the 0.24.5 newcomer (the Ways Out strip). Rules: content/rules/hud_groups.json.
## Reads the match and the Hud only; draws nothing.

const KIT_S := 14.0      # s after landing the "what each button does" card stays up (Hud._draw_kit)

static func rules() -> Dictionary:
	return Content.rules("hud_groups")

## Does this player get the button card at all (Settings tips, not a recording, not the tutorial, alive)?
static func kit_wanted(hud, p: Hunter) -> bool:
	return Settings.get_v("tips") and not Record.clean() and not hud.m.opts.get("tutorial", false) \
			and not p.out and not hud.guide_hidden

## True once the strip has something to tell: a seat is open, in use, taken or lost, or one opens within
## ways_out_lead_s. Always for a player who is out (the "Ways out left" line is theirs).
static func ways_out_shown(m: Match) -> bool:
	var p: Hunter = m.player
	if p == null or p.out or p.extracted:
		return true
	var lead: float = rules()["ways_out_lead_s"]
	for s in WaysOutHud.seats(m):
		if int(s["st"]) != WaysOutHud.St.LOCKED or float(s["t"]) <= lead:
			return true
	return false

## The ids of the groups on screen now: the always-on blocks plus the ones that come and go.
static func on_screen(hud) -> Array:
	var m: Match = hud.m
	var p: Hunter = m.player
	var out: Array = (rules()["always"] as Array).duplicate()
	if p.perks.size() > 0:
		out.append("perks")
	if m.hunters.any(func(h): return h != p and h.team == p.team):
		out.append("squad")
	if hud.msgs.count() > 0:
		out.append("messages")
	if not m.interact.is_empty():
		out.append("prompt")
	if kit_wanted(hud, p) and not (p.dropping or p.riding) and m.time - hud.kit_t0 <= KIT_S:
		out.append("kit")
	if m.heart != null and m.heart.site != Vector3.INF and ways_out_shown(m):
		out.append("ways_out")
	return out
