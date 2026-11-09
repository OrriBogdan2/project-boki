class_name KMovesPair
extends RefCounted
## Keyed full-body moves of Dredge and Cinder (id ashwick), in the same format and channels as
## HunterAnim.KMOVES (looked up by HunterAnim.km_sample). Timed to the reference sheets' beats:
## anticipation, release (with an overshoot key), follow-through, recovery (settle). fl / fr place a
## free hand from its shoulder (hw / rw their weight; -z is forward, +x the hunter's right), p is the
## body pitch (negative = leaning forward), y the twist, lift the hips' rise, sq squash (+) or stretch
## (-), gp the weapon's pitch kick. Held moves with "loop" cycle their last keys (HunterAnim._km_held_t).

const KIT_MOVE_LIFE := 0.5     # s a kit move owns the body before a plain jump or landing may replace it
const JUMP_UP := 3.0            # m/s up off the ground that counts as a jump (not a step down)

## Plays a hero's own plain jump and landing (not in the footage; built from the character, docs Assumptions):
## the jump on leaving the ground upward, the landing on touching down, never over a kit move still playing.
static func air_moves(k: ArchKit, jump_id: String, land_id: String) -> void:
	var h := k.h
	var was_grounded: bool = k.st.get("on_ground", true)
	k.st["on_ground"] = h.grounded
	if was_grounded == h.grounded or h.roll_t > 0.0:
		return
	var body_free: bool = k.anim_id in ["", jump_id] or k.m.time - k.anim_at > KIT_MOVE_LIFE
	if not body_free:
		return
	if not h.grounded and h.vel.y > JUMP_UP:
		k.play(jump_id)
	elif h.grounded and k.anim_id == jump_id:
		k.play(land_id)

const MOVES := {
	# ================================================================= Dredge
	# Scattergun (LMB, every shot, 0.5 s cycle): the barrel kicks up, the torso rocks back and turns side-on,
	# then swings back to the aim in about 0.2 s (sheet 0045, 0080)
	"dr_shot": {"keys": [
		[0.0, {"p": 0.06, "gp": 0.1, "sq": 0.05}],
		[0.05, {
			"p": 0.3, "y": 0.8, "gp": 0.75, "sq": 0.18, "lift": -0.04, "fl": Vector3(-0.2, 0.05, -0.3), "hw": 0.6,
			"lw": 0.8, "legs": [0.4, -0.7, -0.5, -0.3]
		}],
		[0.14, {"p": 0.18, "y": 0.55, "gp": 0.35, "sq": 0.06, "lw": 0.7, "legs": [0.4, -0.7, -0.5, -0.3]}],
		[0.24, {"p": -0.05, "y": -0.06, "gp": -0.05, "sq": -0.03}],
		[0.36, {}]]},
	# Abyssal Hand throw (RMB): the gun swings to the off side, the free arm coils back (0.08 s), then punches
	# out along the aim and stays out while the arm flies (0.4 s to full reach)
	"dr_throw": {"keys": [
		[0.0, {}],
		[0.08, {
			"y": -0.9, "p": 0.2, "fl": Vector3(-0.2, 0.3, 0.45), "hw": 1.0, "fr": Vector3(0.35, -0.05, 0.05),
			"rw": 0.8, "sq": 0.25, "lw": 1.0, "legs": [0.6, -0.9, -0.4, -0.4]
		}],
		[0.14, {
			"y": 0.9, "p": -0.5, "fl": Vector3(0.05, 0.12, -1.05), "hw": 1.0, "fr": Vector3(0.35, -0.1, 0.15),
			"rw": 0.8, "sq": -0.25, "lw": 1.0, "legs": [1.0, -0.8, -0.7, -0.2]
		}],
		[0.22, {
			"y": 0.7, "p": -0.42, "fl": Vector3(0.05, 0.1, -0.98), "hw": 1.0, "fr": Vector3(0.3, -0.1, 0.1), "rw": 0.8,
			"sq": -0.1, "lw": 1.0, "legs": [0.95, -0.85, -0.65, -0.25]
		}],
		[0.45, {
			"y": 0.45, "p": -0.25, "fl": Vector3(0.05, 0.1, -0.9), "hw": 1.0, "fr": Vector3(0.3, -0.1, 0.1), "rw": 0.7,
			"lw": 1.0, "legs": [0.9, -0.85, -0.6, -0.3]
		}],
		[0.7, {}]]},
	# the reel: side-on to the target, braced and leaning back, hauling hand over hand (one haul each 0.26 s,
	# looped for as long as he reels): the reaching hand far forward, the hauling hand back at the hip
	"dr_reel": {"hold": true, "loop": 0.18, "keys": [
		[0.0, {
			"y": 0.45, "p": -0.2, "fl": Vector3(0.05, 0.1, -0.9), "hw": 1.0, "lw": 1.0,
			"legs": [0.9, -0.85, -0.6, -0.3]
		}],
		[0.18, {
			"p": 0.5, "y": 0.75, "lift": -0.16, "fl": Vector3(-0.05, 0.2, -0.95), "hw": 1.0,
			"fr": Vector3(0.1, -0.5, 0.35), "rw": 0.9, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.28
		}],
		[0.44, {
			"p": 0.25, "y": 0.35, "lift": -0.1, "fl": Vector3(-0.1, -0.5, 0.35), "hw": 1.0,
			"fr": Vector3(0.05, 0.2, -0.95), "rw": 0.9, "lw": 1.0, "legs": [0.85, -1.1, -0.7, -0.5], "sq": 0.1
		}],
		[0.70, {
			"p": 0.5, "y": 0.75, "lift": -0.16, "fl": Vector3(-0.05, 0.2, -0.95), "hw": 1.0,
			"fr": Vector3(0.1, -0.5, 0.35), "rw": 0.9, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.28
		}]]},
	# the foe arrives: a last yank back, then a settle
	"dr_pullend": {"keys": [
		[0.0, {
			"p": 0.4, "y": 0.5, "fl": Vector3(-0.05, -0.2, -0.2), "hw": 1.0, "lw": 1.0,
			"legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.25
		}],
		[0.08, {
			"p": 0.52, "y": 0.3, "fl": Vector3(-0.1, -0.1, 0.15), "hw": 1.0, "lw": 1.0, "legs": [0.7, -1.1, -0.7, -0.5],
			"sq": -0.1
		}],
		[0.22, {"p": -0.08, "sq": 0.05}],
		[0.36, {}]]},
	# Anchor Drop (E, 0.38 s to impact, planted): the free fist raised high, the shoulder turned away; up on the
	# toes at the top (0.3); the fist driven down into the ground in front (0.38, the slam frame); a recoil
	# bounce (0.48), then a slow recovery
	"dr_anchor": {"keys": [
		[0.0, {}],
		[0.12, {
			"y": -0.6, "p": 0.22, "fl": Vector3(-0.1, 1.0, 0.15), "hw": 1.0, "fr": Vector3(0.3, 0.1, 0.1), "rw": 0.7,
			"sq": 0.2, "lw": 1.0, "legs": [0.9, -1.3, 0.7, -1.2]
		}],
		[0.3, {
			"y": -0.8, "p": 0.38, "fl": Vector3(-0.15, 1.2, 0.35), "hw": 1.0, "fr": Vector3(0.35, 0.2, 0.0), "rw": 0.7,
			"sq": -0.15, "lift": 0.06, "lw": 1.0, "legs": [1.0, -1.5, 0.8, -1.4]
		}],
		[0.38, {
			"y": 0.35, "p": -0.9, "fl": Vector3(0.1, -0.65, -0.8), "hw": 1.0, "fr": Vector3(0.25, -0.3, -0.3),
			"rw": 0.7, "sq": 0.65, "lift": -0.25, "lw": 1.0, "legs": [1.2, -1.7, -0.45, -1.0]
		}],
		[0.48, {
			"y": 0.3, "p": -0.7, "fl": Vector3(0.1, -0.45, -0.7), "hw": 1.0, "fr": Vector3(0.25, -0.2, -0.25),
			"rw": 0.7, "sq": 0.35, "lift": -0.14, "lw": 1.0, "legs": [1.1, -1.6, -0.4, -0.95]
		}],
		[0.75, {"p": -0.2, "fl": Vector3(0.05, 0.1, -0.3), "hw": 0.5, "sq": 0.1, "lift": -0.03}],
		[1.0, {}]]},
	# Anchor Drop in the air: both fists locked overhead, knees up, dropping like a stone (held to the ground)
	"dr_dive": {"hold": true, "keys": [
		[0.0, {
			"p": 0.2, "fl": Vector3(-0.1, 0.6, 0.1), "hw": 1.0, "fr": Vector3(0.1, 0.6, 0.1), "rw": 1.0, "sq": 0.3,
			"lw": 1.0, "legs": [1.0, -1.5, 0.9, -1.5]
		}],
		[0.12, {
			"p": -0.35, "fl": Vector3(0.0, 0.95, -0.15), "hw": 1.0, "fr": Vector3(0.0, 0.95, -0.15), "rw": 1.0,
			"sq": -0.35, "lw": 1.0, "legs": [1.3, -1.9, 1.2, -1.9]
		}],
		[0.3, {
			"p": -0.45, "fl": Vector3(0.0, 1.0, -0.2), "hw": 1.0, "fr": Vector3(0.0, 1.0, -0.2), "rw": 1.0, "sq": -0.3,
			"lw": 1.0, "legs": [1.3, -1.9, 1.2, -1.9]
		}]]},
	# the air smash lands with the anchor: a huge squash, fists buried in the ground, then a heave back up
	"dr_quake": {"keys": [
		[0.0, {
			"p": -0.95, "fl": Vector3(0.05, -0.75, -0.6), "hw": 1.0, "fr": Vector3(-0.05, -0.75, -0.6), "rw": 1.0,
			"sq": 0.8, "lift": -0.3, "lw": 1.0, "legs": [1.3, -2.0, 1.1, -1.9]
		}],
		[0.3, {
			"p": -0.7, "fl": Vector3(0.05, -0.7, -0.55), "hw": 0.9, "fr": Vector3(-0.05, -0.7, -0.55), "rw": 0.9,
			"sq": 0.45, "lift": -0.22, "lw": 1.0, "legs": [1.2, -1.8, 1.0, -1.7]
		}],
		[0.55, {"p": 0.12, "sq": -0.12, "lift": 0.06}],
		[0.75, {}]]},
	# Barge (Shift, one fast 0.18 s lunge of a run of them): a monster's lunge, low to the ground, both hands
	# reaching far ahead and clawing at the turf, then hauling the bulk along after them; he lands on his
	# knuckles in a squat (0.18, the dash's end) and is back up by 0.38 for the next one
	"dr_lunge": {"keys": [
		[0.0, {
			"p": -0.5, "sq": 0.35, "lift": -0.15, "fl": Vector3(-0.25, -0.2, -0.5), "hw": 1.0,
			"fr": Vector3(0.25, -0.2, -0.5), "rw": 0.9, "lw": 1.0, "legs": [1.1, -1.6, 0.9, -1.5]
		}],
		[0.04, {
			"p": -1.05, "sq": -0.2, "lift": -0.06, "fl": Vector3(-0.3, -0.55, -1.15), "hw": 1.0,
			"fr": Vector3(0.3, -0.45, -0.95), "rw": 0.9, "lw": 1.0, "legs": [-0.6, -0.3, 0.7, -1.3]
		}],
		[0.11, {
			"p": -0.95, "sq": -0.05, "lift": -0.1, "fl": Vector3(-0.25, -0.75, -0.55), "hw": 1.0,
			"fr": Vector3(0.3, -0.6, -1.05), "rw": 0.9, "lw": 1.0, "legs": [0.9, -1.5, -0.6, -0.4]
		}],
		[0.18, {
			"p": -0.6, "sq": 0.45, "lift": -0.2, "fl": Vector3(-0.3, -0.75, -0.4), "hw": 1.0,
			"fr": Vector3(0.3, -0.7, -0.4), "rw": 0.9, "lw": 1.0, "legs": [1.2, -1.8, 1.0, -1.7]
		}],
		[0.3, {"p": -0.15, "sq": 0.1, "lift": -0.03}],
		[0.38, {}]]},
	# The air barge (the same quick 0.18 s lunge, 35% further): a beast's pounce, arms cocked up, then raked
	# forward with the claws out and dragged down through the air, legs tucked, a heavy drop onto his feet
	"dr_pounce": {"keys": [
		[0.0, {
			"p": -0.3, "sq": 0.3, "fl": Vector3(-0.3, 0.4, -0.2), "hw": 1.0, "fr": Vector3(0.3, 0.4, -0.2), "rw": 0.9,
			"lw": 1.0, "legs": [1.2, -1.8, 1.1, -1.8]
		}],
		[0.05, {
			"p": -0.9, "sq": -0.3, "fl": Vector3(-0.35, 0.0, -1.15), "hw": 1.0, "fr": Vector3(0.35, 0.05, -1.1),
			"rw": 0.9, "lw": 1.0, "legs": [-0.5, -0.4, -0.7, -0.3]
		}],
		[0.14, {
			"p": -0.8, "sq": -0.1, "fl": Vector3(-0.3, -0.35, -0.9), "hw": 1.0, "fr": Vector3(0.3, -0.3, -0.9),
			"rw": 0.9, "lw": 1.0, "legs": [1.0, -1.6, 0.9, -1.6]
		}],
		[0.24, {"p": -0.4, "sq": 0.3, "lift": -0.08, "lw": 1.0, "legs": [1.0, -1.5, 0.9, -1.4]}],
		[0.38, {}]]},
	# Salvage (passive): a stack gained - chest out, both fists flexed high above the shoulders, a stomp
	"dr_flex": {"keys": [
		[0.0, {}],
		[0.1, {
			"p": 0.35, "sq": -0.25, "lift": 0.2, "fl": Vector3(-0.45, 0.75, -0.05), "hw": 1.0,
			"fr": Vector3(0.45, 0.75, -0.05), "rw": 0.8, "gp": 1.0
		}],
		[0.22, {
			"p": 0.25, "sq": 0.35, "lift": -0.1, "fl": Vector3(-0.42, 0.65, -0.05), "hw": 1.0,
			"fr": Vector3(0.42, 0.65, -0.05), "rw": 0.8, "gp": 0.9, "lw": 1.0, "legs": [0.7, -1.1, 0.6, -1.0]
		}],
		[0.55, {}]]},
	# ================================================================= Cinder
	# Torch Lance (LMB, held): the pilot flickers for 0.2 s while he sets his feet and drops the nozzle to the
	# right hip, then the roar kicks him back hard (overshoot) and he settles braced, leaning into it, the hose
	# bucking in his hands (an 8 Hz wobble, looped while he holds)
	"as_lance": {"hold": true, "loop": 0.34, "keys": [
		[0.0, {}],
		[0.1, {
			"p": 0.12, "sq": 0.25, "lift": -0.06, "fr": Vector3(0.12, -0.32, -0.3), "rw": 1.0,
			"fl": Vector3(0.05, -0.12, -0.5), "hw": 1.0, "lw": 1.0, "legs": [0.7, -1.1, -0.5, -0.5], "gp": -0.15
		}],
		[0.2, {
			"p": 0.4, "sq": -0.3, "fr": Vector3(0.12, -0.28, -0.42), "rw": 1.0, "fl": Vector3(0.0, -0.08, -0.6),
			"hw": 1.0, "lw": 1.0, "legs": [0.6, -0.9, -0.5, -0.4], "gp": 0.35
		}],
		[0.34, {
			"p": -0.22, "lift": -0.06, "fr": Vector3(0.12, -0.3, -0.45), "rw": 1.0, "fl": Vector3(0.0, -0.12, -0.62),
			"hw": 1.0, "lw": 1.0, "legs": [0.65, -0.95, -0.55, -0.4], "gp": -0.05
		}],
		[0.4025, {
			"p": -0.16, "sq": 0.05, "lift": -0.06, "fr": Vector3(0.12, -0.27, -0.42), "rw": 1.0,
			"fl": Vector3(0.0, -0.09, -0.58), "hw": 1.0, "lw": 1.0, "legs": [0.65, -0.95, -0.55, -0.4], "gp": 0.07
		}],
		[0.465, {
			"p": -0.22, "lift": -0.06, "fr": Vector3(0.12, -0.3, -0.45), "rw": 1.0, "fl": Vector3(0.0, -0.12, -0.62),
			"hw": 1.0, "lw": 1.0, "legs": [0.65, -0.95, -0.55, -0.4], "gp": -0.05
		}]]},
	# Flashover mid-roar: the off fist punches up over his head, the nozzle bucks up once and he bounces on his
	# heels, then he settles back into the braced, bucking hold
	"lw_stoke_lance": {"hold": true, "loop": 0.5, "keys": [
		[0.0, {
			"p": -0.22, "lift": -0.06, "fr": Vector3(0.12, -0.3, -0.45), "rw": 1.0, "fl": Vector3(0.0, -0.12, -0.62),
			"hw": 1.0, "lw": 1.0, "legs": [0.65, -0.95, -0.55, -0.4], "gp": -0.05
		}],
		[0.1, {
			"p": 0.35, "sq": -0.25, "lift": 0.2, "fr": Vector3(0.12, -0.3, -0.45), "rw": 1.0,
			"fl": Vector3(-0.05, 1.05, -0.05), "hw": 1.0, "lw": 1.0, "legs": [0.4, -0.6, -0.3, -0.3], "gp": 0.45
		}],
		[0.22, {
			"p": 0.2, "sq": 0.2, "lift": -0.05, "fr": Vector3(0.12, -0.3, -0.45), "rw": 1.0,
			"fl": Vector3(-0.05, 0.95, -0.05), "hw": 1.0, "lw": 1.0, "legs": [0.7, -1.0, -0.55, -0.45]
		}],
		[0.5, {
			"p": -0.22, "lift": -0.06, "fr": Vector3(0.12, -0.3, -0.45), "rw": 1.0, "fl": Vector3(0.0, -0.12, -0.62),
			"hw": 1.0, "lw": 1.0, "legs": [0.65, -0.95, -0.55, -0.4], "gp": -0.05
		}],
		[0.5625, {
			"p": -0.16, "sq": 0.05, "lift": -0.06, "fr": Vector3(0.12, -0.27, -0.42), "rw": 1.0,
			"fl": Vector3(0.0, -0.09, -0.58), "hw": 1.0, "lw": 1.0, "legs": [0.65, -0.95, -0.55, -0.4], "gp": 0.07
		}],
		[0.625, {
			"p": -0.22, "lift": -0.06, "fr": Vector3(0.12, -0.3, -0.45), "rw": 1.0, "fl": Vector3(0.0, -0.12, -0.62),
			"hw": 1.0, "lw": 1.0, "legs": [0.65, -0.95, -0.55, -0.4], "gp": -0.05
		}]]},
	# letting go: a little recoil back off the hose, then a relaxed settle
	"as_lance_end": {"keys": [
		[0.0, {
			"p": -0.22, "fr": Vector3(0.12, -0.3, -0.45), "rw": 1.0, "fl": Vector3(0.0, -0.12, -0.62), "hw": 1.0,
			"lw": 1.0, "legs": [0.65, -0.95, -0.55, -0.4]
		}],
		[0.08, {"p": 0.15, "sq": -0.08, "fr": Vector3(0.12, -0.25, -0.3), "rw": 0.7, "gp": 0.3}],
		[0.3, {}]]},
	# Cinder Shot aim (RMB held): the gun hand cocked back at the shoulder, the off hand sighting down the lane
	"as_aim": {"hold": true, "keys": [
		[0.0, {}],
		[0.12, {
			"p": 0.1, "y": 0.4, "sq": 0.15, "fr": Vector3(0.15, 0.2, 0.15), "rw": 1.0, "fl": Vector3(-0.05, 0.15, -0.7),
			"hw": 1.0, "lw": 0.8, "legs": [0.5, -0.8, -0.4, -0.3], "gp": 0.2
		}]]},
	# Cinder Shot release: a quick forward thrust of the gun arm (overshoot), the body kicked back from the shot
	"as_shot": {"keys": [
		[0.0, {
			"p": 0.1, "y": 0.4, "fr": Vector3(0.15, 0.2, 0.15), "rw": 1.0, "fl": Vector3(-0.05, 0.15, -0.7), "hw": 1.0,
			"lw": 0.8, "legs": [0.5, -0.8, -0.4, -0.3]
		}],
		[0.06, {
			"p": -0.32, "y": -0.35, "sq": -0.25, "fr": Vector3(-0.05, 0.15, -1.0), "rw": 1.0,
			"fl": Vector3(-0.3, 0.0, 0.2), "hw": 0.8, "lw": 1.0, "legs": [0.9, -0.7, -0.7, -0.2], "gp": -0.1
		}],
		[0.14, {
			"p": 0.3, "y": -0.25, "sq": 0.2, "fr": Vector3(-0.05, 0.25, -0.75), "rw": 1.0, "lw": 0.9,
			"legs": [0.7, -0.9, -0.5, -0.3], "gp": 0.7
		}],
		[0.3, {"p": -0.06, "y": 0.04, "sq": -0.04, "fr": Vector3(0.0, 0.05, -0.5), "rw": 0.5}],
		[0.48, {}]]},
	# Soot Ram (Shift, 0.32 s, fastest at the start): a quick coil, then head-first like a battering ram, balled
	# up compact inside the flame skull (arms swept back, knees folded up behind him), held through the dash;
	# he snaps upright on arrival (a squash, the gun back on the aim) (hero-ref bash, body section 4)
	"as_leap": {"keys": [
		[0.0, {
			"p": 0.2, "sq": 0.4, "lift": -0.12, "lw": 1.0, "legs": [1.1, -1.7, 1.0, -1.7], "fr": Vector3(0.2, 0.1, 0.3),
			"rw": 0.6
		}],
		[0.06, {
			"p": -0.8, "sq": -0.4, "lift": 0.12, "fr": Vector3(0.25, 0.25, 0.55), "rw": 1.0,
			"fl": Vector3(-0.25, 0.25, 0.55), "hw": 1.0, "lw": 1.0, "legs": [-0.2, -1.2, -0.5, -1.0]
		}],
		[0.3, {
			"p": -0.75, "sq": -0.3, "lift": 0.1, "fr": Vector3(0.25, 0.25, 0.55), "rw": 1.0,
			"fl": Vector3(-0.25, 0.25, 0.55), "hw": 1.0, "lw": 1.0, "legs": [-0.15, -1.25, -0.45, -1.05]
		}],
		[0.36, {
			"p": -0.2, "sq": 0.45, "lift": -0.1, "fr": Vector3(0.1, 0.0, -0.3), "rw": 0.6,
			"fl": Vector3(-0.1, 0.0, -0.3), "hw": 0.6, "lw": 1.0, "legs": [1.0, -1.5, 0.6, -1.3]
		}],
		[0.42, {"p": 0.12, "sq": -0.1, "lift": 0.04}],
		[0.55, {}]]},
	# Furnace Cloak (E, 0.24 s, fires on the press): a quick tuck (0.03 s), then chest out and both arms flung
	# wide as the blast goes off (an overshoot up on the toes, the flamer swung up on its strap so the long gun
	# clears the ground), held a beat while the shield swirls up, and a quick settle back onto the grip
	"as_cloak": {"keys": [
		[0.0, {"p": -0.15, "sq": 0.2, "lift": -0.05, "fr": Vector3(-0.15, 0.1, -0.2), "rw": 0.8,
			"fl": Vector3(0.15, 0.1, -0.2), "hw": 0.8, "lw": 1.0, "legs": [0.5, -0.8, 0.45, -0.75], "gp": 0.4}],
		[0.05, {
			"p": 0.4, "sq": -0.35, "lift": 0.18, "fr": Vector3(0.85, 0.5, 0.1), "rw": 1.0,
			"fl": Vector3(-0.85, 0.5, 0.1), "hw": 1.0, "lw": 1.0, "legs": [-0.1, -0.2, -0.1, -0.2], "gp": 1.45
		}],
		[0.13, {
			"p": 0.28, "sq": -0.12, "lift": 0.07, "fr": Vector3(0.75, 0.45, 0.05), "rw": 1.0,
			"fl": Vector3(-0.75, 0.45, 0.05), "hw": 1.0, "gp": 1.35
		}],
		[0.24, {}]]},
	# Cinder's air poof (the air dash): balled up in the burst, one fast roll forward, then he sails out
	# spread-eagled on the launch, arms and legs wide and the nozzle held out, until the speed bleeds off
	"lw_hop": {"keys": [
		[0.0, {"sq": 0.35, "lift": -0.06, "lw": 1.0, "legs": [1.4, -2.1, 1.3, -2.1]}],
		[0.04, {
			"p": -0.7, "sq": -0.4, "fx": -1.5, "fr": Vector3(0.15, -0.1, 0.25), "rw": 0.8,
			"fl": Vector3(-0.15, -0.1, 0.25), "hw": 1.0, "lw": 1.0, "legs": [1.5, -2.2, 1.4, -2.2]
		}],
		[0.16, {
			"p": -0.6, "sq": -0.3, "fx": -6.283, "fl": Vector3(-0.15, -0.1, 0.25), "hw": 1.0, "lw": 1.0,
			"legs": [1.4, -2.0, 1.3, -2.0]
		}],
		[0.24, {
			"p": -0.55, "sq": -0.2, "fx": -6.283, "fl": Vector3(-0.7, 0.35, 0.1), "hw": 1.0,
			"fr": Vector3(0.6, 0.3, -0.2), "rw": 0.6, "lw": 1.0, "legs": [-0.5, -0.2, 0.5, -0.3]
		}],
		[0.5, {
			"p": -0.45, "sq": -0.1, "fx": -6.283, "fl": Vector3(-0.65, 0.3, 0.1), "hw": 1.0,
			"fr": Vector3(0.55, 0.25, -0.2), "rw": 0.5, "lw": 1.0, "legs": [-0.4, -0.25, 0.45, -0.35]
		}],
		[0.7, {"fx": -6.283}]]},
	# Flashover payoff (a foe Flashes over, or a knock): the off fist punches up over his head and the flamer
	# swings up with it (the arm alone hides under the hat from the match camera), a lean back and a bounce
	"lw_stoke": {"keys": [
		[0.0, {}],
		[0.1, {
			"p": 0.35, "sq": -0.25, "lift": 0.2, "fl": Vector3(-0.05, 1.05, -0.05), "hw": 1.0, "lw": 1.0, "gp": 1.1,
			"legs": [0.4, -0.6, -0.3, -0.3]
		}],
		[0.22, {"p": 0.2, "sq": 0.2, "lift": -0.05, "fl": Vector3(-0.05, 0.95, -0.05), "hw": 1.0, "gp": 0.9}],
		[0.5, {}]]},
	# Flue Flight (X, held for the 1.4s flight): a quick crouch as the ember ring bursts (0.08s), then he springs
	# up and leans into the jet, the free arm swept back to the bellows strap, the nozzle held low, legs trailing
	"lw_jet": {"hold": true, "keys": [
		[0.0, {"sq": 0.35, "lift": -0.12, "p": 0.12, "lw": 1.0, "legs": [0.9, -1.4, 0.8, -1.3]}],
		[0.08, {
			"p": -0.3, "gp": -0.45, "sq": -0.38, "lift": 0.42, "lw": 1.0, "legs": [0.15, -0.5, 0.35, -0.7],
			"fl": Vector3(-0.35, -0.2, 0.45), "hw": 1.0
		}],
		[0.22, {
			"p": -0.2, "gp": -0.4, "sq": -0.12, "lift": 0.22, "lw": 1.0, "legs": [0.25, -0.6, 0.4, -0.8],
			"fl": Vector3(-0.3, -0.15, 0.4), "hw": 1.0
		}],
		[0.6, {
			"p": -0.24, "gp": -0.4, "sq": -0.06, "lift": 0.28, "lw": 1.0, "legs": [0.35, -0.7, 0.3, -0.6],
			"fl": Vector3(-0.32, -0.1, 0.42), "hw": 1.0
		}],
		[1.0, {
			"p": -0.2, "gp": -0.4, "sq": -0.1, "lift": 0.22, "lw": 1.0, "legs": [0.25, -0.6, 0.4, -0.8],
			"fl": Vector3(-0.3, -0.15, 0.4), "hw": 1.0
		}]]},
	# the landing: no big impact, a squash onto his feet and he walks on (0.36s)
	"lw_land": {"keys": [
		[0.0, {"p": -0.15, "sq": -0.05, "lift": 0.15}],
		[0.08, {"p": 0.18, "sq": 0.35, "lift": -0.14, "lw": 1.0, "legs": [0.8, -1.3, 0.7, -1.2]}],
		[0.2, {"p": -0.04, "sq": -0.08, "lift": 0.03}],
		[0.36, {}]]},
	# Brass Broadside (X, 2.1s): hunched over his fists while the charge builds (1.1s, deeper at the end), a
	# two-fisted shove at wave 1 (overshoot), a short rewind, the second shove at 1.7s, then he straightens up
	"dr_blast": {"keys": [
		[0.0, {}],
		[0.15, {"p": 0.35, "sq": 0.3, "lift": -0.12, "lw": 1.0, "legs": [0.7, -1.1, 0.7, -1.1],
			"fl": Vector3(-0.15, 0.1, 0.25), "hw": 1.0}],
		[1.0, {"p": 0.5, "sq": 0.42, "lift": -0.18, "lw": 1.0, "legs": [0.8, -1.25, 0.8, -1.25],
			"fl": Vector3(-0.2, 0.15, 0.4), "hw": 1.0}],
		[1.1, {"p": -0.38, "sq": -0.32, "lift": 0.05, "gp": 0.6, "lw": 1.0, "legs": [0.9, -0.6, -0.5, -0.3],
			"fl": Vector3(-0.2, 0.15, -0.98), "hw": 1.0}],
		[1.24, {"p": -0.2, "sq": -0.1, "lw": 1.0, "legs": [0.85, -0.65, -0.45, -0.35],
			"fl": Vector3(-0.2, 0.12, -0.85), "hw": 1.0}],
		[1.6, {"p": 0.3, "sq": 0.25, "lift": -0.1, "lw": 1.0, "legs": [0.8, -1.2, 0.7, -1.1],
			"fl": Vector3(-0.2, 0.12, 0.2), "hw": 1.0}],
		[1.7, {"p": -0.42, "sq": -0.34, "lift": 0.06, "gp": 0.6, "lw": 1.0, "legs": [0.9, -0.6, -0.5, -0.3],
			"fl": Vector3(-0.2, 0.15, -1.0), "hw": 1.0}],
		[1.85, {
			"p": -0.2, "sq": -0.1, "fl": Vector3(-0.15, 0.1, -0.8), "hw": 0.8, "fr": Vector3(0.15, 0.1, -0.8),
			"rw": 0.8
		}],
		[2.1, {}]]},
	# Cinder's plain jump: a quick crouch and a springy tuck, the pack bouncing, the nozzle kept up
	"lw_jump": {"keys": [
		[0.0, {"sq": 0.3, "lift": -0.06, "p": 0.1, "lw": 1.0, "legs": [0.8, -1.2, 0.7, -1.1]}],
		[0.07, {"sq": -0.3, "p": -0.15, "lw": 1.0, "legs": [1.1, -1.8, 0.9, -1.6], "fl": Vector3(-0.3, 0.1, 0.1),
			"hw": 0.8}],
		[0.3, {"sq": -0.05, "lw": 0.6, "legs": [0.6, -1.0, 0.5, -0.9]}],
		[0.45, {}]]},
	# Dredge's plain jump: a deep heave off planted feet, arms out wide for balance, legs hanging heavy
	"dr_jump": {"keys": [
		[0.0, {"sq": 0.45, "lift": -0.14, "p": 0.2, "lw": 1.0, "legs": [1.0, -1.6, 0.9, -1.5]}],
		[0.1, {"sq": -0.25, "p": -0.1, "fl": Vector3(-0.45, 0.15, 0.1), "hw": 1.0, "lw": 1.0,
			"legs": [0.3, -0.5, 0.4, -0.6]}],
		[0.4, {"sq": -0.05, "fl": Vector3(-0.4, 0.1, 0.05), "hw": 0.6, "lw": 0.5, "legs": [0.3, -0.5, 0.4, -0.6]}],
		[0.55, {}]]},
	# Dredge's landing: a heavy squash onto bent knees, then he heaves upright
	"dr_land": {"keys": [
		[0.0, {"sq": 0.55, "lift": -0.18, "p": 0.25, "lw": 1.0, "legs": [1.2, -1.9, 1.1, -1.8],
			"fl": Vector3(-0.4, -0.1, 0.0), "hw": 0.8}],
		[0.14, {"sq": 0.3, "lift": -0.1, "p": 0.15, "lw": 1.0, "legs": [1.0, -1.6, 0.9, -1.5]}],
		[0.4, {}]]},
}
