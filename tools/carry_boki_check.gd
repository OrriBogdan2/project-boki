extends RefCounted
## --carry-boki-check: lifting a Boki at home (HomeCarry). A small one rides in the arms, a middling
## one on the back, a big one is led; you walk at 90% with it; it is set down on the spot in front of
## you; a grumpy one squirms free after its few seconds, a timid one clings on, a brave one wriggles;
## a bonded one gains a little trust once a day; holding the key picks it up and a tap still pats.
## Never touches the real save.

const STEP := 0.1
var bad := 0
var main: Node
var home

func ok(cond: bool, what: String) -> void:
	print("CARRYBOKI %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _species_of_weight(lo: float, hi: float) -> String:
	for f in DirAccess.get_files_at("res://content/kin"):
		var id := f.get_basename()
		var kg := float(Unique.base_size(id)["kg"])
		if f.ends_with(".json") and kg > lo and kg <= hi:
			return id
	return ""

## An average-sized one, so its weight is its species' weight.
func _plain(species: String, nm: String) -> Dictionary:
	var rec := Save.new_kin(species, nm)
	Unique.of(rec)["size"] = 0.0
	Unique.of(rec)["girth"] = 1.0
	return rec

func _kin(species: String, nm: String, bravery: float, temper: float, trust: float) -> Dictionary:
	var rec := _plain(species, nm)
	rec["traits"]["bravery"] = bravery
	rec["traits"]["temper"] = temper
	rec["trust"] = trust
	Save.d["roster"].append(rec)
	return rec

## A Boki of this species/mood standing near the player, as the Home screen holds it.
func _entry(rec: Dictionary) -> Dictionary:
	for e in home.kins:
		if e["rec"]["uid"] == rec["uid"]:
			return e
	return {}

func _put(rec: Dictionary) -> Dictionary:
	var k: Dictionary = _entry(rec)
	k["pos"] = home.ppos + Vector3(0.0, 0.0, -1.0)
	(k["node"] as Node3D).position = k["pos"]
	return k

func _walk(k: Dictionary, secs: float) -> float:
	var far := 0.0
	for i in int(secs / STEP):
		var turn := float(i) * STEP * 2.0      # a small circle, so the island never runs out
		home.ppos += Vector3(sin(turn), 0.0, cos(turn)) * home.SPEED * home.carry.speed_mul() * STEP
		home.player.position = home.ppos
		home.carry.tick(STEP, {}, true)
		home._move_kin(STEP)
		far = maxf(far, Vector2(k["pos"].x - home.ppos.x, k["pos"].z - home.ppos.z).length())
	return far

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	var d := Save.fresh()
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	var small := "zapple"
	var mid := _species_of_weight(HomeCarry.ARMS_KG * 1.3, HomeCarry.BACK_KG * 0.9)
	var big := _species_of_weight(HomeCarry.BACK_KG * 1.3, 1000.0)
	var brave := _kin(small, "Bo", 0.9, 0.3, 60.0)
	var timid := _kin(small, "Ti", 0.1, 0.3, 60.0)
	var grumpy := _kin(small, "Gr", 0.5, 0.9, 60.0)
	var wary := _kin(small, "Wa", 0.9, 0.3, 10.0)
	var bigrec := _kin(big, "Bigg", 0.5, 0.3, 60.0)
	d["active"] = brave["uid"]
	HomeLayout.ensure(d)
	home = await main._hb_home()
	home.set_process(false)      # the check drives the frames itself
	_sizes(mid, big)
	home.ppos = Vector3(38.0, 0.0, 30.0)
	home.pface = 0.0
	home.player.position = home.ppos
	await _lift_walk_drop(_entry(brave))
	_traits(timid, grumpy, brave)
	_trust(brave, wary)
	_lead(bigrec)
	_pose()
	print("CARRYBOKI DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _sizes(mid: String, big: String) -> void:
	ok(mid != "" and big != "", "the roster has a middling (%s) and a big (%s) species" % [mid, big])
	ok(HomeCarry.mode_for(_plain("zapple", "a")) == "carry", "a small one is carried in the arms")
	ok(HomeCarry.mode_for(_plain(mid, "b")) == "pack", "a middling one is carried on the back")
	ok(HomeCarry.mode_for(_plain(big, "c")) == "lead", "a big one is led, not lifted")
	var r := {"traits": {"bravery": 0.9, "temper": 0.3}}
	ok(HomeCarry.temper_of(r) == "brave", "high bravery is brave")
	r["traits"]["bravery"] = 0.1
	ok(HomeCarry.temper_of(r) == "timid", "low bravery is timid")
	r["traits"]["temper"] = 0.9
	ok(HomeCarry.temper_of(r) == "grumpy", "a hot temper is grumpy, whatever the bravery")

func _lift_walk_drop(k: Dictionary) -> void:
	var c: HomeCarry = home.carry
	var scale0: Vector3 = (k["node"] as Node3D).scale
	ok(c.speed_mul() == 1.0, "no change to your speed before you lift")
	await _hold_lifts(k)
	ok(c.k == k and c.mode == "carry" and k["busy"], "holding interact lifts a small Boki into your arms")
	ok(is_equal_approx(c.speed_mul(), 0.9) and c.anim_state()["act"] == "carry", "you walk at 90% with the carry pose")
	var far := _walk(k, 3.0)
	ok(far < 0.8, "it stays in your arms while you walk (%.2f m away at most)" % far)
	var spot: Vector3 = home.ppos + Vector3(-sin(home.pface), 0.0, -cos(home.pface)) * HomeCarry.DROP_DIST
	c.drop()
	var gap := Vector2(k["pos"].x - spot.x, k["pos"].z - spot.z).length()
	var down: bool = c.k.is_empty() and not k["busy"]
	ok(down and gap < 0.15, "pressing again sets it down in front of you (%.2f m off)" % gap)
	var normal: bool = (k["node"] as Node3D).scale.is_equal_approx(scale0) and c.speed_mul() == 1.0
	ok(normal, "its size and your speed are normal again")

## The real key: a long hold lifts, a quick tap pats.
func _hold_lifts(k: Dictionary) -> void:
	var c: HomeCarry = home.carry
	var tap := {"kind": "kin", "k": k}
	var frame := func(): await main.get_tree().process_frame
	k["hold_t"] = 0.0
	Input.action_press("interact")
	c.tick(STEP, tap, true)
	await frame.call()
	Input.action_release("interact")
	c.tick(STEP, tap, true)
	ok(c.k.is_empty() and float(k["hold_t"]) > 0.0, "a quick tap still pats instead of lifting")
	await frame.call()
	Input.action_press("interact")
	c.tick(STEP, tap, true)
	await frame.call()
	for i in int(HomeCarry.HOLD_S / STEP) + 2:
		c.tick(STEP, tap, true)
	Input.action_release("interact")
	await frame.call()

func _traits(timid: Dictionary, grumpy: Dictionary, brave: Dictionary) -> void:
	var c: HomeCarry = home.carry
	var g := _put(grumpy)
	c.press_hold(g)
	var t_free := 0.0
	for i in 200:
		c.tick(STEP, {}, true)
		if c.k.is_empty():
			t_free = float(i + 1) * STEP
			break
	var on_time: bool = absf(t_free - HomeCarry.SQUIRM_S) < 0.3
	ok(on_time, "a grumpy one squirms free after %.1f s (set: %.1f)" % [t_free, HomeCarry.SQUIRM_S])
	var heads_off: bool = g["goal"].distance_to(g["pos"]) > 1.0
	ok(not g["busy"] and heads_off, "it hops down and heads off, no longer carried")
	var ti := _put(timid)
	c.press_hold(ti)
	for i in 300:
		c.tick(STEP, {}, true)
	ok(c.k == ti, "a timid one clings on as long as you like (30 s)")
	var brave_roll := absf((ti["node"] as Node3D).rotation.z)
	ok(brave_roll < 0.1, "and only trembles a little")
	c.drop()
	var b := _put(brave)
	c.press_hold(b)
	var swing := 0.0
	for i in 30:
		c.tick(STEP, {}, true)
		swing = maxf(swing, absf((b["node"] as Node3D).rotation.z))
	ok(swing > 0.12, "a brave one wriggles happily in your arms (%.2f rad)" % swing)
	c.drop()

func _trust(brave: Dictionary, wary: Dictionary) -> void:
	var c: HomeCarry = home.carry
	var carry_for := func(rec: Dictionary) -> float:
		var before := float(rec["trust"])
		c.press_hold(_put(rec))
		for i in int((HomeCarry.TRUST_S + 0.5) / STEP):
			c.tick(STEP, {}, true)
		c.drop()
		return float(rec["trust"]) - before
	brave.erase("carried_day")
	ok(is_equal_approx(carry_for.call(brave), HomeCarry.TRUST_GAIN), "a bonded Boki gains a little trust")
	ok(carry_for.call(brave) == 0.0, "but only once a day")
	brave["carried_day"] = "2000-01-01"
	ok(carry_for.call(brave) > 0.0, "and again the next day")
	ok(carry_for.call(wary) == 0.0, "a Boki that isn't bonded yet gains nothing")

func _lead(rec: Dictionary) -> void:
	var c: HomeCarry = home.carry
	var k := _put(rec)
	c.press_hold(k)
	ok(c.mode == "lead" and not k.get("busy", false) and k.has("led"), "a big one stays on the ground and is led")
	var far := _walk(k, 4.0)
	ok(far < 3.0, "it follows beside you as you walk (%.2f m behind at most)" % far)
	c.press_hold(k)
	ok(c.k.is_empty() and not k.has("led"), "holding again lets it go")

func _pose() -> void:
	var a: HunterAnim = home.p_anim
	for mode in ["carry", "pack"]:
		for i in 40:
			a.update(1.0 / 60.0, {"vel": Vector3(0, 0, -4.0), "face": 0.0, "grounded": true, "act": mode})
		ok(a.act_kind == mode and a.act_k > 0.9, "the hunter holds the %s pose while running" % mode)
