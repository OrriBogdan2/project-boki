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
const GUESS_M := 0.01       # m of run-on past the last snapshot that counts as a guess (a standing body never is)

var ts := PackedFloat64Array()
var ps := PackedVector3Array()
var vs := PackedVector3Array()
var off := 0.0
var late := JITTER_MIN      # s: the margin, the latest recent snapshot against the quickest
var jumped := false         # a teleport came in: the next follow snaps instead of sweeping
var drawn := -INF           # s: the owner time the last follow drew
var drawn_at := 0.0         # s: our match time then
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
	ts.append(t_owner)
	ps.append(p)
	vs.append(v)
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
	var n := ts.size()
	guessing = false
	if rt <= ts[0]:
		e.pos = ps[0]
		e.vel = vs[0]
	elif rt >= ts[n - 1]:
		var run_on := vs[n - 1] * minf(rt - ts[n - 1], RUN_ON)
		e.pos = ps[n - 1] + run_on
		e.vel = vs[n - 1]
		guessing = run_on.length_squared() > GUESS_M * GUESS_M
	else:
		var i := n - 2
		while ts[i] > rt: i -= 1
		var h := ts[i + 1] - ts[i]
		var s := (rt - ts[i]) / h
		var s2 := s * s
		var s3 := s2 * s
		e.pos = (2.0 * s3 - 3.0 * s2 + 1.0) * ps[i] + (s3 - 2.0 * s2 + s) * h * vs[i] \
			+ (3.0 * s2 - 2.0 * s3) * ps[i + 1] + (s3 - s2) * h * vs[i + 1]
		e.vel = vs[i].lerp(vs[i + 1], s)
	if jumped:
		e.prev = e.pos
		jumped = false

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
