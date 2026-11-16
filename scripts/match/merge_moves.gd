class_name MergeMoves
extends RefCounted
## Keyed full-body poses of the merged forms and of the rescue (HunterAnim.km_sample reads MOVES after its own KMOVES).
## Same channels as HunterAnim.KMOVES (p y r lift fx fz fy sq lw hw rw legs fl fr): "mf_*" are the forms' moves
## (transformation, ultimate), "rs_*" the rescue (carry, stand up).
## A move with "hold": true stays on its last key until another replaces it. Forward is -z in the hand keys.

const UP_L := Vector3(-0.12, 0.6, -0.1)
const UP_R := Vector3(0.12, 0.6, -0.1)
const FWD_L := Vector3(-0.12, 0.15, -0.55)
const FWD_R := Vector3(0.12, 0.15, -0.55)

const MOVES := {
	# the transformation: crouch as the Boki leaps up, spring open as it lands (0.45s), settle by 0.7
	"mf_xform": {"keys": [
		[0.0, {}],
		[0.18, {"p": 0.35, "lift": -0.12, "sq": 0.3, "lw": 1.0, "legs": [0.7, -1.2, 0.5, -1.0], "fl": UP_L, "fr": UP_R, "hw": 0.8, "rw": 0.8}],
		[0.45, {"p": -0.3, "lift": 0.22, "sq": -0.4, "lw": 1.0, "legs": [-0.3, -0.2, -0.3, -0.2], "fl": UP_L, "fr": UP_R, "hw": 1.0, "rw": 1.0}],
		[0.58, {"p": 0.1, "lift": -0.05, "sq": 0.2}],
		[0.8, {}]]},
	# the ultimate: arms thrown up, the body lifted and held until the merge ends
	"mf_ult": {"hold": true, "keys": [
		[0.0, {}],
		[0.2, {"p": 0.35, "lift": 0.18, "sq": -0.25, "fl": UP_L, "fr": UP_R, "hw": 1.0, "rw": 1.0, "lw": 1.0, "legs": [-0.2, -0.3, -0.2, -0.3]}]]},
	# the rescue: the Boki lifted into the arms and carried (the legs keep running)
	"rs_carry": {"hold": true, "keys": [
		[0.0, {}],
		[0.3, {"p": 0.2, "lift": -0.05, "fl": Vector3(-0.12, 0.3, -0.4), "fr": Vector3(0.12, 0.3, -0.4), "hw": 1.0, "rw": 1.0}]]},
	"rs_done": {"keys": [
		[0.0, {"p": 0.3, "lift": -0.16, "fl": Vector3(-0.12, 0.3, -0.4), "fr": Vector3(0.12, 0.3, -0.4), "hw": 1.0, "rw": 1.0}],
		[0.15, {"p": -0.2, "lift": 0.15, "sq": -0.25, "fl": UP_L, "fr": UP_R, "hw": 1.0, "rw": 1.0}],
		[0.4, {}]]},
}
