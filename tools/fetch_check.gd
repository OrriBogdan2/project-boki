extends RefCounted
## --fetch-check: Fetch Cup (scripts/home/base_fetch.gd, docs/GARDEN_GAMES.md).
##   1. 400 seeded rounds: equal Boki split the rounds; Speed alone and Focus alone each win clearly more
##      than half, and the better Boki wins 60 to 90% of tosses' rounds, never all of them
##   2. a great head start call moves the backed Boki's odds up, by under 25 points
##   3. the machine: a round lasts about 60 s, no move is refused, the leader wins, DONE refuses moves
##   4. a settled round: the winner gains joy and trust, the loser sulks, both remember, gems to the backer
##   5. on the base: none with base_mode off; with it on, a round runs to a result card in a minute
## Never touches the real save.

const ROUNDS := 400  # rounds in the stat tests
const EDGE := 20  # rounds the better Boki must win above an even split
const CALL_MAX := 0.25  # the call may move the backed Boki's win share by less than this
const DT := 1.0 / 30.0  # s per step
const SETTLE_FRAMES := 600  # frames to wait at most for the home to finish building

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("FETCH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_stats()
	_call()
	_machine()
	_settle()
	await _on_base()
	print("FETCH DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _kin(kname: String, speed: int, focus: int, joy := 60.0, trust := 50.0) -> Dictionary:
	var k := Save.new_kin("zapple", kname)
	k["level"] = 5
	Care.ensure(k)
	k["stats"]["speed"] = speed
	k["stats"]["focus"] = focus
	k["needs"]["joy"] = joy
	k["needs"]["energy"] = 90.0
	k["trust"] = trust
	return k


func _round(recs: Array, back: int, seed_v: int, grade := "") -> BaseFetch.Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var r := BaseFetch.Run.new(recs, back, rng)
	if grade != "":
		r.call_head(grade)
	while not r.over():
		r.step(DT)
	return r


## Boki A with the given Speed and Focus against an untrained B: A's wins in ROUNDS.
func _wins(speed: int, focus: int, grade := "") -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var wins := 0
	for n in ROUNDS:
		if _round([_kin("A", speed, focus), _kin("B", 0, 0)], 0, rng.randi(), grade).winner() == 0:
			wins += 1
	return wins


func _stats() -> void:
	var even := _wins(0, 0)
	var fast := _wins(30, 0)
	var sharp := _wins(0, 30)
	var both := _wins(30, 30)
	ok(absf(even - ROUNDS / 2.0) < 40.0, "equal Boki split the rounds (%d of %d)" % [even, ROUNDS])
	ok(fast > ROUNDS / 2 + EDGE, "Speed alone wins %d of %d" % [fast, ROUNDS])
	ok(sharp > ROUNDS / 2 + EDGE, "Focus alone wins %d of %d" % [sharp, ROUNDS])
	ok(both > fast and both < ROUNDS, "Speed and Focus win %d of %d: more, but not every round" % [both, ROUNDS])
	ok(
		BaseFetch.pace(_kin("H", 10, 10, 100.0, 100.0)) > BaseFetch.pace(_kin("G", 10, 10, 0.0, 0.0)) * 1.1,
		"mood and trust nudge the pace up"
	)
	ok(BaseFetch.p_fumble(_kin("S", 0, 40)) < BaseFetch.p_fumble(_kin("D", 0, 0)), "Focus cuts the fumble chance")


func _call() -> void:
	var without := _wins(10, 10)
	var with_call := _wins(10, 10, "great")
	var against := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for n in ROUNDS:
		var r := _round([_kin("A", 10, 10), _kin("B", 10, 10)], 0, rng.randi(), "great")
		against += 1 if r.winner() == 0 else 0
	var moved := float(against - ROUNDS / 2.0) / ROUNDS
	ok(
		moved > 0.0 and moved < CALL_MAX,
		"a great call moves equal Boki's odds %+.0f points (under %d)" % [moved * 100.0, CALL_MAX * 100.0]
	)
	ok(with_call >= without, "a great call never hurts the backed Boki (%d vs %d of %d)" % [with_call, without, ROUNDS])


func _machine() -> void:
	var r := _round([_kin("A", 10, 10), _kin("B", 10, 10)], 0, 3, "good")
	var round_s := float(BaseFetch.rules()["round_s"])
	ok(r.refused == 0 and r.state == BaseFetch.Run.S.DONE, "a round plays through with no refused move")
	ok(
		r.t >= round_s and r.t < round_s + 10.0 and r.tosses > 5,
		"it lasts about %.0f s: %.1f s, %d tosses" % [round_s, r.t, r.tosses]
	)
	ok(r.score[r.winner()] >= r.score[1 - r.winner()], "the leader wins (%d:%d)" % [r.score[0], r.score[1]])
	ok(not r.move(BaseFetch.Run.S.TOSS) and r.refused == 1, "DONE goes nowhere: the move is refused and counted")


func _settle() -> void:
	Save.d = Save.fresh()
	var a := _kin("Pip", 10, 10)
	var b := _kin("Ash", 10, 10)
	var run_v := BaseFetch.Run.new([a, b], 0, RandomNumberGenerator.new())
	run_v.score = [7, 5]
	var gems := int(Save.d["gems"])
	var res := BaseFetch.settle(run_v)
	ok(res["win"] == a and res["lose"] == b and res["score"] == [7, 5], "settle: the higher score wins")
	ok(float(a["needs"]["joy"]) > 60.0 and float(a["trust"]) > 50.0, "settle: the winner gains joy and trust")
	ok(float(b["needs"]["joy"]) < 60.0, "settle: the loser sulks")
	ok(
		String(a["memory"][-1]["text"]).contains("Ash") and String(b["memory"][-1]["text"]).contains("Pip"),
		"settle: both remember it"
	)
	ok(
		int(Save.d["gems"]) == gems + int(BaseFetch.rules()["gems_win"]) and res["backed_won"],
		"settle: you get gems for backing the winner"
	)
	ok(MinigameHub.best("fetch")["name"] == "Pip", "settle: the winner tops the picker's board")


func _on_base() -> void:
	var rules: Dictionary = FarmUnlocks.rules()
	var d := Save.fresh()
	for i in 3:
		var k := _kin(["Pip", "Ash", "Bo"][i], 10, 10, 70.0)
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	var was: bool = FarmUnlocks.base_mode()
	rules["base_mode"] = false  # the old farm: no mat
	var off = await main._hb_home()
	ok(off.hfetch == null, "off: no toss mat on the farm")
	off.queue_free()
	await main.get_tree().process_frame
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	ok(home.hfetch != null, "on: the base has Fetch Cup")
	if home.hfetch != null:
		var fb: BaseFetch = home.hfetch
		var at := Vector2(fb.mat.position.x, fb.mat.position.z)
		ok(is_instance_valid(fb.mat) and fb.find(at) == {"kind": "fetch"}, "on: the mat offers a round")
		for k in home.kins:
			k.erase("indoors")
		fb.use()
		ok(fb.run != null and fb.pair.size() == 2, "on: a round starts with two Boki")
		var t := 0.0
		var ring := false
		while fb.run != null and t < float(BaseFetch.rules()["round_s"]) + 15.0:
			fb.tick(0.1)
			t += 0.1
			ring = ring or (fb.cue != null and fb.cue.landing.visible)
		ok(fb.run == null and is_instance_valid(fb.card), "on: the round ends with a result card (%.1f s)" % t)
		ok(ring and fb.cue == null, "cue: the landing ring showed on the tosses and is gone at the end")
	rules["base_mode"] = was
	home.queue_free()
	await main.get_tree().process_frame
