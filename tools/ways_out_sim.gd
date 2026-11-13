extends RefCounted
## --ways-out-sim: real-paced bot-only Limited Ways Out matches (briefs/specs/LIMITED_WAY_OUTS.md task 7),
## 10 squads of 3 on The Hollow Crown, one per seed, stepped at the game's own rate to the island fall.
## The player's squad plays on --autoplay and stands in for the human squad (no bot delay, no bot cap).
## Per match one "WAYS match" line: each seat's squad (and its plan) and the time it was taken, squads
## out, the human squad out or not, bot squads on early seats against the cap, the final (taken, or no
## winner: squads still in when the islands fell) and squads alive at each minute. Then "WAYS sum" over
## the run against the spec's gates (section 12): squads out at most 40%, each quest seat used in over
## 50% of matches, no-winner finals at most 5%. A "WAYS end" line per match reads the final (0051 "The
## end phase"): squads in at 10:00, when it was settled (one squad left or the final seat taken), the
## longest stretch two squads stood apart, and Blight downs (the tide or a Blight mob) in the final, apart
## those of a Hunter who stood in the safe ring CATCH_S before while the final was still being fought.
## Its sum: settled within RESOLVE_S of 10:00 in GATE_RESOLVE of matches, and none of those downs.
## Reads the match, changes nothing; never touches the save. --final=N plays the end alone: N squads land,
## then the clock jumps to FINAL_LEAD_S before the final opens and each squad is set down inside the ring.
## Run: godot --headless --path . -- --ways-out-sim [--seed=1 --runs=1 --map=hollowcrown --final=0]

const LOOK_S := 0.5          # s of match time between looks at the seats
const GATE_OUT := 0.40       # spec gate: share of squads out, at most
const GATE_SEAT := 0.50      # each quest seat used in more than this share of matches
const GATE_NOWIN := 0.05     # no-winner finals, at most this share of matches
const RESOLVE_S := 90.0      # s after the final opens (10:00) by which it should be settled...
const GATE_RESOLVE := 0.9    # ...in at least this share of matches
const HIDE_M := 20.0         # m: no two Hunters of rival squads this close means the squads stand apart
const HIDE_S := 30.0         # s apart in a row in the final counts as hiding
const CATCH_S := 5.0         # s: a Blight down of one who stood inside the ring this recently is one in the safe ring
const FINAL_LEAD_S := 90.0   # --final: s before the final opens the clock jumps to
const FINAL_IN := 0.6        # --final: each squad is set down this far out to the ring

var _rows: Array = []
var _gone := {}              # nid -> true while down or out (each down counts once)
var _in_t := {}              # nid -> session time the Hunter last stood inside the tide ring

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var opts := {"seed": 1, "runs": 1, "map": "hollowcrown", "final": 0}
	for a in OS.get_cmdline_user_args():
		for k in opts:
			if a.begins_with("--%s=" % k):
				var v := a.substr(k.length() + 3)
				opts[k] = v if k == "map" else int(v)
	for i in int(opts["runs"]):
		_rows.append(_match(main, int(opts["seed"]) + i, String(opts["map"]), int(opts["final"])))
	_sum()
	main.get_tree().quit(0)

func _match(main: Node, seed_v: int, map: String, final_n: int) -> Dictionary:
	var m := Match.new()
	main.add_child(m)
	var teams := final_n if final_n > 0 else 10
	m.start({"autoplay": true, "sim_keep": true, "map": map, "teams": teams, "squad": 3, "seed": seed_v})
	m.set_process(false)
	var row := {"seed": seed_v, "seats": {}, "alive": [], "final_open": -1.0, "final_alive": 0,
		"settle": -1.0, "apart": 0.0, "apart_run": 0.0, "bl_downs": 0, "bl_zone": 0}
	_gone.clear()
	_in_t.clear()
	var look := 0.0
	var minute := 0.0
	var jump := final_n > 0
	while not m.over and m.time < m.length + 5.0:
		m.step(Match.DT)
		if jump and m.hunters.all(func(h): return not (h.dropping or h.riding)):
			jump = false
			_to_final(m)
		_downs(m, row)
		look += Match.DT
		if look >= LOOK_S:
			look = 0.0
			_look(m, row)
			_final_look(m, row)
		if m.time >= minute:
			minute += 60.0
			row["alive"].append(_alive(m))
		if _alive(m) == 0:
			break
	_look(m, row)
	var out := {}
	for h in m.hunters:
		if h.extracted:
			out[h.team] = true
	row["out"] = out.size()
	row["human_out"] = out.has(m.player.team)
	row["cap"] = BotWays.cap(m)
	var by_bots := func(k): return row["seats"].has(k) and BotWays.bot_squad(m, int(row["seats"][k][0]))
	row["bot_early"] = ["lair", "spark", "uplink"].filter(by_bots).size()
	var opened: bool = float(row["final_open"]) >= 0.0
	row["nowin"] = opened and not row["seats"].has("final") and int(row.get("alive_end", 0)) > 0
	_print(m, row)
	_print_end(row)
	m.queue_free()
	return row

## Who took which seat and when; the final opening and how many squads were in when it did.
func _look(m: Match, row: Dictionary) -> void:
	var t := m.sess_time()
	var sq: QuestSeats = m.exits.seats
	var taken := {"lair": sq.lair.team if sq.lair and sq.lair.out else -1, "spark": m.heart.early_team,
		"uplink": sq.uplink.team if sq.uplink and sq.uplink.state == QuestSeat.S.TAKEN else -1,
		"final": m.heart.final_team if m.heart.state == Heart.S.DONE else -1}
	for k in taken:
		if int(taken[k]) >= 0 and not row["seats"].has(k):
			row["seats"][k] = [int(taken[k]), t, BotWays.plan(m, int(taken[k]))]
	if m.time < m.length:
		row["alive_end"] = _alive(m)
	if float(row["final_open"]) < 0.0 and m.heart.state >= Heart.S.FINAL:
		row["final_open"] = t
		row["final_alive"] = _alive(m)

## --final: the clock to FINAL_LEAD_S before the final opens, each squad on ground inside the ring on its side.
func _to_final(m: Match) -> void:
	m.time = Heart.r("final_s") - FINAL_LEAD_S - m.sess_t0
	var order: Array = []
	for h in m.hunters:
		if not order.has(h.team):
			order.append(h.team)
	var out := Heart.tide_r(m) * FINAL_IN
	var taken: Array = []
	for h in m.hunters:
		var a := TAU * order.find(h.team) / order.size()
		var p := m.world.free_spot_near(m.heart.site + Vector3(cos(a), 0.0, sin(a)) * out, taken, 1.0, 0.45, out)
		taken.append(p)
		h.teleport(p)

## Every step: each new down (or an out with no down first) in the final, Blight ones counted. The tide
## leaves no attacker (Ent.hurt sets last_hit_by null) and hurts only outside the ring.
func _downs(m: Match, row: Dictionary) -> void:
	var t := m.sess_time()
	var tr := Heart.tide_r(m)
	for h in m.hunters:
		var id := String(h.nid)
		var d: float = h.flat_dist(m.heart.site)
		if not (h.downed or h.out):
			_gone.erase(id)
			if tr <= 0.0 or d <= tr:
				_in_t[id] = t
			continue
		if _gone.has(id) or h.extracted:
			continue
		_gone[id] = true
		if t < Heart.r("final_s") or m.time >= m.length:
			continue
		var by: Variant = h.last_hit_by
		var mob := is_instance_valid(by) and by is Blight
		if mob or (by == null and tr > 0.0 and d > tr):
			row["bl_downs"] += 1
			var in_fight := t - float(_in_t.get(id, -INF)) <= CATCH_S and float(row["settle"]) < 0.0
			var note := ""
			if in_fight:
				row["bl_zone"] += 1
				note = " (in the safe ring, final on)"
			print("WAYS blight_down seed %d %s t%d by %s at %.0f m, ring %.0f m%s" % [row["seed"], _clock(t), h.team,
				"mob" if mob else "tide", d, tr, note])

## The final: when it was settled (one squad left or the seat taken, never the islands' fall) and how long
## the squads still in stood apart.
func _final_look(m: Match, row: Dictionary) -> void:
	var t := m.sess_time()
	if float(row["settle"]) < 0.0 and m.time < m.length and (_alive(m) <= 1 or row["seats"].has("final")):
		row["settle"] = t
	if t < Heart.r("final_s") or float(row["settle"]) >= 0.0 or m.time >= m.length:
		return
	if _nearest_rivals(m) > HIDE_M:
		row["apart_run"] += LOOK_S
		row["apart"] = maxf(row["apart"], row["apart_run"])
	else:
		row["apart_run"] = 0.0

## Metres between the nearest two Hunters of different squads still in (INF with fewer than two squads).
func _nearest_rivals(m: Match) -> float:
	var best := INF
	for a in m.hunters:
		if a.out or a.extracted:
			continue
		for b in m.hunters:
			if b.team != a.team and not b.out and not b.extracted:
				best = minf(best, a.flat_dist(b))
	return best

## Seconds from the final opening (10:00) to it being settled: 0 when settled before, INF on a timeout.
static func settle_after(row: Dictionary) -> float:
	if float(row["settle"]) < 0.0:
		return INF
	return maxf(0.0, float(row["settle"]) - Heart.r("final_s"))

func _alive(m: Match) -> int:
	var teams := {}
	for h in m.hunters:
		if not h.out and not h.extracted:
			teams[h.team] = true
	return teams.size()

func _print(m: Match, row: Dictionary) -> void:
	var seats := []
	for k in ["lair", "spark", "uplink", "final"]:
		var s: Array = row["seats"].get(k, [])
		seats.append("%s=%s" % [k, "-" if s.is_empty() else "t%d(%s)@%s" % [s[0], s[2], _clock(s[1])]])
	var fin := "none"
	if float(row["final_open"]) >= 0.0:
		fin = "%s with %d" % [_clock(row["final_open"]), row["final_alive"]]
	var alive := ",".join(row["alive"].map(func(x): return str(x)))
	print("WAYS match seed %d end %s %s out %d/10 human_out %s bot_early %d/%d final_open %s nowin %s" % [
		row["seed"], _clock(m.sess_time()), " ".join(seats), row["out"], _yes(row["human_out"]),
		row["bot_early"], row["cap"], fin, _yes(row["nowin"])], " tries %s alive/min %s" % [_tries(m), alive])

func _print_end(row: Dictionary) -> void:
	var after := settle_after(row)
	print("WAYS end seed %d at_final %d settled %s apart_max %ds blight_downs %d in_ring_fighting %d" % [
		row["seed"], row["final_alive"], "timeout" if after == INF else "+%ds" % int(after), int(row["apart"]),
		row["bl_downs"], row["bl_zone"]])

## How often each early seat was started at all: a squad sealed in the lair, the spark picked up, the uplink
## started ("lair/spark/uplink").
func _tries(m: Match) -> String:
	var sq: QuestSeats = m.exits.seats
	var n := func(trail: Array, edge: String) -> int:
		return trail.filter(func(x): return String(x).contains(edge)).size()
	var lair: int = n.call(sq.lair.trail, ">IN_USE") if sq.lair else 0
	var up: int = n.call(sq.uplink.trail, ">IN_USE") if sq.uplink else 0
	return "%d/%d/%d" % [lair, n.call(m.heart.trail, ">CARRIED"), up]

func _sum() -> void:
	var n := float(_rows.size())
	var share := func(f: Callable) -> float: return _rows.filter(f).size() / n
	var out: float = _rows.reduce(func(a, r): return a + int(r["out"]), 0) / (n * 10.0)
	var used := {}
	for k in ["lair", "spark", "uplink", "final"]:
		used[k] = share.call(func(r): return r["seats"].has(k))
	var quest_ok: bool = used["lair"] > GATE_SEAT and used["uplink"] > GATE_SEAT
	var nowin: float = share.call(func(r): return r["nowin"])
	var seats: float = _rows.reduce(func(a, r): return a + r["seats"].size(), 0) / n
	var out_ok := _pass(out <= GATE_OUT)
	print("WAYS sum runs %d squads_out %.1f%% (gate <= %d%%: %s)" % [n, out * 100.0, GATE_OUT * 100, out_ok])
	print("WAYS sum nowin %.0f%% (gate <= %d%%: %s)" % [nowin * 100.0, GATE_NOWIN * 100, _pass(nowin <= GATE_NOWIN)])
	print("WAYS sum used lair %.0f%% spark %.0f%% uplink %.0f%% final %.0f%% (quest > %d%%: %s) per match %.2f" % [
		used["lair"] * 100.0, used["spark"] * 100.0, used["uplink"] * 100.0, used["final"] * 100.0,
		GATE_SEAT * 100, _pass(quest_ok), seats])
	print("WAYS sum human_out %.0f%%" % (share.call(func(r): return r["human_out"]) * 100.0))
	var fights := _rows.filter(func(r): return int(r["final_alive"]) >= 2).size()
	var settled: float = share.call(func(r): return settle_after(r) <= RESOLVE_S)
	var timeouts: int = _rows.filter(func(r): return settle_after(r) == INF).size()
	var apart: int = _rows.filter(func(r): return float(r["apart"]) >= HIDE_S).size()
	var zone: int = _rows.reduce(func(a, r): return a + int(r["bl_zone"]), 0)
	print("WAYS sum end settled <= %ds %.0f%% (gate >= %d%%: %s) finals with 2+ squads %d timeouts %d apart %d" % [
		RESOLVE_S, settled * 100.0, GATE_RESOLVE * 100, _pass(settled >= GATE_RESOLVE), fights, timeouts, apart],
		" blight downs in the safe ring while the final is fought %d (gate 0: %s)" % [zone, _pass(zone == 0)])

func _yes(on: bool) -> String:
	return "yes" if on else "no"

func _pass(ok: bool) -> String:
	return "PASS" if ok else "MISS"

func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
