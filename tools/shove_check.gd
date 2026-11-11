extends RefCounted
## --shove-check: the Stump Shove (scripts/home/base_shove.gd, briefs/design/GARDEN.md section 5.2).
##   1. 50 headless bouts with random Power, Guard, joy, trust and species: the side with the higher
##      expected push wins 60 to 80% of them (a game, not a dice roll and not a certainty)
##   2. the timed press: the backed Boki's win share with a great press at the start against none,
##      over many bouts of evenly matched Boki, moves by more than 0 and under 15 points
##   3. the type edge: a theme in "beats" gives 10% push, never both ways between two themes
##   4. a settled bout: the winner's joy and trust go up, the loser's joy down, both remember it, gems
##   5. on the base: no stump with base_mode off; with it on, a bout runs to a result card
## Never touches the real save.

const BOUTS := 50
const WIN_LOW := 0.6             # the stronger side must win at least this share
const WIN_HIGH := 0.8            # ... and at most this share
const PRESS_BOUTS := 400         # bouts a side in the press test
const PRESS_MAX := 0.15          # the press may move the backed Boki's win share by less than this
const DT := 1.0 / 30.0           # s per step
const SETTLE_FRAMES := 600       # frames to wait at most for the home to finish building

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("SHOVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_stronger()
	_press()
	_edge()
	_settle()
	await _on_base()
	print("SHOVE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(sp: String, kname: String, power: int, guard: int, joy: float, trust: float) -> Dictionary:
	var k := Save.new_kin(sp, kname)
	k["level"] = 5
	Care.ensure(k)
	k["stats"]["power"] = power
	k["stats"]["guard"] = guard
	k["needs"]["joy"] = joy
	k["needs"]["energy"] = 90.0
	k["trust"] = trust
	return k

func _bout(recs: Array, back: int, rng: RandomNumberGenerator, grade := "") -> BaseShove.Run:
	var r := BaseShove.Run.new(recs, back, rng)
	if grade != "":
		r.shove(grade)
	while not r.over():
		r.step(DT)
	return r

func _random_kin(rng: RandomNumberGenerator, kname: String) -> Dictionary:
	var species: Array = Data.KIN.keys()
	return _kin(species[rng.randi() % species.size()], kname, rng.randi_range(0, 42), rng.randi_range(0, 42),
			rng.randf_range(30.0, 100.0), rng.randf_range(0.0, 100.0))

func _stronger() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261109
	var wins := 0
	for n in BOUTS:
		var a := _random_kin(rng, "A")
		var b := _random_kin(rng, "B")
		var expect := 0 if BaseShove.expected(a, b) >= 0.0 else 1
		var r := _bout([a, b], rng.randi() % 2, rng, ["great", "good", "miss", ""][rng.randi() % 4])
		if r.winner() == expect:
			wins += 1
	var share := float(wins) / BOUTS
	ok(share >= WIN_LOW and share <= WIN_HIGH, "the stronger side wins %d of %d (%.0f%%, needs %d to %d%%)"
			% [wins, BOUTS, share * 100.0, WIN_LOW * 100.0, WIN_HIGH * 100.0])

## Evenly matched Boki, same dice with and without a great press at the start.
func _press() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var with_press := 0
	var without := 0
	for n in PRESS_BOUTS:
		var a := _kin("zapple", "A", 20, 20, 60.0, 50.0)
		var b := _kin("zapple", "B", 20, 20, 60.0, 50.0)
		var s := rng.randi()
		var r1 := RandomNumberGenerator.new()
		r1.seed = s
		var r2 := RandomNumberGenerator.new()
		r2.seed = s
		if _bout([a, b], 0, r1, "great").winner() == 0:
			with_press += 1
		if _bout([a, b], 0, r2).winner() == 0:
			without += 1
	var moved := float(with_press - without) / PRESS_BOUTS
	var what := "a great press moves the backed Boki's odds %d to %d%% (%+.0f points, under %d)"
	ok(moved > 0.0 and moved < PRESS_MAX,
			what % [without * 100 / PRESS_BOUTS, with_press * 100 / PRESS_BOUTS, moved * 100.0, PRESS_MAX * 100.0])

func _edge() -> void:
	var beats: Dictionary = BaseShove.rules()["beats"]
	var mutual := 0
	for t in beats:
		for u in beats[t]:
			if beats.get(u, []).has(t):
				mutual += 1
	ok(mutual == 0, "no theme beats one that beats it")
	var by_theme := {}
	for id in Data.KIN:
		by_theme[String(Data.KIN[id].get("theme", ""))] = id
	var a := _kin(by_theme["ember"], "A", 10, 10, 50.0, 50.0)
	var b := _kin(by_theme["frost"], "B", 10, 10, 50.0, 50.0)
	ok(BaseShove.has_edge(a, b) and not BaseShove.has_edge(b, a), "ember beats frost and not the other way")
	var plain := _kin(by_theme["stone"], "P", 10, 10, 50.0, 50.0)
	var ratio := BaseShove.push(a, b) / BaseShove.push(a, plain)
	ok(absf(ratio - 1.1) < 0.001, "the edge is 10%% of push (x%.3f)" % ratio)

func _settle() -> void:
	Save.d = Save.fresh()
	var a := _kin("zapple", "Pip", 10, 10, 50.0, 50.0)
	var b := _kin("cindle", "Ash", 10, 10, 50.0, 50.0)
	var run_ := BaseShove.Run.new([a, b], 0, RandomNumberGenerator.new())
	run_.balance = 1.0
	var gems := int(Save.d["gems"])
	var res := BaseShove.settle(run_)
	ok(res["win"] == a and res["lose"] == b, "settle: the side at its end of the balance wins")
	ok(float(a["needs"]["joy"]) > 50.0 and float(a["trust"]) > 50.0, "settle: the winner gains joy and trust")
	ok(float(b["needs"]["joy"]) < 50.0, "settle: the loser sulks")
	ok(String(a["memory"][-1]["text"]).contains("Ash") and String(b["memory"][-1]["text"]).contains("Pip"),
			"settle: both remember it")
	ok(int(Save.d["gems"]) > gems and res["backed_won"], "settle: you get gems for backing the winner")

func _on_base() -> void:
	var rules: Dictionary = FarmUnlocks.rules()
	var d := Save.fresh()
	for i in 3:
		var k := _kin(["zapple", "cindle", "zapple"][i], ["Pip", "Ash", "Bo"][i], 10, 10, 70.0, 50.0)
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	var off = await main._hb_home()
	ok(off.hshove == null, "off: no stump on the farm")
	off.queue_free()
	await main.get_tree().process_frame
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	ok(home.hshove != null, "on: the base has the Stump Shove")
	if home.hshove != null:
		var sh: BaseShove = home.hshove
		var at := Vector2(sh.stump.position.x, sh.stump.position.z)
		ok(is_instance_valid(sh.stump) and sh.find(at) == {"kind": "shove"}, "on: the stump offers a shove")
		for k in home.kins:
			k.erase("indoors")
		sh.use()
		ok(sh.run != null and sh.pair.size() == 2, "on: a bout starts with two Boki")
		var duo: Array = sh.pair.duplicate()
		ok(duo.all(func(k): return k["node"].get_meta("kact", "") == "push"), "on: both Boki push")
		var t := 0.0
		while sh.run != null and t < float(BaseShove.rules()["max_s"]) + 5.0:
			sh.tick(0.1)
			t += 0.1
		ok(sh.run == null and is_instance_valid(sh.card), "on: the bout ends with a result card (%.1f s)" % t)
		var acts: Array = duo.map(func(k): return k["node"].get_meta("kact", ""))
		ok(acts.has("win") and acts.has("sulk") and duo.all(func(k): return k["busy"]),
				"on: the winner shows it and the loser sulks, both held")
		sh.tick(float(BaseShove.rules()["card_s"]) + 0.1)
		ok(duo.all(func(k): return not k["busy"] and k["node"].get_meta("kact", "") == ""), "on: both are let go")
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
