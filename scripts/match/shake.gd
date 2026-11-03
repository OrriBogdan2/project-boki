class_name Shake
extends RefCounted
## The one door to camera shake. Your own abilities, dashes, landings and hits
## never shake your screen: they read through hit-stop, flashes, sparks, debris and sound. The only shake
## left is a big thing that happens TO you (a boss slam, a heavy ult landing on or near you): low and
## <= MAX_SECS long, scaled by the Settings "Screen shake" slider (0 = off).

const MAX_SECS := 0.15        # s: the longest any shake runs
const MAX_AMP := 0.25         # world units at full slider (the slider's default 30% scales it down)
const RADIUS := 14.0          # m: a big hit farther from you than this is not felt

## A big hit at `at`, caused by `cause` (null = the world: a boss, a mob, a lair). `power` is 0-1.
## Never shakes the camera of whoever caused it. Returns the strength applied (0 when none).
static func incoming_big(m: Node, at: Vector3, power: float, cause: Ent = null) -> float:
	if m == null or m.get("player") == null or m.get("cam") == null:
		return 0.0
	var p: Ent = m.player
	if cause != null and cause == p:
		return 0.0
	var fall := clampf(1.0 - p.flat_dist(at) / RADIUS, 0.0, 1.0)
	var amp := clampf(power, 0.0, 1.0) * fall * MAX_AMP * float(Settings.get_v("screen_shake"))
	if amp <= 0.001:
		return 0.0
	m.cam.rumble(amp, MAX_SECS)
	return amp
