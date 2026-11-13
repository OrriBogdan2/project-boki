class_name HunterRod
extends RefCounted
## The Empty's fishing rod (Glint Fishing, scripts/home/glint_fishing.gd): five poses on HunterAnim's "act"
## slot and the rod itself, drawn on the torso and held in both hands. The feet are not posed here: the
## legs stay on EmptyGait's planted feet, the body only leans.
##   wait   the rod held out over the water, a tiny sway (a loop)
##   cast   wind back over the shoulder, flick out, settle (once, LENGTH)
##   bite   the rod tip jerks and rings down (once)
##   reel   the rear hand cranks, the rod bobs with the pull (a loop)
##   land   the rod lifts the catch high and comes back to the wait (once)
## Every pose is a function of t, the seconds since it began, and they start and end on the same grip so
## a change of pose never pops. Hands are metres from the middle of the shoulders (forward is -z).

const ACTS := ["wait", "cast", "bite", "reel", "land"]
const LENGTH := {"cast": 0.6, "bite": 0.4, "land": 0.9}      # s each one-shot plays
const GRIP_GAP := 0.2         # m between the hands on the rod
const BUTT := 0.25            # m of rod behind the rear hand
const REEL_S := 0.5           # s per turn of the crank
const CRANK_R := 0.035        # m, the crank hand's circle
const ROD_LEN := 1.3          # m, butt to tip
# a pose is [rear hand from the shoulders' middle, rod direction (butt to tip), lean forward in rad]
const WAIT := [Vector3(0.08, -0.22, -0.26), Vector3(0.0, 0.45, -0.89), 0.1]
const BACK := [Vector3(0.12, 0.08, -0.02), Vector3(0.05, 0.95, 0.3), -0.22]
const THRU := [Vector3(0.06, -0.04, -0.34), Vector3(0.0, 0.2, -0.98), 0.28]
const REEL := [Vector3(0.08, -0.21, -0.26), Vector3(0.0, 0.62, -0.78), 0.18]
const UP := [Vector3(0.1, 0.0, -0.16), Vector3(0.0, 0.92, -0.38), -0.2]
const CAST_BACK := 0.3        # s: the wind-back ends and the flick starts
const CAST_THRU := 0.4        # s: the flick lands
const BITE_KICK := [Vector3(0.0, 0.09, 0.02), Vector3(0.0, 0.5, 0.0), 0.1]      # at the top of the jerk
const BITE_HZ := 30.0         # rad/s of the jerk
const BITE_DAMP := 7.0        # 1/s it rings down at
const LAND_UP := 0.4          # s: the rod is up
const LAND_DOWN := 0.65       # s: it starts to come back

static func _mix(a: Array, b: Array, u: float) -> Array:
	return [(a[0] as Vector3).lerp(b[0], u), (a[1] as Vector3).lerp(b[1], u), lerpf(a[2], b[2], u)]

## The pose at t: [rear hand, rod direction, lean].
static func pose(act: String, t: float) -> Array:
	match act:
		"cast":
			if t < CAST_BACK:
				return _mix(WAIT, BACK, smoothstep(0.0, CAST_BACK, t))
			if t < CAST_THRU:
				return _mix(BACK, THRU, smoothstep(CAST_BACK, CAST_THRU, t))
			return _mix(THRU, WAIT, smoothstep(CAST_THRU, LENGTH["cast"], t))
		"bite":
			var kick := sin(t * BITE_HZ) * exp(-t * BITE_DAMP)
			return [WAIT[0] + BITE_KICK[0] * kick, WAIT[1] + BITE_KICK[1] * kick, WAIT[2] + BITE_KICK[2] * kick]
		"reel":
			var a := t * TAU / REEL_S
			var turn := Vector3(0.0, cos(a), sin(a)) * CRANK_R
			return [REEL[0] + turn, REEL[1] + Vector3(0.0, sin(a) * 0.04, 0.0), REEL[2] + sin(a) * 0.03]
		"land":
			if t < LAND_DOWN:
				return _mix(REEL, UP, smoothstep(0.0, LAND_UP, t))
			return _mix(UP, WAIT, smoothstep(LAND_DOWN, LENGTH["land"], t))
	return [WAIT[0], (WAIT[1] as Vector3) + Vector3(0.0, sin(t * 1.7) * 0.03, 0.0), WAIT[2]]

## HunterAnim._act_pitch.
static func pitch(act: String, t: float) -> float:
	return pose(act, t)[2]

## HunterAnim._act_hands: [left hand, right hand, how much the right hand lets go of the weapon].
static func hands(act: String, t: float, sh_l: Vector3, sh_r: Vector3) -> Array:
	var p := pose(act, t)
	var rear := (sh_l + sh_r) * 0.5 + (p[0] as Vector3)
	return [rear + (p[1] as Vector3).normalized() * GRIP_GAP, rear, 1.0]

# ------------------------------------------------------------------ the rod in the rig
## After the arms are posed: the rod in the hands, shown only while a fishing pose is up.
static func place(a: HunterAnim) -> void:
	var rod := a.torso.get_node_or_null("Rod") as Node3D
	var on := ACTS.has(a.act_kind) and a.act_k > 0.05
	if rod == null and on:
		rod = _build(a.torso)
	if rod == null:
		return
	rod.visible = on and a.arm_l != null and a.arm_r != null
	if not rod.visible:
		return
	var front := a.arm_l.transform * (a.el_l.transform * a.hand_l.position)
	var rear := a.arm_r.transform * (a.el_r.transform * a.hand_r.position)
	var dir := (front - rear).normalized() if front.distance_to(rear) > 0.02 else Vector3.UP
	rod.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), rear - dir * BUTT)

## Where the line leaves the rod, in world space (null when the rod is away).
static func tip(a: HunterAnim) -> Node3D:
	var rod := a.torso.get_node_or_null("Rod") as Node3D
	return rod.get_node("Tip") if rod != null and rod.visible else null

static func _build(torso: Node3D) -> Node3D:
	var rod := Node3D.new()
	rod.name = "Rod"
	var cork := Models.toon(Color("c9a46b"))
	var blank := Models.toon(Color("5b6f7a"))
	var reel := Models.toon(Color("d9d2c3"))
	Models.part(rod, Models.cyl(0.024, 0.024, BUTT + 0.2, 8), cork, Vector3(0, (BUTT + 0.2) * 0.5, 0))
	var long := ROD_LEN - BUTT - 0.2
	Models.part(rod, Models.cyl(0.006, 0.016, long, 8), blank, Vector3(0, ROD_LEN - long * 0.5, 0))
	var spool := Vector3(0.04, BUTT, 0.0)
	Models.part(rod, Models.cyl(0.05, 0.05, 0.03, 12), reel, spool, Vector3.ONE, Vector3(0, 0, PI * 0.5))
	var end := Node3D.new()
	end.name = "Tip"
	end.position = Vector3(0, ROD_LEN, 0)
	rod.add_child(end)
	rod.visible = false
	torso.add_child(rod)
	return rod
