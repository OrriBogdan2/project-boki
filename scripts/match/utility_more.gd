class_name UtilityMore
extends RefCounted
## The source-utility behaviours that are more than an Effects list (docs/SOURCE_UTILITIES.md). The
## numbers are in content/utility/*.json; UtilityUse hands the item here by its "use":
##   pad     a ground pad (Spring pad, Gust Fan): "arm" "life" "after" (life left once used) "push" "lift";
##           a "hp" pad is shot down by rivals' bullets (fan_shot)
##   field   a patch on the ground built on Fields.add_kx; "field" picks it:
##             gate    two gates, one where you aim and one at your feet, open "time" s; once "arm" s have
##                     passed, pressing the item again swaps everyone standing in each (regate)
##             seed    stand in it "hold" seconds and you are thrown to a random spot
##             banner  you show to every rival for "time" s; live through it and the squad returns, plus "reward" gems;
##                     knocked, you go straight out and whoever knocked you takes the gems; each knock your
##                     squad makes takes "cut" s off the timer (on_knock)
##             ward    shows every rival within "r" while it hangs; anyone who steps on it after "arm" s
##                     takes it down onto their own belt
##             pack    the first body to step in heals "heal" of its health over "hold" s (a hit stops it);
##                     a body in the air is thrown up "bounce" instead
##   pilfer  after its channel "time" s standing still, raccoons take "take" of the gems of every rival hunter within
##           "r" of the aim and empty the locked chests there
##   lamp    a revive beacon where you stand (Beacons.lamp)
##   ember   every fallen squadmate wakes where you stand (Beacons.pop)
## and the end of a drink: "warp" (Lostway Scroll) and "omen" (Omen Draught).
## Bodies are moved or hurt only where this game owns them (like the pads before): online, a remote
## hunter in a gate or a seed is handled by its own game only if it set the item itself.

const PAD_R := 0.8
const FAN_HIT_R := 0.9      # m: a bullet this close to a fan's post (flat) hits it
const FAN_HIT_H := 1.6      # m: ...and below this height above its foot
const PACK_AIR_REACH := 4.0 # m above a health pack that a body in the air still catches it

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
			match String(UtilityBelt.def(id).get("field", "")):
				"banner": return not bool(h.m.get_meta("banner_%d" % h.team, false))
				"gate": return not _gate_open(h) or _gate_armed(h)
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
		"lift": float(d.get("lift", 17.0)), "id": d.get("id", ""), "col": d.get("col", Color.WHITE),
		"node": n, "cd": {}, "team": h.team,
	})
	if d.has("hp"):
		h.m.gpads[-1]["hp"] = float(d["hp"])

## Every step: pads count down, arm, and launch whoever stands on them.
static func pads(m: Node, dt: float) -> void:
	BeltSfx.tick(m, dt)    # the placed items' loops share this per-frame call
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
				if BeltSfx.cue(String(gp.get("id", "")), "hit") != "":
					BeltSfx.play_at(m, String(gp["id"]), "hit", h.pos)
				else:
					m.sfx("jump", h.pos, -2.0, 0.8)

## A rival's bullet at a fan with health: the fan takes the hit and the bullet is spent. A fan shot to
## nothing is gone at the next step (pads).
static func fan_shot(m: Node, s: Dictionary, p: Vector3) -> bool:
	for gp in m.gpads:
		if not gp.has("hp") or float(gp["hp"]) <= 0.0 or int(gp["team"]) == int(s["team"]):
			continue
		var foot: Vector3 = gp["pos"]
		if Vector2(p.x - foot.x, p.z - foot.z).length() > FAN_HIT_R or p.y < foot.y - 0.3 or p.y > foot.y + FAN_HIT_H:
			continue
		gp["hp"] = float(gp["hp"]) - float(s["dmg"])
		m.fx.burst(p, gp["col"], 6, 3.0, 0.25, 4.0, 0.8)
		m.sfx("ab_shield_hit", p, -8.0)
		if float(gp["hp"]) <= 0.0:
			gp["t"] = 0.0
			m.fx.burst(foot + Vector3(0, 0.6, 0), gp["col"], 20, 4.0, 0.5)
		return true
	return false

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
			var idle := func(_p, _z): pass
			var pair := [
				m.fields.add_kx(h, at, r, time, 1.0, col, idle, Callable(), null, ""),
				m.fields.add_kx(h, b, r, time, 1.0, col, idle, Callable(), null, "")]
			m.set_meta("gate_%d" % h.get_instance_id(), {"a": at, "b": b, "r": r, "t0": m.time,
				"arm": float(d.get("arm", 8.0)), "zones": pair})
		"seed":
			var held := {}
			var hold := float(d.get("hold", 1.5))
			m.fields.add_kx(h, at, r, time, 0.25, col, func(p, _z): _seed_tick(m, p, r, hold, held),
				Callable(), null, "")
		"banner":
			var key := "banner_%d" % h.team
			var span := {"t0": m.time}         # when it started, moved back by every cut (on_knock)
			m.set_meta(key, true)
			h.reveal_t = maxf(h.reveal_t, time)
			m.fx.word(h.pos + Vector3(0, 2.4, 0), "MOST WANTED", col)
			m.add_feed("%s shows themselves to everyone" % h.pname)
			var z: Dictionary = m.fields.add_kx(h, h.pos, 1.0, time, 0.2, col, func(_p, zz): _banner_tick(m, h, d, zz),
				func(_p): _banner_end(m, h, d, key, span), h, "")
			z["banner"] = span
		"ward":
			m.fields.add_kx(h, at, 0.6, time, 0.5, col, func(p, z): _ward_tick(m, h.team, p, d, z),
				Callable(), null, "totem")
		"pack":
			var done := [false]
			m.fields.add_kx(h, at, r, time, 0.2, col, func(p, z): _pack_tick(m, p, z, d, done), Callable(), null, "")
	return true

static func _near(m: Node, at: Vector3, r: float, rise := 2.0) -> Array:
	return m.hunters.filter(func(x):
		var live: bool = not x.out and not x.downed and not x.remote
		return live and x.flat_dist(at) < r + x.r and absf(x.pos.y - at.y) < rise)

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
		BeltSfx.play_at(m, "twin_gate", "end", a)

static func _gate_of(h: Hunter) -> Dictionary:
	var g: Dictionary = h.m.get_meta("gate_%d" % h.get_instance_id(), {})
	if g.is_empty():
		return g
	var lead: Dictionary = g["zones"][0]
	return {} if float(lead["t"]) <= 0.0 or (lead["node"] as Node3D).is_queued_for_deletion() else g

static func _gate_open(h: Hunter) -> bool:
	return not _gate_of(h).is_empty()

static func _gate_armed(h: Hunter) -> bool:
	var g := _gate_of(h)
	return not g.is_empty() and h.m.time - float(g["t0"]) >= float(g["arm"])

## The second press of a Twin Gate whose gates are armed: everyone in each gate swaps and both close, with
## no charge spent. False when this item is not a gate or none is armed (the press opens a new pair).
static func regate(h: Hunter, id: String) -> bool:
	if String(UtilityBelt.def(id).get("field", "")) != "gate" or not _gate_armed(h):
		return false
	var g := _gate_of(h)
	_swap(h.m, g["a"], g["b"], float(g["r"]))
	for z in g["zones"]:
		z["t"] = 0.0
	h.m.remove_meta("gate_%d" % h.get_instance_id())
	return true

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

## Knocked under the banner: out at once (no wisp, no spare life) and the knocker pockets the bounty.
static func _banner_tick(m: Node, h: Hunter, d: Dictionary, z: Dictionary) -> void:
	if not h.downed or h.out:
		return
	var by = h.last_hit_by
	if by is Kin and by.owner_h:
		by = by.owner_h
	if by is Hunter and by.team != h.team:
		by.gems += int(d.get("reward", 0))
		m.fx.word(by.pos + Vector3(0, 2.4, 0), "+%d gems" % int(d.get("reward", 0)), Color("ffd27a"))
		m.add_feed("%s claims the bounty on %s" % [by.pname, h.pname])
	m.eliminate(h, h.last_hit_by, "bounty", true)
	z["t"] = 0.0

## A knock by a hunter's squad takes the banner's "cut" seconds off that squad's running Bounty Banner.
static func on_knock(m: Node, victim: Hunter, credit: Ent) -> void:
	if not credit is Hunter or credit.team == victim.team:
		return
	var cut := float(UtilityBelt.def("bounty_banner").get("cut", 0.0))
	for z in m.fields.list:
		if z.has("banner") and int(z["team"]) == credit.team:
			z["t"] = maxf(0.1, float(z["t"]) - cut)
			z["banner"]["t0"] = float(z["banner"]["t0"]) - cut
			m.fx.word(z["caster"].pos + Vector3(0, 2.4, 0), "-%d s" % int(cut), Color("ffd27a"))

static func _banner_end(m: Node, h: Hunter, d: Dictionary, key: String, span: Dictionary) -> void:
	m.remove_meta(key)
	if h.out or h.downed or m.time - float(span["t0"]) < float(d.get("time", 120.0)) - 1.5:
		m.fx.word(h.pos + Vector3(0, 2.4, 0), "FELL", Color("ff6a5a"))
		return
	h.reveal_t = 0.0
	h.gems += int(d.get("reward", 0))
	Beacons.pop(m, h.pos, h.team)
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "+%d gems" % int(d.get("reward", 0)), Color("ffd27a"))

static func _ward_tick(m: Node, team: int, at: Vector3, d: Dictionary, z: Dictionary) -> void:
	var r := float(d.get("r", 1.5))
	for o in m.hunters:
		if o.team != team and not o.out and o.flat_dist(at) < r:
			o.reveal_t = maxf(o.reveal_t, 3.0)
	if float(z["t"]) > float(d.get("time", 0.0)) - float(d.get("arm", 0.0)):
		return          # just hung: the one who hung it does not take it straight back
	var id := String(d.get("id", ""))
	for x in _near(m, at, float(d.get("pick", 1.0))):
		if UtilityBelt.has_room(x, id):
			UtilityBelt.pickup(x, id)
			z["t"] = 0.0
			BeltSfx.drop_bed(m, id, at)
			m.fx.burst(at + Vector3(0, 1.0, 0), Color(d.get("col", Color.WHITE)), 10, 2.5, 0.4, -2.0)
			return

static func _pack_tick(m: Node, at: Vector3, z: Dictionary, d: Dictionary, done: Array) -> void:
	if done[0]:
		return
	for x in _near(m, at, float(d.get("r", 1.4)), PACK_AIR_REACH):
		var in_air: bool = not x.grounded
		var is_hurt: bool = x.hp < x.max_hp - 0.5
		if not is_hurt and not in_air:
			continue
		done[0] = true
		z["t"] = 0.0
		if in_air:
			x.vel.y = float(d.get("bounce", 0.0))
			x.glide_cd = 0.0
			m.fx.burst(at + Vector3(0, 0.3, 0), Color("8fe0a0"), 14, 4.0, 0.4, -2.0)
		if is_hurt:
			_regen(m, x, x.max_hp * float(d.get("heal", 0.6)), float(d.get("hold", 5.0)), 0.5, x.hp)
		BeltSfx.play_at(m, "toss_satchel", "end", at)
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
	var wait := UtilityUse.channel(String(d["id"]), "time", 0.0)
	h.root_t = maxf(h.root_t, wait)
	m.fx.ring(at, float(d.get("r", 4.0)), Color("d0b080"), maxf(wait, 0.8))
	m.later(wait, func(): _raid(m, h, at, d))

## The raccoons arrive: half the gems of every rival in the circle, and every locked chest in it emptied.
## Stopped if the thrower went down while channelling.
static func _raid(m: Node, h: Hunter, at: Vector3, d: Dictionary) -> void:
	if h.out or h.downed:
		return
	var r := float(d.get("r", 4.0))
	var took := 0
	for o in m.hunters:
		if o.team != h.team and not o.out and not o.remote and o.flat_dist(at) < r and o.gems > 0:
			var n := int(float(o.gems) * float(d.get("take", 0.5)))
			o.gems -= n
			took += n
			m.fx.word(o.pos + Vector3(0, 2.2, 0), "-%d gems" % n, Color("d0b080"))
	var chests := 0
	for c in m.chests:
		if not c["open"] and not c.get("free", false) and not c.has("ride") \
				and Vector2(c["pos"].x - at.x, c["pos"].z - at.z).length() < r:
			ChestLoot.raid(m, c)
			chests += 1
	m.fx.burst(at + Vector3(0, 0.5, 0), Color("d0b080"), 16, 4.0, 0.6)
	if took > 0 or chests > 0:
		m.add_feed("Raccoons carried off %d gems and %d chests" % [took, chests])

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
