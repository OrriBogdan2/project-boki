class_name MergeMoves
extends RefCounted
## Keyed full-body poses of the merged forms and of the rescue (HunterAnim.km_sample reads MOVES after its own KMOVES).
## Same channels as HunterAnim.KMOVES (p y r lift fx fz fy sq lw hw rw legs fl fr): "mf_*" are the forms' moves
## (transformation, ultimate, release), "rs_*" the rescue (carry, stand up). Each form's ultimate "mf_ult_<form id>"
## keys its beats (content/merge_forms/<id>.json r.beats) to the same times; a Boki without a form has "mf_ult".
## Every other state of a form is the hero's own (idle, walk, run, LMB, RMB, E, dash, hit): --fusion-states-check.
## A move with "hold": true stays on its last key until another replaces it. Forward is -z in the hand keys.

const UP_L := Vector3(-0.12, 0.6, -0.1)
const UP_R := Vector3(0.12, 0.6, -0.1)
const FWD_L := Vector3(-0.12, 0.15, -0.55)
const FWD_R := Vector3(0.12, 0.15, -0.55)
const OPEN_L := Vector3(-0.5, 0.25, -0.15)      # arms flung out to the sides
const OPEN_R := Vector3(0.5, 0.25, -0.15)
const LOW_L := Vector3(-0.15, -0.3, -0.45)      # fists driven down in front
const LOW_R := Vector3(0.15, -0.3, -0.45)
const CHEST_L := Vector3(0.1, 0.25, -0.25)      # arms crossed over the chest
const CHEST_R := Vector3(-0.1, 0.25, -0.25)
const CROUCH := [0.8, -1.4, 0.6, -1.2]
const TUCK := [1.1, -1.7, 1.0, -1.6]
const STRAIGHT := [-0.3, -0.2, -0.3, -0.2]
const RELEASE := "mf_release"
const OUT_AT := "mf_out_at"     # hunter meta on the owner's game: when the merge ended (MergeKit.releasing)

const MOVES := {
	# the transformation: crouch as the Boki leaps up, spring open as it lands (0.45s), settle by 0.7
	"mf_xform": {"keys": [
		[0.0, {}],
		[0.18, {"p": 0.35, "lift": -0.12, "sq": 0.3, "lw": 1.0, "legs": [0.7, -1.2, 0.5, -1.0],
				"fl": UP_L, "fr": UP_R, "hw": 0.8, "rw": 0.8}],
		[0.45, {"p": -0.3, "lift": 0.22, "sq": -0.4, "lw": 1.0, "legs": [-0.3, -0.2, -0.3, -0.2],
				"fl": UP_L, "fr": UP_R, "hw": 1.0, "rw": 1.0}],
		[0.58, {"p": 0.1, "lift": -0.05, "sq": 0.2}],
		[0.8, {}]]},
	# the ultimate: arms thrown up, the body lifted and held until the merge ends
	"mf_ult": {"hold": true, "keys": [
		[0.0, {}],
		[0.2, {"p": 0.35, "lift": 0.18, "sq": -0.25,
				"fl": UP_L, "fr": UP_R, "hw": 1.0, "rw": 1.0, "lw": 1.0, "legs": [-0.2, -0.3, -0.2, -0.3]}]]},
	# Thunderhead (stormwing, rise 0.0-0.7, strike_all at 0.7, end 1.2): a dip, a climb gathering both arms
	# overhead, cocked back at the top, both arms thrown down on the strike, then hovering with arms spread
	"mf_ult_stormwing": {"hold": true, "keys": [
		[0.0, {}],
		[0.12, {"p": 0.3, "lift": -0.08, "sq": 0.25, "lw": 1.0, "legs": CROUCH,
				"fl": FWD_L, "fr": FWD_R, "hw": 0.6, "rw": 0.6}],
		[0.4, {"p": -0.15, "sq": -0.3, "lw": 1.0, "legs": STRAIGHT, "fl": UP_L, "fr": UP_R, "hw": 1.0, "rw": 1.0}],
		[0.62, {"p": -0.4, "sq": -0.2, "lw": 1.0, "legs": [0.2, -0.9, 0.1, -0.7],
				"fl": UP_L, "fr": UP_R, "hw": 1.0, "rw": 1.0}],
		[0.7, {"p": 0.45, "sq": 0.2, "lw": 1.0, "legs": [0.6, -1.0, 0.4, -0.8],
				"fl": LOW_L, "fr": LOW_R, "hw": 1.0, "rw": 1.0}],
		[0.9, {"p": 0.15, "lw": 1.0, "legs": [0.4, -0.8, 0.3, -0.7],
				"fl": OPEN_L, "fr": OPEN_R, "hw": 0.8, "rw": 0.8}]]},
	# Prism Shell (tidal_shell, crack 0.0-0.55, burst at 0.55, end 0.8): curled up tight behind crossed arms while
	# the shell splits, then thrown wide open on the burst
	"mf_ult_tidal_shell": {"hold": true, "keys": [
		[0.0, {}],
		[0.15, {"p": 0.45, "lift": -0.12, "sq": 0.35, "lw": 1.0, "legs": CROUCH,
				"fl": CHEST_L, "fr": CHEST_R, "hw": 1.0, "rw": 1.0}],
		[0.5, {"p": 0.55, "lift": -0.16, "sq": 0.45, "lw": 1.0, "legs": CROUCH,
				"fl": CHEST_L, "fr": CHEST_R, "hw": 1.0, "rw": 1.0}],
		[0.55, {"p": -0.35, "lift": 0.1, "sq": -0.35, "lw": 1.0, "legs": STRAIGHT,
				"fl": OPEN_L, "fr": OPEN_R, "hw": 1.0, "rw": 1.0}],
		[0.75, {"p": -0.1, "sq": -0.1, "lw": 0.6, "legs": STRAIGHT,
				"fl": OPEN_L, "fr": OPEN_R, "hw": 0.8, "rw": 0.8}]]},
	# Heavy Star (titan, leap 0.0-0.65, the pull and small slam on landing, the big slam 0.4 later, end 1.2): load,
	# launch with arms up, tucked at the top, both fists down on the landing, up again and down on the big slam
	"mf_ult_titan": {"hold": true, "keys": [
		[0.0, {}],
		[0.1, {"p": 0.3, "lift": -0.12, "sq": 0.35, "lw": 1.0, "legs": CROUCH,
				"fl": FWD_L, "fr": FWD_R, "hw": 0.5, "rw": 0.5}],
		[0.22, {"p": -0.2, "sq": -0.35, "lw": 1.0, "legs": STRAIGHT, "fl": UP_L, "fr": UP_R, "hw": 1.0, "rw": 1.0}],
		[0.45, {"p": -0.15, "lw": 1.0, "legs": TUCK, "fl": UP_L, "fr": UP_R, "hw": 1.0, "rw": 1.0}],
		[0.65, {"p": 0.55, "lift": -0.18, "sq": 0.45, "lw": 1.0, "legs": CROUCH,
				"fl": LOW_L, "fr": LOW_R, "hw": 1.0, "rw": 1.0}],
		[0.9, {"p": -0.2, "sq": -0.15, "lw": 1.0, "legs": [0.4, -0.8, 0.3, -0.7],
				"fl": UP_L, "fr": UP_R, "hw": 1.0, "rw": 1.0}],
		[1.05, {"p": 0.6, "lift": -0.2, "sq": 0.4, "lw": 1.0, "legs": CROUCH,
				"fl": LOW_L, "fr": LOW_R, "hw": 1.0, "rw": 1.0}],
		[1.2, {"p": 0.35, "lift": -0.1, "sq": 0.2, "lw": 1.0, "legs": CROUCH,
				"fl": LOW_L, "fr": LOW_R, "hw": 0.8, "rw": 0.8}]]},
	# the release: the Boki springs out of the chest, the body jolts back with arms flung open and steps back in
	RELEASE: {"keys": [
		[0.0, {}],
		[0.08, {"p": -0.35, "lift": 0.06, "sq": -0.25, "lw": 0.6, "legs": [-0.2, -0.3, 0.3, -0.5],
				"fl": OPEN_L, "fr": OPEN_R, "hw": 1.0, "rw": 1.0}],
		[0.25, {"p": 0.15, "lift": -0.05, "sq": 0.15, "lw": 0.6, "legs": [0.3, -0.6, 0.2, -0.5]}],
		[0.5, {}]]},
	# the rescue: the Boki lifted into the arms and carried (the legs keep running)
	"rs_carry": {"hold": true, "keys": [
		[0.0, {}],
		[0.3, {"p": 0.2, "lift": -0.05,
				"fl": Vector3(-0.12, 0.3, -0.4), "fr": Vector3(0.12, 0.3, -0.4), "hw": 1.0, "rw": 1.0}]]},
	"rs_done": {"keys": [
		[0.0, {"p": 0.3, "lift": -0.16,
				"fl": Vector3(-0.12, 0.3, -0.4), "fr": Vector3(0.12, 0.3, -0.4), "hw": 1.0, "rw": 1.0}],
		[0.15, {"p": -0.2, "lift": 0.15, "sq": -0.25, "fl": UP_L, "fr": UP_R, "hw": 1.0, "rw": 1.0}],
		[0.4, {}]]},
}

## The ultimate's move for a form ("mf_ult" for a Boki without a form).
static func ult_move(form_id: String) -> String:
	var id := "mf_ult_" + form_id
	return id if MOVES.has(id) else "mf_ult"

## Is this form move still showing `t` seconds in? (a "hold" move shows until another replaces it)
static func playing(id: String, t: float) -> bool:
	if not id.begins_with("mf_") or not MOVES.has(id):
		return false
	var mv: Dictionary = MOVES[id]
	return bool(mv.get("hold", false)) or t < float((mv["keys"] as Array)[-1][0])
