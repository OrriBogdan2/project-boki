class_name ResetPop
extends RefCounted
## The HUD half of ResetCue: a short bright flash on an ability slot that a reset just handed back. The
## slot swells a little and settles, a white fill over it fades fast and its edge burns bright, then
## shrinks back onto the frame (no ring flying off, no sparkles). Pure drawing, driven by the slot's
## slot_fx time t; the numbers are content/rules/reset_cue.json "slot_flash". HudSlot.ab_slot calls
## scaled() and draw().

## How long the flash lasts in seconds (the HUD keeps the slot_fx entry this long).
static func length() -> float:
	return float(ResetCue.rules()["slot_flash"]["time"])

## The slot's rect swelling by "swell" of its size in the first fifth of the flash, then settling back.
static func scaled(r: Rect2, t: float) -> Rect2:
	var f: Dictionary = ResetCue.rules()["slot_flash"]
	var k := clampf(t / length(), 0.0, 1.0)
	var grow := k / 0.2 if k < 0.2 else 1.0 - (k - 0.2) / 0.8
	return r.grow(r.size.x * float(f["swell"]) * grow * 0.5)

static func draw(c: CanvasItem, r: Rect2, col: Color, t: float) -> void:
	var f: Dictionary = ResetCue.rules()["slot_flash"]
	var fade := 1.0 - clampf(t / length(), 0.0, 1.0)
	var calm: bool = Settings.get_v("reduce_flashes")
	var white := float(f["white_calm"] if calm else f["white"])
	c.draw_rect(r, Color(1, 1, 1, white * fade * fade), true)
	var edge := r.grow(float(f["edge_grow"]) * fade)
	c.draw_rect(edge, Color(col.lerp(Color.WHITE, 0.7), fade), false, 3.0)
