class_name WaysOutMap
extends RefCounted
## The four Ways Out seats on the minimap and the full map (briefs/specs/LIMITED_WAY_OUTS.md section 9), from 0:00:
## a badge on each site (a dark ring, a countdown arc in the seat's state colour) and, for the dead and the
## watching, one line: "Ways out left: N" and which seat your squad is nearest.
## States come from WaysOutHud.seats; the dashed next Blight ring is HeartHud's. Until the quest seats are built
## (spec task 4) the Lair seat is the first lair and the Uplink the outpost farther from it (the spec's rule).

const WORDS := ["Sealed Lair", "Heart Gate", "Uplink", "Heart ring"]
const LOCKED_COL := Color("9fb0d8")    # a seat not open yet: cool blue-grey
const OPEN_COL := Color("fff4d0")
const LOST_COL := Color("8a3a4a")
const LINE_FS := 13

static var _sites: Array[Vector3] = [Vector3.INF, Vector3.INF, Vector3.INF, Vector3.INF]    # reused every frame

## Where each seat stands (Vector3.INF where the map has none): Lair, Heart Gate, Uplink, Heart ring.
static func sites(m: Match) -> Array[Vector3]:
	_sites.fill(Vector3.INF)
	if m.heart == null or m.heart.site == Vector3.INF:
		return _sites
	if m.lairs != null and not m.lairs.list.is_empty():
		_sites[0] = m.lairs.list[0]["c"]
	_sites[1] = m.heart.gate
	_sites[2] = _uplink_site(m, _sites[0])
	_sites[3] = m.heart.site
	return _sites

## The outpost farthest from the Lair (the only one when there is one).
static func _uplink_site(m: Match, lair: Vector3) -> Vector3:
	var best := Vector3.INF
	var far := -1.0
	if m.exits == null:
		return best
	for x in m.exits.list:
		if x["kind"] != "outpost":
			continue
		var at: Vector3 = x["pos"]
		var d := Vector2(at.x - lair.x, at.z - lair.z).length() if lair != Vector3.INF else 0.0
		if d > far:
			far = d
			best = at
	return best

static func color_of(s: Dictionary) -> Color:
	match int(s["st"]):
		WaysOutHud.St.LOCKED:
			return LOCKED_COL
		WaysOutHud.St.OPEN:
			return OPEN_COL
		WaysOutHud.St.LOST:
			return LOST_COL
	var team: int = s["team"]
	var squad: Color = Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()]
	return squad.darkened(0.25) if int(s["st"]) == WaysOutHud.St.TAKEN else squad

## How much of the badge's ring is lit, 0..1: a locked seat fills up to its opening, an open one with a shut time
## drains toward it, every other state is a full ring.
static func fraction(i: int, s: Dictionary) -> float:
	var q: Dictionary = Heart.rules()["quest"]
	var t := float(s["t"])
	match int(s["st"]):
		WaysOutHud.St.LOCKED:
			return clampf(1.0 - t / _open_at(i, q), 0.0, 1.0)
		WaysOutHud.St.OPEN:
			if t > 0.0:
				var shut: float = q["lair_shut_s"] if i == 0 else q["uplink_shut_s"]
				return clampf(t / (shut - _open_at(i, q)), 0.0, 1.0)
	return 1.0

## Session seconds at which seat `i` opens.
static func _open_at(i: int, q: Dictionary) -> float:
	match i:
		0:
			return q["lair_open_s"]
		1:
			return Heart.r("wake_s") + Heart.r("charge_s")
		2:
			return q["uplink_open_s"]
	return Heart.r("final_s")

## The short word under a badge on the full map.
static func word(i: int, s: Dictionary) -> String:
	match int(s["st"]):
		WaysOutHud.St.LOCKED:
			return "%s %s" % [WORDS[i], _clock(float(s["t"]))]
		WaysOutHud.St.OPEN:
			return "%s open" % WORDS[i]
		WaysOutHud.St.USE:
			return "%s in use" % WORDS[i]
		WaysOutHud.St.TAKEN:
			return "%s taken" % WORDS[i]
	return "%s lost" % WORDS[i]

static func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]

## One badge: a dark underlay, a faint track, the lit arc from the top, a pulse while open, a strike once taken or lost.
static func badge(c: Control, pv: Vector2, r: float, i: int, s: Dictionary, now: float) -> void:
	var col := color_of(s)
	var st := int(s["st"])
	var w := maxf(2.0, r * 0.3)
	c.draw_arc(pv, r, 0, TAU, 32, Color(0, 0, 0, 0.7), w + 2.0, true)
	c.draw_arc(pv, r, 0, TAU, 32, Color(col, 0.3), w, true)
	var f := fraction(i, s)
	if st == WaysOutHud.St.OPEN or st == WaysOutHud.St.USE:
		var ph := fmod(now * 1.2, 1.0)
		c.draw_arc(pv, r + 1.0 + ph * r * 0.6, 0, TAU, 32, Color(col, 0.8 * (1.0 - ph)), 2.0, true)
	if f >= 0.999:
		c.draw_arc(pv, r, 0, TAU, 32, col, w, true)
	elif f > 0.0:
		c.draw_arc(pv, r, -PI * 0.5, -PI * 0.5 + TAU * f, 32, col, w, true)
	if st == WaysOutHud.St.TAKEN or st == WaysOutHud.St.LOST:
		c.draw_line(pv + Vector2(-r, r) * 0.7, pv + Vector2(r, -r) * 0.7, col, w, true)

# ------------------------------------------------------------------ the maps
static func minimap(hud, inner: Rect2, to_map: Callable, on_map: Callable) -> void:
	var m: Match = hud.m
	if m.heart == null:
		return      # (no Ways Out: the tutorial, training, a duel)
	var at := sites(m)
	var sd := WaysOutHud.seats(m)
	for i in 4:
		if at[i] == Vector3.INF:
			continue
		var pv: Vector2 = to_map.call(at[i])
		if on_map.call(pv, 8.0):
			badge(hud.c, pv, 8.0, i, sd[i], m.time)
		elif int(sd[i]["st"]) <= WaysOutHud.St.USE:
			hud.edge_mini.add(pv - inner.get_center(), color_of(sd[i]), EdgeMarker.PRIO_GOAL)

static func full_map(fm) -> void:
	var m: Match = fm.m
	if m.heart == null:
		return      # (no Ways Out: the tutorial, training, a duel)
	var at := sites(m)
	var sd := WaysOutHud.seats(m)
	var area: Rect2 = fm.rect.grow(-14.0)
	var r := clampf(8.0 + fm.k() * 0.8, 12.0, 18.0)
	for i in 4:
		if at[i] == Vector3.INF:
			continue
		var pv: Vector2 = fm.to_screen(at[i])
		if area.has_point(pv):
			badge(fm.hud.c, pv, r, i, sd[i], m.time)
			var dy := -r - 16.0 if i == 1 else r + 30.0    # the Gate's own label sits below it
			HudStyle.ctext(fm.hud.c, pv + Vector2(0, dy), word(i, sd[i]), 11, color_of(sd[i]), 3)
	draw_line(fm.hud, Vector2(fm.rect.get_center().x, fm.rect.position.y + 22.0))

# ------------------------------------------------------------------ the dead and the watching
## Seats still to be had: locked, open or in use.
static func ways_left(m: Match) -> int:
	var n := 0
	for s in WaysOutHud.seats(m):
		n += 1 if int(s["st"]) <= WaysOutHud.St.USE else 0
	return n

## The seat (index into the four) your squad is nearest, and how far: living squadmates count, or you
## where you fell when none is left. {"i": -1} when no seat is left.
static func nearest(m: Match, team: int) -> Dictionary:
	var at := sites(m)
	var sd := WaysOutHud.seats(m)
	var best := {"i": -1, "d": INF}
	for h in m.hunters:
		if h.team != team or h.out or h.extracted:
			continue
		_nearest_to(best, h.pos, at, sd)
	if best["i"] < 0 and m.player != null:
		_nearest_to(best, m.player.pos, at, sd)
	return best

static func _nearest_to(best: Dictionary, p: Vector3, at: Array[Vector3], sd: Array) -> void:
	for i in 4:
		if at[i] == Vector3.INF or int(sd[i]["st"]) > WaysOutHud.St.USE:
			continue
		var d := Vector2(at[i].x - p.x, at[i].z - p.z).length()
		if d < best["d"]:
			best["i"] = i
			best["d"] = d

## "Ways out left: N" plus the nearest seat, or "" while you are still in the match.
static func line(m: Match) -> String:
	var p: Hunter = m.player
	if m.heart == null or p == null or not (p.out or p.extracted):
		return ""
	var s := "Ways out left: %d" % ways_left(m)
	var near := nearest(m, p.team)
	if near["i"] >= 0:
		s += "  ·  your squad is nearest the %s, %d m" % [String(WORDS[near["i"]]).to_lower(), int(near["d"])]
	return s

## The line on a dark pill centred on `mid` (the HUD under the strip, the full map's top); nothing while you play.
static func draw_line(hud, mid: Vector2) -> void:
	var txt := line(hud.m)
	if txt == "":
		return
	var w := TextCache.width(HudStyle.BIG, txt, LINE_FS) + 24.0
	var pill := Rect2(mid + Vector2(-w * 0.5, -15), Vector2(w, 26))
	hud.c.draw_style_box(HudStyle.box(HudStyle.SHADE, 9, Color(1, 1, 1, 0.14), 1), pill)
	HudStyle.ctext(hud.c, mid + Vector2(0, 3), txt, LINE_FS, HudStyle.INK, 3)
