class_name TimingDrill
extends RefCounted
## The timing bar the Training post drill and the Dash's cheers share. A drill state is a Dictionary
## with "m" (the marker, 0..1), "dir" (+1 or -1), "speed" (bar widths a second) and "zone" (the
## centre of the gold); an optional "wide" (default 1) stretches both bands. The marker sweeps back
## and forth; a press in the gold is great, in the wider band good, anywhere else a miss.

const GREAT := 0.06     # half-width of the gold band, as a fraction of the bar
const GOOD := 0.16      # half-width of the wider band

## Moves the marker on by d seconds, bouncing off both ends.
static func sweep(st: Dictionary, d: float) -> void:
	var m := float(st["m"]) + float(st["dir"]) * float(st["speed"]) * d
	if m > 1.0:
		m = 2.0 - m
		st["dir"] = -1.0
	if m < 0.0:
		m = -m
		st["dir"] = 1.0
	st["m"] = m

## How a press right now is graded: "great", "good" or "miss".
static func grade(st: Dictionary) -> String:
	var off := absf(float(st["m"]) - float(st["zone"]))
	var wide := float(st.get("wide", 1.0))
	if off < GREAT * wide:
		return "great"
	return "good" if off < GOOD * wide else "miss"

## One word for a press right now: "Great" in the gold, else "Early" (the marker hasn't reached the
## gold yet) or "Late" (it has gone past).
static func verdict(st: Dictionary) -> String:
	if grade(st) == "great":
		return "Great"
	var ahead := (float(st["zone"]) - float(st["m"])) * float(st["dir"])
	return "Early" if ahead > 0.0 else "Late"

## Draws the bar, its bands and the marker into c (call from c's draw signal).
static func draw(c: Control, st: Dictionary) -> void:
	var w := c.size.x
	var h := c.size.y
	var z := float(st["zone"])
	var wide := float(st.get("wide", 1.0))
	c.draw_rect(Rect2(0, h * 0.3, w, h * 0.4), Color(1, 1, 1, 0.1))
	c.draw_rect(Rect2(w * (z - GOOD * wide), h * 0.3, w * GOOD * wide * 2.0, h * 0.4), Color(UI.ACCENT, 0.45))
	c.draw_rect(Rect2(w * (z - GREAT * wide), h * 0.2, w * GREAT * wide * 2.0, h * 0.6), UI.GOLD)
	if wide > 1.0:
		var glow := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
		var box := Rect2(w * (z - GOOD * wide) - 2, 1, w * GOOD * wide * 2.0 + 4, h - 2)
		c.draw_rect(box, Color(UI.GOLD, glow), false, 2.0)
	c.draw_rect(Rect2(w * float(st["m"]) - 3, 0, 6, h), UI.INK)
