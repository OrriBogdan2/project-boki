class_name WardenKnockLean
extends RefCounted
## A knock tips a Hero's hips so the head goes with the blow and the feet trail (WardenClips, over the clips and the
## additive flinch): back from a hit on the front, forward from one behind, over to the side from a hit on the flank.
## There is no knock flag in the state, so a knock is read off it: a hit not long ago (hit_t) and a body moving
## faster than he runs, or in the air. It reads only what HunterAnim's state carries, so a remote copy leans the same.

const WINDOW := 0.6          # s after a hit that a body moving faster than he can run is a knock
const FAST := 1.4            # x run speed: faster than this on the ground (or any speed in the air) is a knock
const FULL_SPEED := 8.0      # m/s: the knock that leans him the whole LEAN
const LEAN := 0.5            # rad: how far the hips tip the body toward where the blow sends it
const RATE := 14.0           # 1/s: how fast the lean follows
const STILL := 0.25          # m/s: in the air, slower than this is no knock

var skel: Skeleton3D
var hips := -1
var run_speed := 4.6
var lean := Vector2.ZERO     # in his own frame (x right, y back), 0..1 of LEAN

func _init(sk: Skeleton3D, loco: Dictionary) -> void:
	skel = sk
	hips = WardenSkeleton.find(sk, "hips")
	run_speed = float(loco.get("run_speed", run_speed))

## The goal lean for this state: 0 unless knocked; `on` false (the procedural rig shows) eases it out.
func goal(s: Dictionary, on: bool) -> Vector2:
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var flat := Vector2(vel.x, vel.z)
	var fast := flat.length() > FAST * run_speed or (not bool(s.get("grounded", true)) and flat.length() > STILL)
	if not (on and fast and float(s.get("hit_t", 99.0)) < WINDOW and not bool(s.get("dead", false))):
		return Vector2.ZERO
	var face := float(s.get("face", 0.0))
	var right := flat.dot(Vector2(cos(face), -sin(face)))
	var back := flat.dot(Vector2(sin(face), cos(face)))
	return (Vector2(right, back) / FULL_SPEED).limit_length(1.0)

func step(s: Dictionary, on: bool, dt: float) -> void:
	lean = lean.lerp(goal(s, on), 1.0 - exp(-dt * RATE))
	if hips < 0 or lean.length() < 0.01:
		return
	var toward := Vector3(lean.x, 0.0, lean.y)
	var tip := Quaternion(Vector3.UP.cross(toward).normalized(), LEAN * toward.length())
	skel.set_bone_pose_rotation(hips, tip * skel.get_bone_pose_rotation(hips))
