extends RefCounted
## Grimble's ultimate on X, Brass Broadside, for --dredge-combo-check (docs/heroes/dredge.md): the level gate,
## the 1.1s charge behind a growing fan everyone sees (a slow walk, the fan turning with the aim), two waves 0.6s
## apart of six slugs each (shots through Match.spawn_shot), Anti-Heal, every slug landing up close and fewer
## further out, bond once per cast and only on a land, the stun that stops it, the other buttons locked while
## it runs, no back bonus, the merge drop, the cooldown, the reel combo and the burst cap.

const BURST := preload("res://tools/ult_burst.gd")
const FACE_AWAY := PI / 2.0         # a target east of Grimble facing this way shows him its back

var ak = null
var ok_fn: Callable

func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb

func ok(label: String, cond: bool, info := "") -> void:
	ok_fn.call(label, cond, info)

## What the bond meter owes the current ult cast (KinBond.from_ult keeps the best event per cast id).
func _owed(P: Hunter) -> float:
	var c: Dictionary = P.get_meta("bond_cast", {})
	return float(c.get("got", 0.0)) if String(c.get("id", "")) == HeroUlt.cast_id(P.ak) else 0.0

func run() -> void:
	await _charge_and_waves()
	await _guards()
	await _burst()

func _cast(P: Hunter, at: Vector3) -> DredgeBlast:
	var K: DredgeKit = P.ak
	K.cd["x"] = 0.0
	ak.aim_at(P, at)
	HunterKeys.ult_pressed(P)
	return K.broadside

func _charge_and_waves() -> void:
	var r: Array = ak.setup("dredge", 1.6, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: DredgeKit = P.ak
	var B := K.broadside
	T.teleport(home + Vector3(-6.0, 0, -5.0))
	T2.teleport(home + Vector3(-6.0, 0, 5.0))
	P.lvl = 5
	_cast(P, home + Vector3(4, 0, 0))
	ok("ult: no cast below level 6", not B.running() and float(K.cd["x"]) == 0.0 and B.casts == 0, "level %d" % P.lvl)
	P.lvl = 6
	# his walk first, to compare the slowed walk against
	ak.step(m, 0.2, func(): P.inp["move"] = Vector2(0, 1))
	var w0 := P.pos
	ak.step(m, 0.3, func(): P.inp["move"] = Vector2(0, 1))
	var run_v := P.flat_dist(w0) / 0.3
	P.inp["move"] = Vector2.ZERO
	ak.step(m, 0.2)
	P.teleport(home)
	var shots0: int = m.shot_n
	_cast(P, home + Vector3(4, 0, 0))
	ok(
		"ult cast: the charge move plays, its own cooldown starts (21s)",
		B.charging() and K.anim_id == "dr_blast" and absf(float(K.cd["x"]) - 21.0) < 0.2, "cd %.1f" % float(K.cd["x"])
	)
	ak.step(m, 0.3, func(): P.inp["move"] = Vector2(0, 1))
	var fan: Dictionary = AimKit.entry(P, "x_fan")
	var len_a := float(fan.get("len", 0.0))
	var p0 := P.pos
	ak.step(m, 0.6, func(): P.inp["move"] = Vector2(0, 1))
	var len_b := float(AimKit.entry(P, "x_fan").get("len", 0.0))
	ok(
		"ult telegraph: a 105 degree fan everyone sees, growing over the charge",
		bool(fan.get("all", false)) and absf(float(fan.get("deg", 0.0)) - 105.0) < 0.5 and len_b > len_a + 0.5,
		"len %.1f -> %.1f" % [len_a, len_b]
	)
	var charge_k := P.flat_dist(p0) / 0.6 / maxf(0.01, run_v)
	ok(
		"ult: he walks slowly through the charge (about 30% of his speed)",
		B.waves == 0 and charge_k > 0.2 and charge_k < 0.4, "%.2f of %.1f m/s" % [charge_k, run_v]
	)
	# the cursor swings round to the south: the fan turns with it, and the waves go that way
	ak.aim_at(P, P.pos + Vector3(0, 0, 4.0))
	ak.step(m, 0.25, func(): P.inp["move"] = Vector2(0, 1))
	var p1 := P.pos
	ak.step(m, 0.4, func(): P.inp["move"] = Vector2(0, 1))
	var fire_k := P.flat_dist(p1) / 0.4 / maxf(0.01, run_v)
	var fdir: Vector2 = B.blast.get("dir", Vector2.ZERO)
	ok(
		"ult: he walks slower still while the waves go (about 20%), and keeps turning to the cursor",
		B.waves >= 1 and fire_k > 0.1 and fire_k < 0.3 and fdir.distance_to(Vector2(0, 1)) < 0.15,
		"%.2f, fan toward (%.2f, %.2f)" % [fire_k, fdir.x, fdir.y]
	)
	P.inp["move"] = Vector2.ZERO
	ak.aim_at(P, P.pos + Vector3(4, 0, 0))
	ak.step(m, 0.65)
	ok(
		"ult: one press, two waves of six slugs through spawn_shot",
		B.waves == 2 and m.shot_n - shots0 >= 12 and not B.running(),
		"waves %d shots %d" % [B.waves, m.shot_n - shots0]
	)
	ok(
		"ult bond: nothing for waves that hit nobody", _owed(P) == 0.0 and B.casts == 1,
		"owed %.2f casts %d" % [_owed(P), B.casts]
	)
	HunterKeys.ult_pressed(P)
	ok("ult: the cooldown denies a new cast", not B.running() and B.casts == 1, "cd %.1f" % float(K.cd["x"]))
	# point blank: every slug of both waves lands, with Anti-Heal; the waves 0.6s apart
	P.teleport(home)
	ak.fresh(T)
	T.teleport(home + Vector3(1.6, 0, 0))
	T.face = FACE_AWAY
	var times: Array = []
	_cast(P, T.pos)
	var w := B.waves
	var t := 0.0
	while t < 2.3:
		m.step(ak.DT)
		t += ak.DT
		if B.waves > w:
			w = B.waves
			times.append(t)
	var hits: Array = B.last_wave_hits
	ok(
		"ult beats: wave 1 at the end of the 1.1s charge, wave 2 0.6s later",
		times.size() == 2 and absf(float(times[0]) - 1.1) < 0.05
			and absf(float(times[1]) - float(times[0]) - 0.6) < 0.05,
		str(times)
	)
	ok(
		"ult payoff: point blank, all six slugs of each wave land",
		hits.size() == 2 and int(hits[0]) == 6 and int(hits[1]) == 6, str(hits)
	)
	var per := float(K.x_def()["dmg"]) * K.power("x")
	ok(
		"ult payoff: 4 a slug, no back bonus (12 slugs, target facing away)", absf(ak.dmg(T) - per * 12.0) < 0.6,
		"dmg %.1f expected %.1f" % [ak.dmg(T), per * 12.0]
	)
	ok("ult payoff: the slugs leave Anti-Heal", T.blight_t > 0.0, "%.1fs" % T.blight_t)
	ok(
		"ult bond: 12 slugs land, the cast still counts once (a hit: 0.6)",
		absf(_owed(P) - 0.6) < 0.001, "owed %.2f" % _owed(P)
	)
	# further out only the middle slugs reach
	ak.fresh(T)
	T.teleport(home + Vector3(4.6, 0, 0))
	_cast(P, T.pos)
	ak.step(m, 2.2)
	hits = B.last_wave_hits
	ok(
		"ult payoff: at 4.6m fewer slugs land (a shotgun fan, not a wall)",
		hits.size() == 2 and int(hits[0]) > 0 and int(hits[0]) < 6, str(hits)
	)
	await _reel_combo(m, P, T, home)
	await ak.done(m)

## Abyssal Hand, the foe hauled to your feet stunned, then the Broadside: every slug lands.
func _reel_combo(m: Match, P: Hunter, T: Hunter, home: Vector3) -> void:
	var K: DredgeKit = P.ak
	ak.fresh(T)
	T.teleport(home + Vector3(8.0, 0, 0))
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	ak.aim_at(P, T.pos)
	ak.tap(m, P)
	var t := 0.0
	while t < 3.0 and (K.flying or not K.pull.is_empty()):
		m.step(ak.DT)
		t += ak.DT
	_cast(P, T.pos)
	ak.step(m, 2.2)
	var hits: Array = K.broadside.last_wave_hits
	var n := int(hits[0]) + int(hits[1]) if hits.size() == 2 else 0
	ok("ult combo: reel the foe in, then the Broadside lands (10+ slugs)", K.arrivals >= 1 and n >= 10, "slugs %d" % n)

## A stun in the charge stops it (back in 8s); RMB, E and the barge are locked while it runs; a merge drops it.
func _guards() -> void:
	var r: Array = ak.setup("dredge", 1.6, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: DredgeKit = P.ak
	var B := K.broadside
	_cast(P, T.pos)
	ak.step(m, 0.4)
	var g0 := K.grapples
	var ch0 := K.ch_rmb
	ak.tap(m, P)
	P.ak.use_e()
	var x0 := P.pos
	P.dashes = P.max_dashes()
	P.ak.on_dash(false)
	ak.step(m, 0.1)
	ok(
		"ult: RMB and E are locked while it runs; Shift barges at once and it runs on, its pose kept (item 51)",
		K.ch_rmb == ch0 and K.grapples == g0 and K.wind <= 0.0 and P.flat_dist(x0) > 0.5 and B.charging()
				and K.anim_id == "dr_blast",
		"moved %.2f m, charging %s" % [P.pos.distance_to(x0), B.charging()]
	)
	P.stun_t = 0.5
	ak.step(m, 0.05)
	ok(
		"ult: a stun in the charge stops it, back in 8s",
		not B.running() and B.waves == 0 and float(K.cd["x"]) <= 8.0 and B.stopped == 1, "cd %.1f" % float(K.cd["x"])
	)
	P.stun_t = 0.0
	ak.step(m, 0.6)
	var waves0 := B.waves
	_cast(P, T.pos)
	ak.step(m, 0.3)
	P.dashes = P.max_dashes()
	P.do_dash()
	ak.step(m, 2.2)
	ok("ult: barged out of in the charge, both waves still go", not B.running() and B.waves == waves0 + 2,
			"waves +%d" % (B.waves - waves0))
	ak.step(m, 0.6)
	waves0 = B.waves
	_cast(P, T.pos)
	ak.step(m, 0.4)
	ok("merge hold: the Broadside is charging before the merge", B.charging())
	ok("merge hold: a merge is under way", ak.merge_now(P))
	ak.step(m, 1.8)
	ok(
		"merge hold: dredge's Broadside is dropped, no wave mid-merge", not B.running() and B.waves == waves0,
		"waves %d" % (B.waves - waves0)
	)
	KinMerge.end(P, "test")
	await ak.done(m)

func _burst() -> void:
	var res: Dictionary = await BURST.run(ak, "dredge", 1.6, func(m: Match, P: Hunter, T: Hunter):
		T.face = FACE_AWAY
		_cast(P, T.pos)
		ak.step(m, 2.2))
	var info := "ult %.0f, ult + merge %.0f of %d" % [res["ult"], res["total"], int(Data.CLASSES["light"]["hp"])]
	ok(
		"burst: Brass Broadside then the merge never one-shots a full-health light hunter",
		bool(res["merged"]) and bool(res["alive"]), info
	)
