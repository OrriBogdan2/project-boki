class_name ArmorHud
extends RefCounted
## Armor levelling on the HUD. Everyone starts on the same base armor; it levels up as you deal or
## take damage from rival hunters (Hunter.armor_gain: monsters count a third, a knock adds a big chunk),
## and each level blocks more (Hunter.ARMOR_TIERS). HudVitals shows the tier word and a progress hairline
## by the armour strip; this adds a shield badge on the portrait, ringed by that progress, that pops on a
## level-up.
## Look: HudStyle.

const POP := 0.5               # seconds the badge pops after a level-up
const RADIUS := 19.0           # px: the badge at rest

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
	var at := pr.position + Vector2(pr.size.x - 6, pr.size.y - 6)
	var r := RADIUS * grow
	if pop > 0.0:
		c.draw_style_box(HudStyle.box(Color(0, 0, 0, 0), 16, Color(col, 1.0 - k), 4), pr.grow(4.0 + k * 18.0))
	c.draw_circle(at, r, HudStyle.SHADE)
	c.draw_arc(at, r, 0, TAU, 40, HudStyle.SHADE_EDGE, 1.0, true)
	c.draw_arc(at, r - 2.5, 0, TAU, 40, Color(1, 1, 1, 0.12), 3.0, true)
	c.draw_arc(at, r - 2.5, -PI / 2, -PI / 2 + TAU * p.armor_frac(), 40, _next_col(p), 3.0, true)
	Icons.draw(c, "brightshield", at + Vector2(0, -1), 8.0 * grow, col)
	hud.hover_spots.append([Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), "armor_level"])

## The ring's colour: the next tier's, or the top tier's own once there is no next.
static func _next_col(p: Hunter) -> Color:
	if p.armor_tier >= Hunter.ARMOR_TIERS.size() - 1:
		return p.armor_col()
	return Hunter.ARMOR_TIERS[p.armor_tier + 1][1]

static func tip(p: Hunter) -> Array:
	var out: Array = []
	var last: bool = p.armor_tier >= Hunter.ARMOR_TIERS.size() - 1
	out.append(["Armor  ·  %s" % String(Hunter.ARMOR_TIERS[p.armor_tier][0]), p.armor_col()])
	var how := "Everyone starts on the same armor. Deal or take damage from rival hunters to level it up "
	how += "(monsters count a third, a knock a lot)."
	out.append([how, HudStyle.INK, 14])
	if last:
		out.append(["Top level: %d armor." % int(p.max_armor), HudStyle.MUTED, 13])
	else:
		var nx: Array = Hunter.ARMOR_TIERS[p.armor_tier + 1]
		out.append(["Next: %s  ·  %d of %d  ·  blocks %d%%" % [nx[0], int(p.armor_xp), int(nx[2]),
				int(round(float(nx[3]) * 100.0))], nx[1], 13])
	return out
