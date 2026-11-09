class_name NetInterp
extends RefCounted
## Another player's Hunter, drawn a little in the past so it glides (snapshot interpolation). Its "st"
## snapshots (Net.tick, 10 a second, stamped with the sender's match clock) queue here; each frame the
## body is placed DELAY behind the newest, between the two snapshots around that moment. When the next
## one is late or lost it carries on along the last velocity for at most EXTRAP_MAX, and the error that
## leaves when the snapshot does come fades out (SETTLE, SETTLE_SPD) instead of jumping. A move between two
## snapshots faster than anything can travel (a teleport, Displace's "tp", a respawn) is a hard reset:
## the body is placed there at once. Every remote Hunter (players and the host's bots) uses it; monsters and
## Boki keep Ent.net_follow's chase.

const DELAY := 0.1           # s behind the newest snapshot (one send interval: there is nearly always a next one);
                             # a slower sender (the host's bots, 0.15 s) is drawn one of its own intervals behind
const EXTRAP_MAX := 0.15     # s past the newest snapshot it carries on along that snapshot's velocity
const TP_SPEED := 45.0       # m/s between two snapshots: faster is a teleport (Displace.MAX_SPD is 40)
const TP_SLACK := 1.0        # m added to that, so a short hop between close snapshots never reads as one
const SETTLE := 8.0          # 1/s: how fast a correction left by a late snapshot fades
const SETTLE_SPD := 4.0      # m/s: and at most this fast, so a fade never visibly adds to the body's own speed
const KEEP := 8              # snapshots kept (0.8 s at the send rate)
const CLOCK_PULL := 2.0      # 1/s: how fast the draw clock eases onto DELAY behind the sender
const CLOCK_RATE := 0.05     # share it may run fast or slow while it eases (so motion never visibly speeds up)
const CLOCK_JUMP := 0.25     # s: a draw clock this far off is set at once (the first frames, a stall)
const RESYNC := 0.5          # s: a stamp this far past the last one is the sender's clock being reset
                             # (Match._net_state resyncs a guest's clock to the host's past 0.5 s), not time

var ts := PackedFloat64Array()     # the sender's clock at each snapshot
var ps := PackedVector3Array()
var vs := PackedVector3Array()
var ar := PackedFloat64Array()     # our clock when each arrived
var lag := 0.0               # s: arrival here minus the sender's stamp, the quickest of the queued trips
var every := DELAY           # s: the sender's usual interval between snapshots
var clock := 0.0             # the sender's time being drawn
var off := Vector3.ZERO      # m: a correction still fading
var vel := Vector3.ZERO      # m/s at the drawn moment

## Queues the snapshot just applied to `e` (its net_pos and net_vel). `t_sent` is the sender's stamp
## (below 0: none came with it, so the arrival time stands in).
static func feed(e: Ent, now: float, t_sent: float) -> void:
	if e.interp == null:
		e.interp = NetInterp.new()
	e.interp.push(now, t_sent if t_sent >= 0.0 else now, e.net_pos, e.net_vel)

func push(now: float, t: float, p: Vector3, v: Vector3) -> void:
	var n := ts.size()
	if n == 0:
		_restart(now, t, p, v)
		return
	var gap := t - ts[n - 1]
	if gap <= 0.0 and gap > -CLOCK_JUMP:
		return       # a repeat, or an older snapshot overtaken by a newer one
	if gap <= 0.0 or gap > RESYNC:
		# the sender's clock was reset (to the host's): shift the queue onto its new clock, seamlessly
		var shift := gap - every
		for i in n:
			ts[i] += shift
		clock += shift
		gap = every
	if p.distance_to(ps[n - 1]) > TP_SPEED * gap + TP_SLACK:
		_restart(now, t, p, v)
		return
	var before := _raw()
	if n == KEEP:
		ts.remove_at(0)
		ps.remove_at(0)
		vs.remove_at(0)
		ar.remove_at(0)
	ts.append(t)
	ps.append(p)
	vs.append(v)
	ar.append(now)
	off += before - _raw()
	every += (gap - every) * 0.1
	lag = INF
	for i in ts.size():
		lag = minf(lag, ar[i] - ts[i])

## Where the body is drawn this frame.
func sample(dt: float, now: float) -> Vector3:
	var want := now - lag - maxf(DELAY, every)
	clock += dt
	var err := want - clock
	if absf(err) > CLOCK_JUMP:
		var before := _raw()
		clock = want
		off += before - _raw()
	else:
		clock += clampf(err * CLOCK_PULL * dt, -CLOCK_RATE * dt, CLOCK_RATE * dt)
	off = off.move_toward(Vector3.ZERO, minf(off.length() * (1.0 - exp(-SETTLE * dt)), SETTLE_SPD * dt))
	return _raw() + off

## Starts over from one snapshot, drawn there at once.
func _restart(now: float, t: float, p: Vector3, v: Vector3) -> void:
	ts = PackedFloat64Array([t])
	ps = PackedVector3Array([p])
	vs = PackedVector3Array([v])
	ar = PackedFloat64Array([now])
	lag = now - t
	clock = t - DELAY
	off = Vector3.ZERO

## The snapshots' own position at `clock`: between the two around it, held at the oldest before them,
## carried along the newest's velocity (at most EXTRAP_MAX) after them.
func _raw() -> Vector3:
	var n := ts.size()
	if clock >= ts[n - 1]:
		vel = vs[n - 1]
		return ps[n - 1] + vs[n - 1] * minf(clock - ts[n - 1], EXTRAP_MAX)
	if clock <= ts[0]:
		vel = Vector3.ZERO
		return ps[0]
	var i := n - 2
	while ts[i] > clock:
		i -= 1
	var k := (clock - ts[i]) / (ts[i + 1] - ts[i])
	vel = vs[i].lerp(vs[i + 1], k)
	return ps[i].lerp(ps[i + 1], k)
