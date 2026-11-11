class_name UtilityPose
extends RefCounted
## The body beat of a belt item (content/utility: "move"). Five shared moves, every item maps to one:
##   throw   the free hand cocks back by the ear and flings out ahead (smoke, flare, flask, charges)
##   place   down on a knee, the hand setting the item on the ground (pad, fan, kits, lamp)
##   read    the hand brings the item up in front of the face (cell, keys, scroll, lantern)
##   raise   the hand lifts the item high overhead (banner, whistle, ember)
##   drink   the flask to the mouth (tonic, draughts); HunterAnim's "drink" state
## A move lasts the item's cast time: a channelled item (drink, repair) runs its "channel" time, every
## other item names "cast" in its data. The effect itself never waits for the beat. Upper body only:
## a place kneels only while standing; on the move the legs keep running.
## Hunter.beat_id/beat_t carry an instant item's beat; fill() turns whichever is running into the
## state HunterAnim poses from ("drink" 0..1, or "util" 0..1 with "util_move").

const MOVES := ["throw", "place", "read", "raise", "drink"]
const STILL := 0.5      # m/s of ground speed under which a place kneels

static func move_of(id: String) -> String:
	return String(UtilityBelt.def(id).get("move", ""))

## Seconds the item's move lasts (and the channel runs, for the tonic and the armor kit).
static func cast_time(id: String) -> float:
	if UtilityUse.use_of(id) in ["drink", "repair"]:
		return UtilityUse.channel(id, "time")
	return float(UtilityBelt.def(id).get("cast", 0.0))

## Starts an instant item's beat (the channelled ones run from their own timers).
static func start(h: Hunter, id: String) -> void:
	h.beat_id = id
	h.beat_t = cast_time(id)

## Fills the animation state for whatever item the hunter is using right now.
static func fill(h: Hunter, s: Dictionary) -> void:
	var id := h.beat_id
	var left := h.beat_t
	if h.drink_t > 0.0:
		id = h.drink_id
		left = h.drink_t
	elif h.kit_t > 0.0:
		id = "armor_kit"
		left = h.kit_t
	s["drink"] = -1.0
	s["util"] = -1.0
	if left <= 0.0:
		return
	var p := clampf(1.0 - left / maxf(0.05, cast_time(id)), 0.0, 1.0)
	var mv := move_of(id)
	if mv == "drink":
		s["drink"] = p
		return
	s["util"] = p
	s["util_move"] = mv
	if mv == "place" and Vector2(h.vel.x, h.vel.z).length() < STILL:
		s["crouch"] = maxf(float(s.get("crouch", 0.0)), weight(mv, p))

## How much of the pose is on at progress p (0..1): in, hold, out.
static func weight(move: String, p: float) -> float:
	match move:
		"throw": return smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.65, 1.0, p))
		"place": return smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.75, 1.0, p))
		"read": return smoothstep(0.0, 0.25, p) * (1.0 - smoothstep(0.8, 1.0, p))
		"raise": return smoothstep(0.0, 0.35, p) * (1.0 - smoothstep(0.75, 1.0, p))
	return 0.0

## Where the left hand goes, from its shoulder.
static func hand(move: String, p: float) -> Vector3:
	match move:
		"throw":
			return Vector3(-0.08, 0.28, 0.16).lerp(Vector3(0.1, 0.08, -0.5), smoothstep(0.3, 0.5, p))
		"place":
			return Vector3(0.06, -0.44 - 0.06 * sin(smoothstep(0.4, 0.7, p) * PI), -0.3)
		"read":
			return Vector3(0.1, 0.1 + 0.03 * sin(smoothstep(0.45, 0.65, p) * PI), -0.3)
		"raise":
			return Vector3(0.04, 0.42 + 0.04 * sin(smoothstep(0.4, 0.7, p) * PI), -0.14)
	return Vector3.ZERO

## The head's pitch (positive looks down): at the ground for the place, at the item for the read,
## up at it for the raise.
static func head(move: String, p: float) -> float:
	match move:
		"place": return 0.25 * weight(move, p)
		"read": return 0.3 * weight(move, p)
		"raise": return -0.3 * weight(move, p)
	return 0.0
