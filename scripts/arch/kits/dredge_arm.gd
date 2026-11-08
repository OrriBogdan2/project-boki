class_name DredgeArm
extends RefCounted
## Grimble's Abyssal Hand, drawn: the stretched arm from his wrist socket (DredgeKit._hand, so any model with the
## anchor works) to the bone hook. Its middle rides a spring, so the flesh trails the hook as it whips out, bows
## and settles after a catch, and swells on the yank; the arm snaps back after a miss or the reel, dripping sludge.
## The hook's gameplay (the shot, the grab, the reel) stays in DredgeKit.

const ARM_THICK := 0.82                # m, the stretched arm's girth at the shoulder end
const SNAP_T := 0.14                   # s the stretched arm takes to snap back to his shoulder after a miss or the reel
const DRIP_T := 0.07                   # s between sludge drips off the stretched arm
const SAG_HZ := 4.5                    # Hz: the arm's middle wobbles at this rate before it settles
const SAG_DAMP := 0.28                 # damping ratio of that wobble (low: it swings past once or twice, then settles)
const BEND_MAX := 0.22                 # the bow's furthest reach, as a share of the arm's length
const WHIP_KICK := 7.0                 # m/s: the arm's middle is flung up this fast as the hook leaves (it uncoils)
const CATCH_KICK := 11.0               # m/s: the jolt sideways and up through the arm when the hook bites
const YANK_T := 0.22                   # s the arm stays swollen after a catch (the heavy first haul)
const YANK_SWELL := 0.45               # share of girth added at the start of that yank
const GAP_T := 0.2                     # s unseen after which the spring starts afresh

var k: DredgeKit
var mid := Vector3.ZERO                # the arm's middle as drawn: it chases the straight line between the ends
var mid_v := Vector3.ZERO
var drawn_at := -9.0                   # when the arm was last drawn
var snap_t := 0.0                      # the arm snapping back: time left
var snap_tip := Vector3.ZERO           # ... and where the hook was when it began
var yank_at := -9.0                    # the last catch
var drip_at := 0.0                     # the next sludge drip

func _init(kit: DredgeKit) -> void:
	k = kit

## The wind-back before the throw: the model's own throw coils the arm; a violet glow gathers in his fist.
func wind(frac: float) -> void:
	if k.tells_visible():
		k.fx.orb(k._hand(), DredgeKit.ARM_COL, DredgeKit.BONE, 0.35 + 0.5 * frac, 0.05)

## The hook leaves his hand: the spring starts at the wrist and the middle is flung up, so the arm uncoils.
func whip() -> void:
	mid = k._hand()
	mid_v = Vector3.UP * WHIP_KICK
	drawn_at = k.m.time

## The hook bites at `at`: the jolt runs through the arm (a sideways-and-up kick on its middle), the arm swells,
## and a ring, sludge and a short shake sell the weight.
func catch_at(at: Vector3) -> void:
	var out := at - k._hand()
	var side := out.cross(Vector3.UP).normalized() if out.length() > 0.1 else Vector3.RIGHT
	mid_v += (side * 0.6 + Vector3.UP * 0.8) * CATCH_KICK
	yank_at = k.m.time
	if not k.tells_visible():
		return
	k.fx.wave(at, 1.7, DredgeKit.BONE, 0.3, DredgeKit.ARM_COL)
	k.fx.orb(at, DredgeKit.ARM_COL, DredgeKit.BRASS_HOT, 1.3, 0.12)
	k.m.fx.burst(at, DredgeKit.SLUDGE, 10, 4.0, 0.5, 10.0)
	k.m.shake(0.35, at)

## The arm this step, from his forearm to the hook at `tip`, `thick` at the shoulder.
func draw(tip: Vector3, thick: float) -> void:
	var from := k._hand()
	var want := from.lerp(tip, 0.5)
	var dt := clampf(k.m.time - drawn_at, 0.0, 1.0 / 30.0)
	if k.m.time - drawn_at > GAP_T:
		mid = want
		mid_v = Vector3.ZERO
	drawn_at = k.m.time
	var w := TAU * SAG_HZ
	mid_v += (w * w * (want - mid) - 2.0 * SAG_DAMP * w * mid_v) * dt
	mid += mid_v * dt
	var out := tip - from
	var axis := out.normalized() if out.length() > 0.01 else Vector3.FORWARD
	var bend := mid - want
	bend -= axis * bend.dot(axis)                  # only the bow across the arm; along it the flesh just stretches
	bend = bend.limit_length(out.length() * BEND_MAX)
	var swell := 1.0 + YANK_SWELL * (1.0 - smoothstep(0.0, YANK_T, k.m.time - yank_at))
	var id := k.h.get_instance_id()
	k.fx.arm("arm%d" % id, from, tip, DredgeKit.ARM_COL, thick * swell, bend)
	k.fx.place("hook%d" % id, "hook", tip, DredgeKit.ARM_COL, DredgeKit.BONE, 1.0, atan2(-out.x, -out.z))
	if k.m.time >= drip_at:
		drip_at = k.m.time + DRIP_T
		k.m.fx.burst(from.lerp(tip, randf()) + bend, DredgeKit.SLUDGE, 2, 0.4, 0.7, 10.0, 0.9, Vector3.DOWN, 40.0)

## The arm snaps back to his shoulder after a miss or the end of the reel, with a splash of sludge at the hook.
func snap(tip: Vector3) -> void:
	snap_t = SNAP_T
	snap_tip = tip
	k.m.fx.burst(tip, DredgeKit.SLUDGE, 8, 3.0, 0.5, 10.0)

func tick_snap(dt: float) -> void:
	snap_t = maxf(0.0, snap_t - dt)
	if not k.tells_visible():
		return
	var f := 1.0 - snap_t / SNAP_T
	draw(snap_tip.lerp(k._hook_rest(), f * f), ARM_THICK * (1.0 - 0.4 * f))
