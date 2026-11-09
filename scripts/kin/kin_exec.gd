class_name KinExec
extends RefCounted
## The kin grammar's runtime executor (docs/KIN_GRAMMAR.md, Phase 2). It runs any AbilitySpec,
## merge stage, dodge rider or throw from its parts, inside a match, for players, bots and kin AI.
## Nothing here knows about a particular kin: a delivery puts a shape in the world, the effects
## land on whatever it touches, modifiers change how the delivery behaves, followups ("then") start
## on the delivery's events. World things that stay (walls, mirrors, traps, tethers, zones) are the
## shared Verbs and Fields; this file only gives them callbacks.
##
## A cast context `cx` is a plain dictionary:
##   m        the Match
##   caster   the body performing it (the kin, or its hunter when the kin is carried / from: owner)
##   kin      the kin whose ability it is (or null)        owner  its hunter (or null)
##   team     whose side it's on                           aim    where it was aimed (Vector3)
##   power    damage multiplier (kin power x rank)         slot   "k1" | "k2" | "ult" | "throw" | "dodge"
##   ability  id                                           chain  ability ids that led here (no self-trigger)
##   at       where the previous stage landed (followups)  dir    the previous stage's direction
##   target   what the previous stage hit                  k      strength (repeats, chains, lingers)
##   depth    followup depth                                hits   {n}: units touched by this delivery (MAX_HITS)

const MOVERS := ["dash", "leap", "blink"]

## A fresh context for a cast.
static func make_cx(m: Node, caster: Ent, kin: Ent, owner: Ent, aim: Vector3, power: float, slot: String, ability_id: String, chain: Array = []) -> Dictionary:
	return {"m": m, "caster": caster, "kin": kin, "owner": owner, "team": int(caster.team) if caster else -1, "aim": aim,
		"power": power, "slot": slot, "ability": ability_id, "chain": chain + [ability_id], "depth": 1, "k": 1.0}

## Casts every top-level stage of an ability.
static func cast(ab: AbilitySpec, cx: Dictionary) -> void:
	if ab == null:
		return
	for st in ab.stages:
		run_stage(st, cx.duplicate())

static func run_stages(stages: Array, cx: Dictionary) -> void:
	for st in stages:
		run_stage(st, cx.duplicate())

static func _alive(n) -> bool:
	return n != null and is_instance_valid(n) and not n.dead

## One stage: its delay, the delivery, then its echoes.
static func run_stage(st: StageSpec, cx: Dictionary) -> void:
	if st == null or st.delivery == null or int(cx.get("depth", 1)) > KinParts.MAX_DEPTH + 1:
		return
	var m: Node = cx["m"]
	if m == null or not is_instance_valid(m) or not is_instance_valid(cx["caster"]):
		return
	var dt := st.delivery.type
	if not cx.get("_delayed", false):
		var wait := 0.0
		var dl := st.modifier("delay")
		if dl:
			wait = float(dl.params["time"])
		elif _enemy_area(st, cx):
			wait = Effects.ENEMY_WINDUP       # an area a rival lands on you gets a short wind-up
		# the global telegraph floor (DASHES §5.3): hard CC is never faster than a human can react
		if not cx.get("no_floor", false) and int(cx.get("depth", 1)) <= 1 and Feel.floors_apply(m, int(cx["team"])):
			wait = maxf(wait, (float(dl.params["time"]) if dl else 0.0) + Feel.missing_windup(st))
		if wait > 0.0:
			var c2 := cx.duplicate()
			c2["_delayed"] = true
			if not MOVERS.has(dt):
				c2["at_fixed"] = _origin(st, cx)
				c2["dir_fixed"] = _dir(st, cx, c2["at_fixed"])
				var tr := _reach(st)
				if tr > 0.0 and String(st.delivery.params.get("origin", "")) in ["aim", "here"]:
					_telegraph(m, c2["at_fixed"], tr, _color(st), wait)
			m.later(wait, func(): if is_instance_valid(c2["caster"]): run_stage(st, c2))
			return
	var c := cx.duplicate()
	if not c.has("hits"):
		c["hits"] = {"n": 0}
	var at0 := _origin(st, c)
	var dir0 := _dir(st, c, at0)
	_deliver(st, c)
	var rp := st.modifier("repeat")
	if rp and not cx.get("_echo", false):
		for i in int(rp.params["count"]):
			var c3 := cx.duplicate()
			c3["_echo"] = true
			c3["_delayed"] = true
			c3.erase("hits")
			c3["k"] = float(cx.get("k", 1.0)) * pow(float(rp.params["falloff"]), i + 1)
			if not MOVERS.has(dt):
				c3["at_fixed"] = at0         # an echo happens again at the same spot
				c3["dir_fixed"] = dir0
			m.later(float(rp.params["delay"]) * float(i + 1), func(): if is_instance_valid(c3["caster"]): run_stage(st, c3))

## A rival's big area at the aim gets the same wind-up marker the old Effects gave it.
static func _enemy_area(st: StageSpec, cx: Dictionary) -> bool:
	var m: Node = cx["m"]
	if m.get("player") == null or int(cx["team"]) == int(m.player.team):
		return false
	var d := st.delivery
	return d.type in ["burst", "zone"] and String(d.params.get("origin", "")) == "aim" and float(d.params.get("radius", 0.0)) >= 1.4

static func _telegraph(m: Node, at: Vector3, r: float, col: Color, t: float) -> void:
	var tele: Node3D = m.fx.telegraph_circle(at, r, Color(col, 0.9))
	var tw := tele.create_tween()
	tw.tween_method(func(k: float): if is_instance_valid(tele): m.fx.telegraph_progress(tele, k), 0.0, 1.0, t)
	tw.tween_callback(func(): if is_instance_valid(tele): m.fx.end_telegraph(tele))

# ------------------------------------------------------------------ where and which way
static func _origin(st: StageSpec, cx: Dictionary) -> Vector3:
	if cx.has("at_fixed"):
		return cx["at_fixed"]
	var d := st.delivery
	var caster: Ent = cx["caster"]
	match String(d.params.get("origin", "caster")):
		"owner":
			var o = cx.get("owner")
			return (o.pos if _alive(o) else caster.pos)
		"aim":
			return _ground(cx["m"], cx.get("aim", caster.pos), caster.pos.y)
		"here":
			return cx.get("at", caster.pos)
	return caster.pos

## The body the delivery starts from (moves, carries, follows), or null for a spot on the ground.
static func _origin_unit(st: StageSpec, cx: Dictionary) -> Ent:
	match String(st.delivery.params.get("origin", "caster")):
		"owner":
			var o = cx.get("owner")
			return o if _alive(o) else cx["caster"]
		"caster":
			return cx["caster"]
	return null

static func _dir(st: StageSpec, cx: Dictionary, from: Vector3) -> Vector2:
	if cx.has("dir_fixed"):
		return cx["dir_fixed"]
	var aim: Vector3 = cx.get("aim", from)
	var d := Vector2(aim.x - from.x, aim.z - from.z)
	if String(st.delivery.params.get("origin", "")) == "here" and cx.has("dir") and d.length() < 0.6:
		return cx["dir"]
	if d.length() > 0.05:
		return d.normalized()
	if cx.has("dir"):
		return cx["dir"]
	var c: Ent = cx["caster"]
	if c is Hunter:
		return (c as Hunter).aim_dir()
	return Vector2(-sin(c.face), -cos(c.face))

static func _ground(m: Node, p: Vector3, fallback_y: float) -> Vector3:
	var g: float = m.world.ground_at(p.x, p.z)
	return Vector3(p.x, g if g > World.VOID + 1.0 else fallback_y, p.z)

## The rough size of a stage, for telegraphs and aim rings.
static func _reach(st: StageSpec) -> float:
	var p := st.delivery.params
	for k in ["radius", "length"]:
		if p.has(k): return float(p[k]) * (0.5 if k == "length" else 1.0)
	return 1.2

static func _color(st: StageSpec) -> Color:
	if not st.effects.is_empty():
		return KinRules.effects_color(st.effects)
	for ev in st.then:
		for sub in st.then[ev]:
			if not (sub as StageSpec).effects.is_empty():
				return KinRules.effects_color((sub as StageSpec).effects)
	return KinRules.cat_color("sustain" if st.delivery.type == "wall" else "utility")

static func _height(u) -> float:
	if u is Hunter: return 0.95
	if u is Ent: return 0.5
	return 0.3

# ------------------------------------------------------------------ followups
static func _then(st: StageSpec, ev: String, cx: Dictionary, at: Vector3, dir: Vector2, target: Ent = null) -> void:
	if not st.then.has(ev):
		return
	for sub in st.then[ev]:
		var c2 := cx.duplicate()
		for k in ["at_fixed", "dir_fixed", "hits", "_delayed", "_echo"]:
			c2.erase(k)
		c2["at"] = at
		c2["dir"] = dir
		c2["depth"] = int(cx.get("depth", 1)) + 1
		if target: c2["target"] = target
		else: c2.erase("target")
		run_stage(sub, c2)

# ------------------------------------------------------------------ deliveries
static func _deliver(st: StageSpec, cx: Dictionary) -> void:
	if int(cx.get("depth", 1)) <= 1 and not cx.has("_echo"):
		# the shared cast language (AbilityFx): a Boki's or an archetype's cast reads like a weapon's
		var from := _origin(st, cx)
		var dl := st.delivery.type
		if dl == "projectile" and float(st.delivery.params.get("speed", 0.0)) >= 60.0: dl = "rail"
		AbilityFx.cast(cx["m"], cx["caster"], dl, from, _dir(st, cx, from), _color(st),
			{"range": float(st.delivery.params.get("range", 10.0)), "radius": float(st.delivery.params.get("radius", 1.5)), "grammar": true})
		# the tell sound for grammar casts is Feel's (pointed at AbilityFx's rows), once per caster a frame
		if not cx.get("silent", false):
			Feel.sound(cx["m"], "tell", dl, from, cx["caster"])
	match st.delivery.type:
		"projectile": _projectile(st, cx)
		"cone": _cone(st, cx)
		"beam": _beam(st, cx)
		"burst": _burst(st, cx)
		"zone": _zone(st, cx)
		"trap": _trap(st, cx)
		"wall": _wall(st, cx)
		"aura": _aura(st, cx)
		"tether": _tether(st, cx)
		"dash": _dash(st, cx)
		"leap": _leap(st, cx)
		"blink": _blink(st, cx)
		"summon": _summon(st, cx)

static func _foes_near(cx: Dictionary, at: Vector3, r: float, dy := 2.2) -> Array:
	var out: Array = []
	for f in cx["m"].foes_of(int(cx["team"])):
		if f.hittable() and Vector2(f.pos.x - at.x, f.pos.z - at.z).length() < r + f.r and absf(f.pos.y - at.y) < dy:
			out.append(f)
	return out

static func _projectile(st: StageSpec, cx: Dictionary) -> void:
	var m: Node = cx["m"]
	var p := st.delivery.params
	var from := _origin(st, cx)
	var unit := _origin_unit(st, cx)
	var dir := _dir(st, cx, from)
	var spd := float(p["speed"]); var rng := float(p["range"]); var size := float(p["size"])
	var n := 1; var fan := 0.0
	var sp := st.modifier("split")
	if sp:
		n = int(sp.params["count"]); fan = deg_to_rad(float(sp.params["angle"]))
	var y := from.y + _height(unit)
	var col := _color(st)
	var bounce := st.modifier("bounce")
	var hits: Dictionary = cx["hits"]
	for i in n:
		var a := atan2(dir.y, dir.x) + (fan * (float(i) / float(n - 1) - 0.5) if n > 1 else 0.0)
		var dv := Vector2(cos(a), sin(a))
		var lead := 0.6 if unit else 0.2
		var start := Vector3(from.x + dv.x * lead, y, from.z + dv.y * lead)
		_shoot(st, cx, start, dv, spd, rng, size, col, {"hits": 0, "bounce": int(bounce.params["count"]) if bounce else 0, "seen": {}}, hits)
	if not cx.get("silent", false):
		m.sfx("throw", from, -3.0, 1.15)

static func _shoot(st: StageSpec, cx: Dictionary, start: Vector3, dv: Vector2, spd: float, rng: float, size: float, col: Color, state: Dictionary, hits: Dictionary) -> void:
	var m: Node = cx["m"]
	var p := st.delivery.params
	var extra := {"kx_dmg": _instant_damage(st.effects, cx), "kin": cx["caster"] is Kin, "ab": cx["slot"]}
	extra["kx"] = func(s: Dictionary, at: Vector3, e: Ent, why: String) -> void: _shot_event(st, cx, s, at, e, why, state, hits)
	if st.has_modifier("pierce") or st.has_modifier("return"):
		extra["hitset"] = {}
		extra["pierce"] = st.has_modifier("pierce")
		extra["return"] = st.has_modifier("return")
	if int(cx.get("wall_bounce", 0)) > 0:
		extra["bounce"] = int(cx["wall_bounce"])      # ricochets off walls (an archetype's trick shot)
	if cx.has("shot_crit"):
		extra["crit"] = true
	if bool(p.get("rope", false)):
		extra["rope"] = true
		extra["deco"] = "hook"
	m.spawn_shot(cx["caster"], start, dv * spd, 0.0, rng / spd, size, col, extra)

## What a projectile does when it touches someone ("pass" or "hit") and when it ends.
static func _shot_event(st: StageSpec, cx: Dictionary, s: Dictionary, at: Vector3, e: Ent, why: String, state: Dictionary, hits: Dictionary) -> void:
	if not is_instance_valid(cx["caster"]):
		return
	var dir: Vector2 = (s["vel"] as Vector2).normalized() if (s["vel"] as Vector2).length() > 0.01 else Vector2.ZERO
	if e != null and why in ["pass", "hit"] and is_instance_valid(e):
		state["hits"] = int(state["hits"]) + 1
		state["seen"][e.get_instance_id()] = true
		var pc := st.modifier("pierce")
		var limit := (int(pc.params["count"]) + 1) if pc else 1
		if st.has_modifier("return") and not pc: limit = 2
		if int(state["hits"]) <= limit or why == "hit":
			var c2 := cx.duplicate(); c2["hits"] = hits
			_hit(st.effects, st, [e], c2, at, float(st.delivery.params["size"]) + 0.5)
			_chain(st, e, c2)
			_then(st, "on_hit", cx, e.pos, dir, e)
			if int(state["bounce"]) > 0:
				_bounce(st, cx, at, e, state, hits)
		if pc and int(state["hits"]) >= limit:
			s["life"] = 0.0           # it has gone through as many as it can
	if why != "pass":
		var ecb = cx.get("on_shot_end")
		if ecb is Callable and (ecb as Callable).is_valid():
			(ecb as Callable).call(at, why, e)
		_then(st, "on_end", cx, at, dir)
		_linger(st, cx, at)

## Bounce: flies on to the nearest other foe, a little weaker.
static func _bounce(st: StageSpec, cx: Dictionary, at: Vector3, from_e: Ent, state: Dictionary, hits: Dictionary) -> void:
	var bm := st.modifier("bounce")
	var best: Ent = null; var bd := float(bm.params["range"])
	for f in cx["m"].foes_of(int(cx["team"])):
		if f == from_e or (state["seen"] as Dictionary).has(f.get_instance_id()) or not f.hittable():
			continue
		var d := Vector2(f.pos.x - at.x, f.pos.z - at.z).length()
		if d < bd: bd = d; best = f
	if best == null:
		return
	var c2 := cx.duplicate()
	c2["k"] = float(cx.get("k", 1.0)) * (1.0 - float(bm.params["falloff"]))
	var dv := Vector2(best.pos.x - at.x, best.pos.z - at.z).normalized()
	var p := st.delivery.params
	var st2 := {"hits": 0, "bounce": int(state["bounce"]) - 1, "seen": state["seen"]}
	_shoot(st, c2, Vector3(at.x, best.pos.y + 0.6, at.z), dv, float(p["speed"]), bd + 1.5, float(p["size"]), _color(st), st2, hits)

## Chain: the hit arcs on to nearby foes, one after another.
static func _chain(st: StageSpec, first: Ent, cx: Dictionary) -> void:
	var ch := st.modifier("chain")
	if ch == null or not is_instance_valid(first):
		return
	var m: Node = cx["m"]
	var col := _color(st)
	var seen := [first]
	var from: Ent = first
	var k := float(cx.get("k", 1.0))
	for i in int(ch.params["count"]):
		var best: Ent = null; var bd := float(ch.params["range"])
		for f in m.foes_of(int(cx["team"])):
			if seen.has(f) or not f.hittable(): continue
			var d := from.flat_dist(f)
			if d < bd: bd = d; best = f
		if best == null:
			break
		seen.append(best)
		k *= 1.0 - float(ch.params["falloff"])
		m.fx.bolt(from.pos + Vector3(0, 0.8, 0), best.pos + Vector3(0, 0.8, 0), col)
		var c2 := cx.duplicate(); c2["k"] = k
		_hit(st.effects, st, [best], c2, best.pos, 0.6)
		from = best
	if seen.size() > 1:
		m.sfx("zap", first.pos, -4.0)

static func _cone(st: StageSpec, cx: Dictionary) -> void:
	var m: Node = cx["m"]
	var p := st.delivery.params
	var from := _origin(st, cx)
	var dir := _dir(st, cx, from)
	var r := float(p["radius"])
	var cosv := cos(deg_to_rad(float(p["angle"])) * 0.5)
	var col := _color(st)
	m.fx.cone(from, dir, r, col)
	m.sfx("whoosh", from, -4.0, 0.9)
	var foes: Array = []
	for f in m.foes_of(int(cx["team"])):
		var to := Vector2(f.pos.x - from.x, f.pos.z - from.z)
		if f.hittable() and to.length() < r + f.r and (to.length() < 0.6 or to.normalized().dot(dir) > cosv) and absf(f.pos.y - from.y) < 2.2:
			foes.append(f)
	var hit := _hit(st.effects, st, foes, cx, from, r)
	for f in hit:
		_then(st, "on_hit", cx, f.pos, dir, f)
	_linger(st, cx, from + Vector3(dir.x, 0, dir.y) * r * 0.5)

static func _beam(st: StageSpec, cx: Dictionary) -> void:
	var p := st.delivery.params
	var dur := float(p["duration"])
	if dur <= 0.0:
		_beam_once(st, cx, 1.0)
		return
	# a channel: it ticks every 0.25s from wherever the caster is now, its total spread over the channel
	var ticks := maxi(1, int(round(dur / 0.25)))
	for i in ticks:
		var c2 := cx.duplicate()
		c2.erase("hits")
		cx["m"].later(0.25 * i, func(): if is_instance_valid(c2["caster"]) and not c2["caster"].dead: _beam_once(st, c2, 1.0 / float(ticks)))

static func _beam_once(st: StageSpec, cx: Dictionary, share: float) -> void:
	var m: Node = cx["m"]
	var p := st.delivery.params
	var from := _origin(st, cx)
	var unit := _origin_unit(st, cx)
	var dir := _dir(st, cx, from)
	var rng := float(p["range"]); var half := float(p["width"]) * 0.5
	if bool(p["seek"]):
		# lock onto the foe nearest the aim, within range
		var aim: Vector3 = cx.get("aim", from)
		var best: Ent = null; var bd := 1e9
		for f in m.foes_of(int(cx["team"])):
			if not f.hittable() or Vector2(f.pos.x - from.x, f.pos.z - from.z).length() > rng + f.r or absf(f.pos.y - from.y) > 3.0:
				continue
			var d := Vector2(f.pos.x - aim.x, f.pos.z - aim.z).length()
			if d < bd: bd = d; best = f
		if best:
			dir = Vector2(best.pos.x - from.x, best.pos.z - from.z).normalized()
	var a2 := Vector2(from.x, from.z); var b2 := a2 + dir * rng
	var cand: Array = []
	for f in m.foes_of(int(cx["team"])):
		if not f.hittable() or absf(f.pos.y - from.y) > 2.4: continue
		var fp := Vector2(f.pos.x, f.pos.z)
		var c := Geometry2D.get_closest_point_to_segment(fp, a2, b2)
		if fp.distance_to(c) < half + f.r:
			cand.append([a2.distance_to(c), f])
	cand.sort_custom(func(x, y): return x[0] < y[0])
	var pc := st.modifier("pierce")
	var n := (int(pc.params["count"]) + 1) if pc else 1
	var foes: Array = []
	for i in mini(n, cand.size()):
		foes.append(cand[i][1])
	var end := b2
	if not foes.is_empty() and foes.size() >= n:
		end = Vector2((foes[-1] as Ent).pos.x, (foes[-1] as Ent).pos.z)
	var y0 := from.y + _height(unit)
	var col := _color(st)
	m.fx.bolt(Vector3(a2.x, y0, a2.y), Vector3(end.x, from.y + 0.7, end.y), col)
	m.sfx("zap", from, -5.0, 1.2)
	var c2 := cx.duplicate(); c2["k"] = float(cx.get("k", 1.0)) * share
	var hit := _hit(st.effects, st, foes, c2, Vector3(end.x, from.y, end.y), half)
	if not hit.is_empty():
		_chain(st, hit[0], c2)
	for f in hit:
		_then(st, "on_hit", cx, f.pos, dir, f)
	_linger(st, cx, Vector3(end.x, from.y, end.y))

static func _burst(st: StageSpec, cx: Dictionary) -> void:
	var m: Node = cx["m"]
	var at := _origin(st, cx)
	var r := float(st.delivery.params["radius"])
	var col := _color(st)
	if r > 0.01:
		m.fx.ring(at, r, col, 0.3 if r <= KinParts.BIG_RADIUS else 0.7)
		if r <= KinParts.BIG_RADIUS:
			m.fx.burst(at + Vector3(0, 0.4, 0), col, int(clampf(r * 10.0, 8.0, 30.0)), 5.0, 0.45, 6.0, 1.1)
			m.sfx("boom", at, -3.0 if r > 2.0 else -7.0, 1.3 - minf(0.5, r * 0.1))
			if r > 2.0: m.shake(0.3, at)
		else:
			m.sfx("ping", at, -2.0, 1.1)
		_hit(st.effects, st, _foes_near(cx, at, r), cx, at, r)
	else:
		# radius 0: only the unit at the origin (a self or owner buff)
		_hit(st.effects, st, [], cx, at, 0.0)
		var u := _origin_unit(st, cx)
		if u: m.fx.burst(u.pos + Vector3(0, 0.9, 0), col, 14, 3.0, 0.4)
	_linger(st, cx, at)

static func _zone(st: StageSpec, cx: Dictionary) -> void:
	var m: Node = cx["m"]
	var p := st.delivery.params
	var at := _ground(m, _origin(st, cx), cx["caster"].pos.y)
	var r := float(p["radius"])
	var tick := func(at2: Vector3, _z: Dictionary) -> void:
		if not is_instance_valid(cx["caster"]): return
		var c2 := cx.duplicate(); c2["hits"] = {"n": 0}
		_hit(st.effects, st, _foes_near(cx, at2, r, 2.0), c2, at2, r)
	var end := func(at2: Vector3) -> void:
		if is_instance_valid(cx["caster"]): _then(st, "on_end", cx, at2, cx.get("dir", Vector2.ZERO))
	m.fields.add_kx(cx["caster"], at, r, float(p["duration"]), float(p["every"]), _color(st), tick, end)

static func _aura(st: StageSpec, cx: Dictionary) -> void:
	var m: Node = cx["m"]
	var p := st.delivery.params
	var u := _origin_unit(st, cx)
	if u == null:
		return
	var r := float(p["radius"])
	var tick := func(at2: Vector3, _z: Dictionary) -> void:
		if not is_instance_valid(cx["caster"]): return
		var c2 := cx.duplicate(); c2["hits"] = {"n": 0}
		_hit(st.effects, st, _foes_near(cx, at2, r, 2.0), c2, at2, r)
	var end := func(at2: Vector3) -> void:
		if is_instance_valid(cx["caster"]): _then(st, "on_end", cx, at2, Vector2.ZERO)
	m.fields.add_kx(cx["caster"], u.pos, r, float(p["duration"]), float(p["every"]), _color(st), tick, end, u)

static func _summon(st: StageSpec, cx: Dictionary) -> void:
	var m: Node = cx["m"]
	var p := st.delivery.params
	var at := _ground(m, _origin(st, cx), cx["caster"].pos.y)
	var n := int(p["count"])
	var r := float(p["radius"])
	var sprite := String(p["unit"]) == "sprite"
	for i in n:
		var q := at
		if n > 1 and not sprite:
			var a := TAU * float(i) / float(n)
			q = _ground(m, at + Vector3(cos(a), 0, sin(a)) * 1.2, at.y)
		var tick := func(at2: Vector3, _z: Dictionary) -> void:
			if not is_instance_valid(cx["caster"]): return
			var c2 := cx.duplicate(); c2["hits"] = {"n": 0}
			_hit(st.effects, st, _foes_near(cx, at2, r, 2.0), c2, at2, r)
		var end := func(at2: Vector3) -> void:
			if is_instance_valid(cx["caster"]): _then(st, "on_end", cx, at2, Vector2.ZERO)
		m.fields.add_kx(cx["caster"], q, r, float(p["duration"]), float(p["every"]), _color(st), tick, end, cx["caster"] if sprite else null, "sprite" if sprite else "totem")

static func _trap(st: StageSpec, cx: Dictionary) -> void:
	var m: Node = cx["m"]
	var p := st.delivery.params
	var at := _ground(m, _origin(st, cx), cx["caster"].pos.y)
	var n := int(p["count"])
	var spread := float(p["spread"])
	var d := _dir(st, cx, at)
	var col := _color(st)
	for i in n:
		var q := at
		if n > 1:
			var a := atan2(d.y, d.x) + TAU * float(i) / float(n)
			q = at + Vector3(cos(a), 0, sin(a)) * spread
			if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z): continue
			q.y = m.world.ground_at(q.x, q.z)
		var fire := func(tat: Vector3, f: Ent) -> void:
			if not is_instance_valid(cx["caster"]): return
			var c2 := cx.duplicate(); c2["hits"] = {"n": 0}
			_hit(st.effects, st, [f], c2, tat, float(p["radius"]))
			_then(st, "on_trigger", cx, tat, d, f)
		var end := func(tat: Vector3) -> void:
			if is_instance_valid(cx["caster"]): _then(st, "on_end", cx, tat, d)
		m.verbs.add_trap(cx["caster"], q, {"radius": float(p["radius"]), "arm": float(p["arm"]), "time": float(p["duration"]), "color": col.to_html(false), "kx": fire, "kx_end": end}, {})

static func _wall(st: StageSpec, cx: Dictionary) -> void:
	var m: Node = cx["m"]
	var p := st.delivery.params
	var origin := String(p["origin"])
	var caster: Ent = cx["caster"]
	var anchor: Ent = _origin_unit(st, cx) if origin != "aim" else caster
	var d := _dir(st, cx, anchor.pos)
	if origin == "owner" and anchor is Hunter:
		d = (anchor as Hunter).aim_dir()
		var th = (anchor as Hunter).last_hit_by
		if th is Ent and is_instance_valid(th) and not th.dead and anchor.flat_dist(th) < 16.0:
			d = anchor.dir_to(th)          # the plate goes up between you and whoever is shooting
	var off := float(p["offset"])
	var at: Vector3
	if origin == "aim":
		at = _origin(st, cx) + Vector3(d.x, 0, d.y) * off
		var o = cx.get("owner")
		if caster is Kin and _alive(o):
			# a kin's wall goes up across YOUR line to the spot, the way you aimed it
			var od := Vector2(at.x - o.pos.x, at.z - o.pos.z)
			if od.length() > 0.3: d = od.normalized()
	else:
		at = anchor.pos + Vector3(d.x, 0, d.y) * off
	at = _ground(m, at, anchor.pos.y)
	var touch := {}
	var reflect := false
	var rk := 1.0
	var pw := float(cx["power"]) * float(cx.get("k", 1.0))
	for e in st.effects:
		match e.type:
			"reflect":
				reflect = true
				rk = minf(float(e.params["power"]), KinRules.REFLECT_MAX)
			"damage":
				if float(e.params["over"]) > 0.0: touch["burn"] = float(e.params["amount"]) * pw / float(e.params["over"])
				else: touch["dmg"] = float(touch.get("dmg", 0.0)) + float(e.params["amount"]) * pw
			"slow":
				touch["slow"] = float(e.params["duration"]); touch["slow_k"] = float(e.params["strength"])
			"push":
				touch["kb"] = float(e.params["strength"])
	var col := _color(st)
	var e2 := {"length": float(p["length"]), "hp": float(p["hp"]), "time": float(p["duration"]), "follow": bool(p["follow"]), "dist": maxf(off, 0.6),
		"reflect": reflect, "rk": rk, "color": col.to_html(false), "touch": touch}
	e2["kx_end"] = func(w: Dictionary) -> void:
		if is_instance_valid(cx["caster"]):
			var mid: Vector2 = ((w["a"] as Vector2) + (w["b"] as Vector2)) * 0.5
			_then(st, "on_end", cx, Vector3(mid.x, float(w["y"]), mid.y), d)
	var wl: Dictionary = m.verbs.add_wall(anchor, at, d, e2, 1.0)
	wl["team"] = int(cx["team"])

static func _tether(st: StageSpec, cx: Dictionary) -> void:
	var m: Node = cx["m"]
	var p := st.delivery.params
	var u := _origin_unit(st, cx)
	if u == null:
		return
	var tgt = cx.get("target")
	if not (tgt is Ent and _alive(tgt) and tgt.team != int(cx["team"])):
		tgt = null
		var aim: Vector3 = cx.get("aim", u.pos)
		var bd := float(p["length"]) * 1.5
		for f in m.foes_of(int(cx["team"])):
			if not f.hittable() or u.flat_dist(f) > float(p["length"]): continue
			var d := Vector2(f.pos.x - aim.x, f.pos.z - aim.z).length()
			if d < bd: bd = d; tgt = f
	if tgt == null:
		return
	var col := _color(st)
	var dir := u.dir_to(tgt)
	m.verbs.add_tether(u, tgt, {"max": float(p["length"]), "time": float(p["duration"]), "color": col.to_html(false), "yank": false,
		"kx_snap": func(_a, b) -> void: if is_instance_valid(cx["caster"]) and is_instance_valid(b): _then(st, "on_snap", cx, b.pos, dir, b),
		"kx_end": func(_a, b) -> void: if is_instance_valid(cx["caster"]) and is_instance_valid(b): _then(st, "on_end", cx, b.pos, dir, b)}, 1.0)
	_hit(st.effects, st, [tgt], cx, tgt.pos, 0.6)

static func _dash(st: StageSpec, cx: Dictionary) -> void:
	var m: Node = cx["m"]
	var p := st.delivery.params
	var u := _origin_unit(st, cx)
	if u == null:
		return
	var dir := _dir(st, cx, u.pos)
	var dist := float(p["distance"]); var spd := float(p["speed"]); var w := float(p["width"])
	var hits: Dictionary = cx["hits"]
	var on_hit := func(f: Ent) -> void:
		if not is_instance_valid(cx["caster"]) or not is_instance_valid(f): return
		var c2 := cx.duplicate(); c2["hits"] = hits
		var got := _hit(st.effects, st, [f], c2, f.pos, w)
		if not got.is_empty(): _then(st, "on_hit", cx, f.pos, dir, f)
	var on_end := func(at: Vector3) -> void:
		if not is_instance_valid(cx["caster"]): return
		_then(st, "on_end", cx, at, dir)
		_linger(st, cx, at)
	if u is Kin and (u as Kin).state in ["active", "returning", "flying_home", "flying"]:
		(u as Kin).start_rush(dir, {"distance": dist, "speed": spd, "width": w, "kx_hit": on_hit, "kx_end": on_end, "color": _color(st).to_html(false)}, {"slot": cx["slot"], "ability": cx["ability"]})
	elif u is Hunter:
		var h := u as Hunter
		h.dash_with({"speed": spd, "time": dist / spd, "kind": "rush", "invuln": 0.0})
		h.roll_dir = dir
		h.dash_pass = {"hit": {}, "kx": on_hit, "w": w}
		m.later(dist / spd, func(): if is_instance_valid(h): on_end.call(h.pos))
	elif u is Kin:
		# a carried kin's dash is done by its hunter (KinExec gets the hunter as the caster then)
		pass

static func _leap(st: StageSpec, cx: Dictionary) -> void:
	var m: Node = cx["m"]
	var p := st.delivery.params
	var u := _origin_unit(st, cx)
	if u == null:
		return
	var aim: Vector3 = cx.get("aim", u.pos)
	var dd := Vector2(aim.x - u.pos.x, aim.z - u.pos.z)
	if dd.length() > float(p["range"]):
		dd = dd.normalized() * float(p["range"])
	var to := _ground(m, Vector3(u.pos.x + dd.x, u.pos.y, u.pos.z + dd.y), u.pos.y)
	var lr := 1.6
	for ev in st.then:
		for sub in st.then[ev]:
			lr = maxf(lr, _reach(sub))
	_telegraph(m, to, lr, _color(st), float(p["time"]))
	var dir := dd.normalized() if dd.length() > 0.05 else _dir(st, cx, u.pos)
	var land := func(at: Vector3) -> void:
		if not is_instance_valid(cx["caster"]): return
		var c2 := cx.duplicate(); c2["hits"] = {"n": 0}
		if not st.effects.is_empty():
			_hit(st.effects, st, _foes_near(cx, at, 1.2), c2, at, 1.2)
		_then(st, "on_land", cx, at, dir)
		_linger(st, cx, at)
	if u is Kin and (u as Kin).state in ["active", "returning", "flying_home", "flying"]:
		(u as Kin).start_leap(to, {"time": float(p["time"]), "height": float(p["height"]), "kx_land": land}, {"slot": cx["slot"], "ability": cx["ability"]})
	elif u is Hunter:
		(u as Hunter).launch_to(to, float(p["time"]))
		m.later(float(p["time"]), func(): if is_instance_valid(u): land.call(u.pos))

static func _blink(st: StageSpec, cx: Dictionary) -> void:
	var m: Node = cx["m"]
	var u := _origin_unit(st, cx)
	if u == null:
		return
	var dir := _dir(st, cx, u.pos)
	var best: Vector3 = u.pos
	var k := float(st.delivery.params["distance"])
	while k > 0.5:
		var q: Vector3 = u.pos + Vector3(dir.x, 0, dir.y) * k
		if not m.world.is_void(q.x, q.z) and not m.world.is_block(q.x, q.z):
			best = Vector3(q.x, m.world.ground_at(q.x, q.z), q.z); break
		k -= 0.5
	var col := _color(st)
	m.fx.burst(u.pos + Vector3(0, 0.8, 0), col, 14, 3.0, 0.3)
	u.teleport(best)
	m.fx.burst(best + Vector3(0, 0.8, 0), col, 14, 3.0, 0.3)
	if not st.effects.is_empty():
		_hit(st.effects, st, _foes_near(cx, best, 1.5), cx, best, 1.5)
	_then(st, "on_end", cx, best, dir)

## Linger: a weaker patch where the delivery ended that repeats its effects (never stun or root).
static func _linger(st: StageSpec, cx: Dictionary, at: Vector3) -> void:
	var lg := st.modifier("linger")
	if lg == null:
		return
	var m: Node = cx["m"]
	var effs: Array = st.effects.filter(func(e): return not (e as PartSpec).is_hard_cc())
	if effs.is_empty():
		return
	var r := float(lg.params["radius"])
	var str_k := float(lg.params["strength"])
	var tick := func(at2: Vector3, _z: Dictionary) -> void:
		if not is_instance_valid(cx["caster"]): return
		var c2 := cx.duplicate(); c2["hits"] = {"n": 0}; c2["k"] = float(cx.get("k", 1.0)) * str_k
		_hit(effs, null, _foes_near(cx, at2, r, 2.0), c2, at2, r, false)
	m.fields.add_kx(cx["caster"], _ground(m, at, at.y), r, float(lg.params["duration"]), float(lg.params["every"]), Color(KinRules.effects_color(effs), 0.8), tick, Callable())

# ------------------------------------------------------------------ effects
## The effects of one delivery event: harmful ones on each foe it touched (up to MAX_HITS for the
## whole delivery), friendly ones (owner, self, allies) once. Returns the foes that were hit.
static func _hit(effs: Array, st: StageSpec, foes: Array, cx: Dictionary, center: Vector3, radius: float, friends := true) -> Array:
	var hits: Dictionary = cx.get("hits", {"n": 0})
	var out: Array = []
	cx["_radius"] = radius
	for f in foes:
		if int(hits.get("n", 0)) >= KinParts.MAX_HITS:
			break
		if not is_instance_valid(f) or f.dead:
			continue
		hits["n"] = int(hits.get("n", 0)) + 1
		apply_foe(effs, f, cx, center, st)
		out.append(f)
	if friends:
		apply_friends(effs, cx, center, radius)
	return out

## The total instant damage a list of effects does (what a reflected shot carries home).
static func _instant_damage(effs: Array, cx: Dictionary) -> float:
	var t := 0.0
	for e in effs:
		if (e as PartSpec).type == "damage" and float(e.params["over"]) <= 0.0:
			t += float(e.params["amount"])
	return t * float(cx["power"]) * float(cx.get("k", 1.0))

## Harmful effects on one foe, as one hit: damage, damage over time, slow, root, stun, push and
## lift ride the hit (so diminishing returns, combos and kin stats all see it); pull, marks and
## signatures follow it.
## base_dmg / base: a hit this rides on (a thrown kin's own hit), merged into the same hit.
static func apply_foe(effs: Array, f: Ent, cx: Dictionary, center: Vector3, st: StageSpec = null, base_dmg := 0.0, base := {}) -> void:
	var m: Node = cx["m"]
	var caster = cx["caster"]
	var by: Ent = caster if _alive(caster) else null
	var k := float(cx.get("k", 1.0))
	var pw := float(cx["power"]) * k
	var slot := String(cx.get("slot", ""))
	var o := {"src": "kin" if caster is Kin else "abil", "ab": slot if slot != "" else "abil", "tags": [slot, String(cx.get("ability", ""))], "dr": true, "chain": cx.get("chain", [])}
	if caster is Kin: o["tags"].append("kin")
	for bk in base: o[bk] = base[bk]
	# an archetype payoff stage marks its hits (payoff: T4 hitstop; crit), so the hit itself carries the weight
	var hx = cx.get("hit_extra")
	if hx is Dictionary:
		for hk in hx: o[hk] = hx[hk]
	var dmg := base_dmg
	var any := base_dmg > 0.0 or not base.is_empty()
	var post: Array = []
	var cats := {}
	var kb := Vector2.ZERO
	for e0 in effs:
		var e: PartSpec = e0
		if e.target != "foes":
			continue
		any = true
		cats[e.category()] = true
		var pr := e.params
		match e.type:
			"damage":
				if float(pr["over"]) > 0.0:
					o["burn"] = maxf(float(o.get("burn", 0.0)), float(pr["amount"]) * pw / float(pr["over"]))
					o["burn_for"] = maxf(float(o.get("burn_for", 0.0)), float(pr["over"]))
				else:
					dmg += float(pr["amount"]) * pw
			"slow":
				o["slow"] = maxf(float(o.get("slow", 0.0)), float(pr["duration"]))
				o["slow_k"] = maxf(float(o.get("slow_k", 0.0)), float(pr["strength"]))
			"root":
				o["root"] = maxf(float(o.get("root", 0.0)), float(pr["duration"]))
			"stun":
				o["stun"] = maxf(float(o.get("stun", 0.0)), float(pr["duration"]))
			"push":
				var from := _point(String(pr["from"]), cx, center)
				var away := Vector2(f.pos.x - from.x, f.pos.z - from.z)
				if away.length() < 0.05: away = cx.get("dir", Vector2(1, 0))
				kb += away.normalized() * float(pr["strength"]) * k
			"lift":
				o["lift"] = maxf(float(o.get("lift", 0.0)), float(pr["strength"]) * k)
			_:
				post.append(e)
	if not any:
		return
	if kb.length() > 0.01:
		o["kb"] = (o.get("kb", Vector2.ZERO) as Vector2) + kb
	var spike := st.modifier("spike") if st else null
	if spike and not f.grounded and f.pos.y > f.ground() + 0.35:
		# airborne: slammed down, harder, and stunned if the spike says so
		dmg *= 1.0 + float(spike.params["bonus"])
		if float(spike.params["stun"]) > 0.0:
			o["stun"] = maxf(float(o.get("stun", 0.0)), float(spike.params["stun"]))
		o.erase("lift")
		m.fx.word(f.pos + Vector3(0, 2.0, 0), "SPIKED", KinRules.cat_color("control"), true)
		f.vel.y = -16.0
	# a hook's yank goes first (then the hit, so its stun lands on the way in)
	for e in post:
		if e.type == "pull" and float(e.params["gap"]) > 0.0:
			_post(e, f, cx, center, k)
	var has_status := o.has("burn") or o.has("slow") or o.has("root") or o.has("stun") or o.has("kb") or o.has("lift")
	if dmg > 0.0 or has_status:
		f.hurt(maxf(0.1, dmg), by, o)
	for e in post:
		if not (e.type == "pull" and float(e.params["gap"]) > 0.0):
			_post(e, f, cx, center, k)
	var col := KinRules.cat_color("control") if cats.has("control") else (KinRules.cat_color("damage") if cats.has("damage") else KinRules.cat_color("utility"))
	m.fx.burst(f.pos + Vector3(0, 0.8, 0), col, 6, 2.5, 0.3)
	# an archetype ability's own follow-up on what it hit (Marks, Shadow Step windows, wall pins)
	var cb = cx.get("on_foe")
	if cb is Callable and (cb as Callable).is_valid() and is_instance_valid(f):
		(cb as Callable).call(f, cx)

## A point an effect works from or toward: the delivery's centre, the kin, or its hunter.
static func _point(which: String, cx: Dictionary, center: Vector3) -> Vector3:
	match which:
		"caster":
			var kn = cx.get("kin")
			if _alive(kn) and (kn as Kin).state in ["active", "flying", "returning"]: return kn.pos
			return cx["caster"].pos if _alive(cx["caster"]) else center
		"owner":
			var o = cx.get("owner")
			return o.pos if _alive(o) else center
	return center

static func _post(e: PartSpec, f: Ent, cx: Dictionary, center: Vector3, k: float) -> void:
	var m: Node = cx["m"]
	var pr := e.params
	match e.type:
		"pull":
			var anchor := _point(String(pr["to"]), cx, center)
			var rel := Vector2(anchor.x - f.pos.x, anchor.z - f.pos.z)
			if float(pr["gap"]) > 0.0:
				# a hook: dragged all the way, stopping this far away
				if rel.length() < float(pr["gap"]) + 0.3:
					return
				var p2 := Vector2(anchor.x, anchor.z) - rel.normalized() * float(pr["gap"])
				var dest := _ground(m, Vector3(p2.x, anchor.y, p2.y), anchor.y)
				m.verbs.yank(f, dest, clampf(rel.length() / maxf(4.0, float(pr["strength"])), 0.14, 0.42), 0.8)
				m.fx.bolt(anchor + Vector3(0, 1.0, 0), f.pos + Vector3(0, 0.9, 0), KinRules.cat_color("control"))
				m.fx.word(f.pos + Vector3(0, 2.0, 0), "HOOKED", KinRules.cat_color("control"), false)
				m.sfx("grab", anchor, -1.0, 1.1)
			elif rel.length() > 0.4:
				var r := maxf(1.0, float(cx.get("_radius", 4.0)))
				f.impulse(rel.normalized() * float(pr["strength"]) * k * clampf(rel.length() / r + 0.3, 0.4, 1.0), 1.0)
		"mark":
			KinRules.mark(f, String(pr["mode"]), float(pr["duration"]), float(pr["amount"]))
			if String(pr["mode"]) == "reveal":
				m.fx.ring(f.pos, 1.2, KinRules.cat_color("utility"), 0.6)
		"signature":
			if String(pr["id"]) == "swap":
				_swap(cx, f, String(pr.get("who", "owner")))

static func _swap(cx: Dictionary, tgt: Ent, who_s: String) -> void:
	var m: Node = cx["m"]
	var who = cx.get("owner") if who_s == "owner" else cx["caster"]
	if not _alive(who): who = cx["caster"]
	if not (_alive(tgt) and tgt.mass() < 6.0 and who is Ent) or tgt == who:
		return
	var col := KinRules.cat_color("utility")
	var a: Vector3 = who.pos; var b: Vector3 = tgt.pos
	m.fx.ghost(who.position, who.face, col, 1.0)
	m.fx.burst(a + Vector3(0, 0.9, 0), col, 16, 4.0, 0.4)
	m.fx.burst(b + Vector3(0, 0.9, 0), col, 16, 4.0, 0.4)
	m.fx.bolt(a + Vector3(0, 1.0, 0), b + Vector3(0, 1.0, 0), col)
	who.teleport(b); tgt.teleport(a)
	who.vel = Vector3.ZERO; tgt.vel = Vector3.ZERO
	if who is Hunter: (who as Hunter).gliding = false
	if tgt is Hunter: (tgt as Hunter).gliding = false
	tgt.grounded = false; who.grounded = false
	m.sfx("cloak", b, -1.0, 1.5)

## The friendly effects of a delivery event: on the owner, the kin itself or allies near it.
static func apply_friends(effs: Array, cx: Dictionary, center: Vector3, radius: float) -> void:
	for e0 in effs:
		var e: PartSpec = e0
		if e.target in ["foes", "wall"]:
			continue
		for t in _friend_targets(e.target, cx, center, radius):
			_friend(e, t, cx, center)

static func _friend_targets(which: String, cx: Dictionary, center: Vector3, radius: float) -> Array:
	var m: Node = cx["m"]
	match which:
		"owner":
			var o = cx.get("owner")
			return [o] if _alive(o) else ([cx["caster"]] if _alive(cx["caster"]) else [])
		"self":
			var kn = cx.get("kin")
			if _alive(kn): return [kn]
			return [cx["caster"]] if _alive(cx["caster"]) else []
		"allies":
			var out: Array = []
			var rad := maxf(radius, 2.0)
			for h in m.hunters:
				if h.team == int(cx["team"]) and not h.out and not h.downed and Vector2(h.pos.x - center.x, h.pos.z - center.z).length() < rad + h.r:
					out.append(h)
					if h.kin and _alive(h.kin) and h.kin.state == "active" and h.kin.flat_dist(center) < rad + 0.5:
						out.append(h.kin)
			return out
	return []

static func _friend(e: PartSpec, t: Ent, cx: Dictionary, center: Vector3) -> void:
	var m: Node = cx["m"]
	var pr := e.params
	var k := float(cx.get("k", 1.0))
	var weak := Effects._weak_k(cx["caster"]) if _alive(cx["caster"]) else 1.0
	var col := KinRules.cat_color(e.category())
	match e.type:
		"shield":
			if "shield" in t:
				t.set("shield", maxf(float(t.get("shield")), float(pr["amount"]) * k * weak))
				if "shield_t" in t: t.set("shield_t", maxf(float(t.get("shield_t")), float(pr["duration"])))
			m.fx.ring(t.pos + Vector3(0, 0.1, 0), 1.0 if t is Hunter else 0.7, col, 0.4)
			m.sfx("shield", t.pos, -3.0)
		"heal":
			var amt := float(pr["amount"]) * k * weak
			if float(pr["over"]) > 0.0:
				var n := maxi(1, int(round(float(pr["over"]) / 0.5)))
				for i in n:
					m.later(0.5 * (i + 1), func(): if is_instance_valid(t) and not t.dead: Effects._heal(t, amt / float(n)))
			else:
				Effects._heal(t, amt)
			m.fx.burst(t.pos + Vector3(0, 1.0, 0), col, 12, 2.5, 0.5, -3.0)
		"cleanse":
			t.slow_t = 0.0; t.root_t = 0.0; t.stun_t = 0.0; t.burn_t = 0.0; t.slow_k = 0.0
			m.fx.burst(t.pos + Vector3(0, 1.0, 0), col, 10, 2.5, 0.4, -3.0)
		"reflect":
			var arc := float(pr["arc"])
			m.verbs.add_mirror(t, {"time": float(pr["duration"]), "radius": float(pr["radius"]), "arc": -1.0 if arc >= 359.0 else cos(deg_to_rad(arc) * 0.5),
				"dmg_k": minf(float(pr["power"]), KinRules.REFLECT_MAX), "color": col.to_html(false)})
		"buff":
			_buff(t, String(pr["stat"]), float(pr["amount"]), float(pr["duration"]), col)
		"lift":
			var d := Vector2.ZERO
			if t is Hunter:
				var mv: Vector2 = (t as Hunter).inp.get("move", Vector2.ZERO)
				d = mv.normalized() if mv.length() > 0.1 else (t as Hunter).aim_dir()
			t.vel = Vector3(d.x * float(pr["forward"]) * k, float(pr["strength"]) * k, d.y * float(pr["forward"]) * k)
			t.grounded = false
			if t is Hunter:
				(t as Hunter).fly_t = 0.5
				(t as Hunter).roll_t = 0.0
			m.fx.burst(t.pos + Vector3(0, 0.3, 0), col, 18, 5.0, 0.5, -2.0)
			m.sfx("whoosh", t.pos, -2.0, 1.2)
		"signature":
			match String(pr["id"]):
				"decoy":
					var own = t if t is Hunter else cx.get("owner")
					if own is Hunter:
						m.verbs.add_decoy(own, (own as Hunter).pos, float(pr.get("duration", 1.8)), col)
				"bridge":
					var c: Ent = cx["caster"]
					var from := _ground(m, c.pos, c.pos.y)
					m.verbs.add_bridge(c, from, _dir_from(cx, from), {"length": float(pr.get("length", 8.0)), "width": float(pr.get("width", 1.3)), "time": float(pr.get("duration", 6.0)), "color": col.to_html(false)})

static func _dir_from(cx: Dictionary, from: Vector3) -> Vector2:
	var aim: Vector3 = cx.get("aim", from)
	var d := Vector2(aim.x - from.x, aim.z - from.z)
	return d.normalized() if d.length() > 0.05 else cx.get("dir", Vector2(1, 0))

## A short boost (KinParts.BUFF_STATS). Hunters keep their own buff timers; a kin gets the
## nearest thing it has (haste, guard).
static func _buff(t: Ent, stat: String, amount: float, dur: float, col: Color) -> void:
	if amount <= 0.0:
		amount = float(KinParts.BUFF_STATS.get(stat, [0, 0, 0])[2])
	if t is Hunter:
		(t as Hunter).add_buff(stat, amount, dur)
	else:
		match stat:
			"move_speed":
				if "haste_t" in t: t.set("haste_t", maxf(float(t.get("haste_t")), dur))
			"guard":
				t.guard_t = maxf(t.guard_t, dur); t.guard_k = amount
	t.m.fx.burst(t.pos + Vector3(0, 0.6, 0), col, 10, 2.5, 0.35)
