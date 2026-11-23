class_name TimedSpawns
extends RefCounted
## The mid-match spawns on a clock (docs/SPAWNS.md, content/rules/timed_spawns.json): the Glimmerkin and
## the Watcher at the Heart. Each comes at a fixed share of the session at a fixed place (the Watcher at
## the Heart, the Glimmerkin at one outer-island wild Boki spot picked from the match seed) and is called
## out warn_s and LAST_CALL_S seconds before it appears: a map ping there and a feed line with the
## seconds left. Every peer works out the same place and time, so the callouts need no Net message;
## only the host spawns (and tells the others the Glimmerkin is out, the "anc" event).

const LAST_CALL_S := 10.0  # the second callout, this many seconds before it appears
const GLIMMER_COL := Color("ffd25a")
const WARDEN_COL := Color("c9a0ff")

var m: Match
var list: Array = []  # {id, at: match time, pos, calls: [seconds before], done}


func _init(match_node: Match) -> void:
	m = match_node
	var rules: Dictionary = Content.rules("timed_spawns")
	var spots := {"glimmer": glimmer_spot(), "warden": m.world.heart_spot}
	for id in spots:
		if spots[id] == Vector3.INF:
			continue
		var r: Dictionary = rules[id]
		var calls: Array = [float(r["warn_s"]), LAST_CALL_S]
		list.append({"id": id, "at": m.at_sess(float(r["at"])), "pos": spots[id], "calls": calls, "done": false})


## Where the Glimmerkin turns up: a wild Boki spot off the first island, the same pick on every peer.
func glimmer_spot() -> Vector3:
	var w := m.world
	var outer: Array = w.wild_spots.filter(func(p): return w.island_of(p.x, p.z) >= 1)
	if outer.is_empty():
		return Vector3.INF
	var r := RandomNumberGenerator.new()
	r.seed = hash([m.seed_val, "glimmer"])
	return outer[r.randi_range(0, outer.size() - 1)]


func tick() -> void:
	for e: Dictionary in list:
		if e["done"]:
			continue
		var left := float(e["at"]) - m.time
		if left <= 0.0:
			e["done"] = true
			_appear(e)
		elif not (e["calls"] as Array).is_empty() and left <= float(e["calls"][0]):
			(e["calls"] as Array).pop_front()
			_call_out(e, left)


func _call_out(e: Dictionary, left: float) -> void:
	var at: Vector3 = e["pos"]
	var col := GLIMMER_COL if e["id"] == "glimmer" else WARDEN_COL
	m.ping(at, col)
	if m.player == null or m.player.out:
		return
	var text := "The Watcher wakes on the center island in %d s" % ceili(left)
	if e["id"] == "glimmer":
		text = "A Glimmerkin turns up %s in %d s" % [m.direction_word(m.player.pos, at), ceili(left)]
	m.add_feed(text)
	if m.hud:
		m.hud.toast_small(text, col)


func _appear(e: Dictionary) -> void:
	var at: Vector3 = e["pos"]
	var host := not m.net_on or m.is_host
	if e["id"] == "glimmer":
		if not host:
			return  # the host's "anc" event announces it
		m.spawn_mob("glimmer", at)
		m.ping(at, GLIMMER_COL)
		var where := m.direction_word(m.player.pos, at) if m.player else ""
		m._announce("A Glimmerkin appeared %s. Catch it before it escapes" % where, GLIMMER_COL)
		if m.net_on:
			m.net_event(["anc", "glimmer", m._r(at.x), m._r(at.y), m._r(at.z)])
		return
	if host:
		var w := m.spawn_mob("warden", at + Vector3(0, 0, 1.5))
		w.st = "idle"
		if m.opts.get("watch_heart", false) and m.player:
			var wp := at + Vector3(0, 0, 5.0)
			m.player.teleport(Vector3(wp.x, m.world.ground_at(wp.x, wp.z), wp.z))
	m.sfx("warn", null, 0.0, 0.6)
	m.ping(at, WARDEN_COL)
	if m.player and not m.player.out:
		m.add_feed("The Watcher has woken on the center island")
		if m.hud:
			m.hud.toast("The Watcher wakes", WARDEN_COL)
