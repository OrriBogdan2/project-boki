extends RefCounted
## --garden-pace-check: how long until a Boki's first form (level 4) for a garden-only player
## (feed, pet, fetch, training yard: no runs) against one who also runs expeditions. The game must be
## playable without extraction (DECISIONS 2026-11-09), so the ratio has to stay under pace.max_ratio.
## A fixed-rate play model on the real Care / Game / Evo code; the assumptions are in garden_xp.json.
## Numbers: docs/GARDEN.md, Pace. Never touches the real save.

const FEED_S := 12.0              # s to walk up and feed
const PET_S := 8.0
const PET_GAP := 20.0             # s between pats that count (home.gd pet_ok)
const FETCH_S := 22.0
const DRILL_S := 45.0             # one training round of three marks
const SLEEP_S := 120.0            # s the kin naps when worn out
const DRILL_ROUNDS := 3
const GOAL_LEVEL := 4             # the first form (Evo.on_level)
const GIVE_UP_MIN := 24.0 * 60.0
const BREED_GIVE_UP_MIN := 7.0 * 24.0 * 60.0   # the breed table stops here and prints "never"
const XP_KEYS := ["feed", "feed_love", "pet", "pet_love", "fetch", "fetch_love", "drill_per_point"]

var bad := 0
var rng := RandomNumberGenerator.new()
var clock := 0.0                  # s of play so far; the trust cooldowns read it
var track_trust := false          # the breed table needs friends; the first-form numbers stay as measured

func ok(cond: bool, what: String) -> void:
	print("PACE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _kin(uid := "pace-a") -> Dictionary:
	var rec := Save.new_kin(Data.common_kin()[0], "Pace")
	rec["uid"] = uid       # the likes and hates hash from it, so the numbers repeat
	rec.erase("likes")
	rec["traits"] = {"bravery": 0.5, "temper": 0.5, "loyalty": 0.5, "curiosity": 0.5}
	Care.ensure(rec)
	return rec

## One garden activity for the kin, as a player would: feed when hungry, nap when worn out, keep it
## happy with a pat or a ball, otherwise drill. Returns the seconds it took.
func _garden_step(rec: Dictionary, since_pat: float) -> Dictionary:
	if Care.need(rec, "food") < 50.0:
		GardenXp.give(rec, "feed", false)
		if track_trust: Care.trust_up(rec, "food", clock, "kibble")
		Care.feed(rec, "kibble")
		return {"s": FEED_S, "pat": since_pat + FEED_S}
	if Care.need(rec, "energy") < 30.0:
		Care.tick(rec, SLEEP_S, true)
		return {"s": SLEEP_S, "pat": since_pat + SLEEP_S}
	if Care.need(rec, "joy") < 70.0:
		if since_pat >= PET_GAP:
			Care.change(rec, "joy", 5.0)
			GardenXp.give(rec, "pet", false)
			if track_trust: Care.trust_up(rec, "pet", clock)
			return {"s": PET_S, "pat": 0.0}
		Care.change(rec, "joy", 14.0)
		Care.change(rec, "energy", -6.0)
		Care.change(rec, "clean", -4.0)
		GardenXp.give(rec, "fetch", false)
		return {"s": FETCH_S, "pat": since_pat + FETCH_S}
	var pts := 0
	for _i in DRILL_ROUNDS: pts += [3, 3, 3, 2, 2, 0][rng.randi_range(0, 5)]
	Care.change(rec, "energy", -18.0)
	Care.change(rec, "food", -6.0)
	GardenXp.give(rec, "drill", false, pts)
	return {"s": DRILL_S, "pat": since_pat + DRILL_S}

## Garden play for up to `budget` seconds (or until the goal level). Returns the seconds used.
func _garden(rec: Dictionary, budget: float) -> float:
	var used := 0.0
	var pat := PET_GAP
	while used < budget and int(rec["level"]) < GOAL_LEVEL:
		var st := _garden_step(rec, pat)
		Care.tick(rec, float(st["s"]), false)
		used += float(st["s"])
		pat = float(st["pat"])
	return used

func _minutes_garden_only() -> float:
	var rec := _kin()
	return _garden(rec, GIVE_UP_MIN * 60.0) / 60.0

## Runs of run_min, each followed by home_gap_min of garden play; a win every 1/win_rate runs.
func _minutes_runner(pace: Dictionary) -> float:
	var rec := _kin()
	var t := 0.0
	var run_n := 0
	while int(rec["level"]) < GOAL_LEVEL and t < GIVE_UP_MIN:
		run_n += 1
		var won := floorf(run_n * float(pace["win_rate"])) > floorf((run_n - 1) * float(pace["win_rate"]))
		for nd in Care.MATCH_COST: Care.change(rec, nd, Care.MATCH_COST[nd])
		Game.add_xp(rec, 40 + (40 if won else 0) + int(float(pace["knocks"]) * 10.0), {})
		t += float(pace["run_min"])
		if int(rec["level"]) < GOAL_LEVEL: t += _garden(rec, float(pace["home_gap_min"]) * 60.0) / 60.0
	return t

## One garden step on `rec`, with the clock moved on. Returns the seconds it took.
func _garden_tick(rec: Dictionary, st: Dictionary) -> float:
	var s := float(st["s"])
	Care.tick(rec, s, false)
	clock += s
	return s

## Minutes to each breeding milestone (a key is missing when not reached in BREED_GIVE_UP_MIN) for a player
## who works the starter to `grown`, then the visitor, in sessions of an optional expedition + home_gap_min
## of garden. "second": the wild visitor's expected wait (check_s / chance) plus its favourite meals asked
## to stay, counted in garden seconds. "friends": the real NookRules.friends. "egg": both Grown and friends.
func _breed_ms(runner: bool, grown: int, pace: Dictionary) -> Dictionary:
	var vis: Dictionary = Content.rules("garden_visitor")
	var arrive := float(vis["check_s"]) / float(vis["chance"]) + float(vis["feeds"]) * FEED_S
	var a := _kin()
	var b := {}
	var ms := {}
	var home_s := 0.0
	var pat := PET_GAP
	var runs := 0
	clock = 0.0
	track_trust = true
	while clock < BREED_GIVE_UP_MIN * 60.0 and not ms.has("egg"):
		var tgt: Dictionary = a if int(a["level"]) < grown or b.is_empty() else b
		if runner:
			runs += 1
			var won := floorf(runs * float(pace["win_rate"])) > floorf((runs - 1) * float(pace["win_rate"]))
			for nd in Care.MATCH_COST: Care.change(tgt, nd, Care.MATCH_COST[nd])
			Game.add_xp(tgt, 40 + (40 if won else 0) + int(float(pace["knocks"]) * 10.0), {})
			clock += float(pace["run_min"]) * 60.0
		var chunk := 0.0
		while chunk < float(pace["home_gap_min"]) * 60.0:
			tgt = a if int(a["level"]) < grown or b.is_empty() else b
			var st := _garden_step(tgt, pat)
			pat = float(st["pat"])
			var s := _garden_tick(tgt, st)
			chunk += s
			home_s += s
			if b.is_empty() and home_s >= arrive:
				b = _kin("pace-b")
				b["trust"] = 50.0
				ms["second"] = clock / 60.0
			if not ms.has("grown") and int(a["level"]) >= grown: ms["grown"] = clock / 60.0
			if b.is_empty() or not NookRules.friends(a, b): continue
			if not ms.has("friends"): ms["friends"] = clock / 60.0
			if int(a["level"]) >= grown and int(b["level"]) >= grown: ms["egg"] = clock / 60.0
	track_trust = false
	return ms

func _fmt(ms: Dictionary, key: String) -> String:
	return "never" if not ms.has(key) else "%.0f" % float(ms[key])

## The table: per option (the shipped numbers, then each data-only option of garden_xp.json breed_options,
## which scales the care XP and moves the Grown level here and nowhere else), minutes to each milestone.
func _breed_table(pace: Dictionary) -> void:
	var r := GardenXp.rules()
	var saved: Dictionary = r.duplicate(true)
	var opts: Array = [{"id": "shipped", "xp_mult": 1.0, "grown_lv": NookRules.GROWN_LV}]
	opts.append_array(saved["breed_options"])
	print("PACE breed table, minutes (second Boki / Grown / friends / first egg)")
	for o in opts:
		for k in XP_KEYS: r[k] = int(round(float(saved[k]) * float(o["xp_mult"])))
		for runner in [false, true]:
			rng.seed = 4243
			seed(4243)
			var ms := _breed_ms(runner, int(o["grown_lv"]), pace)
			var who := "with 1 run a session" if runner else "garden-only"
			var row := "PACE breed %-14s Lv%-2d %-20s %5s %6s %6s %6s"
			var at := [_fmt(ms, "second"), _fmt(ms, "grown"), _fmt(ms, "friends"), _fmt(ms, "egg")]
			print(row % ([o["id"], o["grown_lv"], who] + at))
	for k in XP_KEYS: r[k] = saved[k]

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	rng.seed = 4242
	var pace: Dictionary = GardenXp.rules()["pace"]
	var garden := _minutes_garden_only()
	var runner := _minutes_runner(pace)
	var ratio := garden / maxf(runner, 0.001)
	var limit := float(pace["max_ratio"])
	var line := "PACE first form (level %d): garden-only %.0f min, with runs %.0f min, ratio %.2f"
	print(line % [GOAL_LEVEL, garden, runner, ratio])
	ok(garden < GIVE_UP_MIN, "garden-only reaches the first form at all (%.0f min)" % garden)
	ok(ratio <= limit, "garden-only is at most %.1fx slower (%.2fx)" % [limit, ratio])
	var rec := _kin()
	GardenXp.give(rec, "drill", false, 12)
	ok(int(rec["xp"]) > 0, "a farm action gives XP")
	_breed_table(pace)
	print("PACE CHECK DONE, failures: ", bad)
	m.get_tree().quit()
