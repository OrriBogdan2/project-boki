class_name Displace
extends RefCounted
## Every ability that moves someone else's body goes through here: a teleport (Ostra's Trade, a rock rising
## under a foot), a shove, a spike down, and the tows that move a body over time (Cinder's cloak pull,
## Dredge's reel, Breaker's shield push, Ryzz's Skycall drag, Claire's wall carry, the Nightwell's draw).
##
## A body this game owns moves here, now. A body another game owns (Ent.remote: every other player online,
## and the host's bots and monsters on a guest's game) is moved by ITS game: the same call goes out over Net
## and that game runs this same code on its own body, so a player is pulled exactly as a bot is. Its copy
## here only follows the owner's snapshots; a tow keeps a mirror record here so the caster's kit sees it end.
## Only the game that owns a body applies a move to it (the knock path's rule for hits).
##
## Net (through the "ev" topic; Net.VERSION bump pending):
##   ["disp", "tp",   nid, x, y, z]
##   ["disp", "kb",   nid, kbx, kbz, lift]               an impulse (Ent.impulse)
##   ["disp", "vy",   nid, vy]                           a spike: falling at least this fast
##   ["disp", "tow",  nid, by_nid, params]               a tow starts (params: see tow())
##   ["disp", "stop", nid]                               the caster's game ended it
##   ["disp", "end",  nid, why]                          the owner's game ended it: arrived | walled | time | gone
##   ["disp", "yank", nid, x, y, z, dur, hop]            Verbs.yank on a body another game owns

const CLIFF := 1.2           # m: a rise past which a hauled body is lifted onto the ground ahead instead of walking up
const MAX_T := 5.0           # s: the longest tow another game may ask for
const MAX_SPD := 40.0        # m/s: the fastest
const ARRIVE := 0.05         # m: a tow toward an anchor has arrived this close to its gap
const MIRROR_GRACE := 0.4    # s a mirror waits past its time for the owner's "end" (the reply's trip)

## What a hit's options carry beyond the fixed hit fields (Match.net_send_hit), so a knock on a body another
## game owns lands the same there: its wall-slam stun, steer, weight, diminishing returns, burn time, slow
## strength and Blight. Numbers only (heavy and dr travel as 1).
const HIT_EXTRAS := ["kbi", "wallstun", "heavy", "dr", "slow_k", "burn_for", "blight"]

## Tests read what would go out over Net without a connection.
static var capture := false
static var sent: Array = []

var m: Node
var tows: Array = []         # {e, by, p, left, t, v, gone, mirror, net, hauled}; "end" is set when it stops

func _init(match_node: Node) -> void:
	m = match_node

# ------------------------------------------------------------------ one-off moves
func teleport(e: Ent, p: Vector3) -> void:
	if not e.remote:
		e.teleport(p)
	else:
		_send(["tp", e.nid, m._r(p.x), m._r(p.y), m._r(p.z)])

func knock(e: Ent, kb: Vector2, lift := -1.0) -> void:
	if not e.remote:
		e.impulse(kb, lift)
	else:
		_send(["kb", e.nid, m._r(kb.x), m._r(kb.y), m._r(lift)])

## Spiked down: it falls at least `vy` (a negative speed) fast.
func spike(e: Ent, vy: float) -> void:
	if not e.remote:
		e.vel.y = minf(e.vel.y, vy)
	else:
		_send(["vy", e.nid, m._r(vy)])

## Verbs.yank on a body another game owns: that game runs the same yank.
func yank_remote(e: Ent, to: Vector3, dur: float, hop: float) -> void:
	_send(["yank", e.nid, m._r(to.x), m._r(to.y), m._r(to.z), m._r(dur), m._r(hop)])

# ------------------------------------------------------------------ tows
## Starts moving `e` over time and returns its record (the kit watches rec["end"]). One tow per body: a new
## one replaces the last. params (plain JSON values, sent as they are):
##   mode  "step"  toward the anchor at spd until gap (arrived within ARRIVE of it); a wall on both axes
##                 stops it (walled)
##         "haul"  toward the anchor with weight (swing: 1/s it turns onto the new heading), dragged over
##                 rocks and up cliff faces, only a placed wall stops it; stun: s kept on it each step
##         "glide" toward the anchor at spd, nothing in the way; hold: it stays on (idle) once there
##         "push"  along dir for dist at spd; a block or a step up stops it
##         "slide" along dir: dist over dur, easing out to a stop (its own physics carry it)
##   dur (s), spd (m/s), gap (m), to ([x, y, z]: the anchor when there is no `by`), dir ([x, z]), dist (m),
##   unroll (true: a dash it was in ends)
func tow(e: Ent, by: Ent, p: Dictionary) -> Dictionary:
	_drop(towing(e))
	var rec := {"e": e, "by": by, "p": p, "left": float(p["dur"]), "t": 0.0, "v": Vector2.ZERO, "gone": 0.0,
		"mirror": e.remote, "hauled": 0}
	tows.append(rec)
	if by: DashReset.note(e, by)      # being hauled is crowd control: it counts toward an assist
	if e.remote:
		_send(["tow", e.nid, by.nid if by else "", p])
	elif p.get("unroll", false) and e is Hunter:
		(e as Hunter).roll_t = 0.0
	return rec

func towing(e: Ent) -> Dictionary:
	for rec in tows:
		if rec["e"] == e:
			return rec
	return {}

## The caster ends a tow early (its own reasons: stunned, cancelled, the ult closing).
func stop(rec: Dictionary) -> void:
	if rec.is_empty() or rec.has("end"):
		return
	_finish(rec, "stopped")
	if rec["mirror"] and is_instance_valid(rec["e"]):
		_send(["stop", (rec["e"] as Ent).nid])

func tick(dt: float) -> void:
	for rec in tows.duplicate():
		var e = rec["e"]
		if not is_instance_valid(e) or (e as Ent).dead:
			_finish(rec, "gone")
			continue
		rec["left"] = float(rec["left"]) - dt
		rec["t"] = float(rec["t"]) + dt
		if rec["mirror"]:
			if float(rec["left"]) < -MIRROR_GRACE:
				_finish(rec, "time")
			continue
		var why := _step(rec, e as Ent, dt)
		if why != "":
			_finish(rec, why)

func _step(rec: Dictionary, e: Ent, dt: float) -> String:
	var p: Dictionary = rec["p"]
	var mode := String(p["mode"])
	if mode == "push" or mode == "slide":
		if float(rec["left"]) < 0.0:
			return "time"
		return _push(rec, e, dt) if mode == "push" else _slide(rec, e)
	var by = rec["by"]
	if by != null and (not is_instance_valid(by) or (by as Ent).dead):
		return "gone"
	var a: Vector3 = (by as Ent).pos if by != null else _v3(p["to"])
	var to := Vector2(a.x - e.pos.x, a.z - e.pos.z)
	var dist := to.length()
	var gap := float(p.get("gap", 0.0))
	if dist <= gap + ARRIVE:
		if p.get("hold", false) and float(rec["left"]) > 0.0:
			return ""
		if mode == "haul":
			e.vel.x = 0.0
			e.vel.z = 0.0
		return "arrived"
	if float(rec["left"]) < 0.0:
		return "time"
	match mode:
		"step": return _toward(e, to / dist, minf(float(p["spd"]) * dt, dist - gap))
		"glide":
			var s := to / dist * minf(float(p["spd"]) * dt, dist - gap)
			e.teleport(Vector3(e.pos.x + s.x, e.pos.y, e.pos.z + s.y))
		"haul": return _reel(rec, e, to, dist, gap, dt)
	return ""

## Cinder's cloak pull: a straight step, each axis stopped by what's in the way.
func _toward(e: Ent, dir: Vector2, step: float) -> String:
	var nx := e.pos.x + dir.x * step
	var nz := e.pos.z + dir.y * step
	var bx: float = m.world.occupy(nx, e.pos.z, e.r, e.pos.y, false)
	var bz: float = m.world.occupy(e.pos.x, nz, e.r, e.pos.y, false)
	if bx == 0.0: e.pos.x = nx
	if bz == 0.0: e.pos.z = nz
	return "walled" if bx != 0.0 and bz != 0.0 else ""

## Dredge's reel: hauled toward the anchor with weight (it carries its sideways speed and eases into the new
## heading), stunned while carried.
func _reel(rec: Dictionary, e: Ent, to: Vector2, dist: float, gap: float, dt: float) -> String:
	var p: Dictionary = rec["p"]
	if float(p.get("stun", 0.0)) > 0.0:
		e.stun_t = maxf(e.stun_t, float(p["stun"]))
	var want := to / dist * float(p["spd"])
	var sw := float(p.get("swing", 0.0))
	var v: Vector2 = (rec["v"] as Vector2).lerp(want, 1.0 - exp(-sw * dt)) if sw > 0.0 else want
	rec["v"] = v
	var left := minf(v.length() * dt, dist - gap)
	var dir := v.normalized() if v.length() > 0.01 else to / dist
	var moved := _drag(rec, e, dir, left)
	if moved < left - 0.001 and moved < 0.001 and v.length() > 1.0:
		return "walled"
	return ""

## Moves a body `dist` along `dir` in small steps: over rocks and props and up cliff faces (lifted onto them),
## never through a placed wall. Returns how far it went. Over the void it just goes on.
func _drag(rec: Dictionary, fe: Ent, dir: Vector2, dist: float) -> float:
	var moved := 0.0
	var W: World = m.world
	while moved < dist - 0.001:
		var s := minf(0.2, dist - moved)
		var nx := fe.pos.x + dir.x * s
		var nz := fe.pos.z + dir.y * s
		var gy: float = W.ground_at(nx, nz)
		if not W.dyn_walls.is_empty() and Verbs.wall_blocks(W.dyn_walls, nx, nz, fe.r, fe.pos.y) > 0.0:
			break
		var face: float = W.ground_at(nx + dir.x * fe.r, nz + dir.y * fe.r)
		# a body already falling into the abyss isn't saved
		var standing: bool = gy > World.VOID + 1.0 and fe.pos.y > gy - 0.5
		if standing and face > World.VOID + 1.0 and face - fe.pos.y > CLIFF:
			fe.pos.y = face + 0.5          # hauled up a cliff face
			fe.vel.y = maxf(fe.vel.y, 5.0)
		if W.occupy(nx, nz, fe.r, fe.pos.y, false) != 0.0 and gy > World.VOID + 1.0:
			# a rock or a prop in the way: haul the body up and over it to the first clear spot beyond
			var k := _over(fe, dir, W, s)
			if k <= 0.0:
				break
			rec["hauled"] = int(rec["hauled"]) + 1
			moved += k
			continue
		fe.pos.x = nx
		fe.pos.z = nz
		moved += s
	return moved

## The first clear spot beyond what's in the way (`from` up to 5 m on), the body lifted onto it with a little toss;
## how far that was, or 0 when there is none.
func _over(fe: Ent, dir: Vector2, W: World, from: float) -> float:
	var k := from
	while k < 5.0:
		k += 0.2
		var qx := fe.pos.x + dir.x * k
		var qz := fe.pos.z + dir.y * k
		var qy: float = W.ground_at(qx, qz)
		if qy - fe.pos.y > CLIFF:
			return 0.0
		if W.occupy(qx, qz, fe.r, maxf(fe.pos.y, qy), false) == 0.0:
			fe.pos = Vector3(qx, maxf(fe.pos.y, qy) + 0.5, qz)
			fe.vel.y = maxf(fe.vel.y, 5.0)
			return k
	return 0.0

## Breaker's shield push and Claire's wall carry: along a line at a steady speed.
func _push(rec: Dictionary, e: Ent, dt: float) -> String:
	var p: Dictionary = rec["p"]
	var step := minf(float(p["dist"]) - float(rec["gone"]), float(p["spd"]) * dt)
	if step <= 0.0:
		return "arrived"
	var d := _v2(p["dir"])
	var np := e.pos + Vector3(d.x, 0, d.y) * step
	if m.world.is_block(np.x, np.z) or m.world.ground_at(np.x, np.z) > e.pos.y + 0.8:
		return "walled"
	e.pos = np
	rec["gone"] = float(rec["gone"]) + step
	return ""

## Ryzz's Skycall drag: a slow ground slide that eases out (speed falls straight to zero), covering exactly
## dist over dur unless a wall stops it.
func _slide(rec: Dictionary, e: Ent) -> String:
	var p: Dictionary = rec["p"]
	var v := slide_speed(float(p["dist"]), float(p["dur"]), float(rec["t"])) * _v2(p["dir"])
	e.vel.x = v.x
	e.vel.z = v.y
	if e is Hunter:
		(e as Hunter).knock_t = maxf((e as Hunter).knock_t, 2.0 / 60.0)
	return ""

static func slide_speed(dist: float, dur: float, t: float) -> float:
	return 2.0 * dist / dur * maxf(0.0, 1.0 - t / dur)

func _finish(rec: Dictionary, why: String) -> void:
	rec["end"] = why
	tows.erase(rec)
	if rec.get("net", false) and why != "stopped" and is_instance_valid(rec["e"]):
		_send(["end", (rec["e"] as Ent).nid, why])

## Replaced by a new tow on the same body: gone without a word.
func _drop(rec: Dictionary) -> void:
	if not rec.is_empty():
		rec["end"] = "replaced"
		tows.erase(rec)

# ------------------------------------------------------------------ Net
static func hit_extra(o: Dictionary) -> Dictionary:
	var out := {}
	for k in HIT_EXTRAS:
		if o.has(k):
			out[k] = snappedf(float(o[k]), 0.01)
	return out

static func apply_hit_extra(o: Dictionary, x) -> void:
	if typeof(x) != TYPE_DICTIONARY:
		return
	for k in HIT_EXTRAS:
		if (x as Dictionary).has(k):
			o[k] = float(x[k]) if k not in ["heavy", "dr"] else float(x[k]) > 0.0
func _send(x: Array) -> void:
	var e := ["disp"] + x
	if capture:
		sent.append(e)
	if m.net_on:
		m.net_event(e)

static func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func _v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

## A move another game asked for. Only the game that owns the body applies it ("end" closes a mirror here).
func net_in(x: Array) -> void:
	if x.size() < 3:
		return
	var body: Ent = m.ents_by_id.get(String(x[2]), null)
	if body == null or body.dead:
		return
	var kind := String(x[1])
	if kind == "end":
		var rec := towing(body)
		if not rec.is_empty() and rec["mirror"] and x.size() > 3:
			_finish(rec, String(x[3]))
		return
	if body.remote:
		return
	match kind:
		"tp": if x.size() >= 6: body.teleport(Vector3(x[3], x[4], x[5]))
		"kb": if x.size() >= 6: body.impulse(Vector2(x[3], x[4]), float(x[5]))
		"vy": if x.size() >= 4: body.vel.y = minf(body.vel.y, float(x[3]))
		"yank": if x.size() >= 8: m.verbs.yank(body, Vector3(x[3], x[4], x[5]), float(x[6]), float(x[7]))
		"stop":
			var rs := towing(body)
			if rs.get("net", false): _finish(rs, "stopped")
		"tow": _tow_in(body, x)

func _tow_in(body: Ent, x: Array) -> void:
	if x.size() < 5 or typeof(x[4]) != TYPE_DICTIONARY:
		return
	var p: Dictionary = x[4]
	var by: Ent = null
	if String(x[3]) != "":
		by = m.ents_by_id.get(String(x[3]), null)
		if by == null:
			return
	var along := String(p.get("mode", "")) in ["push", "slide"]
	if not p.has("dur") or not p.has("mode") or not p.has("dir" if along else "spd"):
		return
	if not along and by == null and not p.has("to"):
		return
	p["dur"] = clampf(float(p["dur"]), 0.0, MAX_T)
	if p.has("spd"):
		p["spd"] = clampf(float(p["spd"]), 0.0, MAX_SPD)
	tow(body, by, p)["net"] = true
