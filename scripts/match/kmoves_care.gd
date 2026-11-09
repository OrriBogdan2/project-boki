class_name KMovesCare
extends RefCounted
## Keyed full-body moves of Meeko (tender, "mm_") and Neve (rimewright, "tm_"): same format and
## channels as HunterAnim.KMOVES, looked up by HunterAnim.km_sample. Timed to the reference sheets'
## beats (docs/heroes/tender.md, rimewright.md: Animation moves): anticipation, the release on the
## kit's hit time, an overshoot past the key pose, then the settle. Channels used here besides the
## body ones: fl / fr (a free hand from its shoulder, x right, y up, z back), hw / rw their weights,
## wa (the held fan's extra pitch, yaw, roll about its grip), wo (its offset, m) and wf (how far the
## fan turns with the torso instead of staying on the aim). Pip holds nothing: both hands are
## hers to cast from, so her moves key fl and fr.
## A move whose first and last keys match can loop: the kit replays it (the skate stride).

const MOVES := {
	# ================================================================ Pip
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
	# Burrseed wind-up (item 118, a fixed 1.0 s: tender.json rmb windup): turned side-on (~70 deg),
	# the casting fist pointed down the lane, the other hand drawn up beside the ear, sinking on the
	# back leg until the throw
	"mm_seed_aim": {"keys": [
		[0.0, {}],
		[
				0.2,
				{
					"y": 1.0, "p": 0.06, "r": 0.06, "sq": 0.06, "fr": Vector3(-0.42, 0.05, -0.4), "rw": 1.0,
					"fl": Vector3(0.02, 0.32, 0.12), "hw": 1.0, "lw": 0.7, "legs": [-0.25, -0.4, 0.35, -0.55]}],
		[
				1.0,
				{
					"y": 1.2, "p": 0.1, "r": 0.08, "sq": 0.12, "fr": Vector3(-0.42, 0.05, -0.4), "rw": 1.0,
					"fl": Vector3(0.02, 0.4, 0.12), "hw": 1.0, "lw": 0.8, "legs": [-0.3, -0.5, 0.45, -0.7]}]]},
	# ... the throw as the wind-up ends: the coil deepens, then a small hop forward with a
	# two-handed push, the flare round her
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
	# Relay Step, the ground hop (0.2 s of dash): a quick squash, then a skip off one foot with the lead knee
	# up and both arms flung up behind like little wings, a tucked apex, a squash on touchdown and a happy
	# bounce with a wiggle of the shoulders (0.24 s in all)
	"mm_skip": {"keys": [
		[0.0, {"sq": 0.35, "lift": -0.08, "p": 0.1, "lw": 1.0, "legs": [0.9, -1.4, 0.8, -1.3]}],
		[
				0.04,
				{
					"sq": -0.45, "lift": 0.32, "p": -0.3, "r": 0.12, "lw": 1.0, "legs": [1.2, -1.8, -0.2, -0.3],
					"fl": Vector3(-0.35, 0.35, 0.2), "hw": 1.0, "fr": Vector3(0.35, 0.35, 0.2), "rw": 1.0}],
		[
				0.11,
				{
					"sq": -0.1, "lift": 0.36, "p": -0.2, "r": -0.1, "lw": 1.0, "legs": [1.3, -2.0, 1.2, -1.9],
					"fl": Vector3(-0.5, 0.25, 0.0), "hw": 1.0, "fr": Vector3(0.5, 0.25, 0.0), "rw": 1.0}],
		[
				0.17,
				{
					"sq": 0.45, "lift": -0.1, "p": 0.05, "lw": 1.0, "legs": [0.8, -1.3, 0.7, -1.2],
					"fl": Vector3(-0.2, -0.1, -0.2), "hw": 0.8, "fr": Vector3(0.2, -0.1, -0.2), "rw": 0.8}],
		[
				0.21,
				{
					"sq": -0.12, "lift": 0.06, "y": 0.15, "lw": 0.8, "legs": [0.4, -0.7, 0.35, -0.6],
					"fl": Vector3(-0.3, 0.3, -0.1), "hw": 0.7, "fr": Vector3(0.3, 0.3, -0.1), "rw": 0.7}],
		[0.24, {}]]},
	# the air dash, her long float (0.95 s of glide, Elluna's): tucked into a ball for one forward somersault, then
	# unfurled into a seated float, leaning back with the knees tucked up and both arms up in a happy V like
	# a drifting seed, a little sway, the legs reaching down, and a soft squash on touchdown (fx stays a full
	# turn: no unwind)
	"mm_float": {"keys": [
		[0.0, {"sq": 0.2, "p": 0.1, "lw": 1.0, "legs": [0.9, -1.4, 0.8, -1.3]}],
		[
				0.06,
				{
					"fx": -1.6, "sq": 0.35, "lw": 1.0, "legs": [1.5, -2.2, 1.4, -2.2],
					"fl": Vector3(-0.1, -0.15, -0.25), "hw": 1.0, "fr": Vector3(0.1, -0.15, -0.25), "rw": 1.0}],
		[
				0.26,
				{
					"fx": -6.283, "sq": 0.3, "lw": 1.0, "legs": [1.5, -2.2, 1.4, -2.2],
					"fl": Vector3(-0.1, -0.15, -0.25), "hw": 1.0, "fr": Vector3(0.1, -0.15, -0.25), "rw": 1.0}],
		[
				0.36,
				{
					"fx": -6.283, "sq": -0.15, "lift": 0.05, "p": 0.22, "r": 0.1, "lw": 1.0,
					"legs": [1.5, -2.0, 1.4, -1.9], "fl": Vector3(-0.45, 0.6, -0.05), "hw": 1.0,
					"fr": Vector3(0.45, 0.6, -0.05), "rw": 1.0}],
		[
				0.62,
				{
					"fx": -6.283, "sq": -0.08, "lift": 0.05, "p": 0.22, "r": -0.1, "lw": 1.0,
					"legs": [1.5, -2.0, 1.4, -1.9], "fl": Vector3(-0.5, 0.55, 0.0), "hw": 1.0,
					"fr": Vector3(0.5, 0.55, 0.0), "rw": 1.0}],
		[
				0.85,
				{
					"fx": -6.283, "sq": -0.05, "lw": 1.0, "legs": [0.4, -0.7, 0.3, -0.6],
					"fl": Vector3(-0.45, 0.2, -0.05), "hw": 0.9, "fr": Vector3(0.45, 0.2, -0.05), "rw": 0.9}],
		[0.95, {"fx": -6.283, "sq": 0.3, "lift": -0.08, "lw": 1.0, "legs": [0.9, -1.4, 0.8, -1.3]}],
		[1.05, {"fx": -6.283}]]},
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
	# ================================================================ Claire
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
	# a large dart at the end of the barrage: a bigger, two-handed fling. The torso winds away with both hands
	# drawn back to the hip (0.04), then whips round and both arms sling forward, the fan snapping open, the
	# weight thrown onto the front foot (0.08), and a settle back (0.18, the barrage's cadence)
	"tm_dart_heavy": {"keys": [
		[0.0, {}],
		[0.04, {"y": -0.55, "p": 0.12, "sq": 0.14, "fl": Vector3(0.25, -0.15, 0.25), "hw": 1.0,
			"wa": Vector3(0.3, -1.0, 0.6), "wf": 1.0, "lw": 0.7, "legs": [-0.3, -0.4, 0.45, -0.7]}],
		[0.08, {"y": 0.5, "p": -0.25, "sq": -0.12, "fl": Vector3(0.12, 0.12, -0.62), "hw": 1.0,
			"wa": Vector3(-0.4, 0.9, -0.5), "wo": Vector3(0, 0, -0.16), "wf": 1.0, "lw": 0.8,
			"legs": [0.8, -1.0, -0.45, -0.25]}],
		[0.18, {}]]},
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
	# Ice Spear held: she gathers it, both palms drawn in to her chest round the forming spear, elbows back,
	# the weight settling onto the back foot and the body squared to the cursor, a slight crouch
	"tm_spear_aim": {"hold": true, "keys": [
		[0.0, {}],
		[
				0.12,
				{
					"p": 0.18, "sq": 0.14, "lift": -0.05, "fl": Vector3(0.14, 0.12, -0.2), "hw": 1.0,
					"fr": Vector3(-0.14, 0.12, -0.2), "rw": 1.0, "wf": 1.0, "lw": 0.9,
					"legs": [-0.35, -0.4, 0.5, -0.75]}]]},
	# ... let go: a push, not a throw. A quick load deeper into the back foot (0.05), then both palms drive
	# straight out at the cursor and the spear leaves them at full extension (0.1, RimewrightKit.PUSH_T), the
	# body lunging after it; the arms hold out through the recoil, then settle
	"tm_spear": {"keys": [
		[
				0.0,
				{
					"p": 0.18, "sq": 0.14, "lift": -0.05, "fl": Vector3(0.14, 0.12, -0.2), "hw": 1.0,
					"fr": Vector3(-0.14, 0.12, -0.2), "rw": 1.0, "wf": 1.0, "lw": 0.9,
					"legs": [-0.35, -0.4, 0.5, -0.75]}],
		[
				0.05,
				{
					"p": 0.26, "sq": 0.24, "lift": -0.09, "fl": Vector3(0.12, 0.1, -0.14), "hw": 1.0,
					"fr": Vector3(-0.12, 0.1, -0.14), "rw": 1.0, "wf": 1.0, "lw": 1.0,
					"legs": [-0.45, -0.45, 0.6, -0.85]}],
		[
				0.1,
				{
					"p": -0.42, "sq": -0.22, "lift": 0.02, "fl": Vector3(0.1, 0.06, -0.7), "hw": 1.0,
					"fr": Vector3(-0.1, 0.06, -0.7), "rw": 1.0, "wf": 1.0, "lw": 1.0,
					"legs": [1.05, -1.25, -0.6, -0.2]}],
		[
				0.28,
				{
					"p": -0.3, "sq": 0.06, "lift": -0.04, "fl": Vector3(0.14, 0.02, -0.6), "hw": 0.9,
					"fr": Vector3(-0.14, 0.02, -0.6), "rw": 0.9, "wf": 0.8, "lw": 0.9,
					"legs": [0.95, -1.15, -0.55, -0.2]}],
		[0.55, {}]]},
	# Rink Wall (footage: both hands pushed forward): the 0.2 s tell, a deep crouch with both palms drawn back
	# to the hips and the sparkle at her feet; then both palms shoved out low and wide along the ground as the
	# ice erupts ahead (0.27), the body driving after them, held while it starts to slide, then a settle
	"tm_wall": {"keys": [
		[0.0, {}],
		[
				0.1,
				{
					"p": -0.2, "lift": -0.15, "sq": 0.4, "fl": Vector3(0.3, -0.45, 0.25), "hw": 1.0,
					"fr": Vector3(-0.3, -0.45, 0.25), "rw": 1.0, "wf": 1.0, "lw": 1.0,
					"legs": [1.1, -1.7, 1.0, -1.6]}],
		[
				0.2,
				{
					"p": -0.15, "lift": -0.17, "sq": 0.46, "fl": Vector3(0.32, -0.46, 0.3), "hw": 1.0,
					"fr": Vector3(-0.32, -0.46, 0.3), "rw": 1.0, "wf": 1.0, "lw": 1.0,
					"legs": [1.15, -1.75, 1.05, -1.65]}],
		[
				0.27,
				{
					"p": -0.5, "lift": -0.08, "sq": -0.2, "fl": Vector3(0.32, -0.3, -0.68), "hw": 1.0,
					"fr": Vector3(-0.32, -0.3, -0.68), "rw": 1.0, "wf": 1.0, "lw": 1.0,
					"legs": [1.05, -1.25, -0.6, -0.2]}],
		[
				0.42,
				{
					"p": -0.4, "lift": -0.06, "sq": -0.05, "fl": Vector3(0.34, -0.28, -0.6), "hw": 0.9,
					"fr": Vector3(-0.34, -0.28, -0.6), "rw": 0.9, "wf": 0.9, "lw": 0.9,
					"legs": [0.95, -1.15, -0.55, -0.2]}],
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
	# Skate in the air (item 62, looped like tm_skate): no push, a long glide over the ribbon, the free leg
	# stretched behind, the arms out for balance; ART-1 has no clip for it yet
	"tm_skate_air": {"keys": [
		[
				0.0,
				{
					"p": -0.5, "r": 0.1, "y": -0.1, "lift": 0.0, "lw": 1.0, "legs": [0.5, -0.8, -0.7, -0.2],
					"fl": Vector3(-0.1, -0.05, 0.3), "hw": 0.9, "wa": Vector3(0.3, 0.3, 0), "wo": Vector3(0, 0, -0.15),
					"wf": 1.0}],
		[
				0.28,
				{
					"p": -0.42, "r": -0.1, "y": 0.1, "lift": 0.04, "lw": 1.0, "legs": [0.55, -0.9, -0.8, -0.25],
					"fl": Vector3(0.1, 0.05, -0.3), "hw": 0.9, "wa": Vector3(0.3, -0.3, 0), "wo": Vector3(0, 0, 0.15),
					"wf": 1.0}],
		[
				0.56,
				{
					"p": -0.5, "r": 0.1, "y": -0.1, "lift": 0.0, "lw": 1.0, "legs": [0.5, -0.8, -0.7, -0.2],
					"fl": Vector3(-0.1, -0.05, 0.3), "hw": 0.9, "wa": Vector3(0.3, 0.3, 0), "wo": Vector3(0, 0, -0.15),
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
	# skated into the seal (x.carry_t): the momentum carries her as the shell closes. She whips side-on into a
	# braced hockey stop, leaning back hard over the blades with the arms flung out as the rink snaps (0.08),
	# grinds on low with the arms swinging in (0.28), and sinks into the sealed crouch as she stops (0.5)
	"tm_rime_carry": {"keys": [
		[0.0, {"p": -0.45, "lw": 1.0, "legs": [0.85, -1.4, -0.6, -0.3]}],
		[0.08, {"y": 1.15, "r": 0.5, "p": 0.15, "sq": 0.3, "lift": -0.16, "lw": 1.0,
			"legs": [0.9, -1.35, 0.35, -0.85], "fl": Vector3(-0.45, 0.6, 0.05), "hw": 1.0,
			"wa": Vector3(-0.6, 0, 0.9), "wf": 1.0}],
		[0.28, {"y": 0.8, "r": 0.32, "p": 0.3, "sq": 0.28, "lift": -0.14, "lw": 1.0,
			"legs": [0.85, -1.3, 0.55, -1.0], "fl": Vector3(0.1, 0.3, -0.25), "hw": 1.0,
			"wa": Vector3(0.2, 0, 0.1), "wf": 1.0}],
		[0.5, {"p": 0.35, "sq": 0.2, "lift": -0.08, "fl": Vector3(0.28, 0.1, -0.22), "hw": 1.0,
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
