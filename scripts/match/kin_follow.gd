class_name KinFollow
extends RefCounted
## How a Boki walks with you (docs/decisions/0002). The Boki's standing order is Kin.cmd:
##   follow  (default) walks at your side, fights what you fight, comes back between fights
##   guard   holds the spot it was told to (Kin.hold_at) and fights what comes near
##   chase   sticks to one target (Kin.chase_target) until it falls
##   return  on you: the shoulder, the pack, or you ride a mount; safe, and its carried passives are on
## The body states are still Kin.state (active, flying, returning, flying_home, shoulder...).
## Walking is steering on top of an A* path (KinPath): arrive slowing, separation from you, a path
## recomputed on a timer. A Boki that is stuck for stuck_s, or beyond the leash, leaps back to your side
## with a visible arc (never an invisible teleport). When you glide, drop off a ledge or cross a gap it
## cannot walk, it hops onto you (carried, curled up) and hops off once you have been steady on the ground.
## Numbers: content/rules/boki_system.json "follow".

const CMD_IDS := ["guard", "follow", "chase", "return"]       # the index is what goes over the network (KinNet)
const NAMES := {"guard": "Guard", "follow": "Follow", "chase": "Chase", "return": "Return"}
const HEEL_PULL := 4.0     # 1/s: how hard an out-of-place Boki closes on its side spot, on top of your pace

static func rules() -> Dictionary:
	return KinCommand.rules()["follow"]

static func _r(key: String) -> float:
	return float(rules()[key])

# ------------------------------------------------------------------ where
## Where it stands beside you (KinCompanion picks the flank, between you and a threat), or your own spot.
static func side_spot(k: Kin) -> Vector3:
	var o := k.owner_h
	if o == null:
		return k.pos
	var s: Vector3 = k.comp.heel_spot() if k.comp else Vector3.INF
	return s if s != Vector3.INF else o.pos

## Is the Boki fighting alongside you right now? Orders are never refused in a fight (Kin.throw_to).
static func in_combat(k: Kin, p: Vector3) -> bool:
	var o := k.owner_h
	if o != null and k.m.time - o.hurt_at < 3.0:
		return true
	var rad := _r("combat_radius")
	for f in k.m.foes_of(k.team):
		if f.dead or not f.hittable() or Shrubling.hidden(f):
			continue
		if (o != null and f.flat_dist(o) < rad) or f.flat_dist(p) < rad:
			return true
	return false

## The foe you are fighting: the one nearest your cursor, if it is close enough to matter.
static func owner_focus(k: Kin) -> Ent:
	var o := k.owner_h
	if o == null or not o.inp.has("aim"):
		return null
	var aim: Vector3 = o.inp["aim"]
	var best: Ent = null
	var bd := 3.0
	for f in k.m.foes_of(k.team):
		if f.dead or not f.hittable() or Shrubling.hidden(f) or f.flat_dist(o) > _r("engage_range") + 4.0:
			continue
		var d := Vector2(f.pos.x - aim.x, f.pos.z - aim.z).length()
		if d < bd:
			bd = d; best = f
	return best

## How far it may be from you before it hops back, by order.
static func leash(k: Kin) -> float:
	match k.cmd:
		"guard": return _r("guard_leash")
		"chase": return _r("chase_leash")
	return float(KinCommand.rules()["recall_range"])

# ------------------------------------------------------------------ disengage
## An explicit Follow (the wheel) or Call back, given in a fight, means "come to my side and stay": the Boki stops
## picking targets (Kin._sim_active) until a reason ends it. No timer. Out of a fight nothing changes.
static func disengage(k: Kin) -> void:
	k.disengaged = in_combat(k, k.pos)

static func is_disengaged(k: Kin) -> bool:
	return k.disengaged and k.cmd == "follow"

## The reasons (a), (b) of docs/decisions/0002, from Match.on_damage: you hurt a foe (it joins your target), or a foe
## hit it or you from within disengage_range. (c), Sic or Chase, is in set_cmd / sic / Kin._launch.
static func on_damage(target: Ent, by: Ent, d: float) -> void:
	if d <= 0.0 or by == null or target == null or by.team == target.team:
		return
	if by is Hunter and (by as Hunter).kin != null:
		((by as Hunter).kin as Kin).disengaged = false
	var k: Kin = target as Kin if target is Kin else ((target as Hunter).kin if target is Hunter else null)
	if k != null and k.disengaged and by.flat_dist(target) <= _r("disengage_range"):
		k.disengaged = false

# ------------------------------------------------------------------ the order
## Give the order. Returns false (and says why) if it cannot be done. `target` is for chase.
static func set_cmd(k: Kin, cmd: String, target: Ent = null) -> bool:
	if k.dead or k.state in ["downed", "bench", "away", "fused", "reviving"] or k.owner_h == null or k.rest_t > 0.0:
		return false
	var o := k.owner_h
	match cmd:
		"follow":
			k.cmd = "follow"; k.hold_at = Vector3.INF; k.chase_target = null
			disengage(k)
			if k.state == "shoulder":
				hop_off(k)
		"guard":
			k.disengaged = false
			if k.state == "shoulder":
				hop_off(k)
			k.cmd = "guard"; k.chase_target = null
			k.hold_at = k.fly["to"] if not k.fly.is_empty() else k.pos
		"chase":
			if target == null or target.dead or not target.hittable():
				return false
			k.disengaged = false
			k.cmd = "chase"; k.chase_target = target; k.hold_at = Vector3.INF
			k.target = target
			if k.state == "shoulder":
				sic(k, target.pos)
		"return":
			k.disengaged = false
			k.cmd = "return"; k.hold_at = Vector3.INF; k.chase_target = null; k.target = null
			if k.state in ["active", "returning"]:
				if k.flat_dist(o) <= float(KinCommand.rules()["recall_range"]):
					leap(k, o.pos + Vector3(0, 1.5, 0), "shoulder")
				else:
					k.state = "returning"         # too far to leap: it runs back (and hops when it cannot)
			elif k.state == "flying_home" and not k.fly.is_empty():
				k.fly["dest"] = "shoulder"          # already leaping to your side: carry on up onto you
				k.fly["to"] = o.pos + Vector3(0, 1.5, 0)
			# (a Sic in the air: it lands, then Kin._sim_active sends it up onto you)
		_:
			return false
	KinNet.event(k.m, "cmd", k, k.pos, cmd)
	return true

## Sic: an out Boki leaps at a spot (the cursor), hitting what it flies into and staggering what it lands on.
static func sic(k: Kin, p: Vector3) -> void:
	if k.state == "shoulder":
		k.throw_to(p)
		return
	if k.state not in ["active", "returning"] or k.dead:
		return
	var maxd := float(KinCommand.rules()["throw_range"])
	var d2 := Vector2(p.x - k.pos.x, p.z - k.pos.z)
	if d2.length() > maxd:
		d2 = d2.normalized() * maxd
	var tgt := Vector3(k.pos.x + d2.x, 0.0, k.pos.z + d2.y)
	var g: float = k.m.world.ground_at(tgt.x, tgt.z)
	tgt.y = g if g > World.VOID + 1.0 else k.pos.y
	k.st_throws += 1
	k.disengaged = false
	k.fly = {"from": k.pos, "to": tgt, "t": 0.0, "dur": clampf(d2.length() / _r("sic_speed"), 0.18, 0.6), "hit": {}, "sic": true,
		"charge": k.carry_style() == "mount"}
	k.state = "flying"
	k.throw_cd = _r("sic_cd")
	if k.cmd == "return":
		k.cmd = "follow"
	k.hold_at = tgt if k.cmd == "guard" else Vector3.INF
	k.m.sfx("throw", k.pos, -2.0)
	KinNet.event(k.m, "throw", k, tgt)
	CombatBus.kin_thrown.emit(k, k.owner_h)

# ------------------------------------------------------------------ leaps
## A visible leap (an arc) to a spot beside you ("side") or onto you ("shoulder").
static func leap(k: Kin, to: Vector3, dest: String, cmd_hit := false) -> void:
	var dist := Vector2(to.x - k.pos.x, to.z - k.pos.z).length()
	k.fly = {"from": k.pos, "to": to, "t": 0.0, "dur": clampf(dist / 18.0, _r("hop_dur"), 0.7), "hit": {}, "leap": true, "home": true,
		"dest": dest, "height": _r("hop_height"), "cmd": cmd_hit}
	k.state = "flying_home"
	k.vel = Vector3.ZERO
	k.stuck_t = 0.0
	k.m.fx.ring(k.pos, 0.9, Color(k.sp["color"], 0.7), 0.2)
	KinNet.event(k.m, "hop", k, to)

## Back to your side: stuck, or beyond the leash.
static func hop_back(k: Kin) -> void:
	if k.owner_h == null:
		return
	if k.cmd == "return":
		leap(k, k.owner_h.pos + Vector3(0, 1.5, 0), "shoulder")
		return
	var s := side_spot(k)
	if k.cmd == "guard":
		k.hold_at = Vector3.INF
		k.cmd = "follow"
	leap(k, s, "side")

## It lands beside you (Kin._sim_fly_home calls this at the end of a "side" leap).
static func land_side(k: Kin) -> void:
	var to: Vector3 = k.fly["to"]
	k.fly = {}
	k.pos = to
	var g: float = k.m.world.ground_at(to.x, to.z)
	if g > World.VOID + 1.0:
		k.pos.y = g
		k.grounded = true
	k.vel = Vector3.ZERO
	k.state = "active"
	k.m.fx.dust(k.pos, 8)

## Off your shoulder to your side.
static func hop_off(k: Kin) -> void:
	if k.owner_h == null:
		return
	k.settle = 1.0
	leap(k, side_spot(k), "side")

## On you (a glide, a drop, a gap).
static func hop_on(k: Kin) -> void:
	if k.owner_h != null:
		leap(k, k.owner_h.pos + Vector3(0, 1.5, 0), "shoulder")

## You jumped while riding it: you come off into a normal jump, the Boki curls up on your back until you land.
static func on_jump(h: Hunter) -> void:
	var k: Kin = h.kin
	if k != null and k.state == "shoulder" and k.cmd == "return" and k.carry_style() == "mount" and k.giant.is_empty():
		k.cmd = "follow"
		KinNet.event(k.m, "cmd", k, k.pos, "follow")

# ------------------------------------------------------------------ traversal: carry and drop
## Do you have to be carried over this (a glide, a pad, a drop off a ledge, a gap)?
static func need_carry(k: Kin) -> bool:
	var o := k.owner_h
	if o == null or o.dropping:
		return false
	if o.gliding or not o.pad.is_empty() or not o.grap.is_empty():
		return true
	if o.grounded or o.air_t < _r("hop_on_air_s"):
		return false
	var W: World = k.m.world
	var g: float = W.ground_at(o.pos.x, o.pos.z)
	if g <= World.VOID + 1.0 or absf(g - k.pos.y) > KinPath.STEP:
		return true
	if k.m.time - k.gap_at > 0.3:           # (a search, so not every step)
		k.gap_at = k.m.time
		k.gap_v = not KinPath.clear_line(W, Vector2(k.pos.x, k.pos.z), Vector2(o.pos.x, o.pos.z)) and KinPath.find(W, k.pos, o.pos, int(_r("path_window"))).is_empty()
	return k.gap_v

## The ship ride and the opening drop: it rides on your shoulder, never left on the ground or sent leaping
## after you through the sky (it fell into the abyss and went down). It hops off once you are steady on the ground.
static func ride_the_drop(k: Kin) -> void:
	var o := k.owner_h
	if o == null or not (o.riding or o.dropping) or not k.giant.is_empty() or KinMerge.active(o):
		return
	if k.state in ["active", "returning", "flying", "flying_home"]:
		k.fly = {}
		k.state = "shoulder"
		k.settle = 0.0
		k.pos = o.pos + Vector3(0, 1.5, 0)
		k.prev = k.pos

## Carried by traversal (not by order): off again once you have been steady on the ground.
static func carry_tick(k: Kin, dt: float) -> void:
	var o := k.owner_h
	if o == null or k.cmd == "return" or not k.giant.is_empty() or KinMerge.active(o):
		return
	var steady: bool = o.grounded and not o.gliding and o.roll_t <= 0.0 and o.pad.is_empty() and o.grap.is_empty() and not o.downed and not o.dropping
	k.steady_t = k.steady_t + dt if steady else 0.0
	if k.steady_t >= _r("hop_off_steady_s") and k.settle >= 0.35 and k.hesitate_t <= 0.0:
		k.steady_t = 0.0
		hop_off(k)

# ------------------------------------------------------------------ walking
## The velocity it wants to reach `goal` at speed `spd`: A* when the straight walk is blocked, and from the side
## spot, arrive slowing and keeping pace with you (side = true), plus separation from you and your squad.
static func steer(k: Kin, goal: Vector3, dt: float, spd: float, side := true) -> Vector2:
	var from := Vector2(k.pos.x, k.pos.z)
	var to := Vector2(goal.x, goal.z)
	var ts := to - from
	var o := k.owner_h
	var ov := Vector2(o.vel.x, o.vel.z) if o != null and o.grounded else Vector2.ZERO
	var wish := Vector2.ZERO
	if KinPath.clear_line(k.m.world, from, to):
		k.path = []
		if side and ts.length() < 8.0:
			# keep pace like a teammate: your velocity plus a pull to the spot (slows to a stop on it)
			if ts.length() > 0.5 or ov.length() > 0.3:
				wish = (ov + ts * HEEL_PULL).limit_length(maxf(spd * 1.45, ov.length() * 1.3))
		else:
			wish = ts.normalized() * spd
	else:
		var wp := _waypoint(k, goal, dt)
		wish = ((wp if wp != Vector2.INF else to) - from).normalized() * spd      # (no way found: straight on, and the stuck watch hops it back)
	return wish + separation(k) * spd * 0.5

static func _waypoint(k: Kin, goal: Vector3, dt: float) -> Vector2:
	k.path_t -= dt
	var gt := Vector2i(int(floor(goal.x)), int(floor(goal.z)))
	# a search on the timer, or at once when the goal has moved more than a few tiles; never every step
	# (a moving player changes the goal tile all the time), and a failed search backs off for a while
	if k.path_t <= 0.0 or (maxi(absi(k.path_goal.x - gt.x), absi(k.path_goal.y - gt.y)) > int(_r("path_goal_moved")) and k.path_t < _r("path_every_s") * 0.5):
		k.path_goal = gt
		k.path = KinPath.find(k.m.world, k.pos, goal, int(_r("path_window")))
		k.path_t = (_r("path_every_s") + k.rng.randf() * 0.15) if not k.path.is_empty() else _r("path_fail_backoff_s")       # (the jitter spreads the Boki's searches over frames)
		k.path_searches += 1
	var from := Vector2(k.pos.x, k.pos.z)
	while k.path.size() > 1 and from.distance_to(k.path[0]) < 0.6:
		k.path.pop_front()
	if k.path.is_empty():
		return Vector2.INF
	var pick: Vector2 = k.path[0]
	for i in range(mini(k.path.size() - 1, int(_r("path_lookahead"))), -1, -1):     # (a bounded look ahead: the far end is rarely in sight)
		if KinPath.clear_line(k.m.world, from, k.path[i]):
			pick = k.path[i]
			break
	return pick

## A push away from you and your squadmates when it stands too close.
static func separation(k: Kin) -> Vector2:
	var push := Vector2.ZERO
	var rad := _r("separation_r")
	for h in k.m.hunters:
		if h.team != k.team or h.out:
			continue
		var d := Vector2(k.pos.x - h.pos.x, k.pos.z - h.pos.z)
		if d.length() < rad and d.length() > 0.001:
			push += d.normalized() * (1.0 - d.length() / rad)
	return push

## Called after it moved: no progress toward where it wants to go for stuck_s means a visible hop back.
static func watch_stuck(k: Kin, wish: Vector2, dt: float) -> void:
	var o := k.owner_h
	if o == null or k.state not in ["active", "returning"]:
		k.stuck_t = 0.0
		return
	var moved := Vector2(k.pos.x - k.prev.x, k.pos.z - k.prev.z).length() / maxf(dt, 0.0001)
	if wish.length() > 0.8 and moved < wish.length() * 0.25 and k.flat_dist(o) > 3.0 and k.stun_t <= 0.0 and k.root_t <= 0.0:
		k.stuck_t += dt
	else:
		k.stuck_t = maxf(0.0, k.stuck_t - dt * 2.0)
	if k.stuck_t >= _r("stuck_s"):
		k.stuck_t = 0.0
		hop_back(k)

## What it does with no fight: walk at your side (or guard its spot). Returns the velocity it wants.
## May change its state (a hop onto you, a hop back).
static func idle(k: Kin, dt: float, spd: float) -> Vector2:
	var o := k.owner_h
	var dist := k.flat_dist(o)
	if k.cmd == "follow" and need_carry(k):
		hop_on(k)
		return Vector2.ZERO
	if dist > leash(k):
		hop_back(k)
		return Vector2.ZERO
	if k.cmd == "guard" and k.hold_at != Vector3.INF:
		var th := Vector2(k.hold_at.x - k.pos.x, k.hold_at.z - k.pos.z)
		if k.m.world.is_void(k.hold_at.x, k.hold_at.z):
			k.hold_at = Vector3.INF
			k.cmd = "follow"
		elif th.length() > 0.8:
			return th.normalized() * spd * minf(1.0, th.length())
		else:
			return Vector2.ZERO
	return steer(k, side_spot(k), dt, spd)
