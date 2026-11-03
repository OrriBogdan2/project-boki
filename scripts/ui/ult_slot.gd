class_name UltSlot
extends RefCounted
## The hero ultimate's slot in the HUD's ability row (X, HeroUlt): the cooldown like the other slots, a
## "LV 6" tag and a dark face until it unlocks, and a ring while it runs. Returns the next free x.

static func draw(hud, p: Hunter, x: float, y: float, s: float, gap: float) -> float:
	if p.ak == null or not p.ak.has_ult():
		return x
	var xi := p.slot_info("x")
	var r := Rect2(Vector2(x, y), Vector2(s, s))
	var col: Color = xi["col"]
	var cd_left := float(xi["cd"])
	var cd_frac := cd_left / maxf(0.01, float(xi["cd_max"])) if cd_left > 0.0 else 0.0
	hud._ab_slot("x", r, String(xi["icon"]), Settings.key_cap("hunter_ult"), col, cd_frac, cd_left, bool(xi["ready"]))
	if bool(xi["locked"]):
		hud._rounded(r, Color(0.02, 0.02, 0.04, 0.6), 12)
		var tag := "LV %d" % int(xi["unlock"])
		hud._ctext(Vector2(r.get_center().x, r.position.y - 6), tag, 10, Color(UI.INK, 0.85), hud.big)
	elif bool(xi["up"]):
		hud.c.draw_arc(r.get_center(), s * 0.5 + 4.0, 0.0, TAU, 32, Color(col, 0.9), 3.0, true)
	return x + s + gap
