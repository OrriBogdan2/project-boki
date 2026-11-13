class_name OneSeat
extends RefCounted
## A squad uses one seat (docs/decisions/0051-limited-ways-out.md, briefs/specs/LIMITED_WAY_OUTS.md section 5).
## A seat takes the squad members standing in it. The others get Heart.r("late_s") to reach it (a countdown and
## a line to the seat on their screen), then go home without their carried loot; their own Boki always comes
## home. A squad that has used a seat can start no other. Exits owns this; the Heart, the Lair and the Uplink
## call taken() in every game when their seat fires, and each game handles only the Hunters it plays.

var m: Match
var used := {}  # squad -> the `how` of the seat it used
var late := {}  # Hunter -> {how, where, col, at, until, reach}: told to get to the seat before `until`


func _init(match_node: Match) -> void:
	m = match_node


func spent(h: Hunter) -> bool:
	return used.has(h.team)


## The seat `how` (called `where`, at `at`) just took `team`; `reach` says whether a Hunter is in the seat.
func taken(how: String, team: int, where: String, col: Color, at: Vector3, reach: Callable) -> void:
	used[team] = how
	var left := Heart.r("late_s")
	for h in m.hunters:
		if h.team != team or h.remote or h.out or h.extracted:
			continue
		late[h] = {"how": how, "where": where, "col": col, "at": at, "until": m.time + left, "reach": reach}
		if h == m.player and m.hud:
			var msg := "Your squad took a seat out (%s)  ·  get there in %d s or go home without your loot"
			m.hud.toast(msg % [where, int(left)], col)


func tick(_dt: float) -> void:
	for h: Hunter in late.keys():
		var e: Dictionary = late[h]
		if not is_instance_valid(h) or h.out or h.extracted:
			late.erase(h)
		elif (e["reach"] as Callable).call(h):
			late.erase(h)
			m._extract(h, e["how"], e["where"])
		elif m.time >= float(e["until"]):
			late.erase(h)
			_send_home(h)


## Out of the match with nothing: what they carried is dropped where they stand, and the Boki goes home with them.
func _send_home(h: Hunter) -> void:
	var n := mini(10, int(ceil(h.gems / 5.0)))
	for i in n:
		m.drop("gem", h.pos + Vector3(0, 0.5, 0), maxi(1, h.gems / n))
	for s in h.seeds:
		m.drop("seed", h.pos + Vector3(0, 0.5, 0), int(h.seeds[s]), s)
	for rec in h.caught:
		m.spawn_wild(rec, h.pos, true)
	h.gems = 0
	h.seeds = {}
	h.caught = []
	m.cancel_abilities(h)
	h.downed = false
	h.out = true
	h.gone = true
	if h.kin:
		h.kin.visible = false
	m.add_feed("%s went home: their squad's seat was taken" % h.pname)
	if m.net_on:
		m.net_event(["out", h.nid, "", "left behind"])
	if h == m.player:
		m.result = {"extracted": false, "why": "left behind"}
		m._end_soon(1.6)
	m._check_last()


## The local Hunter's countdown, a pin at the seat and a line to it (HeartHud.world_labels calls this).
static func draw(hud) -> void:
	var mt: Match = hud.m
	var os: OneSeat = mt.exits.one_seat if mt.exits else null
	var e: Dictionary = os.late.get(mt.player, {}) if os and mt.player else {}
	if e.is_empty():
		return
	var left := ceili(float(e["until"]) - mt.time)
	var at: Vector3 = e["at"]
	var col: Color = e["col"]
	hud._draw_waypoint(at + Vector3(0, 1.0, 0), "%s  %d s" % [e["where"], left], col)
	if not mt.cam.is_position_behind(at):
		var a: Vector2 = mt.cam.unproject_position(mt.player.pos + Vector3(0, 1.0, 0))
		var b: Vector2 = mt.cam.unproject_position(at + Vector3(0, 1.0, 0))
		hud.c.draw_line(a, b, Color(col, 0.55), 4.0)
	var txt := "Reach %s in %d s  ·  or go home without your loot" % [e["where"], left]
	hud._ctext(Vector2(hud.c.size.x * 0.5, hud.c.size.y * 0.2), txt, 18, col, hud.big)
