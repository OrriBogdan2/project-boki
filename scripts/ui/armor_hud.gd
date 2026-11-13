class_name ArmorHud
extends RefCounted
## Armor levelling on the HUD. Everyone starts on the same base armor; it levels up as you deal
## damage to rival hunters (Hunter.armor_gain: monsters count a third, a knock adds a big chunk), and
## each level adds plates. HudVitals shows the tier word by the armour strip and calls bar() for a thin
## progress bar under it; this adds a shield badge on the portrait, ringed by that progress, that pops on a level-up.
## Look: HudStyle.

const POP := 0.5               # seconds the badge pops after a level-up
const RADIUS := 19.0           # px: the badge at rest
const BAR_H := 2.0             # px: the progress bar under the armour strip
const TICK := 0.5              # seconds the head tick shows after armour progress grows

## The badge at the portrait's bottom-right corner: a shield in the tier's colour ringed by progress.
static func badge(hud, pr: Rect2, p: Hunter) -> void:
	var c: CanvasItem = hud.c
	var seen: int = int(hud.get_meta("armor_seen", -1))
	if seen >= 0 and p.armor_tier > seen:
		hud.set_meta("armor_pop", POP)
	hud.set_meta("armor_seen", p.armor_tier)
	var pop: float = maxf(0.0, float(hud.get_meta("armor_pop", 0.0)) - hud.get_process_delta_time())
	hud.set_meta("armor_pop", pop)
	var k := 1.0 - pop / POP
	var grow := 1.0
	if pop > 0.0:
		grow = 1.0 + 0.35 * sin(k * PI)
	var col: Color = p.armor_col()
	var at := pr.end - Vector2(RADIUS, RADIUS)      # inside the portrait corner: the badge stays in the safe area
	var r := RADIUS * grow
	if pop > 0.0:
		c.draw_style_box(HudStyle.box(Color(0, 0, 0, 0), 16, Color(col, 1.0 - k), 4), pr.grow(4.0 + k * 18.0))
	c.draw_circle(at, r, HudStyle.SHADE)
	c.draw_arc(at, r, 0, TAU, 40, HudStyle.SHADE_EDGE, 1.0, true)
	c.draw_arc(at, r - 2.5, 0, TAU, 40, Color(1, 1, 1, 0.12), 3.0, true)
	c.draw_arc(at, r - 2.5, -PI / 2, -PI / 2 + TAU * p.armor_frac(), 40, _next_col(p), 3.0, true)
	Icons.draw(c, "brightshield", at + Vector2(0, -1), 8.0 * grow, col)
	hud.hover_spots.append([Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), "armor_level"])

## Progress to the next tier as a thin bar in the current tier's colour (full at the top tier); a short
## bright tick at its head marks a hit that added to it. The tier's name shows on hover only.
static func bar(hud, x: float, y: float, w: float, p: Hunter) -> void:
	var c: CanvasItem = hud.c
	# (match time, not frame delta: the vitals redraw at HudPanels.REDRAW_HZ, not every frame)
	if p.armor_xp > float(hud.get_meta("armor_xp_seen", p.armor_xp)):
		hud.set_meta("armor_tick_at", hud.m.time)
	hud.set_meta("armor_xp_seen", p.armor_xp)
	var tick := maxf(0.0, TICK - (hud.m.time - float(hud.get_meta("armor_tick_at", -TICK))))
	var r := Rect2(x, y, w, BAR_H)
	c.draw_rect(r, Color(0, 0, 0, 0.35))
	var fw := w * p.armor_frac()
	c.draw_rect(Rect2(x, y, fw, BAR_H), p.armor_col())
	if tick > 0.0:
		c.draw_rect(Rect2(x + fw - 1.0, y - 2.0, 2.0, BAR_H + 4.0), Color(1, 1, 1, tick / TICK))
	hud.hover_spots.append([r.grow_individual(0, 4, 0, 4), "armor_level"])

## The ring's colour: the next tier's, or the top tier's own once there is no next.
static func _next_col(p: Hunter) -> Color:
	if p.armor_tier >= Hunter.ARMOR_TIERS.size() - 1:
		return p.armor_col()
	return Hunter.ARMOR_TIERS[p.armor_tier + 1][1]

static func tip(p: Hunter) -> Array:
	var out: Array = []
	var last: bool = p.armor_tier >= Hunter.ARMOR_TIERS.size() - 1
	out.append(["Armor  ·  %s" % String(Hunter.ARMOR_TIERS[p.armor_tier][0]), p.armor_col()])
	var how := "Everyone starts on the same armor. Deal damage to rival hunters to level it up "
	how += "(monsters count a third, a knock a lot)."
	out.append([how, HudStyle.INK, 14])
	if last:
		out.append(["Top level: %d armor." % int(p.max_armor), HudStyle.MUTED, 13])
	else:
		var nx: Array = Hunter.ARMOR_TIERS[p.armor_tier + 1]
		out.append(["Next: %s  ·  %d of %d  ·  +%d%% plates" % [nx[0], int(p.armor_xp), int(nx[2]),
				int(Hunter.ARMOR_TIER_BONUS * 100.0)], nx[1], 13])
	return out
