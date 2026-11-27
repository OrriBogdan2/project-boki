class_name PadFlight
extends RefCounted
## A map pad's throw (World.pads, the time trial's pad), as the reference's launches: the pad replaces only your
## vertical speed and adds to your planar speed. No scripted path, no set landing, no clamp onto a terrace: you
## fly a plain air flight (Loco.launch_step: the reference's falling step, your keys bend it), the glider opens
## on a press, and a dash, knock or ledge grab works as anywhere in the air. Numbers: content/rules/hunter_move.json
## "jump_pad" (throw_*), tuning.json air.launch_*; docs/MOVEMENT_FEEL.md "Launch arcs", docs/decisions/0179.

const SIM_DT := 1.0 / 60.0  # the solve and the prediction step as the match does
const FLY_T := 6.0  # s a bot steers a flight before it gives up on it (a long throw is ~2.5 s)
const LET_GO := 0.6  # m: a bot predicted this close to its landing lets the keys go and coasts in
static var throw_dash: float = MoveRules.data()["jump_pad"]["throw_dash"]  # x your speed, coming on in a dash
static var throw_carry_max: float = MoveRules.data()["jump_pad"]["throw_carry_max"]  # m/s carried, at most
static var throw_rise: float = MoveRules.data()["jump_pad"]["throw_rise"]  # m of apex, + throw_rise_k x run
static var throw_rise_k: float = MoveRules.data()["jump_pad"]["throw_rise_k"]
static var _boosts := {}  # "from|to|cap" -> boost m/s (pads don't move)


## Launch `h` off a map pad toward `to`: up at rise_vy, plus a boost along the pad's facing (pad -> `to`) sized so
## a standing hunter who touches no key comes down on `to` (boost_for), plus the planar speed it brought (x
## throw_dash in a dash, at most throw_carry_max). A bot steers for `to` through the flight (steer_bot).
static func launch(h: Hunter, to: Vector3) -> void:
	var run := Vector2(to.x - h.pos.x, to.z - h.pos.z)
	var u := run.normalized() if run.length() > 0.01 else h.aim_dir()
	var vy := rise_vy(h.pos, to)
	var carry := (Vector2(h.vel.x, h.vel.z) * (throw_dash if h.roll_t > 0.0 else 1.0)).limit_length(throw_carry_max)
	var hv := carry + u * boost_for(h.pos, to, h.base_speed)
	h.vel = Vector3(hv.x, vy, hv.y)
	h.roll_t = 0.0
	h.grap = {}
	h.pad = {}
	h.grounded = false
	h.glide_cd = 0.0
	h.launch_air = true
	if h.ctrl == "bot":
		h.ai["pad_fly"] = {"land": to, "t": FLY_T}


## Up speed for a throw from `a` to `b`: an apex throw_rise (+ throw_rise_k per metre run) over the higher end,
## the old scripted arc's height, so the throw clears the lip of a climb.
static func rise_vy(a: Vector3, b: Vector3) -> float:
	var run := Vector2(b.x - a.x, b.z - a.z).length()
	return sqrt(2.0 * Hunter.H_GRAV * (maxf(0.0, b.y - a.y) + throw_rise + throw_rise_k * run))


## The pad's boost (m/s along its facing) that lands a no-key flight from `a` on `b` for a run cap `cap`:
## bisected on the same air step and fall the match runs, cached per pad and cap.
static func boost_for(a: Vector3, b: Vector3, cap: float) -> float:
	var key := "%s|%s|%.2f" % [str(a), str(b), cap]
	if _boosts.has(key):
		return _boosts[key]
	var run := Vector2(b.x - a.x, b.z - a.z).length()
	var vy := rise_vy(a, b)
	var lo := 0.0
	var hi := 120.0
	for i in 28:
		var mid := (lo + hi) * 0.5
		if _reach(a.y, Vector2(mid, 0.0), vy, b.y, cap) < run:
			lo = mid
		else:
			hi = mid
	_boosts[key] = hi
	return hi


## Where a flight from `pos` at `vel` comes down at height `y` with no keys held (`cap`: the run cap, `launch`:
## the pad's launch step): the bot's aim point, and the check's.
static func lands(pos: Vector3, vel: Vector3, y: float, cap: float, launch := true) -> Vector3:
	var hv := Vector2(vel.x, vel.z)
	var p := Vector2(pos.x, pos.z)
	var py := pos.y
	var vy := vel.y
	for i in 900:
		hv = Loco.launch_step(hv, Vector2.ZERO, cap, SIM_DT) if launch else Loco.air_step(hv, Vector2.ZERO, cap, SIM_DT)
		var nvy := maxf(vy - Hunter.H_GRAV * SIM_DT, -HunterMove.fall_max)
		var ny := py + 0.5 * (vy + nvy) * SIM_DT
		var np := p + hv * SIM_DT
		if nvy < 0.0 and ny <= y:
			var k := (py - y) / maxf(0.0001, py - ny)
			return Vector3(lerpf(p.x, np.x, k), y, lerpf(p.y, np.y, k))
		p = np
		py = ny
		vy = nvy
	return Vector3(p.x, py, p.y)


## Metres run before a no-key flight up at `vy` with planar `hv` from height `y0` comes down to `y1`.
static func _reach(y0: float, hv: Vector2, vy: float, y1: float, cap: float) -> float:
	var at := lands(Vector3(0.0, y0, 0.0), Vector3(hv.x, vy, hv.y), y1, cap)
	return Vector2(at.x, at.z).length()


## A bot in a pad's flight steers for its planned landing: the keys push against where the flight would come
## down with none held (lands), so one that ran on fast brakes and one knocked off line comes back; close to
## the plan it lets go and coasts in. Falling short over the void it opens the glider and glides in, folding it
## over the landing. False once the flight is over (landed, timed out), so the bot's normal think runs.
static func steer_bot(m: Match, h: Hunter, dt: float) -> bool:
	var pf: Dictionary = h.ai["pad_fly"]
	pf["t"] = float(pf["t"]) - dt
	if (h.grounded and float(pf["t"]) < FLY_T - 0.2) or float(pf["t"]) <= 0.0 or h.downed or h.out:
		h.ai.erase("pad_fly")
		return false
	var land: Vector3 = pf["land"]
	var to := Vector2(land.x - h.pos.x, land.z - h.pos.z)
	var inp := h.inp
	if h.gliding:
		inp["move"] = to.normalized() if to.length() > LET_GO else Vector2.ZERO
		inp["glide"] = to.length() > 1.6 or m.world.is_void(h.pos.x, h.pos.z)
		return true
	var at := lands(h.pos, h.vel, land.y, h.base_speed, h.launch_air)
	var err := Vector2(land.x - at.x, land.z - at.z)
	inp["move"] = (err / 2.0).limit_length(1.0) if err.length() > LET_GO else Vector2.ZERO
	inp["dash"] = false
	# short of the landing over the void and on the way down: the glider carries it the rest
	var short := err.dot(to) > 0.0 and err.length() > 3.0 and m.world.is_void(at.x, at.z)
	inp["glide"] = short and h.vel.y < 1.0
	inp["jump"] = inp["glide"] and h.can_glide()
	if to.length() > 1.0:
		var fly := to.normalized() * 3.0
		inp["aim"] = Vector3(h.pos.x + fly.x, h.pos.y + 0.9, h.pos.z + fly.y)
		inp["aim_y"] = h.pos.y
	return true
