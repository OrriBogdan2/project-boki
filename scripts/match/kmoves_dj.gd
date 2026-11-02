class_name KMovesDJ
extends RefCounted
## Keyed full-body moves of Dancer (thief) and Juggernaut (same format and channels as
## HunterAnim.KMOVES; HunterAnim.km_sample looks here after KMOVES, KMovesPair and MergeMoves). Each is
## anticipation -> a key pose on the hit -> follow-through and recovery, keyed to the kit's own timing
## and to the footage frame counts in briefs/hero-ref/dancer.md and juggernaut.md (5 fps: a frame is 0.2s).

const MOVES := {
	# ---------------------------------------------------------------- Juggernaut
	# the Searing Wave let go: the raised blade carves down and forward, a long low lunge after it
	"jug_wave": {"keys": [
		[0.0, {"blade": Vector3(0.0, 2.6, 0.0), "bw": 1.0, "p": 0.2}],
		[0.1, {"blade": Vector3(0.0, -0.9, 0.0), "bw": 1.0, "rad": 0.6, "p": -0.5, "lw": 1.0,
				"legs": [1.0, -1.0, -0.6, -0.3], "sq": 0.2}],
		[0.32, {"blade": Vector3(0.0, -0.8, 0.0), "bw": 0.8, "p": -0.35, "lw": 0.8, "legs": [0.8, -0.9, -0.5, -0.3]}],
		[0.6, {}]]},
	# Finishing Slam (footage 0155-0158): 0.6s of wind-up, the blade cocked low behind and the body
	# coiled, rising onto the front foot, the strike at 0.6 (the hit), then a heavy recovery
	"jug_slam": {"keys": [
		[0.0, {}],
		[0.3, {"blade": Vector3(-1.2, -0.4, 1.4), "bw": 1.0, "rad": 0.4, "p": 0.1, "y": 0.75, "lift": -0.1, "lw": 1.0,
				"legs": [0.9, -1.4, -0.3, -0.7], "sq": 0.2}],
		[0.56, {"blade": Vector3(-1.5, -0.3, 1.5), "bw": 1.0, "rad": 0.45, "p": 0.18, "y": 0.95, "lift": -0.12,
				"lw": 1.0, "legs": [1.0, -1.5, -0.35, -0.8], "sq": 0.28}],
		[0.62, {"blade": Vector3(1.1, -0.35, 1.4), "bw": 1.0, "rad": 0.6, "p": -0.55, "y": -0.6, "lift": -0.05,
				"sq": -0.2, "lw": 1.0, "legs": [1.15, -0.7, -0.75, -0.25]}],
		[0.85, {"blade": Vector3(1.2, -0.4, 1.4), "bw": 0.9, "rad": 0.55, "p": -0.45, "y": -0.5, "lw": 1.0,
				"legs": [1.0, -0.8, -0.6, -0.3]}],
		[1.15, {}]]},
	# the Lunge, held (a big wind-up pose): sunk deep, the blade dragged low behind, the torso
	# coiled away from the aim, the back leg loaded; it holds while you charge
	"jug_lunge_wind": {"hold": true, "keys": [
		[0.0, {}],
		[0.12, {"blade": Vector3(-0.9, -0.35, 1.4), "bw": 1.0, "rad": 0.3, "p": -0.1, "y": 0.75, "lw": 1.0,
				"legs": [0.9, -1.5, -0.55, -0.9], "lift": -0.14, "sq": 0.25}],
		[0.45, {"blade": Vector3(-1.1, -0.45, 1.5), "bw": 1.0, "rad": 0.25, "p": -0.38, "y": 1.0, "lw": 1.0,
				"legs": [1.05, -1.7, -0.65, -1.05], "lift": -0.2, "sq": 0.32}]]},
	# ... let go: driving forward, the blade thrust out at full reach, then the follow-through
	"jug_lunge": {"keys": [
		[0.0, {"blade": Vector3(-0.6, -0.25, 1.3), "bw": 1.0, "rad": 0.25, "p": -0.25, "y": 0.6, "lw": 1.0,
				"legs": [0.7, -1.2, -0.45, -0.6]}],
		[0.08, {"blade": Vector3(0.0, -0.05, 0.0), "bw": 1.0, "rad": 0.75, "p": -0.55, "y": -0.35, "lw": 1.0,
				"legs": [1.15, -0.7, -0.75, -0.2], "sq": -0.2}],
		[0.3, {"blade": Vector3(0.0, -0.1, 0.0), "bw": 1.0, "rad": 0.7, "p": -0.45, "y": -0.3, "lw": 1.0,
				"legs": [1.0, -0.8, -0.6, -0.3]}],
		[0.6, {}]]},
	# Meteor Drop: the blade swung up overhead as you tip forward, then driven down into the ground
	"jug_meteor": {"keys": [
		[0.0, {"blade": Vector3(0.0, 2.8, 0.0), "bw": 1.0, "p": 0.3, "lw": 1.0, "legs": [1.3, -1.8, 1.2, -1.7]}],
		[0.12, {"blade": Vector3(0.0, -1.35, 0.0), "bw": 1.0, "rad": 0.5, "p": -0.6, "fx": -0.35, "lw": 1.0,
				"legs": [1.2, -1.6, 0.4, -0.9]}],
		[0.2, {"blade": Vector3(0.0, -1.35, 0.0), "bw": 1.0, "rad": 0.5, "p": -0.7, "sq": 0.5, "lift": -0.15, "lw": 1.0,
				"legs": [1.2, -1.7, -0.5, -1.2]}],
		[0.55, {}]]},
	# Rampage: a shoulder-down drive with the blade levelled ahead, the tip thrust out at the end
	"jug_dash": {"keys": [
		[0.0, {"blade": Vector3(0.0, -0.1, 0.0), "bw": 1.0, "rad": 0.3, "p": -0.35, "y": 0.45, "lw": 1.0,
				"legs": [0.6, -1.0, -0.5, -0.4]}],
		[0.16, {"blade": Vector3(0.0, -0.05, 0.0), "bw": 1.0, "rad": 0.35, "p": -0.5, "y": 0.4, "lw": 1.0,
				"legs": [1.0, -0.6, -0.8, -0.2]}],
		[0.22, {"blade": Vector3(0.0, 0.0, 0.0), "bw": 1.0, "rad": 0.85, "p": -0.6, "y": -0.3, "lw": 1.0,
				"legs": [1.15, -0.6, -0.8, -0.15], "sq": -0.25}],
		[0.42, {"blade": Vector3(0.0, -0.1, 0.0), "bw": 0.8, "rad": 0.6, "p": -0.3, "lw": 0.6,
				"legs": [0.8, -0.8, -0.4, -0.3]}],
		[0.65, {}]]},
	# Warchain: the chain hand cocked back, then flung out ahead; the body twists into it
	"jug_chain": {"keys": [
		[0.0, {}],
		[0.08, {"fl": Vector3(-0.15, 0.25, 0.25), "hw": 1.0, "y": -0.5, "p": 0.1}],
		[0.16, {"fl": Vector3(0.12, 0.12, -0.5), "hw": 1.0, "y": 0.45, "p": -0.25, "lw": 0.6,
				"legs": [0.7, -0.8, -0.4, -0.3]}],
		[0.45, {"fl": Vector3(0.08, 0.05, -0.42), "hw": 0.7, "y": 0.2}],
		[0.7, {}]]},
	# ... pulled along it: leaning hard into the chain, the hand out ahead, the feet trailing
	"jug_reel": {"keys": [
		[0.0, {"fl": Vector3(0.1, 0.12, -0.5), "hw": 1.0, "p": -0.2}],
		[0.08, {"fl": Vector3(0.12, 0.15, -0.52), "hw": 1.0, "p": -0.55, "lift": 0.08, "lw": 1.0,
				"legs": [-0.2, -0.6, -0.7, -0.3], "sq": -0.2}],
		[0.4, {"fl": Vector3(0.12, 0.15, -0.5), "hw": 1.0, "p": -0.5, "lift": 0.05, "lw": 1.0,
				"legs": [-0.1, -0.7, -0.6, -0.4]}],
		[0.65, {}]]},
	# Cinder Spin: blade out wide, the whole body turns twice
	"jug_spin": {"keys": [
		[0.0, {"blade": Vector3(-1.5, 0.0, 1.5), "bw": 1.0, "rad": 0.55, "lw": 1.0, "legs": [0.6, -1.0, 0.5, -0.9],
				"lift": -0.06}],
		[0.36, {"blade": Vector3(-1.5, 0.0, 1.5), "bw": 1.0, "rad": 0.55, "fy": -12.566, "lw": 1.0,
				"legs": [0.6, -1.0, 0.5, -0.9], "lift": -0.06}],
		[0.55, {"fy": -12.566}]]},
	# the Chain Lunge: the chain hand hauls back as the body hurls along the chain, blade levelled
	"jug_chainlunge": {"keys": [
		[0.0, {"fl": Vector3(0.1, 0.12, -0.5), "hw": 1.0, "blade": Vector3(-0.5, -0.2, 1.2), "bw": 1.0, "rad": 0.3,
				"p": -0.3, "y": 0.5, "lw": 1.0, "legs": [0.8, -1.1, -0.5, -0.5]}],
		[0.07, {"fl": Vector3(-0.1, 0.0, 0.2), "hw": 1.0, "blade": Vector3(0.0, -0.05, 0.0), "bw": 1.0, "rad": 0.85,
				"p": -0.65, "y": -0.4, "lift": 0.1, "sq": -0.3, "lw": 1.0, "legs": [1.1, -0.5, -0.9, -0.1]}],
		[0.3, {"fl": Vector3(-0.15, -0.05, 0.15), "hw": 0.8, "blade": Vector3(0.0, -0.1, 0.0), "bw": 1.0, "rad": 0.75,
				"p": -0.5, "y": -0.3, "lw": 1.0, "legs": [1.0, -0.7, -0.6, -0.3]}],
		[0.6, {}]]},
	# a Haul Slam armed: pulled along with the blade cocked high behind the head (held till arrival)
	"jug_haul_wind": {"hold": true, "keys": [
		[0.0, {"fl": Vector3(0.1, 0.12, -0.5), "hw": 1.0, "p": -0.2}],
		[0.15, {"fl": Vector3(0.12, 0.15, -0.5), "hw": 1.0, "blade": Vector3(0.0, 2.9, 0.0), "bw": 1.0, "p": 0.25,
				"lift": 0.12, "lw": 1.0, "legs": [0.9, -1.5, 0.7, -1.3], "sq": -0.2}]]},
	# ... arriving: the whole weight comes down through the blade
	"jug_haulslam": {"keys": [
		[0.0, {"blade": Vector3(0.0, 2.9, 0.0), "bw": 1.0, "p": 0.25, "lift": 0.12, "lw": 1.0,
				"legs": [0.9, -1.5, 0.7, -1.3]}],
		[0.06, {"blade": Vector3(0.0, -1.4, 0.0), "bw": 1.0, "rad": 0.6, "p": -0.8, "lift": -0.2, "sq": 0.55, "lw": 1.0,
				"legs": [1.25, -1.8, -0.45, -1.2]}],
		[0.35, {"blade": Vector3(0.0, -1.3, 0.0), "bw": 0.9, "rad": 0.55, "p": -0.6, "lift": -0.14, "sq": 0.25,
				"lw": 1.0, "legs": [1.1, -1.6, -0.4, -1.0]}],
		[0.7, {}]]},
	# the crash (the old Doomfall, now the Finishing Slam's sweet spot): the blade wrenched up overhead
	# out of the slam and brought down again on the spot, two-handed
	"jug_crash": {"keys": [
		[0.0, {"blade": Vector3(0.0, -1.2, 0.0), "bw": 1.0, "rad": 0.55, "p": -0.6, "lw": 1.0,
				"legs": [1.0, -1.4, -0.35, -0.8]}],
		[0.05, {"blade": Vector3(0.0, 2.9, 0.0), "bw": 1.0, "p": 0.4, "lift": 0.18, "sq": -0.3, "lw": 1.0,
				"legs": [0.3, -0.6, 0.1, -0.5]}],
		[0.11, {"blade": Vector3(0.0, -1.4, 0.0), "bw": 1.0, "rad": 0.6, "p": -0.8, "lift": -0.22, "sq": 0.55,
				"lw": 1.0, "legs": [1.2, -1.7, -0.5, -1.3]}],
		[0.45, {"blade": Vector3(0.0, -1.3, 0.0), "bw": 0.9, "rad": 0.55, "p": -0.65, "lift": -0.15, "sq": 0.25,
				"lw": 1.0, "legs": [1.1, -1.6, -0.45, -1.2]}],
		[0.85, {}]]},
	# ---------------------------------------------------------------- Dancer (thief)
	# Arc Bolts, one per hand (footage 0028-0039: 2-3 frames a shot, one arm whipped forward from a wide
	# low stance, the torso turned about 30 degrees into it, the legs keeping their stance). The arm
	# itself is the twin-hold swing (combo 0 right, 1 left); this is the body: a coil, the release at
	# 0.08, the follow-through to 0.22, back by 0.42
	"thf_lmb_r": {"keys": [
		[0.0, {"y": 0.30, "p": 0.08, "sq": 0.12, "lw": 0.6, "legs": [0.5, -0.95, -0.4, -0.65], "lift": -0.07}],
		[0.08, {"y": -0.75, "p": -0.24, "sq": -0.16, "lw": 0.6, "legs": [0.6, -0.9, -0.5, -0.55], "lift": -0.03}],
		[0.16, {"y": -0.62, "p": -0.2, "sq": -0.05, "lw": 0.5, "legs": [0.55, -0.9, -0.45, -0.6], "lift": -0.05}],
		[0.28, {"y": -0.40, "p": -0.1, "sq": 0.04, "lw": 0.4, "legs": [0.45, -0.85, -0.35, -0.6], "lift": -0.05}],
		[0.42, {}]]},
	"thf_lmb_l": {"keys": [
		[0.0, {"y": -0.30, "p": 0.08, "sq": 0.12, "lw": 0.6, "legs": [0.5, -0.95, -0.4, -0.65], "lift": -0.07}],
		[0.08, {"y": 0.75, "p": -0.24, "sq": -0.16, "lw": 0.6, "legs": [0.6, -0.9, -0.5, -0.55], "lift": -0.03}],
		[0.16, {"y": 0.62, "p": -0.2, "sq": -0.05, "lw": 0.5, "legs": [0.55, -0.9, -0.45, -0.6], "lift": -0.05}],
		[0.28, {"y": 0.40, "p": -0.1, "sq": 0.04, "lw": 0.4, "legs": [0.45, -0.85, -0.35, -0.6], "lift": -0.05}],
		[0.42, {}]]},
	# the empowered bolt (0143): planted and stretched into it, then a hard recoil back on the heels
	"thf_primed": {"keys": [
		[0.0, {"p": -0.3, "sq": 0.15, "lw": 0.8, "legs": [0.8, -1.1, -0.5, -0.4], "lift": -0.08}],
		[0.06, {"p": -0.42, "sq": -0.22, "lw": 0.8, "legs": [0.9, -0.8, -0.6, -0.3]}],
		[0.16, {"p": 0.25, "sq": 0.1, "lw": 0.7, "legs": [0.4, -0.6, -0.2, -0.4]}],
		[0.5, {}]]},
	# Vault: a real cartwheel in the plane of travel (0134-0137), legs split wide over the top, arms out;
	# the dash runs 0.25s, the landing absorbs, back up by 0.55
	"thf_vault_r": {"keys": [[0.0, {"sq": 0.15, "lw": 0.6, "legs": [0.5, -0.8, 0.4, -0.7]}], [0.04, {"lift": 0.22,
			"lw": 1.0, "legs": [1.1, -0.15, -1.1, -0.15], "fl": Vector3(-0.42, 0.25, 0.0), "hw": 1.0}],
		[0.26, {"fz": -6.283, "lift": 0.32, "lw": 1.0, "legs": [1.1, -0.15, -1.1, -0.15],
				"fl": Vector3(-0.42, 0.25, 0.0),
				"hw": 1.0}], [0.33, {"fz": -6.283, "sq": 0.28, "lw": 0.8,
						"legs": [0.7, -1.1, 0.4, -0.9]}], [0.55, {"fz": -6.283}]]},
	"thf_vault_l": {"keys": [[0.0, {"sq": 0.15, "lw": 0.6, "legs": [0.5, -0.8, 0.4, -0.7]}], [0.04, {"lift": 0.22,
			"lw": 1.0, "legs": [1.1, -0.15, -1.1, -0.15], "fl": Vector3(-0.42, 0.25, 0.0), "hw": 1.0}],
		[0.26, {"fz": 6.283, "lift": 0.32, "lw": 1.0, "legs": [1.1, -0.15, -1.1, -0.15],
				"fl": Vector3(-0.42, 0.25, 0.0),
				"hw": 1.0}], [0.33, {"fz": 6.283, "sq": 0.28, "lw": 0.8,
						"legs": [0.7, -1.1, 0.4, -0.9]}], [0.55, {"fz": 6.283}]]},
	# the Bola (0100-0102): whirled overhead in the free hand through the 0.4s lane, then slung with a
	# forward lunge at 0.42
	"thf_bola": {"keys": [
		[0.0, {}],
		[0.08, {"fl": Vector3(-0.15, 0.48, 0.05), "hw": 1.0, "y": -0.3, "p": 0.12}],
		[0.2, {"fl": Vector3(0.12, 0.46, -0.1), "hw": 1.0, "y": -0.15, "p": 0.12}],
		[0.32, {"fl": Vector3(-0.15, 0.48, 0.05), "hw": 1.0, "y": -0.3, "p": 0.12}],
		[0.42, {"fl": Vector3(0.12, 0.1, -0.55), "hw": 1.0, "y": 0.55, "p": -0.35, "sq": -0.12, "lw": 0.9,
				"legs": [0.95, -0.7, -0.5, -0.2], "lift": -0.06}],
		[0.7, {}]]},
	# the Shadow Knife (0222-0225): a spin into a side-arm throw, released at 0.12
	"thf_knife": {"keys": [
		[0.0, {}],
		[0.07, {"fy": 1.6, "fl": Vector3(-0.35, 0.12, 0.2), "hw": 1.0, "p": 0.05}],
		[0.12, {"fy": 0.0, "fl": Vector3(0.15, 0.08, -0.55), "hw": 1.0, "y": 0.55, "p": -0.25, "lw": 0.6,
				"legs": [0.7, -0.8, -0.35, -0.25]}],
		[0.42, {}]]},
	# ... arriving at it: dropped in low out of the blink, then rising
	"thf_arrive": {"keys": [
		[0.0, {"lift": 0.2, "sq": -0.3, "lw": 1.0, "legs": [0.6, -0.9, 0.4, -0.8]}],
		[0.06, {"lift": -0.14, "p": -0.45, "sq": 0.45, "lw": 1.0, "legs": [1.25, -2.0, -0.2, -1.6]}],
		[0.3, {"lift": -0.1, "p": -0.35, "sq": 0.2, "lw": 1.0, "legs": [1.15, -1.8, -0.15, -1.4]}],
		[0.6, {}]]},
	# Jackpot (0296-0350): she keeps walking and shooting, the body snapping side to side as the free
	# arm flings the blades out (no leg keys: the walk keeps the legs)
	"thf_volley": {"keys": [
		[0.0, {"p": 0.12, "sq": -0.15}],
		[0.2, {"y": 0.55, "fl": Vector3(0.1, 0.15, -0.5), "hw": 1.0}],
		[0.4, {"y": -0.55, "fl": Vector3(-0.45, 0.15, -0.1), "hw": 1.0}],
		[0.6, {"y": 0.55, "fl": Vector3(0.1, 0.15, -0.5), "hw": 1.0}],
		[0.8, {"y": -0.55, "fl": Vector3(-0.45, 0.15, -0.1), "hw": 1.0}],
		[1.0, {"y": 0.55, "fl": Vector3(0.1, 0.15, -0.5), "hw": 1.0}],
		[1.2, {"y": -0.55, "fl": Vector3(-0.45, 0.15, -0.1), "hw": 1.0}],
		[1.4, {"y": 0.55, "fl": Vector3(0.1, 0.15, -0.5), "hw": 1.0}],
		[1.6, {}]]},
	# ---------------------------------------------------------------- per-hero base dash (the long air dash)
	# Dancer flicks into a forward tumble, tucked, then opens out to land light
	"thf_exdash": {"keys": [
		[0.0, {"sq": -0.2, "p": -0.3, "lw": 0.8, "legs": [0.9, -0.4, -0.6, -0.3]}],
		[0.05, {"fx": -1.5, "lift": 0.15, "sq": 0.15, "lw": 1.0, "legs": [1.6, -2.1, 1.5, -2.0]}],
		[0.2, {"fx": -6.283, "lift": 0.1, "lw": 1.0, "legs": [1.6, -2.1, 1.5, -2.0]}],
		[0.28, {"fx": -6.283, "sq": 0.3, "lw": 0.9, "legs": [0.8, -1.3, 0.5, -1.0]}],
		[0.45, {"fx": -6.283}]]},
	# Juggernaut lumbers: head down, shoulder driven forward, a heavy stamp and settle at the end
	"jug_exdash": {"keys": [
		[0.0, {"p": -0.2, "sq": 0.2, "lw": 0.8, "legs": [0.6, -1.0, -0.4, -0.6], "lift": -0.06}],
		[0.06, {"p": -0.55, "y": 0.55, "sq": -0.15, "lw": 1.0, "legs": [1.1, -0.6, -0.8, -0.2],
				"blade": Vector3(-0.6, -0.3, 1.2), "bw": 0.8}],
		[0.2, {"p": -0.5, "y": 0.5, "lw": 1.0, "legs": [1.0, -0.7, -0.7, -0.3], "blade": Vector3(-0.6, -0.3, 1.2),
				"bw": 0.8}],
		[0.26, {"p": -0.15, "sq": 0.35, "lift": -0.12, "lw": 1.0, "legs": [0.9, -1.4, -0.4, -0.9]}],
		[0.5, {}]]},
	# ---------------------------------------------------------------- payoffs and passive procs
	# Dancer, VAULT RESET: a spin on the heel with the arms flung wide, then a snap back to aim
	"thf_reset": {"keys": [
		[0.0, {"sq": 0.15, "lift": -0.05}],
		[0.08, {"fy": -3.14, "sq": -0.15, "lift": 0.08, "fl": Vector3(-0.45, 0.25, 0.0), "hw": 1.0}],
		[0.18, {"fy": -6.283, "sq": 0.1, "fl": Vector3(-0.45, 0.2, 0.0), "hw": 0.8}],
		[0.4, {"fy": -6.283}]]},
	# Dancer, a knock: a flourish, chin up, one blade raised, the heal rising through her
	"thf_flourish": {"keys": [
		[0.0, {}],
		[0.1, {"p": 0.25, "lift": 0.1, "sq": -0.2, "fl": Vector3(-0.1, 0.55, -0.05), "hw": 1.0}],
		[0.45, {"p": 0.18, "lift": 0.05, "fl": Vector3(-0.1, 0.5, -0.05), "hw": 0.8}],
		[0.75, {}]]},
	# Juggernaut, Enraged (and a knock): a roar, chest thrown up and out, arms wide, then hunched and swelling
	"jug_roar": {"keys": [
		[0.0, {"p": -0.3, "sq": 0.2, "lift": -0.08, "lw": 1.0, "legs": [0.7, -1.1, 0.5, -1.0]}],
		[0.12, {"p": 0.45, "sq": -0.25, "lift": 0.1, "fl": Vector3(-0.5, 0.35, 0.05), "hw": 1.0,
				"blade": Vector3(0.0, 2.6, 0.0), "bw": 0.7, "lw": 1.0, "legs": [0.4, -0.6, 0.3, -0.5]}],
		[0.5, {"p": 0.35, "sq": -0.15, "fl": Vector3(-0.5, 0.3, 0.05), "hw": 1.0, "blade": Vector3(0.0, 2.6, 0.0),
				"bw": 0.7}],
		[0.75, {"p": -0.15, "sq": 0.15}],
		[1.0, {}]]},
	# Juggernaut slashes: the body for each swing (the blade is the greatsword swing): a step into it,
	# the hips turning through, the follow-through dragging the weight round
	"jug_slash_r": {"keys": [
		[0.0, {"y": 0.35, "sq": 0.1, "lw": 0.8, "legs": [0.7, -1.0, -0.4, -0.5], "lift": -0.05}],
		[0.1, {"y": -0.6, "p": -0.25, "sq": -0.12, "lw": 0.9, "legs": [0.95, -0.7, -0.6, -0.3]}],
		[0.24, {"y": -0.5, "p": -0.15, "lw": 0.7, "legs": [0.85, -0.8, -0.5, -0.35]}],
		[0.45, {}]]},
	"jug_slash_l": {"keys": [
		[0.0, {"y": -0.35, "sq": 0.1, "lw": 0.8, "legs": [0.7, -1.0, -0.4, -0.5], "lift": -0.05}],
		[0.1, {"y": 0.6, "p": -0.25, "sq": -0.12, "lw": 0.9, "legs": [0.95, -0.7, -0.6, -0.3]}],
		[0.24, {"y": 0.5, "p": -0.15, "lw": 0.7, "legs": [0.85, -0.8, -0.5, -0.35]}],
		[0.45, {}]]},
	# the Searing Wave held: the blade dragged up behind the head, the body leaning back, coiling
	"jug_wave_wind": {"hold": true, "keys": [
		[0.0, {}],
		[0.25, {"blade": Vector3(0.0, 2.4, 0.0), "bw": 1.0, "p": 0.3, "sq": 0.18, "lift": -0.06, "lw": 1.0,
				"legs": [0.7, -1.2, -0.4, -0.7]}],
		[0.7, {"blade": Vector3(0.0, 2.7, 0.0), "bw": 1.0, "p": 0.38, "sq": 0.25, "lift": -0.1, "lw": 1.0,
				"legs": [0.8, -1.3, -0.45, -0.8]}]]},
}
