class_name BeltHud
extends RefCounted
## The bottom-right row (`row`): the utility belt (UtilityBelt), four small slots on keys 1 to 4, the
## Boki throw left of it and the grip cards (GripHud) right of it, where the owner's 11-12 reference
## keeps its consumables and item cards (scripts/ui/HUD_SPEC.md). A belt slot shows its item's icon,
## "left/max" over it, and lights when pressing it would do something (a tonic when you are hurt, an
## armor kit when your armor is down). Look: HudStyle (slot frames, key pills).

const SLOT := 26.0             # px (ref 41 at 1080p)
const GAP := 3.0               # px (ref pitch 45)
const BOTTOM := 696.0          # px: where the row stands (bottom-anchored)
const RIGHT_PAD := 49.0        # px from the right edge to the grip cards (room for GearPanel's column)
const TO_GRIPS := 32.0         # px between the belt and the grip cards
const COUNT_FS := 11           # the "left/max" over a slot
const COUNT_UP := 4.0          # px from the slot's top to that count's baseline

## The whole row, right-anchored to the screen size `sz`.
static func row(hud, p: Hunter, sz: Vector2) -> void:
	var bottom := sz.y - 720.0 + BOTTOM
	var grips := GripHud.draw(hud, p, sz.x - RIGHT_PAD, bottom)
	var x := draw(hud, p, grips.position.x - TO_GRIPS - SLOT, bottom - SLOT)
	_throw(hud, p, Rect2(Vector2(x, bottom - SLOT), Vector2(SLOT, SLOT)))

## Throw or recall your Boki (C).
static func _throw(hud, p: Hunter, r: Rect2) -> void:
	var k: Kin = p.kin
	if k == null:
		return
	var out_now: bool = k.state in ["active", "flying", "returning"]
	var can_throw: bool = (k.state == "shoulder" and k.throw_cd <= 0.0) or out_now
	hud._ab_slot("throw", r, "recall" if out_now else "throw", Settings.key_cap("throw"), Data.KIN[k.species]["color"],
			maxf(0.0, k.throw_cd), k.throw_cd, can_throw)
const EMPTY_TIP := "Empty utility slot. Tonics, armor kits and gadgets you find or buy fill it."

## Draws the slots with the last at the right edge `x`, top at `y`. Returns the x where the
## next slot to the left starts.
static func draw(hud, p: Hunter, x: float, y: float) -> float:
	var c: Control = hud.c
	for k in range(UtilityBelt.SLOTS - 1, -1, -1):
		var r := Rect2(Vector2(x, y), Vector2(SLOT, SLOT))
		var key: String = UtilityBelt.KEYS[k]
		var s: Dictionary = p.belt[k]
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
			hud._ab_slot(key, r, UtilityBelt.icon_of(id), Settings.key_cap(key), col, cd / cd_max if cd > 0.0 else 0.0,
					cd, ready)
			var count := "%d/%d" % [int(s["n"]), UtilityBelt.max_of(id)]
			HudStyle.ctext(c, Vector2(r.get_center().x, r.position.y - COUNT_UP), count, COUNT_FS, col.lightened(0.3))
		x -= SLOT + GAP
	return x

## The tooltip for slot k (0..3): [[text, color, size?]] lines in the HUD's format.
static func tip(p: Hunter, k: int) -> Array:
	var out: Array = []
	var key := Settings.key_cap(UtilityBelt.KEYS[k])
	var s: Dictionary = p.belt[k]
	if s.is_empty():
		out.append(["Utility slot %d" % (k + 1), HudStyle.MUTED])
		out.append(["Item  ·  %s" % key, HudStyle.MUTED, 12])
		out.append([EMPTY_TIP, HudStyle.INK, 14])
		return out
	var id := String(s["id"])
	var d := UtilityBelt.def(id)
	out.append([UtilityBelt.name_of(id), UtilityBelt.col_of(id)])
	out.append(["Item  ·  %s  ·  %d of %d" % [key, int(s["n"]), UtilityBelt.max_of(id)], HudStyle.MUTED, 12])
	out.append([String(d.get("desc", "")), HudStyle.INK, 14])
	out.append(["Lost if you go down: it goes in your deathbox.", HudStyle.MUTED, 13])
	return out
