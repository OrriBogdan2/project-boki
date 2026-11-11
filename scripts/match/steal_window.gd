class_name StealWindow
extends RefCounted
## The kill window of a prize monster (content/rules/xp.json "steal", docs/decisions/0048-camps-and-xp.md):
## at or under `window` of its health its bar shows a pulsing band on every screen and it cries out once;
## the first drop under it reels it for `reel` seconds (Mob._stagger: no attacks, normal damage), the
## fighting squad's planned burst. Nothing is synced beyond what a monster's snapshot already carries:
## health and the stagger timer; each machine reads the band and the cry off the health it sees.

const BAND_COL := Color("ffd27a")
const PULSE_HZ := 1.4         # band pulses per second

static func _rules() -> Dictionary:
	return XpRules.rules()["steal"]

static func is_prize(mb: Mob) -> bool:
	return mb.mkind in _rules()["prize"]

## True while `mb` is a prize monster at or under the window's health.
static func open(mb: Mob) -> bool:
	return not mb.dead and mb.hp <= mb.max_hp * float(_rules()["window"]) and is_prize(mb)

static func reel_time() -> float:
	return float(_rules()["reel"])

## Every frame, on every machine: the cry the first time the window opens here; both flags rearm
## when the monster is back above it (a lair boss that reset).
static func tick(mb: Mob) -> void:
	if open(mb):
		if not mb.win_cried:
			mb.win_cried = true
			mb.m.sfx("v_" + mb.mkind, mb.pos, 3.0, 0.7)
	else:
		mb.win_cried = false
		if not mb.dead and mb.hp > mb.max_hp * float(_rules()["window"]):
			mb.win_reeled = false

## After a hit on the machine that owns `mb`: the first drop into the window reels it.
static func on_hurt(mb: Mob, by: Ent, opts: Dictionary) -> void:
	if mb.win_reeled or mb.remote or not open(mb):
		return
	mb.win_reeled = true
	mb.reel(by, opts)

## The pulsing band over the health bar `r` (the bar's 0..window part), drawn after its fill.
static func draw_band(c: CanvasItem, r: Rect2, mb: Mob, time: float) -> void:
	if not open(mb):
		return
	var a := 0.6 + 0.4 * sin(time * TAU * PULSE_HZ)
	var band := Rect2(r.position + Vector2(0, -2), Vector2(r.size.x * float(_rules()["window"]), r.size.y + 4))
	c.draw_rect(band, Color(BAND_COL, 0.3 * a))
	c.draw_rect(band, Color(BAND_COL, a), false, 2.0)
