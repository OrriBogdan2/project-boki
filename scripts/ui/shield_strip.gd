class_name ShieldStrip
extends RefCounted
## Your shield in the bottom-left vitals (HudVitals): one pale strip laid over the top of the health bar,
## since a hit drains it before health, with its source's icon and amount in the numbers row. The strip
## joins the pools in the order a hit drains them: Albert's raised aegis, the timed shield (`Hunter.shield`,
## named by ShieldSrc) and the Boki owner shield (`kin_shield`), with a dark notch between pools. A timed
## shield drops whole when its time runs out (docs/ABILITIES.md, Shields), so it fades over its last
## FADE_S seconds as the warning.

const H_PX := 6.0  # px: the strip's height, over the top of the health bar
const FADE_S := 1.5  # s: a timed shield fades out over this much of its time left
const FADE_MIN := 0.3  # alpha a timed shield has fallen to when it drops
const ICON_TILE := 14.0  # px: the source icon's tile
const TXT := 14  # font size of the amount

static var shown := {}  # what the last draw showed (checks read it): {amount, icon, alpha, frac}


## The pools up now, in the order a hit drains them: [amount, icon, alpha]. Empty with no shield.
static func pools(p: Hunter) -> Array:
	var out: Array = []
	var bk := p.ak as BulwarkKit
	if bk and not bk.wall.is_empty() and float(bk.wall["hp"]) > 0.5:
		out.append([float(bk.wall["hp"]), ShieldSrc.ITEM, 1.0])
	if p.shield > 0.5:
		out.append([p.shield, p.shield_src if p.shield_src != "" else ShieldSrc.ITEM, fade(p.shield_t)])
	if p.kin_shield > 0.5:
		out.append([p.kin_shield, ShieldSrc.BOKI, 1.0])
	return out


## The timed shield's alpha with `time_left` on it (0: no timer, it stays until broken).
static func fade(time_left: float) -> float:
	if time_left <= 0.0 or time_left >= FADE_S:
		return 1.0
	return lerpf(FADE_MIN, 1.0, time_left / FADE_S)


## The strip over the top of `hr` (the health bar) and the icon + amount from `label_x` on the numbers'
## baseline `base_y`.
static func draw(c: CanvasItem, hr: Rect2, p: Hunter, label_x: float, base_y: float) -> void:
	var ps := pools(p)
	if ps.is_empty():
		shown = {}
		return
	var total := 0.0
	for pool in ps:
		total += float(pool[0])
	var x := hr.position.x
	var max_hp := maxf(1.0, p.max_hp)
	var notches := PackedVector2Array()
	for pool in ps:
		var pw := minf(hr.size.x * float(pool[0]) / max_hp, hr.end.x - x)
		c.draw_rect(Rect2(Vector2(x, hr.position.y), Vector2(pw, H_PX)), Color(HudStyle.SHIELD, float(pool[2])))
		x += pw
		notches.append_array([Vector2(x, hr.position.y), Vector2(x, hr.position.y + H_PX)])
	var edge := Rect2(Vector2(hr.position.x, hr.position.y + H_PX), Vector2(x - hr.position.x, 1.0))
	c.draw_rect(edge, HudStyle.SHADE_EDGE)
	c.draw_multiline(notches, HudStyle.SHADE_EDGE, 1.0)
	var lead: Array = ps[0]
	var col := Color(HudStyle.SHIELD, float(lead[2]))
	var tile := Rect2(Vector2(label_x, base_y - ICON_TILE + 1.0), Vector2(ICON_TILE, ICON_TILE))
	c.draw_rect(tile, HudStyle.SHADE)
	c.draw_rect(tile, Color(col, col.a * 0.8), false, 1.0)
	Icons.draw(c, String(lead[1]), tile.get_center(), ICON_TILE * 0.36, col)
	HudStyle.text(c, Vector2(tile.end.x + 4.0, base_y), str(int(ceil(total))), TXT, col)
	shown = {"amount": total, "icon": String(lead[1]), "alpha": float(lead[2]), "frac": (x - hr.position.x) / hr.size.x}
