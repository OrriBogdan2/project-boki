class_name KinCurl
extends RefCounted
## A big Boki (a mount) curling up into a ball on your back (KinFollow.guard_tick: you glide or cross a gap it can't
## walk, or a traversal hop lands it on you) and back down to its flank. Kin.render draws the two ends; this eases
## between them over CURL_S, the same for every species: its root, facing, size and the ball's pitch, from wherever it
## was last drawn off you, carried along with you (its seat moves with you, so the hop never trails your glide).
## --boki-curl-check dumps it per frame.

const CURL_S := 0.6  # s: the hop onto your back and down (a ~3 m hop off a jump: under 0.15 m a frame)
const BALL_PITCH := 0.9  # rad: the curled ball's body pitch
const SEAT := Vector3(0, 0.55, 0.36)  # the ball's seat in your shown torso's space
const REACH := 4.0  # m: from farther off you it is put on (a stow, the drop), not hopped up
const GROUND_SCALE := 0.95  # its size on its feet (x its evo scale), as Kin.render draws it off you


## On your back: eases in from where it was last drawn off you.
static func back(k: Kin, body: Node3D, delta: float) -> void:
	if k.curl == 0.0 and k.curl_rel.length() > REACH:
		k.curl = 1.0
	k.curl = move_toward(k.curl, 1.0, delta / CURL_S)
	body.position.y = absf(sin(k.hop_ph * 0.5)) * 0.03
	body.rotation = Vector3.ZERO
	var from := k.owner_h.model.global_position + k.curl_rel
	_pose(k, body, from, Quaternion(Vector3.UP, k.face), GROUND_SCALE * float(k.model.get_meta("evo_scale", 1.0)))


## Off you, after Kin.render's ground pose: the hop down to its flank eases out; anything but sitting on or guarding
## beside you (a throw, a leap, wild) is never held back.
static func ground(k: Kin, body: Node3D, delta: float) -> void:
	var o := k.owner_h
	if o == null or o.model == null:
		return
	k.curl = move_toward(k.curl, 0.0, delta / CURL_S) if k.state == "shoulder" and k.carry_style() == "mount" else 0.0
	k.curl_rel = k.global_position - o.model.global_position
	if k.curl > 0.0:
		_pose(k, body, k.global_position, k.model.basis.get_rotation_quaternion(), k.model.scale.x)


static func _pose(k: Kin, body: Node3D, from: Vector3, face: Quaternion, size: float) -> void:
	var e := smoothstep(0.0, 1.0, k.curl)
	var seat := WardenGlb.shown_torso(k.owner_h.model) * SEAT
	var ball := lerpf(0.75, 0.42, k.settle) * minf(float(k.model.get_meta("evo_scale", 1.0)), 1.2)
	k.global_position = from.lerp(seat, e)
	k.model.basis = Basis(face.slerp(k.ride_basis().get_rotation_quaternion(), e))
	k.model.scale = Vector3.ONE * lerpf(size, ball, e)
	body.rotation = body.rotation.lerp(Vector3(BALL_PITCH, 0.0, 0.0), e)
