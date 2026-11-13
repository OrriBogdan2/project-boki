class_name ExitMark
extends RefCounted
## The way to extract, on the maps. One look for it that no other marker shares: a dark disc with an arrow
## rising into a ring, in three states (closed: grey ring, opening: the ring fills, open: solid green and
## pulsing), with its timer in a pill under it on the full map. The full map's tooltip (MapHover) and the
## key (MapKey) read the same words from here; the minimap pings an open or opening one on its edge.

const OPEN_COL := Color("4ff09a")       # open: the lift is up, go
const OPENING_COL := Color("45d3e8")    # opening: the uplink is charging, or ready to start
const CLOSED_COL := Color("8d93a3")     # closed: not yet, or used up
const DISC := Color(0.05, 0.07, 0.11, 0.96)
const SAMPLE := {"state": "open", "t": 0.0, "prog": 0.0}     # for the keys: the icon as it looks open
const PING_S := 2.2                     # minimap edge ping: arrow size multiple at its biggest
const PING_HZ := 1.6                    # edge ping pulses per second

## "open", "opening" or "closed".
static func state(x: Dictionary) -> String:
	match String(x["state"]):
		"open": return "open"
		"charging": return "opening"
	return "closed"

static func color(x: Dictionary) -> Color:
	match state(x):
		"open": return OPEN_COL
		"opening": return OPENING_COL
	return CLOSED_COL

## The short word in the pill under the icon: "OPEN 0:12", "OPENING 40%", "OPENS 1:20", "READY", "USED".
static func word(m: Match, x: Dictionary) -> String:
	match String(x["state"]):
		"open": return "OPEN" if float(x["t"]) > 3600.0 else "OPEN %s" % TrainMap.clock(float(x["t"]))
		"charging": return "OPENING %d%%" % int(float(x["prog"]) * 100.0)
		"fizzling": return "SHUTTING"
		"spent": return "USED"
		"closed": return "SHUT"
	if m.exits.startable(x):
		return "READY"
	if m.time < float(x["open_at"]):
		return "OPENS %s" % TrainMap.clock(float(x["open_at"]) - m.time)
	return "CLOSED"

## The tooltip's line: what this is and what it is doing.
static func line(m: Match, x: Dictionary) -> String:
	match String(x["state"]):
		"open": return "Extraction  ·  open%s: step into the light" % _closes(x)
		"charging": return "Extraction  ·  opening, %d%%%s" % [int(float(x["prog"]) * 100.0), _contested(x)]
		"fizzling": return "Extraction  ·  shutting off"
		"spent": return "Extraction  ·  used, cooling down"
		"closed": return "Extraction  ·  shut"
	if m.exits.startable(x):
		return "Extraction  ·  closed, hold its yard to open it"
	if m.time < float(x["open_at"]):
		return "Extraction  ·  opens in %s" % TrainMap.clock(float(x["open_at"]) - m.time)
	return "Extraction  ·  closed"

static func _closes(x: Dictionary) -> String:
	return "" if float(x["t"]) > 3600.0 else ", closes in %s" % TrainMap.clock(float(x["t"]))

static func _contested(x: Dictionary) -> String:
	return "  ·  contested" if x["contested"] else ""

## The icon, radius `r` px at `pv`; the ring fills with the uplink's progress while opening.
static func glyph(c: Control, pv: Vector2, r: float, x: Dictionary, now: float) -> void:
	var col := color(x)
	var st := state(x)
	c.draw_circle(pv, r + 2.0, Color(0, 0, 0, 0.7))
	c.draw_circle(pv, r, col if st == "open" else DISC)
	var w := maxf(2.0, r * 0.22)
	if st == "opening":
		c.draw_arc(pv, r - w * 0.5, 0, TAU, 32, Color(col, 0.3), w, true)
		c.draw_arc(pv, r - w * 0.5, -PI * 0.5, -PI * 0.5 + TAU * float(x["prog"]), 32, col, w, true)
	elif st == "closed":
		c.draw_arc(pv, r - w * 0.5, 0, TAU, 32, col, w, true)
	if st != "closed":
		var ph := fmod(now * 1.2, 1.0)
		c.draw_arc(pv, r + 2.0 + ph * r, 0, TAU, 32, Color(col, 0.8 * (1.0 - ph)), 2.0, true)
	var ink := DISC if st == "open" else col
	var a := PackedVector2Array([Vector2(0, -0.55), Vector2(0.48, 0.0), Vector2(0.18, 0.0), Vector2(0.18, 0.5),
		Vector2(-0.18, 0.5), Vector2(-0.18, 0.0), Vector2(-0.48, 0.0)])
	for i in a.size():
		a[i] = pv + a[i] * r * 0.95
	c.draw_colored_polygon(a, ink)

## The full map: every exit on it, with its pill. Called by FullMap.draw (the shared map helpers clip to a rectangle).
static func full_map(fm: FullMap) -> void:
	var m: Match = fm.m
	var r := clampf(6.0 + fm.k() * 0.7, 9.0, 15.0)
	for x in m.exits.list:
		var pv: Vector2 = fm.to_screen(x["pos"])
		if not fm.rect.grow(-4.0).has_point(pv):
			continue
		glyph(fm.hud.c, pv, r, x, m.time)
		pill(fm, pv + Vector2(0, r + 13.0), word(m, x), color(x))

static func pill(fm: FullMap, at: Vector2, txt: String, col: Color) -> void:
	var w := TextCache.width(HudStyle.BIG, txt, 11) + 12.0
	var box := Rect2(at + Vector2(-w * 0.5, -10.0), Vector2(w, 16.0))
	fm.hud._rounded(box, Color(0.04, 0.05, 0.08, 0.9), 8, Color(col, 0.7), 1)
	HudStyle.ctext(fm.hud.c, at + Vector2(0, 2.0), txt, 11, col, 3)

## The minimap: the icon when it is on the map and meant to show, and for an exit that is opening or open
## and off the map a pulsing arrow on the edge, always (the squad can't miss where to go).
static func minimap(hud, inner: Rect2, x: Dictionary, pv: Vector2, on_map: bool, shown: bool) -> void:
	if on_map and shown:
		glyph(hud.c, pv, MapDetail.ICON_R + 1.5, x, hud.m.time)
	elif not on_map and state(x) != "closed":
		var arrow := 1.4
		if state(x) == "open":
			arrow = lerpf(1.2, PING_S, 1.0 - fmod(hud.m.time * PING_HZ, 1.0))
		hud._edge_arrow(inner, inner.get_center(), pv, color(x), arrow)
