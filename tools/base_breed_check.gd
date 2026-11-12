extends RefCounted
## --base-breed-check: can a player who never goes on an expedition meet every breeding gate, in two play
## sessions or less (GARDEN.md section 6; DECISIONS 2026-11-09: playable without extraction)?
## A fresh base_mode save, one hatched starter, never a match (Save.d matches stays 0). Each gate prints
## "BREED gate <name>: <minutes>" on one play clock; a gate that needs loot, levels or gems only an expedition
## gives prints "BREED BLOCKED <gate>: <why> [<where>] fix: <one line>" and fails, and the run goes on with the
## missing piece handed over so one run lists every blocker. A gap that needs code, not data, is a
## "BREED OPEN" line (docs/DEBT.md) and a gate over the session limit a "BREED OVER" line: both are reported.
##   1. the buildings: the Nesting Nook (the gate itself) and the Training post (the yard's XP) open, in gems
##   2. a second Boki: the Shelter, the base-only way to a pair
##   3. both Grown: the pace model (garden_pace_check.gd) raises each to Grown on farm XP alone; failing only
##      when it is slower than pace.max_ratio against a Boki that also runs expeditions (the first-form rule)
##   4. friends: the two live on the real base (BaseLife) until NookRules.friends
##   5. the egg: laid, ready after its minutes at home, hatches; the baby knows its parents
## Gates 3 and 4 run side by side (the Boki live their days while you care for them), the egg follows both.
## Assumptions (play length) are the pace block of garden_xp.json. Never touches the real save.

const SIM_DT := 0.25            # s of farm time per home step while the Boki live their days
const SIM_FRAME := 400          # home steps between frames, so deferred frees and timers can run
const PET_STEP_S := 12.5        # s between two pets: one in-game hour, the trust cooldown (garden_trust.json)
const SETTLE_FRAMES := 600      # frames to wait at most for the home to finish building
const GIVE_UP_MIN := 24.0 * 60.0

var bad := 0
var main: Node
var home
var pip: Dictionary
var moss: Dictionary

func ok(cond: bool, what: String) -> void:
	print("BREED %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func blocked(gate: String, why: String, where: String, fix: String) -> void:
	print("BREED BLOCKED %s: %s [%s] fix: %s" % [gate, why, where, fix])
	bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(11)
	Save.d = Save.fresh()
	var grown := _raising_min()      # the pace model's own conditions, before the base is built
	FarmUnlocks.rules()["base_mode"] = true
	await _start()
	var limit := _limit_min()
	_buildings()
	_toy()
	_second_boki()
	pip["level"] = NookRules.GROWN_LV      # raised by the model above
	moss["level"] = NookRules.GROWN_LV
	var friends := await _friends_min(limit)
	var egg := _egg()
	var total := maxf(grown, friends) + egg
	print("BREED gate first egg laid: %.0f min; baby out: %.0f min (limit %.0f)" % [maxf(grown, friends), total, limit])
	_over("the baby", total, limit)
	ok(int(Save.d["matches"]) == 0, "no match was entered (matches %d)" % int(Save.d["matches"]))
	FarmUnlocks.rules()["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("BREED DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A gate that takes longer than the play sessions a base-only player is given is reported, not failed.
func _over(gate: String, minutes: float, limit: float) -> void:
	if minutes > limit:
		var sessions := minutes / float(GardenXp.rules()["pace"]["session_min"])
		print("BREED OVER %s: %.0f min, %.1f sessions (limit %.0f min)" % [gate, minutes, sessions, limit])

func _limit_min() -> float:
	var pace: Dictionary = GardenXp.rules()["pace"]
	return float(pace["session_min"]) * float(pace["base_sessions"])

## A fresh save on a farm-start island, tutorial skipped, one hatched starter.
func _start() -> void:
	var d := Save.fresh()
	HomeLayout.new_fs(d, 7)
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true, "match": true}
	pip = Save.new_kin("zapple", "Pip")
	pip["starter"] = true
	d["roster"].append(pip)
	d["active"] = pip["uid"]
	moss = Save.new_kin("burrlet", "Moss")      # the second Boki is in place before the base is built
	d["roster"].append(moss)
	for rec in [pip, moss]:
		rec["loose"] = {}      # docs/DEBT.md: Care.ensure writes the int GardenItems wants, StatBudget.add reads a dict
	Save.d = d
	Progress.add("hatched")
	home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	print("BREED gate hatch: 0 min (a starter, %d gems, farm level %d)" % [int(d["gems"]), FarmUnlocks.level()])

## Is this building open to a base-only player now, in gems and labour only? Blocks the gate when the farm
## says no, or wants wood, stone or fibre that no base-mode action produces.
func _open(id: String, gate: String) -> bool:
	var lock := FarmUnlocks.lock_text(id)
	if lock != "":
		blocked(gate, "%s is locked: \"%s\", and the farm level comes from extractions, bosses and scans" % [id, lock],
				"content/rules/farm_build.json unlock", "open it at the level a new base reaches")
		return false
	var short := FarmSites.short_of(FarmSites.build_cost(id))
	if short != "":
		var cost: Dictionary = FarmSites.build_cost(id)
		blocked(gate, "%s costs %d %s and base_mode has no way to get any" % [id, cost[short], short],
				"content/rules/farm_build.json build.%s" % id, "price it in gems")
		return false
	return true

## The first toy, which costs gems only: friends are made over a ball.
func _toy() -> void:
	var price: Array = HomeLayout.price("toy_ball")
	var gems_only: bool = int(price[2]) == 0 and int(price[3]) == 0 and int(price[0]) <= int(Save.d["gems"])
	ok(gems_only, "a toy costs %d of the %d gems you start with" % [price[0], int(Save.d["gems"])])
	home.hb._pay(int(price[0]), 0)
	var at: Dictionary = home.hg.demo_place("toy_ball", HomeLayout.LANDING + Vector3(-3.5, 0, -3.0))
	ok(not at.is_empty() and home.toys.toys().size() == 1, "the toy stands on the base")

func _buildings() -> void:
	_open("nesting_nook", "the Nesting Nook")
	_open("training_post", "the Training post (the yard's XP)")

## The base-only way to a second Boki is the Shelter, which a stall of tier 2 opens.
func _second_boki() -> void:
	if Stalls.level() < 2:
		var up := FarmSites.upgrade_cost("market_stall", 2)
		var line := "BREED OPEN a second Boki: the Shelter needs a tier 2 market stall (%d wood, %d stone, %d fibre)"
		print(line % [int(up["wood"]), int(up["stone"]), int(up["fibre"])] + "; docs/DEBT.md")

## Minutes to raise both Boki to Grown on farm XP alone (garden_pace_check's play model, one after the other).
func _raising_min() -> float:
	var pace = load("res://tools/garden_pace_check.gd").new()
	pace.goal = NookRules.GROWN_LV
	pace.rng.seed = 4242
	var one: float = pace.minutes_garden_only()
	pace.rng.seed = 4242
	var runner: float = pace.minutes_runner(GardenXp.rules()["pace"])
	print("BREED gate both Grown: %.0f min (%.0f each; a runner needs %.0f each)" % [one * 2.0, one, runner])
	_over("both Grown", one * 2.0, _limit_min())
	ok(one < GIVE_UP_MIN, "farm XP alone reaches Grown at all (%.0f min)" % one)
	var max_ratio := float(GardenXp.rules()["pace"]["max_ratio"])
	var ratio := one / runner
	ok(ratio <= max_ratio, "farm XP is at most %.1fx slower than runs to Grown (%.2fx)" % [max_ratio, ratio])
	return one * 2.0

## Farm minutes the two live and are petted each in-game hour until they are friends.
func _friends_min(limit: float) -> float:
	pip["bonds"][moss["uid"]] = 0.0      # they have met: friends now come from the bond, not the trust stand-in
	moss["bonds"][pip["uid"]] = 0.0
	var now := Time.get_unix_time_from_system()
	var next_pet := 0.0
	var t := 0.0
	var i := 0
	while not NookRules.friends(pip, moss) and t < limit * 60.0:
		t += SIM_DT
		home.day_t = fmod(home.day_t + SIM_DT / home.DAY_LEN, 1.0)
		home._move_kin(SIM_DT)
		home._care_tick(SIM_DT)
		if t >= next_pet:
			next_pet += PET_STEP_S
			Care.trust_up(pip, "pet", now + t)
			Care.trust_up(moss, "pet", now + t)
		i += 1
		if i % SIM_FRAME == 0:
			await main.get_tree().process_frame
	print("BREED gate friends: %.0f min (bond %.2f, trust %.0f/%.0f)"
			% [t / 60.0, BaseRace.bond(pip, moss), float(pip["trust"]), float(moss["trust"])])
	ok(NookRules.friends(pip, moss), "the two become friends on their own within the limit")
	return t / 60.0

## The egg: every other gate is met, it is laid, waits its minutes at home and hatches into a baby.
func _egg() -> float:
	ok(NookRules.pair_why(pip, moss) == "", "every Nook gate is met (%s)" % NookRules.pair_why(pip, moss))
	home._make_egg(pip, moss)
	ok(not Save.d["egg"].is_empty() and not home._egg_ready(), "an egg is laid and is not ready at once")
	var wait := (float(Save.d["egg"]["t"]) - Time.get_unix_time_from_system()) / 60.0
	Save.d["egg"]["t"] = Time.get_unix_time_from_system() - 1.0
	ok(home._egg_ready(), "the egg is ready after its %.0f minutes at home" % wait)
	var kin: int = Save.d["roster"].size()
	home._hatch_nest_egg()
	var born: bool = Save.d["roster"].size() == kin + 1 and int(Save.d["stats"].get("hatched", 0)) >= 1
	ok(born, "the egg hatches into a baby")
	ok(NookRules.can_pair(pip) != "", "a parent rests after laying (%s)" % NookRules.can_pair(pip))
	return wait
