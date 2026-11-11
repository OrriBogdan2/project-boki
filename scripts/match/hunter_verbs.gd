class_name HunterVerbs
extends RefCounted
## The garden verbs on the player's body: crouch-and-offer (feeding), a pat (petting), an underarm
## toss (a ball) and an arms-up cheer (races and drills). Procedural keys for HunterAnim's "act"
## slot: each is a function of t, the seconds since the move began. Hands are metres from the shoulder
## (left shoulder is -x, forward is -z). HomeVerbs times them; HunterAnim asks for legs, pitch, hands.

const ACTS := ["feed", "pat", "toss", "cheer"]
const LENGTH := {"feed": 1.6, "pat": 1.3, "toss": 0.8, "cheer": 1.5}      # s each move plays at home
const TOSS_RELEASE := 0.5            # s into the toss when the ball leaves the hand
const STAND := Vector4(0.12, -0.22, 0.12, -0.22)      # legs at rest
const HANG := Vector3(0.0, -0.42, -0.04)      # a relaxed free hand, from its shoulder

## Leg angles: Vector4(hip_l, knee_l, hip_r, knee_r).
static func legs(act: String, t: float) -> Vector4:
	match act:
		"feed":
			return STAND.lerp(Vector4(1.15, -1.7, 1.0, -1.6), smoothstep(0.0, 0.4, t))
		"pat":
			return STAND.lerp(Vector4(0.75, -1.1, 0.6, -1.0), smoothstep(0.0, 0.3, t))
		"toss":
			var d := smoothstep(0.0, 0.35, t) * (1.0 - 0.5 * smoothstep(TOSS_RELEASE, LENGTH["toss"], t))
			return STAND.lerp(Vector4(0.55, -0.6, -0.3, -0.35), d)
		"cheer":
			var hop := maxf(0.0, sin(t * 9.0))
			return Vector4(0.1 + hop * 0.3, -0.2 - hop * 0.5, 0.1 + hop * 0.3, -0.2 - hop * 0.5)
	return STAND

## How far forward the body leans (negative leans back).
static func pitch(act: String, t: float) -> float:
	match act:
		"feed": return 0.3 * smoothstep(0.0, 0.4, t)
		"pat": return 0.4 * smoothstep(0.0, 0.3, t)
		"toss": return -0.12 * smoothstep(0.0, 0.3, t) + 0.35 * smoothstep(0.3, TOSS_RELEASE, t)
		"cheer": return -0.14
	return 0.0

## Where the hands go: [left hand, right hand, how much the right hand lets go of the weapon].
static func hands(act: String, t: float, sh_l: Vector3, sh_r: Vector3) -> Array:
	match act:
		"feed":
			# both hands reach forward and low, palms up, and hold the snack out
			var d := smoothstep(0.1, 0.5, t)
			var out := Vector3(0.0, -0.32, -0.46) * d + HANG * (1.0 - d)
			return [sh_l + Vector3(0.1, 0.0, 0.0) + out, sh_r + Vector3(-0.1, 0.0, 0.0) + out, 1.0]
		"pat":
			# the right hand rests on the head and bobs; the left hangs
			var d := smoothstep(0.0, 0.3, t)
			var bob := sin(t * 11.0) * 0.06 * d
			var rest := Vector3(-0.1, -0.3 + bob, -0.4) * d + HANG * (1.0 - d)
			return [sh_l + HANG, sh_r + rest, 1.0]
		"toss":
			return _toss_hands(t, sh_l, sh_r)
		"cheer":
			var pump := sin(t * 9.0 + 1.0) * 0.07
			var up := smoothstep(0.0, 0.2, t)
			return [sh_l + Vector3(-0.3, 0.55 + pump, -0.05) * up + HANG * (1.0 - up),
				sh_r + Vector3(0.3, 0.55 - pump, -0.05) * up + HANG * (1.0 - up), 1.0]
	return [sh_l, sh_r, 0.0]

## Underarm: the right hand swings back and low, then forward and up through the release and
## settles; the left points the way for balance.
static func _toss_hands(t: float, sh_l: Vector3, sh_r: Vector3) -> Array:
	var back := Vector3(0.05, -0.38, 0.28)
	var thru := Vector3(-0.05, 0.0, -0.55)
	var end := TOSS_RELEASE + 0.1
	var p := back.lerp(thru, smoothstep(0.3, end, t))
	if t < 0.3:
		p = HANG.lerp(back, smoothstep(0.0, 0.3, t))
	elif t > end:
		p = thru.lerp(HANG, smoothstep(end, LENGTH["toss"], t))
	return [sh_l + Vector3(0.15, -0.1, -0.4) * smoothstep(0.0, 0.3, t), sh_r + p, 1.0]
