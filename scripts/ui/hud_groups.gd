class_name HudGroups
extends RefCounted
## The match HUD's separately placed blocks ("groups"), counted the way docs/UI_FIRST15.md counts them, and the
## reveal rules for a newcomer: the Ways Out strip (0.24.5), and for a save under NEW_PLAYER_MATCHES expeditions the
## "Your kit" card and the row of your own kills/knocks/gems (docs/HUD.md "First real match"). Rules:
## content/rules/hud_groups.json. Reads the match and the Hud only; draws nothing.

const KIT_S := 14.0      # s after landing the "what each button does" card stays up (Hud._draw_kit)
const NEW_PLAYER_MATCHES := 3      # expeditions a save has played before the whole HUD shows by itself

static func new_player() -> bool:
	return int(Save.d.get("matches", 0)) < NEW_PLAYER_MATCHES

## Your own kills, knocks and gems (AliveCounter's quieter row): not before the first kill, knock or gem, or while
## Tab / the map key is held. The squads/players left above it always show.
static func own_numbers_shown(p: Hunter, hold: bool) -> bool:
	return not new_player() or hold or (p != null and p.kills + p.knocks + p.gems > 0)

static func rules() -> Dictionary:
	return Content.rules("hud_groups")

## Does this player get the button card at all (Settings tips, not a recording, not the tutorial, alive)? A new
## player has the slots and their keys and the words on hover; the training room keeps the card.
static func kit_wanted(hud, p: Hunter) -> bool:
	return Settings.get_v("tips") and not Record.clean() and not hud.m.opts.get("tutorial", false) \
			and not p.out and not hud.guide_hidden and (not new_player() or hud.m.opts.get("training", false))

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
	if not hud.loot.rows.is_empty():
		out.append("loot")
	if not m.interact.is_empty():
		out.append("prompt")
	if kit_wanted(hud, p) and not (p.dropping or p.riding) and m.time - hud.kit_t0 <= KIT_S:
		out.append("kit")
	if m.heart != null and m.heart.site != Vector3.INF and ways_out_shown(m):
		out.append("ways_out")
	return out
