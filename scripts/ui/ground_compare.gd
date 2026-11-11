class_name GroundCompare
extends RefCounted
## The card above the pickup prompt when you stand at a piece of gear on the ground and that slot is
## already worn: which slot and piece it replaces, then each number that changes, one line each,
## green when better and red when worse. Only while the prompt points at it (DECISIONS 11-08: no
## always-on UI); the prompt under it already names the one key that takes it.

const FS := 13
const LINE := 18.0

## The lines for interact target `it` (a "weapon" pickup), or [] when there is nothing to compare.
static func lines(p: Hunter, it: Dictionary) -> Array:
	if String(it.get("kind", "")) != "weapon" or not it.has("wp") or not it["wp"].has("gear"):
		return []
	var g := Pack.ground_item(it["wp"])
	var slot := GearCompare.slot_for(p, g)
	var worn: Dictionary = p.gear[slot]
	if worn.is_empty():
		return []
	var worn_name := Loot.name_of(Loot.gear(String(worn["id"]), int(worn["rar"])))
	var out: Array = [["Replaces %s  ·  %s" % [worn_name, InvText.slot_label(slot)], HudStyle.MUTED]]
	for ch in GearCompare.changes(g, worn):
		out.append(_change_line(String(ch[0]), bool(ch[1])))
	if out.size() == 1:
		out.append(["Same numbers as what you wear", HudStyle.MUTED])
	return out

## One changed number in plain words: "+12 max HP  (better)" in green, or red and "worse".
static func _change_line(text: String, better: bool) -> Array:
	if better:
		return ["%s  (better)" % text, InvText.GOOD]
	return ["%s  (worse)" % text, InvText.BAD]

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
