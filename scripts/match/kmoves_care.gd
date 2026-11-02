class_name KMovesCare
extends RefCounted
## Keyed full-body moves of Moosh Moosh (tender, "mm_") and Tamsin (rimewright, "tm_"): same format and
## channels as HunterAnim.KMOVES, looked up by HunterAnim.km_sample. Timed to the reference sheets'
## beats (docs/heroes/tender.md, rimewright.md: Animation moves): anticipation, the release on the
## kit's hit time, an overshoot past the key pose, then the settle. Channels used here besides the
## body ones: fl / fr (a free hand from its shoulder, x right, y up, z back), hw / rw their weights,
## wa (the held weapon's extra pitch, yaw, roll about its grip) and wo (its offset, m): the weapon
## pivot added for this pair (HunterAnim._upper), so the crook flicks and the fan snaps.
## A move whose first and last keys match can loop: the kit replays it (the skate stride).

const MOVES := {
	# ================================================================ Moosh Moosh
	# Moon Shot (LMB, every 0.4 s): the crook cocked up over the shoulder, flicked down at the cursor
	# (the ember leaves at 0.1), a small overshoot of the lantern head, settled by 0.34
	"mm_shot": {"keys": [
		[0.0, {}],
		[0.06, {"wa": Vector3(0.55, -0.12, 0.2), "y": -0.14, "p": 0.06, "sq": -0.06}],
		[0.1, {"wa": Vector3(-0.5, 0.18, -0.1), "y": 0.2, "p": -0.12, "sq": 0.08, "fl": Vector3(-0.12, 0.05, 0.18), "hw": 0.6}],
		[0.17, {"wa": Vector3(-0.22, 0.08, 0.0), "y": 0.08, "p": -0.05}],
		[0.34, {}]]},
	# the Empowered shot after a pause: a bigger coil up on the toes, a long flick and the free arm
	# thrown back for balance
	"mm_shot_emp": {"keys": [
		[0.0, {}],
		[0.09, {"wa": Vector3(0.95, -0.2, 0.35), "y": -0.35, "p": 0.18, "lift": 0.05, "sq": -0.18, "fl": Vector3(0.1, 0.2, -0.2), "hw": 0.8}],
		[0.14, {"wa": Vector3(-0.8, 0.3, -0.2), "y": 0.4, "p": -0.3, "sq": 0.22, "lift": -0.03, "fl": Vector3(-0.2, 0.1, 0.35), "hw": 1.0, "lw": 0.8, "legs": [0.45, -0.6, -0.35, -0.2]}],
		[0.26, {"wa": Vector3(-0.35, 0.12, 0.0), "y": 0.15, "p": -0.12, "fl": Vector3(-0.15, 0.05, 0.25), "hw": 0.6}],
		[0.5, {}]]},
	# Burrseed held: turned side-on, the seed cupped back by the ear, the crook pointing down the lane
	"mm_seed_aim": {"hold": true, "keys": [
		[0.0, {}],
		[0.12, {"y": -0.45, "p": 0.12, "r": -0.08, "fl": Vector3(-0.08, 0.34, 0.22), "hw": 1.0, "wa": Vector3(0.2, 0.25, 0.0), "lw": 0.7, "legs": [-0.2, -0.3, 0.35, -0.5]}]]},
	# ... let go: the coil deepens, then an overhand whip through to the cursor side with a long
	# follow-through and the cast flare round her at 0.1
	"mm_seed": {"keys": [
		[0.0, {"y": -0.45, "p": 0.12, "r": -0.08, "fl": Vector3(-0.08, 0.34, 0.22), "hw": 1.0, "wa": Vector3(0.2, 0.25, 0.0), "lw": 0.7, "legs": [-0.2, -0.3, 0.35, -0.5]}],
		[0.05, {"y": -0.6, "p": 0.2, "r": -0.12, "fl": Vector3(-0.1, 0.42, 0.3), "hw": 1.0, "sq": -0.15, "lw": 0.8, "legs": [-0.25, -0.3, 0.4, -0.55]}],
		[0.1, {"y": 0.55, "p": -0.42, "r": 0.1, "fl": Vector3(0.1, 0.1, -0.62), "hw": 1.0, "sq": 0.25, "wa": Vector3(-0.3, -0.2, 0.0), "lw": 1.0, "legs": [0.7, -0.9, -0.45, -0.25]}],
		[0.22, {"y": 0.4, "p": -0.3, "fl": Vector3(0.12, 0.0, -0.55), "hw": 0.9, "sq": 0.08, "lw": 0.8, "legs": [0.6, -0.8, -0.4, -0.2]}],
		[0.5, {}]]},
	# Hearthlight lit: a crouch to gather the light, then up with the lantern hand thrust high (the
	# plus and the rising rays at 0.18), held, then down
	"mm_hearth": {"keys": [
		[0.0, {}],
		[0.08, {"p": -0.3, "lift": -0.12, "sq": 0.3, "fl": Vector3(0.08, -0.25, -0.2), "hw": 1.0, "wa": Vector3(-0.3, 0, 0), "lw": 1.0, "legs": [0.7, -1.2, 0.6, -1.1]}],
		[0.18, {"p": 0.24, "lift": 0.1, "sq": -0.25, "fl": Vector3(0.04, 0.66, -0.08), "hw": 1.0, "wa": Vector3(0.4, 0, 0), "lw": 0.6, "legs": [-0.1, -0.15, 0.05, -0.2]}],
		[0.34, {"p": 0.2, "lift": 0.04, "sq": -0.08, "fl": Vector3(0.04, 0.6, -0.1), "hw": 1.0}],
		[0.6, {}]]},
	# Hearthlight thrown: a quick wind low behind, then an underhand fling out at the cursor
	"mm_toss": {"keys": [
		[0.0, {}],
		[0.06, {"y": -0.4, "p": 0.1, "fl": Vector3(-0.12, -0.2, 0.3), "hw": 1.0, "sq": 0.12}],
		[0.11, {"y": 0.45, "p": -0.25, "fl": Vector3(0.12, 0.38, -0.58), "hw": 1.0, "sq": -0.18, "lift": 0.04}],
		[0.24, {"y": 0.3, "p": -0.18, "fl": Vector3(0.1, 0.3, -0.5), "hw": 0.8}],
		[0.48, {}]]},
	# Relay Step (the base dash): a crouch, a long stretched hop leaning into it with the knees tucked
	# and the lantern pole swinging back, a landing squash and a settle
	"mm_dash": {"keys": [
		[0.0, {"sq": 0.3, "lift": -0.06, "p": -0.15}],
		[0.05, {"sq": -0.35, "lift": 0.22, "p": -0.42, "lw": 1.0, "legs": [0.9, -1.4, 0.6, -1.0], "fl": Vector3(-0.15, 0.1, 0.35), "hw": 0.8, "wa": Vector3(0.5, 0, 0)}],
		[0.14, {"sq": -0.1, "lift": 0.12, "p": -0.3, "lw": 1.0, "legs": [0.6, -1.0, 0.4, -0.7], "fl": Vector3(-0.1, 0.1, 0.25), "hw": 0.6}],
		[0.2, {"sq": 0.35, "lift": -0.08, "p": -0.18, "lw": 1.0, "legs": [0.6, -1.0, 0.5, -0.9]}],
		[0.42, {}]]},
	# ... through a teammate: the same hop with a free-hand flourish over them (the RELAY proc)
	"mm_relay": {"keys": [
		[0.0, {"sq": 0.3, "lift": -0.06, "p": -0.15}],
		[0.05, {"sq": -0.35, "lift": 0.26, "p": -0.38, "r": 0.15, "lw": 1.0, "legs": [0.9, -1.4, 0.6, -1.0], "fl": Vector3(-0.05, 0.62, 0.0), "hw": 1.0}],
		[0.14, {"sq": -0.1, "lift": 0.16, "p": -0.25, "r": -0.12, "lw": 1.0, "legs": [0.6, -1.0, 0.4, -0.7], "fl": Vector3(-0.25, 0.5, 0.1), "hw": 1.0}],
		[0.2, {"sq": 0.35, "lift": -0.08, "p": -0.18, "lw": 1.0, "legs": [0.6, -1.0, 0.5, -0.9]}],
		[0.45, {}]]},
	# the long air dash: a tucked forward roll over the lantern, out of it stretched, then the catch
	"mm_dash_air": {"keys": [
		[0.0, {"sq": 0.2}],
		[0.06, {"fx": -1.8, "sq": 0.35, "lw": 1.0, "legs": [1.6, -2.2, 1.5, -2.1], "fl": Vector3(0.0, -0.1, -0.2), "hw": 1.0}],
		[0.16, {"fx": -6.28, "sq": -0.25, "lw": 1.0, "legs": [0.4, -0.6, 0.2, -0.4]}],
		[0.24, {"fx": -6.28, "sq": 0.3, "lift": -0.06, "lw": 1.0, "legs": [0.6, -1.0, 0.5, -0.9]}],
		[0.42, {"fx": -6.28}]]},
	# Bearer: scooping a downed teammate up onto the pack: a deep squat, then a heave with a lean back
	"mm_pickup": {"keys": [
		[0.0, {}],
		[0.12, {"p": -0.55, "lift": -0.2, "sq": 0.35, "lw": 1.0, "legs": [1.1, -1.7, 1.0, -1.6], "fl": Vector3(0.05, -0.5, -0.3), "hw": 1.0}],
		[0.3, {"p": 0.25, "lift": 0.05, "sq": -0.2, "lw": 0.6, "legs": [0.2, -0.3, 0.1, -0.2], "fl": Vector3(-0.1, 0.35, 0.2), "hw": 1.0}],
		[0.55, {}]]},
	# the Hearthlight flare (payoff): both arms flung up and out, up on the toes, then down
	"mm_flare": {"keys": [
		[0.0, {}],
		[0.07, {"p": -0.15, "sq": 0.2, "lift": -0.05, "fl": Vector3(0.1, -0.1, -0.2), "hw": 1.0}],
		[0.15, {"p": 0.3, "sq": -0.3, "lift": 0.12, "fl": Vector3(-0.3, 0.6, 0.05), "hw": 1.0, "wa": Vector3(0.7, 0, -0.4)}],
		[0.3, {"p": 0.22, "sq": -0.1, "lift": 0.06, "fl": Vector3(-0.28, 0.55, 0.05), "hw": 1.0}],
		[0.6, {}]]},
	# the Burrseed's root going off (payoff): a sharp tug back on the free hand, as if pulling the thread
	"mm_tug": {"keys": [
		[0.0, {}],
		[0.05, {"fl": Vector3(0.05, 0.1, -0.45), "hw": 1.0, "p": -0.1}],
		[0.11, {"fl": Vector3(-0.05, 0.05, 0.25), "hw": 1.0, "p": 0.22, "y": -0.2, "sq": 0.15, "lw": 0.7, "legs": [-0.2, -0.3, 0.4, -0.6]}],
		[0.36, {}]]},
	# a foe Kindled to 5 (passive proc): the crook spun once in the fingers
	"mm_kindled": {"keys": [
		[0.0, {}],
		[0.08, {"wa": Vector3(0.2, 0, 2.2), "wo": Vector3(0, 0.08, 0), "y": 0.1}],
		[0.2, {"wa": Vector3(0.0, 0, 6.28), "wo": Vector3(0, 0.04, 0)}],
		[0.34, {"wa": Vector3(0.0, 0, 6.28)}]]},
	# ================================================================ Tamsin
	# Ice Dart (LMB stream, one every 0.18 s): the fan snapped open across the body, alternating the
	# fan hand and the free hand, each flick a short twist toward the cursor
	"tm_dart_r": {"keys": [
		[0.0, {}],
		[0.03, {"wa": Vector3(0.1, -0.55, 0.3), "y": -0.16, "sq": -0.04}],
		[0.07, {"wa": Vector3(-0.2, 0.55, -0.2), "y": 0.18, "p": -0.08, "sq": 0.06}],
		[0.16, {}]]},
	"tm_dart_l": {"keys": [
		[0.0, {}],
		[0.03, {"fl": Vector3(0.18, 0.12, 0.05), "hw": 1.0, "y": 0.14, "wa": Vector3(0, -0.2, 0)}],
		[0.07, {"fl": Vector3(0.08, 0.08, -0.55), "hw": 1.0, "y": -0.2, "p": -0.08, "sq": 0.06}],
		[0.16, {}]]},
	# a dart while skating: both hands driven straight out, a stiff lean into it (the straight beam)
	"tm_beam": {"keys": [
		[0.0, {}],
		[0.04, {"fl": Vector3(0.1, 0.15, 0.1), "hw": 1.0, "wa": Vector3(0.3, 0, 0), "p": 0.05}],
		[0.08, {"fl": Vector3(0.18, 0.08, -0.6), "hw": 1.0, "wa": Vector3(-0.15, 0, 0), "wo": Vector3(0, 0, -0.12), "p": -0.2, "sq": -0.12}],
		[0.2, {}]]},
	# Ice Spear held: the spear raised high behind her head in the free hand, body turned away, leaning back
	"tm_spear_aim": {"hold": true, "keys": [
		[0.0, {}],
		[0.12, {"y": -0.6, "p": 0.2, "r": -0.1, "fl": Vector3(0.12, 0.5, 0.35), "hw": 1.0, "wa": Vector3(-0.3, 0.3, 0), "lw": 0.8, "legs": [-0.3, -0.3, 0.45, -0.6]}]]},
	# ... let go: the whip through, a long lunge after the spear at 0.11, the arm across the body
	"tm_spear": {"keys": [
		[0.0, {"y": -0.6, "p": 0.2, "r": -0.1, "fl": Vector3(0.12, 0.5, 0.35), "hw": 1.0, "wa": Vector3(-0.3, 0.3, 0), "lw": 0.8, "legs": [-0.3, -0.3, 0.45, -0.6]}],
		[0.05, {"y": -0.72, "p": 0.26, "r": -0.14, "fl": Vector3(0.14, 0.56, 0.42), "hw": 1.0, "sq": -0.15, "lw": 0.8, "legs": [-0.35, -0.3, 0.5, -0.65]}],
		[0.11, {"y": 0.75, "p": -0.48, "r": 0.12, "fl": Vector3(0.0, 0.05, -0.62), "hw": 1.0, "sq": 0.25, "lw": 1.0, "legs": [0.85, -1.0, -0.5, -0.25]}],
		[0.26, {"y": 0.55, "p": -0.35, "fl": Vector3(-0.1, -0.05, -0.5), "hw": 0.9, "sq": 0.05, "lw": 0.9, "legs": [0.75, -0.95, -0.45, -0.25]}],
		[0.55, {}]]},
	# Rink Wall: the 0.2 s tell (gathering low over the feet, the sparkle), then both hands thrown up and
	# out as the ice erupts ahead, an overshoot up on the toes, a settle
	"tm_wall": {"keys": [
		[0.0, {}],
		[0.1, {"p": -0.38, "lift": -0.14, "sq": 0.32, "fl": Vector3(0.1, -0.4, -0.25), "hw": 1.0, "wa": Vector3(-0.6, 0, 0), "lw": 1.0, "legs": [0.9, -1.4, 0.8, -1.3]}],
		[0.2, {"p": -0.42, "lift": -0.14, "sq": 0.35, "fl": Vector3(0.1, -0.42, -0.28), "hw": 1.0, "wa": Vector3(-0.65, 0, 0), "lw": 1.0, "legs": [0.95, -1.45, 0.85, -1.35]}],
		[0.27, {"p": -0.05, "lift": 0.08, "sq": -0.28, "fl": Vector3(0.05, 0.22, -0.62), "hw": 1.0, "wa": Vector3(-0.2, 0, 0), "wo": Vector3(0, 0.05, -0.15), "lw": 0.6, "legs": [0.3, -0.4, -0.2, -0.1]}],
		[0.4, {"p": -0.12, "sq": 0.05, "fl": Vector3(0.05, 0.12, -0.55), "hw": 0.8}],
		[0.7, {}]]},
	# the wall frozen (E again): a stamp of the skate blade with a fist pulled down
	"tm_freeze": {"keys": [
		[0.0, {}],
		[0.07, {"lift": 0.06, "sq": -0.12, "lw": 1.0, "legs": [0.0, -0.1, -1.0, -1.4], "fl": Vector3(0.05, 0.3, -0.15), "hw": 1.0}],
		[0.13, {"lift": -0.08, "sq": 0.35, "p": -0.25, "lw": 1.0, "legs": [0.4, -0.7, 0.5, -0.8], "fl": Vector3(0.05, -0.3, -0.3), "hw": 1.0}],
		[0.42, {}]]},
	# Skate held (looped by the kit every 0.56 s): low and leaning, the legs pushing out one then the
	# other, the arms swinging opposite and the body rocking with each push
	"tm_skate": {"keys": [
		[0.0, {"p": -0.38, "r": 0.12, "y": -0.12, "lift": -0.06, "lw": 1.0, "legs": [0.65, -1.1, -0.35, -0.2], "fl": Vector3(0.1, -0.05, 0.25), "hw": 0.7, "wa": Vector3(0.3, 0.3, 0)}],
		[0.28, {"p": -0.38, "r": -0.12, "y": 0.12, "lift": -0.06, "lw": 1.0, "legs": [-0.35, -0.2, 0.65, -1.1], "fl": Vector3(0.0, 0.0, -0.3), "hw": 0.7, "wa": Vector3(0.3, -0.3, 0)}],
		[0.56, {"p": -0.38, "r": 0.12, "y": -0.12, "lift": -0.06, "lw": 1.0, "legs": [0.65, -1.1, -0.35, -0.2], "fl": Vector3(0.1, -0.05, 0.25), "hw": 0.7, "wa": Vector3(0.3, 0.3, 0)}]]},
	# Skate start: a deep crouch and a hard push off the back blade
	"tm_skate_go": {"keys": [
		[0.0, {"sq": 0.3, "lift": -0.1, "p": -0.2, "lw": 1.0, "legs": [0.9, -1.4, 0.8, -1.3]}],
		[0.08, {"sq": -0.3, "lift": 0.02, "p": -0.5, "lw": 1.0, "legs": [0.8, -0.9, -0.7, -0.1], "fl": Vector3(0.1, 0.05, 0.4), "hw": 1.0}],
		[0.16, {"p": -0.38, "r": 0.12, "y": -0.12, "lift": -0.06, "lw": 1.0, "legs": [0.65, -1.1, -0.35, -0.2], "fl": Vector3(0.1, -0.05, 0.25), "hw": 0.7, "wa": Vector3(0.3, 0.3, 0)}]]},
	# Skate end: a hockey stop, turned side-on, leaning back over braced blades, then up
	"tm_skate_stop": {"keys": [
		[0.0, {"p": -0.38, "lw": 1.0, "legs": [0.65, -1.1, -0.35, -0.2]}],
		[0.08, {"y": 0.75, "r": 0.35, "p": 0.15, "sq": 0.25, "lift": -0.1, "lw": 1.0, "legs": [0.7, -1.1, 0.2, -0.6], "fl": Vector3(-0.3, 0.2, 0.0), "hw": 1.0}],
		[0.2, {"y": 0.6, "r": 0.25, "p": 0.1, "sq": 0.1, "lw": 1.0, "legs": [0.6, -1.0, 0.15, -0.5], "fl": Vector3(-0.28, 0.15, 0.0), "hw": 0.8}],
		[0.45, {}]]},
	# the long air dash (a light hero): a tumbling side flip with the knees tucked, out stretched
	"tm_dash_air": {"keys": [
		[0.0, {"sq": 0.2}],
		[0.05, {"fz": 1.6, "sq": 0.3, "lw": 1.0, "legs": [1.5, -2.1, 1.5, -2.1], "fl": Vector3(0.1, 0.0, -0.1), "hw": 1.0}],
		[0.15, {"fz": 6.28, "sq": -0.25, "lw": 1.0, "legs": [0.3, -0.4, 0.2, -0.3], "fl": Vector3(-0.3, 0.3, 0.0), "hw": 1.0}],
		[0.22, {"fz": 6.28, "sq": 0.3, "lift": -0.05, "lw": 1.0, "legs": [0.6, -1.0, 0.5, -0.9]}],
		[0.4, {"fz": 6.28}]]},
	# Shatter (payoff): the fan snapped shut in a flourish and the free fist clenched
	"tm_shatter": {"keys": [
		[0.0, {}],
		[0.06, {"wa": Vector3(0.3, 0, 1.4), "fl": Vector3(0.1, 0.2, -0.35), "hw": 1.0, "y": -0.15, "sq": -0.1}],
		[0.12, {"wa": Vector3(-0.2, 0, -0.5), "fl": Vector3(0.0, 0.0, 0.1), "hw": 1.0, "y": 0.15, "p": 0.12, "sq": 0.15}],
		[0.4, {}]]},
	# ================================================================ ultimates on X (10 fps beats)
	# Hearth Call held to aim: the lantern hand reaching toward the teammate under the cursor
	"mm_call_aim": {"hold": true, "keys": [
		[0.0, {}],
		[0.1, {"y": 0.2, "p": -0.08, "fl": Vector3(0.1, 0.32, -0.5), "hw": 1.0, "wa": Vector3(0.25, 0, 0)}]]},
	# cast (f25): the hand pulled back low, then thrust high and out as the plus bursts on the ally,
	# an overshoot, then into the channel pose
	"mm_call": {"keys": [
		[0.0, {"y": 0.2, "p": -0.08, "fl": Vector3(0.1, 0.32, -0.5), "hw": 1.0}],
		[0.05, {"y": -0.2, "p": 0.15, "sq": 0.18, "fl": Vector3(0.05, -0.15, 0.25), "hw": 1.0}],
		[0.1, {"y": 0.3, "p": -0.25, "sq": -0.22, "lift": 0.06, "fl": Vector3(0.1, 0.78, -0.3), "hw": 1.0}],
		[0.2, {"y": 0.22, "p": -0.18, "sq": -0.08, "fl": Vector3(0.08, 0.7, -0.22), "hw": 1.0}],
		[0.35, {"p": -0.06, "fl": Vector3(0.06, 0.62, -0.12), "hw": 1.0, "wa": Vector3(0.3, 0, 0.2)}]]},
	# the channel (f26-f73): one hand held high over the tether, the crook tipped back; the legs keep
	# walking (no leg channel)
	"mm_call_hold": {"hold": true, "keys": [
		[0.0, {"p": -0.06, "fl": Vector3(0.06, 0.62, -0.12), "hw": 1.0, "wa": Vector3(0.3, 0, 0.2)}],
		[0.3, {"p": -0.08, "r": 0.04, "fl": Vector3(0.04, 0.66, -0.1), "hw": 1.0, "wa": Vector3(0.34, 0, 0.18)}]]},
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
		[0.12, {"p": -0.3, "sq": -0.3, "lift": 0.1, "fl": Vector3(-0.3, 0.7, 0.05), "hw": 1.0, "wa": Vector3(-0.6, 0, 0.8),
			"lw": 1.0, "legs": [-0.1, -0.2, 0.1, -0.2]}],
		[0.2, {"p": 0.35, "sq": 0.2, "lift": -0.08, "fl": Vector3(0.28, 0.1, -0.22), "hw": 1.0, "wa": Vector3(0.5, 0, -0.4),
			"lw": 1.0, "legs": [0.7, -1.1, 0.6, -1.0]}]]},
	# sealed in (f27-f55): hunched over, arms crossed on the chest, the fan folded in, knees bent
	"tm_rime_hold": {"hold": true, "keys": [
		[0.0, {"p": 0.35, "sq": 0.2, "lift": -0.08, "fl": Vector3(0.28, 0.1, -0.22), "hw": 1.0, "wa": Vector3(0.5, 0, -0.4),
			"lw": 1.0, "legs": [0.7, -1.1, 0.6, -1.0]}],
		[0.4, {"p": 0.38, "r": 0.03, "sq": 0.24, "lift": -0.1, "fl": Vector3(0.3, 0.08, -0.2), "hw": 1.0,
			"wa": Vector3(0.55, 0, -0.42), "lw": 1.0, "legs": [0.75, -1.15, 0.65, -1.05]}]]},
	# the crash (f57): a deeper crouch, then everything flung wide as the shell bursts, an overshoot up
	# on the toes, settled by recovery (f61)
	"tm_rime_crash": {"keys": [
		[0.0, {"p": 0.38, "sq": 0.24, "lift": -0.1, "fl": Vector3(0.3, 0.08, -0.2), "hw": 1.0, "lw": 1.0,
			"legs": [0.75, -1.15, 0.65, -1.05]}],
		[0.04, {"p": 0.45, "sq": 0.35, "lift": -0.16, "fl": Vector3(0.2, -0.05, -0.15), "hw": 1.0, "lw": 1.0,
			"legs": [0.95, -1.4, 0.85, -1.3]}],
		[0.1, {"p": -0.4, "sq": -0.35, "lift": 0.14, "fl": Vector3(-0.45, 0.65, 0.15), "hw": 1.0, "wa": Vector3(-0.8, 0, 1.2),
			"lw": 1.0, "legs": [-0.2, -0.15, -0.25, -0.1]}],
		[0.2, {"p": -0.22, "sq": -0.12, "lift": 0.06, "fl": Vector3(-0.35, 0.5, 0.1), "hw": 0.8, "wa": Vector3(-0.5, 0, 0.8),
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
