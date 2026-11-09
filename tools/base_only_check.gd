extends RefCounted
## --base-only-check: can a player enjoy the game with no expedition at all (DECISIONS 2026-11-09, GARDEN.md)?
## A fresh base_mode save, the match tutorial skipped, never a match (Save.d matches stays 0). Every step plays the
## real rule code; a step that needs expedition loot (wood, stone, fibre, farm level from extractions, XP from a
## match) prints "BASEONLY BLOCKED <step>: <why> [<where>] fix: <one line>" and counts as a failure.
##   1. snacks: the patch is open, ripens, and each snack it grows feeds a Boki and builds its lean
##   2. toy: a toy is open, costs only gems you have, and stands on the base
##   3. the Dash and Stump Shove: the Training post that anchors them is buildable, then both run and pay out
##   4. gems: wins pay gems, and a Goal (the first hatch) can be claimed
##   5. the next stage: what the steps above gave the starter must reach Youngling
##   6. the Nook: built, both Grown, friends, rested; an egg is laid and hatches
## A blocked step keeps going with the missing piece handed over (named in the line), so one run lists them all.
## Never touches the real save.

const DAYS := 12                # farm days of play and care (home.DAY_LEN each) before the gates are judged
const DT := 1.0 / 30.0          # s per race step
const SIM_DT := 0.25            # s of farm time per home step while the Boki live their days
const SIM_FRAME := 400          # home steps between frames, so deferred frees and timers can run
const MAX_S := 120.0            # s: a race or bout that runs longer is stuck
const PET_STEP_S := 12.5        # s between two pets: one in-game hour, the trust cooldown (garden_trust.json)
const FEED_NEED := 20.0         # a hungry Boki, so any snack is welcome
const SETTLE_FRAMES := 600      # frames to wait at most for the home to finish building

var bad := 0
var main: Node
var home
var pip: Dictionary
var moss: Dictionary

func ok(cond: bool, what: String) -> void:
	print("BASEONLY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func blocked(step: String, why: String, where: String, fix: String) -> void:
	print("BASEONLY BLOCKED %s: %s [%s] fix: %s" % [step, why, where, fix])
	bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(11)
	FarmUnlocks.rules()["base_mode"] = true
	await _start()
	_snacks()
	await _toy()
	_minigames()
	_gems()
	_next_stage()
	await _nook()
	ok(int(Save.d["matches"]) == 0, "no match was entered (matches %d)" % int(Save.d["matches"]))
	FarmUnlocks.rules()["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("BASEONLY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A fresh save on a farm-start island, tutorial skipped, one hatched starter, the patch in storage.
func _start() -> void:
	var d := Save.fresh()
	HomeLayout.new_fs(d, 7)
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true, "match": true}
	pip = Save.new_kin("zapple", "Pip")
	pip["starter"] = true
	d["roster"].append(pip)
	d["active"] = pip["uid"]
	Save.d = d
	moss = _second_boki()
	SnackPatch.grant(d)
	home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	print("BASEONLY start: fresh save, %d gems, farm level %d, %d wood"
			% [int(d["gems"]), FarmUnlocks.level(), Work.mat("wood")])

## Can a base-only player build this now? Blocks the step and returns false when the farm says no, or wants
## materials (wood, stone, fibre) that no base-mode action produces.
func _buildable(id: String, step: String) -> bool:
	var lock := FarmUnlocks.lock_text(id)
	if lock != "":
		blocked(step, "%s is locked: \"%s\"; farm level comes from extractions, bosses and scans" % [id, lock],
				"content/rules/farm_build.json unlock + points", "make the base items open in base_mode")
		return false
	var cost := FarmSites.build_cost(id) if FarmSites.uses_site(id) else {}
	var short := FarmSites.short_of(cost)
	if short != "":
		blocked(step, "%s costs %d %s and base_mode has no way to get any" % [id, int(cost[short]), short],
				"content/rules/farm_build.json build.%s" % id, "price base-mode builds in gems only")
		return false
	return true

# ------------------------------------------------------------------ 1. snacks
func _snacks() -> void:
	ok(FarmUnlocks.open(SnackPatch.ID), "the snack patch is open to build")
	var e := {"id": SnackPatch.ID, "t": Time.get_unix_time_from_system() - float(SnackPatch.rules()["grow_secs"]) - 1.0}
	HomeLayout.of(Save.d)["deco"].append(e)
	var got := SnackPatch.harvest(Save.d, Time.get_unix_time_from_system())
	var snacks: Array = SnackPatch.rules()["snacks"]
	ok(got == snacks, "the ripe patch yields every snack it grows (%s)" % ", ".join(got))
	pip["likes"]["hates"] = "kibble"      # a taste, not a gate: no snack is its hated food
	for s in snacks:
		Care.change(pip, "food", -100.0)
		var fed := Care.feed(pip, s)
		var lean := String(fed.get("lean", ""))
		ok(bool(fed["ok"]) and lean != "" and float(pip["lean"].get(lean, 0.0)) > 0.0,
				"feeding %s works and leans it to %s" % [s, lean])
	HomeLayout.of(Save.d)["deco"].erase(e)

# ------------------------------------------------------------------ 2. toy
func _toy() -> void:
	var id := "toy_ball"
	var price: Array = HomeLayout.price(id)
	var gems_only: bool = int(price[2]) == 0 and int(price[3]) == 0 and int(price[0]) <= int(Save.d["gems"])
	var cost_ok := _buildable(id, "place a toy") and gems_only
	ok(cost_ok, "a %s costs %d gems of the %d you start with, and no materials" % [id, price[0], int(Save.d["gems"])])
	home.hb._pay(int(price[0]), 0)
	var at: Dictionary = home.hg.demo_place(id, HomeLayout.LANDING + Vector3(-3.5, 0, -3.0))
	ok(not at.is_empty() and home.toys.toys().size() == 1, "the toy stands on the base")
	await main.get_tree().process_frame

# ------------------------------------------------------------------ 3. minigames
func _minigames() -> void:
	_buildable("training_post", "the Dash and Stump Shove (they stand by the Training post)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var race := BaseRace.Run.new([pip, moss], 0, rng)
	var t := 0.0
	while not race.over() and t < MAX_S:
		race.step(DT)
		t += DT
	ok(race.over(), "the Dash finishes (%.0f s)" % t)
	if race.over():
		BaseRace.settle(race)
	var bout := BaseShove.Run.new([pip, moss], 0, rng)
	t = 0.0
	while not bout.over() and t < MAX_S:
		bout.step(DT)
		t += DT
	ok(bout.over(), "the Stump Shove ends (%.0f s)" % t)
	if bout.over():
		BaseShove.settle(bout)

## The base-only way to a second Boki is the Shelter, which a stall of tier 2 opens.
func _second_boki() -> Dictionary:
	if Stalls.level() < 2:
		var up := FarmSites.upgrade_cost("market_stall", 2)
		blocked("a second Boki", "the Shelter needs a tier 2 market stall (%d wood, %d stone, %d fibre)"
				% [int(up["wood"]), int(up["stone"]), int(up["fibre"])], "content/rules/farm_build.json upgrade.2",
				"open the Shelter in base_mode, or hand out a second hatchling")
	var rec := Save.new_kin("burrlet", "Moss")
	Save.d["roster"].append(rec)
	return rec

# ------------------------------------------------------------------ 4. gems
func _gems() -> void:
	var before := int(Save.d["gems"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var race := BaseRace.Run.new([pip, moss], 0, rng)
	while not race.over():
		race.step(DT)
	BaseRace.settle(race)
	ok(int(Save.d["gems"]) > before, "a Dash pays gems (%d -> %d)" % [before, int(Save.d["gems"])])
	var open_goals: Array = Progress.CHALLENGES.filter(func(c): return c[3] in ["hatched", "max_trust"])
	ok(open_goals.size() == 2, "two Goals (%s) need only the base" % ", ".join(open_goals.map(func(c): return c[1])))

# ------------------------------------------------------------------ 6. the Nook and an egg
func _nook() -> void:
	_buildable("nesting_nook", "the Nesting Nook")
	await _make_friends()
	for rec in [pip, moss]:
		var gate := NookRules.can_pair(rec)
		if int(rec["level"]) < NookRules.GROWN_LV:
			var why := "%s is level %d of the %d a Grown Boki needs; only a finished match gives XP"
			blocked("both Grown", why % [rec["name"], int(rec["level"]), NookRules.GROWN_LV],
					"scripts/core/game.gd:347", "give Dash wins, toy sessions and snacks a little XP")
			rec["level"] = NookRules.GROWN_LV
		elif gate != "":
			ok(false, "%s: %s" % [rec["name"], gate])
	ok(NookRules.friends(pip, moss), "friends after %d farm days of play and care (bond %.2f, trust %.0f/%.0f)"
			% [DAYS, BaseRace.bond(pip, moss), float(pip["trust"]), float(moss["trust"])])
	ok(NookRules.pair_why(pip, moss) == "", "every Nook gate is met (%s)" % NookRules.pair_why(pip, moss))
	home._make_egg(pip, moss)
	ok(not Save.d["egg"].is_empty() and not home._egg_ready(), "an egg is laid and is not ready at once")
	Save.d["egg"]["t"] = Time.get_unix_time_from_system() - 1.0      # the 10 minutes at home (home.gd _make_egg)
	ok(home._egg_ready(), "the egg is ready after its 10 minutes at home")
	var kin: int = Save.d["roster"].size()
	home._hatch_nest_egg()
	var hatched: int = Save.d["stats"].get("hatched", 0)
	ok(Save.d["roster"].size() == kin + 1 and hatched == 1, "the egg hatches into a new Boki")
	var gems := int(Save.d["gems"])
	ok(Progress.claim("hatch1") > 0 and int(Save.d["gems"]) > gems, "the hatch Goal pays gems")

## DAYS farm days at home: the two Boki live on their own (play, nap, greet) and are petted each in-game hour.
## Friends come from living together; a Dash only moves a bond by its own rules.
func _make_friends() -> void:
	var now := Time.get_unix_time_from_system()
	var next_pet := 0.0
	var t := 0.0
	for i in int(DAYS * home.DAY_LEN / SIM_DT):
		t += SIM_DT
		home.day_t = fmod(home.day_t + SIM_DT / home.DAY_LEN, 1.0)
		home._move_kin(SIM_DT)
		home._care_tick(SIM_DT)
		if t >= next_pet:
			next_pet += PET_STEP_S
			Care.trust_up(pip, "pet", now + t)
			Care.trust_up(moss, "pet", now + t)
		if i % SIM_FRAME == 0:
			await main.get_tree().process_frame

# ------------------------------------------------------------------ 5. the next stage
func _next_stage() -> void:
	var next_lv: int = Care.STAGES[1][0]
	if int(pip["level"]) < next_lv:
		var why := "%s is still a %s (level %d, xp %d): no base action gave it any XP"
		blocked("next Boki stage", why % [pip["name"], Care.stage_name(pip), int(pip["level"]), int(pip["xp"])],
				"scripts/core/game.gd:347", "give Dash wins, toy sessions and snacks a little XP")
