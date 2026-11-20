class_name HudGroups
extends RefCounted
## The match HUD's separately placed blocks ("groups"), counted the way docs/UI_FIRST15.md counts them. Rules:
## content/rules/hud_groups.json. When each block shows is HudReveal's (content/rules/hud_reveal.json); this only
## counts. Reads the match and the Hud only; draws nothing.

static func rules() -> Dictionary:
	return Content.rules("hud_groups")

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
	if HudReveal.kit_wanted(hud, p) and not (p.dropping or p.riding) and m.time - hud.kit_t0 <= HudReveal.kit_s(m):
		out.append("kit")
	if m.heart != null and m.heart.site != Vector3.INF and HudReveal.ways_out_shown(m):
		out.append("ways_out")
	return out
