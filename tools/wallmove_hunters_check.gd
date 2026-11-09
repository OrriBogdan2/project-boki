extends RefCounted
## Per-Hunter wall kick and wall bounce (part of --wallmove-check; DECISIONS 11-07: wall kick and wall
## bounce for everyone, every interaction chainable). Each of the 12 Hunters, in the Training Area's strip
## beside a tall wall, tries both moves from a run, from a jump, out of the dash, and in the air `PRESS_AT`
## seconds after each ability button (LMB, RMB, E, X, Shift; tapped and held). Prints "WHUNT <hunter> ..."
## lines and counts the cases that are blocked. docs/MOVEMENT_FEEL.md lists what is allowed to commit.

const DT := Match.DT
const HUNTERS := ["archer", "ashwick", "bulwark", "dolm", "dredge", "gunslinger", "juggernaut", "mage",
		"ostra", "rimewright", "tender", "thief"]
const KEYS := ["fire", "sec", "sig", "skill", "dash"]
const PRESS_AT := [0.05, 0.2, 0.45, 0.8]   # s after the ability button
const WALL_UPS := 20                # terraces: far taller than any hop or mantle
const START_UP := 12.0              # m above the strip: the air probes start this high on the wall
const RUN_START := 5.0              # m from the wall for the run cases
const DASH_JUMP_AT := 0.1           # s into the dash before the jump (the dash must have its speed to carry)
const DASH_START := 2.5             # m from the wall for the dash cases (a jump out of a dash must still reach it)
const BOUNCE_V := Vector2(6.9, 4.0) # m/s: 30 degrees off the wall's normal, into it at 6.9
const RUN_ANGLE := 25.0             # degrees off the normal for the run bounce (a run is 4.4-4.9 m/s)
## Cases a kit move is allowed to own (the move commits), per Hunter: case-name prefixes, with the cite.
const COMMITS := {
	# Claire's rink skate steers itself: her heading at the wall is head-on (hit within 16 degrees of the normal,
	# which never bounces), so there is no angled hit to rebound. Open: see docs/MOVEMENT_FEEL.md.
	"rimewright": ["bounce:sig/hold", "bounce:skill@"],
}
const SETTLE := 2                   # steps a kick or bounce is given to show

var main: Node
var ac: RefCounted
var m: Match
var P: Hunter
var arch := ""
var face := 0.0                     # x of the wall's face
var low := 0.0                      # strip height
var z0 := 0.0
var blocked: Array = []

## Runs every Hunter; `report` gets (hunter, blocked cases not allowed to commit).
func run(main_node: Node, report: Callable) -> void:
	main = main_node
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	for a in HUNTERS:
		_hunter(a)
		report.call(a, blocked.filter(func(c): return not _commits(a, c)))

func _commits(a: String, case_: String) -> bool:
	for pre in COMMITS.get(a, []):
		if case_.begins_with(pre):
			return true
	return false

func _hunter(a: String) -> void:
	arch = a
	blocked = []
	var r: Array = ac.setup(a, 20.0)
	m = r[0]
	P = r[1]
	P.ctrl = "local"
	var home: Vector3 = r[4]
	low = home.y
	z0 = home.z
	var w: World = m.world
	var hx := int(floor(home.x))
	var hz := int(floor(home.z))
	for dz in range(-6, 7):
		for dx in range(9, 12):
			w.level[w.idx(hx + dx, hz + dz)] = int(round(low / World.LEVEL)) + WALL_UPS
	face = hx + 9.0
	P.set_arch(arch)        # (so P.r is this Hunter's before the first placement)
	_runs()
	_sweeps()
	m.queue_free()

func _fresh(at: Vector3, grounded: bool, v := Vector3.ZERO) -> void:
	P.set_arch(arch)
	P.unlock_all()
	P.out = false
	P.downed = false
	P.hp = P.max_hp
	P.teleport(at)
	P.grounded = grounded
	P.vel = v
	for f in ["pad", "grap", "lfloat", "shove", "charge", "stomp", "abil_charge"]:
		P.set(f, {})
	for f in ["grap_cd", "mantle_cd", "roll_t", "glide_cd", "knock_t", "fly_t", "stun_t", "root_t", "wall_touch_t",
			"fire_cd", "reload_t"]:
		P.set(f, 0.0)
	P.kb_t = -9.0
	P.wall_hit_v = Vector2.ZERO
	P.gliding = false
	P.glide_fuel = 1.0
	P.dropping = false
	P.last_gy = at.y
	P.air_t = 0.0 if grounded else 0.5
	P.dashes = P.max_dashes()
	P.wall_moves.land()
	P.glide_lift.kicked = false
	P.glide_lift.hang_t = 0.0
	for k in ["glide", "jump", "dash", "fire", "sig", "sec", "skill", "sec_hold"]:
		P.inp[k] = false
	P.inp["move"] = Vector2.ZERO
	P.inp["aim"] = Vector3(face, low + 1.0, z0)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()

func _go(keys: Vector2, secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		P.inp["move"] = keys
		if each.is_valid():
			each.call()
		m.step(DT)
		t += DT

## Steps with the keys until the body is touching the wall in the air (or it lands, or a second passes).
func _touch(keys: Vector2) -> void:
	var n := 0
	while P.wall_touch_t <= 0.0 and not P.grounded and n < 60:
		_go(keys, DT)
		n += 1

## Presses jump every step until the body leaves the ground (a jump out of a dash), for at most half a second.
func _jump_out(keys: Vector2) -> void:
	_go(keys, DASH_JUMP_AT)
	var n := 0
	while P.grounded and n < 30:
		P.inp["jump"] = true
		_go(keys, DT)
		n += 1
	P.inp["jump"] = false

## A kick case: n/a when the body never reached the wall (it landed short), else the press must kick.
func _kick_case(what: String) -> void:
	if _at_wall():
		_note(what, _press_jump())

## In the air with the wall within the hop's reach.
func _at_wall() -> bool:
	return not P.grounded and face - P.pos.x - P.r < WallMoves.FACE_REACH

func _kicks() -> int:
	return int(P.stats.get("wall_kicks", 0))

## A jump pressed in the air at the wall: did it kick?
func _press_jump() -> bool:
	var k0 := _kicks()
	P.inp["jump"] = true
	_go(Vector2(1, 0), DT * SETTLE)
	P.inp["jump"] = false
	return _kicks() > k0

func _bounced() -> bool:
	return P.wall_moves.bounce_t > 0.0 or (P.roll_t > 0.0 and P.roll_dir.x < 0.0) or P.vel.x < -1.0

## Steps with the keys until a bounce shows (1), the time is up with the wall never reached fast enough (-1: the
## ability moved you off it, slowed you or landed you: nothing to bounce), or it reached the wall and didn't (0).
func _bounce_run(keys: Vector2, secs: float, each := Callable()) -> int:
	var reached := false
	var t := 0.0
	while t < secs:
		_go(keys, DT, each)
		t += DT
		if _bounced():
			return 1
		reached = reached or (P.wall_touch_t > 0.0 and not P.grounded and P.wall_hit_v.x >= WallMoves.BOUNCE_MIN_INTO)
	return 0 if reached else -1

## What holds the body at a blocked case, for the report.
func _why() -> String:
	var held := {"stun": P.stun_t > 0.0, "grap": P.grap.size() > 0, "gnd": KitStatus.grounded(P),
			"cast_locked": P.ak != null and P.ak.cast_locked(), "lfloat": not P.lfloat.is_empty(),
			"pad": P.pad.size() > 0, "roll": P.roll_t > 0.0, "grounded": P.grounded,
			"cap": P.pos.y > P.last_gy + WallMoves.HOP_CLIMB_CAP, "shove": not P.shove.is_empty(),
			"charge": not P.charge.is_empty(), "glide": P.gliding, "mantling": P.mantling(),
			"knock": P.knock_t > 0.0, "root": P.root_t > 0.0}
	var f: Array = []
	for k in held:
		if held[k]:
			f.append(k)
	return ",".join(f) + " v=(%.1f,%.1f,%.1f)" % [P.vel.x, P.vel.y, P.vel.z]

## ok: true / false, or the bounce result (1 / 0 / -1 = n/a).
func _note(what: String, ok) -> void:
	if (ok is bool and not ok) or (ok is int and ok == 0):
		blocked.append(what + " {" + _why() + "}")

# ------------------------------------------------------------ run, jump, dash
func _runs() -> void:
	var x0 := face - P.r - 0.02 - RUN_START
	var into := Vector2(1, 0)
	# kick from a run: run, jump short of the wall, press again at it
	_fresh(Vector3(x0, low, z0), true)
	_go(into, 0.4)
	var d := face - P.r - P.pos.x
	_go(into, maxf(0.0, d - 0.9) / maxf(P.base_speed, 1.0))
	P.inp["jump"] = true
	_go(into, DT)
	P.inp["jump"] = false
	_touch(into)
	_kick_case("kick:run")
	# kick from a jump: the same, standing start
	_fresh(Vector3(face - P.r - 0.02, low, z0), true)
	P.inp["jump"] = true
	_go(into, DT)
	P.inp["jump"] = false
	_touch(into)
	_kick_case("kick:jump")
	# kick out of the ground dash: dash at the wall, jump (pressed until it takes), press again at the wall
	var xd := face - P.r - 0.02 - DASH_START
	_fresh(Vector3(xd, low, z0), true)
	P.inp["dash"] = true
	_go(into, DT)
	P.inp["dash"] = false
	_jump_out(into)
	_touch(into)
	_kick_case("kick:dash")
	# kick out of the air dash: jump, dash at the wall in the air, press again at it
	_fresh(Vector3(xd, low, z0), true)
	_jump_out(into)
	P.inp["dash"] = true
	_go(into, DT)
	P.inp["dash"] = false
	_touch(into)
	_kick_case("kick:airdash")
	# bounce from a run: angled, run, jump
	var ang := BOUNCE_V.normalized()
	var run_ang := Vector2.from_angle(deg_to_rad(RUN_ANGLE))
	_fresh(Vector3(x0 + 3.0, low, z0 - 1.0), true)
	_go(run_ang, 0.4)
	P.inp["jump"] = true
	_go(run_ang, DT)
	P.inp["jump"] = false
	_note("bounce:run", _bounce_run(run_ang, 1.0))
	# bounce from a jump: airborne at speed (a boosted jump)
	_fresh(Vector3(face - 1.2, low + START_UP, z0 - 1.0), false, Vector3(BOUNCE_V.x, 0.0, BOUNCE_V.y))
	_note("bounce:jump", _bounce_run(ang, 0.6))
	# bounce out of the dash: dash angled, jump out of it, hit the wall
	_fresh(Vector3(xd, low, z0 - 1.0), true)
	P.inp["dash"] = true
	_go(ang, DT)
	P.inp["dash"] = false
	_jump_out(ang)
	_note("bounce:dash", _bounce_run(ang, 1.0))

# ------------------------------------------------------------ out of each ability
func _sweeps() -> void:
	var ang := BOUNCE_V.normalized()
	for key in KEYS:
		for hold in ([false] if key == "dash" else [false, true]):
			var tag := "%s%s" % [key, "/hold" if hold else ""]
			for t in PRESS_AT:
				# kick: in the air against the wall, jump `t` after the button
				_fresh(Vector3(face - P.r - 0.02, low + START_UP, z0), false)
				_touch(Vector2(1, 0))
				P.inp[key] = true
				if key == "sec" and hold:
					P.inp["sec_hold"] = true
				_go(Vector2(1, 0), DT)
				P.inp[key] = hold
				_go(Vector2(1, 0), maxf(0.0, t - DT))
				if _at_wall():     # (a kit move that took you off the wall or down has nothing to kick)
					_note("kick:%s@%.2f" % [tag, t], _press_jump())
				# bounce: reaches the wall `t` after the button, at an angle with speed
				var lead := BOUNCE_V * maxf(t, 0.1)      # (it reaches the wall `t` after the button)
				_fresh(Vector3(face - P.r - 0.02 - lead.x, low + START_UP, z0 - lead.y), false,
						Vector3(BOUNCE_V.x, 0.0, BOUNCE_V.y))
				P.inp["aim"] = P.pos + Vector3(ang.x, 0.0, ang.y) * 6.0  # (moves go where you aim)
				P.inp[key] = true
				if key == "sec" and hold:
					P.inp["sec_hold"] = true
				var first := true
				var each := func():
					P.inp[key] = hold or first
					first = false
				_note("bounce:%s@%.2f" % [tag, t], _bounce_run(ang, maxf(t, 0.1) + 0.5, each))
