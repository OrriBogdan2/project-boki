class_name WaysOutHud
extends RefCounted
## The Ways Out strip (briefs/specs/LIMITED_WAY_OUTS.md section 9), top centre: four pips (Lair, Heart, Uplink,
## Final), each locked with a countdown, open, in use (the squad's colour), taken (struck through) or lost to
## the Blight, and "Squads left" beside them. Plus the carrier's Heart Gate prompt.
## Reads the match only: the Heart's state for the two Heart seats, the lairs and outposts for the quest seats
## (their schedule is content/rules/heart.json "quest"). Drawn with HudStyle on the Hud's canvas.

enum St {LOCKED, OPEN, USE, TAKEN, LOST}
const NAMES := ["LAIR", "HEART", "UPLINK", "FINAL"]
const CELL := Vector2(86.0, 40.0)
const SQUADS_W := 112.0
const TOP_Y := 8.0
const PIP_R := 7.0
const LOST_COL := Color("8a3a4a")    # a seat the Blight took: the tide's crimson, dimmed
const STATE_WORD := ["", "OPEN", "IN USE", "TAKEN", "LOST"]

static var _seats: Array = [{}, {}, {}, {}]    # reused every frame: name, st, t (seconds to open/shut or -1), team

## The four seats as they stand now (the same dictionaries every call).
static func seats(m: Match) -> Array:
	var now := m.sess_time()
	var q: Dictionary = Heart.rules()["quest"]
	_quest(0, now, q["lair_open_s"], q["lair_shut_s"], _lair_team(m, "flown"), _lair_team(m, "sealed_in"))
	_heart_early(m)
	var live := _uplink_team(m, "charging", "open")
	_quest(2, now, q["uplink_open_s"], q["uplink_shut_s"], _uplink_team(m, "spent"), live)
	_heart_final(m, now)
	return _seats

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

## Squads with at least one Hunter still in the match.
static func squads_left(m: Match) -> int:
	var mask := 0
	for h in m.hunters:
		if not h.out and not h.extracted:
			mask |= 1 << h.team
	var n := 0
	while mask != 0:
		n += mask & 1
		mask >>= 1
	return n

static func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]

# ------------------------------------------------------------------ the strip
static func draw(hud) -> void:
	var m: Match = hud.m
	if m.heart == null or m.heart.site == Vector3.INF:
		return
	var c: Control = hud.c
	var sd := seats(m)
	var w := CELL.x * 4.0 + SQUADS_W
	var r := Rect2(Vector2(c.size.x * 0.5 - w * 0.5, TOP_Y), Vector2(w, CELL.y))
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 8, Color(1, 1, 1, 0.14), 1), r)
	for i in 4:
		_cell(c, Rect2(r.position + Vector2(CELL.x * i, 0), CELL), sd[i], m.time)
	var sx := r.end.x - SQUADS_W
	c.draw_line(Vector2(sx, r.position.y + 7), Vector2(sx, r.end.y - 7), Color(1, 1, 1, 0.14), 1.0)
	HudStyle.ctext(c, Vector2(sx + SQUADS_W * 0.5, r.position.y + 16), "Squads left", 11, HudStyle.MUTED, 3)
	HudStyle.ctext(c, Vector2(sx + SQUADS_W * 0.5, r.position.y + 34), str(squads_left(m)), 15, HudStyle.INK, 3)
	WaysOutMap.draw_line(hud, Vector2(c.size.x * 0.5, r.end.y + 20.0))

static func _cell(c: Control, r: Rect2, s: Dictionary, now: float) -> void:
	var st: int = s["st"]
	var team: int = s["team"]
	var squad: Color = Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()] if team >= 0 else HudStyle.INK
	var pv := r.position + Vector2(17, r.size.y * 0.5)
	var word: String = STATE_WORD[st]
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
			c.draw_circle(pv, PIP_R + 2.0, Color(col, 0.35))
			c.draw_circle(pv, PIP_R, col)
		St.TAKEN:
			col = squad.darkened(0.25)
			c.draw_arc(pv, PIP_R, 0, TAU, 20, Color(col, 0.8), 2.0, true)
			var e := PIP_R + 2.0
			c.draw_line(pv + Vector2(-e, e), pv + Vector2(e, -e), col, 2.5, true)
		St.LOST:
			col = LOST_COL
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
	var edge := Color(Heart.GATE_COL, 0.7)
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 9, edge, 1), Rect2(Vector2(x, y - 22), Vector2(w, 34)))
	HudStyle.key_pill(c, Vector2(x + 13 + kw * 0.5, y - 5), key, Heart.GATE_COL)
	HudStyle.text(c, Vector2(x + 13 + kw + 10, y), main, 16, HudStyle.INK)
	HudStyle.strip(c, Rect2(Vector2(x + 6, y + 14), Vector2(w - 12, 4)), float(it["prog"]), Heart.GATE_COL)
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
