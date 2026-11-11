class_name MapHover
extends RefCounted
## Tooltips on the full map (M): rest the cursor on any marker for DWELL_S and a card names it with one short
## line ("Hollow Outpost / Extraction · opens in 1:20"). Every marker kind the full map draws is listed in
## pick(), nearest marker to the cursor wins, exits first on a tie. One instance lives in FullMap.

const DWELL_S := 0.6      # s the cursor rests on one marker before its card shows
const REACH := 12.0       # px from a marker's centre that still counts as on it
const TIP_FS := 12
const NAME_FS := 14
const CARD := Color(0.09, 0.1, 0.15, 0.96)
const RIM := Color(1, 1, 1, 0.14)
const SHRINE_LINE := "Hold the key to pray: heal, a blessing and a perk"
const SPAWN_LINE := {"unknown": "Might be here: scout it to find out", "active": "Here this match",
	"empty": "Nothing here this match", "taken": "Already taken"}

var _id := ""             # what the cursor is on now ("" none)
var _since_ms := 0        # when it came to rest on `_id`
var _mp := Vector2.ZERO   # pick(): the cursor
var _best := INF          # pick(): the distance of the best marker so far
var hit := {}             # pick(): {id, pv, title, line, col} of it, or {}

func draw(fm: FullMap) -> void:
	_mp = fm.hud.c.get_local_mouse_position()
	pick(fm, _mp)
	if rest(hit.get("id", ""), Time.get_ticks_msec()):
		_card(fm)

## The cursor is on marker `id` ("" none) at `now_ms`: has it rested there long enough for the card?
func rest(id: String, now_ms: int) -> bool:
	if id != _id:
		_id = id
		_since_ms = now_ms
	return id != "" and now_ms - _since_ms >= int(DWELL_S * 1000.0)

func _near(pv: Vector2, reach := REACH) -> bool:
	var d := pv.distance_to(_mp)
	if d > reach or d >= _best:
		return false
	_best = d
	return true

func _found(id: String, pv: Vector2, title: String, line: String, col: Color) -> void:
	hit = {"id": id, "pv": pv, "title": title, "line": line, "col": col}

## The marker under `mp` (screen px) into `hit`, or {}.
func pick(fm: FullMap, mp: Vector2) -> void:
	_mp = mp
	_best = INF
	hit = {}
	var m: Match = fm.m
	if m.player == null or not fm.rect.has_point(mp):
		return
	if m.exits:
		_exits(fm, m)
	_seats(fm, m)
	_people(fm, m)
	_spawns(fm, m)
	_things(fm, m)
	_places(fm, m)
	_hot_zone(fm, m)

func _exits(fm: FullMap, m: Match) -> void:
	for x in m.exits.list:
		var pv := fm.to_screen(x["pos"])
		if _near(pv, REACH + 4.0):
			_found("exit " + String(x["name"]), pv, String(x["name"]), ExitMark.line(m, x), ExitMark.color(x))

func _seats(fm: FullMap, m: Match) -> void:
	if m.heart == null:
		return
	var at := WaysOutMap.sites(m)
	var sd := WaysOutHud.seats(m)
	for i in 4:
		if at[i] == Vector3.INF:
			continue
		var pv := fm.to_screen(at[i])
		if _near(pv, REACH + 4.0):
			var tail := WaysOutMap.word(i, sd[i]).trim_prefix(String(WaysOutMap.WORDS[i])).strip_edges()
			if int(sd[i]["st"]) == WaysOutHud.St.LOCKED:
				tail = "opens in " + tail
			_found("seat %d" % i, pv, String(WaysOutMap.WORDS[i]), "Way out  ·  " + tail, WaysOutMap.color_of(sd[i]))

func _people(fm: FullMap, m: Match) -> void:
	var p: Hunter = m.player
	for h in m.hunters:
		if h.out or h.extracted or h.riding:
			continue
		var mine: bool = h.team == p.team
		if not mine and not m.can_see(p.team, h) and not (m.truce != null and m.truce.is_marked(h)):
			continue
		var pv := fm.to_screen(h.pos)
		if _near(pv):
			_found("hunter %d" % h.get_instance_id(), pv, h.pname, _who(h, p), m.mate_col(h) if mine else FullMap.BAD)
	var k := BokiHud.mapped_kin(m)
	if k != null:
		var kv := fm.to_screen(k.position)
		if _near(kv):
			var col := Color(k.sp.get("glow", k.sp["color"]))
			_found("boki", kv, String(k.sp.get("name", "Your Boki")), "Your Boki", col)

func _who(h: Hunter, me: Hunter) -> String:
	if h == me:
		return "You"
	if h.team == me.team:
		return "Your squad"
	return "Rival  ·  bounty on them" if h.has_meta("bounty") else "Rival"

func _beacon_line(bc: Dictionary) -> String:
	if bc["used"]:
		return "Used"
	return "Lit: bring your squad back" if bc["lit"] else "Light it to bring your squad back"

func _spawns(fm: FullMap, m: Match) -> void:
	var sp: SpawnPlan = m.spawn_plan
	if sp == null:
		return
	for cnd in sp.cands:
		var pv := fm.to_screen(cnd["pos"])
		if _near(pv):
			var def: Dictionary = sp.cats.get(cnd["cat"], {})
			var nm := String(def.get("name", "?"))
			if String(cnd["name"]) != "":
				nm += "  ·  " + String(cnd["name"])
			var line: String = SPAWN_LINE[sp.state_for(cnd, m.player.team)]
			_found("spawn %d" % cnd["pos"].x, pv, nm, line, def.get("col", Color.WHITE))

## Shrines, lairs, beacons, boxes, the sky train, the ships and pings.
func _things(fm: FullMap, m: Match) -> void:
	for sh in m.shrines:
		var pv := fm.to_screen(sh["pos"])
		if _near(pv):
			_found("shrine", pv, "Shrine", "Used" if sh["used"] else SHRINE_LINE, Color("9ff0c4"))
	if m.lairs:
		for L in m.lairs.list:
			var pv := fm.to_screen(L["c"])
			if _near(pv, REACH + 4.0):
				var nm := String(L["name"])
				_found("lair " + nm, pv, nm, "Boss lair  ·  %s" % String(L["state"]), Lairs.color_of(L))
	for bc in m.beacons:
		var pv := fm.to_screen(bc["pos"])
		if _near(pv):
			_found("beacon", pv, "Revive beacon", _beacon_line(bc), Beacons.COL)
	for b in ReviveHud._known_boxes(m):
		var pv := fm.to_screen(b["pos"])
		if _near(pv):
			_found("box", pv, "%s's box" % (b["owner"] as Hunter).pname, "Deathbox", Life.owner_col(m, b))
	if m.skytrain:
		var tm: TrainMap = fm.hud.train_map
		for hs in tm.halts(m.skytrain):
			var pv := fm.to_screen(Vector3(hs["pos"].x, 0, hs["pos"].y))
			if _near(pv):
				var nm := String(hs["name"])
				var eta := TrainMap.eta_text(m.skytrain.halt_eta(hs["s"]))
				_found("halt " + nm, pv, nm, "Sky train stop  ·  " + eta, TrainMap.GOLD)
		var tv := fm.to_screen(Vector3(tm.marker(m.skytrain).x, 0, tm.marker(m.skytrain).y))
		if _near(tv):
			_found("train", tv, "Sky train", "Rides the loop and stops at every halt", TrainMap.GOLD)
	if not m.ship.is_empty() and not m.ship.get("gone", false):
		var sv := fm.to_screen(m.ship_pos())
		if _near(sv.clamp(fm.rect.position, fm.rect.end), REACH + 4.0):
			_found("ship", sv, "Skyship", "Carries the drop", FullMap.GOLD)
	for pg in m.pings:
		var pv := fm.to_screen(pg["pos"])
		if _near(pv) and (pg.get("team", null) == null or int(pg["team"]) == m.player.team):
			var by := "From %s" % (pg["by"] as Hunter).pname if pg.has("by") else "A marked spot"
			_found("ping", pv, "Ping", by, pg["col"])

## The named places: perches and chokepoints (and an island's name).
func _places(fm: FullMap, m: Match) -> void:
	for lb in m.world.labels:
		var kind := String(lb["kind"])
		if kind == "rail":
			continue
		var pv := fm.to_screen(lb["pos"])
		if _near(pv):
			var line := "Place"
			if kind == "perch":
				line = "Perch  ·  %dm up" % int(round(float(lb.get("height", 0.0))))
			elif kind == "choke":
				line = "Chokepoint  ·  a narrow way through"
			_found("place " + String(lb["name"]), pv, String(lb["name"]), line, FullMap.INK)

## The hot zone is an area, so it only answers when nothing else is under the cursor.
func _hot_zone(fm: FullMap, m: Match) -> void:
	if not hit.is_empty() or m.biomes == null:
		return
	for I in m.biomes.hot.zone:
		if fm.to_screen(I["c"]).distance_to(_mp) < float(I["r"]) * fm.k():
			_found("hot", _mp, "Hot zone", "Better loot here, and more rivals", HotZone.COL)
			return

func _card(fm: FullMap) -> void:
	var hud = fm.hud
	var title: String = hit["title"]
	var line: String = hit["line"]
	var w := maxf(TextCache.width(hud.big, title, NAME_FS), TextCache.width(hud.body, line, TIP_FS)) + 24.0
	var r := Rect2(hit["pv"] + Vector2(16.0, -52.0), Vector2(w, 46.0))
	if r.end.x > fm.rect.end.x:
		r.position.x = hit["pv"].x - 16.0 - w
	if r.position.y < fm.rect.position.y:
		r.position.y = fm.rect.position.y + 4.0
	hud._rounded(r, CARD, 8, RIM, 1)
	hud._text(r.position + Vector2(12.0, 19.0), title, NAME_FS, hit["col"], hud.big)
	hud._text(r.position + Vector2(12.0, 37.0), line, TIP_FS, FullMap.INK, hud.body)
