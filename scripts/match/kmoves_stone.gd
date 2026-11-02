class_name KMovesStone
extends RefCounted
## Keyed full-body moves of Breah (dolm) and Ostra (same format and channels as HunterAnim.KMOVES; looked
## up by HunterAnim.km_sample after its own table). Timed to the reference sheets' beats: anticipation,
## the release key on the kit's hit frame, an overshoot, then the settle. Breah is heavy and grounded
## (deep knees, squash on every impact, the huge fists leading); Ostra floats (lifts, stretches and a
## spin on her Swell, light hands).

const MOVES := {
	# ---------------------------------------------------------------- Breah
	# Boulder (tap): no long wind-up. The right fist dips back low (0.06), hurls underarm and up on the
	# release (0.12, the shot leaves), the body stretching after it, then a quick settle
	"breah_throw": {"keys": [
		[0.00, {}],
		[
			0.06,
			{
				"p": 0.18, "y": -0.45, "sq": 0.12, "legs": [0.35, -0.7, 0.3, -0.62], "lw": 1.0,
				"fr": Vector3(0.22, -0.32, 0.42), "rw": 1.0, "fl": Vector3(-0.2, 0.25, -0.25), "hw": 0.8
			}
		],
		[
			0.12,
			{
				"p": -0.4, "y": 0.55, "sq": -0.12, "lift": 0.04, "legs": [0.5, -0.9, 0.2, -0.4], "lw": 1.0,
				"fr": Vector3(0.05, 0.38, -0.75), "rw": 1.0, "fl": Vector3(-0.25, 0.05, 0.1), "hw": 0.8
			}
		],
		[0.22, {"p": -0.3, "y": 0.4, "sq": 0.05, "fr": Vector3(0.05, 0.25, -0.62), "rw": 0.8}],
		[0.50, {}]]},
	# Punch held: sunk low and twisted away, the right fist cocked far behind the hip, the left
	# forearm up as a guard; the body squashes into the ground (it holds while you charge)
	"breah_wind": {"hold": true, "keys": [
		[0.00, {}],
		[
			0.10,
			{
				"p": 0.12, "y": 0.4, "sq": 0.08, "legs": [0.3, -0.6, 0.25, -0.55], "lw": 1.0,
				"fr": Vector3(0.3, 0.1, 0.3), "rw": 1.0, "fl": Vector3(-0.05, 0.25, -0.3), "hw": 1.0
			}
		],
		[
			0.24,
			{
				"p": 0.26, "y": 0.78, "sq": 0.22, "lift": -0.1, "legs": [0.62, -1.15, 0.5, -1.0], "lw": 1.0,
				"fl": Vector3(-0.05, 0.36, -0.42), "hw": 1.0, "fr": Vector3(0.38, 0.12, 0.62), "rw": 1.0
			}
		]]},
	# Punch let go: the hips unwind into a straight drive, stretched long on the hit (0.05), an
	# overshoot past the line (0.12), then the heavy fist pulls back in
	"breah_punch": {"keys": [
		[
			0.00,
			{
				"p": 0.26, "y": 0.78, "sq": 0.22, "lift": -0.1, "legs": [0.62, -1.15, 0.5, -1.0], "lw": 1.0,
				"fl": Vector3(-0.05, 0.36, -0.42), "hw": 1.0, "fr": Vector3(0.38, 0.12, 0.62), "rw": 1.0
			}
		],
		[
			0.05,
			{
				"p": -0.7, "y": -0.62, "sq": -0.16, "legs": [0.75, -1.25, 0.1, -0.3], "lw": 1.0,
				"fl": Vector3(-0.25, 0.1, 0.2), "hw": 1.0, "fr": Vector3(0.0, 0.1, -0.98), "rw": 1.0
			}
		],
		[
			0.12,
			{
				"p": -0.78, "y": -0.72, "sq": 0.08, "legs": [0.8, -1.3, 0.12, -0.32], "lw": 1.0,
				"fl": Vector3(-0.25, 0.1, 0.25), "hw": 1.0, "fr": Vector3(0.0, 0.05, -1.02), "rw": 1.0
			}
		],
		[
			0.30,
			{
				"p": -0.32, "y": -0.25, "sq": 0.04, "fr": Vector3(0.0, 0.02, -0.55), "rw": 0.7,
				"fl": Vector3(-0.2, 0.1, -0.15), "hw": 0.5
			}
		],
		[0.60, {}]]},
	# Quakefall held: a low crouch, the fists drawn in at the hips and glowing (it holds)
	"breah_crouch": {"hold": true, "keys": [
		[0.00, {}],
		[
			0.08,
			{
				"p": -0.15, "sq": 0.12, "legs": [0.4, -0.8, 0.36, -0.72], "lw": 1.0, "fl": Vector3(-0.3, -0.1, 0.0),
				"hw": 1.0, "fr": Vector3(0.3, -0.1, 0.0), "rw": 1.0
			}
		],
		[
			0.22,
			{
				"p": -0.38, "sq": 0.28, "lift": -0.16, "legs": [0.95, -1.6, 0.85, -1.5], "lw": 1.0,
				"fl": Vector3(-0.34, -0.26, 0.08), "hw": 1.0, "fr": Vector3(0.34, -0.26, 0.08), "rw": 1.0
			}
		]]},
	# jump while charging: tucked, the fists coming up overhead, leaning into the leap
	"breah_leap": {"hold": true, "keys": [
		[
			0.00,
			{
				"p": -0.38, "sq": 0.28, "lift": -0.16, "legs": [0.95, -1.6, 0.85, -1.5], "lw": 1.0,
				"fl": Vector3(-0.34, -0.26, 0.08), "hw": 1.0, "fr": Vector3(0.34, -0.26, 0.08), "rw": 1.0
			}
		],
		[
			0.10,
			{
				"p": -0.2, "sq": -0.18, "legs": [0.9, -1.7, 0.7, -1.5], "lw": 1.0, "fl": Vector3(-0.2, 0.75, 0.05),
				"hw": 1.0, "fr": Vector3(0.2, 0.75, 0.05), "rw": 1.0
			}
		],
		[
			0.30,
			{
				"p": 0.3, "sq": -0.1, "legs": [1.0, -1.8, 0.8, -1.6], "lw": 1.0, "fl": Vector3(-0.16, 1.0, 0.12),
				"hw": 1.0, "fr": Vector3(0.16, 1.0, 0.12), "rw": 1.0
			}
		]]},
	# Quakefall let go: a hop up, the fists swung overhead (stretched, 0.08), then both driven into the
	# ground on the hit (0.16): squashed flat, knees wide, a long heavy settle
	"breah_slam": {"keys": [
		[
			0.00,
			{
				"p": -0.38, "sq": 0.28, "lift": -0.16, "legs": [0.95, -1.6, 0.85, -1.5], "lw": 1.0,
				"fl": Vector3(-0.34, -0.26, 0.08), "hw": 1.0, "fr": Vector3(0.34, -0.26, 0.08), "rw": 1.0
			}
		],
		[
			0.08,
			{
				"p": 0.38, "lift": 0.36, "sq": -0.22, "legs": [0.5, -1.0, 0.45, -0.9], "lw": 1.0,
				"fl": Vector3(-0.16, 1.02, 0.12), "hw": 1.0, "fr": Vector3(0.16, 1.02, 0.12), "rw": 1.0
			}
		],
		[
			0.16,
			{
				"p": -0.8, "lift": -0.12, "sq": 0.46, "legs": [0.85, -1.45, 0.75, -1.35], "lw": 1.0,
				"fl": Vector3(-0.16, -0.68, -0.5), "hw": 1.0, "fr": Vector3(0.16, -0.68, -0.5), "rw": 1.0
			}
		],
		[
			0.40,
			{
				"p": -0.7, "lift": -0.1, "sq": 0.3, "legs": [0.8, -1.4, 0.7, -1.3], "lw": 1.0,
				"fl": Vector3(-0.16, -0.62, -0.48), "hw": 1.0, "fr": Vector3(0.16, -0.62, -0.48), "rw": 1.0
			}
		],
		[
			0.62,
			{
				"p": -0.25, "sq": 0.08, "fl": Vector3(-0.2, -0.2, -0.3), "hw": 0.6, "fr": Vector3(0.2, -0.2, -0.3),
				"rw": 0.6
			}
		],
		[0.95, {}]]},
	# the air Quakefall: fists high, pitched down over them as she falls
	"breah_dive": {"hold": true, "keys": [
		[0.00, {}],
		[
			0.12,
			{
				"p": 0.3, "sq": -0.2, "legs": [0.6, -1.2, 0.5, -1.1], "lw": 1.0, "fl": Vector3(-0.16, 1.0, 0.1),
				"hw": 1.0, "fr": Vector3(0.16, 1.0, 0.1), "rw": 1.0
			}
		],
		[
			0.30,
			{
				"p": -0.35, "fx": -0.25, "sq": -0.25, "legs": [0.3, -0.5, 0.3, -0.5], "lw": 1.0,
				"fl": Vector3(-0.16, 0.2, -0.6), "hw": 1.0, "fr": Vector3(0.16, 0.2, -0.6), "rw": 1.0
			}
		]]},
	# ... and its landing: the same crash as the slam's hit
	"breah_slam_land": {"keys": [
		[
			0.00,
			{
				"p": -0.8, "lift": -0.14, "sq": 0.5, "legs": [0.9, -1.5, 0.8, -1.4], "lw": 1.0,
				"fl": Vector3(-0.16, -0.68, -0.5), "hw": 1.0, "fr": Vector3(0.16, -0.68, -0.5), "rw": 1.0
			}
		],
		[
			0.28,
			{
				"p": -0.65, "sq": 0.28, "legs": [0.8, -1.4, 0.7, -1.3], "lw": 1.0, "fl": Vector3(-0.16, -0.6, -0.45),
				"hw": 1.0, "fr": Vector3(0.16, -0.6, -0.45), "rw": 1.0
			}
		],
		[0.75, {}]]},
	# the punch during a charge: both fists thrown forward in a short drive
	"breah_lunge": {"keys": [
		[0.00, {"p": -0.38, "sq": 0.2, "legs": [0.9, -1.5, 0.8, -1.4], "lw": 1.0}],
		[
			0.06,
			{
				"p": -0.6, "sq": -0.12, "legs": [0.8, -1.2, 0.1, -0.3], "lw": 1.0, "fl": Vector3(-0.12, 0.05, -0.8),
				"hw": 1.0, "fr": Vector3(0.12, 0.05, -0.8), "rw": 1.0
			}
		],
		[
			0.30,
			{
				"p": -0.38, "sq": 0.24, "lift": -0.12, "legs": [0.9, -1.5, 0.8, -1.4], "lw": 1.0,
				"fl": Vector3(-0.34, -0.26, 0.08), "hw": 1.0, "fr": Vector3(0.34, -0.26, 0.08), "rw": 1.0
			}
		]]},
	# Rubble Rush: the rock bursts up (a stamp, 0.05), then she barrels shoulder-first behind it, fists
	# braced on its back, leaning hard; the end squashes as the rock leaves her hands
	"breah_dash": {"keys": [
		[0.00, {}],
		[
			0.05,
			{
				"p": 0.15, "sq": 0.2, "lift": -0.06, "legs": [-0.6, 0.7, 0.4, -0.8], "lw": 1.0,
				"fl": Vector3(-0.15, -0.35, -0.3), "hw": 1.0, "fr": Vector3(0.15, -0.35, -0.3), "rw": 1.0
			}
		],
		[
			0.12,
			{
				"p": -0.8, "y": 0.45, "sq": -0.1, "legs": [0.8, -1.3, 0.5, -0.9], "lw": 1.0,
				"fl": Vector3(-0.12, -0.02, -0.62), "hw": 1.0, "fr": Vector3(0.12, -0.02, -0.62), "rw": 1.0
			}
		],
		[
			0.28,
			{
				"p": -0.7, "y": 0.35, "legs": [0.4, -0.7, 0.8, -1.2], "lw": 1.0, "fl": Vector3(-0.12, 0.05, -0.85),
				"hw": 1.0, "fr": Vector3(0.12, 0.05, -0.85), "rw": 1.0
			}
		],
		[
			0.36,
			{
				"p": -0.35, "sq": 0.24, "lift": -0.08, "legs": [0.7, -1.2, 0.6, -1.1], "lw": 1.0,
				"fl": Vector3(-0.1, 0.1, -0.9), "hw": 1.0, "fr": Vector3(0.1, 0.1, -0.9), "rw": 1.0
			}
		],
		[0.70, {}]]},
	# her base dash (the long one): a heavy lumbering shove, palms out, weight thrown into it, and a
	# squashing two-footed landing
	"breah_exdash": {"keys": [
		[0.00, {"sq": 0.18, "lift": -0.06, "p": 0.1}],
		[
			0.07,
			{
				"p": -0.6, "y": -0.3, "sq": -0.1, "legs": [0.7, -1.1, 0.2, -0.4], "lw": 1.0,
				"fl": Vector3(-0.2, 0.25, -0.7), "hw": 1.0, "fr": Vector3(0.2, 0.25, -0.7), "rw": 1.0
			}
		],
		[
			0.22,
			{
				"p": -0.5, "y": -0.2, "legs": [0.3, -0.5, 0.7, -1.1], "lw": 1.0, "fl": Vector3(-0.2, 0.2, -0.6),
				"hw": 0.8, "fr": Vector3(0.2, 0.2, -0.6), "rw": 0.8
			}
		],
		[0.30, {"p": -0.2, "sq": 0.3, "lift": -0.1, "legs": [0.8, -1.3, 0.7, -1.2], "lw": 1.0}],
		[0.60, {}]]},
	# Stone Row: a stomp (the knee up, 0.08), both palms slapped to the ground on the tell (0.2), then
	# heaved up as the rocks rise (0.36), a proud settle
	"breah_raise": {"keys": [
		[0.00, {}],
		[
			0.08,
			{
				"p": 0.15, "sq": -0.06, "legs": [-1.1, 1.2, 0.25, -0.35], "lw": 1.0, "fl": Vector3(-0.25, 0.35, -0.1),
				"hw": 1.0, "fr": Vector3(0.25, 0.35, -0.1), "rw": 1.0
			}
		],
		[
			0.20,
			{
				"p": -0.7, "sq": 0.38, "lift": -0.12, "legs": [0.8, -1.35, 0.7, -1.25], "lw": 1.0,
				"fl": Vector3(-0.22, -0.8, -0.45), "hw": 1.0, "fr": Vector3(0.22, -0.8, -0.45), "rw": 1.0
			}
		],
		[
			0.36,
			{
				"p": 0.22, "sq": -0.14, "lift": 0.06, "legs": [0.3, -0.5, 0.25, -0.45], "lw": 1.0,
				"fl": Vector3(-0.3, 0.62, -0.35), "hw": 1.0, "fr": Vector3(0.3, 0.62, -0.35), "rw": 1.0
			}
		],
		[
			0.55,
			{"p": 0.1, "sq": 0.05, "fl": Vector3(-0.3, 0.4, -0.3), "hw": 0.6, "fr": Vector3(0.3, 0.4, -0.3), "rw": 0.6}
		],
		[0.90, {}]]},
	# Tremor Sense finding someone: a palm pressed to the ground, the head cocked toward the feeling
	"breah_sense": {"keys": [
		[0.00, {}],
		[0.10, {"r": 0.16, "p": -0.25, "sq": 0.1, "fr": Vector3(0.15, -0.6, -0.25), "rw": 1.0}],
		[0.30, {"r": 0.12, "p": -0.2, "fr": Vector3(0.15, -0.55, -0.25), "rw": 0.8}],
		[0.50, {}]]},
	# ---------------------------------------------------------------- Ostra
	# an orb: a flick of the casting hand from the shoulder
	"ostra_orb": {"keys": [
		[0.00, {}],
		[0.04, {"gp": 0.25, "y": -0.2, "fr": Vector3(0.2, 0.25, 0.15), "rw": 1.0}],
		[0.09, {"gp": -0.15, "y": 0.25, "p": -0.12, "fr": Vector3(0.05, 0.22, -0.62), "rw": 1.0}],
		[0.30, {}]]},
	# the Settled bolt: drawn back, then the arm flung out straight and the body kicked back by it
	"ostra_orb_hot": {"keys": [
		[0.00, {}],
		[
			0.06,
			{
				"gp": -0.35, "p": 0.2, "y": -0.4, "lift": 0.06, "sq": 0.1, "fr": Vector3(0.3, 0.3, 0.35), "rw": 1.0,
				"fl": Vector3(-0.2, 0.1, -0.2), "hw": 0.6
			}
		],
		[
			0.11,
			{
				"gp": 0.15, "p": -0.3, "y": 0.45, "sq": -0.14, "fr": Vector3(0.0, 0.3, -0.85), "rw": 1.0,
				"fl": Vector3(-0.3, 0.0, 0.2), "hw": 0.6
			}
		],
		[0.22, {"gp": 0.7, "p": 0.18, "y": 0.3, "lift": 0.1, "fr": Vector3(0.0, 0.35, -0.7), "rw": 1.0}],
		[0.50, {}]]},
	# the Snap's wind-up: both hands drawn in to the chest round the dark orb, leaning back (it holds)
	"ostra_snap_wind": {"hold": true, "keys": [
		[0.00, {}],
		[
			0.18,
			{
				"gp": -0.5, "p": 0.34, "y": -0.3, "lift": 0.08, "sq": 0.12, "legs": [0.16, -0.3, 0.14, -0.28],
				"lw": 1.0, "fl": Vector3(-0.04, 0.22, -0.12), "hw": 1.0, "fr": Vector3(0.06, 0.24, -0.1), "rw": 1.0
			}
		]]},
	# ... released: the right palm thrust out flat, stretched on the release (0.05), then the recoil
	# throws her back and up (0.15) and she drifts down to her hover
	"ostra_snap": {"keys": [
		[
			0.00,
			{
				"gp": -0.5, "p": 0.34, "y": -0.3, "lift": 0.08, "sq": 0.12, "fl": Vector3(-0.04, 0.22, -0.12),
				"hw": 1.0, "fr": Vector3(0.06, 0.24, -0.1), "rw": 1.0
			}
		],
		[
			0.05,
			{
				"gp": 0.1, "p": -0.5, "y": 0.4, "sq": -0.16, "fr": Vector3(0.0, 0.18, -0.95), "rw": 1.0,
				"fl": Vector3(-0.35, 0.05, 0.25), "hw": 1.0
			}
		],
		[
			0.15,
			{
				"gp": 0.8, "p": 0.28, "y": 0.25, "lift": 0.16, "sq": 0.06, "fr": Vector3(0.0, 0.3, -0.7), "rw": 1.0,
				"fl": Vector3(-0.35, 0.1, 0.25), "hw": 0.8
			}
		],
		[0.50, {}]]},
	# holding Shift: the lantern hand down and back, ready to lob underhand (it holds)
	"ostra_swap_aim": {"hold": true, "keys": [
		[0.00, {}],
		[
			0.16,
			{
				"gp": -0.7, "p": 0.12, "y": -0.25, "sq": 0.1, "legs": [0.2, -0.4, 0.15, -0.3], "lw": 1.0,
				"fr": Vector3(0.28, -0.42, 0.28), "rw": 1.0, "fl": Vector3(-0.25, 0.15, -0.2), "hw": 0.7
			}
		]]},
	# the lob: from low behind, the hand sweeps up and out high (0.14, it leaves), the body rising with
	# it on its toes, a floaty follow-through
	"ostra_swap": {"keys": [
		[0.00, {"gp": -0.7, "p": 0.12, "y": -0.25, "sq": 0.1, "fr": Vector3(0.28, -0.42, 0.28), "rw": 1.0}],
		[0.06, {"gp": -0.9, "p": -0.18, "sq": 0.18, "lift": -0.04, "fr": Vector3(0.24, -0.5, 0.12), "rw": 1.0}],
		[
			0.14,
			{
				"gp": 1.3, "p": 0.35, "sq": -0.2, "lift": 0.22, "fr": Vector3(0.1, 0.95, -0.55), "rw": 1.0,
				"fl": Vector3(-0.35, 0.1, -0.05), "hw": 0.9
			}
		],
		[0.40, {"gp": 0.8, "p": 0.2, "lift": 0.14, "fr": Vector3(0.1, 0.6, -0.45), "rw": 0.7}],
		[0.85, {}]]},
	# arriving: stretched as she appears, a soft squash on the spot with the arms thrown wide, settle
	"ostra_arrive": {"keys": [
		[
			0.00,
			{
				"gp": 0.6, "lift": 0.3, "sq": -0.25, "fl": Vector3(-0.1, 0.6, 0.0), "hw": 1.0,
				"fr": Vector3(0.1, 0.6, 0.0), "rw": 1.0
			}
		],
		[
			0.10,
			{
				"gp": -0.5, "lift": -0.08, "sq": 0.32, "p": -0.2, "legs": [0.5, -0.9, 0.45, -0.85], "lw": 1.0,
				"fl": Vector3(-0.6, 0.1, 0.0), "hw": 1.0, "fr": Vector3(0.6, 0.1, 0.0), "rw": 1.0
			}
		],
		[
			0.25,
			{
				"gp": 0.2, "lift": 0.05, "sq": -0.06, "fl": Vector3(-0.45, 0.15, 0.0), "hw": 0.7,
				"fr": Vector3(0.45, 0.15, 0.0), "rw": 0.7
			}
		],
		[0.55, {}]]},
	# Brimseed: the hand raised with the seed (0.08), then the palm turned down and opened over the spot
	"ostra_seed": {"keys": [
		[0.00, {}],
		[0.08, {"gp": 0.9, "p": 0.15, "lift": 0.08, "fr": Vector3(0.12, 0.55, -0.2), "rw": 1.0}],
		[
			0.20,
			{
				"gp": -0.7, "p": -0.35, "sq": 0.14, "fr": Vector3(0.1, -0.1, -0.7), "rw": 1.0,
				"fl": Vector3(-0.3, 0.1, 0.1), "hw": 0.6
			}
		],
		[0.50, {"gp": -0.3, "p": -0.1, "fr": Vector3(0.1, 0.0, -0.45), "rw": 0.6}],
		[0.80, {}]]},
	# the pop: both fists clenched in to the chest (the implosion, 0.08), then flung open wide (0.2)
	"ostra_pop": {"keys": [
		[0.00, {}],
		[
			0.08,
			{
				"gp": -0.5, "p": 0.25, "sq": 0.22, "lift": -0.04, "fl": Vector3(-0.05, 0.2, -0.12), "hw": 1.0,
				"fr": Vector3(0.05, 0.2, -0.12), "rw": 1.0
			}
		],
		[
			0.20,
			{
				"gp": 0.9, "p": -0.2, "sq": -0.15, "lift": 0.12, "fl": Vector3(-0.7, 0.35, -0.1), "hw": 1.0,
				"fr": Vector3(0.7, 0.35, -0.1), "rw": 1.0
			}
		],
		[0.60, {}]]},
	# Swollen: lifted off the ground, arms flung up and wide, one full turn in the air, then down
	"ostra_empower": {"keys": [
		[0.00, {}],
		[
			0.10,
			{
				"gp": -0.4, "sq": 0.2, "lift": -0.05, "fl": Vector3(-0.2, -0.2, 0.0), "hw": 1.0,
				"fr": Vector3(0.2, -0.2, 0.0), "rw": 1.0
			}
		],
		[
			0.30,
			{
				"gp": 1.2, "sq": -0.22, "lift": 0.45, "fy": 3.14, "fl": Vector3(-0.55, 0.85, 0.0), "hw": 1.0,
				"fr": Vector3(0.55, 0.85, 0.0), "rw": 1.0
			}
		],
		[
			0.55,
			{
				"gp": 1.0, "sq": -0.1, "lift": 0.35, "fy": 6.28, "fl": Vector3(-0.5, 0.7, 0.0), "hw": 1.0,
				"fr": Vector3(0.5, 0.7, 0.0), "rw": 1.0
			}
		],
		[0.65, {"gp": 0.4, "lift": 0.2, "fy": 6.28}],
		[0.90, {"fy": 6.28}]]},
}
