class_name AmmoDeny
extends RefCounted
## Small extras on the ammo panel: the red tick when R finds nothing to reload (a melee weapon), and the hunter
## ultimate's key tile, drawn only for a hero that has one (ArchKit.has_ult).

const TICK_LEN := 0.35        # s: how long the red outline stays

const ULT_TILE := 30.0        # px: the hunter ultimate tile above the ammo panel

## `r` is the panel's rect, `p` the local hunter.
static func draw(hud, r: Rect2, p: Hunter) -> void:
	_draw_deny(hud, r)
	_draw_ult_tile(hud, r, p)

static func _draw_ult_tile(hud, r: Rect2, p: Hunter) -> void:
	if p.ak == null or not p.ak.has_ult():
		return
	var ready := p.lvl >= int(Hunter.ULT_AT[0])
	var tile := Rect2(Vector2(r.end.x - ULT_TILE, r.position.y - ULT_TILE - 6.0), Vector2(ULT_TILE, ULT_TILE))
	hud._rounded(tile, Color(0.04, 0.05, 0.08, 0.88), 8, Color(1, 1, 1, 0.5 if ready else 0.2), 2)
	var ink := Color.WHITE if ready else Color(1, 1, 1, 0.4)
	hud._text(tile.position + Vector2(8, 21), Settings.key_cap("hunter_ult"), 14, ink, hud.big)

static func _draw_deny(hud, r: Rect2) -> void:
	var fx: Dictionary = hud.slot_fx.get("reload", {})
	if fx.is_empty() or String(fx.get("kind", "")) != "deny":
		return
	var fade := 1.0 - clampf(float(fx["t"]) / TICK_LEN, 0.0, 1.0)
	if fade <= 0.0:
		return
	hud._rounded(r.grow(2.0), Color(1.0, 0.3, 0.25, 0.12 * fade), 12, Color(1.0, 0.35, 0.3, 0.9 * fade), 3)
