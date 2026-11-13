class_name WardenCc
extends RefCounted
## Crowd control a Hero's body shows over its clips (docs/art/wardens/CLIPS.md). Rooted: the legs stay planted on the
## idle and the torso pulls against the hold in tugs, twisting to work loose. Grounded: the crouch layer drops him low
## (WardenClips._crouch) and the head bows at the cords round his legs. Stun is the "stun" state's own sway clip.
## Laid over the clips after tree.advance, in and out in WardenClips.FADE. Data "cc", the Hero's own way of pulling:
## {"pull": rad the torso leans in, "tug_hz": tugs a second, "twist": rad it wrings side to side, "bow": rad the head
## drops under Grounded}.

const PULL := 0.22        # rad: the torso's lean into a pull, when the data has none
const TUG_HZ := 1.4       # tugs a second
const TWIST := 0.12       # rad: the wring side to side, at half the tug rate
const BOW := 0.3          # rad: the head bowed at the cords
const TUG_REST := 0.6     # of the pull held between tugs: the lean never lets go while the root holds

var skel: Skeleton3D
var hips := -1
var head := -1
var pull := PULL
var tug_hz := TUG_HZ
var twist := TWIST
var bow := BOW
var root_w := 0.0         # how much of the strain shows
var gnd_w := 0.0          # how much of the bow shows
var tug_t := 0.0          # s into this root: each one starts on a fresh pull

func _init(sk: Skeleton3D, cc: Dictionary) -> void:
	skel = sk
	hips = WardenSkeleton.find(sk, "hips")
	head = WardenSkeleton.find(sk, "head")
	pull = float(cc.get("pull", PULL))
	tug_hz = float(cc.get("tug_hz", TUG_HZ))
	twist = float(cc.get("twist", TWIST))
	bow = float(cc.get("bow", BOW))

## After tree.advance. `rooted`: the strain owns the torso (only over the legs' own clips); `gnd`: Grounded.
func apply(dt: float, rooted: bool, gnd: bool) -> void:
	root_w = move_toward(root_w, 1.0 if rooted else 0.0, dt / WardenClips.FADE)
	gnd_w = move_toward(gnd_w, 1.0 if gnd else 0.0, dt / WardenClips.FADE)
	tug_t = tug_t + dt if root_w > 0.0 else 0.0
	if root_w > 0.0 and hips >= 0:
		var tug := 0.5 - 0.5 * cos(TAU * tug_hz * tug_t)
		var lean := -pull * lerpf(TUG_REST, 1.0, tug) * root_w     # (about +X a negative turn tips the torso forward)
		var wring := sin(PI * tug_hz * tug_t) * twist * root_w
		_turn(hips, Quaternion(Vector3.UP, wring) * Quaternion(Vector3.RIGHT, lean))
	if gnd_w > 0.0 and head >= 0:
		_turn(head, Quaternion(Vector3.RIGHT, -bow * gnd_w))

## Turns bone `bi` by `q`, given in the skeleton's own frame, on top of its pose.
func _turn(bi: int, q: Quaternion) -> void:
	var p := skel.get_bone_parent(bi)
	var pq := skel.get_bone_global_pose(p).basis.get_rotation_quaternion() if p >= 0 else Quaternion.IDENTITY
	skel.set_bone_pose_rotation(bi, (pq.inverse() * q * pq * skel.get_bone_pose_rotation(bi)).normalized())
