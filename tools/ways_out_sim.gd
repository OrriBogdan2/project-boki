extends RefCounted
## --ways-out-sim: real-paced bot-only Limited Ways Out matches (briefs/specs/LIMITED_WAY_OUTS.md task 7),
## 10 squads of 3 on The Hollow Crown, one per seed, stepped at the game's own rate to the island fall.
## The player's squad plays on --autoplay and stands in for the human squad (no bot delay, no bot cap).
## Per match one "WAYS match" line: each seat's squad (and its plan) and the time it was taken, squads
## out, the human squad out or not, bot squads on early seats against the cap, the final (taken, or no
## winner: squads still in when the islands fell) and squads alive at each minute. Then "WAYS sum" over
## the run against the spec's gates (section 12): squads out at most 40%, each quest seat used in over
## 50% of matches, no-winner finals at most 5%. Reads the match, changes nothing; never touches the save.
## Run: godot --headless --path . -- --ways-out-sim [--seed=1 --runs=1 --map=hollowcrown]

const LOOK_S := 0.5          # s of match time between looks at the seats
const GATE_OUT := 0.40       # spec gate: share of squads out, at most
const GATE_SEAT := 0.50      # each quest seat used in more than this share of matches
const GATE_NOWIN := 0.05     # no-winner finals, at most this share of matches

var _rows: Array = []

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var opts := {"seed": 1, "runs": 1, "map": "hollowcrown"}
	for a in OS.get_cmdline_user_args():
		for k in opts:
			if a.begins_with("--%s=" % k):
				var v := a.substr(k.length() + 3)
				opts[k] = v if k == "map" else int(v)
	for i in int(opts["runs"]):
		_rows.append(_match(main, int(opts["seed"]) + i, String(opts["map"])))
	_sum()
	main.get_tree().quit(0)

func _match(main: Node, seed_v: int, map: String) -> Dictionary:
	var m := Match.new()
	main.add_child(m)
	m.start({"autoplay": true, "sim_keep": true, "map": map, "teams": 10, "squad": 3, "seed": seed_v})
	m.set_process(false)
	var row := {"seed": seed_v, "seats": {}, "alive": [], "final_open": -1.0, "final_alive": 0}
	var look := 0.0
	var minute := 0.0
	while not m.over and m.time < m.length + 5.0:
		m.step(Match.DT)
		look += Match.DT
		if look >= LOOK_S:
			look = 0.0
			_look(m, row)
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

func _yes(on: bool) -> String:
	return "yes" if on else "no"

func _pass(ok: bool) -> String:
	return "PASS" if ok else "MISS"

func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
