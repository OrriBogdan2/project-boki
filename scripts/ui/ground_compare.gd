class_name GroundCompare
extends RefCounted
## The card above the pickup prompt when you stand at a piece of gear on the ground and that slot is
## already worn: which piece it replaces and where, then each number that changes, one line each,
## green when better and red when worse (InvText.change_lines, as the inventory cards). Only while the
## prompt points at it; the prompt under it already names the one key that takes it.

const FS := 13
const LINE := 18.0


## The lines for interact target `it` (a gear pickup), or [] when there is nothing to compare.
static func lines(p: Hunter, it: Dictionary) -> Array:
	if String(it.get("kind", "")) != "weapon" or not it.has("wp") or not it["wp"].has("gear"):
		return []
	var g := Pack.ground_item(it["wp"])
	var slot := GearCompare.slot_for(p, g)
	var worn: Dictionary = p.gear[slot]
	if worn.is_empty():
		return []
	var out: Array = [InvText.worn_line(p, slot, "Replaces")]
	for ln: Array in InvText.change_lines(g, worn):
		var tag := ""
		if ln[1] == InvText.GOOD:
			tag = "  (better)"
		elif ln[1] == InvText.BAD:
			tag = "  (worse)"
		out.append([String(ln[0]) + tag, ln[1]])
	return out


## Draws the card with its bottom edge at `bottom`, centred on `mid`.
static func draw(c: CanvasItem, mid: float, bottom: float, p: Hunter, it: Dictionary) -> void:
	var ls := lines(p, it)
	if ls.is_empty():
		return
	var w := 0.0
	for l in ls:
		w = maxf(w, TextCache.width(HudStyle.BODY, String(l[0]), FS))
	var h := LINE * ls.size() + 10.0
	var r := Rect2(Vector2(mid - w * 0.5 - 12.0, bottom - h), Vector2(w + 24.0, h))
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 7, Color(0, 0, 0, 0), 0), r)
	for i in ls.size():
		var at := Vector2(mid, r.position.y + 18.0 + LINE * i)
		HudStyle.ctext(c, at, String(ls[i][0]), FS, ls[i][1], 3, HudStyle.BODY)
