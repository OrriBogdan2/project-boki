class_name TerrainHud
extends RefCounted
## What you're standing in (TerrainHazards), drawn through the in-match HUD `H` under your hunter:
## the hazard's name, then either a shield and "<Boki> keeps you safe" or what it's doing to you,
## and in deep water without a swimmer, your breath. Kept out of hud.gd (a god file): one call.

const SAFE := Color("8fe3a0")
const RISK := Color("ff9a6a")
const Y := 0.63              # share of the screen height the chip sits at (just under your hunter)

static func draw(H) -> void:
	var p: Hunter = H.m.player
	var tz := TerrainHazards.of(H.m)
	if p == null or p.out or tz == null:
		return
	var info := tz.underfoot(p)
	if info.is_empty():
		return
	var sz: Vector2 = H.c.size
	var safe: bool = info["safe"]
	var col: Color = SAFE if safe else RISK
	var said := "%s keeps you safe" % info["kin"] if safe else String(info["hurts"])
	var line := "%s  ·  %s" % [info["name"], said]
	var c := Vector2(sz.x * 0.5, sz.y * Y)
	var half := 12.0 + line.length() * 4.2
	var box := Rect2(c - Vector2(half, 15), Vector2(half * 2.0, 30))
	H._rounded(box, Color(0.04, 0.04, 0.07, 0.78), 15, Color(info["col"], 0.9), 2)
	var ic := c + Vector2(-half + 16, 0)
	if safe:
		Icons.draw(H.c, "brightshield", ic, 18.0, col)
	else:
		H.c.draw_circle(ic, 8.0, col)
		H._ctext(ic + Vector2(0, 5), "!", 14, Color(0.1, 0.05, 0.05), H.big)
	H._ctext(c + Vector2(10, 5), line, 14, col, H.big)
	var b: float = info["breath"]
	if not safe and b >= 0.0:
		var r := Rect2(c + Vector2(-half + 30, 18), Vector2((half - 15) * 2.0 - 30, 5))
		H.c.draw_rect(r, Color(0, 0, 0, 0.6))
		H.c.draw_rect(Rect2(r.position, Vector2(r.size.x * b, r.size.y)), Color("7ac8ff") if b > 0.3 else RISK)
