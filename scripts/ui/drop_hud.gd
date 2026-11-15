class_name DropHud
extends RefCounted
## The HUD on the way down (DECISIONS 2026-11-11, squad mini rockets). Aboard the rocket it is bare: no health or
## ability bars (HudPanels draws only the map), the landing marker in the world (DropReticle), and one or two
## lines: the leader's "Steer with WASD" and everyone's "Jump out: <key>". After jumping out, until the glider
## opens: "Glider: <key> again" (DECISIONS 11-08 double press: the jump out was the first press).

const LINE_Y := 96.0           # px from the top, the first line
const LINE_GAP := 26.0         # px between lines

## True while `p` rides the squad's rocket: the HUD shows only the map and the drop lines.
static func aboard(p: Hunter) -> bool:
	return p != null and p.rocket != null

## What the drop lines say for `p` right now (empty when there is nothing to say).
static func lines(m: Match, p: Hunter) -> Array:
	var jump := Settings.key_cap("jump")
	if aboard(p):
		var l: Hunter = m.skydrop.leader(p.team)
		var out: Array = []
		if l == null or l == p:
			out.append("Steer with %s" % move_keys())
		out.append("Jump out: %s" % jump)
		return out
	if p != null and p.dropping and p.diving:
		return ["Glider: %s again" % jump]
	return []

static func draw(H, sz: Vector2, p: Hunter) -> void:
	var y := LINE_Y
	for s in lines(H.m, p):
		H._ctext(Vector2(sz.x * 0.5, y), s, 18, H.GOLD, H.big)
		y += LINE_GAP

## The four move keys as bound, "WASD" by default.
static func move_keys() -> String:
	return Settings.key_cap("up") + Settings.key_cap("left") + Settings.key_cap("down") + Settings.key_cap("right")
