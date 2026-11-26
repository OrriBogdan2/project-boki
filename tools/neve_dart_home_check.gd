extends RefCounted
## --neve-dart-home-check: Neve's (rimewright) ice darts against a strafing dummy. Each row taps a burst at a dummy
## that runs sideways (STRAFE m/s, one reversing mid-flight, a juke) and follows its plain dart (or its first large
## one): the dart must hit within HIT_K x its straight-line flight time, and never orbit (its heading turns under
## MAX_TURN degrees in all). Prints NDH PASS/FAIL lines and a DONE line.

const DT := 1.0 / 60.0
const STRAFE := 5.0  # m/s: the dummy's sideways run (a hunter strafing)
const HIT_K := 1.3  # x the straight-line time (distance / dart speed) the hit must land within
const MAX_TURN := 90.0  # degrees: the most a dart's heading may turn over its flight (an orbit turns 360)
## [distance m, side +1/-1, s into the flight it reverses (-1: never), the first large dart (not the plain one)]
const ROWS := [
	[8.0, 1.0, -1.0, false],
	[8.0, -1.0, -1.0, false],
	[10.0, 1.0, -1.0, false],
	[10.0, -1.0, -1.0, false],
	[8.0, 1.0, 0.2, false],
	[10.0, 1.0, -1.0, true],
	[10.0, -1.0, -1.0, true],
]

var main: Node
var ac: RefCounted
var fails := 0


func ok(what: String, cond: bool, info := "") -> void:
	print("NDH %-72s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	Save.no_write = true
	main = main_node
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main_node
	for row in ROWS:
		await _row(float(row[0]), float(row[1]), float(row[2]), bool(row[3]))
	print("NDH DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)


func _row(dist: float, side: float, juke: float, heavy: bool) -> void:
	var r: Array = ac.setup("rimewright", dist)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var k: RimewrightKit = p.ak
	ac.aim_at(p, t.pos)
	p.inp["fire"] = true
	m.step(DT)
	p.inp["fire"] = false
	var dart := _dart(k, heavy)
	var wait := 0.0
	while dart.is_empty() and wait < 1.0:  # (the large ones follow the plain dart, one every wpn.rate)
		t.teleport(t.pos + Vector3(0, 0, side * STRAFE * DT))
		ac.aim_at(p, t.pos)
		m.step(DT)
		wait += DT
		dart = _dart(k, heavy)
	var hp0 := t.hp
	var head0: Vector2 = dart.get("vel", Vector2.RIGHT)
	var prev := head0
	var turned := 0.0
	var age := 0.0
	var hit_at := -1.0
	var way := side
	while m.shots.has(dart) and age < 2.0:
		if juke >= 0.0 and age >= juke:
			way = -side
		t.teleport(t.pos + Vector3(0, 0, way * STRAFE * DT))
		var last: Vector3 = dart["pos"]
		m.step(DT)
		age += DT
		var v: Vector2 = dart["vel"]
		turned += absf(rad_to_deg(prev.angle_to(v)))
		prev = v
		if not m.shots.has(dart) and t.hp < hp0 and Vector2(last.x - t.pos.x, last.z - t.pos.z).length() < 1.5:
			hit_at = age
	var flat := Vector2(t.pos.x - p.pos.x, t.pos.z - p.pos.z).length()
	var straight := flat / head0.length()
	var kind := "large" if heavy else "plain"
	var what := "%s, %.0f m, strafing %s" % [kind, dist, "left" if side < 0.0 else "right"]
	if juke >= 0.0:
		what += ", juke at %.1f s" % juke
	ok(
		"neve %s: hits within %.1fx the straight flight, never orbits" % [what, HIT_K],
		hit_at > 0.0 and hit_at <= straight * HIT_K and turned < MAX_TURN,
		"hit at %.2f s (straight %.2f s), turned %.0f deg" % [hit_at, straight, turned]
	)
	await ac.done(m)


## The first plain (or large) dart in flight, {} none yet.
func _dart(k: RimewrightKit, heavy: bool) -> Dictionary:
	for d in k.darts:
		if bool((d["s"]["x"] as Dictionary).get("heavy", false)) == heavy:
			return d["s"]
	return {}
