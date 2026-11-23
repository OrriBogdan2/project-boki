class_name BotDodge
extends RefCounted
## Bots step out of a hostile ground telegraph (the AimKit shapes a foe shows with "all": a charged
## ult's ring, a lane, a cone). The reaction time is the difficulty's own `react` times READ_K, so an
## easy bot is caught in most of them and a normal one, like a person, mostly gets out. Bots that dash
## spend a real dash charge (Hunter.dashes), never a free one.

const READ_K := 2.0          # a telegraph takes this many times a fresh target's reaction time to read
const MARGIN := 0.6          # m past the rim before a bot stops moving out
const DASH_MIN := 2.5        # m: a dodge this long (or more) is worth a dash charge
const DASH_ABIL := 0.5       # difficulty `abil` from which bots dash out (easy ones only walk)
const FOOT_PAD := 0.3        # m: the footprint is judged a little wider than it is drawn
const LOOK_M := 4.0          # m ahead along the way out that must not be the void

## The way out of the worst hostile telegraph the hunter stands in: {"dir": Vector2, "need": metres to
## clear it}, or {} when it is in none. Only circles, lanes and cones; only foes' shapes that show to all.
static func way_out(m: Match, h: Hunter) -> Dictionary:
	var layer := m.get_node_or_null("AimKit") as AimDraw
	if layer == null:
		return {}
	var best := {}
	for e in layer.entries.values():
		var o := e["h"] as Hunter
		if not e["all"] or o.team == h.team or not layer.live(e):
			continue
		var out := _out_of(e, h.pos)
		if not out.is_empty() and (best.is_empty() or float(out["need"]) > float(best["need"])):
			best = out
	return best

## Move for a bot standing in a hostile telegraph: wait out the reaction time, then walk (or dash) clear.
## `move` comes back unchanged while it is not in one, or has not reacted yet.
static func step(m: Match, h: Hunter, move: Vector2, df: Dictionary, dt: float) -> Vector2:
	var a := h.ai
	var out := way_out(m, h)
	if out.is_empty():
		a.erase("dodge_wait")
		a.erase("dodge_dashed")
		return move
	if not a.has("dodge_wait"):
		a["dodge_wait"] = float(df.get("react", 0.3)) * READ_K * randf_range(0.8, 1.3)
	a["dodge_wait"] = float(a["dodge_wait"]) - dt
	if float(a["dodge_wait"]) > 0.0:
		return move
	var dir: Vector2 = _clear_dir(m, h, out["dir"])
	if dir == Vector2.ZERO:
		return move
	if _may_dash(h, a, df, float(out["need"])):
		a["dodge_dashed"] = true
		a["dash_dir"] = dir
		h.inp["dash"] = true
	return dir

static func _may_dash(h: Hunter, a: Dictionary, df: Dictionary, need: float) -> bool:
	return need >= DASH_MIN and float(df.get("abil", 0.7)) >= DASH_ABIL and h.dashes >= 1.0 \
			and not a.has("dodge_dashed")

## The way out if it does not run off the island; else the two sideways ways; else none.
static func _clear_dir(m: Match, h: Hunter, dir: Vector2) -> Vector2:
	var side := Vector2(-dir.y, dir.x)
	for d: Vector2 in [dir, side, -side]:
		var ahead := Vector2(h.pos.x, h.pos.z) + d * LOOK_M
		if not m.world.is_void(ahead.x, ahead.y):
			return d
	return Vector2.ZERO

static func _out_of(e: Dictionary, p: Vector3) -> Dictionary:
	match String(e["kind"]):
		"circle": return _out_circle(e, p)
		"lane": return _out_lane(e, p)
		"cone": return _out_cone(e, p)
	return {}

static func _out_circle(e: Dictionary, p: Vector3) -> Dictionary:
	var at: Vector2 = e["at"]
	var from := Vector2(p.x, p.z) - at
	var r := float(e["r"])
	if from.length() > r + FOOT_PAD:
		return {}
	var dir := from.normalized() if from.length() > 0.05 else Vector2.RIGHT
	return {"dir": dir, "need": r - from.length() + MARGIN}

static func _out_lane(e: Dictionary, p: Vector3) -> Dictionary:
	var origin: Vector2 = e["from"]
	var dir: Vector2 = e["dir"]
	var width := float(e["width"])
	if not AimMode.in_lane(Vector3(origin.x, p.y, origin.y), dir, float(e["len"]), width, p, FOOT_PAD):
		return {}
	var v := Vector2(p.x, p.z) - origin
	var side := v.x * dir.y - v.y * dir.x
	var way := Vector2(dir.y, -dir.x) * (1.0 if side >= 0.0 else -1.0)
	return {"dir": way, "need": width * 0.5 - absf(side) + MARGIN}

static func _out_cone(e: Dictionary, p: Vector3) -> Dictionary:
	var origin: Vector2 = e["from"]
	var dir: Vector2 = e["dir"]
	var deg := float(e["deg"])
	if not AimMode.in_cone(Vector3(origin.x, p.y, origin.y), dir, float(e["len"]), deg, p, float(e["inner"]), FOOT_PAD):
		return {}
	var v := Vector2(p.x, p.z) - origin
	var swing := dir.angle_to(v)
	var way := dir.rotated(signf(swing) * PI * 0.5) if absf(swing) > 0.01 else Vector2(dir.y, -dir.x)
	var edge := v.length() * sin(maxf(0.0, deg_to_rad(deg) * 0.5 - absf(swing)))
	return {"dir": way, "need": edge + MARGIN}
