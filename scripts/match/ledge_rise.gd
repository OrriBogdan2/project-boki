class_name LedgeRise
extends RefCounted
## The ledge rise (SUPERVIVE's ledge float), one model for a match Hunter and the farm avatar
## (decision 0022, one movement model): which ledge a body in the air catches, the rise up its face,
## the pop over the lip and the fling. The caller owns the body and its own gates (a kit's cast, a
## stun, an open panel) and keeps the rise as a Dictionary (Hunter.lfloat, Home.lfl): {lip, n (into
## the wall), t, max_t, at, last, g0 (glide held when it began), shove, v_in, downed, win, tile}.
## No snap and no fixed path: you gain upward momentum and float up the face while your own keys
## and momentum carry you sideways (Loco.ledge_step); walking never starts one for a player.

const PUSH := MantleCarry.APPROACH_DOT     # keys this far into the wall start a rise
const RISE_MAX := 14.0         # [footage] m/s, the fastest rise from deep in the abyss (HunterMove.rise_vy)
const WALK_VY := 4.0           # [est] m/s up a bot walking into a step starts its rise with
const POP := 2.6               # [est] m/s up as you clear the lip with no jump (a ~0.25m pop)
const OFF := 0.9               # m out from the face: you've let go
const WINDOW := 0.6            # [est] m, the fling window: the last this-many metres below the top (~0.12s)
const FLING_HEIGHT := 0.9      # [est] m a fling timed in the window peaks over the top...
const FLING_SPEED := 7.5       # [est] ...going this fast (m/s) toward your keys (run speed is ~5)
const FLING_EARLY_HEIGHT := 0.2  # [est] m: a jump before the window: only just over the top, at run speed
const LIP_PAD := 0.12          # m over the lip the rise aims for
const DOWNED_PACE := 0.75      # a downed wisp rises this much slower

## What counts as pushing into a face in the air: the keys; with them idle, a shove (`shoved`: over
## the void or off a glide, `hit` the speed the wall stopped) or momentum (MantleCarry). ZERO: none.
static func push_dir(mv: Vector2, shoved: bool, hit: Vector2, carry: MantleCarry) -> Vector2:
	if mv.length() >= 0.3:
		return mv
	if shoved and hit.length() >= 2.0:
		return hit.normalized()
	if carry.v >= MantleCarry.PUSH_SPEED:
		return carry.heading(mv)      # flying in with momentum is a push (item 185b)
	return Vector2.ZERO

## The ledge a body at `pos` (radius r) catches heading `mv`: {} or {x, z, gz, ex, ez}. `grounded`:
## walking into a step (bots only); `void_here`: over the abyss; under an island's lip there any
## wall within reach catches you (Hunter.MANTLE_REACH_ABYSS, WALL_CATCH_REACH); `long_air`: a
## terrace above where you last stood (`last_gy`) counts (GlideLift.airborne_long).
static func find(w: World, pos: Vector3, r: float, mv: Vector2, hvel: Vector2, carry: MantleCarry, grounded: bool,
		void_here: bool, last_gy: float, long_air: bool, reach: float, max_rise: float) -> Dictionary:
	if not grounded and mv.length() > 0.3:
		# a smooth sheer cliff right in front of you has nothing to hold, and its neighbours don't
		# catch you through it either (the deep abyss reach would otherwise reach round its corner)
		var fr := Vector2(pos.x, pos.z) + mv.normalized() * (r + 0.3)
		var fi := Vector2i(int(floor(fr.x)), int(floor(fr.y)))
		if w.inb(fi.x, fi.y) and w.sheer.has(w.idx(fi.x, fi.y)) and w.ground_at(fr.x, fr.y) > pos.y + World.STEP:
			return {}
	var deep := not grounded and void_here and last_gy - pos.y > 0.3
	if deep:
		max_rise = Hunter.MANTLE_REACH_ABYSS      # deep in the abyss, any island wall you touch springs you back up
		# and a wall a short step away catches you too: falling at full speed just off a
		# face while steering along it used to slip past (wall-hug check: 15 of 40 at 3m down)
		reach = r + Hunter.WALL_CATCH_REACH
		var sr := r + Hunter.WALL_CATCH_REACH + 0.6
		for sz in range(int(floor(pos.z - sr)), int(floor(pos.z + sr)) + 1):
			for sx in range(int(floor(pos.x - sr)), int(floor(pos.x + sr)) + 1):
				if w.inb(sx, sz) and w.sheer.has(w.idx(sx, sz)):
					reach = r + 0.4      # a smooth sheer cliff nearby: only the usual reach
	var best := {}
	var bd := 1e9
	for z in range(int(floor(pos.z - reach)), int(floor(pos.z + reach)) + 1):
		for x in range(int(floor(pos.x - reach)), int(floor(pos.x + reach)) + 1):
			if not w.inb(x, z) or w.kind[w.idx(x, z)] != World.T_GROUND:
				continue
			# a smooth sheer cliff (authored maps) has nothing to hold: you can't catch it from the air
			if not grounded and w.sheer.has(w.idx(x, z)):
				continue
			var gz := w.level[w.idx(x, z)] * World.LEVEL
			var dz := gz - pos.y
			if dz < (0.05 if not grounded and void_here else World.STEP + 0.05) or dz > max_rise:
				continue
			var ex := clampf(pos.x, x + 0.06, x + 0.94)
			var ez := clampf(pos.z, z + 0.06, z + 0.94)
			var toward := Vector2(ex - pos.x, ez - pos.z)
			if grounded and toward.dot(mv) <= 0.0:
				continue
			# over the abyss below a lip, steering mostly along a wall still counts as pushing
			# into it (up to ~78 degrees off straight in): SUPERVIVE rarely lets a wall-hugger sink under
			# an island. Elsewhere the rise wants keys or momentum into it, up to ~60 degrees off (MantleCarry)
			if not grounded and toward.length() > 0.01:
				if deep:
					if toward.normalized().dot(mv.normalized()) < 0.2:
						continue
				elif not carry.pushing(toward, mv):
					continue
			if not grounded and not void_here:
				# off the void, only a wall you're heading into and that rises above where you last stood:
				# hopping down a terrace must not float you back up it
				# and one that shares an edge with your tile: the tile ahead along a wall isn't the wall you press
				if absi(x - int(floor(pos.x))) + absi(z - int(floor(pos.z))) > 1:
					continue
				var stepping_back := gz <= last_gy + World.STEP and not long_air
				if stepping_back or (toward.dot(mv) <= 0.0 and toward.dot(hvel) <= 0.0):
					continue
			var d := toward.length()
			if d < bd and d < reach:
				bd = d
				best = {"x": x, "z": z, "gz": gz, "ex": ex, "ez": ez}
	return best

## A new rise up `best` (from find): the rise's Dictionary. `shove`: thrown into the side with no
## keys (it carries you over); `v_in`: the speed you came in with comes over the top (item 185b).
static func begin(best: Dictionary, pos: Vector3, mv: Vector2, glide_held: bool, shove: bool, v_in: float,
		downed: bool, dash_vy := 0.0) -> Dictionary:
	var dir_in := Vector2(float(best["ex"]) - pos.x, float(best["ez"]) - pos.z)
	if dir_in.length() < 0.01:
		dir_in = mv
	return {"lip": float(best["gz"]), "n": dir_in.normalized(), "t": 0.0, "g0": glide_held, "shove": shove,
		"at": Vector2(pos.x, pos.z), "downed": downed, "win": false, "tile": Vector2i(int(best["x"]), int(best["z"])),
		"v_in": v_in, "dash_vy": dash_vy,    # a dash hands over: its speed takes you up the face
		"max_t": HunterMove.rise_time(float(best["gz"]) - pos.y) * (1.35 if downed else 1.0) + 0.3}

## Ticks the rise's clock; true once it has let go on its own: moved out from the face, slid along
## past its end (or teleported), or ran out of time.
static func lets_go(lf: Dictionary, w: World, pos: Vector3, r: float, dt: float) -> bool:
	lf["t"] = float(lf["t"]) + dt
	var here := Vector2(pos.x, pos.z)
	var off := (here - (lf["at"] as Vector2)).dot(-(lf["n"] as Vector2)) > OFF
	var drift := here.distance_to(lf.get("last", here)) > 1.5 or not face_near(w, pos, r, float(lf["lip"]))
	lf["last"] = here
	return off or drift or float(lf["t"]) > float(lf["max_t"])

## Metres still to rise: to just over the lip (a prop on top raises it).
static func left(lf: Dictionary, w: World, pos: Vector3, r: float) -> float:
	var n: Vector2 = lf["n"]
	return maxf(float(lf["lip"]), w.ground_at(pos.x + n.x * (r + 0.3), pos.z + n.y * (r + 0.3))) + LIP_PAD - pos.y

## Up speed this step of the rise.
static func rise_vy(lf: Dictionary, vy: float, to_go: float, dt: float) -> float:
	var up := HunterMove.rise_vy(vy, to_go, DOWNED_PACE if bool(lf["downed"]) else 1.0, RISE_MAX, dt)
	return maxf(up, float(lf.get("dash_vy", 0.0)))

## True the step the fling window near the top opens (cue it so the timing reads).
static func window_opens(lf: Dictionary, to_go: float) -> bool:
	if bool(lf["win"]) or to_go > WINDOW:
		return false
	lf["win"] = true
	return true

## Over the lip: the horizontal velocity you leave with (up: POP). A small pop toward your keys; keys
## still leaning in, or a shove that threw you at it, carry you onto the top; then MantleCarry's exit.
static func pop(lf: Dictionary, hv: Vector2, mv: Vector2, run: float, carry: MantleCarry) -> Vector2:
	var n: Vector2 = lf["n"]
	if mv.length() > 0.3:
		var d := mv.normalized()
		var along := hv.dot(d)
		if along < run * 0.9:
			hv += d * (run * 0.9 - along)
	var launch := HunterMove.mantle_launch(run)
	if (mv.length() > 0.3 and mv.normalized().dot(n) > 0.15) or (bool(lf["shove"]) and mv.length() <= 0.3):
		var short := launch - hv.dot(n)
		if short > 0.0:
			hv += n * short
	return carry.exit(hv, n, mv, float(lf["v_in"]), run, launch)

## A jump during the rise: in the window, a strong fling (higher, faster); earlier, a weaker one.
## Either way toward your keys (or on onto the ledge with none). Returns (vx, vy, vz).
static func fling(lf: Dictionary, pos_y: float, hv: Vector2, mv: Vector2, run: float) -> Vector3:
	var d: Vector2 = mv.normalized() if mv.length() > 0.3 else (lf["n"] as Vector2)
	var timed: bool = lf["win"]
	var spd := FLING_SPEED if timed else run
	var along := hv.dot(d)
	if along < spd:
		hv += d * (spd - along)
	# up speed to peak FLING_HEIGHT (or FLING_EARLY_HEIGHT) over the top from wherever you are on the face
	var to_go := maxf(0.0, float(lf["lip"]) + LIP_PAD - pos_y)
	return Vector3(hv.x, sqrt(2.0 * Hunter.H_GRAV * (to_go + (FLING_HEIGHT if timed else FLING_EARLY_HEIGHT))), hv.y)

## Is there ground at the ledge's height within reach of your side (the face you're rising up)?
static func face_near(w: World, pos: Vector3, r: float, lip: float) -> bool:
	var rr := r + Hunter.WALL_CATCH_REACH + 0.2
	for z in range(int(floor(pos.z - rr)), int(floor(pos.z + rr)) + 1):
		for x in range(int(floor(pos.x - rr)), int(floor(pos.x + rr)) + 1):
			if not w.inb(x, z) or w.kind[w.idx(x, z)] != World.T_GROUND:
				continue
			if absf(w.level[w.idx(x, z)] * World.LEVEL - lip) > 0.05:
				continue
			var ex := clampf(pos.x, x, x + 1.0)
			var ez := clampf(pos.z, z, z + 1.0)
			if Vector2(ex - pos.x, ez - pos.z).length() <= rr:
				return true
	return false
