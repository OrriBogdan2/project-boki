class_name WardenCc
extends RefCounted
## What a stun, a root or Grounded looks like on a Hero's clips (data "cc"), so the effect reads from the body: the
## stun sways in a loop over the stun clip, a root strains the torso and arms against legs that stay planted, Grounded
## drops into the Hero's own crouch (WardenClips eases its crouch layer on) and hunches over it. Each state is a pose
## laid over whatever the clips play: {"hz": loop rate, "pose": {bone: [pitch, yaw, roll]}, "sway": {bone: [...]}}
## in degrees in his own frame (pitch: the bone's top tips toward his front; yaw: it turns to his left; roll: its top
## tips to his right). The sway rides on the pose, pitch and yaw on a sine, roll on its cosine (a circle); every bone
## but the hips follows a beat late. A state eases in and out in WardenClips.FADE (0.1 s).

const STATES := ["stun", "root", "gnd"]   # the anim state's keys, true while the effect runs
const LAG := 0.7             # rad: how far the head and arms trail the hips' sway (follow-through)

var skel: Skeleton3D
var to_skel: Quaternion      # the model's frame into the skeleton's
var bones := {}              # state -> [[bone index, parent index, pose (rad), sway (rad), lag (rad)]]
var hz := {}                 # state -> its loop rate (1/s)
var w := {}                  # state -> how much it shows (0..1)
var t := 0.0                 # s the loop has run

func _init(root: Node3D, sk: Skeleton3D, cc: Dictionary) -> void:
	skel = sk
	var xf := Transform3D()
	var n: Node = sk
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	to_skel = xf.basis.orthonormalized().get_rotation_quaternion()
	for st in STATES:
		if not cc.has(st):
			continue
		var d: Dictionary = cc[st]
		var pose: Dictionary = d.get("pose", {})
		var sway: Dictionary = d.get("sway", {})
		var list: Array = []
		for b in WardenGlb.BONES:
			var bi := WardenSkeleton.find(sk, String(b))
			if bi < 0 or not (pose.has(b) or sway.has(b)):
				continue
			list.append([bi, sk.get_bone_parent(bi), _deg(pose.get(b, [0, 0, 0])), _deg(sway.get(b, [0, 0, 0])),
					0.0 if b == "hips" else LAG])
		bones[st] = list
		hz[st] = float(d.get("hz", 1.0))
		w[st] = 0.0

static func _deg(v: Array) -> Vector3:
	return Vector3(deg_to_rad(float(v[0])), deg_to_rad(float(v[1])), deg_to_rad(float(v[2])))

## How much `st` shows (0..1).
func weight(st: String) -> float:
	return float(w.get(st, 0.0))

## After tree.advance: `s` the anim state, `k` how much of the clips shows (the procedural rig takes the rest).
func apply(dt: float, s: Dictionary, k: float) -> void:
	var any := false
	for st in w:
		w[st] = move_toward(float(w[st]), 1.0 if bool(s.get(st, false)) else 0.0, dt / WardenClips.FADE)
		any = any or float(w[st]) > 0.0
	if not any:
		t = 0.0
		return
	t += dt
	var turns := {}              # bone index -> [parent index, rotation in his frame]
	for st in w:
		var sw := float(w[st]) * k
		if sw <= 0.0:
			continue
		var ph := TAU * float(hz[st]) * t
		for b in bones[st]:
			var lag := float(b[4])
			var sway: Vector3 = b[3]
			var e: Vector3 = b[2] + Vector3(sway.x * sin(ph - lag), sway.y * sin(ph - lag), sway.z * cos(ph - lag))
			# (his frame faces -Z: pitch toward his front turns about -X, a roll to his right about -Z)
			var q := Quaternion.from_euler(Vector3(-e.x, e.y, -e.z) * sw)
			var was: Array = turns.get(int(b[0]), [int(b[1]), Quaternion.IDENTITY])
			turns[int(b[0])] = [was[0], q * (was[1] as Quaternion)]
	var parents := {}            # (read before any bone turns: each turn is on its parent's pose from the clips)
	for bi in turns:
		var p := int(turns[bi][0])
		parents[bi] = skel.get_bone_global_pose(p).basis.get_rotation_quaternion() if p >= 0 else Quaternion.IDENTITY
	for bi in turns:
		var pg: Quaternion = parents[bi]
		var q: Quaternion = to_skel * (turns[bi][1] as Quaternion) * to_skel.inverse()
		skel.set_bone_pose_rotation(bi, pg.inverse() * q * pg * skel.get_bone_pose_rotation(bi))
