class_name BeltHud
extends RefCounted
## The utility belt on the HUD (UtilityBelt): three slots on keys 1, 2 and 3 in the row above the
## weapon card. A slot shows its item's icon, how many charges are left, and lights when pressing
## it would do something (a tonic when you are hurt, an armor kit when your armor is down).

const SLOT := 44.0
const GAP := 8.0
const EMPTY_TIP := "Empty utility slot. Tonics, armor kits and gadgets you find or buy fill it."

## Draws the three slots with the third at the right edge `x`, top at `y`. Returns the x where the
## next slot to the left starts.
static func draw(hud, p: Hunter, x: float, y: float) -> float:
	var c: Control = hud.c
	for k in range(UtilityBelt.SLOTS - 1, -1, -1):
		var r := Rect2(Vector2(x, y), Vector2(SLOT, SLOT))
		var key: String = UtilityBelt.KEYS[k]
		var s: Dictionary = p.belt[k]
		if s.is_empty():
			hud.hover_spots.append([r, key])
			hud._rounded(r, Color(0.05, 0.06, 0.09, 0.55), 12, Color(1, 1, 1, 0.08), 2)
			hud._keycap(Vector2(r.get_center().x, r.end.y), Settings.key_cap(key), hud.MUTED)
		else:
			var id := String(s["id"])
			var col := UtilityBelt.col_of(id)
			var cd: float = float(s.get("cd", 0.0))
			var cd_max: float = maxf(0.01, float(UtilityBelt.def(id).get("cd", 1.0)))
			var ready := UtilityUse.can_use(p, id) and cd <= 0.0 and not p.downed
			hud._ab_slot(key, r, UtilityBelt.icon_of(id), Settings.key_cap(key), col, cd / cd_max if cd > 0.0 else 0.0, cd, ready)
			hud._ctext(Vector2(r.get_center().x, r.position.y - 5), "%d" % int(s["n"]), 12, Color(col, 0.95), hud.big)
		x -= SLOT + GAP
	return x

## The tooltip for slot k (0..2): [[text, color, size?]] lines in the HUD's format.
static func tip(p: Hunter, k: int) -> Array:
	var out: Array = []
	var key := Settings.key_cap(UtilityBelt.KEYS[k])
	var s: Dictionary = p.belt[k]
	if s.is_empty():
		out.append(["Utility slot %d" % (k + 1), Color("a9b0bf")])
		out.append(["Item  ·  %s" % key, Color("a9b0bf"), 12])
		out.append([EMPTY_TIP, Color("f3eee2"), 14])
		return out
	var id := String(s["id"])
	var d := UtilityBelt.def(id)
	out.append([UtilityBelt.name_of(id), UtilityBelt.col_of(id)])
	out.append(["Item  ·  %s  ·  %d of %d" % [key, int(s["n"]), UtilityBelt.max_of(id)], Color("a9b0bf"), 12])
	out.append([String(d.get("desc", "")), Color("f3eee2"), 14])
	out.append(["Lost if you go down: it goes in your deathbox.", Color("a9b0bf"), 13])
	return out
