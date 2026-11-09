class_name DropLaunch
extends RefCounted
## Item 163: the skyship jump is a squad rocket launch. Everyone who jumps with the leader goes out together
## along the ship's heading on one arc, locked in for LOCK_S (no steering, no glider, no keys); Separate breaks
## you off early once SEPARATE_AFTER_S has passed. When the lock ends each Hunter breaks off on their own and
## their glider opens: from there you glide your own way down (SUPERVIVE's drop). Every client times the lock
## from its own jump, so it needs no message of its own.

const LOCK_S := 2.5              # s you are locked into the launch
const SEPARATE_AFTER_S := 1.5    # s before Separate can break you off early
const LAUNCH_SPEED := 14.0       # m/s along the ship's heading; the glide's force sheds it once you break off
const LAUNCH_VY := 6.0           # m/s up out of the hatch: the arc

static func start(h: Hunter, dir: Vector3) -> void:
	h.launch_at = h.m.time
	var d := Vector2(dir.x, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.01 else Vector2.UP
	h.vel = Vector3(d.x * LAUNCH_SPEED, LAUNCH_VY, d.y * LAUNCH_SPEED)

## Still inside the launch (a Separate after SEPARATE_AFTER_S ends it early).
static func locked(h: Hunter) -> bool:
	if not h.dropping or h.launch_at < 0.0:
		return false
	var t: float = h.m.time - h.launch_at
	return t < LOCK_S and not (h.drop_solo and t >= SEPARATE_AFTER_S)

static func can_separate(h: Hunter) -> bool:
	return not locked(h) or h.m.time - h.launch_at >= SEPARATE_AFTER_S

## Drops this step's keys while the launch lasts (AirLimits.gate_drop calls it first).
static func gate(h: Hunter) -> void:
	if not locked(h):
		return
	for key in h.inp:
		if h.inp[key] is bool:
			h.inp[key] = false
	h.inp["move"] = Vector2.ZERO
	h.dash_buf = 0.0

## Every step of a dropping Hunter: the lock over (or broken off early), they break off and the glider opens.
static func tick(h: Hunter) -> void:
	if h.launch_at < 0.0 or not h.dropping or locked(h):
		return
	h.launch_at = -1.0
	if h.m.skydrop and h.drop_follow != null:
		h.m.skydrop.separate(h, true)          # every client does this on its own clock: no message
	if h.diving:
		h._deploy()
	h.m.fx.burst(h.pos, Color("cfeaff"), 12, 5.0, 0.4, 0.0)
	if h == h.m.player:
		h.m.sfx("whoosh", null, -4.0, 1.2)
