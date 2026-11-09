extends RefCounted
## --volley-check: Spark Volley (scripts/home/base_volley.gd, briefs/design/GARDEN.md section 5.4).
##   1. 50 seeded matches with random Speed, Focus, joy, trust and species: the side with the better
##      expected return wins 60 to 85% of them (a game, not a dice roll and not a certainty)
##   2. Focus and Speed: more of either alone wins more than half of its matches between equal Boki
##   3. a good spike call: over 50 seeded matches of equal Boki, the same dice with a great call at the
##      start win the backed Boki more matches than without, by under 25 points
##   4. the machine: no move is refused, a match ends at 5 with a winner, and a TABLE-less move is counted
##   5. a settled match: the winner's joy and trust go up, the loser's joy down, both remember it, gems
##   6. on the base: no log with base_mode off; with it on, a match runs to a result card
## Never touches the real save.

const MATCHES := 50
const WIN_LOW := 0.6             # the better side must win at least this share
const WIN_HIGH := 0.85           # ... and at most this share
const SPIKE_MAX := 0.25          # the call may move the backed Boki's win share by less than this
const EDGE_MATCHES := 400        # matches in the stat tests
const DT := 1.0 / 30.0           # s per step
const SETTLE_FRAMES := 600       # frames to wait at most for the home to finish building

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("VOLLEY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_better()
	_stats()
	_spike()
	_machine()
	_settle()
	await _on_base()
	print("VOLLEY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(sp: String, kname: String, speed: int, focus: int, joy: float, trust: float) -> Dictionary:
	var k := Save.new_kin(sp, kname)
	k["level"] = 5
	Care.ensure(k)
	k["stats"]["speed"] = speed
	k["stats"]["focus"] = focus
	k["needs"]["joy"] = joy
	k["needs"]["energy"] = 90.0
	k["trust"] = trust
	return k

func _random_kin(rng: RandomNumberGenerator, kname: String) -> Dictionary:
	var species: Array = Data.KIN.keys()
	return _kin(species[rng.randi() % species.size()], kname, rng.randi_range(0, 42), rng.randi_range(0, 42),
			rng.randf_range(30.0, 100.0), rng.randf_range(0.0, 100.0))

func _match(recs: Array, back: int, seed_: int, grade := "") -> BaseVolley.Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var r := BaseVolley.Run.new(recs, back, rng)
	if grade != "":
		r.call_spike(grade)
	while not r.over():
		r.step(DT)
	return r

func _better() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261109
	var wins := 0
	for n in MATCHES:
		var a := _random_kin(rng, "A")
		var b := _random_kin(rng, "B")
		var expect := 0 if BaseVolley.expected(a, b) >= 0.5 else 1
		var r := _match([a, b], rng.randi() % 2, rng.randi(), ["great", "good", "miss", ""][rng.randi() % 4])
		if r.winner() == expect:
			wins += 1
	var share := float(wins) / MATCHES
	ok(share >= WIN_LOW and share <= WIN_HIGH, "the better side wins %d of %d (%.0f%%, needs %d to %d%%)"
			% [wins, MATCHES, share * 100.0, WIN_LOW * 100.0, WIN_HIGH * 100.0])

## Boki A with the given Speed and Focus against an untrained B of the same species: A's wins in EDGE_MATCHES.
func _wins(speed: int, focus: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var wins := 0
	for n in EDGE_MATCHES:
		var a := _kin("zapple", "A", speed, focus, 60.0, 50.0)
		var b := _kin("zapple", "B", 0, 0, 60.0, 50.0)
		if _match([a, b], 0, rng.randi()).winner() == 0:
			wins += 1
	return wins

func _stats() -> void:
	var level := EDGE_MATCHES / 2
	var even := _wins(0, 0)
	var fast := _wins(30, 0)
	var sharp := _wins(0, 30)
	ok(absf(even - level) < 40, "equal Boki split the matches (%d of %d)" % [even, EDGE_MATCHES])
	ok(fast > level + 20, "Speed alone wins %d of %d" % [fast, EDGE_MATCHES])
	ok(sharp > level + 20, "Focus alone wins %d of %d" % [sharp, EDGE_MATCHES])
	var by_theme := {}
	for id in Data.KIN:
		by_theme[String(Data.KIN[id].get("theme", ""))] = id
	var a := _kin(by_theme["ember"], "A", 10, 10, 50.0, 50.0)
	var b := _kin(by_theme["frost"], "B", 10, 10, 50.0, 50.0)
	var plain := _kin(by_theme["stone"], "P", 10, 10, 50.0, 50.0)
	var ratio := BaseVolley.strength(a, b) / BaseVolley.strength(a, plain)
	ok(absf(ratio - float(BaseVolley.rules()["edge"])) < 0.001, "the type edge is x%.3f of strength" % ratio)
	var happy := _kin("zapple", "H", 10, 10, 100.0, 100.0)
	var glum := _kin("zapple", "G", 10, 10, 0.0, 0.0)
	ok(BaseVolley.strength(happy, glum) > BaseVolley.strength(glum, happy) * 1.1, "mood and trust nudge strength up")

## Equal Boki, same dice with and without a great call at the start.
func _spike() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var with_call := 0
	var without := 0
	for n in EDGE_MATCHES:
		var a := _kin("zapple", "A", 20, 20, 60.0, 50.0)
		var b := _kin("zapple", "B", 20, 20, 60.0, 50.0)
		var s := rng.randi()
		if _match([a, b], 0, s, "great").winner() == 0:
			with_call += 1
		if _match([a, b], 0, s).winner() == 0:
			without += 1
	var moved := float(with_call - without) / EDGE_MATCHES
	var what := "a great spike call moves the backed Boki's odds %d to %d%% (%+.0f points, under %d)"
	ok(moved > 0.0 and moved < SPIKE_MAX,
			what % [without * 100 / EDGE_MATCHES, with_call * 100 / EDGE_MATCHES, moved * 100.0, SPIKE_MAX * 100.0])

func _machine() -> void:
	var a := _kin("zapple", "A", 10, 10, 50.0, 50.0)
	var b := _kin("cindle", "B", 10, 10, 50.0, 50.0)
	var r := _match([a, b], 0, 3, "good")
	var top := maxi(r.score[0], r.score[1])
	ok(r.refused == 0 and r.state == BaseVolley.Run.S.DONE, "a match plays through with no refused move")
	var ended := top >= int(BaseVolley.rules()["to_win"]) and r.score[r.winner()] == top
	ok(ended, "it ends at the target with the leader as winner (%d:%d)" % [r.score[0], r.score[1]])
	ok(not r.go(BaseVolley.Run.S.SERVE) and r.refused == 1, "DONE goes nowhere: the move is refused and counted")

func _settle() -> void:
	Save.d = Save.fresh()
	var a := _kin("zapple", "Pip", 10, 10, 50.0, 50.0)
	var b := _kin("cindle", "Ash", 10, 10, 50.0, 50.0)
	var run_ := BaseVolley.Run.new([a, b], 0, RandomNumberGenerator.new())
	run_.score = [5, 3]
	var gems := int(Save.d["gems"])
	var res := BaseVolley.settle(run_)
	ok(res["win"] == a and res["lose"] == b and res["score"] == [5, 3], "settle: the higher score wins")
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
	ok(off.hvolley == null, "off: no volley log on the farm")
	off.queue_free()
	await main.get_tree().process_frame
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	ok(home.hvolley != null, "on: the base has Spark Volley")
	if home.hvolley != null:
		var vb: BaseVolley = home.hvolley
		var at := Vector2(vb.log_node.position.x, vb.log_node.position.z)
		ok(is_instance_valid(vb.log_node) and vb.find(at) == {"kind": "volley"}, "on: the log offers a match")
		for k in home.kins:
			k.erase("indoors")
		vb.use()
		ok(vb.run != null and vb.pair.size() == 2, "on: a match starts with two Boki")
		var t := 0.0
		while vb.run != null and t < float(BaseVolley.rules()["max_s"]) + 5.0:
			vb.tick(0.1)
			t += 0.1
		ok(vb.run == null and is_instance_valid(vb.card), "on: the match ends with a result card (%.1f s)" % t)
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
