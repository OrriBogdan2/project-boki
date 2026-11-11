extends RefCounted
## The scattergun for --dredge-combo-check (docs/heroes/dredge.md): a volley he waits for is all seven slugs in a
## tight cluster on the aim line (not one slug), firing again at once fans them wide, a short pause keeps the fan,
## holding off past the fire rate draws it back in gradually; the spread's edge lines show the next volley's fan,
## follow the body and the aim on the drawn frame, and glide instead of jumping.

const SHORT_PAUSE := 0.3            # s off the trigger, under the fire rate (0.5)
const PART_PAUSE := 0.65            # s off the trigger: the fan has started drawing in, not finished
const LONG_PAUSE := 1.0             # s off the trigger, past the draw-in
const CLUSTER_AT := 5.5             # m to the dummy for the hit count, inside the 6.3 m slug range

var ak = null
var ok_fn: Callable

func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb

func ok(label: String, cond: bool, info := "") -> void:
	ok_fn.call(label, cond, info)

func run() -> void:
	var r: Array = ak.setup("dredge", 9.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	T.teleport(P.pos + Vector3(0, 0, 9.0))
	_fans(m, P)
	_cluster_lands(m, P, T)
	_aimer(m, P)
	await ak.done(m)

## The fan of each volley through a burst, pauses of three lengths and a waited shot.
func _fans(m: Match, P: Hunter) -> void:
	var tight: float = float(P.wpn["fan_deg"]) * 0.5
	var wide: float = tight + float(P.wpn["bloom_max_deg"]) * 0.5
	var vols: Array = []            # per volley: each slug's angle off the aim line, in degrees, sorted
	vols.append_array(_hold(m, P, 3))
	_release(m, P, SHORT_PAUSE)
	vols.append_array(_hold(m, P, 1))
	_release(m, P, PART_PAUSE)
	vols.append_array(_hold(m, P, 1))
	_release(m, P, LONG_PAUSE)
	vols.append_array(_hold(m, P, 1))
	var half: Array = vols.map(func(a: Array) -> float: return maxf(absf(a[0]), absf(a[a.size() - 1])))
	var info := "half-fans %s" % str(half.map(func(x: float) -> String: return "%.1f" % x))
	var first: Array = vols[0]
	ok(
		"gun: a waited volley is all seven slugs packed in a tight cluster on the aim line, not one slug",
		_distinct(first) == int(P.wpn["pellets"]) and absf(float(half[0]) - tight) < 0.3 and tight >= 2.0
		and absf(float(first[0]) + float(first[first.size() - 1])) < 0.3,
		"%s, slugs %s" % [info, str(first)]
	)
	ok("gun: firing again at once fans the slugs wide", half[1] > tight * 3.0 and half[2] >= half[1], info)
	ok("gun: a short pause keeps the fan wide", half[3] > tight * 3.0, info)
	ok(
		"gun: holding off past the fire rate draws the fan in part-way (no snap)",
		half[4] > tight + 2.0 and half[4] < wide - 2.0, info
	)
	ok("gun: after a longer pause the volley is the tight cluster again", absf(float(half[5]) - tight) < 0.3, info)

## Damage stays the volley's: on a foe straight ahead inside the slug range, the waited cluster lands all seven.
func _cluster_lands(m: Match, P: Hunter, T: Hunter) -> void:
	_release(m, P, LONG_PAUSE)
	T.teleport(P.pos + Vector3(CLUSTER_AT, 0, 0))
	ak.fresh(T)
	var seen := P.shot_n
	_hold(m, P, 1)
	ak.step(m, 0.6)
	var pg := "%s_%d|%s" % [P.nid, seen + 1, T.nid if T.nid != "" else str(T.get_instance_id())]
	var hits := int(m.pellet_hits.get(pg, 0))
	ok(
		"gun: every slug of a waited cluster lands on a foe %.1fm ahead" % CLUSTER_AT,
		hits == int(P.wpn["pellets"]), "hits %d" % hits
	)
	T.teleport(P.pos + Vector3(0, 0, 9.0))

## The edge lines: the next volley's true fan, glided per drawn frame, from the drawn body toward this frame's aim.
func _aimer(m: Match, P: Hunter) -> void:
	var d := AimKit.layer(m)
	var k := AimDraw.key(P, "spread")
	_release(m, P, LONG_PAUSE)
	var e: Dictionary = AimKit.entry(P, "spread")
	var tight := float(P.wpn["fan_deg"])
	ok(
		"aimer: idle, the edge lines sit at the tight cluster's fan",
		not e.is_empty() and absf(float(e["deg"]) - tight) < 0.01, "deg %.1f" % float(e.get("deg", -1.0))
	)
	d.track(1.0)
	_hold(m, P, 1)
	m.step(ak.DT)
	e = d.entries[k]
	var want := tight + P.wbloom
	var before := float(e["deg_at"])
	d.track(1.0 / 60.0)
	var one := float(e["deg_at"])
	ok(
		"aimer: after a shot the fan widens over frames, no jump",
		float(e["deg"]) == want and one > before and one < want,
		"from %.1f to %.1f, one frame %.1f" % [before, want, one]
	)
	e["deg_at"] = before
	for i in 4:
		d.track(1.0 / 240.0)
	ok(
		"aimer: the glide is the same at 60 and 240 frames a second", absf(float(e["deg_at"]) - one) < 0.01,
		"%.3f vs %.3f" % [float(e["deg_at"]), one]
	)
	for i in 9:
		d.track(1.0 / 60.0)
	var settled := float(e["deg_at"])
	ok("aimer: within 0.15 s the fan is on the gun's", absf(settled - want) < 0.5, "%.2f" % settled)
	# a drawn frame between steps: the body drawn ahead of the step, the cursor moved; no step runs
	P.global_position = P.pos + Vector3(0.12, 0, 0.05)
	ak.aim_at(P, P.pos + Vector3(0, 0, -4.0))
	d.track(1.0 / 144.0)
	var body := Vector2(P.global_position.x, P.global_position.z)
	ok(
		"aimer: the edge lines start at the drawn body and point at this frame's aim",
		(e["from"] as Vector2).distance_to(body) < 0.001 and (e["dir"] as Vector2).dot(P.aim_dir()) > 0.9999,
		"from %s body %s dir %s" % [e["from"], body, e["dir"]]
	)

## Holds fire on the east until `count` new volleys leave; returns each one's slug angles off the aim line.
func _hold(m: Match, P: Hunter, count: int) -> Array:
	var out: Array = []
	var seen := P.shot_n
	var t := 0.0
	while out.size() < count and t < 3.0:
		ak.aim_at(P, P.pos + Vector3(2.0, 0, 0))
		P.inp["fire"] = true
		m.step(ak.DT)
		t += ak.DT
		if P.shot_n != seen:
			seen = P.shot_n
			out.append(_angles(m, P, "%s_%d" % [P.nid, P.shot_n]))
	P.inp["fire"] = false
	return out

func _release(m: Match, P: Hunter, secs: float) -> void:
	P.inp["fire"] = false
	ak.step(m, secs)

func _angles(m: Match, P: Hunter, pg: String) -> Array:
	var aim := P.aim_dir()
	var out: Array = []
	for sd in m.shots:
		if sd["by"] == P and String((sd["x"] as Dictionary).get("pg", "")) == pg:
			out.append(rad_to_deg(aim.angle_to(sd["vel"] as Vector2)))
	out.sort()
	return out

## Slugs on separate lines (0.2 degrees apart or more).
func _distinct(angles: Array) -> int:
	var n := 0
	var last := -INF
	for a: float in angles:
		if a - last >= 0.2:
			n += 1
		last = a
	return n
