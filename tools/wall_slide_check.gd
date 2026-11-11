extends RefCounted
## --wall-slide-check: running into a wall at an angle slides you along it (as in the source). Sable
## (light), Vex (medium) and Kael (heavy) run at 15, 45 and 75 degrees into a straight cliff on The Hollow
## Crown, a placed Tenzo rock and three Hollow Crown prop corners, and dash into the cliff on the ground
## (in the air a dash into a wall is the wall bounce's: WallMoves). Each try starts at full speed half a
## metre out and runs 1 s; the same try on open ground is its reference.
## A try fails when the speed along the wall drops under MIN_TANGENT of the reference's on any step, or
## the Hunter stands still for more than MAX_STOP steps in a row.
## Counts fixed simulation steps; never touches the save. Prints one "WSLIDE ..." line per try and
## "WALL SLIDE CHECK DONE, failures: N".

const DT := 1.0 / 60.0
const STEPS := 60               # 1 s
const LEAD := 0.5               # m: start this far out from the wall, along the run
const MIN_TANGENT := 0.9        # share of the reference's speed along the wall every step must keep
const MAX_STOP := 2             # steps in a row a Hunter may stand still
const STILL := 0.1              # a step that moves under this share of the reference's step counts as still
const HEROES := ["thief", "gunslinger", "juggernaut"]      # Sable, Vex, Kael
const ANGLES := [15.0, 45.0, 75.0]
const CLIFF_RUN := 11.0         # m of straight cliff the slide needs (a dash and the rest of the second)
const ROCK_TURN := 30.0         # degrees: the rock is placed off the map's grid, as an aimed one is

var bad := 0
var m: Match
var w: World
var P: Hunter
var open_spot := Vector3.ZERO       # the reference runs' ground
var rock_spot := Vector3.ZERO

func run(main: Node) -> void:
	await _setup(main)
	open_spot = _flat_spot(9.0)
	rock_spot = _flat_spot(6.0)
	var walls: Array = [_cliff()] + _corners()
	print("WSLIDE surfaces: %s" % ", ".join(walls.map(func(s: Dictionary) -> String:
		return "%s at %s" % [s.get("name", "none"), str(s.get("edge", "-"))])))
	if walls.size() < 4 or walls[0].is_empty():
		bad += 1
	for a in HEROES:
		P.reclass(Arch.weight(a), a, Arch.signature(a))
		for ang in ANGLES:
			for s in walls:
				if s.is_empty(): continue
				_try(a, s, ang, false)
				if s["name"] == "cliff":
					_try(a, s, ang, true)
			_try_rock(a, ang)
	print("WALL SLIDE CHECK DONE, failures: ", bad)
	main.get_tree().quit()

## A quiet Hollow Crown with only the player in it (no mobs, no Boki, the other Hunters parked far off).
func _setup(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 3, "no_drop": true, "god": true})
	m.set_process(false)
	w = m.world
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for k in m.kins: k.queue_free()      # (Boki would shove the runs: Match._separate)
	m.kins.clear()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		h.kin = null
		h.kin2 = null
		if h != P:
			h.teleport(Vector3(-500, 50, -500))
			h.out = true
	P.ctrl = "local"
	P.reclass(Arch.weight(HEROES[-1]), HEROES[-1], Arch.signature(HEROES[-1]))      # the widest body finds the room

## The body's centre where it first touches surface s: its edge point plus the Hunter's reach against it
## (terrain meets the full radius, rocks, trees and walls the slimmer World.BLOCK_BODY one).
func _at(s: Dictionary) -> Vector2:
	var reach: float = P.r if s["name"] == "cliff" else P.r * World.BLOCK_BODY
	return s["edge"] + s["n"] * reach

## One try against surface `s` ({name, t: along the wall, n: out of it, at: the body's centre where it first
## touches, y}): the run's speed along the wall and still steps, step by step, against the open-ground reference.
func _try(hero: String, s: Dictionary, ang: float, dash: bool) -> void:
	var t: Vector2 = s["t"]
	var wish := _wish(s, ang)
	var at: Vector2 = s["at"] if s.has("at") else _at(s)
	var start := at - wish * LEAD
	var ref := _drive(Vector3(open_spot.x, open_spot.y, open_spot.z), wish, t, dash)
	var got := _drive(Vector3(start.x, float(s["y"]), start.y), wish, t, dash)
	var worst := INF
	var still := 0
	var still_max := 0
	for i in STEPS:
		var rt: float = ref[i].x
		if rt > 0.3:
			worst = minf(worst, got[i].x / rt)
		still = still + 1 if got[i].y < ref[i].y * STILL else 0
		still_max = maxi(still_max, still)
	var ok := worst >= MIN_TANGENT and still_max <= MAX_STOP
	if not ok: bad += 1
	var how := "dash" if dash else "run"
	var verdict := "ok" if ok else "FAIL"
	print("WSLIDE %-10s %-16s a%-2d %-4s along %5.1f%% (>= %d%%)  still %d steps (<= %d)  %s" % [
		hero, s["name"], int(ang), how, worst * 100.0, int(MIN_TANGENT * 100.0), still_max, MAX_STOP, verdict])

## A placed Tenzo rock on open ground, turned off the grid: the run meets its long side near one end.
func _try_rock(hero: String, ang: float) -> void:
	var rd: Dictionary = Arch.def("dolm")["rock"]
	var length := float(rd["len"])
	var d := Vector2(1, 0).rotated(deg_to_rad(ROCK_TURN))
	var mid := Vector2(rock_spot.x, rock_spot.z)
	# (someone else's rock, so it is a full wall to the runner; it outlasts the try and no hit breaks it)
	var rock := HeroZones.rock(m, m.hunters[1], rock_spot, d, "wslide", length, 30.0, 999.0, false)
	var t := Vector2(-d.y, d.x)
	var at := mid + t * (length * 0.5 - 0.3) - d * Verbs.wall_reach(rock, P.r)
	_try(hero, {"name": "tenzo rock", "t": t, "n": -d, "at": at, "y": rock_spot.y}, ang, false)
	HeroZones.remove_rock(m, rock)

## Runs 1 s from `at` holding `wish` (dashing on the first step if `dash`): per step, x = speed along t
## (m/s) and y = metres moved.
func _drive(at: Vector3, wish: Vector2, t: Vector2, dash: bool) -> Array:
	_reset(at, wish)
	var out: Array = []
	for i in STEPS:
		var was := Vector2(P.pos.x, P.pos.z)
		P.inp["move"] = wish
		P.inp["aim"] = P.pos + Vector3(wish.x, 0.9, wish.y) * 6.0
		P.inp["dash"] = dash and i == 0
		m.step(DT)
		var d := Vector2(P.pos.x, P.pos.z) - was
		out.append(Vector2(d.dot(t) / DT, d.length()))
	return out

func _reset(at: Vector3, wish: Vector2) -> void:
	P.out = false
	P.gone = false
	P.downed = false
	P.teleport(at)
	P.grounded = true
	P.vel = Vector3(wish.x, 0, wish.y) * P.base_speed
	P.pad = {}
	P.grap = {}
	P.roll_t = 0.0
	P.knock_t = 0.0
	P.fly_t = 0.0
	P.stun_t = 0.0
	P.root_t = 0.0
	P.ex_cd = 0.0
	P.dash_buf = 0.0
	P.wedged_t = 0.0
	P.kb_t = -9.0
	P.gliding = false
	P.dropping = false
	P.dashes = P.max_dashes()
	P.hp = P.max_hp
	P.set_arch(P.arch)      # a fresh kit: no buff from the try before (Sable's Vault haste) carries over
	for k in ["glide", "glide_btn", "jump", "dash", "fire", "sec"]: P.inp[k] = false

## True when a body a little slimmer than the Hunter's fits at every point of `pts`, on ground at y.
func _clear(pts: Array, y: float) -> bool:
	for p in pts:
		if w.occupy(p.x, p.y, P.r * 0.9, y, false) != 0.0 or absf(w.ground_at(p.x, p.y) - y) > 0.05:
			return false
	return true

## Points every `step` m from a to b.
func _line(a: Vector2, b: Vector2, step := 0.25) -> Array:
	var out: Array = []
	var k := int(ceil(a.distance_to(b) / step))
	for i in k + 1:
		out.append(a.lerp(b, float(i) / maxf(1.0, k)))
	return out

## The first straight cliff (three terraces or more up, CLIFF_RUN long, open flat ground in front) whose
## slide path is clear at every angle.
func _cliff() -> Dictionary:
	for iz in range(2, w.h - 2):
		for ix in range(2, w.w - 2):
			var li := w.idx(ix, iz)
			if w.kind[li] != World.T_GROUND: continue
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not _tall(ix - n.x, iz - n.y, int(w.level[li]) + 3): continue
				var nf := Vector2(n)
				for t in [Vector2(-nf.y, nf.x), Vector2(nf.y, -nf.x)]:
					var ok := true
					for k in int(CLIFF_RUN) + 1:      # tile by tile first: cheap
						var tx := ix + int(t.x) * k
						var tz := iz + int(t.y) * k
						if not _tall(tx - n.x, tz - n.y, int(w.level[li]) + 3) or not _open(tx, tz, int(w.level[li])) \
								or not _open(tx + n.x, tz + n.y, int(w.level[li])):
							ok = false
							break
					if not ok: continue
					var s := {"name": "cliff", "t": t, "n": nf, "edge": Vector2(ix + 0.5, iz + 0.5) - nf * 0.5,
						"y": float(w.level[li]) * World.LEVEL}
					if _path_ok(s, _line(_at(s), _at(s) + t * CLIFF_RUN)):
						return s
	return {}

## A tile of ground at least `lv` terraces up.
func _tall(x: int, z: int, lv: int) -> bool:
	return w.inb(x, z) and w.kind[w.idx(x, z)] != World.T_VOID and int(w.level[w.idx(x, z)]) >= lv

## A tile of open ground at terrace lv.
func _open(x: int, z: int, lv: int) -> bool:
	return w.inb(x, z) and w.kind[w.idx(x, z)] == World.T_GROUND and int(w.level[w.idx(x, z)]) == lv

## The run-in at every angle and `after` (where the body goes from the touch on) are clear.
func _path_ok(s: Dictionary, after: Array) -> bool:
	var at := _at(s)
	var pts := after.duplicate()
	for ang in ANGLES:
		pts.append_array(_line(at - _wish(s, ang) * LEAD, at))
	return _clear(pts, s["y"])

func _wish(s: Dictionary, ang: float) -> Vector2:
	return (s["t"] * cos(deg_to_rad(ang)) - s["n"] * sin(deg_to_rad(ang))).normalized()

## Three convex corners of Hollow Crown props of different kinds (crates, ruins, built walls, rocks and
## trees), each with the ground round it open so the run meets the face just before the corner and goes on.
func _corners() -> Array:
	var found := {}
	for iz in range(3, w.h - 3):
		for ix in range(3, w.w - 3):
			var bi := w.idx(ix, iz)
			if w.kind[bi] != World.T_BLOCK: continue
			var what: String = "%s corner" % ("wall" if w.walls.has(bi) else String(w.props.get(bi, "rock or tree")))
			if found.has(what): continue
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c := _corner(ix, iz, n, what)
				if not c.is_empty():
					found[what] = c
					break
			if found.size() >= 3:
				return found.values()
	return found.values()

func _corner(ix: int, iz: int, n: Vector2i, what: String) -> Dictionary:
	var lv := int(w.level[w.idx(ix, iz)])
	var nf := Vector2(n)
	for t in [Vector2i(-n.y, n.x), Vector2i(n.y, -n.x)]:
		# the ground in front of the face and past the corner is open (tiles first: cheap)
		var ok := true
		for o in [n, n * 2, n + t, n * 2 + t, t, t * 2, t - n, t * 2 - n, t - n * 2, t * 2 - n * 2, t - n * 3, n - t]:
			if not _open(ix + o.x, iz + o.y, lv):
				ok = false
				break
		if not ok: continue
		var tf := Vector2(t)
		var corner := Vector2(ix + 0.5, iz + 0.5) + nf * 0.5 + tf * 0.5
		var s := {"name": what, "t": tf, "n": nf, "edge": corner - tf * 0.4, "y": float(lv) * World.LEVEL}
		var rb := P.r * World.BLOCK_BODY
		var after := _line(_at(s), corner + nf * rb)
		for ang in ANGLES:
			var away := (tf * sin(deg_to_rad(ang)) + nf * cos(deg_to_rad(ang))).normalized()
			after.append_array(_line(corner + away * rb, corner + away * rb + _wish(s, ang) * 4.0))
		if _path_ok(s, after):
			return s
	return {}

## A flat open spot, `rad` m clear all round.
func _flat_spot(rad: float) -> Vector3:
	for k in 4000:
		var g: Vector3 = w.random_ground()
		var pts: Array = []
		for i in 16:
			var a := TAU * i / 16.0
			for d in [rad * 0.33, rad * 0.66, rad]:
				pts.append(Vector2(g.x + cos(a) * d, g.z + sin(a) * d))
		if _clear(pts, g.y):
			return g
	return w.random_ground()
