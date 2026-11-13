class_name ScoreMute
extends RefCounted
## The Mute chip on each other player's row of the Tab scoreboard (Hud._draw_scores). Only people on
## the net get one: bots have nobody to silence. Click one while Tab is held to flip MuteList for that
## name; while you hold Tab over a chip the click belongs to the chip, not to your weapon.

const CHIP := Vector2(66, 20)    # px, one chip
const MUTED_FILL := Color(0.4, 0.12, 0.34, 0.9)
const OFF_FILL := Color(0.165, 0.11, 0.251, 0.9)

var rects := {}     # player name -> chip rect, as last drawn (hud canvas coordinates; checks read it)

## Draws `h`'s chip with its left edge at `x`, text baseline `y`; remembers where it is.
func draw(hud, h: Hunter, x: float, y: float) -> void:
	if h.ctrl != "remote":
		return
	var muted := MuteList.has(h.pname)
	var r := Rect2(Vector2(x, y - 15), CHIP)
	rects[h.pname] = r
	hud.c.draw_rect(r, MUTED_FILL if muted else OFF_FILL)
	hud.c.draw_rect(r, UI.ACCENT if muted else UI.LINE, false, 1.5)
	var ink: Color = UI.ACCENT_HI if muted else UI.MUTED
	hud._text(Vector2(x + 10, y), "Muted" if muted else "Mute", 13, ink)

## Forget last frame's chips (the scoreboard is not up).
func hide() -> void:
	rects.clear()

## The cursor (hud canvas coordinates) is on a chip.
func over(at: Vector2) -> bool:
	return rects.values().any(func(r: Rect2): return r.has_point(at))

## A left click on a chip flips that player's mute; returns whether it was one.
func click(event: InputEvent, at: Vector2) -> bool:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return false
	for who in rects:
		if (rects[who] as Rect2).has_point(at):
			MuteList.toggle(who)
			return true
	return false
