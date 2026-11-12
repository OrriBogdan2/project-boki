extends RefCounted
## --base-life-check (GARDEN.md section 4 and 9.2): with base_mode on, four Boki live 10 simulated minutes on the
## real farm (home.gd _move_kin at 4 steps a second, BaseLife at 10 Hz) with one toy. Two hot tempers and two calm
## ones: at least one friend pair and one rival pair form, no state but Nap lasts over 90 s, the fourth Boki's
## arrival brings the others over (React), at night the three day Boki nap while the nocturnal Zapple stays up,
## no machine refuses a transition, bonds are symmetric, and a v11 save's Boki gain an empty bonds map. Never
## touches the real save.

const SIM_SECS := 600.0      # 10 simulated minutes
const DT := 0.25             # s per farm step (the machines tick at 10 Hz inside it)
const NIGHT_AT := 480.0      # s: the last two minutes are night
const ARRIVE_AT := 20.0      # s: the fourth Boki comes out
const LONGEST := 90.0        # s: no state but Nap may last longer

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BASELIFE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _new_save() -> Array:
	var d := Save.fresh()
	var recs: Array = []
	var hot := 0.95       # temper of the two that squabble
	var calm := 0.1
	var specs := [["cindle", "Ash", hot], ["basaltoad", "Crag", hot],
		["burrlet", "Moss", calm], ["zapple", "Pip", calm]]
	for spec in specs:
		var rec := Save.new_kin(spec[0], spec[1])
		rec["traits"]["temper"] = spec[2]
		recs.append(rec)
	recs[0]["starter"] = true
	d["roster"] = recs.slice(0, 3)
	d["active"] = recs[0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}      # no base tutorial (Lead)
	Save.d = d
	HomeLayout.ensure(d)
	return recs

func _gather(home, at: Vector3) -> void:
	for k in home.kins:
		k["pos"] = home.world.free_spot_near(at + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), [], 0.8)
		(k["node"] as Node3D).position = k["pos"]

## Two friends, the more outgoing one first: who starts, the cap, a swap, the 6-10 s length, the walkable ground
## all through, and both lying down side by side at the end. The other two Boki are parked asleep.
func _chase_rows(home, center: Vector3) -> void:
	var R: Dictionary = BaseChase.rules()
	var life: BaseLife = home.life
	home.day_t = 0.4
	for k in home.kins:
		(life.machine(k) as Fsm).go(BaseLife.S.ROAM, "test")
		k["nap_t"] = 0.0
		k["pers"]["social"] = 1.0
	var a: Dictionary = home.kins[0]
	var b: Dictionary = home.kins[1]
	var c: Dictionary = home.kins[2]
	var d: Dictionary = home.kins[3]
	a["pers"]["social"] = 0.4
	b["pers"]["social"] = 0.1
	BaseLife.add_bond(a["rec"], b["rec"], 2.0)
	BaseLife.add_bond(c["rec"], d["rec"], 2.0)
	_gather(home, center)
	ok(BaseChase.pick(life, b, [a]).is_empty() and is_same(BaseChase.pick(life, a, [b]), b),
		"friends: the more outgoing one (social 0.4 over 0.1) is the one that starts")
	var began := BaseChase.begin(life, a, b)
	ok(began and a.has("life_it") and not b.has("life_it") and life.machine(b).is_in(BaseLife.S.PLAY_WITH),
		"start: both friends are in PlayWith and the starter is the chaser")
	var secs := float(a["life_for"])
	ok(secs >= R["secs"][0] and secs <= R["secs"][1], "start: the chase is %.1f s (6 to 10)" % secs)
	ok(BaseChase.pick(life, c, [d]).is_empty() and BaseChase.running(life) == 1,
		"cap: a second pair in the zone does not start while one chase runs")
	var swaps := 0
	var dry := true
	var t := 0.0
	var was_it: bool = a.has("life_it")
	var ended_at := -1.0
	while t < 20.0:
		home._move_kin(DT)
		t += DT
		for k in [a, b]:
			var p: Vector3 = k["pos"]
			dry = dry and not home.world.is_void(p.x, p.z) and home.water.depth(p.x, p.z) < 2
		swaps += 1 if a.has("life_it") != was_it and a.has("life_chase") else 0
		was_it = a.has("life_it")
		if ended_at < 0.0 and not life.machine(a).is_in(BaseLife.S.PLAY_WITH):
			ended_at = t
	ok(swaps >= 1, "swap: the tag landed and the roles swapped (%d swaps)" % swaps)
	ok(dry, "nav: both stayed on the zone's ground, out of deep water")
	ok(ended_at > 0.0 and absf(ended_at - secs) <= 1.0, "end: it stopped at %.1f s of the %.1f s" % [ended_at, secs])
	ok(life.machine(a).is_in(BaseLife.S.NAP) and life.machine(b).is_in(BaseLife.S.NAP) and BaseLife._dist(a, b) < 2.5,
		"end: both are resting together (%.1f m apart)" % BaseLife._dist(a, b))
	var marks: bool = a.has("life_chase") or b.has("tag_pace") or BaseChase.running(life) > 0
	ok(not marks, "end: the chase marks are gone")
	var slow := {"stats": {"speed": 0}, "species": "cindle"}
	var fast := {"stats": {"speed": 999}, "species": "cindle"}
	var p_fast := BaseChase._pace(fast, 1.0)
	var p_slow := BaseChase._pace(slow, 1.0)
	ok(p_fast > p_slow, "pace: a higher Speed stat runs faster (%.2f over %.2f)" % [p_fast, p_slow])

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(11)
	var old := Save.fresh()
	old["v"] = 11
	old["roster"] = [{"uid": "old1", "species": "zapple", "name": "Old", "traits": {}, "trust": 35.0}]
	var upgraded := Save.migrate(old) and int(old["v"]) == Save.VERSION
	var bonds = old["roster"][0].get("bonds")
	ok(upgraded and bonds is Dictionary and (bonds as Dictionary).is_empty(),
		"a v11 save upgrades and its Boki gain an empty bonds map")
	var rules: Dictionary = Content.rules("farm_build")
	rules["base_mode"] = true
	var recs := _new_save()
	var home = await main._hb_home()
	ok(home.life != null, "base_mode on: the farm runs BaseLife")
	home.day_t = 0.4
	home.ppos = Vector3(-500, 0, -500)       # you are away: nobody clings to you
	var center: Vector3 = home.world.random_ground(0)
	Save.d["layout"]["deco"].append({"id": "toy_ball", "u": 990001, "px": center.x + 3.0, "pz": center.z})
	ok(home.life.toy_spots().size() == 1, "the placed ball is the one toy the machine knows (HomeToys owns the toys)")
	_gather(home, center)
	var longest := {}         # state name -> longest s seen
	var reacted := false
	var night_frames := 0
	var day_asleep := 0
	var pip_awake := 0
	var refused := 0
	var chase_max := 0         # most friend chases running at once in the 10 minutes
	var t := 0.0
	while t < SIM_SECS:
		if t < ARRIVE_AT and t + DT >= ARRIVE_AT:
			for kk in home.kins: refused += (kk["life"] as Fsm).refused
			Save.d["roster"].append(recs[3])
			home._spawn_kin()
			_gather(home, center)
		if t >= NIGHT_AT:
			home.day_t = 0.0
		home._move_kin(DT)
		t += DT
		chase_max = maxi(chase_max, BaseChase.running(home.life))
		for k in home.kins:
			if not k.has("life"):
				continue
			var fsm: Fsm = k["life"]
			if not fsm.is_in(BaseLife.S.NAP):
				longest[fsm.state_name()] = maxf(float(longest.get(fsm.state_name(), 0.0)), fsm.since)
			reacted = reacted or fsm.is_in(BaseLife.S.REACT)
			if t >= NIGHT_AT + 15.0:
				if k["rec"]["species"] == "zapple":
					pip_awake += 0 if fsm.is_in(BaseLife.S.NAP) else 1
				else:
					day_asleep += 1 if fsm.is_in(BaseLife.S.NAP) else 0
		night_frames += 1 if t >= NIGHT_AT + 15.0 else 0
	for k in home.kins: refused += (k["life"] as Fsm).refused
	print(home.life.readout())
	var friends := 0
	var rivals := 0
	var symmetric := true
	for i in recs.size():
		for j in range(i + 1, recs.size()):
			var b := BaseLife.bond(recs[i], recs[j])
			symmetric = symmetric and is_equal_approx(b, BaseLife.bond(recs[j], recs[i]))
			friends += 1 if b >= float(home.life.R["friend_at"]) else 0
			rivals += 1 if b <= float(home.life.R["rival_at"]) else 0
	ok(friends >= 1, "at least one friend pair formed (%d)" % friends)
	ok(rivals >= 1, "at least one rival pair formed (%d)" % rivals)
	ok(symmetric, "every bond is the same both ways")
	var over: Array = longest.keys().filter(func(s): return float(longest[s]) > LONGEST)
	ok(over.is_empty(), "no state but Nap lasts over %.0f s (longest %s)" % [LONGEST, longest])
	ok(reacted, "the fourth Boki's arrival brought the others over to look (React)")
	ok(day_asleep >= night_frames * 3 * 0.8,
		"at night the three day Boki nap (%d of %d frames)" % [day_asleep, night_frames * 3])
	ok(pip_awake >= night_frames * 0.5,
		"the nocturnal Zapple stays up at night (%d of %d frames)" % [pip_awake, night_frames])
	ok(refused == 0, "no machine refused a transition (%d)" % refused)
	var cap := int(BaseChase.rules()["per_zone"])
	ok(chase_max <= cap, "never more than %d friend chase at once in the 10 minutes (most %d)" % [cap, chase_max])
	_chase_rows(home, center)
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("BASELIFE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
