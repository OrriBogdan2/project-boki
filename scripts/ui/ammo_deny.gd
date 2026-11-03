class_name AmmoDeny
extends RefCounted
## The red tick on the ammo panel when R finds nothing to reload (a melee weapon).

const TICK_LEN := 0.35        # s: how long the red outline stays

## `r` is the panel's rect.
static func draw(hud, r: Rect2) -> void:
	var fx: Dictionary = hud.slot_fx.get("reload", {})
	if fx.is_empty() or String(fx.get("kind", "")) != "deny":
		return
	var fade := 1.0 - clampf(float(fx["t"]) / TICK_LEN, 0.0, 1.0)
	if fade <= 0.0:
		return
	hud._rounded(r.grow(2.0), Color(1.0, 0.3, 0.25, 0.12 * fade), 12, Color(1.0, 0.35, 0.3, 0.9 * fade), 3)
