class_name MergeMoves
extends RefCounted
## Keyed full-body poses of the merged forms and of the rescue (HunterAnim.km_sample reads MOVES after its own KMOVES).
## Same channels as HunterAnim.KMOVES (p y r lift fx fz fy sq lw hw rw legs fl fr): "mf_*" are the forms' moves
## (transformation, slams, roll, hover, prism, bolts, ultimate), "rs_*" the rescue (kneel, cradle, stand up).
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
	# Heavy Star's slams: the near fist raised, then driven into the ground (the cone lands on the second key)
	"mf_slam_a": {"keys": [
		[0.0, {}],
		[0.12, {"p": 0.3, "lift": 0.08, "fr": UP_R, "rw": 1.0, "lw": 1.0, "legs": [0.2, -0.4, -0.2, -0.3]}],
		[0.2, {"p": -0.65, "lift": -0.1, "sq": 0.4, "fr": Vector3(0.1, -0.2, -0.6), "rw": 1.0, "lw": 1.0, "legs": [0.6, -0.8, -0.3, -0.5]}],
		[0.46, {}]]},
	"mf_slam_b": {"keys": [
		[0.0, {}],
		[0.12, {"p": 0.3, "lift": 0.1, "fl": UP_L, "hw": 1.0, "fr": UP_R, "rw": 1.0}],
		[0.2, {"p": -0.75, "lift": -0.14, "sq": 0.5, "fl": Vector3(-0.1, -0.2, -0.6), "hw": 1.0, "fr": Vector3(0.1, -0.2, -0.6), "rw": 1.0, "lw": 1.0, "legs": [0.7, -0.9, -0.3, -0.6]}],
		[0.5, {}]]},
	# the bulldoze: head down, shoulder first, held while it lasts
	"mf_roll": {"hold": true, "keys": [
		[0.0, {}],
		[0.15, {"p": -0.75, "sq": 0.25, "lift": -0.05, "lw": 1.0, "legs": [1.0, -1.3, -1.0, 0.4], "fl": FWD_L, "fr": FWD_R, "hw": 0.8, "rw": 0.8}]]},
	# the hover: lifted, legs hanging, arms out for balance
	"mf_hover": {"hold": true, "keys": [
		[0.0, {}],
		[0.2, {"lift": 0.15, "p": 0.1, "lw": 1.0, "legs": [0.3, -0.6, 0.2, -0.5], "fl": Vector3(-0.5, 0.2, -0.1), "fr": Vector3(0.5, 0.2, -0.1), "hw": 1.0, "rw": 1.0}]]},
	# the prism: both hands out in front, braced
	"mf_prism": {"hold": true, "keys": [
		[0.0, {}],
		[0.1, {"p": 0.1, "lw": 1.0, "legs": [0.3, -0.5, -0.3, -0.3], "fl": FWD_L, "fr": FWD_R, "hw": 1.0, "rw": 1.0}]]},
	# one-off casts
	"mf_e": {"keys": [
		[0.0, {}],
		[0.1, {"p": -0.3, "fl": FWD_L, "fr": FWD_R, "hw": 1.0, "rw": 1.0, "sq": -0.15}],
		[0.4, {}]]},
	"mf_bolt": {"keys": [
		[0.0, {"fr": FWD_R, "rw": 1.0, "p": -0.15}],
		[0.07, {"fr": Vector3(0.12, 0.15, -0.65), "rw": 1.0, "p": -0.25, "sq": -0.1}],
		[0.2, {}]]},
	"mf_shard": {"keys": [
		[0.0, {"fl": FWD_L, "fr": FWD_R, "hw": 1.0, "rw": 1.0}],
		[0.08, {"fl": Vector3(-0.16, 0.15, -0.7), "fr": Vector3(0.16, 0.15, -0.7), "hw": 1.0, "rw": 1.0, "p": -0.2}],
		[0.24, {}]]},
	# the ultimate: arms thrown up, the body lifted and held until the merge ends
	"mf_ult": {"hold": true, "keys": [
		[0.0, {}],
		[0.2, {"p": 0.35, "lift": 0.18, "sq": -0.25, "fl": UP_L, "fr": UP_R, "hw": 1.0, "rw": 1.0, "lw": 1.0, "legs": [-0.2, -0.3, -0.2, -0.3]}]]},
	# the rescue: down on a knee, then the Boki lifted and cradled; a pop to stand up
	"rs_kneel": {"hold": true, "keys": [
		[0.0, {}],
		[0.3, {"p": 0.5, "lift": -0.32, "sq": 0.3, "lw": 1.0, "legs": [1.2, -1.9, 0.2, -1.3], "fl": Vector3(-0.1, -0.1, -0.5), "fr": Vector3(0.1, -0.1, -0.5), "hw": 1.0, "rw": 1.0}]]},
	"rs_cradle": {"hold": true, "keys": [
		[0.0, {"p": 0.5, "lift": -0.32, "sq": 0.3, "lw": 1.0, "legs": [1.2, -1.9, 0.2, -1.3], "fl": Vector3(-0.1, -0.1, -0.5), "fr": Vector3(0.1, -0.1, -0.5), "hw": 1.0, "rw": 1.0}],
		[0.6, {"p": 0.3, "lift": -0.16, "sq": 0.15, "lw": 1.0, "legs": [0.7, -1.1, 0.1, -0.7], "fl": Vector3(-0.12, 0.3, -0.4), "fr": Vector3(0.12, 0.3, -0.4), "hw": 1.0, "rw": 1.0}]]},
	"rs_done": {"keys": [
		[0.0, {"p": 0.3, "lift": -0.16, "fl": Vector3(-0.12, 0.3, -0.4), "fr": Vector3(0.12, 0.3, -0.4), "hw": 1.0, "rw": 1.0}],
		[0.15, {"p": -0.2, "lift": 0.15, "sq": -0.25, "fl": UP_L, "fr": UP_R, "hw": 1.0, "rw": 1.0}],
		[0.4, {}]]},
}
