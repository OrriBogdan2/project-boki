class_name ExtractWidget
extends RefCounted
## The one box about the way out: shown while an exit is open, hidden when none is. It says which exit
## (the squad's own, else the nearest), the way and distance to it, how long it stays open, the next step, and
## while boarding or charging the progress and what cancels it. All numbers are the match's own (Exits).
## state() is the data (checked in --extract-check); draw() puts it inside the safe area.

const SAFE := Vector2(0.04, 0.04)     # of the screen kept clear on each side and edge
const PROMPT_CLEAR := 262.0           # px from the bottom edge that the interact prompt (and its bar) fills
const BOX_W := 330.0                  # px at 1080p, scaled with screen height
const ROW_H := 20.0                   # px per text row at 1080p
const FAR := Color(0.75, 0.78, 0.85)  # the arrow and distance
const CANCEL := Color("ffb08a")

## The widget's data, or {} while it is hidden: x (the exit), name, col, bearing (rad from screen up, clockwise),
## dist (m), left (how long it stays open), step (the one next thing to do, "" when the prompt owns it), prog
## (0..1 or -1), cancel (what cancels it, "" if nothing).
static func state(m: Match, p: Hunter) -> Dictionary:
	if hidden(m, p):
		return {}
	var x := _pick(m, p)
	if x.is_empty():
		return {}
	var at: Vector3 = x.get("berth", x["pos"])
	var s := {"x": x, "name": String(x["name"]), "col": Exits.color_of(x), "dist": p.flat_dist(at),
		"bearing": atan2(at.x - p.pos.x, p.pos.z - at.z), "left": "", "step": "", "prog": -1.0, "cancel": ""}
	match String(x["kind"]):
		"dock": _dock(m, p, x, s)
		"hatch": _hatch(m, p, x, s)
		_: _outpost(m, p, x, s)
	var it := m.interact
	if it.has("act") and is_same(it.get("x"), x):
		s["step"] = ""
	return s

## No widget: nobody to tell (out, out of the match, dropping in), the tutorial has its own banner, a duel.
static func hidden(m: Match, p: Hunter) -> bool:
	return m.exits == null or p == null or p.out or p.extracted or p.dropping or m.duel != null \
		or bool(m.opts.get("tutorial", false))

## An exit the squad could use right now: a skiff to call or board, a hatch open (or openable with a key), an uplink.
static func is_open(m: Match, x: Dictionary, p: Hunter) -> bool:
	if String(x["kind"]) == "hatch":
		return String(x["state"]) in ["unlocking", "open"] or (x["state"] == "sealed" and p.rift_keys > 0)
	return m.exits.live(x)

## An info-only exit prompt the widget already says (so the prompt lane stays free for it).
static func covers_prompt(m: Match, it: Dictionary) -> bool:
	return String(it.get("kind", "")) == "exit" and not it.has("act") and not hidden(m, m.player) \
		and is_open(m, it["x"], m.player)

## The area inside the screen margins: nothing of the widget goes outside it.
static func safe_rect(sz: Vector2) -> Rect2:
	return Rect2(sz * SAFE, sz * (Vector2.ONE - SAFE * 2.0))

## Where the box sits: bottom centre, just above the interact prompt (the top is the message lane), inside the
## safe area.
static func box_rect(sz: Vector2, rows: int) -> Rect2:
	var k := _scale(sz)
	var box := Vector2(BOX_W, ROW_H * (rows + 1) + 14.0) * k
	var safe := safe_rect(sz)
	var at := Vector2(sz.x * 0.5 - box.x * 0.5, sz.y - PROMPT_CLEAR - box.y)
	at = at.clamp(safe.position, safe.end - box)
	return Rect2(at, box)

static func draw(h, sz: Vector2) -> void:
	var s := state(h.m, h.m.player)
	if s.is_empty():
		return
	var rows := 2 + int(s["step"] != "") + int(s["cancel"] != "")
	var r := box_rect(sz, rows)
	var k := _scale(sz)
	var col: Color = s["col"]
	h._panel(r, Color(0.04, 0.05, 0.08, 0.9), 12)
	var x := r.position.x + 12.0 * k
	var y := r.position.y + ROW_H * k
	_arrow(h, Vector2(x + 10.0 * k, y - 6.0 * k), float(s["bearing"]), 10.0 * k, col)
	h._text(Vector2(x + 28.0 * k, y), String(s["name"]), int(17.0 * k), col, h.big)
	var dist := "%d m" % int(round(float(s["dist"])))
	var dist_w: float = h.big.get_string_size(dist, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17.0 * k)).x
	h._text(Vector2(r.end.x - 12.0 * k - dist_w, y), dist, int(17.0 * k), h.INK, h.big)
	y += ROW_H * k
	h._text(Vector2(x, y), String(s["left"]), int(14.0 * k), FAR)
	if s["step"] != "":
		y += ROW_H * k
		h._text(Vector2(x, y), String(s["step"]), int(15.0 * k), h.GOLD, h.big)
	if float(s["prog"]) >= 0.0:
		h._bar(Rect2(Vector2(x, r.end.y - 9.0 * k), Vector2(r.size.x - 24.0 * k, 4.0 * k)), float(s["prog"]), col)
	if s["cancel"] != "":
		y += ROW_H * k
		h._text(Vector2(x, y), String(s["cancel"]), int(13.0 * k), CANCEL)

static func _scale(sz: Vector2) -> float:
	return clampf(sz.y / 1080.0, 0.75, 1.25)

static func _arrow(h, c: Vector2, bearing: float, radius: float, col: Color) -> void:
	var wing := radius * 0.7
	var corners := [Vector2(0, -radius), Vector2(wing, wing), Vector2(0, radius * 0.3), Vector2(-wing, wing)]
	var pts := PackedVector2Array()
	for v: Vector2 in corners:
		pts.append(c + v.rotated(bearing))
	h.c.draw_colored_polygon(pts, col)

## The squad's own exit, else the nearest open one.
static func _pick(m: Match, p: Hunter) -> Dictionary:
	var mine: Dictionary = m.exits.active_for(p.team)
	if not mine.is_empty():
		return mine
	var best := {}
	var best_d := INF
	for x in m.exits.list:
		var d := p.flat_dist(x["pos"])
		if d < best_d and is_open(m, x, p):
			best = x
			best_d = d
	return best

static func _dock(m: Match, p: Hunter, x: Dictionary, s: Dictionary) -> void:
	var key := Settings.key_cap("interact")
	match String(x["state"]):
		"called":
			s["left"] = "Skiff arrives in %s" % Exits.cap(x["t"])
			s["step"] = "Hold the dock until it ties up"
			s["prog"] = clampf(1.0 - float(x["t"]) / Exits.CALL_T, 0.0, 1.0)
		"boarding":
			var aboard: bool = m.exits.on_deck(x, p)
			s["left"] = "Leaves in %ds" % int(ceil(x["t"]))
			s["step"] = "Aboard: stay on the deck" if aboard else "Get on the skiff's deck"
			s["prog"] = clampf(1.0 - float(x["t"]) / Exits.BOARD_T, 0.0, 1.0)
			s["cancel"] = "Step off the deck and you stay behind" if aboard else ""
		_:
			var until := minf(float(x["close_at"]), m.length)
			s["left"] = "Open for %s" % Exits.cap(until - m.time)
			var here: bool = p.flat_dist(x["pos"]) < 1.8
			s["step"] = ("Hold %s here to call a skiff" % key) if here else "Go to the beacon to call a skiff"

static func _hatch(m: Match, p: Hunter, x: Dictionary, s: Dictionary) -> void:
	match String(x["state"]):
		"unlocking":
			s["left"] = "Opens in %ds" % int(ceil(float(x["t"])))
			s["step"] = "Hold out until it opens"
			s["prog"] = clampf(1.0 - float(x["t"]) / Exits.HATCH_UNLOCK_T, 0.0, 1.0)
		"open":
			s["left"] = "%d of %d drops left" % [int(x["uses"]), Exits.HATCH_USES]
			s["step"] = "Walk in to drop through"
		_:
			s["left"] = "Sealed: your key opens it"
			s["step"] = "Take your Rift Key to the hatch"

static func _outpost(m: Match, p: Hunter, x: Dictionary, s: Dictionary) -> void:
	match String(x["state"]):
		"charging": _uplink_charging(m, p, x, s)
		"open":
			s["left"] = "Lift closes in %ds" % int(ceil(x["t"]))
			s["step"] = "Step into the light"
			s["prog"] = clampf(1.0 - float(x["t"]) / Exits.LIFT_T, 0.0, 1.0)
		_:
			s["left"] = "Open for %s" % Exits.cap(m.length - m.time)
			var here: bool = p.flat_dist(x["pos"]) < 1.9
			var key := Settings.key_cap("interact")
			s["step"] = ("Hold %s at the console to start" % key) if here else "Go to the console to start it"

static func _uplink_charging(m: Match, p: Hunter, x: Dictionary, s: Dictionary) -> void:
	var mine: bool = int(x["team"]) == p.team
	var rate := maxf(1.0, Exits.crew_rate(int(x.get("crew", 0))))
	s["prog"] = clampf(float(x["prog"]), 0.0, 1.0)
	if x.get("draining", false):
		s["left"] = "Runs dry in %s" % Exits.cap(m.exits.drain_left(x))
	elif x["contested"]:
		s["left"] = "Stalled by a rival"
	else:
		s["left"] = "Lift in %s" % Exits.cap((1.0 - float(x["prog"])) * m.exits.uplink_time(x) / rate)
	if not m.exits.in_yard(x, p):
		s["step"] = "Back to the yard" if mine else "Hold the yard to take it over"
	elif x["contested"]:
		s["step"] = "Clear the rival out of the yard"
	else:
		s["step"] = "Hold the yard" if mine else "Hold the yard to take it over"
	if mine:
		s["cancel"] = "Leave the yard and it drains · a rival in it stalls it"
