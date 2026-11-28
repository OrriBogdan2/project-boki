class_name GardenTrailCheck
extends RefCounted
## The garden half of --boki-follow-check (BaseGreet.trail, content/rules/base_life.json "trail"): your partner
## trails you on the base. You walk a straight line, stop, wait, cross to the far side of a house and step onto
## the Waystone; the home is stepped by hand (fixed DT, no rendering). Asserts: it keeps min..max m of you (a
## little lag allowed) while you walk, stops within STOP_S of you stopping, sits when you idle and gets up when
## you move, never stands in a block (house, toy, water, void), and waits outside the Waystone's ring instead
## of going through. Distances come from the rules file. Never touches the real save. Returns the failure count.

const DT := 0.1  # s per step
const SEED := 7
const WALK := 3.2  # m/s you walk at
const LAG := 0.8  # m of slack on the band while you accelerate or turn
const STOP_S := 3.0  # s a partner has to settle after you stop
const START_S := 12.0  # s the partner may take to start trailing (its think timer)
const REST_SPEED := 0.3  # m/s: under this it counts as stopped

var main: Node
var home
var r: Dictionary
var bad := 0
var inside := 0
var kin: Dictionary


func ok(cond: bool, what: String) -> void:
	print("BOKIFOLLOW %s garden: %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node) -> int:
	main = m
	r = BaseGreet.trail_rules()
	FarmUnlocks.rules()["base_mode"] = true
	_save()
	home = await _open("")
	_stage(true)
	_straight_walk()
	_rest_and_sit()
	_round_house()
	home.queue_free()
	home = await _open(GardenZones.HUB)
	_stage(false)
	_waystone()
	home.queue_free()
	FarmUnlocks.rules()["base_mode"] = false
	ok(inside == 0, "it never stood in a block, the house, a toy or water (%d steps inside)" % inside)
	return bad


func _save() -> void:
	var d := Save.fresh()
	for i in 2:
		var rec := Save.new_kin(["zapple", "cindle"][i], "T%d" % i, SEED + i)
		rec["uid"] = "trail%d" % i
		Care.ensure(rec)
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	HomeLayout.new_fs(d, SEED)
	Save.d = d


func _open(zone: String) -> Node:
	if zone == "":
		return await main._hb_home()
	var hm: Node = load("res://scripts/home/home.gd").new()
	hm.zone = zone
	main.add_child(hm)
	main.current = hm
	for i in 2:
		await main.get_tree().process_frame
	while hm.building:
		await main.get_tree().process_frame
	return hm


## The partner next to you on open ground, the house placed off to one side.
func _stage(with_house: bool) -> void:
	home.set_process(false)
	seed(SEED)
	home.day_t = 0.5
	var land := HomeLayout.LANDING
	if with_house:
		home.hg.demo_place("house", land + Vector3(7.0, 0, -4.0))
		home.hb.apply(false)
		home._sync_fixtures()
	home.ppos = land + Vector3(0, 0, 1.0)
	home.pvel = Vector3.ZERO
	home.player.position = home.ppos
	kin = home.kins.filter(func(k): return GardenZones.is_partner(k["rec"]))[0]
	for k in home.kins:
		if k != kin:
			k["pos"] = home.world.free_spot_near(land + Vector3(-9.0, 0, 6.0), [], 0.8)
			k["node"].position = k["pos"]
			k["goal"] = k["pos"]
	kin["pos"] = home.world.free_spot_near(home.ppos + Vector3(0, 0, 2.5), [], 0.8)
	kin["node"].position = kin["pos"]
	kin["goal"] = kin["pos"]
	var waited := 0.0
	while not kin.has("life_greet") and waited < START_S:
		_run_for(DT)
		waited += DT
	ok(kin.has("life_greet"), "it starts trailing you within %.0f s (%.1f s)" % [START_S, waited])
	_run_for(2.0)


## One step: you move at `dir` * speed (or stand), the farm steps.
func _step(dir: Vector2, speed: float) -> void:
	home.pvel = Vector3(dir.x, 0, dir.y) * speed
	if speed > 0.0:
		home.pface = atan2(-dir.x, -dir.y)
		var nx: float = home.ppos.x + dir.x * speed * DT
		var nz: float = home.ppos.z + dir.y * speed * DT
		if home.world.occupy(nx, nz, 0.4, 0.0, true) == 0.0 and not home.world.is_void(nx, nz):
			home.ppos = Vector3(nx, home.ppos.y, nz)
		else:
			home.pvel = Vector3.ZERO
	home.player.position = home.ppos
	home._move_kin(DT)
	var p: Vector3 = kin["pos"]
	if not kin.has("leap") and (home.world.occupy(p.x, p.z, 0.0, 0.0, true) != 0.0 or home.world.is_void(p.x, p.z)):
		inside += 1


func _run_for(secs: float, dir := Vector2.ZERO, speed := 0.0) -> void:
	for i in int(secs / DT):
		_step(dir, speed)


func _gap() -> float:
	return Vector2(kin["pos"].x - home.ppos.x, kin["pos"].z - home.ppos.z).length()


func _speed() -> float:
	return Vector2(kin["vel"].x, kin["vel"].z).length()


## The longest open run (m) from you along `dir`.
func _clear_run(dir: Vector2) -> float:
	var d := 0.0
	while d < 30.0:
		var p: Vector3 = home.ppos + Vector3(dir.x, 0, dir.y) * (d + 1.0)
		if home.world.is_void(p.x, p.z) or home.world.occupy(p.x, p.z, 0.5, 0.0, true) != 0.0:
			break
		d += 1.0
	return d


func _straight_walk() -> void:
	var best := Vector2.RIGHT
	for c in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		if _clear_run(c) > _clear_run(best):
			best = c
	var secs := minf(_clear_run(best) / WALK - 1.0, 7.0)
	ok(secs >= 4.0, "a straight run of %.1f s is open to walk" % secs)
	_run_for(2.5, best, WALK)  # it gets going
	var lo := 99.0
	var hi := 0.0
	for i in int((secs - 2.5) / DT):
		_step(best, WALK)
		lo = minf(lo, _gap())
		hi = maxf(hi, _gap())
	var fits := lo >= float(r["min_m"]) - LAG and hi <= float(r["max_m"]) + LAG
	var band := "walking, it keeps %.1f..%.1f m from you (band %.0f..%.0f m, %s)"
	ok(fits, band % [lo, hi, r["min_m"], r["max_m"], (kin["life"] as Fsm).state_name()])
	_run_for(STOP_S)
	var settled := _gap() >= float(r["min_m"]) - 0.4 and _gap() <= float(r["max_m"]) + 0.4
	var line := "you stop, it stops within %.0f s, %.1f m off (%.2f m/s)"
	ok(_speed() < REST_SPEED and settled, line % [STOP_S, _gap(), _speed()])


func _rest_and_sit() -> void:
	ok(not kin.has("sat"), "it is not sitting while you have only just stopped")
	_run_for(float(r["sit_s"]) + 2.0)
	ok(kin.has("sat") and _speed() < REST_SPEED, "you idle %.0f s: it sits" % r["sit_s"])
	var away := Vector2.LEFT if _clear_run(Vector2.LEFT) > _clear_run(Vector2.RIGHT) else Vector2.RIGHT
	_run_for(1.5, away, WALK)
	ok(not kin.has("sat"), "you move: it gets up")


## You cross to the far side of the house: it has to find its way round, not through.
func _round_house() -> void:
	var far := Vector3(HomeLayout.LANDING.x + 14.0, 0, HomeLayout.LANDING.z - 4.0)
	home.ppos = home.world.free_spot_near(far, [], 1.0)
	home.player.position = home.ppos
	home.pvel = Vector3.ZERO
	_run_for(12.0)
	var near := _gap() <= float(r["max_m"]) + 0.4 or kin.has("leap")
	ok(near, "you cross the house: it comes round to %.1f m of you" % _gap())


## In the hub you stand on the Waystone: it waits at the ring and is still there when you travel.
func _waystone() -> void:
	var stone: Vector3 = home.hway.node.position
	home.ppos = home.world.free_spot_near(stone + Vector3(0, 0, 1.2), [], 0.5)
	home.player.position = home.ppos
	_run_for(10.0)
	var ring := float(r["pad_m"])
	var off := Vector2(kin["pos"].x - stone.x, kin["pos"].z - stone.z).length()
	var wait := "you stand on the Waystone: it waits %.1f m off (ring %.1f m), not on it"
	ok(off >= ring - 0.5, wait % [off, ring])
	home.hway.hopping = "bramblebank"
	var at: Vector3 = kin["pos"]
	_run_for(3.0)
	var still := Vector2(kin["pos"].x - at.x, kin["pos"].z - at.z).length()
	var held: bool = still < 0.3 and home.kins.has(kin) and not kin.has("zone_go")
	ok(held, "the stone lights for the hop: it holds still (%.2f m)" % still)
	home.hway.hopping = ""
