class_name KMovesPair
extends RefCounted
## Keyed full-body moves of Dredge and Linwick (id ashwick), in the same format and channels as
## HunterAnim.KMOVES (looked up by HunterAnim.km_sample). Timed to the reference sheets' beats:
## anticipation, release (with an overshoot key), follow-through, recovery (settle). fl / fr place a
## free hand from its shoulder (hw / rw their weight; -z is forward, +x the hunter's right), p is the
## body pitch (negative = leaning forward), y the twist, lift the hips' rise, sq squash (+) or stretch
## (-), gp the weapon's pitch kick. No new animation channel was needed: overshoot and settle are keyed.

const MOVES := {
	# ================================================================= Dredge
	# Scattergun (LMB, every shot, 0.5 s cycle): the barrel kicks up, the torso rocks back and turns side-on,
	# then swings back to the aim in about 0.2 s (sheet 0045, 0080)
	"dr_shot": {"keys": [
		[0.0, {"p": 0.06, "gp": 0.1, "sq": 0.05}],
		[0.05, {"p": 0.3, "y": 0.45, "gp": 0.75, "sq": 0.18, "lift": -0.04, "fl": Vector3(-0.2, 0.05, -0.3), "hw": 0.6, "lw": 0.8, "legs": [0.4, -0.7, -0.5, -0.3]}],
		[0.14, {"p": 0.18, "y": 0.3, "gp": 0.35, "sq": 0.06, "lw": 0.7, "legs": [0.4, -0.7, -0.5, -0.3]}],
		[0.24, {"p": -0.05, "y": -0.06, "gp": -0.05, "sq": -0.03}],
		[0.36, {}]]},
	# Grapnel throw (RMB): the gun swings to the off side, the free arm coils back (0.08 s), then punches
	# out along the aim and stays out while the arm flies (0.4 s to full reach)
	"dr_throw": {"keys": [
		[0.0, {}],
		[0.08, {"y": -0.7, "p": 0.15, "fl": Vector3(-0.15, 0.25, 0.35), "hw": 1.0, "fr": Vector3(0.35, -0.05, 0.05), "rw": 0.8, "sq": 0.25, "lw": 1.0, "legs": [0.6, -0.9, -0.4, -0.4]}],
		[0.14, {"y": 0.65, "p": -0.38, "fl": Vector3(0.05, 0.12, -1.0), "hw": 1.0, "fr": Vector3(0.35, -0.1, 0.15), "rw": 0.8, "sq": -0.25, "lw": 1.0, "legs": [1.0, -0.8, -0.7, -0.2]}],
		[0.22, {"y": 0.5, "p": -0.3, "fl": Vector3(0.05, 0.1, -0.92), "hw": 1.0, "fr": Vector3(0.3, -0.1, 0.1), "rw": 0.8, "sq": -0.1, "lw": 1.0, "legs": [0.95, -0.85, -0.65, -0.25]}],
		[0.45, {"y": 0.45, "p": -0.25, "fl": Vector3(0.05, 0.1, -0.9), "hw": 1.0, "fr": Vector3(0.3, -0.1, 0.1), "rw": 0.7, "lw": 1.0, "legs": [0.9, -0.85, -0.6, -0.3]}],
		[0.7, {}]]},
	# the reel: side-on to the target, braced and leaning back, hauling hand over hand (held up to 3 s)
	"dr_reel": {"keys": [
		[0.0, {"y": 0.45, "p": -0.2, "fl": Vector3(0.05, 0.1, -0.9), "hw": 1.0, "lw": 1.0, "legs": [0.9, -0.85, -0.6, -0.3]}],
		[0.18, {"p": 0.36, "y": 0.55, "lift": -0.14, "fl": Vector3(-0.05, -0.15, -0.55), "hw": 1.0, "fr": Vector3(0.05, -0.25, -0.22), "rw": 0.9, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.20}],
		[0.44, {"p": 0.44, "y": 0.55, "lift": -0.14, "fl": Vector3(-0.05, -0.25, -0.2), "hw": 1.0, "fr": Vector3(0.05, -0.15, -0.5), "rw": 0.9, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.28}],
		[0.70, {"p": 0.36, "y": 0.55, "lift": -0.14, "fl": Vector3(-0.05, -0.15, -0.55), "hw": 1.0, "fr": Vector3(0.05, -0.25, -0.22), "rw": 0.9, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.20}],
		[0.96, {"p": 0.44, "y": 0.55, "lift": -0.14, "fl": Vector3(-0.05, -0.25, -0.2), "hw": 1.0, "fr": Vector3(0.05, -0.15, -0.5), "rw": 0.9, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.28}],
		[1.22, {"p": 0.36, "y": 0.55, "lift": -0.14, "fl": Vector3(-0.05, -0.15, -0.55), "hw": 1.0, "fr": Vector3(0.05, -0.25, -0.22), "rw": 0.9, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.20}],
		[1.48, {"p": 0.44, "y": 0.55, "lift": -0.14, "fl": Vector3(-0.05, -0.25, -0.2), "hw": 1.0, "fr": Vector3(0.05, -0.15, -0.5), "rw": 0.9, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.28}],
		[1.74, {"p": 0.36, "y": 0.55, "lift": -0.14, "fl": Vector3(-0.05, -0.15, -0.55), "hw": 1.0, "fr": Vector3(0.05, -0.25, -0.22), "rw": 0.9, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.20}],
		[2.00, {"p": 0.44, "y": 0.55, "lift": -0.14, "fl": Vector3(-0.05, -0.25, -0.2), "hw": 1.0, "fr": Vector3(0.05, -0.15, -0.5), "rw": 0.9, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.28}],
		[2.26, {"p": 0.36, "y": 0.55, "lift": -0.14, "fl": Vector3(-0.05, -0.15, -0.55), "hw": 1.0, "fr": Vector3(0.05, -0.25, -0.22), "rw": 0.9, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.20}],
		[2.52, {"p": 0.44, "y": 0.55, "lift": -0.14, "fl": Vector3(-0.05, -0.25, -0.2), "hw": 1.0, "fr": Vector3(0.05, -0.15, -0.5), "rw": 0.9, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.28}],
		[2.78, {"p": 0.36, "y": 0.55, "lift": -0.14, "fl": Vector3(-0.05, -0.15, -0.55), "hw": 1.0, "fr": Vector3(0.05, -0.25, -0.22), "rw": 0.9, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.20}],
		[3.1, {}]]},
	# the foe arrives: a last yank back, then a settle
	"dr_pullend": {"keys": [
		[0.0, {"p": 0.4, "y": 0.5, "fl": Vector3(-0.05, -0.2, -0.2), "hw": 1.0, "lw": 1.0, "legs": [0.8, -1.2, -0.75, -0.55], "sq": 0.25}],
		[0.08, {"p": 0.52, "y": 0.3, "fl": Vector3(-0.1, -0.1, 0.15), "hw": 1.0, "lw": 1.0, "legs": [0.7, -1.1, -0.7, -0.5], "sq": -0.1}],
		[0.22, {"p": -0.08, "sq": 0.05}],
		[0.36, {}]]},
	# Anchor Drop (E, 0.38 s to impact): f1 the free fist hauled back and the shoulder turned away; f2 a hop up
	# and about a body height forward (the kit moves the body); f3 the fist drives down; f4-f5 a crouched
	# follow-through, then recovery with a small rebound
	"dr_anchor": {"keys": [
		[0.0, {}],
		[0.14, {"y": -0.75, "p": 0.3, "fl": Vector3(-0.2, 0.75, 0.3), "hw": 1.0, "fr": Vector3(0.3, 0.0, 0.1), "rw": 0.7, "sq": 0.35, "lift": -0.1, "lw": 1.0, "legs": [0.9, -1.4, 0.7, -1.3]}],
		[0.26, {"y": -0.45, "p": 0.1, "fl": Vector3(-0.1, 0.95, 0.05), "hw": 1.0, "fr": Vector3(0.3, 0.2, 0.0), "rw": 0.7, "sq": -0.35, "lift": 0.38, "lw": 1.0, "legs": [1.2, -1.9, 1.0, -1.8]}],
		[0.38, {"y": 0.35, "p": -0.85, "fl": Vector3(0.1, -0.6, -0.75), "hw": 1.0, "fr": Vector3(0.25, -0.3, -0.3), "rw": 0.7, "sq": 0.6, "lift": -0.22, "lw": 1.0, "legs": [1.15, -1.6, -0.45, -1.0]}],
		[0.6, {"y": 0.25, "p": -0.65, "fl": Vector3(0.1, -0.62, -0.7), "hw": 0.9, "sq": 0.3, "lift": -0.16, "lw": 1.0, "legs": [1.05, -1.5, -0.4, -0.9]}],
		[0.82, {"p": 0.08, "sq": -0.08, "lift": 0.03}],
		[1.0, {}]]},
	# Anchor Drop in the air: both fists locked overhead, knees up, dropping like a stone (held to the ground)
	"dr_dive": {"hold": true, "keys": [
		[0.0, {"p": 0.2, "fl": Vector3(-0.1, 0.6, 0.1), "hw": 1.0, "fr": Vector3(0.1, 0.6, 0.1), "rw": 1.0, "sq": 0.3, "lw": 1.0, "legs": [1.0, -1.5, 0.9, -1.5]}],
		[0.12, {"p": -0.35, "fl": Vector3(0.0, 0.95, -0.15), "hw": 1.0, "fr": Vector3(0.0, 0.95, -0.15), "rw": 1.0, "sq": -0.35, "lw": 1.0, "legs": [1.3, -1.9, 1.2, -1.9]}],
		[0.3, {"p": -0.45, "fl": Vector3(0.0, 1.0, -0.2), "hw": 1.0, "fr": Vector3(0.0, 1.0, -0.2), "rw": 1.0, "sq": -0.3, "lw": 1.0, "legs": [1.3, -1.9, 1.2, -1.9]}]]},
	# the air smash lands with the anchor: a huge squash, fists buried in the ground, then a heave back up
	"dr_quake": {"keys": [
		[0.0, {"p": -0.95, "fl": Vector3(0.05, -0.75, -0.6), "hw": 1.0, "fr": Vector3(-0.05, -0.75, -0.6), "rw": 1.0, "sq": 0.8, "lift": -0.3, "lw": 1.0, "legs": [1.3, -2.0, 1.1, -1.9]}],
		[0.3, {"p": -0.7, "fl": Vector3(0.05, -0.7, -0.55), "hw": 0.9, "fr": Vector3(-0.05, -0.7, -0.55), "rw": 0.9, "sq": 0.45, "lift": -0.22, "lw": 1.0, "legs": [1.2, -1.8, 1.0, -1.7]}],
		[0.55, {"p": 0.12, "sq": -0.12, "lift": 0.06}],
		[0.75, {}]]},
	# Barge (Shift): anticipation (sink and coil), launch shoulder-first with the gun trailing, a lumbering
	# shove through the dash, a crouched landing and a turn back to the aim
	"dr_barge": {"keys": [
		[0.0, {"p": 0.15, "y": -0.3, "sq": 0.35, "lift": -0.08, "lw": 1.0, "legs": [0.9, -1.4, 0.6, -1.2]}],
		[0.06, {"p": -0.72, "y": 0.6, "sq": -0.3, "fr": Vector3(0.25, 0.0, 0.45), "rw": 0.9, "fl": Vector3(0.1, 0.1, -0.15), "hw": 0.9, "lw": 1.0, "legs": [1.15, -0.6, -0.85, -0.15]}],
		[0.2, {"p": -0.6, "y": 0.5, "sq": -0.1, "fr": Vector3(0.25, 0.0, 0.45), "rw": 0.9, "fl": Vector3(0.1, 0.1, -0.15), "hw": 0.9, "lw": 1.0, "legs": [0.6, -1.0, -0.4, -0.6]}],
		[0.34, {"p": -0.55, "y": 0.45, "sq": 0.0, "fr": Vector3(0.25, 0.0, 0.4), "rw": 0.8, "lw": 1.0, "legs": [1.15, -0.6, -0.85, -0.15]}],
		[0.42, {"p": -0.2, "y": 0.15, "sq": 0.5, "lift": -0.16, "lw": 1.0, "legs": [1.1, -1.7, 0.9, -1.6]}],
		[0.6, {"p": 0.1, "sq": -0.1, "lift": 0.04}],
		[0.75, {}]]},
	# Dredge's air hop (the class air dash, further than on foot): arms flung wide, legs pumping, then a heavy settle
	"dr_hop": {"keys": [
		[0.0, {"sq": 0.3, "p": 0.1, "lw": 1.0, "legs": [1.0, -1.5, 0.9, -1.4]}],
		[0.06, {"sq": -0.3, "p": -0.5, "fl": Vector3(-0.45, 0.2, 0.25), "hw": 1.0, "fr": Vector3(0.45, 0.2, 0.25), "rw": 0.6, "lw": 1.0, "legs": [-0.3, -0.3, 0.8, -1.2]}],
		[0.24, {"sq": -0.1, "p": -0.45, "fl": Vector3(-0.5, 0.25, 0.3), "hw": 1.0, "lw": 1.0, "legs": [0.8, -1.2, -0.3, -0.3]}],
		[0.4, {"sq": 0.2, "p": -0.1}],
		[0.55, {}]]},
	# Salvage (passive): a stack gained - chest out, both fists flexed, a stomp
	"dr_flex": {"keys": [
		[0.0, {}],
		[0.1, {"p": 0.3, "sq": -0.2, "lift": 0.08, "fl": Vector3(-0.4, 0.4, -0.05), "hw": 1.0, "fr": Vector3(0.4, 0.4, -0.05), "rw": 0.6}],
		[0.18, {"p": 0.22, "sq": 0.3, "lift": -0.08, "fl": Vector3(-0.38, 0.32, -0.05), "hw": 1.0, "lw": 1.0, "legs": [0.7, -1.1, 0.6, -1.0]}],
		[0.5, {}]]},
	# ================================================================= Linwick
	# Torch Lance (LMB, held): the pilot flickers for 0.2 s while he sets his feet and drops the nozzle to the
	# right hip, then the roar kicks him back a touch (overshoot) and he settles braced, leaning into it
	"as_lance": {"hold": true, "keys": [
		[0.0, {}],
		[0.1, {"p": 0.12, "sq": 0.25, "lift": -0.06, "fr": Vector3(0.12, -0.32, -0.3), "rw": 1.0, "fl": Vector3(0.05, -0.12, -0.5), "hw": 1.0, "lw": 1.0, "legs": [0.7, -1.1, -0.5, -0.5], "gp": -0.15}],
		[0.2, {"p": 0.22, "sq": -0.15, "fr": Vector3(0.12, -0.3, -0.42), "rw": 1.0, "fl": Vector3(0.0, -0.1, -0.6), "hw": 1.0, "lw": 1.0, "legs": [0.6, -0.9, -0.5, -0.4], "gp": 0.25}],
		[0.34, {"p": -0.22, "lift": -0.06, "fr": Vector3(0.12, -0.3, -0.45), "rw": 1.0, "fl": Vector3(0.0, -0.12, -0.62), "hw": 1.0, "lw": 1.0, "legs": [0.65, -0.95, -0.55, -0.4], "gp": -0.05}]]},
	# letting go: a little recoil back off the hose, then a relaxed settle
	"as_lance_end": {"keys": [
		[0.0, {"p": -0.22, "fr": Vector3(0.12, -0.3, -0.45), "rw": 1.0, "fl": Vector3(0.0, -0.12, -0.62), "hw": 1.0, "lw": 1.0, "legs": [0.65, -0.95, -0.55, -0.4]}],
		[0.08, {"p": 0.15, "sq": -0.08, "fr": Vector3(0.12, -0.25, -0.3), "rw": 0.7, "gp": 0.3}],
		[0.3, {}]]},
	# Cinder Shot aim (RMB held): the gun hand cocked back at the shoulder, the off hand sighting down the lane
	"as_aim": {"hold": true, "keys": [
		[0.0, {}],
		[0.12, {"p": 0.1, "y": 0.4, "sq": 0.15, "fr": Vector3(0.15, 0.2, 0.15), "rw": 1.0, "fl": Vector3(-0.05, 0.15, -0.7), "hw": 1.0, "lw": 0.8, "legs": [0.5, -0.8, -0.4, -0.3], "gp": 0.2}]]},
	# Cinder Shot release: a quick forward thrust of the gun arm (overshoot), the body kicked back from the shot
	"as_shot": {"keys": [
		[0.0, {"p": 0.1, "y": 0.4, "fr": Vector3(0.15, 0.2, 0.15), "rw": 1.0, "fl": Vector3(-0.05, 0.15, -0.7), "hw": 1.0, "lw": 0.8, "legs": [0.5, -0.8, -0.4, -0.3]}],
		[0.06, {"p": -0.32, "y": -0.35, "sq": -0.25, "fr": Vector3(-0.05, 0.15, -1.0), "rw": 1.0, "fl": Vector3(-0.3, 0.0, 0.2), "hw": 0.8, "lw": 1.0, "legs": [0.9, -0.7, -0.7, -0.2], "gp": -0.1}],
		[0.14, {"p": 0.3, "y": -0.25, "sq": 0.2, "fr": Vector3(-0.05, 0.25, -0.75), "rw": 1.0, "lw": 0.9, "legs": [0.7, -0.9, -0.5, -0.3], "gp": 0.7}],
		[0.3, {"p": -0.06, "y": 0.04, "sq": -0.04, "fr": Vector3(0.0, 0.05, -0.5), "rw": 0.5}],
		[0.48, {}]]},
	# Soot Ram (Shift): a coil, then head-first like a battering ram, arms swept back and legs
	# trailing; the impact squashes him, and he springs back upright (sheet bash_strip 0157-0164)
	"as_leap": {"keys": [
		[0.0, {"p": 0.2, "sq": 0.4, "lift": -0.12, "lw": 1.0, "legs": [1.1, -1.7, 1.0, -1.7], "fr": Vector3(0.2, 0.1, 0.3), "rw": 0.6}],
		[0.05, {"p": -1.05, "sq": -0.4, "lift": 0.12, "fr": Vector3(0.25, 0.25, 0.55), "rw": 1.0, "fl": Vector3(-0.25, 0.25, 0.55), "hw": 1.0, "lw": 1.0, "legs": [-0.5, -0.2, -0.9, -0.15]}],
		[0.24, {"p": -0.95, "sq": -0.3, "lift": 0.1, "fr": Vector3(0.25, 0.25, 0.55), "rw": 1.0, "fl": Vector3(-0.25, 0.25, 0.55), "hw": 1.0, "lw": 1.0, "legs": [-0.4, -0.3, -0.85, -0.2]}],
		[0.3, {"p": -0.45, "sq": 0.5, "lift": -0.12, "fr": Vector3(0.1, 0.0, -0.3), "rw": 0.8, "fl": Vector3(-0.1, 0.0, -0.3), "hw": 0.8, "lw": 1.0, "legs": [1.0, -1.5, 0.6, -1.3]}],
		[0.46, {"p": 0.18, "sq": -0.12, "lift": 0.05}],
		[0.62, {}]]},
	# Furnace Cloak (E): 0.2 s curled in, arms crossed over the chest (the ring shows), then flung wide with the
	# blast (an overshoot up on the toes), held wide while the heat rolls out, and a settle
	"as_cloak": {"keys": [
		[0.0, {}],
		[0.12, {"p": -0.35, "sq": 0.4, "lift": -0.12, "fr": Vector3(-0.2, 0.2, -0.3), "rw": 1.0, "fl": Vector3(0.2, 0.2, -0.3), "hw": 1.0, "lw": 1.0, "legs": [0.8, -1.3, 0.7, -1.2]}],
		[0.2, {"p": 0.38, "sq": -0.38, "lift": 0.18, "fr": Vector3(0.7, 0.45, 0.05), "rw": 1.0, "fl": Vector3(-0.7, 0.45, 0.05), "hw": 1.0, "lw": 1.0, "legs": [-0.1, -0.2, -0.1, -0.2]}],
		[0.32, {"p": 0.22, "sq": -0.1, "lift": 0.06, "fr": Vector3(0.6, 0.4, 0.0), "rw": 1.0, "fl": Vector3(-0.6, 0.4, 0.0), "hw": 1.0}],
		[0.6, {"p": 0.1, "fr": Vector3(0.4, 0.25, 0.0), "rw": 0.6, "fl": Vector3(-0.4, 0.25, 0.0), "hw": 0.6}],
		[0.8, {}]]},
	# Linwick's air hop (the class air dash): a jet of flame from the bellows tucks him into a forward ball
	"lw_hop": {"keys": [
		[0.0, {"sq": 0.25, "lw": 1.0, "legs": [0.9, -1.4, 0.8, -1.3]}],
		[0.05, {"p": -0.6, "sq": -0.3, "fr": Vector3(0.2, 0.15, 0.4), "rw": 0.8, "fl": Vector3(-0.2, 0.15, 0.4), "hw": 0.8, "lw": 1.0, "legs": [1.3, -1.9, 1.2, -1.9]}],
		[0.22, {"p": -0.4, "sq": -0.1, "lw": 1.0, "legs": [1.2, -1.8, 1.1, -1.8]}],
		[0.36, {"sq": 0.2, "p": 0.05}],
		[0.5, {}]]},
	# Flashover payoff (a foe Flashes over, or a knock): the off fist pumps up, a lean back, a bounce
	"lw_stoke": {"keys": [
		[0.0, {}],
		[0.1, {"p": 0.3, "sq": -0.2, "lift": 0.1, "fl": Vector3(-0.1, 0.9, -0.1), "hw": 1.0}],
		[0.2, {"p": 0.2, "sq": 0.15, "lift": -0.03, "fl": Vector3(-0.1, 0.8, -0.1), "hw": 1.0}],
		[0.45, {}]]},
}
