extends RefCounted
## --duo-check (GARDEN_MODERN.md section 5 rank 4, scripts/home/base_duo.gd): the duo bonus starts at bond
## 0.6 (0.59 gets nothing), a nap shared with a friend on the real farm restores nap_joy more than a nap
## beside a 0.5 bond, the Dash hand-off into a stretch runs 6% faster with a friend alongside (and not with a
## 0.59 bond or a friend 3 m behind), and the first duo moment is one journal line. Never touches the real save.

const DT := 0.25         # s per farm step
const NAP_S := 30.0      # s: the fixed nap length in this check
const WAKE_S := 60.0     # s simulated: everyone has woken by then
const START_JOY := 40.0

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("DUO %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _pair(a: Dictionary, b: Dictionary, bond: float) -> void:
	BaseLife.add_bond(a, b, bond - BaseLife.bond(a, b))

func _race(bond: float, gap: float) -> BaseRace.Run:
	var a := Save.new_kin("cindle", "Ash")
	var b := Save.new_kin("burrlet", "Moss")
	_pair(a, b, bond)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var run := BaseRace.Run.new([a, b], 0, rng)
	run.dist = [5.0, 5.0 + gap]
	run.stretch = [1, 1]
	return run

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(11)
	var a := Save.new_kin("cindle", "Ash")
	var b := Save.new_kin("burrlet", "Moss")
	_pair(a, b, 0.6)
	ok(BaseDuo.friends(a, b), "bond 0.6 is a duo")
	_pair(a, b, 0.59)
	ok(not BaseDuo.friends(a, b), "bond 0.59 is not")
	var rules: Dictionary = Content.rules("base_duo")
	ok(is_equal_approx(float(rules["friend_at"]), 0.6), "the threshold is in content/rules/base_duo.json")
	var duo_run := _race(0.7, 0.5)
	var plain_run := _race(0.59, 0.5)
	ok(duo_run._duo_mate(0) == 1 and duo_run._duo_mate(1) == 0, "friends side by side hand off cleanly")
	ok(plain_run._duo_mate(0) == -1, "no clean hand-off at bond 0.59")
	ok(_race(0.7, 3.0)._duo_mate(0) == -1, "no clean hand-off with the friend 3 m behind")
	duo_run._roll(0)
	plain_run._roll(0)
	var ratio := float(duo_run.pace[0]) / float(plain_run.pace[0])
	ok(is_equal_approx(ratio, float(rules["handoff_pace"])), "the clean hand-off paces x%.2f" % ratio)
	BaseDuo.note_first(a, b, "handed off cleanly with")
	BaseDuo.note_first(a, b, "napped with")
	ok(a["memory"].filter(func(e): return e["kind"] == "duo").size() == 1, "the first duo moment is one journal line")
	await _nap_check()
	print("DUO DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Four Boki nap in two pairs, one pair at bond 0.7 and one at 0.5: the friends wake nap_joy happier.
func _nap_check() -> void:
	var farm: Dictionary = Content.rules("farm_build")
	farm["base_mode"] = true
	Content.rules("base_life")["nap"] = [NAP_S, NAP_S]
	var d := Save.fresh()
	var recs: Array = []
	for spec in [["cindle", "Ash"], ["basaltoad", "Crag"], ["burrlet", "Moss"], ["zapple", "Pip"]]:
		var rec := Save.new_kin(spec[0], spec[1])
		rec["traits"]["temper"] = 0.1
		recs.append(rec)
	recs[0]["starter"] = true
	d["roster"] = recs
	d["active"] = recs[0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(d)
	_pair(recs[0], recs[1], 0.7)
	_pair(recs[2], recs[3], 0.5)
	var home = await main._hb_home()
	home.day_t = 0.4
	home.ppos = Vector3(-500, 0, -500)
	var center: Vector3 = home.world.random_ground(0)
	for k in home.kins:
		var side := -12.0 if k["rec"] in [recs[0], recs[1]] else 12.0
		k["pos"] = home.world.free_spot_near(center + Vector3(side, 0, 0), [], 0.8)
		(k["node"] as Node3D).position = k["pos"]
		Care.change(k["rec"], "joy", START_JOY - float(Care.need(k["rec"], "joy")))
		home.life._nap(k, "test")
	var t := 0.0
	while t < WAKE_S:
		home._move_kin(DT)
		t += DT
	var friends_gain := (Care.need(recs[0], "joy") + Care.need(recs[1], "joy")) * 0.5
	var others_gain := (Care.need(recs[2], "joy") + Care.need(recs[3], "joy")) * 0.5
	var extra := friends_gain - others_gain
	ok(absf(extra - float(Content.rules("base_duo")["nap_joy"])) < 1.5,
		"a shared nap restores nap_joy more than a 0.5 bond's (joy %.1f vs %.1f)" % [friends_gain, others_gain])
	var noted := func(r: Dictionary) -> bool: return r["memory"].any(func(e): return e["kind"] == "duo")
	ok(noted.call(recs[0]) and not noted.call(recs[2]), "the friends' nap is in the journal; the 0.5 pair's is not")
	farm["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
