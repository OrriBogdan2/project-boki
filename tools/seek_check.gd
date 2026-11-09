extends RefCounted
## --seek-check: Seek (scripts/home/base_seek.gd, briefs/design/GARDEN.md section 5.3).
##   1. 20 seeded hunts: a high-Focus Boki beats a no-Focus one in most of them (either side of the pair)
##   2. curiosity: a curious Boki beats an incurious one at equal Focus
##   3. night: a Spore Boki beats an identical plain Boki far more at night than by day
##   4. friends and rivals: friends share a good sniff, rivals slow the slower one
##   5. a settled hunt: winner joy and trust up, loser sulks (less with a friend), both remember it, gems, bonds
##   6. the state machine refuses moves its table lacks
##   7. on the base: no basket with base_mode off; with it on, take, hide and hunt to a result card
## Never touches the real save.

const ROUNDS := 20
const MOST := 14                 # a clear favourite wins at least this many of ROUNDS
const NIGHT_ROUNDS := 80         # hunts in the night test
const NIGHT_GAP := 0.15          # the Spore share at night must beat the day's by at least this
const DT := 1.0 / 30.0           # s per step
const DAY_T := 0.5               # day clock at noon
const NIGHT_T := 0.97            # day clock in the dead of night
const SETTLE_FRAMES := 600       # frames to wait at most for the home to finish building

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("SEEK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_focus()
	_curiosity()
	_night()
	_company()
	_settle()
	_machine()
	await _on_base()
	print("SEEK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(sp: String, kname: String, focus: int, curiosity := 0.5) -> Dictionary:
	var k := Save.new_kin(sp, kname)
	k["level"] = 5
	Care.ensure(k)
	k["stats"]["focus"] = focus
	k["traits"]["curiosity"] = curiosity
	k["needs"]["joy"] = 50.0
	k["needs"]["energy"] = 90.0
	k["trust"] = 50.0
	return k

func _species(theme: String) -> String:
	for id in Data.KIN:
		if Data.KIN[id].get("theme", "") == theme and not Work.NOCTURNAL.has(id):
			return id
	return ""

## One hunt from the origin to a scent 6 to 14 m away; returns the winner's index.
func _hunt(a: Dictionary, b: Dictionary, seed_: int, night := false) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var at := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(6.0, 14.0)
	var hunt := BaseSeek.Hunt.new([a, b], [Vector2.ZERO, Vector2.ZERO], at, night, rng)
	while not hunt.over():
		hunt.step(DT)
	return hunt.winner()

## A hunt from the origin to a scent 5 m east, ready to step.
func _at5(a: Dictionary, b: Dictionary) -> BaseSeek.Hunt:
	return BaseSeek.Hunt.new([a, b], [Vector2.ZERO, Vector2.ZERO], Vector2(5, 0), false, RandomNumberGenerator.new())

## Wins of the first Boki over rounds, swapping sides every other round.
func _wins(a: Dictionary, b: Dictionary, rounds: int, night := false) -> int:
	var wins := 0
	for n in rounds:
		var swap := n % 2 == 1
		var w := _hunt(b, a, 1000 + n, night) if swap else _hunt(a, b, 1000 + n, night)
		if (w == 1) == swap:
			wins += 1
	return wins

func _focus() -> void:
	var sharp := _kin("zapple", "Sharp", 40)
	var dull := _kin("zapple", "Dull", 0)
	var wins := _wins(sharp, dull, ROUNDS)
	ok(wins >= MOST, "high Focus wins %d of %d (needs %d)" % [wins, ROUNDS, MOST])
	ok(BaseSeek.speed(sharp) > BaseSeek.speed(dull) and BaseSeek.right_p(sharp, false) > BaseSeek.right_p(dull, false),
			"Focus adds speed and good sniffs")

func _curiosity() -> void:
	var curious := _kin("zapple", "Curious", 10, 0.95)
	var bland := _kin("zapple", "Bland", 10, 0.05)
	var wins := _wins(curious, bland, NIGHT_ROUNDS)
	ok(wins * 100 >= NIGHT_ROUNDS * 55, "curiosity wins %d of %d at equal Focus" % [wins, NIGHT_ROUNDS])

func _night() -> void:
	var spore := _kin(_species("spore"), "Spore", 10)
	var plain := _kin(_species("stone"), "Plain", 10)
	ok(HomeWork.is_night(NIGHT_T) and not HomeWork.is_night(DAY_T), "the day clock tells night from noon")
	ok(BaseSeek.night_type(spore) and not BaseSeek.night_type(plain), "Spore is a night type, Stone is not")
	var by_day := float(_wins(spore, plain, NIGHT_ROUNDS)) / NIGHT_ROUNDS
	var by_night := float(_wins(spore, plain, NIGHT_ROUNDS, true)) / NIGHT_ROUNDS
	ok(by_night >= by_day + NIGHT_GAP and by_night > 0.5,
			"night favours Spore: %.0f%% of hunts by night, %.0f%% by day" % [by_night * 100.0, by_day * 100.0])

func _company() -> void:
	var a := _kin("zapple", "A", 10)
	var b := _kin("zapple", "B", 10)
	var rng := RandomNumberGenerator.new()
	var hunt := BaseSeek.Hunt.new([a, b], [Vector2.ZERO, Vector2.ZERO], Vector2(9, 0), false, rng)
	ok(not hunt.friends() and not hunt.rivals(), "strangers are neither friends nor rivals")
	BaseRace.nudge_bond(a, b, 0.6)
	ok(hunt.friends(), "a bond above friend_at makes friends")
	BaseRace.nudge_bond(a, b, -1.6)
	ok(hunt.rivals(), "a bond below rival_at makes rivals")
	var slow := _kin("zapple", "Slow", 0)
	var fast := _kin("zapple", "Fast", 30)
	BaseRace.nudge_bond(slow, fast, -1.0)
	var near := BaseSeek.Hunt.new([slow, fast], [Vector2.ZERO, Vector2(0.5, 0)], Vector2(0, 50), false, rng)
	near.step(DT)
	ok(near.pos[0].distance_to(Vector2.ZERO) < BaseSeek.speed(slow) * DT * 0.7,
			"rivals shoulder: the slower one is held back")

func _settle() -> void:
	Save.d = Save.fresh()
	var a := _kin("zapple", "Pip", 10)
	var b := _kin("cindle", "Ash", 10)
	var hunt := _at5(a, b)
	hunt.found = 0
	var gems := int(Save.d["gems"])
	var res := BaseSeek.settle(hunt)
	ok(res["win"] == a and res["lose"] == b, "settle: the finder wins")
	ok(float(a["needs"]["joy"]) > 50.0 and float(a["trust"]) > 50.0, "settle: the winner gains joy and trust")
	ok(float(b["needs"]["joy"]) < 50.0, "settle: the loser sulks")
	ok(String(a["memory"][-1]["text"]).contains("Ash") and String(b["memory"][-1]["text"]).contains("Pip"),
			"settle: both remember it")
	ok(int(Save.d["gems"]) > gems, "settle: you get gems")
	ok(BaseRace.bond(a, b) < 0.0, "settle: strangers grow apart")
	var c := _kin("zapple", "Cy", 10)
	var d := _kin("zapple", "Dee", 10)
	BaseRace.nudge_bond(c, d, 0.6)
	var friends := _at5(c, d)
	friends.found = 0
	BaseSeek.settle(friends)
	ok(float(d["needs"]["joy"]) > float(b["needs"]["joy"]) and BaseRace.bond(c, d) > 0.6,
			"settle: a friend sulks less and the pair grow closer")

func _machine() -> void:
	var s := BaseSeek.new(null)
	ok(not s.go(BaseSeek.S.HUNT) and s.state == BaseSeek.S.IDLE and s.refused == 1, "idle cannot jump to the hunt")
	ok(s.go(BaseSeek.S.CARRY) and s.go(BaseSeek.S.HUNT) and s.go(BaseSeek.S.RESULT) and s.go(BaseSeek.S.IDLE),
			"idle, carry, hunt, result, idle is the way round")
	ok(not s.go(BaseSeek.S.RESULT) and s.refused == 2, "a refused move is counted and changes nothing")

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
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	var off = await main._hb_home()
	ok(off.hseek == null, "off: no scent basket on the farm")
	off.queue_free()
	await main.get_tree().process_frame
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	ok(home.hseek != null, "on: the base has Seek")
	if home.hseek != null:
		var sk: BaseSeek = home.hseek
		var at := Vector2(sk.basket.position.x, sk.basket.position.z)
		var away := at + Vector2(30, 0)
		ok(sk.find(at) == {"kind": "seek"} and sk.find(away).is_empty(), "on: the basket offers the scent")
		for k in home.kins:
			k.erase("indoors")
		sk.use()
		ok(sk.state == BaseSeek.S.CARRY and sk.find(away) == {"kind": "seek"}, "on: carrying, any spot offers a hide")
		home.ppos = sk.h.kins[0]["pos"] + Vector3(1, 0, 0)
		sk.use()
		ok(sk.state == BaseSeek.S.CARRY, "on: too close to the Boki, the scent stays in hand")
		var far: Vector3 = home.kins[0]["pos"] + Vector3(7, 0, 0)
		home.ppos = far
		sk.use()
		ok(sk.state == BaseSeek.S.HUNT and sk.hunt != null and sk.pair.size() == 2, "on: hidden, two Boki hunt")
		var t := 0.0
		while sk.state == BaseSeek.S.HUNT and t < float(BaseSeek.rules()["max_s"]) + 5.0:
			sk.tick(0.1)
			t += 0.1
		var carded: bool = sk.state == BaseSeek.S.RESULT and is_instance_valid(sk.card)
		ok(carded, "on: the hunt ends with a result card (%.1f s)" % t)
		sk.tick(float(BaseSeek.rules()["card_s"]) + 1.0)
		ok(sk.state == BaseSeek.S.IDLE, "on: the card goes and Seek is ready again")
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
