class_name KMovesPinBjorn
extends RefCounted
## Keyed full-body moves of Hem (archer) and Breaker (bulwark): the same format and channels as
## HunterAnim.KMOVES (looked up by HunterAnim.km_sample). Timed to the hero sheets' 5 fps footage frames
## (one frame = 0.2 s): anticipation, a key pose on the release, overshoot, follow-through and settle.
## fl / fr place a free hand from its shoulder (hw / rw their weight), gp pitches the weapon.

## Hem's held draw: side-on, leaning back, the bow arm out at full reach, the string hand past the chest
## (the draw's Empowered key and the start of every release)
const DRAW_LEGS := [0.45, -0.6, -0.35, -0.3]
const DRAW_HAND := Vector3(0.17, 0.18, 0.36)
const DRAW_BOW := Vector3(0.04, 0.14, -0.6)
const DRAW_POSE := {
	"p": 0.2,
	"y": 0.8,
	"lw": 1.0,
	"legs": DRAW_LEGS,
	"hw": 1.0,
	"fl": DRAW_HAND,
	"rw": 1.0,
	"fr": DRAW_BOW
}

## The arrow nocked (0.05 s into the draw) and the fullest draw (Supercharged and held)
const NOCK_POSE := {
	"p": 0.05,
	"y": 0.25,
	"lw": 1.0,
	"legs": [0.15, -0.2, -0.1, -0.1],
	"hw": 1.0,
	"fl": Vector3(0.06, 0.14, 0.1),
	"rw": 1.0,
	"fr": Vector3(0.04, 0.1, -0.15)
}
const FULL_POSE := {
	"p": 0.24,
	"y": 0.9,
	"lw": 1.0,
	"legs": [0.5, -0.65, -0.38, -0.32],
	"hw": 1.0,
	"fl": Vector3(0.2, 0.2, 0.42),
	"rw": 1.0,
	"fr": Vector3(0.04, 0.15, -0.64)
}

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
	# ---------------------------------------------------------------- Hem (archer; hero sheet pin.md, 5 fps footage)
	# the bow drawn, on the draw's own clock (ArcherKit keeps it at Hunter.draw_t, so a quick draw and the
	# stage cues line up): the arrow nocks on the press (0.05 s), then one steady pull, the bow arm
	# reaching out and the string hand travelling back, to Empowered (0.6 s) and on to Supercharged (1.15 s)
	# where it holds; no tremble and no pose pop between stages (keys sit on a straight path)
	"arc_draw": {"hold": true, "keys": [
		[0.00, {}],
		[0.05, NOCK_POSE],
		[
			0.20,
			{
				"p": 0.091,
				"y": 0.4,
				"lw": 1.0,
				"legs": [0.232, -0.309, -0.168, -0.155],
				"hw": 1.0,
				"fl": Vector3(0.09, 0.151, 0.171),
				"rw": 1.0,
				"fr": Vector3(0.04, 0.111, -0.273)
			}
		],
		[
			0.35,
			{
				"p": 0.132,
				"y": 0.55,
				"lw": 1.0,
				"legs": [0.314, -0.418, -0.236, -0.209],
				"hw": 1.0,
				"fl": Vector3(0.12, 0.162, 0.242),
				"rw": 1.0,
				"fr": Vector3(0.04, 0.122, -0.395)
			}
		],
		[
			0.48,
			{
				"p": 0.167,
				"y": 0.68,
				"lw": 1.0,
				"legs": [0.385, -0.513, -0.295, -0.256],
				"hw": 1.0,
				"fl": Vector3(0.146, 0.171, 0.303),
				"rw": 1.0,
				"fr": Vector3(0.04, 0.131, -0.502)
			}
		],
		[0.60, DRAW_POSE],
		[
			0.80,
			{
				"p": 0.215,
				"y": 0.836,
				"lw": 1.0,
				"legs": [0.468, -0.618, -0.361, -0.307],
				"hw": 1.0,
				"fl": Vector3(0.181, 0.187, 0.382),
				"rw": 1.0,
				"fr": Vector3(0.04, 0.144, -0.615)
			}
		],
		[
			1.00,
			{
				"p": 0.229,
				"y": 0.873,
				"lw": 1.0,
				"legs": [0.486, -0.636, -0.372, -0.315],
				"hw": 1.0,
				"fl": Vector3(0.192, 0.195, 0.404),
				"rw": 1.0,
				"fr": Vector3(0.04, 0.147, -0.629)
			}
		],
		[1.15, FULL_POSE]]},
	# the string let go: the hand snaps back open (one frame), no big recoil, then settles
	"arc_loose": {"keys": [
		[0.0, DRAW_POSE],
		[
			0.05,
			{
				"p": 0.18,
				"y": 0.5,
				"lw": 1.0,
				"legs": [0.4, -0.5, -0.3, -0.3],
				"hw": 1.0,
				"fl": Vector3(0.26, 0.14, 0.34)
			}
		],
		[0.22, {"p": 0.06, "y": 0.3, "lw": 0.6, "hw": 0.5, "fl": Vector3(0.2, 0.05, 0.2)}],
		[0.42, {}]]},
	# a Supercharged release: the body kicks back hard, a half step back, the hand flung wide behind
	"arc_super": {"keys": [
		[0.0, FULL_POSE],
		[
			0.05,
			{
				"p": 0.38,
				"y": 0.35,
				"lift": 0.04,
				"sq": -0.16,
				"lw": 1.0,
				"legs": [0.15, -0.35, -0.55, -0.4],
				"hw": 1.0,
				"fl": Vector3(0.32, 0.2, 0.42),
				"gp": 0.15
			}
		],
		[
			0.25,
			{
				"p": 0.15,
				"y": 0.2,
				"sq": 0.08,
				"lw": 0.8,
				"legs": [0.4, -0.6, -0.3, -0.4],
				"hw": 0.6,
				"fl": Vector3(0.2, 0.05, 0.25)
			}
		],
		[0.6, {}]]},
	# the Heavy Shot's draw: like the bow draw but sunk low, weight back, the shoulders turned hard (holds)
	"arc_heavy_wind": {"hold": true, "keys": [
		[0.0, {}],
		[
			0.2,
			{
				"p": 0.18,
				"y": 0.6,
				"lift": -0.1,
				"sq": 0.15,
				"lw": 1.0,
				"legs": [0.8, -1.2, -0.5, -0.7],
				"hw": 1.0,
				"fl": Vector3(0.14, 0.16, 0.18)
			}
		],
		[
			1.1,
			{
				"p": 0.26,
				"y": 0.66,
				"lift": -0.16,
				"sq": 0.24,
				"lw": 1.0,
				"legs": [0.9, -1.3, -0.55, -0.8],
				"hw": 1.0,
				"fl": Vector3(0.2, 0.18, 0.3)
			}
		]]},
	# ... let go: thrown back by the shot (one frame), then planting out of it
	"arc_heavy": {"keys": [
		[
			0.0,
			{
				"p": 0.26,
				"y": 0.66,
				"lift": -0.16,
				"sq": 0.24,
				"lw": 1.0,
				"legs": [0.9, -1.3, -0.55, -0.8],
				"hw": 1.0,
				"fl": Vector3(0.2, 0.18, 0.3)
			}
		],
		[
			0.06,
			{
				"p": 0.5,
				"y": 0.15,
				"lift": 0.05,
				"sq": -0.2,
				"lw": 1.0,
				"legs": [0.5, -0.5, -0.4, -0.2],
				"hw": 1.0,
				"fl": Vector3(0.34, 0.1, 0.45),
				"gp": 0.2
			}
		],
		[0.28, {"p": 0.25, "lift": -0.05, "lw": 0.8, "legs": [0.6, -0.8, -0.3, -0.4]}],
		[0.6, {}]]},
	# Hail Wall: the bow raised high, the body arching back, the volley lobbed up in an arc, then down
	"arc_hail": {"keys": [
		[0.0, {"p": 0.1}],
		[
			0.12,
			{
				"p": 0.42,
				"lift": 0.06,
				"gp": 1.6,
				"hw": 1.0,
				"fl": Vector3(0.05, 0.8, 0.05),
				"lw": 0.8,
				"legs": [0.3, -0.5, 0.3, -0.5]
			}
		],
		[
			0.24,
			{
				"p": 0.3,
				"gp": 1.6,
				"hw": 1.0,
				"fl": Vector3(0.12, 0.75, 0.2),
				"sq": -0.1,
				"lw": 0.8,
				"legs": [0.4, -0.5, 0.1, -0.4]
			}
		],
		[0.6, {}]]},
	# Spirit Walk's dodge roll: tucked into one forward roll in 0.16 s, then up and light on the feet
	"pin_roll": {"keys": [
		[0.0, {"p": -0.35, "sq": 0.25, "lw": 1.0, "legs": [0.9, -1.3, 0.9, -1.3]}],
		[
			0.07,
			{
				"p": -0.5,
				"fx": 2.2,
				"sq": 0.35,
				"lift": 0.35,
				"lw": 1.0,
				"legs": [1.4, -1.9, 1.4, -1.9],
				"hw": 1.0,
				"fl": Vector3(0.0, -0.1, -0.2)
			}
		],
		[0.24, {"p": -0.3, "fx": 6.28, "sq": 0.15, "lift": 0.2, "lw": 1.0, "legs": [0.7, -1.0, 0.7, -1.0]}],
		[
			0.36,
			{
				"p": -0.25,
				"fx": 6.28,
				"lift": 0.0,
				"lw": 0.5,
				"legs": [0.5, -0.7, -0.2, -0.4],
				"hw": 0.9,
				"fl": Vector3(-0.15, -0.1, 0.35),
				"rw": 0.9,
				"fr": Vector3(0.15, -0.1, 0.35)
			}
		]]},
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
	# ---------------------------------------------------------------- Hem: the other LMB variants, procs and payoffs
	# a tap shot (let go before Empowered): a quick snap of the bow hand, half side-on, a little hop of the heel
	"arc_tap": {"keys": [
		[
			0.0,
			{
				"y": 0.6,
				"p": 0.1,
				"hw": 1.0,
				"fl": Vector3(0.12, 0.16, 0.24),
				"rw": 1.0,
				"fr": Vector3(0.04, 0.12, -0.45)
			}
		],
		[
			0.04,
			{
				"y": 0.3,
				"p": 0.22,
				"sq": -0.16,
				"hw": 1.0,
				"fl": Vector3(0.36, 0.12, 0.48),
				"rw": 1.0,
				"fr": Vector3(0.04, 0.16, -0.55),
				"lw": 1.0,
				"legs": [0.4, -0.6, -0.2, -0.4]
			}
		],
		[
			0.1,
			{
				"y": 0.2,
				"p": 0.26,
				"sq": -0.18,
				"hw": 1.0,
				"fl": Vector3(0.42, 0.1, 0.52),
				"lw": 1.0,
				"legs": [0.4, -0.6, -0.2, -0.4]
			}
		],
		[0.22, {"y": 0.05, "p": -0.08, "sq": 0.1, "hw": 0.5, "fl": Vector3(0.2, 0.05, 0.2)}],
		[0.36, {}]]},
	# a perfect release: the string hand flung up and open in a flourish, the chest lifted, a spin of the bow
	# hand and a proud settle (the gold star shows beside the bow hand)
	"arc_perfect": {"keys": [
		[0.0, DRAW_POSE],
		[
			0.06,
			{
				"p": 0.3,
				"y": 0.4,
				"lift": 0.06,
				"sq": -0.18,
				"lw": 1.0,
				"legs": [0.3, -0.4, -0.35, -0.3],
				"hw": 1.0,
				"fl": Vector3(0.3, 0.45, 0.3),
				"gp": 0.35
			}
		],
		[
			0.2,
			{
				"p": -0.08,
				"y": 0.1,
				"lift": -0.02,
				"sq": 0.1,
				"r": 0.12,
				"hw": 1.0,
				"fl": Vector3(0.25, 0.3, 0.05),
				"gp": -0.15,
				"lw": 0.8,
				"legs": [0.4, -0.6, -0.2, -0.3]
			}
		],
		[0.36, {"p": 0.04, "r": -0.04, "hw": 0.5, "fl": Vector3(0.12, 0.1, 0.05)}],
		[0.55, {}]]},
	# overdrawn: the draw arm starts to shake, the chest sags, the bow dips (held while drawing on)
	"arc_over": {"hold": true, "keys": [
		[0.0, FULL_POSE],
		[
			0.08,
			{
				"p": 0.02,
				"y": 0.58,
				"r": 0.06,
				"lw": 1.0,
				"legs": [0.45, -0.6, -0.3, -0.35],
				"hw": 1.0,
				"fl": Vector3(0.14, 0.12, 0.17),
				"gp": -0.12
			}
		],
		[
			0.16,
			{
				"p": 0.08,
				"y": 0.64,
				"r": -0.05,
				"lw": 1.0,
				"legs": [0.45, -0.6, -0.3, -0.35],
				"hw": 1.0,
				"fl": Vector3(0.16, 0.15, 0.19),
				"gp": -0.08
			}
		],
		[
			0.24,
			{
				"p": -0.02,
				"y": 0.57,
				"r": 0.06,
				"lw": 1.0,
				"legs": [0.5, -0.65, -0.3, -0.35],
				"hw": 1.0,
				"fl": Vector3(0.13, 0.1, 0.16),
				"gp": -0.16
			}
		],
		[
			0.32,
			{
				"p": 0.05,
				"y": 0.62,
				"r": -0.04,
				"lw": 1.0,
				"legs": [0.5, -0.65, -0.3, -0.35],
				"hw": 1.0,
				"fl": Vector3(0.15, 0.13, 0.18),
				"gp": -0.12
			}
		],
		[
			0.42,
			{
				"p": -0.05,
				"y": 0.56,
				"sq": 0.08,
				"lw": 1.0,
				"legs": [0.55, -0.7, -0.3, -0.4],
				"hw": 1.0,
				"fl": Vector3(0.12, 0.08, 0.15),
				"gp": -0.2
			}
		]]},
	# ...and let go: a weak, drooping release, the bow arm falling, a shake of the head
	"arc_over_loose": {"keys": [
		[
			0.0,
			{
				"p": -0.05,
				"y": 0.56,
				"sq": 0.08,
				"lw": 1.0,
				"legs": [0.55, -0.7, -0.3, -0.4],
				"hw": 1.0,
				"fl": Vector3(0.12, 0.08, 0.15),
				"gp": -0.2
			}
		],
		[0.06, {"p": -0.18, "y": 0.4, "sq": 0.14, "lw": 0.9, "hw": 1.0, "fl": Vector3(0.1, -0.05, 0.2), "gp": -0.5}],
		[0.3, {"p": -0.1, "y": 0.15, "r": 0.08, "sq": 0.06, "gp": -0.3}],
		[0.55, {}]]},
	# Spirit Walk after the roll: light on the toes, leaning in, arms trailing like a ghost (held while it lasts)
	"pin_walk": {"hold": true, "keys": [
		[0.0, {"p": -0.15, "fx": 6.28, "lw": 0.5, "legs": [0.4, -0.5, -0.2, -0.3]}],
		[
			0.2,
			{
				"p": -0.25,
				"lift": 0.08,
				"sq": -0.08,
				"hw": 0.9,
				"fl": Vector3(-0.15, -0.1, 0.35),
				"rw": 0.9,
				"fr": Vector3(0.15, -0.1, 0.35)
			}
		]]},
	# the base long dash (in the air, or out of Spirit Walk charges): a quick flick and a sideways tumble
	"pin_flick": {"keys": [
		[0.0, {"p": -0.2, "sq": 0.2, "lw": 1.0, "legs": [0.7, -1.0, 0.2, -0.4]}],
		[
			0.05,
			{
				"p": -0.35,
				"fz": 1.6,
				"sq": -0.25,
				"lift": 0.06,
				"lw": 1.0,
				"legs": [1.2, -1.6, 1.0, -1.5],
				"hw": 1.0,
				"fl": Vector3(-0.2, 0.3, 0.0)
			}
		],
		[0.18, {"p": -0.15, "fz": 6.28, "sq": 0.15, "lw": 1.0, "legs": [0.6, -0.9, 0.3, -0.5]}],
		[0.32, {"fz": 6.28, "sq": -0.05}],
		[0.42, {"fz": 6.28}]]},
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
	# ---------------------------------------------------------------- the ultimates on X (10 fps beats: 0.1 s each)
	# a beam loosed: the whole body kicked back one frame, the string hand flung behind, a skid, settle
	"pin_ult_loose": {"keys": [
		[0.0, {"p": 0.18, "y": 0.74, "lw": 1.0, "hw": 1.0, "fl": Vector3(0.2, 0.25, 0.3)}],
		[
			0.1,
			{
				"p": 0.42,
				"y": 0.4,
				"lift": 0.05,
				"sq": -0.2,
				"lw": 1.0,
				"legs": [0.1, -0.3, -0.6, -0.5],
				"hw": 1.0,
				"fl": Vector3(0.35, 0.22, 0.5),
				"gp": 0.2
			}
		],
		[0.3, {"p": 0.12, "y": 0.25, "sq": 0.1, "lw": 0.8, "legs": [0.4, -0.6, -0.3, -0.4], "hw": 0.5}],
		[0.5, {}]]},
	# the last beam: a bigger kick, both feet off the ground for a frame, a hard landing crouch
	"pin_ult_final": {"keys": [
		[0.0, {"p": 0.18, "y": 0.74, "lw": 1.0, "hw": 1.0, "fl": Vector3(0.2, 0.25, 0.3)}],
		[
			0.1,
			{
				"p": 0.55,
				"y": 0.45,
				"lift": 0.18,
				"sq": -0.28,
				"lw": 1.0,
				"legs": [-0.2, -0.4, -0.7, -0.6],
				"hw": 1.0,
				"fl": Vector3(0.45, 0.3, 0.6),
				"gp": 0.35
			}
		],
		[0.25, {"p": 0.05, "lift": -0.12, "sq": 0.3, "lw": 1.0, "legs": [0.9, -1.3, -0.4, -0.8], "hw": 0.6}],
		[0.65, {}]]},
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
		[0.6, {}]]},
}
