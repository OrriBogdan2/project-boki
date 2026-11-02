class_name ArmorHud
extends RefCounted
## Armor levelling on the HUD. Everyone starts on the same base armor; it levels up as you deal
## damage to rival hunters (Hunter.armor_gain: monsters count a third, a knock adds a big chunk), and
## each level adds plates. Shown as the tier name beside the armor number, a hairline of progress to
## the next tier, and a shield badge on the portrait ringed by that progress that pops on a level-up.

const POP := 0.5               # seconds the badge pops after a level-up

## The tier word and the progress hairline over the armor bar, at the vitals' left edge x0, top y0.
static func bar(hud, p: Hunter, x0: float, y0: float, w: float) -> void:
	var c: Control = hud.c
	if p.armor > 0.5:
		var at := "%d" % int(ceil(p.armor))
		var aw: float = hud.big.get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var tier_txt := String(Hunter.ARMOR_TIERS[p.armor_tier][0]).to_upper()
		hud._text(Vector2(x0 + w - aw, y0 - 2), at, 13, p.armor_col(), hud.big)
		hud._text(Vector2(x0 + w - aw - 8 - hud.big.get_string_size(tier_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, y0 - 3), tier_txt, 10, Color(p.armor_col(), 0.75), hud.big)
	if p.armor_tier < Hunter.ARMOR_TIERS.size() - 1:
		var nxt: Color = Hunter.ARMOR_TIERS[p.armor_tier + 1][1]
		c.draw_rect(Rect2(Vector2(x0, y0 + 3), Vector2(w, 2)), Color(0, 0, 0, 0.35))
		c.draw_rect(Rect2(Vector2(x0, y0 + 3), Vector2(w * p.armor_frac(), 2)), Color(nxt, 0.9))

## The badge at the portrait's bottom-right corner: a shield in the tier's colour ringed by progress.
static func badge(hud, pr: Rect2, p: Hunter) -> void:
	var c: Control = hud.c
	var seen: int = int(hud.get_meta("armor_seen", -1))
	if seen >= 0 and p.armor_tier > seen:
		hud.set_meta("armor_pop", POP)
	hud.set_meta("armor_seen", p.armor_tier)
	var pop: float = maxf(0.0, float(hud.get_meta("armor_pop", 0.0)) - hud.get_process_delta_time())
	hud.set_meta("armor_pop", pop)
	var k := 1.0 - pop / POP
	var sc := 1.0 + 0.35 * sin(k * PI) if pop > 0.0 else 1.0
	var col: Color = p.armor_col()
	var bc := pr.position + Vector2(pr.size.x - 6, pr.size.y - 6)
	var r := 19.0 * sc
	if pop > 0.0:
		hud._rounded(pr.grow(4.0 + k * 18.0), Color(0, 0, 0, 0), 16, Color(col, 1.0 - k), 4)
	c.draw_circle(bc, r, Color(0.03, 0.03, 0.05, 0.97))
	c.draw_arc(bc, r - 2.5, 0, TAU, 40, Color(1, 1, 1, 0.12), 3.0, true)
	c.draw_arc(bc, r - 2.5, -PI / 2, -PI / 2 + TAU * p.armor_frac(), 40, col if p.armor_tier >= Hunter.ARMOR_TIERS.size() - 1 else Hunter.ARMOR_TIERS[p.armor_tier + 1][1], 3.0, true)
	Icons.draw(c, "brightshield", bc + Vector2(0, -1), 8.0 * sc, col)
	hud.hover_spots.append([Rect2(bc - Vector2(r, r), Vector2(r, r) * 2.0), "armor_level"])

static func tip(p: Hunter) -> Array:
	var out: Array = []
	var last: bool = p.armor_tier >= Hunter.ARMOR_TIERS.size() - 1
	out.append(["Armor  ·  %s" % String(Hunter.ARMOR_TIERS[p.armor_tier][0]), p.armor_col()])
	out.append(["Everyone starts on the same armor. Deal damage to rival hunters to level it up (monsters count a third, a knock a lot).", Color("f3eee2"), 14])
	if last:
		out.append(["Top level: %d armor." % int(p.max_armor), Color("a9b0bf"), 13])
	else:
		var nx: Array = Hunter.ARMOR_TIERS[p.armor_tier + 1]
		out.append(["Next: %s  ·  %d of %d  ·  +%d%% plates" % [nx[0], int(p.armor_xp), int(nx[2]), int(Hunter.ARMOR_TIER_BONUS * 100.0)], nx[1], 13])
	return out
