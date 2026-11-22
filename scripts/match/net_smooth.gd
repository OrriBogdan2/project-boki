class_name NetSmooth
extends RefCounted
## A remote Hunter's snapshot buffer. The body is drawn GAP plus a margin behind its owner's clock, on a smooth
## curve between the two snapshots around that moment (cubic Hermite through their positions and
## velocities), so late, jittered or lost snapshots don't make it stutter or overshoot. A move between
## two snapshots faster than SNAP_SPEED (a teleport, a displace's blink) is drawn as one jump, unless the
## velocities the two snapshots report account for it (a kit's scripted dive, like Kitefall's fall).
## Times are the owner's match time from the "st" header; `off` is our match time minus theirs plus the
## line's delay, taken from the quickest recent arrival. The margin on top of one snapshot gap follows how
## late recent snapshots came against that quickest one (a jitter buffer), so a jittery long line (two hops
## of 150 +-20 ms) doesn't run the body on past a dash's end and pull it back (docs/ONLINE_FEEL.md).

const GAP := 0.1            # s between an owner's snapshots (Net.tick's send_t)
const JITTER_MIN := 0.05    # s of margin over GAP at least: the drawn delay is 0.15 s on a steady line
const JITTER_MAX := 0.1     # s of margin at most: a worse line runs on (RUN_ON); 0.24 s behind on a 40 ms line
const JITTER_KEEP := 0.97   # share of the margin kept per snapshot as the line calms (about 2 s to halve)
const SLEW := 0.1           # share the drawn clock runs fast or slow while the margin changes (never backwards)
const RUN_ON := 0.25        # s at most the body runs on along its last velocity when snapshots stop
const SNAP_SPEED := 40.0    # m/s between two snapshots: anything faster is a teleport
const RESYNC := 0.5         # s an arrival is off the usual: a clock was reset, start over
const OFF_EASE := 0.05      # share of a slower-than-usual arrival the clock gap takes on per snapshot
const KEEP := 6             # snapshots kept (0.6 s at 10 a second)
const FLAT_STEPS := 4       # tries between the cubic and a straight line (flattening by a quarter each)
const FLAT_TOL := 1.05      # the curve's fastest speed may be this much over the faster snapshot's (or the average)
const PEAK_SAMPLES := 12    # points of a curve whose speed is looked at
const CATCH := 0.3          # share of its own speed a body that fell behind the curve gains on it per second
const CATCH_MIN := 1.0      # m/s it gains at least (a body at rest still gets there)
const CATCH_REACH := 0.4    # s of its speed a late snapshot may put the curve ahead of a guessing body (more: a jump)
const GUESS_M := 0.01       # m of run-on past the last snapshot that counts as a guess (a standing body never is)

var ts := PackedFloat64Array()
var ps := PackedVector3Array()
var vs := PackedVector3Array()
var off := 0.0
var late := JITTER_MIN      # s: the margin, the latest recent snapshot against the quickest
var jumped := false         # a teleport came in: the next follow snaps instead of sweeping
var drawn := -INF           # s: the owner time the last follow drew
var drawn_at := 0.0         # s: our match time then
var flat_t := -INF          # the pair of snapshots (its first one's time) whose flattening flat_k is
var flat_k := 0.0
var behind := Vector3.ZERO  # m the drawn body is still short of the curve (closed at CATCH of its speed)
var shown := Vector3.ZERO   # where the last follow drew the body
var at_vel := Vector3.ZERO  # _at's velocity and guess flag for the position it returned
var at_guess := false
var guessing := false       # drawn running on past its last snapshot: a guess, so it shoves no body (Match._separate)

func push(t_owner: float, now: float, p: Vector3, v: Vector3) -> void:
	var gap := now - t_owner
	var n := ts.size()
	if n > 0 and absf(gap - off) > RESYNC:
		_clear()
		n = 0
	if n > 0 and t_owner <= ts[n - 1]:
		return
	if n == 0 or gap < off:
		late += off - gap if n > 0 else 0.0
		off = gap
	else:
		late = maxf(late * JITTER_KEEP, gap - off)
		off += (gap - off) * OFF_EASE
	if n > 0 and p.distance_to(ps[n - 1]) > _reach(p - ps[n - 1], v, vs[n - 1]) * (t_owner - ts[n - 1]):
		_clear()
		jumped = true
	var seen := shown
	var was := n > 0 and drawn > -INF and not jumped
	ts.append(t_owner)
	ps.append(p)
	vs.append(v)
	if was and guessing:
		# the body was drawn on a guess past the last snapshot, and the new one puts the curve elsewhere at that moment
		var miss := seen - _at(drawn)
		var room := maxf(vs[n - 1].length(), v.length()) * CATCH_REACH + GUESS_M
		behind = miss if miss.length() <= room else Vector3.ZERO
	if ts.size() > KEEP:
		ts.remove_at(0)
		ps.remove_at(0)
		vs.remove_at(0)

## Moves the body to where it is drawn at our match time `now`.
func follow(e: Ent, now: float) -> void:
	var rt := now - off - GAP - clampf(late, JITTER_MIN, JITTER_MAX)
	# A late snapshot raises the margin at once; the drawn clock eases onto it so the body never steps back
	var dt := now - drawn_at
	if dt >= 0.0 and absf(rt - drawn - dt) < RESYNC:
		rt = clampf(rt, drawn + dt * (1.0 - SLEW), drawn + dt * (1.0 + SLEW))
	drawn = rt
	drawn_at = now
	e.pos = _at(rt)
	e.vel = at_vel
	guessing = at_guess
	if behind != Vector3.ZERO:       # a late snapshot's catch-up is spread over a few frames, not one step
		behind = behind.move_toward(Vector3.ZERO, maxf(CATCH_MIN, CATCH * e.vel.length()) * maxf(dt, 0.0))
		e.pos += behind
	shown = e.pos
	if jumped:
		e.prev = e.pos
		jumped = false

## Where the body is drawn when the owner's clock reads `rt`: before the first snapshot, on it; past the last,
## run on along its velocity for RUN_ON at most (at_guess says so); between two, on the curve.
func _at(rt: float) -> Vector3:
	var n := ts.size()
	at_guess = false
	if rt <= ts[0]:
		at_vel = vs[0]
		return ps[0]
	if rt >= ts[n - 1]:
		var run_on := vs[n - 1] * minf(rt - ts[n - 1], RUN_ON)
		at_vel = vs[n - 1]
		at_guess = run_on.length_squared() > GUESS_M * GUESS_M
		return ps[n - 1] + run_on
	var i := n - 2
	while ts[i] > rt: i -= 1
	var h := ts[i + 1] - ts[i]
	var s := (rt - ts[i]) / h
	var s2 := s * s
	var s3 := s2 * s
	var k := _flatten(i)
	var m0 := (vs[i] * h).lerp(ps[i + 1] - ps[i], k)
	var m1 := (vs[i + 1] * h).lerp(ps[i + 1] - ps[i], k)
	at_vel = vs[i].lerp(vs[i + 1], s)
	return (2.0 * s3 - 3.0 * s2 + 1.0) * ps[i] + (s3 - 2.0 * s2 + s) * m0 \
		+ (3.0 * s2 - 2.0 * s3) * ps[i + 1] + (s3 - s2) * m1

## How far (0 to 1) the curve between snapshots i and i + 1 is flattened toward a straight line. The cubic runs
## through the two positions with the two velocities, so when the velocity changes between them (a dash that
## starts or ends inside the 0.1 s) it speeds up past both, up to a third over the dash's own speed for a few
## frames: a jump the owner's game never makes. Its tangents are moved toward the chord (a steady speed)
## in FLAT_STEPS until its fastest sampled speed is no more than the faster snapshot's or the pair's average.
## A pair whose velocities agree with its positions is left as it was. Worked out once per pair.
func _flatten(i: int) -> float:
	if ts[i] == flat_t:
		return flat_k
	var h := ts[i + 1] - ts[i]
	var d := ps[i + 1] - ps[i]
	var cap := maxf(maxf(vs[i].length(), vs[i + 1].length()), d.length() / h) * FLAT_TOL
	var k := 0.0
	while k < 1.0:
		var m0 := (vs[i] * h).lerp(d, k)
		var m1 := (vs[i + 1] * h).lerp(d, k)
		var top := 0.0
		for q in range(PEAK_SAMPLES + 1):
			var s := float(q) / PEAK_SAMPLES
			var s2 := s * s
			var dp := (6.0 * s2 - 6.0 * s) * -d + (3.0 * s2 - 4.0 * s + 1.0) * m0 + (3.0 * s2 - 2.0 * s) * m1
			top = maxf(top, dp.length() / h)
		if top <= cap:
			break
		k += 1.0 / FLAT_STEPS
	flat_t = ts[i]
	flat_k = minf(k, 1.0)
	return flat_k

## m/s along the move `d` between two snapshots that is still motion: SNAP_SPEED, or twice the faster speed
## the two report along it (a move that speeds up from rest or lands hard between them covers up to that).
## A teleport reports the speed it goes on with, not one along the jump, so it still snaps.
static func _reach(d: Vector3, v: Vector3, v0: Vector3) -> float:
	var along := d.normalized()
	return maxf(SNAP_SPEED, 2.0 * maxf(v.dot(along), v0.dot(along)))

func _clear() -> void:
	behind = Vector3.ZERO
	ts.clear()
	ps.clear()
	vs.clear()
