class_name KMovesCare
extends RefCounted
## Keyed full-body moves of Moosh Moosh (tender, "mm_") and Tamsin (rimewright, "tm_"): same format and
## channels as HunterAnim.KMOVES, looked up by HunterAnim.km_sample. Timed to the reference sheets'
## beats (docs/heroes/tender.md, rimewright.md: Animation moves): anticipation, the release on the
## kit's hit time, an overshoot past the key pose, then the settle. Channels used here besides the
## body ones: fl / fr (a free hand from its shoulder, x right, y up, z back), hw / rw their weights,
## wa (the held fan's extra pitch, yaw, roll about its grip), wo (its offset, m) and wf (how far the
## fan turns with the torso instead of staying on the aim). Moosh Moosh holds nothing: both hands are
## hers to cast from, so her moves key fl and fr.
## A move whose first and last keys match can loop: the kit replays it (the skate stride).

const MOVES := {
	# ================================================================ Moosh Moosh
	# Ember Cast, right hand (every 0.4 s, alternating): the fist pulled back to the hip with the torso
	# twisted away, then a straight-arm punch-push at the cursor with the torso unwound ~45 deg past
	# square and the stance dropped; held out 0.1 s, then the left hand rises open for the next one
	"mm_shot_r": {"keys": [
		[0.0, {}],
		[
				0.04,
				{
					"y": -0.6, "fy": -0.35, "p": 0.12, "sq": 0.1, "fr": Vector3(0.1, -0.3, 0.3), "rw": 1.0,
					"fl": Vector3(-0.1, 0.05, -0.35), "hw": 0.8, "lw": 0.6, "legs": [-0.2, -0.4, 0.3, -0.6]}],
		[
				0.08,
				{
					"y": 0.8, "fy": 0.55, "p": -0.3, "sq": -0.12, "lift": -0.06,
					"fr": Vector3(-0.1, 0.12, -0.62), "rw": 1.0,
					"fl": Vector3(-0.28, -0.05, 0.3), "hw": 1.0, "lw": 0.9, "legs": [0.75, -1.0, -0.45, -0.25]}],
		[
				0.18,
				{
					"y": 0.7, "fy": 0.45, "p": -0.25, "lift": -0.05, "fr": Vector3(-0.08, 0.1, -0.6), "rw": 1.0,
					"fl": Vector3(-0.26, -0.03, 0.26), "hw": 0.9, "lw": 0.8, "legs": [0.65, -0.95, -0.4, -0.25]}],
		[
				0.3,
				{
					"y": 0.3, "p": -0.08, "fr": Vector3(0.12, -0.12, -0.3), "rw": 0.6,
					"fl": Vector3(-0.06, 0.25, -0.25), "hw": 1.0}],
		[0.42, {}]]},
	# ... the left hand (the same beats, mirrored)
	"mm_shot_l": {"keys": [
		[0.0, {}],
		[
				0.04,
				{
					"y": 0.6, "fy": 0.35, "p": 0.12, "sq": 0.1, "fl": Vector3(-0.1, -0.3, 0.3), "hw": 1.0,
					"fr": Vector3(0.1, 0.05, -0.35), "rw": 0.8, "lw": 0.6, "legs": [0.3, -0.6, -0.2, -0.4]}],
		[
				0.08,
				{
					"y": -0.8, "fy": -0.55, "p": -0.3, "sq": -0.12, "lift": -0.06,
					"fl": Vector3(0.1, 0.12, -0.62), "hw": 1.0,
					"fr": Vector3(0.28, -0.05, 0.3), "rw": 1.0, "lw": 0.9, "legs": [-0.45, -0.25, 0.75, -1.0]}],
		[
				0.18,
				{
					"y": -0.7, "fy": -0.45, "p": -0.25, "lift": -0.05, "fl": Vector3(0.08, 0.1, -0.6), "hw": 1.0,
					"fr": Vector3(0.26, -0.03, 0.26), "rw": 0.9, "lw": 0.8, "legs": [-0.4, -0.25, 0.65, -0.95]}],
		[
				0.3,
				{
					"y": -0.3, "p": -0.08, "fl": Vector3(-0.12, -0.12, -0.3), "hw": 0.6,
					"fr": Vector3(0.06, 0.25, -0.25), "rw": 1.0}],
		[0.42, {}]]},
	# the Empowered ember after a pause: a deep coil with both hands back, then up on the toes with a
	# two-handed push and the free arm flung back past it, held, then down
	"mm_shot_emp": {"keys": [
		[0.0, {}],
		[
				0.09,
				{
					"y": -0.7, "p": 0.18, "sq": 0.22, "lift": -0.08, "fr": Vector3(0.1, -0.28, 0.28), "rw": 1.0,
					"fl": Vector3(-0.2, -0.2, 0.25), "hw": 1.0, "lw": 1.0, "legs": [0.6, -1.0, 0.5, -0.9]}],
		[
				0.14,
				{
					"y": 0.9, "p": -0.32, "sq": -0.3, "lift": 0.25, "fr": Vector3(-0.04, 0.1, -0.62), "rw": 1.0,
					"fl": Vector3(-0.38, 0.28, 0.4), "hw": 1.0, "lw": 1.0, "legs": [0.2, -0.2, -0.5, -0.1]}],
		[
				0.3,
				{
					"y": 0.7, "p": -0.25, "sq": -0.15, "lift": 0.18, "fr": Vector3(-0.02, 0.08, -0.6), "rw": 1.0,
					"fl": Vector3(-0.36, 0.25, 0.36), "hw": 1.0, "lw": 0.8, "legs": [0.15, -0.2, -0.45, -0.1]}],
		[0.55, {}]]},
	# Burrseed held: turned side-on (~70 deg), the casting fist pointed down the lane, the other hand
	# cupped up beside the ear, knees bent
	"mm_seed_aim": {"hold": true, "keys": [
		[0.0, {}],
		[
				0.12,
				{
					"y": 1.2, "p": 0.1, "r": 0.08, "sq": 0.12, "fr": Vector3(-0.42, 0.05, -0.4), "rw": 1.0,
					"fl": Vector3(0.02, 0.4, 0.12), "hw": 1.0, "lw": 0.8, "legs": [-0.3, -0.5, 0.45, -0.7]}]]},
	# ... let go: the coil deepens, then a small hop forward with a two-handed push, the flare round her
	"mm_seed": {"keys": [
		[
				0.0,
				{
					"y": 1.2, "p": 0.1, "r": 0.08, "sq": 0.12, "fr": Vector3(-0.42, 0.05, -0.4), "rw": 1.0,
					"fl": Vector3(0.02, 0.4, 0.12), "hw": 1.0, "lw": 0.8, "legs": [-0.3, -0.5, 0.45, -0.7]}],
		[
				0.05,
				{
					"y": 1.3, "p": 0.18, "sq": 0.3, "lift": -0.06, "fr": Vector3(-0.3, -0.1, -0.1), "rw": 1.0,
					"fl": Vector3(0.05, 0.3, 0.2), "hw": 1.0, "lw": 1.0, "legs": [0.6, -1.1, 0.55, -1.0]}],
		[
				0.12,
				{
					"y": 0.1, "p": -0.35, "sq": -0.25, "lift": 0.22, "fr": Vector3(-0.1, 0.1, -0.6), "rw": 1.0,
					"fl": Vector3(0.1, 0.1, -0.6), "hw": 1.0, "lw": 1.0, "legs": [0.9, -1.5, 0.7, -1.3]}],
		[
				0.32,
				{
					"y": 0.05, "p": -0.2, "sq": 0.18, "lift": 0.0, "fr": Vector3(-0.08, 0.05, -0.5), "rw": 0.9,
					"fl": Vector3(0.08, 0.05, -0.5), "hw": 0.9, "lw": 1.0, "legs": [0.6, -1.0, 0.5, -0.9]}],
		[0.55, {}]]},
	# Hearthlight lit: a deep crouch to gather the light, then both arms thrust straight up overhead
	# (the plus and the rising rays at 0.18), held, then down
	"mm_hearth": {"keys": [
		[0.0, {}],
		[
				0.08,
				{
					"p": -0.3, "lift": -0.16, "sq": 0.4, "fl": Vector3(0.12, -0.3, -0.2), "hw": 1.0,
					"fr": Vector3(-0.12, -0.3, -0.2), "rw": 1.0, "lw": 1.0, "legs": [0.9, -1.5, 0.8, -1.4]}],
		[
				0.18,
				{
					"p": 0.2, "lift": 0.12, "sq": -0.3, "fl": Vector3(0.04, 0.66, -0.02), "hw": 1.0,
					"fr": Vector3(-0.04, 0.66, -0.02), "rw": 1.0, "lw": 0.6, "legs": [-0.1, -0.15, 0.05, -0.2]}],
		[
				0.4,
				{
					"p": 0.16, "lift": 0.05, "sq": -0.1, "fl": Vector3(0.06, 0.6, -0.05), "hw": 1.0,
					"fr": Vector3(-0.06, 0.6, -0.05), "rw": 1.0}],
		[0.65, {}]]},
	# Hearthlight thrown: a quick wind low behind, then a one-handed underhand fling out at the cursor
	"mm_toss": {"keys": [
		[0.0, {}],
		[
				0.06,
				{
					"y": -0.6, "p": 0.12, "sq": 0.15, "fr": Vector3(0.12, -0.3, 0.3), "rw": 1.0,
					"fl": Vector3(-0.2, 0.05, -0.2), "hw": 0.8}],
		[
				0.12,
				{
					"y": 0.6, "p": -0.3, "sq": -0.2, "lift": 0.06, "fr": Vector3(-0.05, 0.35, -0.55), "rw": 1.0,
					"fl": Vector3(-0.3, 0.0, 0.25), "hw": 0.9, "lw": 0.6, "legs": [0.4, -0.6, -0.3, -0.2]}],
		[0.26, {"y": 0.4, "p": -0.2, "fr": Vector3(-0.02, 0.3, -0.5), "rw": 0.8}],
		[0.5, {}]]},
	# Relay Step (the base dash, 0.16 s): a crouch, a quick stretched hop with the knees tucked and the
	# arms swept back, a landing squash and a settle
	"mm_dash": {"keys": [
		[0.0, {"sq": 0.3, "lift": -0.06, "p": -0.15}],
		[
				0.05,
				{
					"sq": -0.45, "lift": 0.3, "p": -0.5, "lw": 1.0, "legs": [1.0, -1.6, 0.7, -1.2],
					"fl": Vector3(-0.2, 0.0, 0.4), "hw": 1.0, "fr": Vector3(0.2, 0.0, 0.4), "rw": 1.0}],
		[
				0.14,
				{
					"sq": -0.15, "lift": 0.18, "p": -0.35, "lw": 1.0, "legs": [0.7, -1.2, 0.5, -0.9],
					"fl": Vector3(-0.25, 0.05, 0.3), "hw": 0.8, "fr": Vector3(0.25, 0.05, 0.3), "rw": 0.8}],
		[0.2, {"sq": 0.45, "lift": -0.1, "p": -0.18, "lw": 1.0, "legs": [0.7, -1.1, 0.6, -1.0]}],
		[0.4, {}]]},
	# ... through a teammate: the same hop with a free-hand wave over them (the RELAY proc)
	"mm_relay": {"keys": [
		[0.0, {"sq": 0.3, "lift": -0.06, "p": -0.15}],
		[
				0.05,
				{
					"sq": -0.45, "lift": 0.34, "p": -0.42, "r": 0.18, "lw": 1.0, "legs": [1.0, -1.6, 0.7, -1.2],
					"fl": Vector3(-0.05, 0.62, 0.0), "hw": 1.0, "fr": Vector3(0.2, 0.0, 0.35), "rw": 1.0}],
		[
				0.14,
				{
					"sq": -0.15, "lift": 0.2, "p": -0.25, "r": -0.15, "lw": 1.0, "legs": [0.7, -1.2, 0.5, -0.9],
					"fl": Vector3(-0.3, 0.5, 0.1), "hw": 1.0}],
		[0.2, {"sq": 0.45, "lift": -0.1, "p": -0.18, "lw": 1.0, "legs": [0.7, -1.1, 0.6, -1.0]}],
		[0.45, {}]]},
	# the long air glide (0.8 s): a head-first streak with the arms reaching ahead and the legs trailing,
	# a seated float with the knees tucked and the arms out wide, then a soft touchdown
	"mm_dash_air": {"keys": [
		[0.0, {"sq": 0.15, "p": -0.2}],
		[
				0.08,
				{
					"fx": -1.15, "sq": -0.3, "lw": 1.0, "legs": [-0.35, -0.2, -0.45, -0.1],
					"fl": Vector3(0.06, 0.15, -0.55), "hw": 1.0, "fr": Vector3(-0.06, 0.15, -0.55), "rw": 1.0}],
		[
				0.24,
				{
					"fx": -1.1, "sq": -0.28, "lw": 1.0, "legs": [-0.3, -0.2, -0.4, -0.1],
					"fl": Vector3(0.04, 0.12, -0.55), "hw": 1.0, "fr": Vector3(-0.04, 0.12, -0.55), "rw": 1.0}],
		[
				0.4,
				{
					"fx": -0.1, "sq": 0.1, "lift": 0.05, "lw": 1.0, "legs": [1.4, -2.0, 1.3, -1.9],
					"fl": Vector3(-0.45, 0.05, -0.02), "hw": 1.0, "fr": Vector3(0.45, 0.05, -0.02), "rw": 1.0}],
		[
				0.72,
				{
					"fx": -0.05, "sq": 0.12, "lift": 0.05, "r": 0.06, "lw": 1.0, "legs": [1.3, -1.9, 1.2, -1.8],
					"fl": Vector3(-0.45, 0.12, 0.0), "hw": 1.0, "fr": Vector3(0.45, 0.12, 0.0), "rw": 1.0}],
		[
				0.86,
				{
					"sq": 0.12, "lw": 0.6, "legs": [0.4, -0.7, 0.3, -0.6],
					"fl": Vector3(-0.35, 0.2, -0.05), "hw": 0.8, "fr": Vector3(0.35, 0.2, -0.05), "rw": 0.8}],
		[1.0, {}]]},
	# Bearer: scooping a downed teammate up onto her back: a deep squat, then a heave with a lean back
	"mm_pickup": {"keys": [
		[0.0, {}],
		[
				0.12,
				{
					"p": -0.6, "lift": -0.2, "sq": 0.4, "lw": 1.0, "legs": [1.1, -1.7, 1.0, -1.6],
					"fl": Vector3(0.1, -0.5, -0.3), "hw": 1.0, "fr": Vector3(-0.1, -0.5, -0.3), "rw": 1.0}],
		[
				0.3,
				{
					"p": 0.3, "lift": 0.08, "sq": -0.25, "lw": 0.6, "legs": [0.2, -0.3, 0.1, -0.2],
					"fl": Vector3(-0.1, 0.35, 0.2), "hw": 1.0, "fr": Vector3(0.1, 0.35, 0.2), "rw": 1.0}],
		[0.55, {}]]},
	# the Hearthlight flare (payoff): both arms flung up and out, up on the toes, then down
	"mm_flare": {"keys": [
		[0.0, {}],
		[
				0.07,
				{
					"p": -0.18, "sq": 0.25, "lift": -0.06, "fl": Vector3(0.1, -0.15, -0.2), "hw": 1.0,
					"fr": Vector3(-0.1, -0.15, -0.2), "rw": 1.0}],
		[
				0.15,
				{
					"p": 0.3, "sq": -0.3, "lift": 0.16, "fl": Vector3(-0.32, 0.6, 0.05), "hw": 1.0,
					"fr": Vector3(0.32, 0.6, 0.05), "rw": 1.0}],
		[
				0.32,
				{
					"p": 0.22, "sq": -0.1, "lift": 0.08, "fl": Vector3(-0.3, 0.55, 0.05), "hw": 1.0,
					"fr": Vector3(0.3, 0.55, 0.05), "rw": 1.0}],
		[0.6, {}]]},
	# the Burrseed's root going off (payoff): a sharp tug back on the free hand, as if pulling the thread
	"mm_tug": {"keys": [
		[0.0, {}],
		[0.05, {"fl": Vector3(0.05, 0.1, -0.45), "hw": 1.0, "p": -0.1}],
		[
				0.11,
				{
					"fl": Vector3(-0.05, 0.05, 0.25), "hw": 1.0, "p": 0.22, "y": -0.2, "sq": 0.15, "lw": 0.7,
					"legs": [-0.2, -0.3, 0.4, -0.6]}],
		[0.36, {}]]},
	# a foe Kindled to 5 (passive proc): a snap of the fingers up by the shoulder, a little bounce
	"mm_kindled": {"keys": [
		[0.0, {}],
		[0.06, {"fr": Vector3(-0.05, 0.2, -0.25), "rw": 1.0, "sq": 0.1}],
		[0.12, {"fr": Vector3(0.12, 0.42, -0.1), "rw": 1.0, "sq": -0.12, "lift": 0.06, "y": 0.15}],
		[0.34, {}]]},
	# ================================================================ Tamsin
	# Ice Dart (LMB stream, one every 0.18 s): the fan snapped open across the body and whipped out at
	# the cursor, alternating with a flick of the free hand, each with a sharp twist toward the cursor
	"tm_dart_r": {"keys": [
		[0.0, {}],
		[0.03, {"wa": Vector3(0.2, -0.9, 0.5), "wf": 1.0, "y": -0.35, "sq": -0.06}],
		[0.07, {"wa": Vector3(-0.3, 0.8, -0.4), "wf": 1.0, "wo": Vector3(0, 0, -0.12), "y": 0.35, "p": -0.1,
			"sq": 0.08}],
		[0.16, {}]]},
	"tm_dart_l": {"keys": [
		[0.0, {}],
		[0.03, {"fl": Vector3(0.22, 0.15, 0.1), "hw": 1.0, "y": 0.3, "wa": Vector3(0, -0.3, 0), "wf": 0.6}],
		[0.07, {"fl": Vector3(0.1, 0.1, -0.6), "hw": 1.0, "y": -0.35, "p": -0.1, "sq": 0.08}],
		[0.16, {}]]},
	# a dart while skating: both hands driven straight out ahead, a stiff lean into it (the straight beam)
	"tm_beam": {"keys": [
		[0.0, {}],
		[0.04, {"fl": Vector3(0.1, 0.15, 0.15), "hw": 1.0, "wa": Vector3(0.4, 0, 0), "p": 0.05}],
		[
				0.08,
				{
					"fl": Vector3(0.2, 0.06, -0.62), "hw": 1.0, "wa": Vector3(-0.2, 0, 0),
					"wo": Vector3(-0.04, 0.04, -0.26), "p": -0.35, "sq": -0.15}],
		[0.14, {"fl": Vector3(0.18, 0.05, -0.58), "hw": 1.0, "wo": Vector3(0, 0.03, -0.22), "p": -0.3}],
		[0.22, {}]]},
	# Ice Spear held: the spear raised high behind her head in the free hand, the body turned away and
	# leaning well back, the fan hand pointing the way
	"tm_spear_aim": {"hold": true, "keys": [
		[0.0, {}],
		[
				0.12,
				{
					"y": -0.75, "p": 0.35, "r": -0.12, "fl": Vector3(0.05, 0.6, 0.3), "hw": 1.0,
					"wa": Vector3(-0.3, 0.5, 0), "wf": 0.5, "lw": 0.9, "legs": [-0.4, -0.3, 0.55, -0.8]}]]},
	# ... let go: the coil deepens, then the whip through to the cursor and a long lunge after the spear
	# at 0.11, the arm across the body, then up
	"tm_spear": {"keys": [
		[
				0.0,
				{
					"y": -0.75, "p": 0.35, "r": -0.12, "fl": Vector3(0.05, 0.6, 0.3), "hw": 1.0,
					"wa": Vector3(-0.3, 0.5, 0), "wf": 0.5, "lw": 0.9, "legs": [-0.4, -0.3, 0.55, -0.8]}],
		[
				0.05,
				{
					"y": -0.9, "p": 0.42, "r": -0.16, "fl": Vector3(0.08, 0.62, 0.38), "hw": 1.0, "sq": -0.18,
					"lw": 0.9, "legs": [-0.45, -0.3, 0.6, -0.85]}],
		[
				0.11,
				{
					"y": 0.85, "p": -0.5, "r": 0.14, "fl": Vector3(0.05, 0.08, -0.64), "hw": 1.0, "sq": 0.28,
					"lift": -0.08, "lw": 1.0, "legs": [1.05, -1.25, -0.6, -0.2]}],
		[
				0.28,
				{
					"y": 0.6, "p": -0.4, "fl": Vector3(-0.1, -0.08, -0.5), "hw": 0.9, "sq": 0.08, "lift": -0.06,
					"lw": 0.9, "legs": [0.95, -1.15, -0.55, -0.2]}],
		[0.6, {}]]},
	# Rink Wall: the 0.2 s tell (a deep crouch over the feet, the sparkle), then both arms flung up and
	# out as the ice erupts ahead, an overshoot up on the toes, a settle
	"tm_wall": {"keys": [
		[0.0, {}],
		[
				0.1,
				{
					"p": -0.45, "lift": -0.15, "sq": 0.45, "fl": Vector3(0.15, -0.45, -0.25), "hw": 1.0,
					"wa": Vector3(-0.7, 0, 0), "wf": 1.0, "lw": 1.0, "legs": [1.1, -1.7, 1.0, -1.6]}],
		[
				0.2,
				{
					"p": -0.5, "lift": -0.16, "sq": 0.48, "fl": Vector3(0.15, -0.46, -0.28), "hw": 1.0,
					"wa": Vector3(-0.75, 0, 0), "wf": 1.0, "lw": 1.0, "legs": [1.15, -1.75, 1.05, -1.65]}],
		[
				0.27,
				{
					"p": 0.1, "lift": 0.12, "sq": -0.35, "fl": Vector3(-0.35, 0.55, -0.2), "hw": 1.0,
					"wa": Vector3(1.0, 0, -0.6), "wo": Vector3(0.1, 0.25, -0.05), "wf": 1.0, "lw": 0.6,
					"legs": [0.2, -0.3, -0.2, -0.1]}],
		[
				0.42,
				{
					"p": 0.05, "sq": -0.1, "lift": 0.05, "fl": Vector3(-0.3, 0.48, -0.2), "hw": 0.9,
					"wa": Vector3(0.8, 0, -0.5), "wo": Vector3(0.08, 0.2, -0.05), "wf": 1.0}],
		[0.7, {}]]},
	# the wall frozen (E again): a stamp of the skate blade with a fist pulled down
	"tm_freeze": {"keys": [
		[0.0, {}],
		[
				0.07,
				{
					"lift": 0.08, "sq": -0.15, "lw": 1.0, "legs": [0.0, -0.1, -1.1, -1.5],
					"fl": Vector3(0.05, 0.35, -0.15), "hw": 1.0}],
		[
				0.13,
				{
					"lift": -0.1, "sq": 0.4, "p": -0.3, "lw": 1.0, "legs": [0.5, -0.8, 0.6, -0.9],
					"fl": Vector3(0.05, -0.35, -0.3), "hw": 1.0}],
		[0.42, {}]]},
	# Skate held (looped by the kit every 0.56 s): low and leaning hard, the knees deep, one long push
	# then the other, the arms swinging against the legs and the body rocking with each push
	"tm_skate": {"keys": [
		[
				0.0,
				{
					"p": -0.45, "r": 0.18, "y": -0.2, "lift": -0.12, "lw": 1.0, "legs": [0.85, -1.4, -0.6, -0.3],
					"fl": Vector3(-0.15, -0.05, 0.35), "hw": 0.9, "wa": Vector3(0.3, 0.4, 0), "wo": Vector3(0, 0, -0.2),
					"wf": 1.0}],
		[
				0.28,
				{
					"p": -0.45, "r": -0.18, "y": 0.2, "lift": -0.12, "lw": 1.0, "legs": [-0.6, -0.3, 0.85, -1.4],
					"fl": Vector3(0.1, 0.05, -0.4), "hw": 0.9, "wa": Vector3(0.3, -0.4, 0), "wo": Vector3(0, 0, 0.22),
					"wf": 1.0}],
		[
				0.56,
				{
					"p": -0.45, "r": 0.18, "y": -0.2, "lift": -0.12, "lw": 1.0, "legs": [0.85, -1.4, -0.6, -0.3],
					"fl": Vector3(-0.15, -0.05, 0.35), "hw": 0.9, "wa": Vector3(0.3, 0.4, 0), "wo": Vector3(0, 0, -0.2),
					"wf": 1.0}]]},
	# Skate start: a deep crouch and a hard push off the back blade
	"tm_skate_go": {"keys": [
		[0.0, {"sq": 0.35, "lift": -0.12, "p": -0.25, "lw": 1.0, "legs": [1.0, -1.6, 0.9, -1.5]}],
		[
				0.08,
				{
					"sq": -0.35, "lift": 0.02, "p": -0.6, "lw": 1.0, "legs": [0.9, -1.0, -0.85, -0.1],
					"fl": Vector3(0.1, 0.05, 0.45), "hw": 1.0}],
		[
				0.16,
				{
					"p": -0.45, "r": 0.18, "y": -0.2, "lift": -0.12, "lw": 1.0, "legs": [0.85, -1.4, -0.6, -0.3],
					"fl": Vector3(-0.15, -0.05, 0.35), "hw": 0.9, "wa": Vector3(0.3, 0.4, 0), "wo": Vector3(0, 0, -0.2),
					"wf": 1.0}]]},
	# Skate end: a hockey stop, turned side-on, leaning back hard over braced blades, then up
	"tm_skate_stop": {"keys": [
		[0.0, {"p": -0.45, "lw": 1.0, "legs": [0.85, -1.4, -0.6, -0.3]}],
		[
				0.07,
				{
					"y": 1.2, "r": 0.45, "p": 0.2, "sq": 0.3, "lift": -0.14, "lw": 1.0,
					"legs": [0.85, -1.3, 0.3, -0.8], "fl": Vector3(-0.4, 0.25, 0.0), "hw": 1.0, "wf": 1.0,
					"wa": Vector3(0, 0, 0.6)}],
		[
				0.22,
				{
					"y": 1.0, "r": 0.3, "p": 0.12, "sq": 0.15, "lift": -0.08, "lw": 1.0, "legs": [0.7, -1.1, 0.2, -0.6],
					"fl": Vector3(-0.35, 0.2, 0.0), "hw": 0.8, "wf": 0.8}],
		[0.5, {}]]},
	# the air dash: a stretched skater's glide (she never tumbles in the source): pitched forward, one
	# leg trailing long, arms out wide like wings, held, then a light landing
	"tm_dash_air": {"keys": [
		[0.0, {"sq": 0.2, "p": -0.1}],
		[
				0.06,
				{
					"p": -0.7, "sq": -0.3, "r": 0.15, "lw": 1.0, "legs": [0.35, -0.3, -0.95, -0.15],
					"fl": Vector3(-0.5, 0.12, 0.08), "hw": 1.0, "wa": Vector3(0.2, 0, 1.2),
						"wo": Vector3(0.25, 0.1, 0.1),
					"wf": 1.0}],
		[
				0.24,
				{
					"p": -0.65, "sq": -0.25, "r": 0.1, "lw": 1.0, "legs": [0.3, -0.3, -0.9, -0.15],
					"fl": Vector3(-0.5, 0.15, 0.1), "hw": 1.0, "wa": Vector3(0.2, 0, 1.2),
						"wo": Vector3(0.25, 0.1, 0.1),
					"wf": 1.0}],
		[0.32, {"p": -0.2, "sq": 0.2, "lift": -0.06, "lw": 1.0, "legs": [0.6, -1.0, 0.5, -0.9]}],
		[0.5, {}]]},
	# Shatter (payoff): the fan snapped shut in a big flourish, the free fist clenched and pulled in, a
	# lean into it
	"tm_shatter": {"keys": [
		[0.0, {}],
		[
				0.06,
				{
					"wa": Vector3(0.5, 0, 2.4), "wo": Vector3(0.05, 0.2, 0), "wf": 1.0, "fl": Vector3(0.0, 0.3, -0.45),
					"hw": 1.0, "y": -0.3, "sq": -0.15, "lift": 0.05}],
		[
				0.13,
				{
					"wa": Vector3(-0.4, 0, -0.9), "wo": Vector3(0, -0.05, -0.1), "wf": 1.0,
						"fl": Vector3(0.1, -0.05, -0.1),
					"hw": 1.0, "y": 0.3, "p": -0.2, "sq": 0.25, "lift": -0.06, "lw": 0.8,
						"legs": [0.5, -0.9, 0.3, -0.5]}],
		[0.24, {"p": -0.15, "sq": 0.12, "fl": Vector3(0.1, -0.03, -0.12), "hw": 1.0, "wf": 1.0}],
		[0.45, {}]]},
	# ================================================================ ultimates on X (10 fps beats)
	# cast (f25): the hand pulled back low, then thrust high and out as the plus bursts on the ally,
	# an overshoot, then into the channel pose
	"mm_call": {"keys": [
		[0.0, {"y": 0.2, "p": -0.08, "fl": Vector3(0.1, 0.32, -0.5), "hw": 1.0}],
		[0.05, {"y": -0.2, "p": 0.15, "sq": 0.18, "fl": Vector3(0.05, -0.15, 0.25), "hw": 1.0}],
		[0.1, {"y": 0.3, "p": -0.25, "sq": -0.22, "lift": 0.06, "fl": Vector3(0.1, 0.78, -0.3), "hw": 1.0}],
		[0.2, {"y": 0.22, "p": -0.18, "sq": -0.08, "fl": Vector3(0.08, 0.7, -0.22), "hw": 1.0}],
		[0.35, {"p": -0.06, "fl": Vector3(0.06, 0.62, -0.12), "hw": 1.0, "fr": Vector3(0.25, 0.0, -0.2), "rw": 0.7}]]},
	# the channel (f26-f73): one hand held high over the tether, the other out for balance; the legs
	# keep walking (no leg channel)
	"mm_call_hold": {"hold": true, "keys": [
		[0.0, {"p": -0.06, "fl": Vector3(0.06, 0.62, -0.12), "hw": 1.0, "fr": Vector3(0.25, 0.0, -0.2), "rw": 0.7}],
		[0.3, {"p": -0.08, "r": 0.04, "fl": Vector3(0.04, 0.66, -0.1), "hw": 1.0, "fr": Vector3(0.28, 0.05, -0.18),
			"rw": 0.7}]]},
	# the end (f74-f77): the raised hand swept down to her side, pulling the teammate home, both arms
	# open on the arrival burst, then settled (recovery is instant in the footage)
	"mm_call_end": {"keys": [
		[0.0, {"p": -0.08, "fl": Vector3(0.04, 0.66, -0.1), "hw": 1.0}],
		[0.07, {"y": -0.3, "p": 0.12, "sq": 0.15, "fl": Vector3(0.45, 0.0, 0.1), "hw": 1.0}],
		[0.14, {"y": 0.1, "p": -0.15, "sq": -0.12, "lift": 0.04, "fl": Vector3(0.5, 0.35, -0.05), "hw": 1.0}],
		[0.3, {}]]},
	# Rimelock cast (f25-f27): a crouch with the arms crossed, then thrown up and out as the rink snaps,
	# then down into the sealed crouch
	"tm_rime": {"keys": [
		[0.0, {}],
		[0.06, {"p": 0.3, "sq": 0.3, "lift": -0.1, "fl": Vector3(0.25, 0.05, -0.2), "hw": 1.0, "lw": 1.0,
			"legs": [0.8, -1.2, 0.7, -1.1]}],
		[0.12, {"p": -0.3, "sq": -0.3, "lift": 0.1, "fl": Vector3(-0.3, 0.7, 0.05), "hw": 1.0,
			"wa": Vector3(-0.6, 0, 0.8), "wf": 1.0,
			"lw": 1.0, "legs": [-0.1, -0.2, 0.1, -0.2]}],
		[0.2, {"p": 0.35, "sq": 0.2, "lift": -0.08, "fl": Vector3(0.28, 0.1, -0.22), "hw": 1.0,
			"wa": Vector3(0.5, 0, -0.4), "wf": 1.0,
			"lw": 1.0, "legs": [0.7, -1.1, 0.6, -1.0]}]]},
	# sealed in (f27-f55): hunched over, arms crossed on the chest, the fan folded in, knees bent
	"tm_rime_hold": {"hold": true, "keys": [
		[0.0, {"p": 0.35, "sq": 0.2, "lift": -0.08, "fl": Vector3(0.28, 0.1, -0.22), "hw": 1.0,
			"wa": Vector3(0.5, 0, -0.4), "wf": 1.0,
			"lw": 1.0, "legs": [0.7, -1.1, 0.6, -1.0]}],
		[0.4, {"p": 0.38, "r": 0.03, "sq": 0.24, "lift": -0.1, "fl": Vector3(0.3, 0.08, -0.2), "hw": 1.0,
			"wa": Vector3(0.55, 0, -0.42), "wf": 1.0, "lw": 1.0, "legs": [0.75, -1.15, 0.65, -1.05]}]]},
	# the crash (f57): a deeper crouch, then everything flung wide as the shell bursts, an overshoot up
	# on the toes, settled by recovery (f61)
	"tm_rime_crash": {"keys": [
		[0.0, {"p": 0.38, "sq": 0.24, "lift": -0.1, "fl": Vector3(0.3, 0.08, -0.2), "hw": 1.0, "lw": 1.0,
			"legs": [0.75, -1.15, 0.65, -1.05]}],
		[0.04, {"p": 0.45, "sq": 0.35, "lift": -0.16, "fl": Vector3(0.2, -0.05, -0.15), "hw": 1.0, "lw": 1.0,
			"legs": [0.95, -1.4, 0.85, -1.3]}],
		[0.1, {"p": -0.4, "sq": -0.35, "lift": 0.14, "fl": Vector3(-0.45, 0.65, 0.15), "hw": 1.0,
			"wa": Vector3(-0.8, 0, 1.2), "wf": 1.0,
			"lw": 1.0, "legs": [-0.2, -0.15, -0.25, -0.1]}],
		[0.2, {"p": -0.22, "sq": -0.12, "lift": 0.06, "fl": Vector3(-0.35, 0.5, 0.1), "hw": 0.8,
			"wa": Vector3(-0.5, 0, 0.8), "wf": 1.0,
			"lw": 0.8, "legs": [0.1, -0.3, 0.0, -0.3]}],
		[0.4, {}]]},
	# an early break: a shrug that pushes the shell off, small and quick
	"tm_rime_break": {"keys": [
		[0.0, {"p": 0.35, "sq": 0.2, "fl": Vector3(0.28, 0.1, -0.22), "hw": 1.0}],
		[0.08, {"p": -0.1, "sq": -0.1, "fl": Vector3(0.1, 0.25, -0.4), "hw": 1.0}],
		[0.3, {}]]},
	# the spear going off (payoff): a sharp clench of the free hand
	"tm_clench": {"keys": [
		[0.0, {}],
		[0.05, {"fl": Vector3(0.08, 0.15, -0.4), "hw": 1.0}],
		[0.1, {"fl": Vector3(0.0, -0.05, -0.12), "hw": 1.0, "p": 0.1, "sq": 0.12}],
		[0.34, {}]]},
}

## The length of a move (s), 0 for none.
static func length(id: String) -> float:
	var mv: Dictionary = MOVES.get(id, {})
	if mv.is_empty(): return 0.0
	var keys: Array = mv["keys"]
	return float(keys[-1][0])
