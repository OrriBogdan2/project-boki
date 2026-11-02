class_name KMovesPinBjorn
extends RefCounted
## Keyed full-body moves of Pin (archer) and Bjorn (bulwark): the same format and channels as
## HunterAnim.KMOVES (looked up by HunterAnim.km_sample). Timed to the hero sheets' 5 fps footage frames
## (one frame = 0.2 s): anticipation, a key pose on the release, overshoot, follow-through and settle.
## fl / fr place a free hand from its shoulder (hw / rw their weight), gp pitches the weapon.

const MOVES := {
	# ---------------------------------------------------------------- Pin (archer; hero sheet pin.md, 5 fps footage)
	# the bow drawn: side-on to the cursor, the bow arm out at it, the string hand pulled back to the chest
	# (0.2 s, one footage frame, then held while drawing; a touch deeper by Empowered)
	"arc_draw": {"hold": true, "keys": [
		[0.0, {}],
		[0.2, {"p": 0.08, "y": 0.55, "lw": 1.0, "legs": [0.35, -0.5, -0.3, -0.3], "hw": 1.0, "fl": Vector3(0.12, 0.16, 0.12)}],
		[0.6, {"p": 0.12, "y": 0.62, "lw": 1.0, "legs": [0.4, -0.55, -0.3, -0.3], "hw": 1.0, "fl": Vector3(0.16, 0.17, 0.2)}]]},
	# the string let go: the hand snaps back open (one frame), no big recoil, then settles
	"arc_loose": {"keys": [
		[0.0, {"p": 0.12, "y": 0.62, "lw": 1.0, "legs": [0.4, -0.55, -0.3, -0.3], "hw": 1.0, "fl": Vector3(0.16, 0.17, 0.2)}],
		[0.05, {"p": 0.18, "y": 0.5, "lw": 1.0, "legs": [0.4, -0.5, -0.3, -0.3], "hw": 1.0, "fl": Vector3(0.26, 0.14, 0.34)}],
		[0.22, {"p": 0.06, "y": 0.3, "lw": 0.6, "hw": 0.5, "fl": Vector3(0.2, 0.05, 0.2)}],
		[0.42, {}]]},
	# a Supercharged release: the body kicks back hard, a half step back, the hand flung wide behind
	"arc_super": {"keys": [
		[0.0, {"p": 0.12, "y": 0.62, "lw": 1.0, "legs": [0.4, -0.55, -0.3, -0.3], "hw": 1.0, "fl": Vector3(0.16, 0.17, 0.2)}],
		[0.05, {"p": 0.38, "y": 0.35, "lift": 0.04, "sq": -0.16, "lw": 1.0, "legs": [0.15, -0.35, -0.55, -0.4], "hw": 1.0, "fl": Vector3(0.32, 0.2, 0.42), "gp": 0.15}],
		[0.25, {"p": 0.15, "y": 0.2, "sq": 0.08, "lw": 0.8, "legs": [0.4, -0.6, -0.3, -0.4], "hw": 0.6, "fl": Vector3(0.2, 0.05, 0.25)}],
		[0.6, {}]]},
	# the Heavy Shot's draw: like the bow draw but sunk low, weight back, the shoulders turned hard (holds)
	"arc_heavy_wind": {"hold": true, "keys": [
		[0.0, {}],
		[0.2, {"p": 0.18, "y": 0.6, "lift": -0.1, "sq": 0.15, "lw": 1.0, "legs": [0.8, -1.2, -0.5, -0.7], "hw": 1.0, "fl": Vector3(0.14, 0.16, 0.18)}],
		[1.1, {"p": 0.26, "y": 0.66, "lift": -0.16, "sq": 0.24, "lw": 1.0, "legs": [0.9, -1.3, -0.55, -0.8], "hw": 1.0, "fl": Vector3(0.2, 0.18, 0.3)}]]},
	# ... let go: thrown back by the shot (one frame), then planting out of it
	"arc_heavy": {"keys": [
		[0.0, {"p": 0.26, "y": 0.66, "lift": -0.16, "sq": 0.24, "lw": 1.0, "legs": [0.9, -1.3, -0.55, -0.8], "hw": 1.0, "fl": Vector3(0.2, 0.18, 0.3)}],
		[0.06, {"p": 0.5, "y": 0.15, "lift": 0.05, "sq": -0.2, "lw": 1.0, "legs": [0.5, -0.5, -0.4, -0.2], "hw": 1.0, "fl": Vector3(0.34, 0.1, 0.45), "gp": 0.2}],
		[0.28, {"p": 0.25, "lift": -0.05, "lw": 0.8, "legs": [0.6, -0.8, -0.3, -0.4]}],
		[0.6, {}]]},
	# the snare: a quick flick of the bow hand, a half-step forward
	"arc_snare": {"keys": [
		[0.0, {"p": 0.1, "y": 0.2}],
		[0.07, {"p": -0.3, "y": -0.2, "lw": 0.7, "legs": [0.6, -0.5, -0.4, -0.2]}],
		[0.3, {}]]},
	# Hail Wall: the bow raised high, the body arching back, the volley lobbed up in an arc, then down
	"arc_hail": {"keys": [
		[0.0, {"p": 0.1}],
		[0.12, {"p": 0.42, "lift": 0.06, "gp": 0.9, "hw": 1.0, "fl": Vector3(0.05, 0.5, 0.05), "lw": 0.8, "legs": [0.3, -0.5, 0.3, -0.5]}],
		[0.24, {"p": 0.3, "gp": 1.1, "hw": 1.0, "fl": Vector3(0.12, 0.45, 0.2), "sq": -0.1, "lw": 0.8, "legs": [0.4, -0.5, 0.1, -0.4]}],
		[0.6, {}]]},
	# Spirit Walk's dodge roll: tucked into one forward roll in 0.16 s, then up and light on the feet
	"pin_roll": {"keys": [
		[0.0, {"p": -0.35, "sq": 0.25, "lw": 1.0, "legs": [0.9, -1.3, 0.9, -1.3]}],
		[0.05, {"p": -0.5, "fx": 2.2, "sq": 0.35, "lift": 0.05, "lw": 1.0, "legs": [1.4, -1.9, 1.4, -1.9], "hw": 1.0, "fl": Vector3(0.0, -0.1, -0.2)}],
		[0.16, {"p": -0.2, "fx": 6.28, "sq": 0.1, "lw": 1.0, "legs": [0.7, -1.0, 0.7, -1.0]}],
		[0.3, {"p": -0.15, "fx": 6.28, "lw": 0.5, "legs": [0.4, -0.5, -0.2, -0.3]}],
		[0.42, {"fx": 6.28}]]},
	# the plunge: shooting straight down, folded over the bow
	"arc_plunge": {"keys": [
		[0.0, {"p": -0.5, "sq": 0.2, "lw": 1.0, "legs": [1.0, -1.4, 1.0, -1.4]}],
		[0.12, {"p": -0.9, "sq": 0.4, "lw": 1.0, "legs": [1.2, -1.7, 1.2, -1.7]}],
		[0.45, {}]]},
	# ---------------------------------------------------------------- Bjorn (bulwark; hero sheet bjorn.md)
	# the hammer thrown: cocked low and behind for one frame, then an overhand throw, arm forward
	"bul_throw": {"keys": [
		[0.0, {}],
		[0.1, {"y": 0.75, "p": 0.25, "gp": 0.9, "lw": 1.0, "legs": [0.3, -0.5, -0.3, -0.3]}],
		[0.2, {"y": -0.7, "p": -0.42, "gp": -0.6, "sq": 0.15, "lw": 1.0, "legs": [0.85, -0.7, -0.5, -0.3]}],
		[0.38, {"y": -0.3, "p": -0.15, "gp": -0.2, "lw": 0.6}],
		[0.6, {}]]},
	# the hammer called back: the free hand reaches out, then draws in and catches
	"bul_recall": {"keys": [
		[0.0, {"hw": 1.0, "fl": Vector3(0.05, 0.1, -0.55), "p": -0.1}],
		[0.2, {"hw": 1.0, "fl": Vector3(0.05, 0.1, -0.6), "p": -0.15}],
		[0.34, {"hw": 1.0, "fl": Vector3(-0.05, -0.05, -0.15), "p": 0.1, "sq": 0.12}],
		[0.55, {}]]},
	# LMB held (owner note): spinning the hammer, side-on and crouched, the hammer arm out to the side, the
	# shield arm forward; the hammer turns in the hand (BjornFx) while the body keeps facing the cursor
	"bul_smash_wind": {"hold": true, "keys": [
		[0.0, {}],
		[0.2, {"y": 0.75, "p": 0.12, "lift": -0.06, "sq": 0.1, "gp": 0.25, "lw": 1.0, "legs": [0.55, -0.85, -0.45, -0.5], "hw": 1.0, "fl": Vector3(-0.05, 0.12, -0.42)}],
		[1.25, {"y": 0.85, "p": 0.18, "lift": -0.1, "sq": 0.16, "gp": 0.3, "lw": 1.0, "legs": [0.65, -0.95, -0.5, -0.55], "hw": 1.0, "fl": Vector3(-0.05, 0.14, -0.45)}]]},
	# ... let go: the hammer sweeps round from behind to the front in one frame and crashes down, the body
	# lunging after it, the impact the frame after, then 0.4 s to recover
	"bul_smash": {"keys": [
		[0.0, {"y": 0.85, "p": 0.18, "lift": -0.1, "sq": 0.16, "gp": 0.3, "lw": 1.0, "legs": [0.65, -0.95, -0.5, -0.55], "hw": 1.0, "fl": Vector3(-0.05, 0.14, -0.45)}],
		[0.08, {"y": -0.65, "p": -0.35, "lift": -0.14, "sq": 0.45, "gp": -0.9, "lw": 1.0, "legs": [1.15, -1.5, -0.45, -0.9]}],
		[0.16, {"y": -0.55, "p": -0.3, "lift": -0.12, "sq": 0.3, "gp": -0.8, "lw": 1.0, "legs": [1.1, -1.4, -0.4, -0.85]}],
		[0.55, {}]]},
	# the aegis raised: braced low behind it, the shield arm out front (holds while it's up)
	"bul_guard": {"hold": true, "keys": [
		[0.0, {}],
		[0.12, {"p": -0.18, "lift": -0.06, "sq": 0.1, "y": -0.2, "lw": 1.0, "legs": [0.6, -0.9, -0.4, -0.5], "hw": 1.0, "fl": Vector3(0.0, 0.15, -0.48)}]]},
	# the Bash: a short-stepped shoulder shove behind the shield
	"bul_bash": {"keys": [
		[0.0, {"p": 0.15, "y": 0.3, "lw": 1.0, "legs": [0.2, -0.4, -0.1, -0.2]}],
		[0.07, {"p": -0.45, "y": -0.2, "sq": 0.3, "lw": 1.0, "legs": [0.9, -0.9, -0.5, -0.4], "hw": 1.0, "fl": Vector3(0.0, 0.1, -0.6)}],
		[0.28, {"p": -0.2, "lw": 0.7}],
		[0.5, {}]]},
	# 360 Smash: the short dash leaning in (0.23 s), then ONE full turn with the hammer out, low and braced
	"bul_whirl": {"keys": [
		[0.0, {"p": -0.12, "sq": 0.15, "lw": 1.0, "legs": [0.9, -0.8, -0.6, -0.4]}],
		[0.26, {"p": -0.15, "fy": 0.0, "y": 0.6, "sq": 0.2, "lw": 1.0, "legs": [0.7, -0.9, -0.4, -0.5]}],
		[0.34, {"p": -0.1, "fy": 3.1, "sq": 0.15, "gp": 0.3, "lw": 1.0, "legs": [0.6, -0.8, -0.3, -0.4]}],
		[0.42, {"p": -0.08, "fy": 6.28, "sq": 0.1, "lw": 1.0, "legs": [0.5, -0.7, -0.3, -0.4]}],
		[0.66, {"fy": 6.28}]]},
	# the Shield Charge: head down, the whole body a ram
	"bul_charge": {"keys": [
		[0.0, {"p": -0.5, "y": 0.2, "sq": 0.2, "lw": 1.0, "legs": [0.8, -1.0, -0.6, -0.4]}],
		[0.16, {"p": -0.7, "sq": 0.3, "lw": 1.0, "legs": [1.1, -1.1, -0.8, -0.3]}],
		[0.34, {"p": -0.3, "lw": 0.6, "legs": [0.7, -0.8, -0.4, -0.3]}],
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
		[0.16, {"lift": 0.14, "p": 0.35, "sq": -0.22, "gp": 1.3, "hw": 1.0, "fl": Vector3(0.0, 0.55, -0.1), "lw": 1.0, "legs": [-0.1, -0.2, 0.2, -0.3]}],
		[0.26, {"lift": -0.16, "p": -0.6, "sq": 0.42, "gp": -1.0, "hw": 1.0, "fl": Vector3(0.0, -0.45, -0.4), "lw": 1.0, "legs": [1.0, -1.4, -0.4, -0.9]}],
		[0.45, {"lift": -0.1, "p": -0.45, "sq": 0.25, "gp": -0.8, "hw": 0.8, "fl": Vector3(0.0, -0.35, -0.35), "lw": 1.0, "legs": [0.9, -1.2, -0.35, -0.8]}],
		[0.95, {}]]},
	# ---------------------------------------------------------------- Pin: the other LMB variants, procs and payoffs
	# a tap shot (let go before Empowered): a quick snap of the bow hand, half side-on, a little hop of the heel
	"arc_tap": {"keys": [
		[0.0, {"y": 0.3, "hw": 0.8, "fl": Vector3(0.08, 0.14, 0.1)}],
		[0.04, {"y": 0.15, "p": 0.1, "sq": -0.08, "hw": 1.0, "fl": Vector3(0.2, 0.12, 0.26), "lw": 0.6, "legs": [0.2, -0.3, -0.1, -0.2]}],
		[0.2, {"y": 0.05, "p": -0.04, "sq": 0.05}],
		[0.34, {}]]},
	# a perfect release: the string hand flung up and open in a flourish, the chest lifted, a spin of the bow
	# hand and a proud settle (the gold star shows beside the bow hand)
	"arc_perfect": {"keys": [
		[0.0, {"p": 0.12, "y": 0.62, "lw": 1.0, "legs": [0.4, -0.55, -0.3, -0.3], "hw": 1.0, "fl": Vector3(0.16, 0.17, 0.2)}],
		[0.06, {"p": 0.3, "y": 0.4, "lift": 0.06, "sq": -0.18, "lw": 1.0, "legs": [0.3, -0.4, -0.35, -0.3], "hw": 1.0, "fl": Vector3(0.3, 0.45, 0.3), "gp": 0.35}],
		[0.2, {"p": -0.08, "y": 0.1, "lift": -0.02, "sq": 0.1, "r": 0.12, "hw": 1.0, "fl": Vector3(0.25, 0.3, 0.05), "gp": -0.15, "lw": 0.8, "legs": [0.4, -0.6, -0.2, -0.3]}],
		[0.36, {"p": 0.04, "r": -0.04, "hw": 0.5, "fl": Vector3(0.12, 0.1, 0.05)}],
		[0.55, {}]]},
	# overdrawn: the draw arm starts to shake, the chest sags, the bow dips (held while drawing on)
	"arc_over": {"hold": true, "keys": [
		[0.0, {"p": 0.12, "y": 0.62, "lw": 1.0, "legs": [0.4, -0.55, -0.3, -0.3], "hw": 1.0, "fl": Vector3(0.16, 0.17, 0.2)}],
		[0.08, {"p": 0.02, "y": 0.58, "r": 0.06, "lw": 1.0, "legs": [0.45, -0.6, -0.3, -0.35], "hw": 1.0, "fl": Vector3(0.14, 0.12, 0.17), "gp": -0.12}],
		[0.16, {"p": 0.08, "y": 0.64, "r": -0.05, "lw": 1.0, "legs": [0.45, -0.6, -0.3, -0.35], "hw": 1.0, "fl": Vector3(0.16, 0.15, 0.19), "gp": -0.08}],
		[0.24, {"p": -0.02, "y": 0.57, "r": 0.06, "lw": 1.0, "legs": [0.5, -0.65, -0.3, -0.35], "hw": 1.0, "fl": Vector3(0.13, 0.1, 0.16), "gp": -0.16}],
		[0.32, {"p": 0.05, "y": 0.62, "r": -0.04, "lw": 1.0, "legs": [0.5, -0.65, -0.3, -0.35], "hw": 1.0, "fl": Vector3(0.15, 0.13, 0.18), "gp": -0.12}],
		[0.42, {"p": -0.05, "y": 0.56, "sq": 0.08, "lw": 1.0, "legs": [0.55, -0.7, -0.3, -0.4], "hw": 1.0, "fl": Vector3(0.12, 0.08, 0.15), "gp": -0.2}]]},
	# ...and let go: a weak, drooping release, the bow arm falling, a shake of the head
	"arc_over_loose": {"keys": [
		[0.0, {"p": -0.05, "y": 0.56, "sq": 0.08, "lw": 1.0, "legs": [0.55, -0.7, -0.3, -0.4], "hw": 1.0, "fl": Vector3(0.12, 0.08, 0.15), "gp": -0.2}],
		[0.06, {"p": -0.18, "y": 0.4, "sq": 0.14, "lw": 0.9, "hw": 1.0, "fl": Vector3(0.1, -0.05, 0.2), "gp": -0.5}],
		[0.3, {"p": -0.1, "y": 0.15, "r": 0.08, "sq": 0.06, "gp": -0.3}],
		[0.55, {}]]},
	# Spirit Walk after the roll: light on the toes, leaning in, arms trailing like a ghost (held while it lasts)
	"pin_walk": {"hold": true, "keys": [
		[0.0, {"p": -0.15, "fx": 6.28, "lw": 0.5, "legs": [0.4, -0.5, -0.2, -0.3]}],
		[0.2, {"p": -0.25, "lift": 0.08, "sq": -0.08, "hw": 0.9, "fl": Vector3(-0.15, -0.1, 0.35), "rw": 0.9, "fr": Vector3(0.15, -0.1, 0.35)}]]},
	# the base long dash (in the air, or out of Spirit Walk charges): a quick flick and a sideways tumble
	"pin_flick": {"keys": [
		[0.0, {"p": -0.2, "sq": 0.2, "lw": 1.0, "legs": [0.7, -1.0, 0.2, -0.4]}],
		[0.05, {"p": -0.35, "fz": 1.6, "sq": -0.25, "lift": 0.06, "lw": 1.0, "legs": [1.2, -1.6, 1.0, -1.5], "hw": 1.0, "fl": Vector3(-0.2, 0.3, 0.0)}],
		[0.18, {"p": -0.15, "fz": 6.28, "sq": 0.15, "lw": 1.0, "legs": [0.6, -0.9, 0.3, -0.5]}],
		[0.32, {"fz": 6.28, "sq": -0.05}],
		[0.42, {"fz": 6.28}]]},
	# Deadeye (the payoff): the bow thrust out at the target, the body locked low and still, then a slow rise
	"pin_deadeye": {"keys": [
		[0.0, {}],
		[0.05, {"p": -0.12, "y": 0.7, "lift": -0.1, "sq": 0.2, "lw": 1.0, "legs": [0.8, -1.2, -0.5, -0.6], "hw": 1.0, "fl": Vector3(0.3, 0.25, 0.4), "gp": 0.1}],
		[0.4, {"p": -0.1, "y": 0.68, "lift": -0.1, "sq": 0.18, "lw": 1.0, "legs": [0.8, -1.2, -0.5, -0.6], "hw": 0.8, "fl": Vector3(0.28, 0.22, 0.38)}],
		[0.75, {}]]},
	# a knock run down (passive): a quick pumped fist and a skip
	"pin_rundown": {"keys": [
		[0.0, {}],
		[0.1, {"lift": 0.12, "p": 0.15, "sq": -0.15, "hw": 1.0, "fl": Vector3(0.05, 0.6, 0.0), "lw": 0.8, "legs": [-0.2, -0.4, 0.6, -0.9]}],
		[0.22, {"lift": 0.0, "p": -0.05, "sq": 0.12, "hw": 1.0, "fl": Vector3(0.05, 0.35, -0.05)}],
		[0.45, {}]]},
	# ---------------------------------------------------------------- Bjorn: procs, payoffs and the base dash
	# Crushed (the payoff): the hammer swung up overhead in triumph, a stamp, the chest out
	"bul_crush": {"keys": [
		[0.0, {}],
		[0.1, {"p": 0.35, "lift": 0.1, "sq": -0.2, "gp": 1.4, "lw": 1.0, "legs": [0.2, -0.3, 0.1, -0.2]}],
		[0.22, {"p": -0.2, "lift": -0.08, "sq": 0.3, "gp": 0.9, "lw": 1.0, "legs": [0.8, -1.1, -0.3, -0.6]}],
		[0.6, {}]]},
	# the Shield Slam (Guard 50): the 0.3 s tell, shield drawn in to the chest and the weight rocked back,
	# then a full-body drive behind it
	"bul_slamshield": {"keys": [
		[0.0, {}],
		[0.25, {"p": 0.32, "y": 0.45, "lift": 0.04, "sq": -0.12, "lw": 1.0, "legs": [-0.1, -0.3, 0.5, -0.7], "hw": 1.0, "fl": Vector3(0.05, 0.15, -0.1)}],
		[0.33, {"p": -0.6, "y": -0.3, "lift": -0.08, "sq": 0.42, "lw": 1.0, "legs": [1.1, -1.0, -0.6, -0.4], "hw": 1.0, "fl": Vector3(0.0, 0.12, -0.7)}],
		[0.55, {"p": -0.35, "y": -0.15, "sq": 0.18, "hw": 0.8, "fl": Vector3(0.0, 0.1, -0.5)}],
		[0.85, {}]]},
	# the aegis broken: rocked back, the shield arm flung wide, a stagger and recover
	"bul_break": {"keys": [
		[0.0, {}],
		[0.06, {"p": 0.45, "y": 0.3, "r": 0.15, "sq": -0.1, "hw": 1.0, "fl": Vector3(-0.4, 0.3, 0.2), "lw": 1.0, "legs": [-0.3, -0.2, 0.5, -0.8]}],
		[0.3, {"p": 0.2, "r": -0.08, "hw": 0.6, "fl": Vector3(-0.2, 0.0, 0.0), "lw": 0.8, "legs": [0.3, -0.6, 0.2, -0.4]}],
		[0.65, {}]]},
	# a Guard pip lighting up (the passive filling): a brief shrug of the shield up into place
	"bul_armed": {"keys": [
		[0.0, {}],
		[0.1, {"p": -0.08, "lift": 0.04, "sq": -0.08, "hw": 1.0, "fl": Vector3(0.0, 0.25, -0.35)}],
		[0.35, {}]]},
	# the base long dash: a lumbering shoulder shove, head down, the hammer trailing
	"bul_lumber": {"keys": [
		[0.0, {"p": -0.1, "y": 0.45, "sq": 0.2, "lw": 1.0, "legs": [0.8, -1.0, -0.5, -0.4], "gp": 0.4}],
		[0.12, {"p": -0.2, "y": 0.6, "sq": 0.3, "lift": -0.06, "lw": 1.0, "legs": [1.1, -0.9, -0.7, -0.3], "hw": 1.0, "fl": Vector3(0.1, 0.0, -0.3), "gp": 0.5}],
		[0.3, {"p": -0.12, "y": 0.3, "sq": 0.35, "lift": -0.1, "lw": 1.0, "legs": [0.9, -1.3, -0.4, -0.8]}],
		[0.5, {"sq": -0.05}],
		[0.6, {}]]},
}
