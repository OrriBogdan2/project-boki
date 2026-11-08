class_name KMovesDJ
extends RefCounted
## Keyed full-body moves of Sable (thief) and Juggernaut (same format and channels as
## HunterAnim.KMOVES; HunterAnim.km_sample looks here after KMOVES, KMovesPair and MergeMoves). Each is
## anticipation -> a key pose on the hit -> follow-through and recovery, keyed to the kit's own timing
## and to the footage frame counts in briefs/hero-ref/dancer.md and juggernaut.md (5 fps: a frame is 0.2s).

const MOVES := {
	# ---------------------------------------------------------------- Juggernaut
	# the Searing Wave let go: a flat side swing from his right across to his left at waist height,
	# the hips turning through it, the weight stepping into it
	"jug_wave": {"keys": [
		[0.0, {"blade": Vector3(-1.9, 0.1, 0.0), "bw": 1.0, "rad": 0.5, "y": 0.9, "p": 0.1, "lw": 1.0,
				"legs": [0.8, -1.2, -0.45, -0.8], "sq": 0.2}],
		[0.1, {"blade": Vector3(1.5, 0.0, 0.0), "bw": 1.0, "rad": 0.75, "y": -0.95, "p": -0.35, "lw": 1.0,
				"legs": [1.0, -1.0, -0.6, -0.3], "sq": -0.1}],
		[0.32, {"blade": Vector3(1.7, 0.05, 0.0), "bw": 0.8, "y": -0.7, "p": -0.25, "lw": 0.8,
				"legs": [0.8, -0.9, -0.5, -0.3]}],
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
	# the Lunge, held as long as RMB is held, ready to lunge: he sinks onto the loaded
	# back leg and levels the blade forward at the aim, leaning in behind it
	"jug_lunge_wind": {"hold": true, "keys": [
		[0.0, {}],
		[0.1, {"blade": Vector3(-0.3, 0.6, 0.2), "bw": 1.0, "rad": 0.35, "p": -0.05, "y": 0.4, "sq": 0.12,
				"lift": -0.05, "lw": 1.0, "legs": [0.8, -1.3, -0.5, -0.7]}],
		[0.28, {"blade": Vector3(0.0, 0.2, 0.0), "bw": 1.0, "rad": 0.5, "p": -0.3, "y": 0.2, "sq": 0.28,
				"lift": -0.16, "lw": 1.0, "legs": [1.0, -1.6, -0.6, -1.0]}],
		[0.45, {"blade": Vector3(0.0, 0.15, 0.0), "bw": 1.0, "rad": 0.55, "p": -0.35, "y": 0.2, "sq": 0.3,
				"lift": -0.18, "lw": 1.0, "legs": [1.05, -1.7, -0.65, -1.05]}]]},
	# ... let go: the levelled blade drives out ahead as he goes, then the follow-through
	"jug_lunge": {"keys": [
		[0.0, {"blade": Vector3(0.0, 0.15, 0.0), "bw": 1.0, "rad": 0.55, "p": -0.35, "y": 0.2, "sq": 0.2, "lw": 1.0,
				"legs": [0.9, -1.5, -0.55, -0.9]}],
		[0.08, {"blade": Vector3(0.0, -0.05, 0.0), "bw": 1.0, "rad": 0.75, "p": -0.55, "y": -0.35, "lw": 1.0,
				"legs": [1.15, -0.7, -0.75, -0.2], "sq": -0.2}],
		[0.3, {"blade": Vector3(0.0, -0.1, 0.0), "bw": 1.0, "rad": 0.7, "p": -0.45, "y": -0.3, "lw": 1.0,
				"legs": [1.0, -0.8, -0.6, -0.3]}],
		[0.6, {}]]},
	# Meteor Drop, the hang and the dive (footage 0261-0288: the rise, a slash at the top, a steep drive): he
	# rocks back and hauls the blade up overhead with the knees tucked, turning once as he gathers (0.2s hang),
	# then drops upright and straight down, the blade driven point-down under him and the legs
	# straight; that pose holds until he hits the ground
	"jug_meteor": {"hold": true, "keys": [
		[0.0, {"p": 0.1, "sq": 0.1, "lw": 1.0, "legs": [0.9, -1.3, 0.7, -1.1]}],
		[0.08, {"blade": Vector3(0.0, 2.9, 0.0), "bw": 1.0, "rad": 0.4, "p": 0.4, "fx": 0.35, "fy": -3.14, "sq": -0.15,
				"lift": 0.12, "lw": 1.0, "legs": [1.3, -1.9, 1.2, -1.8]}],
		[0.2, {"blade": Vector3(0.0, 3.0, 0.0), "bw": 1.0, "rad": 0.45, "p": 0.45, "fx": 0.5, "fy": -6.283, "sq": 0.2,
				"lift": 0.08, "lw": 1.0, "legs": [1.35, -2.0, 1.25, -1.9]}],
		[0.3, {"blade": Vector3(0.0, -1.45, 0.0), "bw": 1.0, "rad": 0.6, "p": -0.2, "fx": 0.0, "fy": -6.283,
				"sq": -0.35, "lift": 0.05, "lw": 1.0, "legs": [0.1, -0.2, -0.1, -0.2]}]]},
	# ... the landing (0288-0300): slammed down onto the knees, the blade buried ahead, the deepest squash of
	# the six; a bounce as the weight settles, then 0.5s rising from the crouch with the blade dragged low
	"jug_meteor_land": {"keys": [
		[0.0, {"blade": Vector3(0.0, -1.45, 0.0), "bw": 1.0, "rad": 0.6, "p": -0.6, "sq": 0.75, "lift": -0.36,
				"lw": 1.0, "legs": [1.35, -2.1, -0.6, -1.6]}],
		[0.07, {"blade": Vector3(0.0, -1.4, 0.0), "bw": 1.0, "rad": 0.6, "p": -0.5, "sq": 0.6, "lift": -0.3,
				"lw": 1.0, "legs": [1.3, -2.0, -0.55, -1.5]}],
		[0.25, {"blade": Vector3(-1.2, -0.4, 1.4), "bw": 1.0, "rad": 0.45, "p": -0.4, "sq": 0.45, "lift": -0.22,
				"lw": 1.0, "legs": [1.1, -1.7, -0.45, -1.2]}],
		[0.42, {"blade": Vector3(-1.1, -0.4, 1.3), "bw": 0.8, "rad": 0.35, "p": -0.15, "sq": 0.12, "lift": -0.06,
				"lw": 0.7, "legs": [0.7, -1.0, -0.3, -0.6]}],
		[0.5, {}]]},
	# Rampage (Quick Dash, 0372-0377): a 0.15s crouch with the blade cocked high behind, the drive flat and
	# stretched along the ground with the blade levelled, the tip thrust out at its end, then a long low
	# recovery with the blade dragging behind him (up by 0.9)
	"jug_dash": {"keys": [
		[0.0, {}],
		[0.05, {"blade": Vector3(0.0, 0.5, 0.0), "bw": 1.0, "rad": 0.4, "p": 0.1, "y": 0.45, "sq": 0.3, "lift": -0.14,
				"lw": 1.0, "legs": [0.9, -1.5, -0.4, -0.9]}],
		[0.09, {"blade": Vector3(0.0, -0.1, 0.0), "bw": 1.0, "rad": 0.75, "p": -0.7, "y": 0.2, "sq": -0.3, "lw": 1.0,
				"legs": [1.15, -0.6, -0.85, -0.15]}],
		[0.2, {"blade": Vector3(0.0, 0.0, 0.0), "bw": 1.0, "rad": 0.85, "p": -0.65, "y": -0.3, "sq": -0.25, "lw": 1.0,
				"legs": [1.15, -0.6, -0.8, -0.15]}],
		[0.28, {"blade": Vector3(-1.2, -0.4, 1.4), "bw": 1.0, "rad": 0.4, "p": -0.35, "sq": 0.2, "lift": -0.1,
				"lw": 1.0, "legs": [0.95, -1.3, -0.4, -0.8]}],
		[0.42, {}]]},
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
	# Gilded Riposte, the guard (ult f33-f38, 0.6s): planted wide, the blade drawn up vertical in front of
	# him, braced and shivering a little under the gold
	"jug_guard": {"keys": [
		[0.0, {}],
		[0.08, {"blade": Vector3(0.0, 1.55, 0.0), "bw": 1.0, "rad": 0.45, "p": 0.08, "sq": 0.18, "lift": -0.08,
				"lw": 1.0, "legs": [0.75, -1.1, -0.55, -0.75]}],
		[0.36, {"blade": Vector3(0.0, 1.6, 0.0), "bw": 1.0, "rad": 0.42, "p": 0.04, "sq": 0.24, "lift": -0.1,
				"lw": 1.0, "legs": [0.8, -1.15, -0.6, -0.8]}],
		[0.66, {"blade": Vector3(0.0, 1.5, 0.0), "bw": 1.0, "rad": 0.45, "p": 0.1, "sq": 0.2, "lift": -0.09,
				"lw": 1.0, "legs": [0.8, -1.15, -0.6, -0.8]}]]},
	# ... the answer (f39-f44): the blade drops low for a beat, then he lunges and cleaves it up through
	# them, stretched tall on the release, and settles back heavy
	"jug_riposte": {"keys": [
		[0.0, {"blade": Vector3(0.0, -1.2, 0.0), "bw": 1.0, "rad": 0.6, "p": 0.3, "sq": 0.25, "lift": -0.12,
				"lw": 1.0, "legs": [1.0, -1.4, -0.4, -0.9]}],
		[0.06, {"blade": Vector3(0.0, 3.0, 0.0), "bw": 1.0, "rad": 0.55, "p": 0.38, "sq": -0.35, "lift": 0.16,
				"lw": 1.0, "legs": [1.2, -0.6, -0.75, -0.3]}],
		[0.14, {"blade": Vector3(0.0, 2.7, 0.0), "bw": 1.0, "rad": 0.5, "p": 0.2, "sq": -0.12, "lift": 0.04,
				"lw": 1.0, "legs": [1.15, -0.65, -0.7, -0.3]}],
		[0.3, {"blade": Vector3(0.0, 1.6, 0.0), "bw": 0.8, "rad": 0.45, "p": -0.1, "sq": 0.12, "lw": 0.8,
				"legs": [0.9, -0.8, -0.5, -0.4]}],
		[0.45, {}]]},
	# ---------------------------------------------------------------- Sable (thief)
	# Arc Bolts, one per hand (footage 0028-0039: 2-3 frames a shot, one arm whipped forward from a wide
	# low stance, the torso turned about 30 degrees into it; running, the legs keep running). The body for
	# each throw; the blade and the hand on it are whipped by the swing (HunterAnim.SWINGS "arc_bolts": from
	# cocked out wide and high to straight ahead at reach, about 0.05s). The bolt leaves as the move starts, so
	# it starts wound toward the throwing side (the last throw's recovery wound it there), unwinds through
	# the throw by 0.04, overshoots at 0.12, settles by 0.26, and by 0.45 (the next bolt) is wound toward the
	# other hand, where the next throw starts; with no next bolt she lets it go by 0.7. The legs are a stance.
	"thf_lmb_r": {"stance": true, "swing": 0, "keys": [
		[0.0, {"y": 0.5, "p": 0.12, "sq": 0.16, "lift": -0.1, "lw": 1.0, "legs": [0.85, -1.2, -0.75, -0.9]}],
		[0.04, {"y": -0.5, "p": -0.3, "sq": -0.2, "lift": -0.04, "lw": 1.0, "legs": [0.95, -1.0, -0.8, -0.6]}],
		[0.12, {"y": -0.62, "p": -0.34, "sq": -0.08, "lift": -0.05, "lw": 1.0, "legs": [0.95, -1.05, -0.8, -0.65]}],
		[0.26, {"y": -0.2, "p": -0.04, "sq": 0.05, "lift": -0.07, "lw": 1.0, "legs": [0.8, -1.1, -0.7, -0.85]}],
		[0.45, {"y": -0.5, "p": 0.12, "sq": 0.16, "lift": -0.1, "lw": 1.0, "legs": [0.85, -1.2, -0.75, -0.9]}],
		[0.7, {}]]},
	"thf_lmb_l": {"stance": true, "swing": 1, "keys": [
		[0.0, {"y": -0.5, "p": 0.12, "sq": 0.16, "lift": -0.1, "lw": 1.0, "legs": [0.85, -1.2, -0.75, -0.9]}],
		[0.04, {"y": 0.5, "p": -0.3, "sq": -0.2, "lift": -0.04, "lw": 1.0, "legs": [0.95, -1.0, -0.8, -0.6]}],
		[0.12, {"y": 0.62, "p": -0.34, "sq": -0.08, "lift": -0.05, "lw": 1.0, "legs": [0.95, -1.05, -0.8, -0.65]}],
		[0.26, {"y": 0.2, "p": -0.04, "sq": 0.05, "lift": -0.07, "lw": 1.0, "legs": [0.8, -1.1, -0.7, -0.85]}],
		[0.45, {"y": 0.5, "p": 0.12, "sq": 0.16, "lift": -0.1, "lw": 1.0, "legs": [0.85, -1.2, -0.75, -0.9]}],
		[0.7, {}]]},
	# the empowered bolt (0143: a big streak, a vertical blade flash at her hands), thrown with both blades at
	# once (the swing drives both out in a V, HunterAnim.SWINGS "arc_bolts" step 2): she is caught coiled and
	# sunk low, lunges into it at 0.04, holds the reach through 0.12, recoils back onto her heels by 0.24 and
	# settles by 0.55 (the next bolt's throw takes over at 0.45)
	"thf_primed": {"swing": 2, "keys": [
		[0.0, {"p": 0.16, "sq": 0.22, "lift": -0.1, "lw": 1.0, "legs": [0.85, -1.25, -0.7, -0.95]}],
		[0.04, {"p": -0.46, "sq": -0.26, "lift": -0.02, "lw": 1.0, "legs": [1.05, -0.9, -0.9, -0.5]}],
		[0.12, {"p": -0.52, "sq": -0.18, "lift": -0.03, "lw": 1.0, "legs": [1.1, -0.95, -0.95, -0.5]}],
		[0.24, {"p": 0.24, "sq": 0.14, "lift": -0.06, "lw": 0.9, "legs": [0.5, -0.7, -0.3, -0.55]}],
		[0.38, {"p": 0.06, "sq": 0.04, "lw": 0.5, "legs": [0.7, -0.95, -0.55, -0.7], "lift": -0.05}],
		[0.55, {}]]},
	# Vault, the ground Cartwheel (sheet: body 0176-0178, 0134-0137), inside the 0.48s dash: a 0.05s crouch with
	# the arms swung up and the body leaning into the side, a push-off with the crossbows tucked to her chest and
	# the wings flaring, one full aerial turn in the plane of travel, a low two-beat landing crouch at 0.36, upright
	# by 0.48 (a bolt thrown mid-flip whips both blades out in a V, swing step 2: footage 0193, the Cartwheel and
	# the empowered shot on one frame with a blade flash at her hands)
	"thf_vault_r": {"swing": 2, "keys": [
		[0.0, {}],
		[0.05, {"sq": 0.24, "lift": -0.08, "p": 0.12, "r": 0.32, "lw": 1.0, "legs": [0.8, -1.3, 0.6, -1.1],
				"fl": Vector3(-0.25, 0.6, 0.05), "hw": 1.0, "fr": Vector3(0.25, 0.6, 0.05), "rw": 1.0, "wg": 0.5}],
		[0.1, {"fz": -0.6, "sq": -0.18, "lift": 0.34, "r": 0.2, "lw": 1.0, "legs": [1.2, -0.05, -1.2, -0.05],
				"fl": Vector3(-0.16, 0.0, -0.2), "hw": 1.0, "fr": Vector3(0.16, 0.0, -0.2), "rw": 1.0, "wg": 1.0}],
		[0.3, {"fz": -6.283, "sq": -0.12, "lift": 0.42, "lw": 1.0, "legs": [1.2, -0.05, -1.2, -0.05],
				"fl": Vector3(-0.16, 0.0, -0.2), "hw": 1.0, "fr": Vector3(0.16, 0.0, -0.2), "rw": 1.0, "wg": 1.0}],
		[0.36, {"fz": -6.283, "sq": 0.3, "lift": -0.1, "p": 0.18, "lw": 1.0, "legs": [0.9, -1.4, 0.5, -1.2],
				"fl": Vector3(-0.5, 0.0, 0.15), "hw": 1.0, "fr": Vector3(0.5, 0.0, 0.15), "rw": 1.0, "wg": 0.6}],
		[0.48, {"fz": -6.283}]]},
	"thf_vault_l": {"swing": 2, "keys": [
		[0.0, {}],
		[0.05, {"sq": 0.24, "lift": -0.08, "p": 0.12, "r": -0.32, "lw": 1.0, "legs": [0.8, -1.3, 0.6, -1.1],
				"fl": Vector3(-0.25, 0.6, 0.05), "hw": 1.0, "fr": Vector3(0.25, 0.6, 0.05), "rw": 1.0, "wg": 0.5}],
		[0.1, {"fz": 0.6, "sq": -0.18, "lift": 0.34, "r": -0.2, "lw": 1.0, "legs": [1.2, -0.05, -1.2, -0.05],
				"fl": Vector3(-0.16, 0.0, -0.2), "hw": 1.0, "fr": Vector3(0.16, 0.0, -0.2), "rw": 1.0, "wg": 1.0}],
		[0.3, {"fz": 6.283, "sq": -0.12, "lift": 0.42, "lw": 1.0, "legs": [1.2, -0.05, -1.2, -0.05],
				"fl": Vector3(-0.16, 0.0, -0.2), "hw": 1.0, "fr": Vector3(0.16, 0.0, -0.2), "rw": 1.0, "wg": 1.0}],
		[0.36, {"fz": 6.283, "sq": 0.3, "lift": -0.1, "p": 0.18, "lw": 1.0, "legs": [0.9, -1.4, 0.5, -1.2],
				"fl": Vector3(-0.5, 0.0, 0.15), "hw": 1.0, "fr": Vector3(0.5, 0.0, 0.15), "rw": 1.0, "wg": 0.6}],
		[0.48, {"fz": 6.283}]]},
	# ... the routine's second flip (ThiefChain): a tucked somersault the way she goes, knees to her chest, the same
	# beats as the cartwheel so a chain keeps its rhythm
	"thf_vault_f": {"swing": 2, "keys": [
		[0.0, {}],
		[0.05, {"sq": 0.28, "lift": -0.1, "p": -0.3, "lw": 1.0, "legs": [1.0, -1.5, 0.8, -1.3],
				"fl": Vector3(-0.3, -0.1, 0.25), "hw": 1.0, "fr": Vector3(0.3, -0.1, 0.25), "rw": 1.0, "wg": 0.5}],
		[0.1, {"fx": -0.7, "sq": -0.1, "lift": 0.4, "lw": 1.0, "legs": [1.35, -2.0, 1.25, -1.9],
				"fl": Vector3(-0.16, -0.05, -0.2), "hw": 1.0, "fr": Vector3(0.16, -0.05, -0.2), "rw": 1.0, "wg": 1.0}],
		[0.3, {"fx": -6.283, "sq": 0.1, "lift": 0.45, "lw": 1.0, "legs": [1.35, -2.0, 1.25, -1.9],
				"fl": Vector3(-0.16, -0.05, -0.2), "hw": 1.0, "fr": Vector3(0.16, -0.05, -0.2), "rw": 1.0, "wg": 1.0}],
		[0.36, {"fx": -6.283, "sq": 0.3, "lift": -0.1, "p": 0.18, "lw": 1.0, "legs": [0.9, -1.4, 0.5, -1.2],
				"fl": Vector3(-0.5, 0.0, 0.15), "hw": 1.0, "fr": Vector3(0.5, 0.0, 0.15), "rw": 1.0, "wg": 0.6}],
		[0.48, {"fx": -6.283}]]},
	"thf_vault_b": {"swing": 2, "keys": [
		[0.0, {}],
		[0.05, {"sq": 0.28, "lift": -0.1, "p": 0.25, "lw": 1.0, "legs": [1.0, -1.5, 0.8, -1.3],
				"fl": Vector3(-0.3, 0.5, 0.1), "hw": 1.0, "fr": Vector3(0.3, 0.5, 0.1), "rw": 1.0, "wg": 0.5}],
		[0.1, {"fx": 0.7, "sq": -0.1, "lift": 0.4, "lw": 1.0, "legs": [1.35, -2.0, 1.25, -1.9],
				"fl": Vector3(-0.16, -0.05, -0.2), "hw": 1.0, "fr": Vector3(0.16, -0.05, -0.2), "rw": 1.0, "wg": 1.0}],
		[0.3, {"fx": 6.283, "sq": 0.1, "lift": 0.45, "lw": 1.0, "legs": [1.35, -2.0, 1.25, -1.9],
				"fl": Vector3(-0.16, -0.05, -0.2), "hw": 1.0, "fr": Vector3(0.16, -0.05, -0.2), "rw": 1.0, "wg": 1.0}],
		[0.36, {"fx": 6.283, "sq": 0.3, "lift": -0.1, "p": 0.18, "lw": 1.0, "legs": [0.9, -1.4, 0.5, -1.2],
				"fl": Vector3(-0.5, 0.0, 0.15), "hw": 1.0, "fr": Vector3(0.5, 0.0, 0.15), "rw": 1.0, "wg": 0.6}],
		[0.48, {"fx": 6.283}]]},
	# ... and its third: a stretched corkscrew, the cartwheel's turn with a full spin wrapped round it, legs together
	# and the crossbows drawn in tight
	"thf_vault_twist": {"swing": 2, "keys": [
		[0.0, {}],
		[0.05, {"sq": 0.24, "lift": -0.08, "p": 0.1, "lw": 1.0, "legs": [0.8, -1.3, 0.6, -1.1],
				"fl": Vector3(-0.25, 0.6, 0.05), "hw": 1.0, "fr": Vector3(0.25, 0.6, 0.05), "rw": 1.0, "wg": 0.5}],
		[0.1, {"fz": -0.6, "fy": 0.6, "sq": -0.25, "lift": 0.34, "lw": 1.0, "legs": [0.15, -0.1, -0.15, -0.1],
				"fl": Vector3(-0.14, 0.05, -0.16), "hw": 1.0, "fr": Vector3(0.14, 0.05, -0.16), "rw": 1.0, "wg": 1.0}],
		[0.3, {"fz": -6.283, "fy": 6.283, "sq": -0.25, "lift": 0.45, "lw": 1.0, "legs": [0.15, -0.1, -0.15, -0.1],
				"fl": Vector3(-0.14, 0.05, -0.16), "hw": 1.0, "fr": Vector3(0.14, 0.05, -0.16), "rw": 1.0, "wg": 1.0}],
		[0.36, {"fz": -6.283, "fy": 6.283, "sq": 0.3, "lift": -0.1, "p": 0.18, "lw": 1.0,
				"legs": [0.9, -1.4, 0.5, -1.2], "fl": Vector3(-0.5, 0.0, 0.15), "hw": 1.0,
				"fr": Vector3(0.5, 0.0, 0.15), "rw": 1.0, "wg": 0.6}],
		[0.48, {"fz": -6.283, "fy": 6.283}]]},
	# the Bola (0100-0102): the right hand raised over the head and circled (three points every 0.13s)
	# through the 0.4s lane, the weights whirling round it (DJFx), then slung with a long forward lunge; the
	# legs are a stance, so walking through the wind-up she keeps walking
	"thf_bola": {"stance": true, "keys": [
		[0.0, {}],
		[0.05, {"fr": Vector3(0.1, 0.62, 0.05), "rw": 1.0, "y": -0.25, "p": 0.14, "lw": 0.8,
				"legs": [0.6, -1.0, -0.5, -0.7]}],
		[0.093, {"fr": Vector3(0.26, 0.72, 0.06), "rw": 1.0, "y": -0.25, "p": 0.14, "lw": 0.8,
				"legs": [0.6, -1.0, -0.5, -0.7]}],
		[0.136, {"fr": Vector3(0.00, 0.78, -0.24), "rw": 1.0, "y": -0.25, "p": 0.14, "lw": 0.8,
				"legs": [0.6, -1.0, -0.5, -0.7]}],
		[0.179, {"fr": Vector3(-0.22, 0.72, 0.08), "rw": 1.0, "y": -0.25, "p": 0.14, "lw": 0.8,
				"legs": [0.6, -1.0, -0.5, -0.7]}],
		[0.222, {"fr": Vector3(0.26, 0.72, 0.06), "rw": 1.0, "y": -0.25, "p": 0.14, "lw": 0.8,
				"legs": [0.6, -1.0, -0.5, -0.7]}],
		[0.265, {"fr": Vector3(0.00, 0.78, -0.24), "rw": 1.0, "y": -0.25, "p": 0.14, "lw": 0.8,
				"legs": [0.6, -1.0, -0.5, -0.7]}],
		[0.308, {"fr": Vector3(-0.22, 0.72, 0.08), "rw": 1.0, "y": -0.25, "p": 0.14, "lw": 0.8,
				"legs": [0.6, -1.0, -0.5, -0.7]}],
		[0.351, {"fr": Vector3(0.26, 0.72, 0.06), "rw": 1.0, "y": -0.25, "p": 0.14, "lw": 0.8,
				"legs": [0.6, -1.0, -0.5, -0.7]}],
		[0.394, {"fr": Vector3(0.00, 0.78, -0.24), "rw": 1.0, "y": -0.25, "p": 0.14, "lw": 0.8,
				"legs": [0.6, -1.0, -0.5, -0.7]}],
		[0.42, {"fr": Vector3(0.08, 0.18, -0.66), "rw": 1.0, "y": 0.6, "p": -0.42, "sq": -0.15, "lift": -0.08,
				"lw": 1.0, "legs": [1.15, -0.7, -0.75, -0.2]}],
		[0.5, {"fr": Vector3(0.04, 0.1, -0.7), "rw": 1.0, "y": 0.5, "p": -0.38, "lw": 1.0,
				"legs": [1.1, -0.75, -0.7, -0.25]}],
		[0.75, {}]]},
	# the Shadow Knife (0222-0225): a whole-body spin (about 250 degrees by 0.09) with the off hand cocked
	# back, unwinding into a side-arm throw released at 0.12
	"thf_knife": {"keys": [
		[0.0, {"sq": 0.12, "lift": -0.04}],
		[0.04, {"fy": -1.6, "fl": Vector3(-0.42, 0.2, 0.15), "hw": 1.0, "p": 0.08, "sq": 0.1, "lw": 0.8,
				"legs": [0.5, -0.9, 0.3, -0.7]}],
		[0.09, {"fy": -4.4, "fl": Vector3(-0.3, 0.26, 0.3), "hw": 1.0, "p": 0.12, "lift": 0.04, "lw": 0.8,
				"legs": [0.4, -0.8, 0.5, -0.9]}],
		[0.12, {"fy": -6.283, "fl": Vector3(0.18, 0.1, -0.66), "hw": 1.0, "y": 0.6, "p": -0.32, "sq": -0.15, "lw": 1.0,
				"legs": [0.95, -0.8, -0.6, -0.3]}],
		[0.24, {"fy": -6.283, "fl": Vector3(0.22, 0.06, -0.6), "hw": 1.0, "y": 0.5, "p": -0.26, "lw": 0.9,
				"legs": [0.9, -0.85, -0.55, -0.35]}],
		[0.45, {"fy": -6.283}]]},
	# ... arriving at it: dropped in low out of the blink, then rising
	"thf_arrive": {"keys": [
		[0.0, {"lift": 0.2, "sq": -0.3, "lw": 1.0, "legs": [0.6, -0.9, 0.4, -0.8]}],
		[0.06, {"lift": -0.14, "p": -0.45, "sq": 0.45, "lw": 1.0, "legs": [1.25, -2.0, -0.2, -1.6]}],
		[0.3, {"lift": -0.1, "p": -0.35, "sq": 0.2, "lw": 1.0, "legs": [1.15, -1.8, -0.15, -1.4]}],
		[0.6, {}]]},
	# Encore (ult f27-f35): both blades raised as the ring grows (anticipation, a little squash), then a
	# whole-body spin as it opens, done by 0.4s when the dance takes over (no leg keys: she walks)
	"thf_encore": {"keys": [
		[0.0, {}],
		[0.08, {"fl": Vector3(-0.3, 0.55, 0.1), "hw": 1.0, "fr": Vector3(0.3, 0.55, 0.1), "rw": 1.0, "p": 0.18,
				"sq": 0.15}],
		[0.2, {"fl": Vector3(-0.35, 0.6, 0.05), "hw": 1.0, "fr": Vector3(0.35, 0.6, 0.05), "rw": 1.0, "p": 0.1,
				"sq": 0.2, "fy": 0.0}],
		[0.38, {"fl": Vector3(-0.55, 0.35, 0.0), "hw": 1.0, "fr": Vector3(0.55, 0.35, 0.0), "rw": 1.0, "p": -0.1,
				"sq": -0.2, "fy": 6.283}],
		[0.55, {}]]},
	# ... the dance (our own choreography, on Encore's 0.2s beats; f33-f35 is the source's arm snap): eight beats
	# that loop, one fling per beat, right on the even ones, left on the odd, so the blade leaves the hand that is
	# out at that moment (ThiefUlt._volley). Two side flings, a pirouette with the arms wide and the wings open, two
	# low sweeps, then the crossbows crossed overhead and a twirl back. Upper body and hips only: walking, the legs
	# keep walking (the leg keys are a stance)
	"thf_encore_dance": {"hold": true, "loop": 0.0, "stance": true, "keys": [
		[0.0, {"y": 0.65, "fr": Vector3(0.62, 0.12, -0.2), "rw": 1.0, "fl": Vector3(-0.3, 0.2, 0.25), "hw": 0.7,
				"sq": -0.12, "wg": 0.7, "lw": 0.7, "legs": [0.6, -0.9, -0.5, -0.6]}],
		[0.12, {"y": 0.3, "fl": Vector3(-0.2, 0.35, 0.2), "hw": 1.0, "fr": Vector3(0.45, 0.2, 0.1), "rw": 0.8,
				"sq": 0.1, "wg": 0.3, "lw": 0.6, "legs": [0.4, -1.0, -0.2, -0.8]}],
		[0.2, {"y": -0.65, "fl": Vector3(-0.62, 0.12, -0.2), "hw": 1.0, "fr": Vector3(0.3, 0.2, 0.25), "rw": 0.7,
				"sq": -0.12, "wg": 0.7, "lw": 0.7, "legs": [-0.5, -0.6, 0.6, -0.9]}],
		[0.32, {"y": -0.2, "fl": Vector3(-0.5, 0.25, 0.05), "hw": 0.8, "fr": Vector3(0.45, 0.3, 0.1), "rw": 1.0,
				"sq": 0.14, "lift": -0.05, "wg": 0.4, "lw": 0.6, "legs": [0.5, -1.1, 0.3, -1.0]}],
		[0.4, {"fr": Vector3(0.64, 0.25, -0.05), "rw": 1.0, "fl": Vector3(-0.64, 0.25, -0.05), "hw": 1.0, "sq": -0.15,
				"lift": 0.06, "wg": 1.0, "lw": 0.5, "legs": [0.2, -0.3, -0.2, -0.3]}],
		[0.6, {"fy": 3.1416, "fr": Vector3(0.66, 0.3, 0.0), "rw": 1.0, "fl": Vector3(-0.66, 0.3, 0.0), "hw": 1.0,
				"sq": -0.2, "lift": 0.1, "wg": 1.0, "lw": 0.5, "legs": [0.15, -0.2, -0.15, -0.2]}],
		[0.8, {"fy": 6.283, "fr": Vector3(0.6, -0.12, -0.3), "rw": 1.0, "fl": Vector3(-0.3, 0.1, 0.25), "hw": 0.8,
				"y": 0.5, "p": -0.3, "sq": 0.25, "lift": -0.1, "wg": 0.7, "lw": 0.8,
				"legs": [0.95, -1.4, 0.3, -1.0]}],
		[0.92, {"fy": 6.283, "y": 0.1, "p": -0.15, "sq": 0.15, "lift": -0.08,
				"fl": Vector3(-0.3, 0.1, 0.2), "hw": 1.0, "fr": Vector3(0.4, 0.1, 0.1), "rw": 0.8, "wg": 0.3,
				"lw": 0.8, "legs": [0.8, -1.4, 0.5, -1.2]}],
		[1.0, {"fy": 6.283, "y": -0.5, "p": -0.25, "fl": Vector3(-0.6, -0.1, -0.3), "hw": 1.0, "sq": 0.18,
				"lift": -0.06, "fr": Vector3(0.3, 0.1, 0.25), "rw": 0.8, "wg": 0.7, "lw": 0.8,
				"legs": [0.3, -1.0, 0.95, -1.4]}],
		[1.12, {"fy": 6.283, "y": -0.1, "fl": Vector3(-0.3, 0.5, 0.05), "hw": 1.0, "fr": Vector3(0.3, 0.5, 0.05),
				"rw": 1.0, "sq": -0.05, "wg": 0.4, "lw": 0.5, "legs": [0.4, -0.7, 0.2, -0.6]}],
		[1.2, {"fy": 6.283, "fr": Vector3(-0.12, 0.72, 0.0), "rw": 1.0, "fl": Vector3(0.12, 0.72, 0.0), "hw": 1.0,
				"p": 0.15, "sq": -0.25, "lift": 0.08, "wg": 1.0, "lw": 0.4, "legs": [0.15, -0.2, -0.15, -0.2]}],
		[1.4, {"fy": 3.1416, "fl": Vector3(-0.45, 0.6, 0.0), "hw": 1.0, "fr": Vector3(0.45, 0.6, 0.0), "rw": 1.0,
				"p": 0.1, "sq": -0.18, "lift": 0.06, "wg": 1.0, "lw": 0.4,
				"legs": [0.15, -0.2, -0.15, -0.2]}],
		[1.52, {"fy": 1.0, "y": 0.3, "fr": Vector3(0.3, 0.3, 0.2), "rw": 1.0, "fl": Vector3(-0.45, 0.25, 0.1),
				"hw": 0.8, "sq": 0.1, "wg": 0.4, "lw": 0.6, "legs": [-0.2, -0.8, 0.4, -1.0]}],
		[1.6, {"y": 0.65, "fr": Vector3(0.62, 0.12, -0.2), "rw": 1.0, "fl": Vector3(-0.3, 0.2, 0.25), "hw": 0.7,
				"sq": -0.12, "wg": 0.7, "lw": 0.7, "legs": [0.6, -0.9, -0.5, -0.6]}]]},
	# ---------------------------------------------------------------- per-hero base dash (the long air dash)
	# the air Cartwheel (sheet: 0129-0134, 303.8-304.5s): a tucked flick, the star turned over sideways (0.08 to
	# 0.34), then carried flat and stretched on its speed, legs split and arms swept back, held until she lands
	# (ThiefKit plays thf_land then); the whole air dash runs up to 1.09s, the keys end at 0.5
	"thf_exdash": {"hold": true, "swing": 2, "keys": [
		[0.0, {}],
		[0.05, {"sq": 0.28, "lift": -0.04, "p": 0.25, "lw": 1.0, "legs": [1.1, -1.6, 0.9, -1.4],
				"fl": Vector3(-0.2, 0.15, 0.25), "hw": 1.0, "fr": Vector3(0.2, 0.15, 0.25), "rw": 1.0}],
		[0.08, {"sq": -0.2, "lift": 0.18, "lw": 1.0, "legs": [1.25, -0.05, -1.25, -0.05],
				"fl": Vector3(-0.58, 0.3, 0.0), "hw": 1.0, "fr": Vector3(0.58, 0.3, 0.0), "rw": 1.0}],
		[0.34, {"fz": -6.283, "sq": -0.2, "lift": 0.22, "lw": 1.0, "legs": [1.25, -0.05, -1.25, -0.05],
				"fl": Vector3(-0.58, 0.3, 0.0), "hw": 1.0, "fr": Vector3(0.58, 0.3, 0.0), "rw": 1.0}],
		[0.5, {"fz": -6.283, "p": -0.75, "sq": -0.22, "lift": 0.12, "lw": 1.0, "legs": [1.0, -0.2, -1.0, -0.35],
				"fl": Vector3(-0.45, -0.05, 0.4), "hw": 1.0, "fr": Vector3(0.45, -0.05, 0.4), "rw": 1.0}]]},
	# touching down from the air Cartwheel (sheet 6: a low crouch held ~0.1s, up in ~0.05s, no dust)
	"thf_land": {"keys": [
		[0.0, {"sq": 0.34, "lift": -0.12, "p": 0.2, "lw": 1.0, "legs": [0.9, -1.5, 0.5, -1.2],
				"fl": Vector3(-0.5, -0.05, 0.15), "hw": 1.0, "fr": Vector3(0.5, -0.05, 0.15), "rw": 1.0}],
		[0.1, {"sq": 0.3, "lift": -0.1, "p": 0.16, "lw": 1.0, "legs": [0.9, -1.4, 0.5, -1.15],
				"fl": Vector3(-0.5, 0.0, 0.15), "hw": 0.8, "fr": Vector3(0.5, 0.0, 0.15), "rw": 0.8}],
		[0.18, {}]]},
	# his air dash (the shared long dash, ~0.24s): a hurled shoulder charge. Knees snap up and the shoulder
	# turns in, then the body goes flat behind the leading shoulder with the blade trailing low behind, legs
	# streaming back; at the end the knees come up under him to take the weight (no stamp, no ground mark)
	"jug_exdash": {"keys": [
		[0.0, {"p": 0.1, "y": 0.6, "sq": 0.25, "lift": 0.04, "lw": 1.0, "legs": [1.2, -1.6, 1.0, -1.5],
				"blade": Vector3(-1.3, -0.3, 1.5), "bw": 0.9, "rad": 0.35}],
		[0.05, {"p": -0.75, "y": 0.75, "r": 0.1, "sq": -0.3, "lift": 0.06, "lw": 1.0, "legs": [-0.4, -0.3, -0.9, -0.2],
				"blade": Vector3(-1.4, -0.2, 1.6), "bw": 1.0, "rad": 0.4}],
		[0.22, {"p": -0.7, "y": 0.7, "r": 0.15, "sq": -0.25, "lift": 0.05, "lw": 1.0,
				"legs": [-0.3, -0.35, -0.85, -0.25],
				"blade": Vector3(-1.4, -0.2, 1.6), "bw": 1.0, "rad": 0.4}],
		[0.32, {"p": -0.2, "y": 0.3, "sq": 0.15, "lw": 1.0, "legs": [1.0, -1.4, 0.6, -1.2],
				"blade": Vector3(-1.2, -0.4, 1.4), "bw": 0.8, "rad": 0.35}],
		[0.5, {}]]},
	# ---------------------------------------------------------------- payoffs and passive procs
	# Sable, VAULT RESET: a spin on the heel with the arms flung wide, then a snap back to aim
	"thf_reset": {"keys": [
		[0.0, {"sq": 0.15, "lift": -0.05}],
		[0.08, {"fy": -3.14, "sq": -0.15, "lift": 0.08, "fl": Vector3(-0.45, 0.25, 0.0), "hw": 1.0}],
		[0.18, {"fy": -6.283, "sq": 0.1, "fl": Vector3(-0.45, 0.2, 0.0), "hw": 0.8}],
		[0.4, {"fy": -6.283}]]},
	# Sable, a knock: a flourish, chin up, one blade raised, the heal rising through her
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
		[0.0, {"y": 0.60, "p": 0.08, "sq": 0.16, "lw": 1.0, "legs": [0.8, -1.2, -0.5, -0.7], "lift": -0.08}],
		[0.1, {"y": -0.95, "p": -0.35, "sq": -0.18, "lw": 1.0, "legs": [1.1, -0.65, -0.75, -0.25]}],
		[0.24, {"y": -0.80, "p": -0.22, "sq": 0.05, "lw": 0.9, "legs": [1.0, -0.8, -0.6, -0.35], "lift": -0.04}],
		[0.45, {}]]},
	"jug_slash_l": {"keys": [
		[0.0, {"y": -0.60, "p": 0.08, "sq": 0.16, "lw": 1.0, "legs": [0.8, -1.2, -0.5, -0.7], "lift": -0.08}],
		[0.1, {"y": 0.95, "p": -0.35, "sq": -0.18, "lw": 1.0, "legs": [1.1, -0.65, -0.75, -0.25]}],
		[0.24, {"y": 0.80, "p": -0.22, "sq": 0.05, "lw": 0.9, "legs": [1.0, -0.8, -0.6, -0.35], "lift": -0.04}],
		[0.45, {}]]},
	# the Searing Wave held: the blade drawn back flat past his right hip, the body coiling round
	"jug_wave_wind": {"hold": true, "keys": [
		[0.0, {}],
		[0.25, {"blade": Vector3(-1.6, 0.1, 0.0), "bw": 1.0, "rad": 0.45, "y": 0.7, "p": 0.1, "sq": 0.18, "lift": -0.06,
				"lw": 1.0, "legs": [0.7, -1.2, -0.4, -0.7]}],
		[0.7, {"blade": Vector3(-1.9, 0.1, 0.0), "bw": 1.0, "rad": 0.5, "y": 0.9, "p": 0.1, "sq": 0.25, "lift": -0.1,
				"lw": 1.0, "legs": [0.8, -1.3, -0.45, -0.8]}]]},
}
