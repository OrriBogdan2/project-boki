extends RefCounted
## --race-check: the Dash (scripts/home/base_race.gd). 20 headless races of 3 Boki with mixed stats,
## leans and moods: the favourite (lowest expected lap time) wins at least 60%. Also: a lean speeds
## up its own stretch only, mood matters, good cheers beat missed ones, and settling a race moves
## joy, trust, gems, memories and (where a record has them) bonds. The save's first race has a double-wide
## first window and Great / Early / Late words; after it the Dash is normal. Never touches the real save.

const RACES := 20
const FAVOURITE_MIN := 0.6      # share of races the favourite must win

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("RACE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _boki(sps: Array, rng: RandomNumberGenerator, i: int) -> Dictionary:
	var rec := Save.new_kin(String(sps[rng.randi() % sps.size()]), "Runner%d" % i)
	Care.ensure(rec)
	for s in Care.STATS:
		rec["stats"][s] = rng.randi_range(0, 40)
	rec["needs"]["joy"] = rng.randf_range(20.0, 100.0)
	rec["bonds"] = {}
	return rec

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var sps: Array = Data.common_kin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	# ---------------------------------------------------------------- 1. the favourite usually wins
	var fav_wins := 0
	for i in RACES:
		var recs: Array = [_boki(sps, rng, 0), _boki(sps, rng, 1), _boki(sps, rng, 2)]
		var fav: Dictionary = recs[0]
		for r in recs:
			if BaseRace.expected_time(r) < BaseRace.expected_time(fav): fav = r
		var rn := BaseRace.sim(recs, 100 + i)
		if rn["order"][0] == fav: fav_wins += 1
	ok(fav_wins >= int(ceil(RACES * FAVOURITE_MIN)), "the favourite wins %d of %d races" % [fav_wins, RACES])
	# ---------------------------------------------------------------- 2. lean, mood
	var water := {}
	var straight := {}
	for s in BaseRace.course():
		if s["id"] == "water": water = s
		if s["id"] == "straight": straight = s
	var plain := _boki(sps, rng, 3)
	plain["lean"] = {"stone": 1.0}
	var swimmer: Dictionary = plain.duplicate(true)
	swimmer["lean"] = {"frost": 1.0}
	var edge := BaseRace.pace(swimmer, water) / BaseRace.pace(plain, water)
	var want := 1.0 + float(BaseRace.rules()["lean_edge"])
	ok(absf(edge - want) < 0.001, "a Frost lean swims the pond faster (x%.2f)" % edge)
	var same := is_equal_approx(BaseRace.pace(swimmer, straight), BaseRace.pace(plain, straight))
	ok(same, "and runs the straight the same")
	var glum: Dictionary = plain.duplicate(true)
	glum["needs"] = {"food": 10.0, "energy": 10.0, "joy": 10.0, "clean": 10.0}
	ok(BaseRace.expected_time(glum) > BaseRace.expected_time(plain), "a glum Boki runs slower")
	# ---------------------------------------------------------------- 3. cheers
	var a := _boki(sps, rng, 4)
	var b := _boki(sps, rng, 5)
	var great := BaseRace.sim([a, b], 7, ["great", "great", "great"])
	var miss := BaseRace.sim([a, b], 7, ["miss", "miss", "miss"])
	var t_great := float(great["runners"][0]["done"])
	var t_miss := float(miss["runners"][0]["done"])
	ok(t_great < t_miss, "three great cheers finish sooner than three misses (%.2f s vs %.2f s)" % [t_great, t_miss])
	# ---------------------------------------------------------------- 4. the payout
	var c := _boki(sps, rng, 6)
	var e := _boki(sps, rng, 7)
	var f := _boki(sps, rng, 8)
	f.erase("bonds")
	for r in [c, e, f]:
		r["needs"]["joy"] = 50.0
		r["trust"] = 40.0
	var rn2 := BaseRace.sim([c, e, f], 11)
	var gems0 := int(Save.d["gems"])
	var res := BaseRace.settle(rn2)
	var win: Dictionary = res["order"][0]
	var lose: Dictionary = res["order"][2]
	ok(Care.need(win, "joy") > 50.0 and Care.need(lose, "joy") < 50.0, "the winner is happier, the last one sulks")
	ok(float(win["trust"]) > 40.0 and is_equal_approx(float(lose["trust"]), 40.0), "winning raises trust")
	var gained := int(Save.d["gems"]) - gems0
	ok(gained > 0 and gained == int(res["gems"]), "you get a few gems (+%d)" % gained)
	ok(String(lose["memory"][-1]["text"]).contains(String(win["name"])), "the loser remembers who beat it")
	var bonded: Array = [c, e].filter(func(r): return r != win)
	var rival: Dictionary = bonded[0]
	ok(float(rival["bonds"].get(win["uid"], 0.0)) < 0.0, "a loser with bonds leans rival toward the winner")
	ok(not f.has("bonds"), "a record without bonds isn't given any")
	ok(String(res["memory"]) != "", "the card has a memory line: %s" % res["memory"])
	# ---------------------------------------------------------------- 5. the first race
	Save.d["tutorial"].erase(BaseRace.RACED)
	ok(BaseRace.first_race(), "a fresh save's next Dash is its first")
	var first := BaseRace.new_run([a, b], 5)
	ok(first["first"], "the run is marked first")
	first["mark"] = 1
	var wide := BaseRace.window_scale(first)
	ok(is_equal_approx(wide, 2.0), "the first mark's window is twice as wide (x%.1f)" % wide)
	first["mark"] = 2
	ok(is_equal_approx(BaseRace.window_scale(first), 1.0), "the second mark is the normal window")
	var bar := {"m": 0.5 + TimingDrill.GREAT * 1.5, "dir": 1.0, "speed": 1.1, "zone": 0.5}
	ok(TimingDrill.grade(bar) == "good", "off by 1.5 greats is only good on a normal bar")
	bar["wide"] = wide
	ok(TimingDrill.grade(bar) == "great", "the same press is great on the wide first bar")
	ok(TimingDrill.verdict(bar) == "Great", "and the word is Great")
	bar["wide"] = 1.0
	ok(TimingDrill.verdict(bar) == "Late", "past the gold while moving on is Late")
	bar["m"] = 0.5 - TimingDrill.GREAT * 1.5
	ok(TimingDrill.verdict(bar) == "Early", "before the gold is Early")
	bar["dir"] = -1.0
	ok(TimingDrill.verdict(bar) == "Late", "on the way back it flips: the same spot is Late")
	var sim1 := BaseRace.sim([a, b], 5)
	BaseRace.settle(sim1)
	ok(not BaseRace.first_race(), "after a race is settled the next one is the normal game")
	var again := BaseRace.new_run([a, b], 6)
	again["mark"] = 1
	ok(not again["first"] and is_equal_approx(BaseRace.window_scale(again), 1.0), "and its first window is normal")
	print("RACE CHECK DONE, failures: ", bad)
	m.get_tree().quit(1 if bad > 0 else 0)
