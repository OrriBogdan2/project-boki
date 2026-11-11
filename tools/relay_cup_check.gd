extends RefCounted
## --relay-cup-check: the Relay Cup (scripts/home/base_relay.gd, GARDEN_MODERN.md 4.2 game 5).
##   1. a seeded relay is deterministic: the same seed gives the same times; each team runs three legs
##      and hands off twice
##   2. hand-off timing changes the result: against an even team, great presses win far more often than
##      missed ones, and at least one seed flips from a loss to a win
##   3. the order: a water-lean Boki is put on the water leg
##   4. duo friends hand off cleanly even on a miss and beat strangers; rivals fumble unless the press is great
##   5. the visitors are at least the cup round's strength, so a win counts for the cup: prizes, gems,
##      memories and the next round from garden_prizes.json "relay"; a loss starts the run over
##   6. on the base: the relay stand by the Dash loop starts a relay of three against three that ends on a
##      result card, and the visitors leave
## Never touches the real save.

const DT := 1.0 / 30.0           # s per step
const MAX_S := 120.0             # s: a relay that runs longer is stuck
const SEEDS := 30                # seeded relays per press style
const SETTLE_FRAMES := 600       # frames to wait at most for the home to finish building

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("RELAY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_determinism()
	_timing()
	_order()
	_duo_rivals()
	_cup()
	await _on_base()
	print("RELAY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(sp: String, kname: String, speed: int) -> Dictionary:
	var k := Save.new_kin(sp, kname)
	k["level"] = 5
	k["stats"]["speed"] = speed
	k["needs"]["joy"] = 70.0
	k["needs"]["energy"] = 90.0
	return k

func _team() -> Array:
	return [_kin("zapple", "Pip", 12), _kin("cindle", "Ash", 12), _kin("zapple", "Bo", 12)]

## One relay to the end; `grade` is pressed at every hand-off ("" presses nothing).
func _relay(mine: Array, theirs: Array, seed: int, grade: String) -> BaseRelay.Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var r := BaseRelay.Run.new(mine, theirs, rng)
	while not r.over() and r.t < MAX_S:
		if grade != "" and r.can_press():
			r.press(grade)
		r.step(DT)
	return r

func _determinism() -> void:
	var mine := _team()
	var theirs := BaseRelay.rivals(mine, 1.0)
	var a := _relay(mine, theirs, 4242, "good")
	var b := _relay(mine, theirs, 4242, "good")
	ok(a.over() and a.done_t == b.done_t and a.lost == b.lost,
			"seed 4242 twice: same times (%.2f / %.2f s)" % [a.done_t[0], a.done_t[1]])
	ok(a.leg == [2, 2] and a.lost[0].size() == 2 and a.lost[1].size() == 2 and a.grades.size() == 2,
			"three legs a team, two hand-offs each")
	var c := _relay(mine, theirs, 4243, "good")
	ok(c.done_t != a.done_t, "another seed, other times (%.2f s)" % c.done_t[0])

func _timing() -> void:
	var mine := _team()
	var theirs := BaseRelay.rivals(mine, 1.0)
	var wins := {"great": 0, "miss": 0}
	var slower := 0.0
	var flips := 0
	for s in SEEDS:
		var g := _relay(mine, theirs, 900 + s, "great")
		var m := _relay(mine, theirs, 900 + s, "")
		wins["great"] += int(g.won())
		wins["miss"] += int(m.won())
		slower += (float(m.done_t[0]) - float(g.done_t[0])) / SEEDS
		if g.won() and not m.won():
			flips += 1
	ok(wins["great"] >= wins["miss"] + SEEDS / 3,
			"even teams: great hand-offs win %d of %d, no presses win %d" % [wins["great"], SEEDS, wins["miss"]])
	ok(slower > 0.8, "no presses run %.2f s slower on average" % slower)
	ok(flips > 0, "hand-off timing flips the result on %d seeds" % flips)

func _order() -> void:
	var swimmer := _kin("cindle", "Fin", 12)
	swimmer["lean"] = {"water": 1.0}
	var team := [swimmer, _kin("zapple", "Pip", 12), _kin("zapple", "Bo", 12)]
	ok(BaseRelay.order(team)[1] == swimmer, "the water-lean Boki runs the water leg")
	var fast := _kin("zapple", "Zip", 40)
	var order := BaseRelay.order([_kin("zapple", "Pip", 5), _kin("zapple", "Bo", 5), fast])
	ok(order.size() == 3 and order.has(fast), "order keeps all three")

func _duo_rivals() -> void:
	var friends := _team()
	for a in friends:
		for b in friends:
			if a != b:
				a["bonds"][String(b["uid"])] = 0.7
	var theirs := BaseRelay.rivals(_team(), 1.0)
	var duo := _relay(friends, theirs, 77, "")
	ok(duo.lost[0] == [0.0, 0.0] and duo.duo.size() == 2,
			"duo friends hand off cleanly with no press (lost %s)" % [duo.lost[0]])
	var strangers := _relay(_team(), theirs, 77, "")
	ok(float(duo.done_t[0]) < float(strangers.done_t[0]),
			"friends %.2f s, strangers %.2f s on the same seed" % [duo.done_t[0], strangers.done_t[0]])
	var rivals := _team()
	for a in rivals:
		for b in rivals:
			if a != b:
				a["bonds"][String(b["uid"])] = -0.6
	var R := BaseRelay.rules()
	var good := _relay(rivals, theirs, 78, "good")
	var want := float(R["handoff"]["good"]) + float(R["fumble"])
	ok(is_equal_approx(float(good.lost[0][0]), want), "rivals fumble on a good press (%.2f s)" % good.lost[0][0])
	var great := _relay(rivals, theirs, 78, "great")
	ok(great.lost[0] == [0.0, 0.0], "rivals hand off cleanly on a great press")

func _cup() -> void:
	Save.d = Save.fresh()
	var mine := _team()
	for rec in mine:
		Save.d["roster"].append(rec)
	var anchor: Dictionary = mine[0]
	for round in GardenPrizes.rules()["cup"]["rounds"]:
		var ratio := float(round["min_ratio"])
		var foes := BaseRelay.rivals(mine, ratio)
		ok(GardenPrizes.strength(foes[0]) >= ratio * GardenPrizes.strength(anchor),
				"%s round: visitors at %.1fx strength" % [round["name"], ratio])
	var gems := int(Save.d["gems"])
	var r := _relay(mine, BaseRelay.rivals(mine, BaseRelay.cup_round(anchor)["min_ratio"]), 5, "great")
	r.done_t = [30.0, 31.0]       # settle a win
	var res := BaseRelay.settle(r, anchor)
	ok(res["won"] and int(Save.d["gems"]) == gems + int(BaseRelay.rules()["gems_win"]), "a win pays the relay's gems")
	ok(not res["prize"]["items"].is_empty() and res["prize"]["round"] == "Sprout"
			and GardenPrizes.stage(anchor, "relay") == 1,
			"a win rolls the relay prize table and counts for the Sprout round (%s)" % [res["prize"]["items"]])
	ok(anchor["memory"][-1]["kind"] == "relay", "the team remembers it: \"%s\"" % anchor["memory"][-1]["text"])
	r.done_t = [32.0, 31.0]       # settle a loss
	res = BaseRelay.settle(r, anchor)
	ok(not res["won"] and res["prize"]["reset"] and GardenPrizes.stage(anchor, "relay") == 0,
			"a loss starts the cup run over")

func _on_base() -> void:
	var rules: Dictionary = FarmUnlocks.rules()
	var d := Save.fresh()
	for i in 3:
		var k := _kin(["zapple", "cindle", "zapple"][i], ["Pip", "Ash", "Bo"][i], 10)
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()      # the full stock farm, with a Training post
	Save.d = d
	HomeLayout.ensure(Save.d)
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:      # the home builds over a few frames; the UI comes last
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	var relay: BaseRelay = home.hrace.relay if home.hrace != null else null
	ok(relay != null and is_instance_valid(relay.stand), "on: the Dash loop has a relay stand")
	if relay != null and is_instance_valid(relay.stand):
		var at := Vector2(relay.stand.position.x, relay.stand.position.z)
		ok(home.hrace.find(at) == {"kind": "relay"}, "on: the stand offers \"%s\"" % relay.label())
		for k in home.kins:
			k.erase("indoors")
		relay.use()
		ok(relay.run != null and relay.mine.size() == 3 and relay.visitors.size() == 3,
				"on: a relay starts, three against three")
		var press := InputEventAction.new()
		press.action = "interact"
		press.pressed = true
		var t := 0.0
		var nodes: Array = relay.visitors.map(func(v): return v["node"])
		while relay.run != null and t < MAX_S:
			if relay.run.can_press():
				relay.bar.m = relay.bar.zone        # a press right on the gold
				home.hrace.input(press)
			home.hrace.tick(DT)
			t += DT
		ok(relay.run == null and is_instance_valid(home.hrace.card),
				"on: the relay ends with a result card (%.1f s)" % t)
		await main.get_tree().process_frame
		ok(nodes.all(func(n): return not is_instance_valid(n)), "on: the visitors leave")
		ok(home.kins.all(func(k): return not k.get("busy", false)), "on: your three are free again")
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
