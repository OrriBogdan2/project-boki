class_name BeltHud
extends RefCounted
## The utility belt on the HUD (UtilityBelt): six slots on keys 1 to 6 in the row above the
## weapon card (1 and 2 are the tonic's and the armor kit's). A slot shows its item's icon, how many
## charges are left, and lights when pressing it would do something (a tonic when you are hurt, an armor
## kit when your armor is down).
## Look: HudStyle (slot frames, key pills, count badges).

const SLOT := 44.0
const GAP := 8.0
const EMPTY_TIP := "Empty utility slot. Gadgets you find or buy fill it."
const PINNED_TIP := "Only %s go here: find or buy some."
const SPARE_FROM := 2  # slots 3 to 6 (index 2..5) are held back while empty (HudReveal "belt_spare")


## Staged HUD (HudReveal "belt"): the belt stays folded away until a held item could be used (a tonic when
## hurt, an armor kit when the armor is down); from then on this save keeps it. `see` is false for a read-only
## count (HudGroups).
static func shown(m: Match, p: Hunter, see := false) -> bool:
	if HudReveal.on(m, "belt"):
		return true
	var matters := p.belt.any(func(s): return not s.is_empty() and UtilityUse.can_use(p, String(s["id"])))
	if matters and see:
		HudReveal.see("belt")
	return matters


## Draws the slots with the last at the right edge `x`, top at `y`. Returns the x where the
## next slot to the left starts.
static func draw(hud, p: Hunter, x: float, y: float) -> float:
	if not shown(hud.m, p, true):
		return x
	var c: Control = hud.c
	for k in range(UtilityBelt.SLOTS - 1, -1, -1):
		var r := Rect2(Vector2(x, y), Vector2(SLOT, SLOT))
		var key: String = UtilityBelt.KEYS[k]
		var s: Dictionary = p.belt[k]
		if s.is_empty() and k >= SPARE_FROM and not HudReveal.on(hud.m, "belt_spare"):
			x -= SLOT + GAP  # slots 3 to 6 wait until something is in them (the others keep their places)
			continue
		if s.is_empty():
			hud.hover_spots.append([r, key])
			HudStyle.slot_frame(c, r, HudStyle.MUTED, "off")
			HudStyle.key_pill(c, Vector2(r.get_center().x, r.end.y), Settings.key_cap(key), HudStyle.MUTED)
		else:
			var id := String(s["id"])
			var col := UtilityBelt.col_of(id)
			var cd: float = float(s.get("cd", 0.0))
			var cd_max: float = maxf(0.01, float(UtilityBelt.def(id).get("cd", 1.0)))
			var ready := UtilityUse.can_use(p, id) and cd <= 0.0 and not p.downed
			hud._ab_slot(
				key, r, UtilityBelt.icon_of(id), Settings.key_cap(key), col, cd / cd_max if cd > 0.0 else 0.0, cd, ready
			)
			HudStyle.count_badge(c, Vector2(r.end.x - 4.0, r.position.y + 2.0), int(s["n"]), col)
		x -= SLOT + GAP
	return x


## The tooltip for slot k (0..5): [[text, color, size?]] lines in the HUD's format.
static func tip(p: Hunter, k: int) -> Array:
	var out: Array = []
	var key := Settings.key_cap(UtilityBelt.KEYS[k])
	var s: Dictionary = p.belt[k]
	if s.is_empty():
		out.append(["Utility slot %d" % (k + 1), HudStyle.MUTED])
		out.append(["Item  ·  %s" % key, HudStyle.MUTED, 12])
		var pin := UtilityBelt.reserved_id(k)
		var tip := PINNED_TIP % (UtilityBelt.name_of(pin).to_lower() + "s") if pin != "" else EMPTY_TIP
		out.append([tip, HudStyle.INK, 14])
		return out
	var id := String(s["id"])
	var d := UtilityBelt.def(id)
	out.append([UtilityBelt.name_of(id), UtilityBelt.col_of(id)])
	out.append(["Item  ·  %s  ·  %d of %d" % [key, int(s["n"]), UtilityBelt.max_of(id)], HudStyle.MUTED, 12])
	out.append([String(d.get("desc", "")), HudStyle.INK, 14])
	out.append(["Lost if you go down: it goes in your deathbox.", HudStyle.MUTED, 13])
	return out
