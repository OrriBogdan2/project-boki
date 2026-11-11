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
	await _carve_beams()
	await _carve_wall()
	await _carve_rime()
	await _slide_out_presses()

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

## Her shots in flight.
func _mine(m: Match, P: Hunter) -> Array:
	return m.shots.filter(func(s): return s["by"] == P)

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

## The skate's heading after `secs` of carving toward +z (keys swung 90 degrees off the push-off), firing or not.
func _carve_heading(fire: bool, secs: float) -> Array:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	_push_off(m, P)
	P.inp["move"] = Vector2(0, 1)
	sc.aim_at(P, P.pos + Vector3(-6.0, 0, -6.0))     # the cursor behind her, off the skate's way
	P.inp["fire"] = fire
	var worst := 0.0
	var seen := {}
	var t := 0.0
	while t < secs:
		step(m, DT)
		t += DT
		var want := Vector2(P.inp["aim"].x - P.pos.x, P.inp["aim"].z - P.pos.z)
		for s in _mine(m, P):
			if not seen.has(s["sid"]):
				seen[s["sid"]] = true
				worst = maxf(worst, rad_to_deg(absf(want.angle_to(s["vel"]))))
	var heading := rad_to_deg(Vector2(1, 0).angle_to(K.rinkrun.get("dir", Vector2.ZERO)))
	var out := [heading, int(K.stats["beams"]), worst]
	P.inp["fire"] = false
	P.inp["dash_down"] = false
	await _free(m)
	return out

## Skate -> LMB on the carve: the beams leave straight at the cursor (behind her, wherever the carve heads)
## and firing leaves the carve as it was (her facing turns to the cursor, her line does not).
func _carve_beams() -> void:
	var dry: Array = await _carve_heading(false, 0.5)
	var wet: Array = await _carve_heading(true, 0.5)
	ok(
			"neve Shift -> LMB: carving, the beams leave at the cursor (within 6 deg) and the carve is unchanged",
			int(wet[1]) >= 2 and float(wet[2]) < 6.0 and absf(float(wet[0]) - float(dry[0])) < 1.0,
			"%d beams, worst %.1f deg off; heading %.1f firing vs %.1f not" % [wet[1], wet[2], wet[0], dry[0]])

## Skate -> E on the carve: the wall goes where the cursor was on the press (not along the carve) and the
## skate carves on through the tell.
func _carve_wall() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	_push_off(m, P)
	P.inp["move"] = Vector2(0, 1)
	step(m, 0.2)
	sc.aim_at(P, P.pos + Vector3(8.0, 0, 0))
	P.inp["sig"] = true
	step(m, DT)
	P.inp["sig"] = false
	step(m, 0.25)
	var wd: Vector2 = K.wall.get("dir", Vector2.ZERO)
	ok(
			"neve Shift -> E: carving, the wall slides along the aim of the press and the skate goes on",
			not K.wall.is_empty() and wd.dot(Vector2(1, 0)) > 0.99 and K.rinkrunning(),
			"wall dir %s, skating %s" % [wd, K.rinkrunning()])
	P.inp["dash_down"] = false
	await _free(m)

## Skate -> X on the carve: the statue slides straight on along the heading of the cast frame (no more carve,
## the keys still held to the side), then she is rooted.
func _carve_rime() -> void:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	K.cd["x"] = 0.0
	_push_off(m, P)
	P.inp["move"] = Vector2(0, 1)
	step(m, 0.35)
	var dir0: Vector2 = K.rinkrun["dir"]
	var bent := rad_to_deg(absf(Vector2(1, 0).angle_to(dir0)))
	HunterKeys.ult_pressed(P)
	P.inp["dash_down"] = false
	var worst := 1.0
	for i in int(float(K.x_def()["carry_t"]) * 60.0) - 6:
		var q := P.pos
		step(m, DT)
		var dv := Vector2(P.pos.x - q.x, P.pos.z - q.z)
		if dv.length() > 0.001:
			worst = minf(worst, dv.normalized().dot(dir0))
	ok(
			"neve Shift -> X: cast mid-carve, the statue slides straight along the cast frame's heading (no carve)",
			K.ult_running() and bent > 10.0 and worst > 0.995,
			"bent %.0f deg at the cast, direction dot %.4f" % [bent, worst])
	P.inp["move"] = Vector2.ZERO
	await _free(m)

## A skate let go after 0.5 s: returns [m, P, K] on the first frame of the slide-out.
func _sliding() -> Array:
	var r: Array = sc.setup("rimewright", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	K.cd["x"] = 0.0
	_push_off(m, P)
	step(m, 0.5)
	P.inp["dash_down"] = false
	P.inp["move"] = Vector2.ZERO
	step(m, DT)
	return [m, P, K]

## Presses in the slide-out: the skate is over on the release (the source's "release to stop"), so LMB throws
## plain darts, X roots her at once (no statue slide), Shift with no charge is refused and the slide goes on,
## and a jump takes off with the slide's speed (the shared jump keeps its run-up).
func _slide_out_presses() -> void:
	var r: Array = _sliding()
	var P: Hunter = r[1]
	var K: RimewrightKit = r[2]
	var beams := int(K.stats["beams"])
	var darts := int(K.stats["darts"])
	P.inp["fire"] = true
	step(r[0], DT)
	P.inp["fire"] = false
	ok(
			"neve slide-out -> LMB: a plain dart, not a beam (the skate ended on the release)",
			not K.in_dash() and int(K.stats["darts"]) == darts + 1 and int(K.stats["beams"]) == beams,
			"darts +%d, beams +%d" % [int(K.stats["darts"]) - darts, int(K.stats["beams"]) - beams])
	await _free(r[0])
	r = _sliding()
	P = r[1]
	K = r[2]
	var v0 := Vector2(P.vel.x, P.vel.z).length()
	HunterKeys.ult_pressed(P)
	step(r[0], 2.0 * DT)
	var v1 := Vector2(P.vel.x, P.vel.z).length()
	ok(
			"neve slide-out -> X: rooted at once, the slide is dropped (no statue slide)",
			K.ult_running() and K.anim_id == "tm_rime" and v0 > 5.0 and v1 < 0.01,
			"%.1f -> %.2f m/s" % [v0, v1])
	await _free(r[0])
	r = _sliding()
	P = r[1]
	K = r[2]
	v0 = Vector2(P.vel.x, P.vel.z).length()
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	step(r[0], DT)
	P.inp["dash"] = false
	P.inp["dash_down"] = false
	v1 = Vector2(P.vel.x, P.vel.z).length()
	ok(
			"neve slide-out -> Shift: no charge left, refused; the slide goes on under the brake",
			not K.rinkrunning() and P.dashes < 1.0 and v1 > 0.7 * v0 and v1 < v0,
			"%.1f -> %.1f m/s, %.2f charges" % [v0, v1, P.dashes])
	await _free(r[0])
	r = _sliding()
	P = r[1]
	v0 = Vector2(P.vel.x, P.vel.z).length()
	P.inp["jump"] = true
	step(r[0], DT)
	P.inp["jump"] = false
	step(r[0], 0.1)
	v1 = Vector2(P.vel.x, P.vel.z).length()
	ok(
			"neve slide-out -> jump: she takes off with the slide's speed (over 80% of it 0.1 s up)",
			not P.grounded and v1 > 0.8 * v0,
			"%.1f -> %.1f m/s" % [v0, v1])
	await _free(r[0])
