extends RefCounted
## The scattergun for --dredge-combo-check (docs/heroes/dredge.md): every volley is all seven slugs in a tight
## group on the aim line (not one slug, not a fan), shots in a row stay as tight; one aim line shows the aim,
## following the drawn body and the aim on the drawn frame.

const LONG_PAUSE := 1.0             # s off the trigger
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
	_muzzle(m, P)
	_cluster_lands(m, P, T)
	_aimer(m, P)
	await ak.done(m)

## Every volley of a burst and one after a pause: all seven slugs in the same tight group on the aim line.
func _fans(m: Match, P: Hunter) -> void:
	var half_fan: float = float(P.wpn["fan_deg"]) * 0.5
	var vols: Array = _hold(m, P, 3)            # per volley: each slug's angle off the aim line, in degrees, sorted
	_release(m, P, LONG_PAUSE)
	vols.append_array(_hold(m, P, 1))
	var info := "slugs %s" % str(vols[0])
	ok(
		"gun: a volley is all seven slugs packed in a tight group on the aim line, not one slug",
		_distinct(vols[0]) == int(P.wpn["pellets"]) and half_fan >= 1.0 and half_fan <= 5.0
		and absf(float(vols[0][0]) + float(vols[0][vols[0].size() - 1])) < 0.3,
		info
	)
	var same := true
	for v: Array in vols:
		same = same and absf(maxf(absf(v[0]), absf(v[v.size() - 1])) - half_fan) < 0.3
	ok("gun: firing again at once keeps the group as tight (no bloom), and so does a volley after a pause", same, info)

## Every slug of a volley leaves the blunderbuss's one muzzle point (not a ring round his body) and its hit sweep
## starts at the body, so a volley fired against a wall still stops at the wall.
func _muzzle(m: Match, P: Hunter) -> void:
	_release(m, P, LONG_PAUSE)
	_hold(m, P, 1)
	var mz: Dictionary = P.wpn["muzzle"]
	var pg := "%s_%d" % [P.nid, P.shot_n]
	var n := 0
	var first := Vector3.INF
	var same := true            # every slug starts at the one muzzle point, the data's height above the feet
	var ahead := true           # whose hit sweep starts that far behind it, at the body
	for sd in m.shots:
		if sd["by"] == P and String((sd["x"] as Dictionary).get("pg", "")) == pg:
			n += 1
			var at: Vector3 = sd["muzzle"] if sd.has("muzzle") else Vector3.INF
			first = at if n == 1 else first
			same = same and at.distance_to(first) < 0.001 and absf(at.y - P.pos.y - float(mz["up"])) < 0.001
			var st: Vector3 = sd["start"]
			ahead = ahead and absf(Vector2(at.x - st.x, at.z - st.z).length() - float(mz["fwd"])) < 0.001
	ok(
		"gun: all seven slugs leave one muzzle point", n == int(P.wpn["pellets"]) and same,
		"slugs %d at %s" % [n, first]
	)
	ok("gun: the hit sweep starts at his body, the muzzle's reach behind it", ahead)

## Damage stays the volley's: on a foe straight ahead inside the slug range, the tight group lands all seven.
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
		"gun: every slug of a tight group lands on a foe %.1fm ahead" % CLUSTER_AT,
		hits == int(P.wpn["pellets"]), "hits %d" % hits
	)
	T.teleport(P.pos + Vector3(0, 0, 9.0))

## The aim line: one line from the drawn body toward this frame's aim, out to the slug range.
func _aimer(m: Match, P: Hunter) -> void:
	var d := AimKit.layer(m)
	_hold(m, P, 1)
	m.step(ak.DT)
	var e: Dictionary = AimKit.entry(P, "spread")
	ok(
		"aimer: one aim line (a merged line, not two cone edges) out to the slug range",
		not e.is_empty() and e["kind"] == "vee" and e["merged"]
		and absf(float(e["len"]) - float(P.wpn["range"])) < 0.01,
		"%s" % [e.get("kind", "none")]
	)
	# a drawn frame between steps: the body drawn ahead of the step, the cursor moved; no step runs
	P.global_position = P.pos + Vector3(0.12, 0, 0.05)
	ak.aim_at(P, P.pos + Vector3(0, 0, -4.0))
	d.track(1.0 / 144.0)
	var body := Vector2(P.global_position.x, P.global_position.z)
	ok(
		"aimer: the line starts at the drawn body and points at this frame's aim",
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
