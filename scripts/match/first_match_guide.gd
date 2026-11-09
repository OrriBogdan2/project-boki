class_name FirstMatchGuide
extends RefCounted
## "What to do next" for a new player's first two real Extractions: one highlighted plain line at a time
## (content/rules/first_match_guide.json). A line shows once per match, when its moment comes, and clears
## on its trigger or after its time. It is only drawn: it never pauses or blocks anything. The save's
## "first_guide" counts the Extractions that have had it; at the rule's `matches` it stops for good.
## Match owns one as `guide` (null when this match gets none) and calls tick().

const MINT := Color("8fe3c8")
const ORDER := ["land", "squad", "blight", "exit", "rank", "send", "chest"]   # what to say first when two lines are due
const EXIT_NEAR := 8.0        # m: this close to an exit, the exit line has done its job

var m: Match
var line := ""                # the one line on screen ("" for none)
var id := ""                  # which line
var shown := {}               # ids already shown this match
var _t := 0.0                 # s the line has been up
var _gap := 0.0               # s of quiet left before the next line
var _throws0 := 0             # the Boki's sends when its line came up

static func rules() -> Dictionary:
	return Content.rules("first_match_guide")

## The guide for a match that is a real Extraction and a save that still needs it, else null. Counts the match.
static func for_match(mt: Match, opts: Dictionary) -> FirstMatchGuide:
	for skip in ["tutorial", "duel", "arena", "training"]:
		if opts.get(skip, false):
			return null
	var n := int(Save.d.get("first_guide", 0))
	if n >= int(rules()["matches"]):
		return null
	Save.d["first_guide"] = n + 1
	var g := FirstMatchGuide.new()
	g.m = mt
	return g

## Old saves: one that has played already has had its first matches (keyed by its own field, like FarmBuilder).
static func migrate(data: Dictionary) -> void:
	if not data.has("first_guide"):
		data["first_guide"] = mini(int(data.get("matches", 0)), int(rules()["matches"]))

func tick(dt: float) -> void:
	var p := m.player
	if p == null or p.out or p.extracted or p.downed:
		line = ""
		id = ""
		return
	_gap = maxf(_gap - dt, 0.0)
	if id != "":
		_t += dt
		if _t >= _life(id) or _done(id, p):
			id = ""
			line = ""
			_gap = float(rules()["gap"])
	if id == "" and _gap <= 0.0:
		for cand: String in ORDER:
			if not shown.has(cand) and _due(cand, p):
				_start(cand, p)
				return

func _life(lid: String) -> float:
	for row: Array in rules()["lines"]:
		if row[0] == lid:
			return float(row[2])
	return 0.0

func _start(lid: String, p: Hunter) -> void:
	id = lid
	shown[lid] = true
	_t = 0.0
	_throws0 = p.kin.st_throws if p.kin else 0
	var txt := ""
	for row: Array in rules()["lines"]:
		if row[0] == lid:
			txt = String(row[1])
	var who := String(p.kin.rec.get("name", "your Boki")) if p.kin else "your Boki"
	line = TutorialText.fill(txt, p).replace("%s", who)

func _left() -> float:
	return (m.length - m.time) / m.length

func _enemy_near(p: Hunter) -> bool:
	for h in m.hunters:
		if h.team != p.team and not h.out and not h.extracted and not h.downed \
				and h.pos.distance_to(p.pos) <= float(rules()["squad_range"]):
			return true
	return false

func _exit_near(p: Hunter) -> bool:
	return m.exits != null and m.exits.spots().any(func(s: Vector3): return s.distance_to(p.pos) <= EXIT_NEAR)

func _kin_ready(p: Hunter) -> bool:
	return p.kin != null and p.kin.state != "downed"

## Is it time for this line?
func _due(lid: String, p: Hunter) -> bool:
	if lid == "land":
		return p.dropping
	if p.dropping:
		return false
	match lid:
		"squad": return _enemy_near(p)
		"blight": return _left() <= float(rules()["close_at"])
		"exit": return shown.has("blight")
		"rank": return p.ak != null and p.skill_pts > 0
		"send": return _kin_ready(p)
		"chest": return m.chests.any(func(c: Dictionary): return not c["open"])
	return false

## Has the player done what this line says (or is it no longer true)?
func _done(lid: String, p: Hunter) -> bool:
	match lid:
		"land": return not p.dropping
		"squad": return not _enemy_near(p)
		"exit": return _exit_near(p)
		"rank": return p.skill_pts == 0
		"send": return not _kin_ready(p) or p.kin.st_throws > _throws0
		"chest": return int(p.stats.get("chests", 0)) > 0
	return false

## The line in the banner lane at the top-centre (the tutorial's lane: the two never show together).
func draw(h, sz: Vector2) -> void:
	if line == "":
		return
	var r: Rect2 = TutorialHud.lanes(sz)["banner"]
	var a := clampf(_t / 0.25, 0.0, 1.0)
	h._panel(r, Color(TutorialHud.PANEL.r, TutorialHud.PANEL.g, TutorialHud.PANEL.b, TutorialHud.PANEL.a * a), 14)
	h.c.draw_rect(r, Color(MINT, 0.7 * a), false, 2.0)
	var w := TutorialText.wrap(h.big, line, int(r.size.y * 0.42), r.size.x - 28.0, 2)
	var y: float = r.get_center().y - (w["lines"].size() - 1) * float(w["px"]) * 0.6 + float(w["px"]) * 0.36
	for ln in w["lines"]:
		h._ctext(Vector2(r.get_center().x, y), String(ln), int(w["px"]), Color(1, 1, 1, a), h.big)
		y += float(w["px"]) * 1.2
