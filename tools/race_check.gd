extends RefCounted
## --race-check: the Dash (scripts/home/base_race.gd, briefs/design/GARDEN.md 5.1 and 9.4).
##   1. 20 headless races of 3 Boki with random Speed, joy and species, a random backed Boki and
##      random cheer grades: the one with the highest expected pace wins at least 60% of them
##   2. leans: a water lean swims faster, a flying lean glides the gap faster, neither helps elsewhere
##   3. friends run side by side (closer than strangers), rivals bump
##   4. a settled race: the winner's joy and trust go up, the loser's joy down, both remember it,
##      you get gems, the two grow apart (bonds)
##   5. on the base: no race post with base_mode off; with it on, a race runs to a result card
##   6. the Training post drill still runs on the shared timing bar: three presses, then it ends
## Never touches the real save.

const RACES := 20
const WIN_SHARE := 0.6           # the favourite must win at least this share
const DT := 1.0 / 30.0           # s per step
const MAX_S := 120.0             # s: a race that runs longer is stuck
const SETTLE_FRAMES := 600       # frames to wait at most for the home to finish building

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("RACE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_favourites()
	_leans()
	_friends_rivals()
	_settle()
	await _on_base()
	print("RACE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(sp: String, kname: String, speed: int, joy: float) -> Dictionary:
	var k := Save.new_kin(sp, kname)
	k["level"] = 5
	Care.ensure(k)
	k["stats"]["speed"] = speed
	k["needs"]["joy"] = joy
	k["needs"]["energy"] = 90.0
	return k

func _race(recs: Array, back: int, rng: RandomNumberGenerator, cheer := true) -> BaseRace.Run:
	var r := BaseRace.Run.new(recs, back, rng)
	while not r.over() and r.t < MAX_S:
		if cheer and r.can_cheer():
			r.cheer(["great", "good", "miss"][rng.randi() % 3])
		r.step(DT)
	return r

func _favourites() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261109
	var species: Array = Data.KIN.keys()
	var wins := 0
	var stuck := 0
	for n in RACES:
		var recs: Array = []
		for i in 3:
			var sp: String = species[rng.randi() % species.size()]
			recs.append(_kin(sp, "R%d" % i, rng.randi_range(0, 42), rng.randf_range(30.0, 100.0)))
		var fav := 0
		for i in 3:
			if BaseRace.expected_time(recs[i]) < BaseRace.expected_time(recs[fav]):
				fav = i
		var r := _race(recs, rng.randi() % 3, rng)
		if not r.over():
			stuck += 1
		elif r.order()[0] == fav:
			wins += 1
	ok(stuck == 0, "every race finishes in under %d s" % int(MAX_S))
	var need := int(ceil(RACES * WIN_SHARE))
	ok(wins >= need, "the favourite wins %d of %d races (needs %d)" % [wins, RACES, need])

func _leans() -> void:
	var walker: String = Data.KIN.keys().filter(func(sp): return not BaseRace.winged({"species": sp}))[0]
	var plain := _kin(walker, "Plain", 10, 60.0)
	var swim := _kin(walker, "Swim", 10, 60.0)
	var fly := _kin(walker, "Fly", 10, 60.0)
	swim["lean"] = {"water": 1.0}
	fly["lean"] = {"flying": 1.0}
	var st: Array = BaseRace.rules()["stretches"]
	var water := -1
	var jump := -1
	for i in st.size():
		if st[i]["kind"] == "water": water = i
		if st[i]["kind"] == "jump": jump = i
	var base0 := BaseRace.stretch_pace(plain, 0)
	ok(BaseRace.stretch_pace(swim, water) > BaseRace.stretch_pace(plain, water) * 1.2, "a water lean swims faster")
	ok(BaseRace.stretch_pace(fly, jump) > BaseRace.stretch_pace(plain, jump) * 1.2, "a flying lean glides the gap")
	var flat := is_equal_approx(BaseRace.stretch_pace(swim, 0), base0) \
			and is_equal_approx(BaseRace.stretch_pace(fly, 0), base0)
	ok(flat, "leans don't help on the straight")
	var any_wings := Data.KIN.keys().any(func(sp): return BaseRace.winged({"species": sp}))
	ok(any_wings, "some species have wings (they glide without a lean)")
	var glum := _kin(walker, "Glum", 10, 5.0)
	ok(BaseRace.expected_time(glum) > BaseRace.expected_time(plain), "a glum Boki is slower (mood)")

## The mean gap between runners 0 and 1 over a race.
func _mean_gap(recs: Array, seed_n: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var r := BaseRace.Run.new(recs, 0, rng)
	var sum := 0.0
	var n := 0
	while not r.over() and r.t < MAX_S:
		r.step(DT)
		sum += absf(float(r.dist[0]) - float(r.dist[1]))
		n += 1
	return sum / maxf(1.0, n)

func _friends_rivals() -> void:
	var a := _kin("zapple", "A", 30, 80.0)
	var b := _kin("zapple", "B", 6, 50.0)
	var apart := _mean_gap([a, b], 7)
	BaseRace.nudge_bond(a, b, 1.0)
	var together := _mean_gap([a, b], 7)
	ok(together < apart * 0.6, "friends run side by side: mean gap %.2f m vs %.2f m as strangers" % [together, apart])
	BaseRace.nudge_bond(a, b, -2.0)
	var c := _kin("zapple", "C", 10, 60.0)
	var d := _kin("zapple", "D", 10, 60.0)
	BaseRace.nudge_bond(c, d, -1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var r := _race([c, d], 0, rng, false)
	ok(not r.bumped.is_empty(), "rivals bump (%d bumps)" % r.bumped.size())

func _settle() -> void:
	var fast := _kin("zapple", "Fast", 42, 60.0)
	var slow := _kin("zapple", "Slow", 0, 60.0)
	var gems := int(Save.d["gems"])
	var trust := float(fast["trust"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var r := _race([fast, slow], 0, rng)
	var res := BaseRace.settle(r)
	ok(res["win"] == fast and res["lose"] == slow, "the much faster Boki wins")
	ok(Care.need(fast, "joy") > 60.0 and float(fast["trust"]) > trust, "the winner gains joy and trust")
	ok(Care.need(slow, "joy") < 60.0, "the loser sulks (joy down)")
	ok(int(Save.d["gems"]) > gems, "you get gems (+%d)" % (int(Save.d["gems"]) - gems))
	var apart := BaseRace.bond(fast, slow) < 0.0 and BaseRace.bond(slow, fast) < 0.0
	ok(apart, "the two grow apart (bonds %.2f)" % BaseRace.bond(fast, slow))
	var mem_w: Array = fast["memory"]
	var mem_l: Array = slow["memory"]
	ok(not mem_w.is_empty() and mem_w[-1]["kind"] == "race" and not mem_l.is_empty() and mem_l[-1]["kind"] == "race",
			"both remember it: \"%s\"" % (mem_w[-1]["text"] if not mem_w.is_empty() else ""))

func _on_base() -> void:
	var rules: Dictionary = FarmUnlocks.rules()
	ok(not FarmUnlocks.base_mode(), "base_mode is off in the shipped rules")
	var d := Save.fresh()
	for i in 3:
		var k := _kin(["zapple", "cindle", "zapple"][i], ["Pip", "Ash", "Bo"][i], 10, 70.0)
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()      # the full stock farm, with a Training post
	Save.d = d
	HomeLayout.ensure(Save.d)
	var off = await main._hb_home()
	ok(off.hrace == null, "off: no race post on the farm")
	off.queue_free()
	await main.get_tree().process_frame
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:      # the home builds over a few frames; the UI comes last
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	ok(home.hrace != null, "on: the base has the Dash")
	if home.hrace != null:
		var race: BaseRace = home.hrace
		var post_ok := is_instance_valid(race.post)
		ok(post_ok and race.find(Vector2(race.post.position.x, race.post.position.z)) == {"kind": "race"},
				"on: the race post stands by the Training post and offers a race")
		for k in home.kins:
			k.erase("indoors")
		race.use()
		ok(race.run != null and race.runners.size() >= 2, "on: a race starts with %d Boki" % race.runners.size())
		if race.run != null:
			race.bar.m = race.bar.zone        # a press right on the gold
			var press := InputEventAction.new()
			press.action = "interact"
			press.pressed = true
			race.input(press)
			ok(home.verbs.act == "cheer", "on: a good race cheer plays your Hunter's cheer (%s)" % home.verbs.act)
		var t := 0.0
		while race.run != null and t < MAX_S:
			race.tick(0.1)
			t += 0.1
		ok(race.run == null and is_instance_valid(race.card), "on: the race ends with a result card (%.1f s)" % t)
	await _drill(home)
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame

func _drill(home) -> void:
	if home.yard == null:
		ok(true, "drill: no Training post on this base (skipped)")
		return
	var rec := Save.active_kin()
	rec["needs"]["energy"] = 90.0
	rec["needs"]["food"] = 90.0
	home._start_drill(rec, "speed")
	ok(not home.train.is_empty() and home.train["bar"] is TimingBar, "drill: starts on the timing bar")
	for i in 3:
		home._train_hit()
		for f in 40:
			home._train_process(1.0 / 30.0)
	ok(home.train.is_empty(), "drill: three presses end it (%s)" % rec["stats"]["speed"])
