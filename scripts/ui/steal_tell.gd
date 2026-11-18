class_name StealTell
extends RefCounted
## The steal window's look (docs/HUD.md "Steal window"). Kill XP and a lair boss's rewards go to the
## last hit (KillXp), so once a boss is at or under `at` of its health (content/rules/steal_window.json)
## one burst can take it. From that line its health bar (the world bar, and the top bar for the squad
## in its lair) pulses gold instead of red, and while a Hunter of your squad is within KillXp.SHARE_R
## of it (close enough to be paid for the kill) a small STEAL mark sits by the bar. Every machine reads
## it off the health it already sees, so nothing is synced. Looks only: no stat or damage changes.

## The window's gold: apart from the bar's red, the stagger's lilac and the chip's white.
const COL := Color("ffc93a")
const INK := Color(0.05, 0.04, 0.02, 0.9)  # the mark's outline and glyph
const PULSE_HZ := 2.0  # fill pulses per second
const MARK_R := 9.0  # px: the mark's diamond, centre to tip

static var _at := -1.0


## The share of max health at or under which the window is open.
static func at() -> float:
	if _at < 0.0:
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/steal_window.json"))
		_at = float(d["at"]) if d is Dictionary else 0.25
	return _at


static func open(mb: Mob) -> bool:
	return mb is Boss and not mb.dead and mb.hp <= mb.max_hp * at()


## True when a Hunter of `team` still in the match is within the kill-share radius of `mb`.
static func near(m: Match, mb: Mob, team: int) -> bool:
	for h in m.hunters:
		if h.team == team and not h.out and not h.extracted and h.flat_dist(mb) <= KillXp.SHARE_R:
			return true
	return false


## The bar's fill colour: `base`, or gold pulsing toward white while the window is open.
static func fill(mb: Mob, base: Color, time: float) -> Color:
	if not open(mb):
		return base
	return COL.lerp(Color.WHITE, 0.4 * (0.5 + 0.5 * sin(time * TAU * PULSE_HZ)))


## The STEAL mark centred on `at_px` (a gold diamond, the word to its right) when the window is open and
## the viewer's squad is near enough to be paid.
static func mark(hud, at_px: Vector2, mb: Mob) -> void:
	var m: Match = hud.m
	if not open(mb) or m.player == null or not near(m, mb, m.player.team):
		return
	var tips := PackedVector2Array(
		[
			at_px + Vector2(0, -MARK_R),
			at_px + Vector2(MARK_R, 0),
			at_px + Vector2(0, MARK_R),
			at_px + Vector2(-MARK_R, 0)
		]
	)
	hud.c.draw_colored_polygon(tips, COL)
	tips.append(tips[0])
	hud.c.draw_polyline(tips, INK, 1.5, true)
	Icons.draw(hud.c, "burst", at_px, 3.2, INK)
	hud._text(at_px + Vector2(MARK_R + 4, 5), "STEAL", 13, COL, hud.big)
