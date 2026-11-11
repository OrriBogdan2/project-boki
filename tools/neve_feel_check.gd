extends RefCounted
## Neve (rimewright): no overhead badges, the ice shards stuck in the foe are the
## Shatter read; her Skate carves wide like a skater and slides out at the end. Runs on tools/support_check.gd's
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

## The carve: keys swung 90 degrees bend the skate gradually (no snap), and keys swung right round can't
## turn it back on itself within the whole skate (the old 3.6 rad/s did in 0.87 s).
func _carve() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	var dd := K.dash_def()
	_push_off(m, P)
	P.inp["move"] = Vector2(0, 1)
	step(m, 0.1)
	var early := rad_to_deg(absf(Vector2(1, 0).angle_to(K.rinkrun["dir"])))
	step(m, 0.5)
	var mid := rad_to_deg(absf(Vector2(1, 0).angle_to(K.rinkrun["dir"])))
	ok(
			"neve Shift: the carve leans in (under 8 deg in 0.1 s) and bends wide (25-60 deg in 0.6 s)",
			K.rinkrunning() and early < 8.0 and mid > 25.0 and mid < 60.0 and float(dd["steer"]) < OLD_STEER * 0.5,
			"%.1f then %.0f deg (steer %.1f rad/s, old %.1f)" % [early, mid, float(dd["steer"]), OLD_STEER])
	P.inp["dash_down"] = false
	step(m, 0.6)
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
	_push_off(m, P)
	step(m, 0.5)
	var skate_v := Vector2(P.vel.x, P.vel.z).length()
	P.inp["dash_down"] = false
	P.inp["move"] = Vector2.ZERO
	step(m, DT)
	var out_v := Vector2(P.vel.x, P.vel.z).length()
	var from := P.pos
	var t := 0.0
	while Vector2(P.vel.x, P.vel.z).length() > 0.05 and t < 1.0:
		step(m, DT)
		t += DT
	var slid := Vector2(P.pos.x - from.x, P.pos.z - from.z).length()
	ok(
			"neve Shift: letting go slides out (keeps about 70% of the speed, glides 0.6-1.6 m, stops within 0.5 s)",
			not K.rinkrunning() and P.grounded and out_v > 0.6 * skate_v and slid > 0.6 and slid < 1.6 and t < 0.5,
			"%.1f -> %.1f m/s, %.2f m in %.2f s" % [skate_v, out_v, slid, t])
	await _free(m)
