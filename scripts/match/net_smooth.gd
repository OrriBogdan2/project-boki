class_name NetSmooth
extends RefCounted
## A remote Hunter's snapshot buffer. The body is drawn DELAY behind its owner's clock, on a smooth
## curve between the two snapshots around that moment (cubic Hermite through their positions and
## velocities), so late, jittered or lost snapshots don't make it stutter or overshoot. A move between
## two snapshots faster than SNAP_SPEED (a teleport, a displace's blink) is drawn as one jump.
## Times are the owner's match time from the "st" header; `off` is our match time minus theirs plus the
## line's delay, taken from the quickest recent arrival.

const DELAY := 0.15         # s drawn behind the quickest arrival: one 0.1 s snapshot gap plus 40 ms of jitter
const RUN_ON := 0.25        # s at most the body runs on along its last velocity when snapshots stop
const SNAP_SPEED := 40.0    # m/s between two snapshots: anything faster is a teleport
const RESYNC := 0.5         # s an arrival is off the usual: a clock was reset, start over
const OFF_EASE := 0.05      # share of a slower-than-usual arrival the clock gap takes on per snapshot
const KEEP := 6             # snapshots kept (0.6 s at 10 a second)

var ts := PackedFloat64Array()
var ps := PackedVector3Array()
var vs := PackedVector3Array()
var off := 0.0
var jumped := false         # a teleport came in: the next follow snaps instead of sweeping

func push(t_owner: float, now: float, p: Vector3, v: Vector3) -> void:
	var gap := now - t_owner
	var n := ts.size()
	if n > 0 and absf(gap - off) > RESYNC:
		_clear()
		n = 0
	if n > 0 and t_owner <= ts[n - 1]:
		return
	if n == 0 or gap < off:
		off = gap
	else:
		off += (gap - off) * OFF_EASE
	if n > 0 and p.distance_to(ps[n - 1]) > SNAP_SPEED * (t_owner - ts[n - 1]):
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
	var rt := now - off - DELAY
	var n := ts.size()
	if rt <= ts[0]:
		e.pos = ps[0]
		e.vel = vs[0]
	elif rt >= ts[n - 1]:
		e.pos = ps[n - 1] + vs[n - 1] * minf(rt - ts[n - 1], RUN_ON)
		e.vel = vs[n - 1]
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

func _clear() -> void:
	ts.clear()
	ps.clear()
	vs.clear()
