extends RefCounted
## --base-life-check (GARDEN.md section 4 and 9.2): with base_mode on, four Boki live 10 simulated minutes on the
## real farm (home.gd _move_kin at 4 steps a second, BaseLife at 10 Hz) with one toy. Two hot tempers and two calm
## ones: at least one friend pair and one rival pair form, no state but Nap lasts over 90 s, the fourth Boki's
## arrival brings the others over (React), at night the three day Boki nap while the nocturnal Zapple stays up,
## no machine refuses a transition, bonds are symmetric, and a v11 save's Boki gain an empty bonds map; the sleepers
## breathe and yawn (BokiNapSfx, _nap_sounds). Never touches the real save.

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

## BokiNapSfx: of 30 Boki asleep around you only the nearest few breathe, within the loop's reach; a bigger
## Boki breathes lower; the night's sleepers breathe near you, and at dawn they yawn and the woken ones' loops let go.
func _nap_sounds(home) -> void:
	var pile := []
	for i in 30:
		pile.append({"pos": Vector3(float(i % 6) * 1.2, 0, float(i / 6) * 1.2)})
	var heard := BokiNapSfx.heard(pile, Vector3.ZERO)
	var reach := float(Sfx.sound_reach.get(BokiNapSfx.LOOP, 0.0))
	var inside := heard.all(func(k): return Vector2(k["pos"].x, k["pos"].z).length() < reach)
	ok(heard.size() == BokiNapSfx.MAX_HEARD and inside and is_same(heard[0], pile[0]),
		"of 30 asleep only the %d nearest breathe, all within %.0f m" % [heard.size(), reach])
	var by_cm: Array = home.kins.map(func(k): return k["rec"])
	by_cm.sort_custom(func(a, b): return float(Unique.size_info(a)["cm"]) < float(Unique.size_info(b)["cm"]))
	var lower := true
	for i in by_cm.size() - 1:
		lower = lower and BokiNapSfx.pitch_of(by_cm[i + 1]) <= BokiNapSfx.pitch_of(by_cm[i])
	ok(lower, "a bigger Boki breathes lower (%s)" % [by_cm.map(func(r): return "%.2f" % BokiNapSfx.pitch_of(r))])
	var sleeper: Dictionary = home.kins.filter(func(k): return float(k.get("nap_t", 0.0)) > 0.0)[0]
	Sfx.listener = sleeper["pos"]
	home._move_kin(DT)
	var on := Sfx.loops.keys().filter(func(key): return String(key).begins_with("nap:"))
	ok(on.size() >= 1 and on.size() <= BokiNapSfx.MAX_HEARD,
		"the night's sleepers near you breathe (%d loops)" % on.size())
	home.day_t = 0.3
	Sfx.last_played.erase(BokiNapSfx.YAWN)
	for i in int(10.0 / DT):
		Sfx.listener = sleeper["pos"]
		home._move_kin(DT)
		if Sfx.last_played.has(BokiNapSfx.YAWN):
			break
	ok(Sfx.last_played.has(BokiNapSfx.YAWN), "a Boki waking at dawn yawns")
	await main.get_tree().create_timer(0.4).timeout
	var awake: Array = home.kins.filter(func(k): return float(k.get("nap_t", 0.0)) <= 0.0) \
		.map(func(k): return "nap:" + String(k["rec"]["uid"]))
	var left := Sfx.loops.keys().filter(func(key): return key in awake)
	ok(not awake.is_empty() and left.is_empty(),
		"an awake Boki's breath lets go (%d of %d still on)" % [left.size(), awake.size()])

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
	await _nap_sounds(home)
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("BASELIFE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
