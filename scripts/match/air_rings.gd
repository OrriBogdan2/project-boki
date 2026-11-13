class_name AirRings
extends RefCounted
## Air rings (docs/AIR_RINGS.md): fixed rings in the air that make the map fast to cross.
## A glide ring lines an air lane (a map glide marked "rings"): fly through one and your glide is thrown
## along the lane, held at speed and at the lane's height for a moment, and the glider cools, so a chain
## carries you across a gap far wider than one glider's heat. A lift ring lies flat over a map updraft
## marked "ring" at the foot of high ground: hop into it and it throws you up with the glider open, and
## the updraft carries you to the top. Every ring is fixed by the map; tuning is content/rules/air_rings.json.
## Each peer runs the rings for the hunters it moves, like the rest of movement; for the ones another peer
## moves it only plays the pass's sound (AirRingSfx).

const GLIDE_COL := Color("5ad0f0")     # cyan: speed
const LIFT_COL := Color("ffd27a")      # warm gold, the updraft column's colour: height
const BODY_Y := 0.8                    # m: a hunter's body over its feet (what goes through a ring)
const TIP_R := 9.0                     # m: the first time you come this close to a ring, the tip shows
const CLIMB_EASE := 2.5                # 1/s and m/s per m: the lane pulls you to its height (as a wind road does)

var n := 0                     # rings flown through this match (SIMSTAT)
var list: Array = []           # {pos, dir: Vector2, lift: bool, lane: int, node, cd: {nid: time}, top, onto (lifts)}
var lanes: Array = []          # {a, b}: each ringed lane's ring line (ring centres), for the hold and the maps
var sfx: AirRingSfx
var _m: Match
var _slip := {}                # Hunter -> {until: time, speed: m/s, lane: int}

static func r(key: String) -> float:
	return float(Content.rules("air_rings")[key])

## Lays the layout's rings into the world (World.generate_authored calls this once its glides and updrafts
## are placed): rings along every glide marked "rings", plus the way back as a bot route, and a lift ring
## over every updraft marked "ring". `ids` maps island ids to indexes.
static func lay(w: World, layout: Dictionary, ids: Dictionary) -> void:
	for G in layout.get("glides", []):
		if not (G is Dictionary and G.get("rings", false)):
			continue
		var from: int = ids.get(String(G["a"]), -1)
		var to: int = ids.get(String(G["b"]), -1)
		if from < 0 or to < 0:
			continue
		var take := _ground(w, G["take"])
		var land := _ground(w, G["land"])
		for lk in w.links:
			if lk.get("glide", false) and lk["take"].distance_to(take) < 0.1 and lk["land"].distance_to(land) < 0.1:
				lk["rings"] = true       # (bots time a ringed lane at the ring speed: BotRoute)
		w.links.append({"from": to, "to": from, "take": land, "land": take, "glide": true, "rings": true})
		_lay_lane(w, take, land)
	for U in layout.get("updrafts", []):
		if U.get("ring", false):
			var at := _ground(w, U["at"])
			var top := float(U.get("top", 2)) * World.LEVEL
			w.rings.append({"pos": at + Vector3.UP * r("lift_y"), "dir": Vector2.ZERO, "lift": true,
				"top": top, "onto": onto(w, at, top)})

## Where a lift ring at `foot` sets you down: the nearest ground at least `top` high beside it (within 6 m),
## 1.5 m further in from the rim. INF if there is none.
static func onto(w: World, foot: Vector3, top: float) -> Vector3:
	var best := Vector3.INF
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			var x := foot.x + dx
			var z := foot.z + dz
			if w.is_void(x, z) or w.ground_at(x, z) < top - 0.05:
				continue
			var p := Vector3(x, w.ground_at(x, z), z)
			if best == Vector3.INF or foot.distance_to(p) < foot.distance_to(best):
				best = p
	if best == Vector3.INF:
		return best
	return best + (best - foot).normalized() * Vector3(1, 0, 1) * 1.5

static func _ground(w: World, xz: Array) -> Vector3:
	var x := floorf(float(xz[0])) + 0.5
	var z := floorf(float(xz[1])) + 0.5
	return Vector3(x, w.ground_at(x, z), z)

## Rings evenly along take -> land, `up` m over the line between the two grounds.
static func _lay_lane(w: World, take: Vector3, land: Vector3) -> void:
	var a := take + Vector3.UP * r("up")
	var b := land + Vector3.UP * r("up")
	var length := Vector2(b.x - a.x, b.z - a.z).length()
	var span := length - r("first") - r("end")
	if span < 0.0:
		return
	var count := int(span / r("gap")) + 1
	var dir := Vector2(b.x - a.x, b.z - a.z).normalized()
	for k in count:
		var s := r("first") + (span * k / (count - 1) if count > 1 else span * 0.5)
		var at := a.lerp(b, s / length)
		at.y = lane_y(a, b, at)
		w.rings.append({"pos": at, "dir": dir, "lift": false, "a": a, "b": b})

func _init(m: Match) -> void:
	_m = m
	sfx = AirRingSfx.new(m)
	for rg in m.world.rings:
		var lift: bool = rg.get("lift", false)
		var node := ring_node(lift)
		node.position = rg["pos"]
		if not lift:
			node.rotation.y = atan2(float(rg["dir"].x), float(rg["dir"].y))
		m.add_child(node)
		list.append({"pos": rg["pos"], "dir": rg["dir"], "lift": lift, "lane": _lane_of(rg), "node": node, "cd": {},
			"top": rg.get("top", 0.0), "onto": rg.get("onto", Vector3.INF)})

func _lane_of(rg: Dictionary) -> int:
	if not rg.has("a"):
		return -1
	for i in lanes.size():
		if lanes[i]["a"] == rg["a"] and lanes[i]["b"] == rg["b"]:
			return i
	lanes.append({"a": rg["a"], "b": rg["b"]})
	return lanes.size() - 1

## A ring: a glowing hoop that reads from across the map, standing up along its lane (cyan) or lying
## flat over its updraft (gold), with a faint film across it. Static: rings don't spin.
static func ring_node(lift: bool) -> Node3D:
	var root := Node3D.new()
	var col := LIFT_COL if lift else GLIDE_COL
	var radius := r("look_r")
	var tube := TorusMesh.new()
	tube.inner_radius = radius - 0.16
	tube.outer_radius = radius + 0.16
	tube.rings = 32
	tube.ring_segments = 8
	var tilt := Vector3.ZERO if lift else Vector3(PI / 2, 0, 0)
	var hoop := Models.part(root, tube, Models.toon(col, true, 0.9), Vector3.ZERO, Vector3.ONE, tilt, "Ring")
	hoop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var film_mat := Models.glow_mat(Color(col.lightened(0.4), 0.14))
	var film := Models.part(root, Models.cyl(radius - 0.12, radius - 0.12, 0.02, 24), film_mat,
		Vector3.ZERO, Vector3.ONE, Vector3.ZERO if lift else Vector3(PI / 2, 0, 0), "Film")
	film.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

## Every step, after the hunters move: rings flown through, and the hold of the last glide ring.
func tick(dt: float) -> void:
	_tip()
	for h in _m.hunters:
		if h.grounded or h.out or h.downed or h.riding or not h.pad.is_empty():
			continue
		var body: Vector3 = h.pos + Vector3.UP * BODY_Y
		for rg in list:
			if _through(rg, body) and float(rg["cd"].get(h.nid, -9.0)) <= _m.time:
				rg["cd"][h.nid] = _m.time + r("cd")
				if h.remote:
					sfx.passed(h, rg)        # its own game throws it: here only the sound
				elif rg["lift"]:
					_lift(h, rg)
				else:
					_boost(h, rg)
	for h in _slip.keys():
		_hold(h, dt)
	sfx.tick(list)

func _through(rg: Dictionary, body: Vector3) -> bool:
	var c: Vector3 = rg["pos"]
	if not rg["lift"]:
		return body.distance_to(c) <= r("hit_r")
	return Vector2(body.x - c.x, body.z - c.z).length() <= r("lift_r") and absf(body.y - c.y) <= r("lift_dy")

## A glide ring: along the lane (whichever way you fly it) at the ring speed, the glider open and cooler.
func _boost(h: Hunter, rg: Dictionary) -> void:
	var flat := Vector2(h.vel.x, h.vel.z)
	var lane: Vector2 = rg["dir"]
	var heading: Vector2 = flat.normalized() if flat.length() > 1.0 else lane
	if absf(heading.dot(lane)) > 0.5:
		heading = lane if heading.dot(lane) > 0.0 else -lane
	var speed := maxf(flat.length(), r("speed"))
	h.vel.x = heading.x * speed
	h.vel.z = heading.y * speed
	h.vel.y = maxf(h.vel.y, r("kick_vy"))
	_slip[h] = {"until": _m.time + r("hold"), "speed": speed, "lane": rg["lane"]}
	_cool(h, rg, GLIDE_COL)

## A lift ring: straight up with the glider open; the updraft under it does the rest.
func _lift(h: Hunter, rg: Dictionary) -> void:
	h.vel.y = maxf(h.vel.y, r("lift_vy"))
	_slip.erase(h)
	_cool(h, rg, LIFT_COL)

func _cool(h: Hunter, rg: Dictionary, col: Color) -> void:
	n += 1
	h.add_stat("rings")
	h.glide_fuel = minf(1.0, h.glide_fuel + r("heat"))
	if not h.gliding and not h.dropping:
		h.glide_cd = 0.0
		h.gliding = true
		h.auto_glide = true
	var c: Vector3 = rg["pos"]
	_m.fx.ring(c, r("look_r"), col, 0.3)
	_m.fx.burst(c, col.lightened(0.5), 14, 4.0, 0.35, 0.0)
	sfx.passed(h, rg)

## While the hold lasts and you keep gliding: never slower than the ring threw you, and on a lane, eased
## to its height (so a lane up to higher ground carries you up it). Your keys still steer.
func _hold(h: Hunter, dt: float) -> void:
	var s: Dictionary = _slip[h]
	if not is_instance_valid(h) or h.grounded or not h.gliding or h.downed or _m.time > float(s["until"]):
		_slip.erase(h)
		return
	var flat := Vector2(h.vel.x, h.vel.z)
	if flat.length() > 0.5 and flat.length() < float(s["speed"]):
		flat = flat.normalized() * float(s["speed"])
		h.vel.x = flat.x
		h.vel.z = flat.y
	if int(s["lane"]) < 0:
		return
	var ln: Dictionary = lanes[int(s["lane"])]
	var want_y := lane_y(ln["a"], ln["b"], h.pos) - BODY_Y
	var climb := clampf((want_y - h.pos.y) * CLIMB_EASE, -3.0, 6.0)
	h.vel.y = lerpf(h.vel.y, climb, 1.0 - exp(-4.0 * dt))

## A lane's height over `p`: level at its high end's height, changing only over the last `rise` m before its
## low end. Over the void a glider can't sink below where it took off, so a lane can't slope down the whole
## way; near the low end's land it can, and the lane's hold climbs or eases you down that stretch.
static func lane_y(a: Vector3, b: Vector3, p: Vector3) -> float:
	var low := a if a.y <= b.y else b
	var high := b if a.y <= b.y else a
	var from_low := Vector2(p.x - low.x, p.z - low.z).length()
	return lerpf(low.y, high.y, clampf(from_low / r("rise"), 0.0, 1.0))

func _tip() -> void:
	var p: Hunter = _m.player
	if p == null or p.out or int(_m.time * 4.0) % 4 != 0:
		return
	for rg in list:
		if p.pos.distance_to(rg["pos"]) < TIP_R:
			var jump := Settings.key_cap("jump")
			_m._tip("rings", "Rings in the air: glide through a blue one to fly fast along its line, "
				+ "hop into a gold one to soar up to high ground (%s, then %s again to glide)." % [jump, jump])
			return

## Test (--ring-demo): start gliding at the first glide ring's lane, flying along it.
func demo() -> void:
	var p: Hunter = _m.player
	var glides := list.filter(func(rg): return not rg["lift"])
	if p == null or glides.is_empty():
		return
	if _m.time < 0.05:
		var rg: Dictionary = glides[0]
		var lane: Vector2 = rg["dir"]
		p.teleport(rg["pos"] - Vector3(lane.x, 0, lane.y) * 5.0 + Vector3(0, -BODY_Y, 0))
		p.grounded = false
		p.gliding = true
		p.vel = Vector3(lane.x, 0, lane.y) * 9.6
	if p.gliding:
		p.inp["glide"] = true
		p.inp["move"] = Vector2(p.vel.x, p.vel.z).normalized()
