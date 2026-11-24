class_name Shake
extends RefCounted
## The one door to camera shake. Your own abilities, dashes, landings and hits
## never shake your screen: they read through hit-stop, flashes, sparks, debris and sound. The only shake
## left is a big thing that happens TO you (a boss slam, a heavy ult landing on or near you): low and
## max_secs long, scaled by the Settings "Screen shake" slider (0 = off), and at most one started per
## shake_gap_s however many big hits stack. Every number is a hit class in content/rules/shake.json
## (docs/MOVEMENT_FEEL.d/1123-shake-table.md); a caller names its class, never a number.

const RULES_PATH := "res://content/rules/shake.json"
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
static var _started := -9.0  # match time the last shake started (the team-fight cap)


## What every shake shares: max_secs (s), max_amp (world units at power 1), radius_m (m).
static func door(key: String) -> float:
	return float(rules["door"][key])


## A class's power (0-1), plus its step per `stage` (a lair seal's crack).
static func power(cls: String, stage := 0) -> float:
	var row: Dictionary = rules["classes"][cls]
	return float(row["power"]) + float(row.get("step", 0.0)) * stage


## A big thing of class `cls` at `at`, caused by `cause` (null = the world: a boss, a mob, a lair).
static func big(m: Node, at: Vector3, cls: String, cause: Ent = null, stage := 0) -> float:
	return incoming_big(m, at, power(cls, stage), cause)


## A big hit at `at` of `pwr` (0-1, from a class: `big`, or a hit tier: Feel). Never shakes the camera of
## whoever caused it (or of the owner of the Boki that did). Returns the strength applied (0 when none).
static func incoming_big(m: Node, at: Vector3, pwr: float, cause: Ent = null) -> float:
	if m == null or m.get("player") == null or m.get("cam") == null:
		return 0.0
	var p: Ent = m.player
	if cause != null and (cause == p or (cause is Kin and (cause as Kin).owner_h == p)):
		return 0.0  # (your own Boki's moves are yours too)
	var fall := clampf(1.0 - p.flat_dist(at) / door("radius_m"), 0.0, 1.0)
	var amp := clampf(pwr, 0.0, 1.0) * fall * door("max_amp") * float(Settings.get_v("screen_shake"))
	if amp <= 0.001:
		return 0.0
	# stacked big hits (a team fight) start one shake per shake_gap_s: inside it they only raise its strength
	var now := float(m.get("time"))
	var fresh := now - _started >= ImpactWeight.cap("shake_gap_s") or now < _started
	if fresh:
		_started = now
	m.cam.rumble(amp, door("max_secs") if fresh else 0.0)
	return amp
