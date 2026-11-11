class_name BeltHud
extends RefCounted
## The utility belt on the HUD (UtilityBelt): six slots on keys 1 to 6 in the row above the
## weapon card (1 and 2 are the tonic's and the armor kit's). A slot shows its item's icon, how many
## charges are left, and lights when pressing it would do something (a tonic when you are hurt, an armor
## kit when your armor is down). An open slot is a dim frame (a ghost of the tonic or the kit in 1 and 2,
## so you see what belongs there); a drink or repair in progress fills its slot from the bottom; Twin
## Gate's slot rings and counts down while its gates are open (RECAST_MARK).
## Look: HudStyle (slot frames, key pills, count badges).

const SLOT := 44.0
const GAP := 8.0
const EMPTY_TIP := "Empty utility slot. Gadgets you find or buy fill it."
const RECAST_MARK := "swap"      # the word on Twin Gate's pill while its gates are open
const PINNED_TIP := "Only %s go here: find or buy some."

static var shown := {}      # slot index -> {id, n, key, fill, recast} as last drawn (checks read it)

## The seconds left before Twin Gate's open gates swap (0 when none are open): UtilityMore sets "gate_end".
static func recast_left(p: Hunter) -> float:
	return maxf(0.0, float(p.get_meta("gate_end", 0.0)) - p.m.time)

## How full the drink or repair channel in slot k is, 0 when that slot is not being used.
static func channel_fill(p: Hunter, id: String) -> float:
	if p.drink_t > 0.0 and p.drink_id == id:
		return 1.0 - p.drink_t / maxf(0.01, p.drink_len)
	if p.kit_t > 0.0 and id == "armor_kit":
		return 1.0 - p.kit_t / maxf(0.01, p.kit_len)
	return 0.0

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
			var pin := UtilityBelt.reserved_id(k)
			if pin != "":
				var ghost := Color(UtilityBelt.col_of(pin), 0.22)
				Icons.draw(c, UtilityBelt.icon_of(pin), r.get_center() + Vector2(0, -2), SLOT * 0.27, ghost)
			HudStyle.key_pill(c, Vector2(r.get_center().x, r.end.y), Settings.key_cap(key), HudStyle.MUTED)
			shown[k] = {"id": "", "n": 0, "key": Settings.key_cap(key), "fill": 0.0, "recast": 0.0}
		else:
			var id := String(s["id"])
			var col := UtilityBelt.col_of(id)
			var cd: float = float(s.get("cd", 0.0))
			var cd_max: float = maxf(0.01, float(UtilityBelt.def(id).get("cd", 1.0)))
			var ready := UtilityUse.can_use(p, id) and cd <= 0.0 and not p.downed
			hud._ab_slot(key, r, UtilityBelt.icon_of(id), Settings.key_cap(key), col, cd / cd_max if cd > 0.0 else 0.0,
					cd, ready)
			var fill := channel_fill(p, id)
			if fill > 0.0:
				var h := (SLOT - 4.0) * fill
				c.draw_rect(Rect2(r.position + Vector2(2.0, SLOT - 2.0 - h), Vector2(SLOT - 4.0, h)), Color(col, 0.4))
				c.draw_rect(Rect2(r.position + Vector2(2.0, SLOT - 3.0 - h), Vector2(SLOT - 4.0, 2.0)), col)
			var recast := recast_left(p) if id == "twin_gate" else 0.0
			if recast > 0.0:
				_recast(hud, r, col, recast)
			HudStyle.count_badge(c, Vector2(r.end.x - 4.0, r.position.y + 2.0), int(s["n"]), col)
			shown[k] = {"id": id, "n": int(s["n"]), "key": Settings.key_cap(key), "fill": fill, "recast": recast}
		x -= SLOT + GAP
	return x

## Twin Gate's cue: a pulsing ring round the slot and a pill with the seconds left above it.
static func _recast(hud, r: Rect2, col: Color, secs: float) -> void:
	var pulse := 0.5 + 0.5 * sin(float(hud.m.time) * 7.0)
	hud._rounded(r.grow(2.0 + pulse * 2.0), Color(0, 0, 0, 0), HudStyle.SLOT_RAD + 2, Color(col, 0.5 + 0.5 * pulse), 2)
	var txt := "%s %s" % [RECAST_MARK, HudSlot.cd_text(secs)]
	var tw := HudStyle.BIG.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0
	var tr := Rect2(Vector2(r.get_center().x - tw * 0.5, r.position.y - 17), Vector2(tw, 14))
	hud._rounded(tr, HudStyle.KEY_BG, 5, Color(col, 0.9), 1)
	HudStyle.ctext(hud.c, Vector2(r.get_center().x, tr.end.y - 3), txt, 10, Color(HudStyle.INK, 0.95), 0)

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
