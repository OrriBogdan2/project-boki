extends RefCounted
## --race-cup-check: the Grand Dash (scripts/home/base_race_cup.gd, docs/GARDEN_GAMES.md). Headless:
##   1. bots fill the lanes to four, the Run is three laps and lasts 45 to 100 s
##   2. the cheer button boosts your Boki, then waits its cooldown (a press inside it does nothing)
##   3. a boosted run beats the same seeded run without presses
##   4. a finished run pays out: gems by place, energy spent, the Dash prize round logged
##   5. on the base: with one rested Boki the post starts a Grand Dash, it ends and frees the bots
## Never touches the real save.

const DT := 1.0 / 30.0
const MAX_S := 150.0
const SETTLE_FRAMES := 600

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("RACECUP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_headless()
	await _on_base()
	print("RACECUP DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin() -> Dictionary:
	var k := Save.new_kin("zapple", "Pip")
	k["level"] = 5
	Care.ensure(k)
	k["stats"]["speed"] = 10
	k["needs"]["joy"] = 60.0
	k["needs"]["energy"] = 90.0
	return k

func _lap(recs: Array, presses: bool, seed_v: int) -> BaseRace.Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var r := BaseRace.Run.new(recs, 0, rng, {}, int(BaseRaceCup.rules()["laps"]))
	while not r.over() and r.t < MAX_S:
		if presses and r.can_boost():
			r.boost()
		r.step(DT)
	return r

func _headless() -> void:
	var mine := _kin()
	var recs: Array = [mine]
	recs.append_array(BaseRaceCup.bots(mine))
	ok(recs.size() == 4, "bots fill the empty lanes up to four")
	var plain := _lap(recs, false, 5)
	var fin: float = plain.done_t[0]
	var slowest := float(plain.done_t.max())
	var lasts := "a cup run of %d laps lasts %.0f s" % [plain.laps, slowest]
	ok(plain.over() and slowest >= 45.0 and slowest <= 100.0, lasts)
	var boosted := _lap(recs, true, 5)
	var sooner := "the cheer button gets home sooner (%.1f vs %.1f s)" % [boosted.done_t[0], fin]
	ok(float(boosted.done_t[0]) < fin, sooner)
	var rng := RandomNumberGenerator.new()
	var r := BaseRace.Run.new(recs, 0, rng, {}, 3)
	r.boost()
	ok(not r.can_boost(), "the cheer button waits its cooldown")
	r.step(float(BaseRaceCup.rules()["cooldown_s"]) + 0.1)
	ok(r.can_boost(), "and works again after it")
	var gems := int(Save.d["gems"])
	var energy := Care.need(mine, "energy")
	var res := BaseRaceCup.settle(boosted)
	var paid := int(BaseRaceCup.rules()["gems"][res["place"]])
	ok(int(Save.d["gems"]) == gems + paid, "gems are paid by place (+%d)" % paid)
	ok(Care.need(mine, "energy") < energy, "the race costs energy")
	ok(res["prize"]["game"] == "dash", "the Dash prize round is rolled")

func _on_base() -> void:
	var d := Save.fresh()
	var k := _kin()
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "first_race": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	var race: BaseRace = home.hrace
	for e in home.kins:
		e.erase("indoors")
	race.use()
	var lanes: bool = race.run != null and race.run.laps == 3 and race.runners.size() == 4
	ok(lanes, "on: one rested Boki starts a 4-lane Grand Dash")
	var gems := int(Save.d["gems"])
	var guard := 0
	while race.run != null and guard < 6000:
		if race.run.can_boost():
			race.run.boost()
		race.tick(1.0 / 30.0)
		guard += 1
	var got := int(Save.d["gems"]) - gems
	ok(race.run == null and got > 0, "on: it finishes and pays gems (+%d)" % got)
	ok(race.runners.is_empty(), "on: the lanes are cleared after it")
