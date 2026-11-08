class_name UtilityMore
extends RefCounted
## The source-utility behaviours that are more than an Effects list (docs/SOURCE_UTILITIES.md). The
## numbers are in content/utility/*.json; UtilityUse hands the item here by its "use":
##   pad     a ground pad (Spring pad, Gust Fan): "arm" "life" "after" (life left once used) "push" "lift"
##   field   a patch on the ground built on Fields.add_kx; "field" picks it:
##             gate    two gates, one where you aim and one at your feet; later everyone in each swaps
##             seed    stand in it "hold" seconds and you are thrown to a random spot
##             banner  you show to every rival for "time" s; live through it and the squad returns, plus "reward" gems
##             ward    shows every rival within "r" while it hangs
##             pack    the first body to step in heals "heal" of its health over "hold" s (a hit stops it)
##   pilfer  raccoons take "take" of the gems of every rival hunter within "r" of the aim
##   lamp    a revive beacon where you stand (Beacons.lamp)
##   ember   every fallen squadmate wakes where you stand (Beacons.pop)
## and the end of a drink: "warp" (Lostway Scroll) and "omen" (Omen Draught).
## Bodies are moved or hurt only where this game owns them (like the pads before): online, a remote
## hunter in a gate or a seed is handled by its own game only if it set the item itself.

const PAD_R := 0.8

static func start(h: Hunter, id: String, d: Dictionary) -> bool:
	match String(d.get("use", "")):
		"pad": _pad(h, d)
		"field": return _field(h, id, d)
		"pilfer": _pilfer(h, d)
		"lamp": Beacons.lamp(h.m, h.pos)
		"ember": Beacons.pop(h.m, h.pos, h.team)
	return true

## Anything stopping the item right now (nothing to revive, a banner already running).
static func can_use(h: Hunter, id: String) -> bool:
	match String(UtilityBelt.def(id).get("use", "")):
		"ember": return not Beacons.targets(h.m, h.team).is_empty()
		"field":
			if String(UtilityBelt.def(id).get("field", "")) == "banner":
				return not bool(h.m.get_meta("banner_%d" % h.team, false))
	return true

# ------------------------------------------------------------------ pads
static func _spot(h: Hunter, dist: float) -> Vector3:
	var a := h.aim_dir()
	var at := Vector3(h.pos.x + a.x * dist, h.pos.y, h.pos.z + a.y * dist)
	if h.m.world.is_void(at.x, at.z) or h.m.world.is_block(at.x, at.z):
		return h.pos
	at.y = h.m.world.ground_at(at.x, at.z)
	return at

static func _pad(h: Hunter, d: Dictionary) -> void:
	var at := _spot(h, 1.6)
	var n := Models.gear_pad(d.get("col", Color.WHITE))
	n.position = at
	h.m.add_child(n)
	h.m.gpads.append({
		"pos": at, "t": float(d.get("life", 20.0)), "arm": float(d.get("arm", 0.0)),
		"after": float(d.get("after", 0.0)), "push": float(d.get("push", 6.0)),
		"lift": float(d.get("lift", 17.0)), "col": d.get("col", Color.WHITE), "node": n, "cd": {},
	})
	h.m.sfx("throw", h.pos, -2.0, 1.2)

## Every step: pads count down, arm, and launch whoever stands on them.
static func pads(m: Node, dt: float) -> void:
	for gp in m.gpads.duplicate():
		gp["t"] = float(gp["t"]) - dt
		gp["arm"] = float(gp["arm"]) - dt
		if float(gp["t"]) <= 0.0:
			(gp["node"] as Node3D).queue_free()
			m.gpads.erase(gp)
			continue
		var top: Node3D = (gp["node"] as Node3D).get_node_or_null("Top")
		if top: top.scale = Vector3.ONE * (1.0 + sin(m.time * 6.0) * 0.06) * (0.6 if float(gp["arm"]) > 0.0 else 1.0)
		if float(gp["arm"]) > 0.0:
			continue
		for h in m.hunters:
			if h.out or h.downed or h.remote or not h.grounded:
				continue
			var on_pad: bool = h.flat_dist(gp["pos"]) < PAD_R and absf(h.pos.y - float(gp["pos"].y)) < 0.6
			if on_pad and float(gp["cd"].get(h.nid, -9.0)) < m.time:
				gp["cd"][h.nid] = m.time + 1.0
				if float(gp["after"]) > 0.0:
					gp["t"] = minf(float(gp["t"]), float(gp["after"]))
				var hv := Vector2(h.vel.x, h.vel.z)
				var dir: Vector2 = hv.normalized() if hv.length() > 0.5 else h.aim_dir()
				var sp := maxf(hv.length(), float(gp["push"]))
				h.vel = Vector3(dir.x * sp, float(gp["lift"]), dir.y * sp)
				h.grounded = false
				h.glide_cd = 0.0
				m.fx.burst(gp["pos"] + Vector3(0, 0.3, 0), gp["col"], 16, 5.0, 0.4, -2.0)
				m.sfx("jump", h.pos, -2.0, 0.8)

# ------------------------------------------------------------------ fields
static func _field(h: Hunter, id: String, d: Dictionary) -> bool:
	var m = h.m
	var col: Color = d.get("col", Color.WHITE)
	var time := float(d.get("time", 10.0))
	var r := float(d.get("r", 1.5))
	var at := _spot(h, float(d.get("range", 1.6)))
	match String(d.get("field", "")):
		"gate":
			var b := h.pos
			var tick := func(_p, _z): pass
			m.fields.add_kx(h, at, r, time, 1.0, col, tick, func(_p): _swap(m, at, b, r), null, "")
			m.fields.add_kx(h, b, r, time, 1.0, col, tick, Callable(), null, "")
		"seed":
			var held := {}
			var hold := float(d.get("hold", 1.5))
			m.fields.add_kx(h, at, r, time, 0.25, col, func(p, _z): _seed_tick(m, p, r, hold, held),
				Callable(), null, "")
		"banner":
			var key := "banner_%d" % h.team
			var t0: float = m.time
			m.set_meta(key, true)
			h.reveal_t = maxf(h.reveal_t, time)
			m.fx.word(h.pos + Vector3(0, 2.4, 0), "MOST WANTED", col)
			m.add_feed("%s shows themselves to everyone" % h.pname)
			m.fields.add_kx(h, h.pos, 1.0, time, 1.0, col, func(_p, _z): pass,
				func(_p): _banner_end(m, h, d, key, t0), h, "")
		"ward":
			m.fields.add_kx(h, at, 0.6, time, 0.5, col, func(p, _z): _ward_tick(m, h.team, p, r),
				Callable(), null, "totem")
		"pack":
			var done := [false]
			m.fields.add_kx(h, at, r, time, 0.2, col, func(p, z): _pack_tick(m, p, z, d, done), Callable(), null, "")
	m.sfx("throw", h.pos, -2.0, 1.0)
	return true

static func _near(m: Node, at: Vector3, r: float) -> Array:
	return m.hunters.filter(func(x):
		var live: bool = not x.out and not x.downed and not x.remote
		return live and x.flat_dist(at) < r + x.r and absf(x.pos.y - at.y) < 2.0)

static func _put(m: Node, x: Node, p: Vector3) -> void:
	m.fx.ghost(x.position, x.face, Color("c9a0ff"), 0.6)
	x.teleport(Vector3(p.x, m.world.ground_at(p.x, p.z), p.z))
	x.vel = Vector3.ZERO
	m.fx.burst(x.pos + Vector3(0, 0.9, 0), Color("c9a0ff"), 12, 3.0, 0.4)

static func _swap(m: Node, a: Vector3, b: Vector3, r: float) -> void:
	var ina := _near(m, a, r)
	var inb := _near(m, b, r)
	for x in ina:
		_put(m, x, b + (x.pos - a))
	for x in inb:
		_put(m, x, a + (x.pos - b))
	if not ina.is_empty() or not inb.is_empty():
		m.sfx("blink", a, -2.0, 0.9)

static func random_spot(m: Node) -> Vector3:
	for i in 8:
		var p: Vector3 = m.world.random_ground(randi() % maxi(1, m.world.islands.size()))
		if p != Vector3.INF and not m.world.is_void(p.x, p.z):
			return p
	return Vector3.INF

static func warp(h: Hunter) -> void:
	var p := random_spot(h.m)
	if p != Vector3.INF:
		_put(h.m, h, p)

static func _seed_tick(m: Node, at: Vector3, r: float, hold: float, held: Dictionary) -> void:
	var inside := _near(m, at, r)
	for x in inside:
		held[x.nid] = float(held.get(x.nid, 0.0)) + 0.25
		if float(held[x.nid]) >= hold:
			held.erase(x.nid)
			warp(x)
	for k in held.keys():
		if not inside.any(func(x): return x.nid == k):
			held.erase(k)

static func _banner_end(m: Node, h: Hunter, d: Dictionary, key: String, t0: float) -> void:
	m.remove_meta(key)
	if h.out or h.downed or m.time - t0 < float(d.get("time", 120.0)) - 1.5:
		m.fx.word(h.pos + Vector3(0, 2.4, 0), "FELL", Color("ff6a5a"))
		return
	h.reveal_t = 0.0
	h.gems += int(d.get("reward", 0))
	Beacons.pop(m, h.pos, h.team)
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "+%d gems" % int(d.get("reward", 0)), Color("ffd27a"))

static func _ward_tick(m: Node, team: int, at: Vector3, r: float) -> void:
	for o in m.hunters:
		if o.team != team and not o.out and o.flat_dist(at) < r:
			o.reveal_t = maxf(o.reveal_t, 3.0)

static func _pack_tick(m: Node, at: Vector3, z: Dictionary, d: Dictionary, done: Array) -> void:
	if done[0]:
		return
	for x in _near(m, at, float(d.get("r", 1.4))):
		if x.hp >= x.max_hp - 0.5:
			continue
		done[0] = true
		z["t"] = 0.0
		_regen(m, x, x.max_hp * float(d.get("heal", 0.6)), float(d.get("hold", 5.0)), 0.5, x.hp)
		m.sfx("heal", at, -2.0, 1.2)
		return

## Heals `total` over `secs` in steps; getting hit stops it.
static func _regen(m: Node, x: Hunter, total: float, secs: float, step: float, last_hp: float) -> void:
	if x.out or x.downed or x.hp < last_hp - 0.01 or secs <= 0.0:
		return
	x.heal(total * step / secs)
	m.fx.burst(x.pos + Vector3(0, 1.0, 0), Color("8fe0a0"), 4, 2.0, 0.4, -3.0)
	m.later(step, func(): _regen(m, x, total, secs - step, step, x.hp))

# ------------------------------------------------------------------ the rest
static func _pilfer(h: Hunter, d: Dictionary) -> void:
	var m = h.m
	var at := Effects._aim_point(h, {"reach": float(d.get("range", 8.0))})
	at.y = m.world.ground_at(at.x, at.z) if not m.world.is_void(at.x, at.z) else h.pos.y
	var r := float(d.get("r", 4.0))
	m.fx.ring(at, r, Color("d0b080"), 0.8)
	var took := 0
	for o in m.hunters:
		if o.team != h.team and not o.out and not o.remote and o.flat_dist(at) < r and o.gems > 0:
			var n := int(float(o.gems) * float(d.get("take", 0.5)))
			o.gems -= n
			took += n
			m.fx.word(o.pos + Vector3(0, 2.2, 0), "-%d gems" % n, Color("d0b080"))
	m.fx.burst(at + Vector3(0, 0.5, 0), Color("d0b080"), 16, 4.0, 0.6)
	m.sfx("throw", h.pos, -2.0, 1.4)
	if took > 0:
		m.add_feed("Raccoons carried off %d gems" % took)

## The end of a drink: Lostway Scroll's warp, Omen Draught's wardens.
static func drank(h: Hunter, d: Dictionary) -> void:
	if d.get("warp", false):
		warp(h)
	if float(d.get("omen", 0.0)) > 0.0:
		_omen(h.m, h.team, float(d["omen"]), d.get("col", Color.WHITE))

static func _omen(m: Node, team: int, left: float, col: Color) -> void:
	if left <= 0.0 or m.blight == null:
		return
	if m.player and m.player.team == team:
		for w in m.blight.wardens:
			if is_instance_valid(w) and not w.dead:
				m.fx.ring(w.pos, 3.0, col, 1.2)
				m.fx.burst(w.pos + Vector3(0, 1.0, 0), col, 8, 2.0, 1.0, 6.0)
	m.later(2.0, func(): _omen(m, team, left - 2.0, col))
