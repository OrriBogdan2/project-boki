class_name KMovesStone
extends RefCounted
## Keyed full-body moves of Tarek (dolm) and Ostra (same format and channels as HunterAnim.KMOVES; looked
## up by HunterAnim.km_sample after its own table). Timed to the reference sheets' beats: anticipation,
## the release key on the kit's hit frame, an overshoot, then the settle. Tarek is heavy and grounded
## (deep knees, squash on every impact, the huge fists leading); Ostra floats (lifts, stretches and a
## spin on her Swell, light hands).

const MOVES := {
	# ---------------------------------------------------------------- Tarek
	# Basalt Spine held: sunk wide and low, both fists spread out to the sides at the ground, the body
	# turned along the ridge being dragged (it holds while X is down)
	"breah_spine_aim": {"hold": true, "keys": [
		[0.00, {}],
		[
			0.12,
			{
				"p": -0.3, "sq": 0.2, "lift": -0.1, "legs": [0.7, -1.3, 0.65, -1.2], "lw": 1.0,
				"fl": Vector3(-0.7, -0.3, 0.05), "hw": 1.0, "fr": Vector3(0.7, -0.3, 0.05), "rw": 1.0
			}
		]]},
	# Basalt Spine let go: the fists swing up (0.05) and are driven into the ground (0.1, the cracks), she
	# stays down through the 0.2s cracks and the 0.4s rise, then heaves up as the ridge stands (0.7)
	"breah_spine": {"keys": [
		[
			0.00,
			{
				"p": -0.3, "sq": 0.2, "lift": -0.1, "legs": [0.7, -1.3, 0.65, -1.2], "lw": 1.0,
				"fl": Vector3(-0.7, -0.3, 0.05), "hw": 1.0, "fr": Vector3(0.7, -0.3, 0.05), "rw": 1.0
			}
		],
		[
			0.05,
			{
				"p": 0.3, "lift": 0.18, "sq": -0.2, "legs": [0.5, -1.0, 0.45, -0.9], "lw": 1.0,
				"fl": Vector3(-0.2, 1.0, 0.0), "hw": 1.0, "fr": Vector3(0.2, 1.0, 0.0), "rw": 1.0
			}
		],
		[
			0.10,
			{
				"p": -0.85, "lift": -0.14, "sq": 0.5, "legs": [0.9, -1.5, 0.8, -1.4], "lw": 1.0,
				"fl": Vector3(-0.3, -0.72, -0.45), "hw": 1.0, "fr": Vector3(0.3, -0.72, -0.45), "rw": 1.0
			}
		],
		[
			0.55,
			{
				"p": -0.75, "lift": -0.12, "sq": 0.36, "legs": [0.85, -1.45, 0.75, -1.35], "lw": 1.0,
				"fl": Vector3(-0.32, -0.66, -0.42), "hw": 1.0, "fr": Vector3(0.32, -0.66, -0.42), "rw": 1.0
			}
		],
		[
			0.70,
			{
				"p": 0.25, "lift": 0.1, "sq": -0.18, "legs": [0.3, -0.6, 0.25, -0.5], "lw": 1.0,
				"fl": Vector3(-0.5, 0.7, -0.1), "hw": 1.0, "fr": Vector3(0.5, 0.7, -0.1), "rw": 1.0
			}
		],
		[1.00, {}]]},
	# Boulder (tap): a side hurl. Twisted far away with the right fist cocked back and out (0.07), the hips
	# whip round and the arm flings it out long (0.13), the fist follows through across her body (0.24)
	"breah_throw": {"keys": [
		[0.00, {}],
		[
			0.07,
			{
				"p": 0.15, "y": 0.65, "sq": 0.22, "lift": -0.06, "legs": [0.45, -0.8, 0.3, -0.6], "lw": 1.0,
				"fr": Vector3(0.5, 0.05, 0.38), "rw": 1.0, "fl": Vector3(-0.3, 0.2, -0.38), "hw": 1.0
			}
		],
		[
			0.13,
			{
				"p": -0.38, "y": -0.6, "sq": -0.16, "lift": 0.04, "legs": [0.7, -1.0, 0.1, -0.3], "lw": 1.0,
				"fr": Vector3(0.05, 0.25, -0.88), "rw": 1.0, "fl": Vector3(-0.4, -0.05, 0.28), "hw": 1.0
			}
		],
		[
			0.24,
			{
				"p": -0.3, "y": -0.75, "sq": 0.06, "legs": [0.7, -1.0, 0.15, -0.35], "lw": 1.0,
				"fr": Vector3(-0.28, 0.0, -0.66), "rw": 1.0, "fl": Vector3(-0.4, -0.1, 0.2), "hw": 0.8
			}
		],
		[0.55, {}]]},
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
	# Quakefall let go (the hop is a real 0.6s arc, the slam lands with him, owner item 61): from the gathered
	# crouch he drives up off both legs with the fists swinging back (0.05), arches at the top with both fists
	# high behind his head (0.3), whips them over and down as he drops (0.5), smashes them into the ground on
	# landing (0.6: flat squash, knees wide), rebounds a little in the crater (0.7), stays low over his
	# fists while the dust settles (0.88) and heaves himself up (1.12-1.36)
	"breah_slam": {"keys": [
		[
			0.00,
			{
				"p": -0.38, "sq": 0.28, "lift": -0.16, "legs": [0.95, -1.6, 0.85, -1.5], "lw": 1.0,
				"fl": Vector3(-0.34, -0.26, 0.08), "hw": 1.0, "fr": Vector3(0.34, -0.26, 0.08), "rw": 1.0
			}
		],
		[
			0.05,
			{
				"p": -0.1, "sq": -0.22, "lift": 0.04, "legs": [0.2, -0.3, 0.15, -0.25], "lw": 1.0,
				"fl": Vector3(-0.3, 0.1, 0.4), "hw": 1.0, "fr": Vector3(0.3, 0.1, 0.4), "rw": 1.0
			}
		],
		[
			0.30,
			{
				"p": 0.4, "sq": -0.26, "lift": 0.1, "legs": [0.75, -1.35, 0.65, -1.2], "lw": 1.0,
				"fl": Vector3(-0.2, 1.08, 0.24), "hw": 1.0, "fr": Vector3(0.2, 1.08, 0.24), "rw": 1.0
			}
		],
		[
			0.50,
			{
				"p": -0.35, "sq": -0.12, "legs": [0.45, -0.7, 0.4, -0.65], "lw": 1.0,
				"fl": Vector3(-0.18, 0.55, -0.45), "hw": 1.0, "fr": Vector3(0.18, 0.55, -0.45), "rw": 1.0
			}
		],
		[
			0.60,
			{
				"p": -0.88, "lift": -0.16, "sq": 0.52, "legs": [0.95, -1.55, 0.85, -1.45], "lw": 1.0,
				"fl": Vector3(-0.2, -0.72, -0.52), "hw": 1.0, "fr": Vector3(0.2, -0.72, -0.52), "rw": 1.0
			}
		],
		[
			0.70,
			{
				"p": -0.74, "lift": -0.08, "sq": 0.3, "legs": [0.85, -1.4, 0.75, -1.3], "lw": 1.0,
				"fl": Vector3(-0.2, -0.62, -0.5), "hw": 1.0, "fr": Vector3(0.2, -0.62, -0.5), "rw": 1.0
			}
		],
		[
			0.88,
			{
				"p": -0.62, "lift": -0.1, "sq": 0.24, "legs": [0.8, -1.35, 0.7, -1.25], "lw": 1.0,
				"fl": Vector3(-0.2, -0.6, -0.48), "hw": 1.0, "fr": Vector3(0.2, -0.6, -0.48), "rw": 1.0
			}
		],
		[
			1.12,
			{
				"p": -0.22, "sq": 0.06, "fl": Vector3(-0.24, -0.2, -0.3), "hw": 0.6, "fr": Vector3(0.24, -0.2, -0.3),
				"rw": 0.6
			}
		],
		[1.36, {}]]},
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
	# the punch during a charge: the whole body drives forward off the back foot, both fists thrown out long
	# (0.05), the follow-through stretched past the line (0.16), then back down into the gathered crouch
	"breah_lunge": {"keys": [
		[0.00, {"p": -0.38, "sq": 0.2, "legs": [0.9, -1.5, 0.8, -1.4], "lw": 1.0}],
		[
			0.05,
			{
				"p": -0.85, "y": -0.3, "sq": -0.24, "lift": 0.05, "legs": [1.1, -0.5, -0.6, -0.2], "lw": 1.0,
				"fl": Vector3(-0.12, 0.1, -0.95), "hw": 1.0, "fr": Vector3(0.12, 0.1, -0.95), "rw": 1.0
			}
		],
		[
			0.16,
			{
				"p": -0.72, "y": -0.2, "sq": 0.12, "legs": [1.0, -0.9, -0.3, -0.5], "lw": 1.0,
				"fl": Vector3(-0.16, 0.0, -0.85), "hw": 1.0, "fr": Vector3(0.16, 0.0, -0.85), "rw": 1.0
			}
		],
		[
			0.36,
			{
				"p": -0.38, "sq": 0.24, "lift": -0.12, "legs": [0.9, -1.5, 0.8, -1.4], "lw": 1.0,
				"fl": Vector3(-0.34, -0.26, 0.08), "hw": 1.0, "fr": Vector3(0.34, -0.26, 0.08), "rw": 1.0
			}
		]]},
	# Rock Hop's hop (0.3s, a low fast arc): crouched on the rock (0), kicked off it long with the fists back
	# (0.06), knees tucked, arms out for balance (0.16), the feet reaching for the next rock (0.28)
	"breah_hop": {"keys": [
		[
			0.00,
			{
				"p": -0.3, "sq": 0.36, "lift": -0.14, "legs": [1.0, -1.6, 0.9, -1.5], "lw": 1.0,
				"fl": Vector3(-0.24, -0.5, -0.3), "hw": 1.0, "fr": Vector3(0.24, -0.5, -0.3), "rw": 1.0
			}
		],
		[
			0.06,
			{
				"p": -0.4, "sq": -0.3, "lift": 0.1, "legs": [-0.5, -0.2, 0.4, -0.6], "lw": 1.0,
				"fl": Vector3(-0.38, 0.1, -0.4), "hw": 1.0, "fr": Vector3(0.38, 0.1, -0.4), "rw": 1.0
			}
		],
		[
			0.16,
			{
				"p": 0.1, "sq": 0.08, "legs": [1.1, -1.7, 0.7, -1.2], "lw": 1.0,
				"fl": Vector3(-0.38, 0.3, 0.1), "hw": 1.0, "fr": Vector3(0.38, 0.3, 0.1), "rw": 1.0
			}
		],
		[
			0.28,
			{
				"p": -0.12, "sq": -0.08, "legs": [0.5, -0.7, 0.3, -0.5], "lw": 1.0,
				"fl": Vector3(-0.36, 0.2, 0.1), "hw": 1.0, "fr": Vector3(0.36, 0.2, 0.1), "rw": 1.0
			}
		]]},
	# Rock Hop's skid: a skater's low stance along the rock, front knee bent, back leg long, one arm out ahead and
	# one behind (0.08), held as he slides
	"breah_skate": {"keys": [
		[0.00, {"p": -0.1, "sq": 0.3, "lift": -0.12, "legs": [0.9, -1.2, -0.3, -0.5], "lw": 1.0}],
		[
			0.08,
			{
				"p": -0.3, "sq": 0.26, "lift": -0.14, "legs": [1.0, -1.4, -0.4, -0.4], "lw": 1.0,
				"fl": Vector3(-0.36, 0.1, 0.34), "hw": 1.0, "fr": Vector3(0.36, 0.2, -0.34), "rw": 1.0
			}
		],
		[
			0.3,
			{
				"p": -0.26, "sq": 0.22, "lift": -0.1, "legs": [0.9, -1.3, -0.3, -0.4], "lw": 1.0,
				"fl": Vector3(-0.36, 0.15, 0.34), "hw": 1.0, "fr": Vector3(0.36, 0.22, -0.34), "rw": 1.0
			}
		]]},
	# Rock Hop's crash: both fists smashed into the ground with a deep squash (0.05), held down through
	# the crash (0.25), then she heaves upright
	"breah_leap_land": {"keys": [
		[
			0.00,
			{
				"p": -0.25, "legs": [0.4, -0.5, 0.3, -0.45], "lw": 1.0, "fl": Vector3(-0.26, 0.75, -0.2), "hw": 1.0,
				"fr": Vector3(0.26, 0.75, -0.2), "rw": 1.0
			}
		],
		[
			0.05,
			{
				"p": -0.85, "sq": 0.55, "lift": -0.24, "legs": [1.0, -1.6, 0.9, -1.5], "lw": 1.0,
				"fl": Vector3(-0.3, -0.85, -0.45), "hw": 1.0, "fr": Vector3(0.3, -0.85, -0.45), "rw": 1.0
			}
		],
		[
			0.25,
			{
				"p": -0.7, "sq": 0.35, "lift": -0.16, "legs": [0.95, -1.5, 0.85, -1.4], "lw": 1.0,
				"fl": Vector3(-0.3, -0.75, -0.42), "hw": 1.0, "fr": Vector3(0.3, -0.75, -0.42), "rw": 1.0
			}
		],
		[
			0.50,
			{
				"p": -0.15, "sq": 0.08, "fl": Vector3(-0.3, -0.3, -0.3), "hw": 0.5, "fr": Vector3(0.3, -0.3, -0.3),
				"rw": 0.5
			}
		],
		[0.75, {}]]},
	# her air dash (the class long dash, 0.23s): the source's shove, taken into the air: a quick gather with
	# the fists in at the chest (0.03), then a shoulder-first barge, the lead shoulder dropped and turned in,
	# the lead fist driven out low, the rear one guarding the chest, the legs trailing (0.08), held through
	# the push (0.18), and braced with the knees coming up to land as it ends (0.23)
	"breah_exdash": {"keys": [
		[0.00, {}],
		[
			0.03,
			{
				"p": 0.12, "sq": 0.22, "lift": -0.04, "legs": [0.6, -1.0, 0.5, -0.9], "lw": 1.0,
				"fl": Vector3(-0.18, 0.35, -0.15), "hw": 1.0, "fr": Vector3(0.18, 0.35, -0.15), "rw": 1.0
			}
		],
		[
			0.08,
			{
				"p": -0.72, "y": -0.5, "sq": -0.16, "legs": [-0.3, -0.2, -0.7, -0.4], "lw": 1.0,
				"fl": Vector3(-0.08, 0.0, -0.85), "hw": 1.0, "fr": Vector3(0.24, 0.38, -0.25), "rw": 1.0
			}
		],
		[
			0.18,
			{
				"p": -0.64, "y": -0.45, "sq": -0.1, "legs": [-0.2, -0.3, -0.6, -0.5], "lw": 1.0,
				"fl": Vector3(-0.1, 0.05, -0.8), "hw": 1.0, "fr": Vector3(0.24, 0.36, -0.22), "rw": 1.0
			}
		],
		[
			0.23,
			{
				"p": -0.25, "y": -0.15, "sq": 0.16, "legs": [0.8, -1.3, 0.7, -1.2], "lw": 1.0,
				"fl": Vector3(-0.22, 0.1, -0.45), "hw": 0.8, "fr": Vector3(0.22, 0.15, -0.35), "rw": 0.8
			}
		]]},
	# Stone Row: reared back with both fists high overhead (0.06), slammed down into the ground on the tell
	# with a deep squash (0.18, the fists travel 1.6m), held down through it, then heaved up and out as the
	# rocks rise (0.36), a proud settle
	"breah_raise": {"keys": [
		[0.00, {}],
		[
			0.06,
			{
				"p": 0.35, "sq": -0.16, "lift": 0.12, "legs": [-0.9, 1.0, 0.25, -0.35], "lw": 1.0,
				"fl": Vector3(-0.25, 0.78, 0.05), "hw": 1.0, "fr": Vector3(0.25, 0.78, 0.05), "rw": 1.0
			}
		],
		[
			0.18,
			{
				"p": -0.8, "sq": 0.48, "lift": -0.22, "legs": [0.95, -1.55, 0.85, -1.45], "lw": 1.0,
				"fl": Vector3(-0.26, -0.86, -0.5), "hw": 1.0, "fr": Vector3(0.26, -0.86, -0.5), "rw": 1.0
			}
		],
		[
			0.26,
			{
				"p": -0.7, "sq": 0.4, "lift": -0.18, "legs": [0.9, -1.5, 0.8, -1.4], "lw": 1.0,
				"fl": Vector3(-0.28, -0.8, -0.48), "hw": 1.0, "fr": Vector3(0.28, -0.8, -0.48), "rw": 1.0
			}
		],
		[
			0.38,
			{
				"p": 0.3, "sq": -0.2, "lift": 0.15, "legs": [0.3, -0.5, 0.25, -0.45], "lw": 1.0,
				"fl": Vector3(-0.45, 0.82, -0.3), "hw": 1.0, "fr": Vector3(0.45, 0.82, -0.3), "rw": 1.0
			}
		],
		[
			0.60,
			{
				"p": 0.1, "sq": 0.05, "fl": Vector3(-0.35, 0.45, -0.3), "hw": 0.6, "fr": Vector3(0.35, 0.45, -0.3),
				"rw": 0.6
			}
		],
		[0.95, {}]]},
	# Tremor Sense finding someone: sunk into a deep crouch, one palm flat on the ground, the head and
	# shoulders cocked toward the feeling, the other fist up on guard
	"breah_sense": {"keys": [
		[0.00, {}],
		[
			0.12,
			{
				"r": 0.18, "p": -0.38, "y": 0.25, "sq": 0.35, "lift": -0.2, "legs": [0.95, -1.6, 0.7, -1.3],
				"lw": 1.0, "fr": Vector3(0.22, -0.8, -0.32), "rw": 1.0, "fl": Vector3(-0.3, 0.15, -0.35), "hw": 0.8
			}
		],
		[
			0.45,
			{
				"r": 0.15, "p": -0.34, "y": 0.3, "sq": 0.32, "lift": -0.18, "legs": [0.9, -1.5, 0.7, -1.3],
				"lw": 1.0, "fr": Vector3(0.22, -0.78, -0.3), "rw": 1.0, "fl": Vector3(-0.3, 0.15, -0.35), "hw": 0.8
			}
		],
		[0.75, {}]]},
	# ---------------------------------------------------------------- Ostra
	# an orb: a flick of the casting hand from the shoulder
	"ostra_orb": {"keys": [
		[0.00, {}],
		[0.04, {"gp": 0.25, "y": -0.2, "fr": Vector3(0.2, 0.25, 0.15), "rw": 1.0}],
		[0.09, {"gp": -0.15, "y": 0.25, "p": -0.12, "fr": Vector3(0.05, 0.22, -0.62), "rw": 1.0}],
		[0.30, {}]]},
	# the full-charge orb: drawn back, then the arm flung out straight and the body kicked back by it
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
	# item 136's RMB (the kit plays it on the press): eight cards dealt from the raised left hand by the right
	"ostra_flurry": {"keys": [
		[0.00, {}],
		[0.05, {"p": -0.1, "fr": Vector3(0.2, 0.25, -0.5), "rw": 1.0, "fl": Vector3(-0.2, 0.25, -0.35), "hw": 1.0}],
		[0.66, {"p": -0.1, "fr": Vector3(0.2, 0.25, -0.5), "rw": 1.0, "fl": Vector3(-0.2, 0.25, -0.35), "hw": 1.0}],
		[0.90, {}]]},
	# the Snap's wind-up (0.32s, it holds): she sinks and draws both hands in round the dark orb as it forms
	# (0.12), then coils, rising and leaning far back with the orb cupped at the chest (0.30, loaded)
	"ostra_snap_wind": {"hold": true, "keys": [
		[0.00, {}],
		[
			0.12,
			{
				"gp": -0.4, "p": 0.12, "y": -0.2, "lift": -0.03, "sq": 0.14, "fl": Vector3(-0.3, 0.12, -0.3),
				"hw": 1.0, "fr": Vector3(0.3, 0.12, -0.3), "rw": 1.0
			}
		],
		[
			0.30,
			{
				"gp": -0.7, "p": 0.5, "y": -0.65, "lift": 0.14, "sq": -0.1, "legs": [0.2, -0.35, 0.16, -0.3],
				"lw": 1.0, "fl": Vector3(-0.12, 0.3, -0.18), "hw": 1.0, "fr": Vector3(0.12, 0.32, -0.16), "rw": 1.0
			}
		]]},
	# ... released (the hit frame is the release): both palms shoved out flat as she pitches forward into it,
	# stretched long (0.05); the bundle's kick throws her back and up (0.16); she floats down to her hover
	"ostra_snap": {"keys": [
		[
			0.00,
			{
				"gp": -0.7, "p": 0.5, "y": -0.65, "lift": 0.14, "sq": -0.1, "fl": Vector3(-0.12, 0.3, -0.18),
				"hw": 1.0, "fr": Vector3(0.12, 0.32, -0.16), "rw": 1.0
			}
		],
		[
			0.05,
			{
				"gp": 0.2, "p": -0.6, "y": 0.45, "lift": 0.02, "sq": -0.22, "fr": Vector3(0.1, 0.2, -1.0),
				"rw": 1.0, "fl": Vector3(-0.1, 0.18, -0.95), "hw": 1.0
			}
		],
		[
			0.16,
			{
				"gp": 0.8, "p": 0.3, "y": 0.15, "lift": 0.18, "sq": 0.1, "fr": Vector3(0.05, 0.3, -0.7),
				"rw": 0.9, "fl": Vector3(-0.3, 0.1, -0.4), "hw": 0.7
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
	# the lob from the air (her air dash): the crook hand swung across her body low (0.08), then slung up and over
	# in a wide arc as she stretches (0.18, it leaves); she settles into a drift, leaning into it with the hands
	# and legs trailing back under the streaming hem, swaying gently side to side (a loop from 0.45) until she
	# arrives (no tumble)
	"ostra_swap_air": {"hold": true, "loop": 0.45, "keys": [
		[0.00, {}],
		[
			0.08,
			{
				"gp": -0.5, "y": 0.45, "lift": 0.04, "sq": 0.12, "fr": Vector3(-0.25, -0.1, -0.2), "rw": 1.0,
				"fl": Vector3(-0.3, 0.1, 0.2), "hw": 0.8
			}
		],
		[
			0.18,
			{
				"gp": 1.2, "y": -0.35, "lift": 0.16, "sq": -0.2, "fr": Vector3(0.2, 0.9, -0.35), "rw": 1.0,
				"fl": Vector3(-0.45, 0.2, 0.25), "hw": 0.9
			}
		],
		[
			0.45,
			{
				"gp": 0.2, "p": -0.3, "fx": 0.22, "r": 0.08, "lift": 0.1, "sq": -0.08,
				"legs": [-0.45, 0.3, -0.38, 0.25], "lw": 1.0, "fl": Vector3(-0.45, -0.1, 0.35), "hw": 0.9,
				"fr": Vector3(0.45, -0.1, 0.35), "rw": 0.9
			}
		],
		[
			0.85,
			{
				"gp": 0.25, "p": -0.26, "fx": 0.2, "r": -0.08, "lift": 0.14, "sq": -0.06,
				"legs": [-0.4, 0.26, -0.44, 0.3], "lw": 1.0, "fl": Vector3(-0.42, -0.06, 0.38), "hw": 0.9,
				"fr": Vector3(0.48, -0.12, 0.32), "rw": 0.9
			}
		],
		[
			1.25,
			{
				"gp": 0.2, "p": -0.3, "fx": 0.22, "r": 0.08, "lift": 0.1, "sq": -0.08,
				"legs": [-0.45, 0.3, -0.38, 0.25], "lw": 1.0, "fl": Vector3(-0.45, -0.1, 0.35), "hw": 0.9,
				"fr": Vector3(0.45, -0.1, 0.35), "rw": 0.9
			}
		]]},
	# arriving: she pops into being stretched tall with her arms up (0.0), squashes hard as she settles into
	# the spot with the arms and hem flung wide (0.08), overshoots tall again (0.15, the pop) and floats down
	"ostra_arrive": {"keys": [
		[
			0.00,
			{
				"gp": 0.6, "lift": 0.35, "sq": -0.4, "fl": Vector3(-0.12, 0.62, 0.0), "hw": 1.0,
				"fr": Vector3(0.12, 0.62, 0.0), "rw": 1.0
			}
		],
		[
			0.08,
			{
				"gp": -0.5, "lift": -0.1, "sq": 0.32, "p": -0.25, "legs": [0.5, -0.9, 0.45, -0.85], "lw": 1.0,
				"fl": Vector3(-0.66, 0.08, 0.05), "hw": 1.0, "fr": Vector3(0.66, 0.08, 0.05), "rw": 1.0
			}
		],
		[
			0.15,
			{
				"gp": 0.3, "lift": 0.14, "sq": -0.16, "p": 0.1, "fl": Vector3(-0.5, 0.3, 0.0), "hw": 0.9,
				"fr": Vector3(0.5, 0.3, 0.0), "rw": 0.9
			}
		],
		[
			0.30,
			{
				"lift": 0.02, "sq": 0.06, "fl": Vector3(-0.4, 0.12, 0.0), "hw": 0.6, "fr": Vector3(0.4, 0.12, 0.0),
				"rw": 0.6
			}
		],
		[0.60, {}]]},
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
	# Nightwell, a committed cast (she is locked in it while the dome fills): she sinks with the hands crossed
	# low (0.10), then rises tall and flings both arms out wide and high, the crook raised (0.25, the commit); she holds
	# that spread pose while the dome fills
	"ostra_well": {"hold": true, "keys": [
		[0.00, {}],
		[
			0.10,
			{
				"gp": -0.6, "p": 0.15, "lift": -0.04, "sq": 0.16, "fl": Vector3(0.15, -0.2, -0.3), "hw": 1.0,
				"fr": Vector3(-0.15, -0.2, -0.3), "rw": 1.0
			}
		],
		[
			0.25,
			{
				"gp": 1.0, "p": -0.12, "lift": 0.45, "sq": -0.25,
				"fl": Vector3(-0.85, 0.7, 0.1), "hw": 1.0, "fr": Vector3(0.85, 0.7, 0.1), "rw": 1.0
			}
		]]},
	# the well opens and frees her: the spread hands clench and haul in to the chest (0.08), she hunches over
	# the pull (0.22), then flings the hands down and away to let it run on its own (0.36) and floats upright,
	# free to move (0.55)
	"ostra_well_snap": {"keys": [
		[
			0.00,
			{
				"gp": 1.0, "p": -0.12, "lift": 0.45, "sq": -0.25, "fl": Vector3(-0.85, 0.7, 0.1), "hw": 1.0,
				"fr": Vector3(0.85, 0.7, 0.1), "rw": 1.0
			}
		],
		[
			0.08,
			{
				"gp": -0.1, "p": -0.4, "lift": 0.1, "sq": 0.22, "fl": Vector3(-0.2, 0.35, -0.42), "hw": 1.0,
				"fr": Vector3(0.2, 0.35, -0.42), "rw": 1.0
			}
		],
		[
			0.22,
			{
				"gp": 0.0, "p": -0.3, "lift": 0.16, "sq": 0.12, "fl": Vector3(-0.3, 0.3, -0.52), "hw": 1.0,
				"fr": Vector3(0.3, 0.3, -0.52), "rw": 1.0
			}
		],
		[
			0.36,
			{
				"gp": 0.4, "p": 0.1, "lift": 0.05, "sq": -0.08, "fl": Vector3(-0.5, -0.3, 0.25), "hw": 1.0,
				"fr": Vector3(0.5, -0.3, 0.25), "rw": 1.0
			}
		],
		[0.55, {}]]},
	# she is knocked or stunned out of the cast (or merges): the hands let go and drop, and she floats back down
	"ostra_well_end": {"keys": [
		[
			0.00,
			{
				"gp": 1.0, "p": -0.12, "lift": 0.45, "sq": -0.25, "fl": Vector3(-0.85, 0.7, 0.1), "hw": 1.0,
				"fr": Vector3(0.85, 0.7, 0.1), "rw": 1.0
			}
		],
		[0.35, {}]]},
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

# ---------------------------------------------------------------- locomotion (HunterAnim asks per frame)
## m (the model's: a hand's width): Motley's box floats this high over its ground point (visual only: the hitbox and
## ring stay on the ground)
const HOVER_H := 0.15
const HOVER_BOB := 0.015               # m, up and down
const HOVER_HZ := 0.6                  # bobs a second
const HOVER_GAIT := 0.1                # no legs walk: no footstep sounds (gait < 0.5 never steps)

## How much a hero's legs walk (1: a full step cycle).
static func gait(arch: String) -> float:
	return HOVER_GAIT if arch == "ostra" else 1.0

## How high a hero's body floats over its feet at time `t` (s), with a slow bob.
static func hover(arch: String, t: float) -> float:
	if arch != "ostra":
		return 0.0
	return HOVER_H + sin(t * TAU * HOVER_HZ) * HOVER_BOB
