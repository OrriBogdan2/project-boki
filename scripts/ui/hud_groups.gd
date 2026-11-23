class_name HudGroups
extends RefCounted
## The match HUD's separately placed blocks ("groups"), counted the way docs/UI_FIRST15.md counts them. Rules:
## content/rules/hud_groups.json. When each block shows is HudReveal's (content/rules/hud_reveal.json); this only
## counts. Reads the match and the Hud only; draws nothing.

static func rules() -> Dictionary:
	return Content.rules("hud_groups")

## The clock/status strip under the minimap: a save's first expeditions hold it back until the first Ways Out beat (a
## seat within seat_pips' lead_s of opening, open, taken or lost; or you are out) or your first kill or knock
## (DECISIONS 2026-11-08), then it stays (HudReveal "beat_clock", remembered in the save). Through HudReveal's table:
## from match 4 on (or Tab, Settings "Show full HUD", a tutorial or training room) it always shows.
static func clock_shown(m: Match) -> bool:
	if HudReveal.on(m, "beat_clock"):
		return true
	var p: Hunter = m.player
	var beat: bool = p != null and p.kills + p.knocks > 0
	if not beat and m.heart != null and m.heart.site != Vector3.INF:
		beat = HudReveal.ways_out_shown(m)
	if beat:
		HudReveal.see("beat_clock")
	return beat

## The gear strip (GearPanel's four slots): HudReveal's "gear" stage is open and a slot holds gear. Until then
## nothing is drawn, so nothing is counted (the perk row is held the same way: HudReveal "perks", and a perk picked up).
static func gear_shown(m: Match, p: Hunter) -> bool:
	return HudReveal.on(m, "gear") and GearPanel.worn_any(p)

## The glider ring (Hud._draw_glider_heat) draws only while you glide or the meter is not full.
static func glider_shown(p: Hunter) -> bool:
	return not (p.dropping or p.downed or p.riding) and (p.gliding or p.glide_fuel < 0.99)

## The ids of the groups on screen now: the always-on blocks plus the ones that come and go.
static func on_screen(hud) -> Array:
	var m: Match = hud.m
	var p: Hunter = m.player
	var out: Array = (rules()["always"] as Array).duplicate()
	if gear_shown(m, p):
		out.append("gear")
	if HudReveal.on(m, "counters"):
		out.append("counters")
	if glider_shown(p):
		out.append("glider")
	if BeltHud.shown(m, p):
		out.append("belt")
	if p.perks.size() > 0 and HudReveal.on(m, "perks"):
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
