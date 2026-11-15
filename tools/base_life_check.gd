extends RefCounted
## --base-life-check (GARDEN.md section 4 and 9.2): with base_mode on, four Boki live 10 simulated minutes on the
## real farm (home.gd _move_kin at 4 steps a second, BaseLife at 10 Hz) with one toy. Two hot tempers and two calm
## ones: at least one friend pair and one rival pair form, no state but Nap lasts over 90 s, the fourth Boki's
## arrival brings the others over (React), at night the three day Boki nap while the nocturnal Zapple stays up,
## no machine refuses a transition, bonds are symmetric, and a v11 save's Boki gain an empty bonds map; the sleepers
## breathe and yawn (BokiNapSfx, _nap_sounds). Then the rivalry beat (BaseRival). Then nap spots: a tired Boki walks to a free one, its friend lies
## down beside it, a third takes another. Then the arrival greeting (BaseGreet):
## a trusting Boki 10 m off reaches you within GREET_SECS, a napping one sleeps on, a shy one peeks, a sulky one turns
## away, and each greets once. Never touches the real save.

const SIM_SECS := 600.0      # 10 simulated minutes
const DT := 0.25             # s per farm step (the machines tick at 10 Hz inside it)
const NIGHT_AT := 480.0      # s: the last two minutes are night
const ARRIVE_AT := 20.0      # s: the fourth Boki comes out
const LONGEST := 90.0        # s: no state but Nap may last longer
const LET_GO_MS := 1500      # ms of real time a woken Boki's breathing loop may take to stop
const GREET_SECS := 4.0      # s: a trusting Boki reaches you after you arrive
const GREET_AT := 10.0       # m: how far off it starts

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

## The rivalry beat (BaseRival, garden_sim.json rivalry): rivals passing close turn, huff and walk on, once a
## cooldown, and never play tag; a pair that is not rivals does nothing.
func _rival_beat(home) -> void:
	var R: Dictionary = BaseRival.rules()
	var a: Dictionary = home.kins[0]
	var b: Dictionary = home.kins[1]
	var c: Dictionary = home.kins[2]
	home.day_t = 0.4
	home.life.night = false
	for k in [a, b, c]:
		for key in ["rival_cd", "play", "eat", "nap_t", "life_at", "life_rival"]:
			k.erase(key)
		(k["life"] as Fsm).go(BaseLife.S.ROAM, "test")
	# the beat walks 4 m away from the other, which only counts on open ground: start from the island's middle
	var mid: Vector2 = home.world.islands[maxi(home.world.island_of(a["pos"].x, a["pos"].z), 0)]["c"]
	a["pos"] = home.world.free_spot_near(Vector3(mid.x, 0, mid.y), [], 0.8)
	(a["node"] as Node3D).position = a["pos"]
	b["pos"] = a["pos"] + Vector3(float(R["pass_m"]) * 0.5, 0, 0)
	c["pos"] = a["pos"] + Vector3(-float(R["pass_m"]) * 0.5, 0, 0)
	BaseLife.add_bond(a["rec"], b["rec"], -1.0 - BaseLife.bond(a["rec"], b["rec"]))
	BaseLife.add_bond(a["rec"], c["rec"], 0.0 - BaseLife.bond(a["rec"], c["rec"]))
	var heard := int(GardenSfx.heard.get("garden_sulk_small", 0)) + int(GardenSfx.heard.get("garden_sulk_medium", 0)) \
		+ int(GardenSfx.heard.get("garden_sulk_large", 0))
	home.life.step(0.2)
	var fa: Fsm = a["life"]
	var fb: Fsm = b["life"]
	var facing := is_same(a["life_at"], b) and is_same(b["life_at"], a)
	ok(fa.is_in(BaseLife.S.REACT) and fb.is_in(BaseLife.S.REACT) and facing,
		"rivals passing within %.1f m both turn to each other (React)" % float(R["pass_m"]))
	ok(float(a["huff_t"]) > 0.0 and float(b["huff_t"]) > 0.0, "both play the growl clip")
	var after := int(GardenSfx.heard.get("garden_sulk_small", 0)) + int(GardenSfx.heard.get("garden_sulk_medium", 0)) \
		+ int(GardenSfx.heard.get("garden_sulk_large", 0))
	ok(after == heard + 2, "each huffs through the garden SFX (%d cues)" % (after - heard))
	ok((c["life"] as Fsm).is_in(BaseLife.S.ROAM), "a Boki that is not a rival is left alone")
	var gap := BaseLife._dist(a, b)
	for i in int(float(R["beat_s"]) / 0.1) + 2:
		home.life.step(0.1)
	ok(fa.is_in(BaseLife.S.ROAM) and fb.is_in(BaseLife.S.ROAM) and not a.has("life_rival"), 
		"the beat ends in %.1f s" % float(R["beat_s"]))
	ok(Vector2(a["goal"].x - b["pos"].x, a["goal"].z - b["pos"].z).length() > gap, "it walks on, away from the other")
	home.life.step(0.2)
	ok(not fa.is_in(BaseLife.S.REACT), "no repeat inside the cooldown (%.0f s)" % float(R["cooldown_s"]))
	for k in [a, b]:
		(k["life"] as Fsm).go(BaseLife.S.ROAM, "test")
	home.life._tag(a, b)
	ok(not fa.is_in(BaseLife.S.PLAY_WITH) and not fb.is_in(BaseLife.S.PLAY_WITH), "rivals never play tag together")

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
	# Sfx.loop_hold lets go HOLD_MS of real time after the last hold; give the frames up to LET_GO_MS to run it
	var t0 := Time.get_ticks_msec()
	var left := _awake_breaths(home)
	while not left.is_empty() and Time.get_ticks_msec() - t0 < LET_GO_MS:
		await main.get_tree().process_frame
		left = _awake_breaths(home)
	ok(left.is_empty(), "an awake Boki's breath lets go within %d ms (%d still on)" % [LET_GO_MS, left.size()])

## The breathing loops still on for Boki that are awake.
func _awake_breaths(home) -> Array:
	var awake: Array = home.kins.filter(func(k): return float(k.get("nap_t", 0.0)) <= 0.0) \
		.map(func(k): return "nap:" + String(k["rec"]["uid"]))
	return Sfx.loops.keys().filter(func(key): return key in awake)

## Nap spots (garden_zones.json nap, set here around the gathering place: the farm island is random).
func _spots_part(home, center: Vector3) -> void:
	var zone: Dictionary = GardenZones.info(GardenZones.start())
	var kept: Array = zone["nap"]
	var cx := int(center.x)
	var cz := int(center.z)
	zone["nap"] = [["sunny rock", cx + 4, cz], ["under a tree", cx - 4, cz + 3]]
	var life: BaseLife = home.life
	home.day_t = 0.4
	for k in home.kins:
		k["nap_t"] = 0.0
		life.machine(k).go(BaseLife.S.ROAM, "test")
		k["rec"]["bonds"] = {}
		Care.need(k["rec"], "joy")
		k["rec"]["needs"]["joy"] = 90.0
	_gather(home, center)
	var keys: Array = home.kins.map(func(k): return k["rec"].keys())
	var a: Dictionary = home.kins[0]
	var b: Dictionary = home.kins[1]
	var c: Dictionary = home.kins[2]
	BaseLife.add_bond(a["rec"], b["rec"], 0.6)
	for k in [a, b, c]:
		life._nap(k, "tired")
	var sa: Dictionary = a.get("life_spot", {})
	var sb: Dictionary = b.get("life_spot", {})
	var sc: Dictionary = c.get("life_spot", {})
	ok(not sa.is_empty() and int(sa["slot"]) == 0, "a tired Boki heads for a free nap spot")
	ok(not sb.is_empty() and sb["i"] == sa.get("i") and int(sb["slot"]) == 1,
		"its friend (bond 0.6) takes the place beside it")
	ok(not sc.is_empty() and sc["i"] != sa.get("i") and int(sc["slot"]) == 0, "a third Boki takes the other spot")
	var t := 0.0
	while t < float(life.R["spot_walk"]) + 1.0 and [a, b, c].any(func(k): return float(k.get("nap_t", 0.0)) <= 0.0):
		home._move_kin(DT)
		t += DT
	var on := [a, b, c].filter(func(k): return k.has("life_spot") and float(k["nap_t"]) > 0.0 \
		and BaseLife._dist(k, {"pos": k["life_spot"]["pos"]}) < BaseLife.SPOT_AT * 2.0)
	ok(on.size() == 3, "all three walked there and lie down on their places in %.1f s (%d of 3)" % [t, on.size()])
	var was := BaseLife.bond(a["rec"], b["rec"])
	for i in 20:
		home._move_kin(DT)
	ok(BaseLife.bond(a["rec"], b["rec"]) > was, "napping side by side, the friends' bond grows")
	ok(home.kins.map(func(k): return k["rec"].keys()) == keys, "nothing of it is saved: the records gain no key")
	zone["nap"] = kept

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
	_rival_beat(home)
	_spots_part(home, center)
	home.queue_free()
	await main.get_tree().process_frame
	await _greet_case()
	rules["base_mode"] = false
	print("BASELIFE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## You arrive (the teleporter's flag): Keen (trust 80) runs over and hops, Doze (trust 80, napping) sleeps on,
## Wary (trust 10) peeks, Glum (trust 40, joy 5) turns away. Each enters Greet at most once.
func _greet_case() -> void:
	var d := Save.fresh()
	var specs := [["Keen", 80.0, 80.0, GREET_AT], ["Doze", 80.0, 80.0, 4.0], ["Wary", 10.0, 80.0, 5.0],
		["Glum", 40.0, 5.0, 5.0]]
	for spec in specs:
		var rec := Save.new_kin("burrlet", spec[0])
		rec["trust"] = spec[1]
		Care.ensure(rec)
		for n in rec["needs"]:
			rec["needs"][n] = 90.0
		rec["needs"]["joy"] = spec[2]
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	Save.d = d
	HomeLayout.ensure(d)
	var home = await main._hb_home()
	home.day_t = 0.4
	var me: Vector3 = home.world.random_ground(0)
	home.ppos = me
	var by := {}
	for i in home.kins.size():
		var k: Dictionary = home.kins[i]
		var angle: float = TAU * i / home.kins.size()
		k["pos"] = home.world.free_spot_near(me + Vector3(cos(angle), 0, sin(angle)) * float(specs[i][3]), [], 0.8)
		(k["node"] as Node3D).position = k["pos"]
		k["t"] = 30.0
		by[k["rec"]["name"]] = k
	home.life.machine(by["Doze"]).go(BaseLife.S.NAP, "test")
	by["Doze"]["nap_t"] = 60.0
	var keen_from := _flat(by["Keen"]["pos"] - me)
	var glum_from := _flat(by["Glum"]["pos"] - me)
	home.life.arrival = true
	var reached := -1.0
	var hows := {}
	var entered := {}
	var doze_woke := false
	var glum_far := 0.0
	var t := 0.0
	while t < 14.0:
		home._move_kin(DT)
		t += DT
		for k in home.kins:
			var who := String(k["rec"]["name"])
			var greeting := (k["life"] as Fsm).is_in(BaseLife.S.GREET)
			if greeting and not hows.has(who):
				hows[who] = k["life_greet"]["how"]
			if greeting and not k.get("was_greeting", false):
				entered[who] = int(entered.get(who, 0)) + 1
			k["was_greeting"] = greeting
		if reached < 0.0 and _flat(by["Keen"]["pos"] - me) < 2.5:
			reached = t
		doze_woke = doze_woke or not (by["Doze"]["life"] as Fsm).is_in(BaseLife.S.NAP)
		glum_far = maxf(glum_far, _flat(by["Glum"]["pos"] - me))
	ok(keen_from >= GREET_AT * 0.6 and reached >= 0.0 and reached <= GREET_SECS,
		"a trusting Boki %.1f m off runs to you on arrival (there at %.2f s, max %.0f s)"
			% [keen_from, reached, GREET_SECS])
	ok(hows.get("Keen", "") == "run", "it greets by running over (%s)" % hows.get("Keen", "none"))
	ok(not doze_woke and not hows.has("Doze"), "a napping Boki stays asleep")
	ok(hows.get("Wary", "") == "peek", "a shy Boki peeks and waves (%s)" % hows.get("Wary", "none"))
	ok(hows.get("Glum", "") == "sulk" and glum_far > glum_from + 1.0,
		"a sulking Boki turns away (%s, %.1f m to %.1f m off)" % [hows.get("Glum", "none"), glum_from, glum_far])
	ok(entered.values().all(func(n): return n == 1) and entered.size() == 3,
		"each awake Boki greets once per arrival (%s)" % entered)
	ok(home.kins.all(func(k): return (k["life"] as Fsm).refused == 0), "no machine refused a transition while greeting")
	home.queue_free()
	await main.get_tree().process_frame

static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
