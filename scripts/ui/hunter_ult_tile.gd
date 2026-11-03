class_name HunterUltTile
extends RefCounted
## The hero's own ultimate (X, HeroUlt) on the ability row beside Shift and E: its icon, a padlock and the level it
## opens at until then, the cooldown sweep and countdown after a cast, and the key cap of "hunter_ult". The same
## slot art as the rest of the row (HudSlot); hover id "x".

## Draws the tile at (x, y) for a hero with an X and returns the x after it (x unchanged without one).
static func draw(H, p: Hunter, x: float, y: float, s: float, gap: float) -> float:
	if p.ak == null or p.ak.x_def().is_empty():
		return x
	var xi := p.slot_info("x")
	var r := Rect2(Vector2(x, y), Vector2(s, s))
	var key := Settings.key_cap("hunter_ult")
	if bool(xi["locked"]):
		H.hover_spots.append([r, "x"])
		HudSlot.locked(H, "x", r, String(xi["icon"]), xi["col"], key, false, "LV %d" % int(xi["unlock"]))
		return x + s + gap
	var cd_left := float(xi["cd"])
	var frac := cd_left / maxf(0.01, float(xi["cd_max"])) if cd_left > 0.0 else 0.0
	H._ab_slot("x", r, String(xi["icon"]), key, xi["col"], frac, cd_left, bool(xi["ready"]))
	return x + s + gap

## The hover text: [title, colour] then rows of [text, colour, size].
static func tip(p: Hunter) -> Array:
	if p.ak == null or p.ak.x_def().is_empty():
		return []
	var xi := p.slot_info("x")
	var out: Array = [[String(xi["name"]), xi["col"]]]
	out.append(["%s ultimate  ·  %s" % [Arch.name_of(p.arch), Settings.key_cap("hunter_ult")], HudStyle.MUTED, 12])
	out.append([String(xi["desc"]), HudStyle.INK, 13])
	var state := "ready"
	if bool(xi["locked"]):
		state = "unlocks at level %d" % int(xi["unlock"])
	elif float(xi["cd"]) > 0.0:
		state = "ready in %ss" % KinText.n(ceilf(float(xi["cd"])))
	out.append(["Cooldown %ss  ·  %s" % [KinText.n(float(xi["cd_max"])), state], HudStyle.MUTED, 13])
	return out
