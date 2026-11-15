extends RefCounted
## Neve (rimewright): no overhead badges, the ice shards stuck in the foe are the
## Shatter read; her Skate carves wide like a skater and slides out at the end,
## and sounds it (RimeSkateSfx). Runs on tools/support_check.gd's
## setup (--neve-feel-check, and inside --rimewright-combo-check).

const DT := 1.0 / 60.0
const OLD_STEER := 3.6         # rad/s: the old instant turn rate (a U-turn in 0.87 s); the carve stays under half

var sc        # the SupportCheck running us

func ok(what: String, cond: bool, info := "") -> void:
	sc.ok(what, cond, info)

func step(m: Match, secs: float) -> void:
	sc.step(m, secs)

func _free(m: Match) -> void:
	m.queue_free()
	await sc.main.get_tree().process_frame

func run_all() -> void:
	await _shards()
	await _carve()
	await _slide_out()

## Shards out on the foe's body (-1: the look is not up).
func _shards_out(K: RimewrightKit, T: Ent) -> int:
	var key := "shards%d" % T.get_instance_id()
	if not K.lk().showing(key):
		return -1
	var n: Node3D = K.lk().held[key]["n"]
	return n.get_children().filter(func(c): return (c as Node3D).visible).size()

func _darts(K: RimewrightKit, T: Ent, count: int) -> void:
	for i in count:
		K.on_deal(T, 1.0, {"ab": "fan"})

func _shards() -> void:
	var r: Array = sc.setup("rimewright", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var K: RimewrightKit = P.ak
	_darts(K, T, 3)
	step(m, 0.3)
	var marks: Array = []
	K.combo_marks(marks)
	ok(
			"neve: no overhead badges on a Chilled, stacked foe, the shards are the read",
			marks.is_empty() and (K.cue.get("marks", []) as Array).is_empty() and K.chilled(T),
			"%d badges" % marks.size())
	var three := _shards_out(K, T)
	_darts(K, T, 4)
	step(m, 0.3)
	var seven := _shards_out(K, T)
	ok("neve: one ice shard sticks in the foe per dart (3 darts: 3, 7 darts: 7)", three == 3 and seven == 7,
			"%d then %d" % [three, seven])
	step(m, RimewrightKit.FAN_HOLD + 0.2)
	ok("neve: the shards are gone once the stacks run out", _shards_out(K, T) == -1)
	var s0 := K.splinter_log
	_darts(K, T, 5)
	step(m, 0.1)
	var before := _shards_out(K, T)
	_darts(K, T, 3)
	step(m, 0.4)
	ok(
			"neve: the eighth dart Shatters the foe and takes the shards with it",
			before == 5 and K.splinter_log > s0 and _shards_out(K, T) == -1,
			"%d before, shattered %s" % [before, K.splinter_log > s0])
	var made := K.lk().made
	for i in 3:
		_darts(K, T, 4)
		step(m, RimewrightKit.FAN_HOLD + 0.2)
	ok("neve: the shard look is pooled (no new nodes on later stacks)", K.lk().made == made,
			"%d -> %d" % [made, K.lk().made])
	await _free(m)

## Starts a skate along +x on the ground and returns once it runs.
func _push_off(m: Match, P: Hunter) -> void:
	P.dashes = 1.0
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(m, DT)
	P.inp["dash"] = false

## Another player's Neve standing beside her: her game runs no kit, only the sounds off the synced state.
func _remote_copy(m: Match, P: Hunter) -> Hunter:
	var R := m.make_hunter("neve_remote", P.team, P.cls, "Remote", "idle", {}, P.pos + Vector3(0, 0, 3),
			{"arch": "rimewright"})
	R.remote = true
	return R

## What the net brings her copy each step: her move (ArchKit.net_move) and her velocity.
func _mirror(P: Hunter, R: Hunter) -> void:
	var it := []
	it.resize(ArchKit.NET_MOVE_AT + 2)
	var mv := ArchKit.net_move(P)
	it[ArchKit.NET_MOVE_AT] = mv[0]
	it[ArchKit.NET_MOVE_AT + 1] = mv[1]
	ArchKit.apply_net_move(R, it)
	R.net_vel = P.vel

## The carve: keys swung 90 degrees bend the skate gradually (no snap), and keys swung right round can't
## turn it back on itself within the whole skate (the old 3.6 rad/s did in 0.87 s).
func _carve() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	var dd := K.dash_def()
	var R := _remote_copy(m, P)
	var snd := K.skate_snd
	_push_off(m, P)
	P.inp["move"] = Vector2(0, 1)
	var carve := {"n": 0, "first": 0.0, "top": -99.0, "near": 0.0, "glide": true}
	var listen := func() -> void:
		_mirror(P, R)
		if float(K.rinkrun.get("t", 0.0)) > 2.0 * DT:       # the sound reads the step before (one behind the kit)
			carve["glide"] = bool(carve["glide"]) and Sfx.loop_on(snd.glide_key)
		if int(snd.stats["carve"]) == int(carve["n"]):
			return
		carve["n"] = int(snd.stats["carve"])
		var db := float(snd.stats["carve_db"])
		if int(carve["n"]) == 1: carve["first"] = db
		if db > float(carve["top"]):
			carve["top"] = db
			carve["near"] = absf(float(K.rinkrun.get("rate", 0.0))) / float(dd["steer"])
	sc.step(m, 0.1, listen)
	var early := rad_to_deg(absf(Vector2(1, 0).angle_to(K.rinkrun["dir"])))
	sc.step(m, 0.5, listen)
	var mid := rad_to_deg(absf(Vector2(1, 0).angle_to(K.rinkrun["dir"])))
	ok(
			"neve Shift: the carve leans in (under 8 deg in 0.1 s) and bends wide (25-60 deg in 0.6 s)",
			K.rinkrunning() and early < 8.0 and mid > 25.0 and mid < 60.0 and float(dd["steer"]) < OLD_STEER * 0.5,
			"%.1f then %.0f deg (steer %.1f rad/s, old %.1f)" % [early, mid, float(dd["steer"]), OLD_STEER])
	var most_n := int(ceilf(0.6 / RimeSkateSfx.CARVE_GAP)) + 1
	ok(
			"neve Shift sound: the skate loop holds, the carve scrapes throttled (one per %.2f s) and rising to the cap"
				% RimeSkateSfx.CARVE_GAP,
			bool(carve["glide"]) and int(carve["n"]) >= 2 and int(carve["n"]) <= most_n
				and float(carve["top"]) > float(carve["first"]) + 2.0 and float(carve["near"]) > 0.85,
			"%d scrapes (at most %d), %.1f -> %.1f dB, loudest at %.0f%% of the cap"
				% [carve["n"], most_n, carve["first"], carve["top"], float(carve["near"]) * 100.0])
	P.inp["dash_down"] = false
	sc.step(m, 0.6, listen)
	ok(
			"neve Shift sound: another player's game hears the glide and the carve (her synced move and velocity)",
			int(R.ak.skate_snd.stats["carve"]) >= 2 and not Sfx.loop_on(snd.glide_key),
			"%d remote scrapes" % int(R.ak.skate_snd.stats["carve"]))
	_push_off(m, P)
	P.inp["move"] = Vector2(-1, 0.05)
	var most := 0.0
	while K.rinkrunning():
		most = maxf(most, rad_to_deg(absf(Vector2(1, 0).angle_to(K.rinkrun["dir"]))))
		step(m, DT)
	ok("neve Shift: keys held back can't turn a whole skate round (under 150 deg in 1.6 s)",
			most > 60.0 and most < 150.0, "%.0f deg" % most)
	P.inp["dash_down"] = false
	await _free(m)

## The slide-out: let go and she glides on about a metre on the ground brake, not a dead stop.
func _slide_out() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	var R := _remote_copy(m, P)
	var snd := K.skate_snd
	var mirror := func() -> void: _mirror(P, R)
	_push_off(m, P)
	sc.step(m, 0.5, mirror)
	var skate_v := Vector2(P.vel.x, P.vel.z).length()
	var straight := int(snd.stats["carve"])
	P.inp["dash_down"] = false
	P.inp["move"] = Vector2.ZERO
	sc.step(m, DT, mirror)
	var out_v := Vector2(P.vel.x, P.vel.z).length()
	var from := P.pos
	var t := 0.0
	var hiss0 := float(snd.stats["hiss_t"])
	var remote_hiss := false
	while Vector2(P.vel.x, P.vel.z).length() > RimeSkateSfx.STILL_V and t < 1.0:
		sc.step(m, DT, mirror)
		t += DT
		remote_hiss = remote_hiss or bool(R.ak.skate_snd.stats["hiss"])
	var slid := Vector2(P.pos.x - from.x, P.pos.z - from.z).length()
	ok(
			"neve Shift: letting go slides out (keeps about 70% of the speed, glides 0.6-1.6 m, stops within 0.5 s)",
			not K.rinkrunning() and P.grounded and out_v > 0.6 * skate_v and slid > 0.6 and slid < 1.6 and t < 0.5,
			"%.1f -> %.1f m/s, %.2f m in %.2f s" % [skate_v, out_v, slid, t])
	sc.step(m, DT, mirror)       # the sound reads the step she stopped on
	var hissed := float(snd.stats["hiss_t"]) - hiss0
	ok(
			"neve Shift sound: the slide-out hisses exactly as long as she slides and stops when she does",
			absf(hissed - t) <= 2.0 * DT and not bool(snd.stats["hiss"]) and not Sfx.loop_on(snd.hiss_key),
			"hiss %.3f s for a %.3f s slide-out" % [hissed, t])
	ok(
			"neve Shift sound: a straight skate never carves, and another player's game hears the hiss too",
			straight == 0 and remote_hiss and not bool(R.ak.skate_snd.stats["hiss"]),
			"%d straight scrapes, remote hiss %s" % [straight, remote_hiss])
	await _free(m)
