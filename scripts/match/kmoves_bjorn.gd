class_name KMovesBjorn
extends RefCounted
## Keyed full-body moves of Breaker (bulwark): the same format and channels as
## HunterAnim.KMOVES (looked up by HunterAnim.km_sample). Timed to the hero sheets' 5 fps footage frames
## (one frame = 0.2 s): anticipation, a key pose on the release, overshoot, follow-through and settle.

## Breaker's coil at full charge (the perfect window's pose and the start of each release): twisted hard away,
## sunk low and wide, the shield arm out front, the hammer hand hauled back low behind him
const BUL_COIL := {
	"y": 1.15,
	"p": 0.3,
	"lift": -0.16,
	"sq": 0.24,
	"gp": 0.5,
	"lw": 1.0,
	"legs": [0.85, -1.25, -0.6, -0.75],
	"hw": 1.0,
	"fl": Vector3(-0.05, 0.1, -0.5),
	"rw": 1.0,
	"fr": Vector3(0.3, -0.05, 0.42)
}

const MOVES := {
	# ---------------------------------------------------------------- Breaker (bulwark; hero sheet bjorn.md)
	# the hammer thrown (sheet 0033-0034): cocked far back and low for one frame, leaning away, then an
	# overhand throw (the hammer leaves the hand ~0.12 s after the press, as the arm comes through)
	# that overshoots past the front before it settles
	"bul_throw": {"keys": [
		[0, {}],
		[0.07, {"y": 1.1, "p": 0.3, "gp": 1.2, "sq": -0.1, "lw": 1.0, "legs": [0.2, -0.5, -0.35, -0.3]}],
		[0.14, {"y": -0.7, "p": -0.42, "gp": -0.6, "sq": 0.15, "lw": 1.0, "legs": [0.85, -0.7, -0.5, -0.3]}],
		[0.21, {"y": -0.95, "p": -0.48, "gp": -0.95, "sq": 0.2, "lw": 1.0, "legs": [0.9, -0.75, -0.55, -0.3]}],
		[0.34, {"y": -0.3, "p": -0.15, "gp": -0.2, "lw": 0.6}],
		[0.5, {}]]},
	# the hammer called back: the free hand reaches out, then draws in and catches
	"bul_recall": {"keys": [
		[0, {"hw": 1.0, "fl": Vector3(0.05, 0.1, -0.55), "p": -0.1}],
		[0.176, {"hw": 1.0, "fl": Vector3(0.05, 0.1, -0.6), "p": -0.15}],
		[0.299, {"hw": 1.0, "fl": Vector3(-0.05, -0.05, -0.15), "p": 0.1, "sq": 0.12}],
		[0.484, {}]]},
	# LMB held: whirling the hammer, side-on and crouched, the hammer arm out to the side, the
	# shield arm forward; the hammer circles him (BjornFx) while the body keeps facing the cursor. At full (1.05 s
	# into the move, 1.25 s held) he is sunk lowest and leaning into it, the whirl still going; the release keys
	# start from the coil (BUL_COIL), so the hammer hauls back on the swing's first frame
	"bul_smash_wind": {"hold": true, "keys": [
		[0.0, {}],
		[
			0.2,
			{
				"y": 0.75,
				"p": 0.12,
				"lift": -0.06,
				"sq": 0.1,
				"gp": 0.25,
				"lw": 1.0,
				"legs": [0.55, -0.85, -0.45, -0.5],
				"hw": 1.0,
				"fl": Vector3(-0.05, 0.12, -0.42),
				"rw": 1.0,
				"fr": Vector3(0.42, 0.38, 0.05)
			}
		],
		[
			0.95,
			{
				"y": 0.85,
				"p": 0.18,
				"lift": -0.1,
				"sq": 0.16,
				"gp": 0.3,
				"lw": 1.0,
				"legs": [0.65, -0.95, -0.5, -0.55],
				"hw": 1.0,
				"fl": Vector3(-0.05, 0.14, -0.45),
				"rw": 1.0,
				"fr": Vector3(0.45, 0.42, 0.05)
			}
		],
		[
			1.05,
			{
				"y": 0.9,
				"p": 0.22,
				"lift": -0.13,
				"sq": 0.2,
				"gp": 0.32,
				"lw": 1.0,
				"legs": [0.72, -1.05, -0.55, -0.62],
				"hw": 1.0,
				"fl": Vector3(-0.05, 0.14, -0.47),
				"rw": 1.0,
				"fr": Vector3(0.46, 0.44, 0.05)
			}
		]]},
	# ... let go: the hammer arm sweeps round from behind to the front in one frame and crashes down; the
	# shoulders turn hard with it but the body stays on its feet (the step's dash lean adds ~0.45 rad
	# forward, so the move's own pitch stays near zero), the impact the frame after, then 0.4 s to recover
	"bul_smash": {"keys": [
		[0.0, BUL_COIL],
		[
			0.08,
			{
				"y": -0.6,
				"p": 0.25,
				"lift": -0.12,
				"sq": 0.3,
				"gp": -1.1,
				"lw": 1.0,
				"legs": [1.15, -1.5, -0.45, -0.9],
				"rw": 1.0,
				"fr": Vector3(0.1, -0.1, -0.55)
			}
		],
		[
			0.16,
			{
				"y": -0.5,
				"p": 0.25,
				"lift": -0.1,
				"sq": 0.2,
				"gp": -1.0,
				"lw": 1.0,
				"legs": [1.1, -1.4, -0.4, -0.85],
				"rw": 1.0,
				"fr": Vector3(0.05, -0.15, -0.5)
			}
		],
		[0.5, {}]]},
	# the perfect swing: the coil uncoils in a full-body heave that throws his weight after the hammer
	# (stretched long, the back leg driving), feet off the ground with the knees tucked over the 0.3 s
	# launch, the front leg reaching for the ground, then a hard plant: braced back against a skid, sunk low
	# over the planted hammer, and a slow rise
	"bul_launch": {"keys": [
		[0.0, BUL_COIL],
		[
			0.05,
			{
				"y": -0.7,
				"p": 0.35,
				"lift": 0.3,
				"sq": -0.3,
				"gp": -1.1,
				"lw": 1.0,
				"legs": [0.9, -0.5, -0.85, -0.15],
				"hw": 1.0,
				"fl": Vector3(-0.15, 0.05, 0.2),
				"rw": 1.0,
				"fr": Vector3(0.1, -0.05, -0.6)
			}
		],
		[
			0.15,
			{
				"y": -0.55,
				"p": 0.42,
				"lift": 0.8,
				"sq": -0.12,
				"gp": -1.0,
				"lw": 1.0,
				"legs": [1.15, -1.7, 0.35, -1.5],
				"hw": 1.0,
				"fl": Vector3(-0.2, 0.15, 0.15),
				"rw": 1.0,
				"fr": Vector3(0.1, -0.2, -0.6)
			}
		],
		[
			0.26,
			{
				"y": -0.45,
				"p": 0.2,
				"lift": 0.35,
				"sq": 0.0,
				"gp": -0.9,
				"lw": 1.0,
				"legs": [1.0, -0.35, -0.35, -0.9],
				"hw": 1.0,
				"fl": Vector3(-0.2, 0.2, 0.0),
				"rw": 1.0,
				"fr": Vector3(0.15, -0.2, -0.5)
			}
		],
		[
			0.32,
			{
				"y": -0.4,
				"p": -0.15,
				"lift": -0.2,
				"sq": 0.45,
				"gp": -0.7,
				"lw": 1.0,
				"legs": [1.3, -1.1, -0.95, -0.45],
				"hw": 1.0,
				"fl": Vector3(-0.25, 0.25, 0.1),
				"rw": 1.0,
				"fr": Vector3(0.2, -0.25, -0.4)
			}
		],
		[
			0.48,
			{
				"y": -0.3,
				"p": -0.05,
				"lift": -0.16,
				"sq": 0.3,
				"gp": -0.6,
				"lw": 1.0,
				"legs": [1.2, -1.2, -0.8, -0.5],
				"hw": 0.6,
				"fl": Vector3(-0.2, 0.2, 0.1),
				"rw": 0.8,
				"fr": Vector3(0.2, -0.2, -0.35)
			}
		],
		[0.85, {}]]},
	# the aegis raised: braced low behind it, the shield arm out front (holds while it's up)
	"bul_guard": {"hold": true, "keys": [
		[0.0, {}],
		[
			0.12,
			{
				"p": -0.18,
				"lift": -0.06,
				"sq": 0.1,
				"y": -0.2,
				"lw": 1.0,
				"legs": [0.6, -0.9, -0.4, -0.5],
				"hw": 1.0,
				"fl": Vector3(0.0, 0.15, -0.48)
			}
		]]},
	# 360 Smash: a hard 0.17 s run-up (the dash's own lean tips him forward, so the move adds none), ONE full
	# turn in 0.16 s with the hammer held out at arm's length while he slides on, then a low crouched
	# recovery to 0.58 s
	"bul_whirl": {"keys": [
		[0.0, {"p": 0.15, "sq": -0.1, "lw": 1.0, "legs": [0.9, -0.8, -0.6, -0.4]}],
		[
			0.17,
			{
				"p": 0.05,
				"fy": 0.0,
				"y": 0.6,
				"sq": 0.2,
				"gp": 0.4,
				"lw": 1.0,
				"legs": [0.7, -0.9, -0.4, -0.5],
				"rw": 1.0,
				"fr": Vector3(0.6, 0.1, 0.0)
			}
		],
		[
			0.25,
			{
				"p": -0.05,
				"fy": 3.14,
				"sq": 0.15,
				"gp": 0.4,
				"lw": 1.0,
				"legs": [0.6, -0.8, -0.3, -0.4],
				"rw": 1.0,
				"fr": Vector3(0.65, 0.1, 0.0)
			}
		],
		[
			0.33,
			{
				"p": -0.1,
				"fy": 6.28,
				"sq": 0.35,
				"lift": -0.12,
				"gp": 0.3,
				"lw": 1.0,
				"legs": [1.0, -1.4, -0.4, -0.9]
			}
		],
		[0.58, {"p": -0.08, "fy": 6.28, "sq": 0.25, "lift": -0.1, "lw": 1.0, "legs": [0.9, -1.3, -0.35, -0.8]}],
		[0.75, {"fy": 6.28}]]},
	# the Shield Charge: head down behind the shield, a ram (on top of the dash's own forward lean)
	"bul_charge": {"keys": [
		[0.0, {"p": -0.1, "y": 0.2, "sq": 0.2, "lw": 1.0, "legs": [0.8, -1.0, -0.6, -0.4]}],
		[0.16, {"p": -0.2, "sq": 0.3, "lw": 1.0, "legs": [1.1, -1.1, -0.8, -0.3]}],
		[0.34, {"p": -0.1, "lw": 0.6, "legs": [0.7, -0.8, -0.4, -0.3]}],
		[0.6, {}]]},
	# the short dash out of a spinning Crushing Blow: a small hop-step that keeps the stance
	"bul_short": {"keys": [
		[0.0, {"y": 0.75, "p": 0.12, "lift": -0.06, "gp": 0.25, "lw": 1.0, "legs": [0.55, -0.85, -0.45, -0.5]}],
		[0.1, {"y": 0.6, "p": 0.05, "lift": 0.05, "gp": 0.25, "lw": 1.0, "legs": [0.7, -0.6, -0.5, -0.3]}],
		[0.25, {"y": 0.75, "p": 0.12, "lift": -0.06, "gp": 0.25, "lw": 1.0, "legs": [0.55, -0.85, -0.45, -0.5]}]]},
	# Mending Ground (Purify): the hammer hauled up to the sky on the toes, then driven down into the earth
	# as the light comes down; overshoot into a deep crouch, settle
	"bul_mend": {"keys": [
		[0.0, {}],
		[
			0.16,
			{
				"lift": 0.14,
				"p": 0.35,
				"sq": -0.22,
				"gp": 1.3,
				"hw": 1.0,
				"fl": Vector3(0.0, 0.55, -0.1),
				"lw": 1.0,
				"legs": [-0.1, -0.2, 0.2, -0.3]
			}
		],
		[
			0.26,
			{
				"lift": -0.16,
				"p": -0.6,
				"sq": 0.42,
				"gp": -1.0,
				"hw": 1.0,
				"fl": Vector3(0.0, -0.45, -0.4),
				"lw": 1.0,
				"legs": [1.0, -1.4, -0.4, -0.9]
			}
		],
		[
			0.45,
			{
				"lift": -0.1,
				"p": -0.45,
				"sq": 0.25,
				"gp": -0.8,
				"hw": 0.8,
				"fl": Vector3(0.0, -0.35, -0.35),
				"lw": 1.0,
				"legs": [0.9, -1.2, -0.35, -0.8]
			}
		],
		[0.95, {}]]},
	"bul_crush": {"keys": [
		[0.0, {}],
		[0.1, {"p": 0.35, "lift": 0.1, "sq": -0.2, "gp": 1.4, "lw": 1.0, "legs": [0.2, -0.3, 0.1, -0.2]}],
		[0.22, {"p": -0.2, "lift": -0.08, "sq": 0.3, "gp": 0.9, "lw": 1.0, "legs": [0.8, -1.1, -0.3, -0.6]}],
		[0.6, {}]]},
	# the Shield Slam (Guard 50): the 0.3 s tell, shield drawn in to the chest and the weight rocked back,
	# then a full-body drive behind it
	"bul_slamshield": {"keys": [
		[0.0, {}],
		[
			0.25,
			{
				"p": 0.32,
				"y": 0.45,
				"lift": 0.04,
				"sq": -0.12,
				"lw": 1.0,
				"legs": [-0.1, -0.3, 0.5, -0.7],
				"hw": 1.0,
				"fl": Vector3(0.05, 0.15, -0.1)
			}
		],
		[
			0.33,
			{
				"p": -0.6,
				"y": -0.3,
				"lift": -0.08,
				"sq": 0.42,
				"lw": 1.0,
				"legs": [1.1, -1.0, -0.6, -0.4],
				"hw": 1.0,
				"fl": Vector3(0.0, 0.12, -0.7)
			}
		],
		[0.55, {"p": -0.35, "y": -0.15, "sq": 0.18, "hw": 0.8, "fl": Vector3(0.0, 0.1, -0.5)}],
		[0.85, {}]]},
	# the aegis broken: rocked back, the shield arm flung wide, a stagger and recover
	"bul_break": {"keys": [
		[0.0, {}],
		[
			0.06,
			{
				"p": 0.22,
				"y": 0.3,
				"r": 0.15,
				"sq": -0.1,
				"hw": 1.0,
				"fl": Vector3(-0.4, 0.3, 0.2),
				"lw": 1.0,
				"legs": [-0.3, -0.2, 0.5, -0.8]
			}
		],
		[
			0.3,
			{"p": 0.2, "r": -0.08, "hw": 0.6, "fl": Vector3(-0.2, 0.0, 0.0), "lw": 0.8, "legs": [0.3, -0.6, 0.2, -0.4]}
		],
		[0.65, {}]]},
	# a Guard pip lighting up (the passive filling): a brief shrug of the shield up into place
	"bul_armed": {"keys": [
		[0.0, {}],
		[0.1, {"p": -0.08, "lift": 0.04, "sq": -0.08, "hw": 1.0, "fl": Vector3(0.0, 0.25, -0.35)}],
		[0.35, {}]]},
	# the base long dash: a lumbering shoulder shove, head down, the hammer trailing
	"bul_lumber": {"keys": [
		[0.0, {"p": -0.1, "y": 0.45, "sq": 0.2, "lw": 1.0, "legs": [0.8, -1.0, -0.5, -0.4], "gp": 0.4}],
		[
			0.12,
			{
				"p": -0.2,
				"y": 0.6,
				"sq": 0.3,
				"lift": -0.06,
				"lw": 1.0,
				"legs": [1.1, -0.9, -0.7, -0.3],
				"hw": 1.0,
				"fl": Vector3(0.1, 0.0, -0.3),
				"gp": 0.5
			}
		],
		[0.3, {"p": -0.12, "y": 0.3, "sq": 0.35, "lift": -0.1, "lw": 1.0, "legs": [0.9, -1.3, -0.4, -0.8]}],
		[0.5, {"sq": -0.05}],
		[0.6, {}]]},
	# Faultline wind-up (0.4 s, held): planted wide, the hammer hauled overhead in both hands, leaning back
	"bul_ult_wind": {"hold": true, "keys": [
		[0.0, {}],
		[
			0.2,
			{
				"p": -0.3,
				"lift": 0.04,
				"sq": -0.12,
				"blade": Vector3(0.0, 2.4, 0.0),
				"bw": 1.0,
				"rad": 0.35,
				"hw": 1.0,
				"fl": Vector3(0.0, 0.6, -0.05),
				"lw": 1.0,
				"legs": [0.6, -0.8, -0.5, -0.6]
			}
		],
		[
			0.4,
			{
				"p": -0.4,
				"lift": 0.06,
				"sq": -0.16,
				"blade": Vector3(0.0, 2.8, 0.0),
				"bw": 1.0,
				"rad": 0.35,
				"hw": 1.0,
				"fl": Vector3(0.0, 0.66, -0.1),
				"lw": 1.0,
				"legs": [0.7, -0.9, -0.55, -0.7]
			}
		]]},
	# the Faultline slam: one frame from overhead down into the ground, a deep crouch over it through the plant
	# (0.2 s), then the legs free to walk while the back comes up over the hammer as the lane erupts
	"bul_ult_slam": {"keys": [
		[
			0.0,
			{
				"p": -0.4,
				"blade": Vector3(0.0, 2.8, 0.0),
				"bw": 1.0,
				"rad": 0.35,
				"hw": 1.0,
				"fl": Vector3(0.0, 0.66, -0.1),
				"lw": 1.0,
				"legs": [0.7, -0.9, -0.55, -0.7]
			}
		],
		[
			0.1,
			{
				"p": 0.4,
				"lift": -0.22,
				"sq": 0.45,
				"blade": Vector3(0.0, -0.1, 0.0),
				"bw": 1.0,
				"rad": 0.85,
				"hw": 1.0,
				"fl": Vector3(0.0, -0.5, 0.45),
				"lw": 1.0,
				"legs": [1.2, -1.6, -0.5, -1.0]
			}
		],
		[
			0.2,
			{
				"p": 0.35,
				"lift": -0.18,
				"sq": 0.35,
				"blade": Vector3(0.0, -0.15, 0.0),
				"bw": 0.9,
				"rad": 0.8,
				"hw": 1.0,
				"fl": Vector3(0.0, -0.45, 0.4),
				"lw": 1.0,
				"legs": [1.1, -1.5, -0.45, -0.9]
			}
		],
		[
			0.36,
			{
				"p": 0.18,
				"lift": -0.04,
				"sq": 0.12,
				"blade": Vector3(0.0, 0.3, 0.0),
				"bw": 0.5,
				"rad": 0.6,
				"hw": 0.6,
				"fl": Vector3(0.0, -0.3, 0.3),
				"lw": 0.0
			}
		],
		[0.6, {}]]}
}
