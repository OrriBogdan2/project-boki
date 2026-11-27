extends RefCounted
## The scattergun for --dredge-combo-check (docs/heroes/dredge.md): every volley is seven slugs spread evenly over
## the `fan_deg` fan on the aim line (each its own shot), the same fan for shots in a row; the fan's two edges show the
## aim, following the drawn body and the aim on the drawn frame, and a fired volley lights its fan.

const LONG_PAUSE := 1.0  # s off the trigger
const NEAR_AT := 2.5  # m to the dummy where the whole fan lands
const FAR_AT := 5.5  # m to the dummy where only the middle slugs land, inside the 6.3 m slug range

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
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	t.teleport(p.pos + Vector3(0, 0, 9.0))
	_fans(m, p)
	_muzzle(m, p)
	_cluster_lands(m, p, t)
	_aimer(m, p)
	await ak.done(m)


## Every volley of a burst and one after a pause: seven slugs on seven separate lines, evenly over the fan.
func _fans(m: Match, p: Hunter) -> void:
	var fan: float = float(p.wpn["fan_deg"])
	var pel := int(p.wpn["pellets"])
	var vols: Array = _hold(m, p, 3)  # per volley: each slug's angle off the aim line, in degrees, sorted
	_release(m, p, LONG_PAUSE)
	vols.append_array(_hold(m, p, 1))
	var info := "slugs %s" % str(vols[0])
	ok("gun: a volley is seven slugs, each on its own line", _distinct(vols[0]) == pel and fan >= 15.0, info)
	var same := true
	for v: Array in vols:
		var gap := fan / float(pel - 1)
		same = same and absf(float(v[0]) + fan * 0.5) < 0.3 and absf(float(v[pel - 1]) - fan * 0.5) < 0.3
		same = same and absf(float(v[1]) - float(v[0]) - gap) < 0.3
	ok("gun: every volley (in a row, or after a pause) spreads evenly over the %.0f degree fan" % fan, same, info)


## Every slug of a volley leaves the blunderbuss's one muzzle point (not a ring round his body) and its hit sweep
## starts at the body, so a volley fired against a wall still stops at the wall.
func _muzzle(m: Match, p: Hunter) -> void:
	_release(m, p, LONG_PAUSE)
	_hold(m, p, 1)
	var mz: Dictionary = p.wpn["muzzle"]
	var pg := "%s_%d" % [p.nid, p.shot_n]
	var n := 0
	var first := Vector3.INF
	var same := true  # every slug starts at the one muzzle point, the data's height above the feet
	var ahead := true  # whose hit sweep starts that far behind it, at the body
	for sd in m.shots:
		if sd["by"] == p and String((sd["x"] as Dictionary).get("pg", "")) == pg:
			n += 1
			var at: Vector3 = sd["muzzle"] if sd.has("muzzle") else Vector3.INF
			first = at if n == 1 else first
			same = same and at.distance_to(first) < 0.001 and absf(at.y - p.pos.y - float(mz["up"])) < 0.001
			var st: Vector3 = sd["start"]
			ahead = ahead and absf(Vector2(at.x - st.x, at.z - st.z).length() - float(mz["fwd"])) < 0.001
	ok(
		"gun: all seven slugs leave one muzzle point",
		n == int(p.wpn["pellets"]) and same,
		"slugs %d at %s" % [n, first]
	)
	ok("gun: the hit sweep starts at his body, the muzzle's reach behind it", ahead)


## Every slug is its own hit: all seven land on a foe up close, only the middle ones at range, never none.
func _cluster_lands(m: Match, p: Hunter, t: Hunter) -> void:
	var near := _slug_hits(m, p, t, NEAR_AT)
	var far := _slug_hits(m, p, t, FAR_AT)
	var pel := int(p.wpn["pellets"])
	ok("gun: all seven slugs land on a foe %.1fm ahead" % NEAR_AT, near == pel, "hits %d" % near)
	ok("gun: only the middle slugs land on a foe %.1fm ahead" % FAR_AT, far >= 3 and far < pel, "hits %d" % far)
	t.teleport(p.pos + Vector3(0, 0, 9.0))


## One volley at a fresh dummy `dist` m east: how many of its slugs hit.
func _slug_hits(m: Match, p: Hunter, t: Hunter, dist: float) -> int:
	_release(m, p, LONG_PAUSE)
	t.teleport(p.pos + Vector3(dist, 0, 0))
	ak.fresh(t)
	var seen := p.shot_n
	_hold(m, p, 1)
	ak.step(m, 0.6)
	var pg := "%s_%d|%s" % [p.nid, seen + 1, t.nid if t.nid != "" else str(t.get_instance_id())]
	return int(m.pellet_hits.get(pg, 0))


## The aim: the fan's two edges from the drawn body toward this frame's aim, out to the slug range; a volley lights it.
func _aimer(m: Match, p: Hunter) -> void:
	var d := AimKit.layer(m)
	_hold(m, p, 1)
	m.step(ak.DT)
	ok("aimer: a fired volley lights its fan for everyone", AimKit.shown(p, "shot_fan"))
	var e: Dictionary = AimKit.entry(p, "spread")
	ok(
		"aimer: the fan's two edges out to the slug range, as wide as the volley",
		(
			not e.is_empty()
			and e["kind"] == "cone"
			and e["edges"]
			and absf(float(e["len"]) - float(p.wpn["range"])) < 0.01
			and absf(float(e["deg"]) - float(p.wpn["fan_deg"])) < 0.01
		),
		"%s" % [e.get("kind", "none")]
	)
	# a drawn frame between steps: the body drawn ahead of the step, the cursor moved; no step runs
	p.global_position = p.pos + Vector3(0.12, 0, 0.05)
	ak.aim_at(p, p.pos + Vector3(0, 0, -4.0))
	d.track(1.0 / 144.0)
	var body := Vector2(p.global_position.x, p.global_position.z)
	ok(
		"aimer: the edges start at the drawn body and points at this frame's aim",
		(e["from"] as Vector2).distance_to(body) < 0.001 and (e["dir"] as Vector2).dot(p.aim_dir()) > 0.9999,
		"from %s body %s dir %s" % [e["from"], body, e["dir"]]
	)


## Holds fire on the east until `count` new volleys leave; returns each one's slug angles off the aim line.
func _hold(m: Match, p: Hunter, count: int) -> Array:
	var out: Array = []
	var seen := p.shot_n
	var t := 0.0
	while out.size() < count and t < 3.0:
		ak.aim_at(p, p.pos + Vector3(2.0, 0, 0))
		p.inp["fire"] = true
		m.step(ak.DT)
		t += ak.DT
		if p.shot_n != seen:
			seen = p.shot_n
			out.append(_angles(m, p, "%s_%d" % [p.nid, p.shot_n]))
	p.inp["fire"] = false
	return out


func _release(m: Match, p: Hunter, secs: float) -> void:
	p.inp["fire"] = false
	ak.step(m, secs)


func _angles(m: Match, p: Hunter, pg: String) -> Array:
	var aim := p.aim_dir()
	var out: Array = []
	for sd in m.shots:
		if sd["by"] == p and String((sd["x"] as Dictionary).get("pg", "")) == pg:
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
