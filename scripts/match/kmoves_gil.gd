class_name KMovesGil
extends RefCounted
## Keyed full-body moves of Gil (content/archetypes/gil.json, scripts/arch/kits/gil_kit.gd), in the
## HunterAnim.KMOVES format: a fencer's thrusts on the swordfish (right foot leading, the back hand up behind),
## the held Tide Lunge, the dive under the ground and the burst back out, the potion toss, the Riptide spin and
## the wave ride. Where his .glb has a clip (content/rules/warden_anim/gil.json) the clip plays and these keys give
## the move its length; the Tide Lunge and the dive have no clip, so the rig plays these poses. Signs as KMovesDJ:
## p < 0 leans in, y < 0 brings the right (sword) shoulder forward, lift is metres up from the feet.

const MOVES := {
	# Fencer thrusts 1 and 2: the hit lands on the press, so the point snaps out in 0.05s from the guard and
	# holds a beat (the read), then eases home. The second drives a little lower and turns the wrist over.
	"gil_thrust_a": {"stance": true, "keys": [
		[0.0, {"blade": Vector3(0.1, 0.1, 0.0), "bw": 1.0, "rad": 0.22, "y": 0.25, "lw": 0.6}],
		[0.05, {"blade": Vector3(0.0, -0.02, 0.0), "bw": 1.0, "rad": 0.78, "p": -0.25, "y": -0.45, "sq": -0.08,
				"fl": Vector3(-0.3, 0.4, 0.3), "hw": 0.8, "lw": 0.8, "legs": [-0.5, -0.3, 0.75, -0.5]}],
		[0.16, {"blade": Vector3(0.0, -0.04, 0.0), "bw": 1.0, "rad": 0.72, "p": -0.2, "y": -0.4,
				"fl": Vector3(-0.3, 0.4, 0.3), "hw": 0.8, "lw": 0.8, "legs": [-0.45, -0.3, 0.7, -0.5]}],
		[0.32, {}]]},
	"gil_thrust_b": {"stance": true, "keys": [
		[0.0, {"blade": Vector3(-0.1, 0.05, 0.6), "bw": 1.0, "rad": 0.2, "y": 0.2, "lw": 0.6}],
		[0.05, {"blade": Vector3(0.05, -0.12, 1.4), "bw": 1.0, "rad": 0.8, "p": -0.3, "y": -0.5, "sq": -0.08,
				"fl": Vector3(-0.32, 0.45, 0.32), "hw": 0.8, "lw": 0.8, "legs": [-0.55, -0.3, 0.8, -0.55]}],
		[0.16, {"blade": Vector3(0.05, -0.14, 1.4), "bw": 1.0, "rad": 0.74, "p": -0.25, "y": -0.45,
				"fl": Vector3(-0.32, 0.45, 0.32), "hw": 0.8, "lw": 0.8, "legs": [-0.5, -0.3, 0.75, -0.5]}],
		[0.32, {}]]},
	# the third: a full fencing lunge, the front knee deep, the back leg straight, the whole body behind the point
	"gil_lunge": {"keys": [
		[0.0, {"blade": Vector3(0.05, 0.15, 0.0), "bw": 1.0, "rad": 0.15, "p": 0.05, "y": 0.4, "sq": 0.15,
				"lw": 1.0, "legs": [0.2, -0.6, 0.3, -0.7]}],
		[0.06, {"blade": Vector3(0.0, -0.08, 0.0), "bw": 1.0, "rad": 0.95, "p": -0.5, "y": -0.6, "sq": -0.18,
				"lift": -0.14, "fl": Vector3(-0.25, 0.55, 0.4), "hw": 1.0, "lw": 1.0,
				"legs": [-0.85, -0.1, 1.2, -1.1]}],
		[0.26, {"blade": Vector3(0.0, -0.1, 0.0), "bw": 1.0, "rad": 0.9, "p": -0.42, "y": -0.55, "lift": -0.12,
				"fl": Vector3(-0.25, 0.55, 0.4), "hw": 1.0, "lw": 1.0, "legs": [-0.8, -0.1, 1.15, -1.05]}],
		[0.48, {}]]},
	# Tide Lunge held: he sinks onto the back leg and draws the point back along the aim, the back hand high;
	# a small tremble (looped) as the water gathers on the bill
	"gil_tide_wind": {"hold": true, "loop": 0.22, "keys": [
		[0.0, {}],
		[0.12, {"blade": Vector3(0.0, 0.1, 0.0), "bw": 1.0, "rad": 0.1, "p": 0.12, "y": 0.6, "sq": 0.22,
				"lift": -0.12, "fl": Vector3(-0.3, 0.75, 0.3), "hw": 1.0, "lw": 1.0,
				"legs": [-0.25, -1.1, 0.55, -0.9]}],
		[0.22, {"blade": Vector3(0.0, 0.08, 0.0), "bw": 1.0, "rad": 0.08, "p": 0.14, "y": 0.62, "sq": 0.25,
				"lift": -0.13, "fl": Vector3(-0.3, 0.75, 0.3), "hw": 1.0, "lw": 1.0,
				"legs": [-0.25, -1.15, 0.55, -0.95]}],
		[0.3, {"blade": Vector3(0.0, 0.12, 0.0), "bw": 1.0, "rad": 0.09, "p": 0.12, "y": 0.6, "sq": 0.22,
				"lift": -0.12, "fl": Vector3(-0.3, 0.75, 0.3), "hw": 1.0, "lw": 1.0,
				"legs": [-0.25, -1.1, 0.55, -0.9]}],
		[0.38, {"blade": Vector3(0.0, 0.08, 0.0), "bw": 1.0, "rad": 0.08, "p": 0.14, "y": 0.62, "sq": 0.25,
				"lift": -0.13, "fl": Vector3(-0.3, 0.75, 0.3), "hw": 1.0, "lw": 1.0,
				"legs": [-0.25, -1.15, 0.55, -0.95]}]]},
	# ... let go: he drives out flat behind the point (stretched), then a long recovery from the deep lunge
	"gil_tide_lunge": {"keys": [
		[0.0, {"blade": Vector3(0.0, 0.08, 0.0), "bw": 1.0, "rad": 0.1, "p": 0.14, "y": 0.6, "sq": 0.25,
				"lift": -0.12, "lw": 1.0, "legs": [-0.25, -1.1, 0.55, -0.9]}],
		[0.06, {"blade": Vector3(0.0, -0.06, 0.0), "bw": 1.0, "rad": 1.0, "p": -0.7, "y": -0.7, "sq": -0.3,
				"lift": -0.1, "fl": Vector3(-0.2, 0.5, 0.5), "hw": 1.0, "lw": 1.0, "legs": [-1.0, 0.0, 1.3, -0.9]}],
		[0.3, {"blade": Vector3(0.0, -0.1, 0.0), "bw": 1.0, "rad": 0.95, "p": -0.55, "y": -0.6, "sq": -0.1,
				"lift": -0.16, "fl": Vector3(-0.2, 0.5, 0.5), "hw": 1.0, "lw": 1.0, "legs": [-0.9, -0.1, 1.25, -1.2]}],
		[0.6, {}]]},
	# Ground Swim: a quick crouch, then head first into the ground like a dive into water; held under
	# (the body fully below the surface) until gil_surface replaces it
	"gil_dive": {"hold": true, "keys": [
		[0.0, {"p": 0.15, "sq": 0.3, "lift": -0.08, "lw": 1.0, "legs": [0.9, -1.4, 0.9, -1.4],
				"fl": Vector3(-0.2, 1.0, 0.0), "hw": 1.0, "blade": Vector3(0.0, 1.4, 0.0), "bw": 1.0, "rad": 0.4}],
		[0.07, {"p": -0.8, "fx": -0.7, "sq": -0.35, "lift": -0.7, "lw": 1.0, "legs": [-0.2, -0.1, -0.2, -0.1],
				"fl": Vector3(-0.1, 0.2, -0.9), "hw": 1.0, "blade": Vector3(0.0, -0.3, 0.0), "bw": 1.0, "rad": 0.8}],
		[0.15, {"p": -0.9, "fx": -1.2, "sq": -0.35, "lift": -2.8, "lw": 1.0, "legs": [-0.2, -0.1, -0.2, -0.1],
				"fl": Vector3(-0.1, 0.2, -0.9), "hw": 1.0, "blade": Vector3(0.0, -0.3, 0.0), "bw": 1.0, "rad": 0.8}]]},
	# ... and out: he bursts up through the ground, stretched, arms and point up, then lands in a squash
	"gil_surface": {"keys": [
		[0.0, {"p": 0.1, "sq": -0.35, "lift": -2.2, "lw": 1.0, "legs": [0.2, -0.3, 0.2, -0.3],
				"fl": Vector3(-0.2, 1.0, 0.0), "hw": 1.0, "blade": Vector3(0.0, 1.5, 0.0), "bw": 1.0, "rad": 0.5}],
		[0.1, {"p": 0.15, "sq": -0.35, "lift": 0.6, "lw": 1.0, "legs": [0.6, -1.2, 0.3, -0.8],
				"fl": Vector3(-0.3, 1.0, 0.0), "hw": 1.0, "blade": Vector3(0.0, 1.5, 0.0), "bw": 1.0, "rad": 0.5}],
		[0.24, {"p": 0.05, "sq": 0.05, "lift": 0.3, "lw": 1.0, "legs": [0.9, -1.5, 0.7, -1.3],
				"fl": Vector3(-0.5, 0.5, 0.0), "hw": 0.8, "blade": Vector3(-0.6, 0.6, 0.6), "bw": 0.8, "rad": 0.4}],
		[0.34, {"p": -0.15, "sq": 0.35, "lift": -0.1, "lw": 1.0, "legs": [0.9, -1.6, 0.8, -1.5]}],
		[0.467, {}]]},      # (ends with the surface clip, 14 frames at 30 fps)
	# Grab Bag: the free hand whips a bottle overhand from behind the hat, the shoulders turning into it
	"gil_toss": {"stance": true, "keys": [
		[0.0, {}],
		[0.08, {"fl": Vector3(-0.35, 0.75, 0.35), "hw": 1.0, "y": 0.4, "p": 0.1, "lw": 0.6,
				"legs": [-0.3, -0.4, 0.4, -0.5]}],
		[0.16, {"fl": Vector3(-0.15, 0.3, -0.6), "hw": 1.0, "y": -0.35, "p": -0.25, "sq": -0.06, "lw": 0.6,
				"legs": [0.5, -0.5, -0.3, -0.3]}],
		[0.42, {}]]},
	# Riptide: the swordfish held straight out to the side, the free arm out for balance, turning on the spot
	# once every 0.25s (looped: a turn ends where it began)
	"gil_spin": {"hold": true, "loop": 0.1, "keys": [
		[0.0, {}],
		[0.1, {"fy": 0.0, "blade": Vector3(-1.5, -0.05, 1.5), "bw": 1.0, "rad": 0.8, "fl": Vector3(-0.75, 0.1, 0.0),
				"hw": 1.0, "sq": 0.12, "lift": -0.06, "p": -0.1, "lw": 1.0, "legs": [0.5, -0.8, 0.5, -0.8]}],
		[0.35, {"fy": -6.283, "blade": Vector3(-1.5, -0.05, 1.5), "bw": 1.0, "rad": 0.8, "fl": Vector3(-0.75, 0.1, 0.0),
				"hw": 1.0, "sq": 0.12, "lift": -0.06, "p": -0.1, "lw": 1.0, "legs": [0.5, -0.8, 0.5, -0.8]}]]},
	# ... the spout let go: the spin stops on a thrust down the line
	"gil_spout": {"keys": [
		[0.0, {"blade": Vector3(0.0, 0.3, 0.0), "bw": 1.0, "rad": 0.3, "y": 0.5, "sq": 0.2, "lw": 1.0,
				"legs": [0.3, -0.8, 0.4, -0.8]}],
		[0.07, {"blade": Vector3(0.0, -0.1, 0.0), "bw": 1.0, "rad": 0.95, "p": -0.5, "y": -0.55, "sq": -0.2,
				"fl": Vector3(-0.3, 0.5, 0.4), "hw": 1.0, "lw": 1.0, "legs": [-0.8, -0.1, 1.1, -1.0]}],
		[0.4, {}]]},      # (ends with the spout clip, 12 frames at 30 fps)
	# Tidal Wave: up on the crest in a low surfer's crouch, side on, the arms out, rocking with the water
	"gil_surf": {"hold": true, "loop": 0.15, "keys": [
		[0.0, {"sq": 0.25, "lift": -0.1, "lw": 1.0, "legs": [0.9, -1.4, 0.9, -1.4]}],
		[0.15, {"y": 1.1, "r": 0.12, "p": -0.25, "sq": 0.18, "lift": 0.7, "fl": Vector3(-0.8, 0.25, 0.0), "hw": 1.0,
				"blade": Vector3(-1.4, 0.2, 1.5), "bw": 1.0, "rad": 0.6, "lw": 1.0, "legs": [0.7, -1.2, -0.5, -0.9]}],
		[0.45, {"y": 1.0, "r": -0.1, "p": -0.3, "sq": 0.24, "lift": 0.6, "fl": Vector3(-0.8, 0.4, 0.0), "hw": 1.0,
				"blade": Vector3(-1.4, 0.35, 1.5), "bw": 1.0, "rad": 0.6, "lw": 1.0, "legs": [0.75, -1.3, -0.5, -1.0]}],
		[0.75, {"y": 1.1, "r": 0.12, "p": -0.25, "sq": 0.18, "lift": 0.7, "fl": Vector3(-0.8, 0.25, 0.0), "hw": 1.0,
				"blade": Vector3(-1.4, 0.2, 1.5), "bw": 1.0, "rad": 0.6, "lw": 1.0, "legs": [0.7, -1.2, -0.5, -0.9]}]]},
	# ... off the wave: dropped onto both feet in a deep squash, then up
	"gil_wave_land": {"keys": [
		[0.0, {"sq": -0.2, "lift": 0.5, "lw": 1.0,
				"legs": [0.3, -0.4, 0.3, -0.4], "fl": Vector3(-0.6, 0.4, 0.0), "hw": 1.0}],
		[0.1, {"sq": 0.45, "lift": -0.15, "p": -0.2, "lw": 1.0, "legs": [1.0, -1.7, 0.9, -1.6],
				"fl": Vector3(-0.7, -0.2, 0.0), "hw": 1.0}],
		[0.467, {}]]},      # (ends with the wave_land clip, 14 frames at 30 fps)
}
