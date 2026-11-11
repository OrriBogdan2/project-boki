class_name BeltHud
extends RefCounted
## The utility belt on the HUD (UtilityBelt): four slots on keys 1 to 4 in the row above the
## weapon card. A slot shows its item's icon, how many charges are left, and lights when pressing
## it would do something (a tonic when you are hurt, an armor kit when your armor is down).
## Look: HudStyle (slot frames, key pills, count badges).

const SLOT := 44.0
const GAP := 8.0

## Draws the filled slots (an empty one stays hidden, so a new player sees no belt) with the last at
## the right edge `x`, top at `y`. Returns the x where the next slot to the left starts.
static func draw(hud, p: Hunter, x: float, y: float) -> float:
	var c: Control = hud.c
	for k in range(UtilityBelt.SLOTS - 1, -1, -1):
		var s: Dictionary = p.belt[k]
		if s.is_empty():
			continue
		var r := Rect2(Vector2(x, y), Vector2(SLOT, SLOT))
		var key: String = UtilityBelt.KEYS[k]
		var id := String(s["id"])
		var col := UtilityBelt.col_of(id)
		var cd: float = float(s.get("cd", 0.0))
		var cd_max: float = maxf(0.01, float(UtilityBelt.def(id).get("cd", 1.0)))
		var ready := UtilityUse.can_use(p, id) and cd <= 0.0 and not p.downed
		hud._ab_slot(key, r, UtilityBelt.icon_of(id), Settings.key_cap(key), col, cd / cd_max if cd > 0.0 else 0.0,
				cd, ready)
		HudStyle.count_badge(c, Vector2(r.end.x - 4.0, r.position.y + 2.0), int(s["n"]), col)
		x -= SLOT + GAP
	return x

## The tooltip for slot k (0..3): [[text, color, size?]] lines in the HUD's format.
static func tip(p: Hunter, k: int) -> Array:
	var out: Array = []
	var key := Settings.key_cap(UtilityBelt.KEYS[k])
	var s: Dictionary = p.belt[k]
	if s.is_empty():           # the slot emptied under the cursor (last one used): no tip
		return out
	var id := String(s["id"])
	var d := UtilityBelt.def(id)
	out.append([UtilityBelt.name_of(id), UtilityBelt.col_of(id)])
	out.append(["Item  ·  %s  ·  %d of %d" % [key, int(s["n"]), UtilityBelt.max_of(id)], HudStyle.MUTED, 12])
	out.append([String(d.get("desc", "")), HudStyle.INK, 14])
	out.append(["Lost if you go down: it goes in your deathbox.", HudStyle.MUTED, 13])
	return out
