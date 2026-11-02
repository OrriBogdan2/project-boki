class_name HeroUltHud
extends RefCounted
## The X slot on the in-match HUD: the hero's own ultimate (the archetype's "r" data, ArchKit.use_r), drawn
## beside the Merge on R through the HUD `H`. Locked until level 6 like the R slot, then its cooldown, and a
## ring round it while the ultimate is running. Kept out of hud.gd (a god file): hud.gd only calls these.

const GAP := 10.0          # px between this slot and the next one in the row

## Draws the X slot at (x, y), size s. Returns the x where the next slot goes (unchanged for a hero
## without an ultimate of their own).
static func draw(H, p: Hunter, x: float, y: float, s: float) -> float:
	if p.ak == null or p.ak.r_def().is_empty():
		return x
	var ri := p.ak.slot_info("r")
	var cd_left := float(ri["cd"])
	var sweep := cd_left / maxf(0.01, float(ri["cd_max"])) if cd_left > 0.0 else 0.0
	var r := Rect2(Vector2(x, y), Vector2(s, s))
	H._skill_slot("ult", "x", r, String(ri["icon"]), Settings.key_cap("hunter_ult"), ri["col"], sweep, cd_left,
			bool(ri["ready"]))
	var up: float = p.ak.ult_running()
	if up > 0.0:
		H.c.draw_arc(r.get_center(), s * 0.5 + 4.0, -PI / 2, -PI / 2 + TAU * clampf(up, 0.0, 1.0), 32,
				Color(ri["col"], 0.95), 3.0, true)
	return x + s + GAP

## The hover text for the X slot.
static func tip(H, p: Hunter) -> Array:
	var ri := p.ak.slot_info("r")
	var head := "%s ultimate  ·  %s  ·  %s" % [Arch.name_of(p.arch), Settings.key_cap("hunter_ult"), p.rank_text("r")]
	var cd_line := "Cooldown %s" % H._secs(float(ri["cd_max"]))
	if float(ri["cd"]) > 0.0:
		cd_line += "  ·  ready in %s" % H._secs(float(ri["cd"]))
	var unlock := int(p.ak.r_def().get("unlock", Hunter.ULT_AT[0]))
	return [
		[String(ri["name"]), ri["col"]],
		[head, H.MUTED, 12],
		[String(ri["desc"]), H.INK, 13],
		["Opens at level %d. Landing it fills your bond meter a long way." % unlock, H.MUTED, 12],
		[cd_line, H.MUTED, 13],
	]
