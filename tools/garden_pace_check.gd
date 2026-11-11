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
const FIRST_FORM := 4             # the first form (Evo.on_level)
const GIVE_UP_MIN := 24.0 * 60.0

var bad := 0
var goal := FIRST_FORM            # the level the kin is raised to (--base-breed-check sets Grown)
var rng := RandomNumberGenerator.new()

func ok(cond: bool, what: String) -> void:
	print("PACE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _kin() -> Dictionary:
	var rec := Save.new_kin(Data.common_kin()[0], "Pace")
	rec["traits"] = {"bravery": 0.5, "temper": 0.5, "loyalty": 0.5, "curiosity": 0.5}
	Care.ensure(rec)
	return rec

## One garden activity for the kin, as a player would: feed when hungry, nap when worn out, keep it
## happy with a pat or a ball, otherwise drill. Returns the seconds it took.
func _garden_step(rec: Dictionary, since_pat: float) -> Dictionary:
	if Care.need(rec, "food") < 50.0:
		GardenXp.give(rec, "feed", false)
		Care.feed(rec, "kibble")
		return {"s": FEED_S, "pat": since_pat + FEED_S}
	if Care.need(rec, "energy") < 30.0:
		Care.tick(rec, SLEEP_S, true)
		return {"s": SLEEP_S, "pat": since_pat + SLEEP_S}
	if Care.need(rec, "joy") < 70.0:
		if since_pat >= PET_GAP:
			Care.change(rec, "joy", 5.0)
			GardenXp.give(rec, "pet", false)
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
	while used < budget and int(rec["level"]) < goal:
		var st := _garden_step(rec, pat)
		Care.tick(rec, float(st["s"]), false)
		used += float(st["s"])
		pat = float(st["pat"])
	return used

func minutes_garden_only() -> float:
	var rec := _kin()
	return _garden(rec, GIVE_UP_MIN * 60.0) / 60.0

## Runs of run_min, each followed by home_gap_min of garden play; a win every 1/win_rate runs.
func minutes_runner(pace: Dictionary) -> float:
	var rec := _kin()
	var t := 0.0
	var run_n := 0
	while int(rec["level"]) < goal and t < GIVE_UP_MIN:
		run_n += 1
		var won := floorf(run_n * float(pace["win_rate"])) > floorf((run_n - 1) * float(pace["win_rate"]))
		for nd in Care.MATCH_COST: Care.change(rec, nd, Care.MATCH_COST[nd])
		Game.add_xp(rec, 40 + (40 if won else 0) + int(float(pace["knocks"]) * 10.0), {})
		t += float(pace["run_min"])
		if int(rec["level"]) < goal: t += _garden(rec, float(pace["home_gap_min"]) * 60.0) / 60.0
	return t

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	rng.seed = 4242
	var pace: Dictionary = GardenXp.rules()["pace"]
	var garden := minutes_garden_only()
	var runner := minutes_runner(pace)
	var ratio := garden / maxf(runner, 0.001)
	var limit := float(pace["max_ratio"])
	var line := "PACE first form (level %d): garden-only %.0f min, with runs %.0f min, ratio %.2f"
	print(line % [goal, garden, runner, ratio])
	ok(garden < GIVE_UP_MIN, "garden-only reaches the first form at all (%.0f min)" % garden)
	ok(ratio <= limit, "garden-only is at most %.1fx slower (%.2fx)" % [limit, ratio])
	var rec := _kin()
	GardenXp.give(rec, "drill", false, 12)
	ok(int(rec["xp"]) > 0, "a farm action gives XP")
	print("PACE CHECK DONE, failures: ", bad)
	m.get_tree().quit()
