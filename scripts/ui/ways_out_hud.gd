class_name WaysOutHud
extends RefCounted
## The Ways Out strip (briefs/specs/LIMITED_WAY_OUTS.md section 9), top centre: four pips (Lair, Heart, Uplink,
## Final), each locked with a countdown, open, in use (the squad's colour), taken (struck through) or lost to
## the Blight (squads and players left are the top-right AliveCounter). Plus the carrier's Heart Gate prompt.
## Reads the match only: the Heart's state for the two Heart seats, the lairs and outposts for the quest seats
## (their schedule is content/rules/heart.json "quest"). Drawn with HudStyle on the Hud's canvas.

enum St {LOCKED, OPEN, USE, TAKEN, LOST}
const NAMES := ["LAIR", "HEART", "UPLINK", "FINAL"]
const CELL := Vector2(86.0, 40.0)
const PIP_R := 7.0
const STATE_WORD := ["", "OPEN", "IN USE", "TAKEN", "LOST"]

## Reused every frame: name, st, t (seconds to open/shut or -1), team, viewer (the local squad).
static var _seats: Array = [{}, {}, {}, {}]

## The four seats as they stand now (the same dictionaries every call).
static func seats(m: Match) -> Array:
	var now := m.sess_time()
	var q: Dictionary = Heart.rules()["quest"]
	_quest(0, now, q["lair_open_s"], q["lair_shut_s"], _lair_team(m, "flown"), _lair_team(m, "sealed_in"))
	_heart_early(m)
	var live := _uplink_team(m, "charging", "open")
	_quest(2, now, q["uplink_open_s"], q["uplink_shut_s"], _uplink_team(m, "spent"), live)
	_heart_final(m, now)
	var viewer := SideColor.viewer(m)
	for d in _seats:
		d["viewer"] = viewer
	return _seats

## A squad other than the viewer's holds the seat (taking or having taken it).
static func rival(s: Dictionary) -> bool:
	return int(s["team"]) >= 0 and int(s["team"]) != int(s["viewer"])

## The seat's state word; a seat a squad uses or took says whose it is, so squad and rival never read by hue alone.
static func state_word(s: Dictionary) -> String:
	if int(s["team"]) >= 0 and int(s["st"]) in [St.USE, St.TAKEN]:
		return WaysOutLook.WORD_RIVAL if rival(s) else WaysOutLook.WORD_MINE
	return STATE_WORD[int(s["st"])]

static func _seat(i: int, st: int, t: float, team: int) -> void:
	var d: Dictionary = _seats[i]
	d["name"] = NAMES[i]
	d["st"] = st
	d["t"] = t
	d["team"] = team

static func _quest(i: int, now: float, open_s: float, shut_s: float, taken: int, using: int) -> void:
	if taken >= 0:
		_seat(i, St.TAKEN, -1.0, taken)
	elif using >= 0:
		_seat(i, St.USE, -1.0, using)
	elif now < open_s:
		_seat(i, St.LOCKED, open_s - now, -1)
	elif now < shut_s:
		_seat(i, St.OPEN, shut_s - now, -1)
	else:
		_seat(i, St.LOST, -1.0, -1)

static func _heart_early(m: Match) -> void:
	var ht: Heart = m.heart
	if ht.early_team >= 0:
		_seat(1, St.TAKEN, -1.0, ht.early_team)
	elif ht.carrier != null:
		_seat(1, St.USE, -1.0, ht.carrier.team)
	elif ht.spark_live():
		_seat(1, St.OPEN, -1.0, -1)
	elif ht.state == Heart.S.ASLEEP:
		_seat(1, St.LOCKED, Heart.r("wake_s") + Heart.r("charge_s") - m.sess_time(), -1)
	elif ht.state == Heart.S.CHARGING:
		_seat(1, St.LOCKED, Heart.r("charge_s") - ht.charge, -1)
	else:
		_seat(1, St.LOST, -1.0, -1)

static func _heart_final(m: Match, now: float) -> void:
	var ht: Heart = m.heart
	match ht.state:
		Heart.S.DONE:
			_seat(3, St.TAKEN, -1.0, ht.final_team)
		Heart.S.FINAL:
			_seat(3, St.USE if ht.final_team >= 0 and ht.final_prog > 0.0 else St.OPEN, -1.0, ht.final_team)
		_:
			_seat(3, St.LOCKED, Heart.r("final_s") - now, -1)

## The squad of the first hunter listed under `key` on any lair ("flown": left by the updraft, "sealed_in": fighting).
static func _lair_team(m: Match, key: String) -> int:
	if m.lairs == null:
		return -1
	for L in m.lairs.list:
		var who: Array = L.get(key, [])
		if not who.is_empty():
			return (who[0] as Hunter).team
	return -1

## The squad of the first outpost in one of these states.
static func _uplink_team(m: Match, a: String, b := "") -> int:
	if m.exits == null:
		return -1
	for x in m.exits.list:
		if x["kind"] == "outpost" and (x["state"] == a or x["state"] == b):
			return int(x.get("team", -1))
	return -1

static func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]

# ------------------------------------------------------------------ the strip
## Where the strip starts: the top of the window's safe area.
static func top_y(sz: Vector2) -> float:
	return HudStyle.safe_pad(sz).y

## The lowest y the strip and the line under it reach (the pill ends 11 px under its middle), or 0 when the strip
## is not drawn (no Heart, a tutorial, training or a duel): what sits under it at the top-centre starts lower.
static func bottom(m: Match) -> float:
	if m.duel or m.opts.get("training", false) or m.opts.get("tutorial", false):
		return 0.0
	if m.heart == null or m.heart.site == Vector3.INF:
		return 0.0
	return top_y(m.get_viewport().get_visible_rect().size) + CELL.y + 20.0 + 11.0

static func draw(hud) -> void:
	var m: Match = hud.m
	if m.heart == null or m.heart.site == Vector3.INF or not HudGroups.ways_out_shown(m):
		return
	var c: Control = hud.c
	var sd := seats(m)
	var w := CELL.x * 4.0
	var r := Rect2(Vector2(c.size.x * 0.5 - w * 0.5, top_y(c.size)), Vector2(w, CELL.y))
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 8, Color(1, 1, 1, 0.14), 1), r)
	for i in 4:
		_cell(c, Rect2(r.position + Vector2(CELL.x * i, 0), CELL), sd[i], m.time)
	for i in [0, 2]:
		QuestRace.draw(m, c, Vector2(r.position.x + CELL.x * i + 17.0, r.end.y + 7.0), QuestRace.read(m, i))
	WaysOutMap.draw_line(hud, Vector2(c.size.x * 0.5, r.end.y + 32.0))

static func _cell(c: Control, r: Rect2, s: Dictionary, now: float) -> void:
	var st: int = s["st"]
	var team: int = s["team"]
	var squad: Color = SideColor.of_team(s["viewer"], team) if team >= 0 else HudStyle.INK
	var foe := rival(s)
	var pv := r.position + Vector2(17, r.size.y * 0.5)
	var word := state_word(s)
	var col := HudStyle.MUTED
	match st:
		St.LOCKED:
			word = _clock(s["t"])
			c.draw_arc(pv, PIP_R, 0, TAU, 20, Color(col, 0.7), 2.0, true)
		St.OPEN:
			col = HudStyle.INK
			word = "%s %s" % [word, _clock(s["t"])] if float(s["t"]) > 0.0 else word
			var ph := fmod(now * 1.2, 1.0)
			c.draw_arc(pv, PIP_R + 1.0 + ph * 4.0, 0, TAU, 20, Color(col, 1.0 - ph), 1.5, true)
			c.draw_circle(pv, PIP_R, col)
		St.USE:
			col = squad
			pip(c, pv, PIP_R + 2.0, Color(col, 0.35), foe, true)
			pip(c, pv, PIP_R, col, foe, true)
		St.TAKEN:
			col = squad.darkened(0.25)
			pip(c, pv, PIP_R, Color(col, 0.8), foe, false)
			var e := PIP_R + 2.0
			c.draw_line(pv + Vector2(-e, e), pv + Vector2(e, -e), col, 2.5, true)
		St.LOST:
			col = SideColor.tone("seat_lost")
			c.draw_circle(pv, PIP_R, Color(col, 0.55))
			c.draw_line(pv + Vector2(-3, -3), pv + Vector2(3, 3), Color(0, 0, 0, 0.7), 2.0, true)
			c.draw_line(pv + Vector2(-3, 3), pv + Vector2(3, -3), Color(0, 0, 0, 0.7), 2.0, true)
	var tx := r.position.x + 31.0
	var name_col := HudStyle.INK if st == St.OPEN or st == St.USE else col
	HudStyle.text(c, Vector2(tx, r.position.y + 16), s["name"], 11, name_col, 3)
	HudStyle.text(c, Vector2(tx, r.position.y + 33), word, 12, col if st != St.LOCKED else HudStyle.INK, 3)
	if st == St.TAKEN:
		var nw := TextCache.width(HudStyle.BIG, s["name"], 11)
		c.draw_line(Vector2(tx - 1, r.position.y + 12), Vector2(tx + nw + 1, r.position.y + 12), col, 1.5)

## A pip: a disc for your squad or nobody, a diamond for a rival's seat; filled or an outline.
static func pip(c: Control, pv: Vector2, r: float, col: Color, diamond: bool, fill: bool) -> void:
	if not diamond:
		if fill:
			c.draw_circle(pv, r, col)
		else:
			c.draw_arc(pv, r, 0, TAU, 20, col, 2.0, true)
		return
	var k := r * 1.25
	var pts := PackedVector2Array([pv + Vector2(0, -k), pv + Vector2(k, 0), pv + Vector2(0, k), pv + Vector2(-k, 0)])
	if fill:
		c.draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		c.draw_polyline(pts, col, 2.0, true)

# ------------------------------------------------------------------ the Heart Gate prompt
## What the carrier sees at the Gate: the live key, "Leave now: small reward", the hold bar (rules gate_hold_s),
## one line under it. `it` is the Heart's interact dictionary; false when it is not the carrier's leave prompt.
static func gate_prompt(hud, sz: Vector2, y: float, it: Dictionary) -> bool:
	if it.get("kind", "") != "heart" or it.get("act", "") != "leave":
		return false
	var c: Control = hud.c
	var key := Settings.key_cap("interact")
	var main := "Leave now: small reward"
	var mw := TextCache.width(HudStyle.BIG, main, 16)
	var kw := TextCache.width(HudStyle.BIG, key, HudStyle.KEY_FS) + 12.0
	var w := kw + 10.0 + mw + 26.0
	var x := sz.x * 0.5 - w * 0.5
	var edge := Color(Heart.gate_col(), 0.7)
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 9, edge, 1), Rect2(Vector2(x, y - 22), Vector2(w, 34)))
	HudStyle.key_pill(c, Vector2(x + 13 + kw * 0.5, y - 5), key, Heart.gate_col())
	HudStyle.text(c, Vector2(x + 13 + kw + 10, y), main, 16, HudStyle.INK)
	HudStyle.strip(c, Rect2(Vector2(x + 6, y + 14), Vector2(w - 12, 4)), float(it["prog"]), Heart.gate_col())
	var mid := sz.x * 0.5
	var stay := stay_line(hud.m)
	var sw := TextCache.width(HudStyle.BODY, stay, 13) + 20.0
	var back := Rect2(Vector2(mid - sw * 0.5, y + 22), Vector2(sw, 20))
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 7, Color(0, 0, 0, 0), 0), back)
	HudStyle.ctext(c, Vector2(mid, y + 37), stay, 13, HudStyle.INK, 3, HudStyle.BODY)
	return true

## The line under the Gate prompt: what staying gets you.
static func stay_line(m: Match) -> String:
	if m.heart.state == Heart.S.FINAL:
		return "Stay and hold the Heart ring for the big reward."
	return "Stay and the Heart opens at %s." % _clock(Heart.r("final_s"))
