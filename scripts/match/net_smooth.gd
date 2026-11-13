class_name NetSmooth
extends RefCounted
## A remote Hunter's snapshot buffer. The body is drawn DELAY behind its owner's clock, on a smooth
## curve between the two snapshots around that moment (cubic Hermite through their positions and
## velocities), so late, jittered or lost snapshots don't make it stutter or overshoot. A move between
## two snapshots faster than SNAP_SPEED (a teleport, a displace's blink) is drawn as one jump, unless the
## velocities the two snapshots report account for it (a kit's scripted dive, like Kitefall's fall).
## Times are the owner's match time from the "st" header; `off` is our match time minus theirs plus the
## line's delay, taken from the quickest arrival of the last OFF_KEEP (so an owner whose clock fell behind,
## a hitch past its 0.1 s step cap, is caught up with within a second). The drawn moment `rt` runs on our
## clock and only leans (SLEW) toward now - off - DELAY, so a quicker arrival or a slower owner bends the
## drawn speed by a few percent instead of jumping the body; out of snapshots it eases to a stop at most
## RUN_ON past the newest (a run-on that kept going jumped 4.8 m in a frame when the next one came in), and
## where the late snapshot puts the body behind its run-on the miss is taken back as it moves on (`fix`).

const DELAY := 0.15         # s drawn behind the quickest arrival: one 0.1 s snapshot gap plus 40 ms of jitter
const RUN_ON := 0.25        # s at most the body runs on along its last velocity when snapshots stop
const SNAP_SPEED := 40.0    # m/s between two snapshots: anything faster is a teleport
const RESYNC := 0.5         # s an arrival is off the usual: a clock was reset, start over
const OFF_KEEP := 10        # arrivals the quickest is taken from (1 s at 10 a second)
const SLEW := 0.1           # share the drawn clock runs faster or slower than ours to close on its mark
const SLEW_FULL := 0.1      # s off its mark at which the drawn clock leans the whole SLEW
const FIX_TAKE := 0.5       # share of the body's own step a run-on's miss is taken back by each frame
const FIX_SLIDE := 0.3      # m/s it is taken back by once the body has stopped, so it still settles
const FIX_STILL := 0.5      # m/s: slower than this the body has stopped (moving, the miss only goes with it,
                            # so taking it back never draws the body stepping back against its way)
const FLOOR_SLACK := 0.05   # m under the floor the last snapshot may be and still have the run-on stop on it
const KEEP := 6             # snapshots kept (0.6 s at 10 a second)
const GUESS_M := 0.01       # m of run-on past the last snapshot that counts as a guess (a standing body never is)

var ts := PackedFloat64Array()
var ps := PackedVector3Array()
var vs := PackedVector3Array()
var off := 0.0
var gaps := PackedFloat64Array()   # our time minus the owner's at each recent arrival
var rt := 0.0               # the owner's time the body is drawn at
var last_now := -1.0        # our time at the last follow (-1: start the drawn clock on its mark)
var fix := Vector3.ZERO     # drawn minus the curve: a run-on's miss, taken back as the body moves on
var last_at := Vector3.ZERO # the curve's point at the last follow
var on_t := -1.0            # the newest snapshot's time while the last follow ran on past it (-1: it didn't)
var on_p := Vector3.ZERO    # and that snapshot's position and velocity
var on_v := Vector3.ZERO
var jumped := false         # a teleport came in: the next follow snaps instead of sweeping
var guessing := false       # drawn running on past its last snapshot: a guess, so it shoves no body (Match._separate)

func push(t_owner: float, now: float, p: Vector3, v: Vector3) -> void:
	var gap := now - t_owner
	var n := ts.size()
	if n > 0 and absf(gap - off) > RESYNC:
		_clear()
		gaps.clear()
		n = 0
	if n > 0 and t_owner <= ts[n - 1]:
		return
	gaps.append(gap)
	if gaps.size() > OFF_KEEP:
		gaps.remove_at(0)
	off = gap
	for g in gaps: off = minf(off, g)
	if n > 0 and p.distance_to(ps[n - 1]) > _reach(p - ps[n - 1], v, vs[n - 1]) * (t_owner - ts[n - 1]):
		_clear()
		jumped = true
	ts.append(t_owner)
	ps.append(p)
	vs.append(v)
	if ts.size() > KEEP:
		ts.remove_at(0)
		ps.remove_at(0)
		vs.remove_at(0)

## Moves the body to where it is drawn at our match time `now`.
func follow(e: Ent, now: float) -> void:
	var n := ts.size()
	guessing = false
	var mark := now - off - DELAY
	var dt := maxf(0.0, now - last_now)
	var fresh := last_now < 0.0 or absf(mark - rt) > RESYNC
	if fresh:
		rt = mark
	else:
		var rate := 1.0 + SLEW * clampf((mark - rt) / SLEW_FULL, -1.0, 1.0)
		var over := rt - ts[n - 1]
		if over > 0.0:
			rate = minf(rate, maxf(0.0, 1.0 - over / RUN_ON))
		rt += dt * rate
	last_now = now
	var at: Vector3
	if rt <= ts[0]:
		at = ps[0]
		e.vel = vs[0]
	elif rt >= ts[n - 1]:
		at = _run_on(e, ps[n - 1], vs[n - 1], rt - ts[n - 1])
		e.vel = vs[n - 1]
		guessing = at.distance_squared_to(ps[n - 1]) > GUESS_M * GUESS_M
	else:
		var i := n - 2
		while ts[i] > rt: i -= 1
		at = _curve(i, rt)
		e.vel = vs[i].lerp(vs[i + 1], (rt - ts[i]) / (ts[i + 1] - ts[i]))
	if fresh or jumped:
		fix = Vector3.ZERO
	elif on_t >= 0.0 and ts[n - 1] > on_t:
		fix += _run_on(e, on_p, on_v, rt - on_t) - at      # a snapshot came in under a run-on: keep its miss
	var moved := at.distance_to(last_at) if not fresh else 0.0
	fix = fix.move_toward(Vector3.ZERO, FIX_TAKE * moved + (FIX_SLIDE * dt if moved < FIX_STILL * dt else 0.0))
	last_at = at
	on_t = ts[n - 1] if rt > ts[n - 1] else -1.0
	on_p = ps[n - 1]
	on_v = vs[n - 1]
	e.pos = at + fix
	if jumped:
		e.prev = e.pos
		jumped = false

## The body `over` s past a snapshot at p moving v: along v, slowing to a stop with the drawn clock, and a
## fall stops on the floor rather than 0.6 m into it (a landing's snapshot came late).
func _run_on(e: Ent, p: Vector3, v: Vector3, over: float) -> Vector3:
	var q := p + v * minf(over, RUN_ON)
	if v.y < 0.0:
		e.pos = q
		var g := e.ground()
		if q.y < g and p.y >= g - FLOOR_SLACK:
			q.y = g
	return q

## The Hermite curve from snapshot i to i + 1 at owner time t. Each end's push along the step is held to 3x the
## step (Fritsch-Carlson), so it can't run past a stop and come back: a lost snapshot before a brake left a
## 0.23 s segment whose 4 m/s start covered 0.94 m against a 0.25 m step, and the body stepped back.
func _curve(i: int, t: float) -> Vector3:
	var h := ts[i + 1] - ts[i]
	var s := (t - ts[i]) / h
	var s2 := s * s
	var s3 := s2 * s
	var d := ps[i + 1] - ps[i]
	var m0 := vs[i] * h
	var m1 := vs[i + 1] * h
	var l := d.length()
	if l < 0.0001:
		m0 = Vector3.ZERO
		m1 = Vector3.ZERO
	else:
		var u := d / l
		m0 -= u * maxf(0.0, m0.dot(u) - 3.0 * l)
		m1 -= u * maxf(0.0, m1.dot(u) - 3.0 * l)
	return (2.0 * s3 - 3.0 * s2 + 1.0) * ps[i] + (s3 - 2.0 * s2 + s) * m0 \
		+ (3.0 * s2 - 2.0 * s3) * ps[i + 1] + (s3 - s2) * m1

## m/s along the move `d` between two snapshots that is still motion: SNAP_SPEED, or twice the faster speed
## the two report along it (a move that speeds up from rest or lands hard between them covers up to that).
## A teleport reports the speed it goes on with, not one along the jump, so it still snaps.
static func _reach(d: Vector3, v: Vector3, v0: Vector3) -> float:
	var along := d.normalized()
	return maxf(SNAP_SPEED, 2.0 * maxf(v.dot(along), v0.dot(along)))

func _clear() -> void:
	ts.clear()
	ps.clear()
	vs.clear()
