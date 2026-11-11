class_name WispFollow
extends RefCounted
## How a riding Boki wisp (KinWisp) keeps to its orbit point at its Hunter's standing shoulder height: a
## critically damped spring on its offset from that point, stepped with the match's fixed step. Its orbit goes
## round its Hunter where their render has them as the next step comes (your own a step ahead,
## Hunter.render_pos), and it is drawn between its last two steps, eased up a terrace with them, so it moves the
## same at 60 or 144 frames a second and a snap of another player's Hunter reaches it smoothed. The damper works
## on the speed relative to the orbit point, so at any steady speed (a run, a glide dive) the wisp keeps its
## place, and a change of speed (a dash, a stop, a landing) swings it back or ahead before it settles in about
## 0.2 s, never more than LEASH away. A jump of more than SNAP in one step is a teleport: it goes along at once.
## Its height takes up the shoulder only while the Hunter stands still (a run's lean, a flip, a dash or a dive
## pose leave it be). The ground, a terrace side or a rock pushes its orbit point out, so the spring smooths a
## turn round a wall, and pushes the wisp itself out as it moves (collision push-out: it slides along a wall),
## so it is never drawn inside the level, even while its Hunter's own body phases into a wall. Presentation
## only: nothing here is synced or read by the rules. --wisp-follow-check measures it.

const OMEGA := 20.0      # 1/s: the spring's rate; a sudden change of speed dv swings it about dv / (OMEGA * e) m
const LEASH := 0.75      # m it may trail or lead its orbit point at most (within 1 m with a push round a wall)
const SNAP := 3.0        # m the orbit point moves in one step that counts as a teleport (180 m/s)
const RISE_RATE := 3.0   # 1/s its height eases to the shoulder of a Hunter standing still (a crouch)
const STILL := 0.5       # m/s: moving slower than this on the ground (by any means), a Hunter stands still
const BALL := BokiWispLook.BODY_RADIUS + BokiWispLook.DART   # m kept clear round it: its body and its dart
const PASSES := 3        # push-outs in a row: one per box of a corner it sits in
const SLIDE := 0.1       # m it moves at most between push-outs (half its ball: a contact never gets deep)
const EDGE := 0.999      # m: a tile's far edge, read as still that tile
const SIDES := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]   # a tile box's four sides

var h: Hunter                  # the Hunter it orbits (a new carrier gets a new follow)
var orbit: Dictionary          # their orbit style (BokiWispCosmetics), read once
var shoulder := KinWisp.SHOULDER_Y   # m: their shoulder above their feet, as last drawn
var has_shoulder := false      # drawn at least once (the first drawing sets the height it orbits at)
var rise := KinWisp.SHOULDER_Y # m: the height it orbits at above their feet: their shoulder as they stand
var goal := Vector3.ZERO       # m: its orbit point at the last step
var off := Vector3.ZERO        # m: the wisp minus its orbit point at the last step
var at := Vector3.ZERO         # m: where the wisp is at the last step
var last_at := Vector3.ZERO    # m: where it was a step before (it is drawn between the two)
var vel := Vector3.ZERO        # m/s: the wisp's own speed
var stamp := -1.0              # s: match time of the last step; a gap starts it again on its orbit point
var has_speed := false         # false: the next step takes its orbit point's speed

func _init(carrier: Hunter) -> void:
	h = carrier
	orbit = BokiWispCosmetics.worn(carrier)["orbit"]

## One fixed step of dt at match time `now`, `angle` (rad) round the orbit: the spring toward the orbit point (out
## of the level), on its leash and out of the level itself.
func step(angle: float, world: World, now: float, dt: float) -> void:
	if has_shoulder and h.grounded and h.roll_t <= 0.0 and (h.pos - h.prev).length() < STILL * dt:
		rise = lerpf(rise, shoulder, 1.0 - exp(-RISE_RATE * dt))
	var ahead := h.render_pos(1.0)      # where the Hunter is drawn as the next step comes
	var to := goal       # held while the Hunter's own shoulder is in the level (a dash phasing into a wall)
	if not has_speed or _top(world, ahead.x, ahead.z) < ahead.y + rise:
		to = clear(world, KinWisp.orbit_spot(orbit, angle, ahead, ahead.y + rise))     # the orbit bends round walls
	var to_vel := (to - goal) / dt
	var starts_over := absf(now - stamp - dt) > dt * 0.5 or to.distance_to(goal) > SNAP
	stamp = now
	goal = to
	last_at = at
	if starts_over:
		at = clear(world, to)
		last_at = at
		off = at - to
		has_speed = false
		return
	if not has_speed:
		vel = to_vel
		has_speed = true
	# the exact step of off'' = -OMEGA^2 off - 2 OMEGA off' (critically damped), so it is stable at any dt
	var slip := vel - to_vel             # m/s: its speed against its orbit point's
	var lean := slip + off * OMEGA
	var fade := exp(-OMEGA * dt)
	var swing := (off + lean * dt) * fade
	slip = (slip - lean * (OMEGA * dt)) * fade
	at = slide(world, last_at, to + swing.limit_length(LEASH))
	# held back by the leash or a wall: its speed is what it really moved, so it never builds up against them
	vel = to_vel + slip if at.is_equal_approx(to + swing) else (at - last_at) / dt
	off = at - to

## Where it is drawn: `alpha` of the way from the step before to the last one, eased up or down a terrace with
## its Hunter (StepSmooth), sliding out of the level (a corner the straight line between two steps cuts).
## `shoulder_y`: the drawn shoulder's height, kept for the next step (the first one is taken as it is); before
## its first step it sits there.
func drawn(shoulder_y: float, world: World, alpha: float) -> Vector3:
	shoulder = shoulder_y - h.position.y
	if not has_shoulder:
		var lift := Vector3(0, shoulder - rise, 0)     # the height it guessed until now gives way to theirs
		at += lift
		last_at += lift
		goal += lift
		rise = shoulder
		has_shoulder = true
	if stamp < 0.0:
		return h.position + Vector3(0, shoulder, 0)
	var between := last_at.lerp(at, alpha)
	return slide(world, between, between + Vector3(0, h.position.y - h.render_pos(alpha).y, 0))

## Moving from `from` to `to` with a push-out at least every SLIDE m, so it slides along the level (over a top
## edge, down a wall) instead of jumping to another way out.
static func slide(world: World, from: Vector3, to: Vector3) -> Vector3:
	var moves := maxi(1, ceili(from.distance_to(to) / SLIDE))
	var spot := from
	for _i in moves:
		spot = clear(world, spot + (to - from) / moves)
	return spot

## The spot nearest `want` where the wisp's ball is clear of the level. Every tile is a column up to its ground
## (BLOCK_H more on a rock, tree or wall tile, as World.los reads them); the ball leaves each column it is in by
## the shortest way, along its gap to the column (on a top, off an edge, along a side: it slides along a wall),
## or when its middle is inside one, out of its nearest way. PASSES times, for a corner of two columns.
static func clear(world: World, want: Vector3) -> Vector3:
	var spot := want
	for _pass in PASSES:
		var pushed := false
		for tile_z in range(floori(spot.z - BALL), floori(spot.z + BALL) + 1):
			for tile_x in range(floori(spot.x - BALL), floori(spot.x + BALL) + 1):
				var near := Vector3(clampf(spot.x, tile_x, tile_x + EDGE), 0.0, clampf(spot.z, tile_z, tile_z + EDGE))
				var top := _top(world, near.x, near.z)
				near.y = minf(spot.y, top)
				var gap := spot - near
				var dist := gap.length()
				if dist >= BALL:
					continue
				pushed = true
				if dist > 0.0001:
					spot += gap * ((BALL - dist) / dist)
				else:
					spot = _out_of(world, spot, top)
		if not pushed:
			break
	return spot

## Its middle is inside the column under it (up to `top`): out the nearest way, over the top or through a side
## whose neighbour stands below its middle (the next pass takes it clear of that one).
static func _out_of(world: World, spot: Vector3, top: float) -> Vector3:
	var best := Vector3(spot.x, top + BALL, spot.z)
	var cost := top + BALL - spot.y
	var inner := Vector2(spot.x - floorf(spot.x), spot.z - floorf(spot.z))     # where in the tile it is, 0..1
	for side in SIDES:
		var along := inner.dot(Vector2(absi(side.x), absi(side.y)))
		var reach := (along if side.x + side.y < 0 else 1.0 - along) + BALL
		var out := spot + Vector3(side.x, 0.0, side.y) * reach
		if reach < cost and _top(world, out.x, out.z) < spot.y:
			best = out
			cost = reach
	return best

## The top (m) of the level at (x, z): the ground, and BLOCK_H above it on a rock, tree or wall tile.
static func _top(world: World, x: float, z: float) -> float:
	return world.ground_at(x, z) + (World.BLOCK_H if world.is_block(x, z) else 0.0)
