class_name FirstMatchGuide
extends RefCounted
## "What to do next" for a new player's first real Extractions (the camp lines one match longer): one
## highlighted plain line at a time (content/rules/first_match_guide.json). A line shows once per match,
## when its moment comes, and clears on its trigger or after its time. It is only drawn: it never pauses
## or blocks anything. The save's
## "first_guide" counts the Extractions that have had it; past the rule's `matches` only the camp lines
## (CAMP_LINES) show, and at its `camp_matches` it stops for good.
## Match owns one as `guide` (null when this match gets none) and calls tick().

const MINT := Color("8fe3c8")
## What to say first when two lines are due.
const ORDER := ["pick", "land", "camp", "squad", "blight", "exit", "rank", "send", "chest"]
const CAMP_LINES := ["pick", "camp"]
const EXIT_NEAR := 8.0        # m: this close to an exit, the exit line has done its job

var m: Match
var line := ""                # the one line on screen ("" for none)
var id := ""                  # which line
var shown := {}               # ids already shown this match
var nth := 0                  # this match among the save's guided Extractions (0: the first)
var _t := 0.0                 # s the line has been up
var _gap := 0.0               # s of quiet left before the next line
var _throws0 := 0             # the Boki's sends when its line came up
var target := Vector3.INF     # the camp the line points at (INF for none): pulsed on the drop map, pinned in the world
var _cleared := false         # the squad has cleared a camp
var _wired := false           # listening to Camps.cleared

static func rules() -> Dictionary:
	return Content.rules("first_match_guide")

## The guide for a match that is a real Extraction and a save that still needs it, else null. Counts the match.
static func for_match(mt: Match, opts: Dictionary) -> FirstMatchGuide:
	for skip in ["tutorial", "duel", "arena", "training"]:
		if opts.get(skip, false):
			return null
	var n := int(Save.d.get("first_guide", 0))
	if n >= int(rules()["camp_matches"]):
		return null
	Save.d["first_guide"] = n + 1
	var g := FirstMatchGuide.new()
	g.m = mt
	g.nth = n
	return g

## Old saves: one that has played already has had its first matches (keyed by its own field, like FarmBuilder).
static func migrate(data: Dictionary) -> void:
	if not data.has("first_guide"):
		data["first_guide"] = mini(int(data.get("matches", 0)), int(rules()["camp_matches"]))

func tick(dt: float) -> void:
	var p := m.player
	if p == null or p.out or p.extracted or p.downed:
		line = ""
		id = ""
		target = Vector3.INF
		return
	_gap = maxf(_gap - dt, 0.0)
	if not _wired and m.camps:
		_wired = true
		m.camps.cleared.connect(func(_id: int, squad: int): _cleared = _cleared or squad == m.player.team)
	if id == "camp":
		target = _nearest_camp(p)
	if id != "":
		_t += dt
		if _t >= _life(id) or _done(id, p):
			id = ""
			line = ""
			target = Vector3.INF
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
	if lid == "pick":
		target = _mid_small_camp()

## The nearest camp with monsters up, for the pointer after landing (INF if none).
func _nearest_camp(p: Hunter) -> Vector3:
	var c := m.camps.nearest_live(p.pos, INF) if m.camps else {}
	return c["pos"] if not c.is_empty() else Vector3.INF

## The Small Camp to pulse on the drop map: in a middle region (not the Crown or the hot zone), nearest the centre.
func _mid_small_camp() -> Vector3:
	if m.camps == null or m.biomes == null:
		return Vector3.INF
	var crown := -1
	if m.world.heart_spot != Vector3.INF:
		crown = m.biomes.hot.region_at(m.world.heart_spot)
	var skip := [m.biomes.hot.hot, crown]
	var mid := Vector3(m.world.w * 0.5, 0.0, m.world.h * 0.5)
	var best := Vector3.INF
	for e in m.camps.list():
		if e["size"] != "small" or e["region"] < 0 or e["region"] in skip:
			continue
		if best == Vector3.INF or e["pos"].distance_to(mid) < best.distance_to(mid):
			best = e["pos"]
	return best

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
	if nth >= int(rules()["matches"]) and lid not in CAMP_LINES:
		return false
	if lid == "pick":
		return m.skydrop != null and m.skydrop.planning and _mid_small_camp() != Vector3.INF
	if lid == "land":
		return p.dropping
	if p.dropping:
		return false
	match lid:
		"camp": return not _cleared and not p.riding and _nearest_camp(p) != Vector3.INF
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
		"pick": return not m.skydrop.planning
		"land": return not p.dropping
		"camp": return _cleared
		"squad": return not _enemy_near(p)
		"exit": return _exit_near(p)
		"rank": return p.skill_pts == 0
		"send": return not _kin_ready(p) or p.kin.st_throws > _throws0
		"chest": return int(p.stats.get("chests", 0)) > 0
	return false

## The line in the tutorial's strip at the top-centre (the two never show together), under the Ways Out strip.
func draw(h, sz: Vector2) -> void:
	if line == "":
		return
	if id == "camp" and target != Vector3.INF and m.player:
		h._draw_waypoint(target, "Camp", MINT)
	var below := WaysOutHud.bottom(h.m)
	if h.m.skydrop and h.m.skydrop.planning:
		below = maxf(below, 48.0)      # the ship's countdown line (Hud, y 40, 18 px)
	TutorialStrip.paint(h.c, h.big, TutorialStrip.shown(sz, _t, below), {"text": line}, _t, clampf(_t / 0.25, 0.0, 1.0))
