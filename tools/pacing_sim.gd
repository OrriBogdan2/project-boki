extends RefCounted
## --pacing-sim: one real-paced bot-only expedition (no shortcuts), with the clock read.
## Every squad is bots (the player's too, on autoplay); the match steps at the game's own rate to its end.
## Prints PACE lines for tools/pacing_report.py: landing, first damage, camp clears, level-ups, lair and
## Heart states, the tide radius, squads alive, hunters out and extracted. Reads the match, changes nothing.
## Run: godot --headless --path . -- --pacing-sim [--map=hollowcrown --teams=10 --squad=3 --seed=N]
## (those are the defaults)

const LOOK_S := 0.5          # s of match time between the slow probes (camps, lairs, squads alive)
const CAMP_SNAP_T := 3.0     # s: the camps are snapshotted once, before any Blight or lair add exists
const CAMP_R := 3.5          # m: a mob this close to a camp spot at the snapshot is in that camp (jitter 1.8 m)
const SNAP_EVERY_S := 30.0   # s between the squad level lines

var _m: Match
var _camps := {}             # camp key -> {mobs: Array[Mob], t: clear time or -1}
var _lair_state := {}
var _extracted := {}
var _dropping := {}          # nid -> was gliding down (landing is the first grounded step after that)
var _landed := {}
var _hit := {}
var _lvl := {}
var _alive_last := -1

func run(main: Node) -> void:
	var opts := {"autoplay": true, "sim_keep": true, "map": "hollowcrown", "teams": 10, "squad": 3, "seed": 1}
	for a in OS.get_cmdline_user_args():
		for k in ["map", "teams", "squad", "seed"]:
			if a.begins_with("--%s=" % k):
				var v := a.substr(k.length() + 3)
				opts[k] = v if k == "map" else int(v)
	_m = Match.new()
	main.add_child(_m)
	_m.start(opts)
	_m.set_process(false)
	var m := _m
	print("PACE start seed %d map %s teams %d hunters %d raid %s" % [
		m.seed_val, opts["map"], opts["teams"], m.hunters.size(), m.raid])
	var look := 0.0
	var snap := SNAP_EVERY_S
	while not m.over and m.time < m.length + 5.0:
		m.step(Match.DT)
		_fast()
		look += Match.DT
		if look >= LOOK_S:
			look = 0.0
			_slow()
		if m.time >= snap:
			snap += SNAP_EVERY_S
			_levels()
		if _alive_last == 0:
			break
	_levels()
	_end()
	main.get_tree().quit(0)

func _ev(kind: String, what: String) -> void:
	print("PACE ev %.2f %s %s" % [_m.time, kind, what])

## Every step: landings, the first damage each Hunter deals, level-ups, extractions.
func _fast() -> void:
	for h in _m.hunters:
		var id := String(h.nid)
		if h.dropping:
			_dropping[id] = true
		elif _dropping.has(id) and not _landed.has(id) and h.grounded:
			_landed[id] = _m.time
			_ev("land", "%s t%d" % [id, h.team])
		if not _hit.has(id) and h.dmg_done > 0.0:
			_hit[id] = _m.time
			_ev("hit", "%s t%d dmg %d" % [id, h.team, int(h.dmg_done)])
		if h.lvl != int(_lvl.get(id, 1)):
			_lvl[id] = h.lvl
			_ev("lvl", "%s t%d L%d" % [id, h.team, h.lvl])
		if h.extracted and not _extracted.has(id):
			_extracted[id] = _m.time
			_ev("extract", "%s t%d" % [id, h.team])

func _slow() -> void:
	if _camps.is_empty() and _m.time >= CAMP_SNAP_T:
		for c in _m.world.camp_spots:
			var p: Vector3 = c["pos"]
			var near := _m.mobs.filter(func(mb): return mb.flat_dist(p) <= CAMP_R)
			if not near.is_empty():
				var key := "%d,%d" % [int(p.x), int(p.z)]
				_camps[key] = {"mobs": near, "t": -1.0, "size": near.size(), "kind": String(c.get("kind", "normal"))}
		var n_mobs := 0
		for c in _camps.values():
			n_mobs += int(c["size"])
		_ev("camps", "%d groups, %d mobs" % [_camps.size(), n_mobs])
	for key in _camps:
		var c: Dictionary = _camps[key]
		if c["t"] < 0.0 and c["mobs"].all(func(mb): return not is_instance_valid(mb) or mb.dead):
			c["t"] = _m.time
			_ev("camp_clear", "%s size %d %s" % [key, c["size"], c["kind"]])
	for L in _m.lairs.list:
		var st := String(L["state"])
		if st != String(_lair_state.get(L["name"], "")):
			_lair_state[L["name"]] = st
			_ev("lair", "%s %s" % [L["name"], st])
	var teams := {}
	for h in _m.hunters:
		if not h.out and not h.extracted:
			teams[h.team] = true
	if teams.size() != _alive_last:
		_alive_last = teams.size()
		_ev("squads_alive", str(_alive_last))

## One line a snapshot: the tide radius and the mean level of every squad still in the match.
func _levels() -> void:
	var by := {}
	var alive := {}
	for h in _m.hunters:
		if not by.has(h.team):
			by[h.team] = []
		by[h.team].append(h.lvl)
		if not h.out and not h.extracted:
			alive[h.team] = true
	var means: Array = []
	for t in by:
		if alive.has(t):
			means.append("%.1f" % (float(by[t].reduce(func(a, b): return a + b, 0)) / by[t].size()))
	var down := _m.hunters.filter(func(h): return h.out).size()
	print("PACE snap %d tide %.0f levels %s out %d extracted %d" % [
		int(_m.time), Heart.tide_r(_m), ",".join(means), down, _extracted.size()])

func _end() -> void:
	var m := _m
	for line in m.heart.trail:
		print("PACE heart ", line)
	var sq: QuestSeats = m.exits.seats
	if sq:
		for line in sq.lair.trail:
			print("PACE seat_lair ", line)
		for line in sq.uplink.trail:
			print("PACE seat_uplink ", line)
	var kills := 0
	for line in m.feed_all:
		if line.contains(" knocked "):
			kills += 1
			if kills == 1:
				print("PACE first_knock ", line)
	var cleared := _camps.values().filter(func(c): return c["t"] >= 0.0).size()
	print("PACE end t %.1f result %s knocks %d camps_cleared %d/%d extracted %d" % [
		m.time, str(m.result), kills, cleared, _camps.size(), _extracted.size()])
