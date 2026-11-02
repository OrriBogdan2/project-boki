class_name KMovesPair
extends RefCounted
## Keyed full-body moves of Dredge and Ashwick (same format and channels as HunterAnim.KMOVES; looked
## up by HunterAnim.km_sample). Every ability: an anticipation pose, a strong key pose on the hit, and
## a follow-through. fl / fr place a free hand from its shoulder (hw / rw their weight).

const MOVES := {
	# ---------------------------------------------------------------- Dredge
	# Grapnel: the rope arm coiled back over the shoulder, the body twisted away, then thrown out ahead
	"dr_throw": {"keys": [
		[0.0, {}],
		[0.16, {"y": 0.7, "p": 0.18, "fr": Vector3(0.18, 0.5, 0.35), "rw": 1.0, "lw": 0.8, "legs": [0.5, -0.7, -0.3, -0.4]}],
		[0.24, {"y": -0.55, "p": -0.42, "fr": Vector3(-0.1, 0.1, -0.85), "rw": 1.0, "sq": 0.25, "lw": 1.0, "legs": [0.9, -0.9, -0.6, -0.3]}],
		[0.42, {"y": -0.35, "p": -0.25, "fr": Vector3(-0.1, 0.0, -0.7), "rw": 0.8, "lw": 0.7, "legs": [0.7, -0.8, -0.5, -0.3]}],
		[0.65, {}]]},
	# reeling: braced and leaning back, both fists clamped on the rope at the hip, legs planted wide
	"dr_reel": {"keys": [
		[0.0, {}],
		[0.18, {"p": 0.38, "lift": -0.12, "fr": Vector3(0.0, -0.2, -0.45), "rw": 1.0, "fl": Vector3(0.0, -0.2, -0.4), "hw": 1.0, "lw": 1.0, "legs": [0.7, -1.1, -0.7, -0.5], "sq": 0.2}],
		[3.0, {"p": 0.42, "lift": -0.14, "fr": Vector3(0.0, -0.2, -0.45), "rw": 1.0, "fl": Vector3(0.0, -0.25, -0.4), "hw": 1.0, "lw": 1.0, "legs": [0.7, -1.1, -0.7, -0.5], "sq": 0.25}],
		[3.2, {}]]},
	"dr_pullend": {"keys": [[0.0, {"p": 0.3, "lw": 1.0, "legs": [0.7, -1.1, -0.7, -0.5]}], [0.3, {}]]},
	# Anchor Drop: the fist hauled up over the head and the body rising on the toes, then driven down
	"dr_anchor": {"keys": [
		[0.0, {}],
		[0.2, {"p": 0.45, "lift": 0.22, "fr": Vector3(0.1, 0.75, 0.0), "rw": 1.0, "fl": Vector3(-0.1, 0.5, 0.05), "hw": 1.0, "lw": 1.0, "legs": [-0.2, -0.3, 0.3, -0.5], "sq": -0.3}],
		[0.25, {"p": -0.75, "lift": -0.2, "fr": Vector3(-0.05, -0.55, -0.7), "rw": 1.0, "fl": Vector3(0.05, -0.5, -0.55), "hw": 1.0, "sq": 0.55, "lw": 1.0, "legs": [1.1, -1.5, -0.4, -0.9]}],
		[0.55, {"p": -0.6, "lift": -0.14, "fr": Vector3(-0.05, -0.55, -0.7), "rw": 0.9, "fl": Vector3(0.05, -0.5, -0.55), "hw": 0.9, "sq": 0.25, "lw": 1.0, "legs": [1.0, -1.4, -0.35, -0.8]}],
		[0.95, {}]]},
	# Barge: head down, one shoulder driven in, the arms tucked
	"dr_barge": {"keys": [
		[0.0, {"p": -0.4, "y": 0.5, "lw": 1.0, "legs": [0.6, -1.0, -0.5, -0.4], "fr": Vector3(0.1, -0.1, -0.2), "rw": 0.8}],
		[0.14, {"p": -0.62, "y": 0.45, "lw": 1.0, "legs": [1.1, -0.7, -0.8, -0.2], "sq": 0.2, "fr": Vector3(0.1, -0.1, -0.2), "rw": 0.8}],
		[0.22, {"p": -0.55, "y": 0.3, "lw": 1.0, "legs": [1.15, -0.6, -0.8, -0.15], "sq": -0.2}],
		[0.5, {}]]},
	# ---------------------------------------------------------------- Ashwick
	# Torch Lance, held: braced forward behind the nozzle, the off hand steadying the hose
	"as_lance": {"hold": true, "keys": [
		[0.0, {}],
		[0.2, {"p": -0.28, "lift": -0.06, "fl": Vector3(-0.15, 0.0, -0.55), "hw": 1.0, "lw": 1.0, "legs": [0.6, -0.9, -0.5, -0.4]}]]},
	"as_lance_end": {"keys": [
		[0.0, {"p": -0.28, "fl": Vector3(-0.15, 0.0, -0.55), "hw": 1.0, "lw": 1.0, "legs": [0.6, -0.9, -0.5, -0.4]}],
		[0.3, {}]]},
	# Cinder Shot: the gun hand cocked back, then thrust out; the whole body kicks back from it
	"as_shot": {"keys": [
		[0.0, {}],
		[0.1, {"p": -0.1, "y": 0.35, "fr": Vector3(0.1, 0.15, 0.1), "rw": 1.0, "lw": 0.7, "legs": [0.4, -0.6, -0.3, -0.3]}],
		[0.16, {"p": 0.28, "y": -0.3, "fr": Vector3(-0.1, 0.1, -0.85), "rw": 1.0, "lw": 0.9, "legs": [0.6, -0.8, -0.5, -0.3], "sq": 0.15}],
		[0.45, {}]]},
	# Spark Leap: a deep crouch, then stretched out along the leap, legs trailing
	"as_leap": {"keys": [
		[0.0, {"p": -0.3, "lift": -0.15, "sq": 0.4, "lw": 1.0, "legs": [1.1, -1.7, 1.0, -1.7]}],
		[0.08, {"p": -0.75, "lift": 0.05, "sq": -0.3, "lw": 1.0, "legs": [-0.6, -0.2, -0.9, -0.1], "fr": Vector3(-0.1, 0.2, -0.8), "rw": 1.0, "fl": Vector3(0.1, 0.2, -0.8), "hw": 1.0}],
		[0.2, {"p": -0.6, "lw": 1.0, "legs": [-0.5, -0.3, -0.8, -0.2], "fr": Vector3(-0.1, 0.2, -0.8), "rw": 0.8, "fl": Vector3(0.1, 0.2, -0.8), "hw": 0.8}],
		[0.5, {}]]},
	# Furnace Cloak: curled in on itself, arms crossed over the chest, then thrown wide as the heat goes off
	"as_cloak": {"keys": [
		[0.0, {}],
		[0.14, {"p": -0.35, "sq": 0.35, "lift": -0.1, "fr": Vector3(-0.15, 0.2, -0.3), "rw": 1.0, "fl": Vector3(0.15, 0.2, -0.3), "hw": 1.0, "lw": 1.0, "legs": [0.7, -1.1, -0.7, -0.5]}],
		[0.2, {"p": 0.3, "sq": -0.3, "lift": 0.14, "fr": Vector3(0.55, 0.45, 0.0), "rw": 1.0, "fl": Vector3(-0.55, 0.45, 0.0), "hw": 1.0, "lw": 1.0, "legs": [0.0, -0.2, 0.0, -0.2]}],
		[0.5, {"p": 0.15, "fr": Vector3(0.45, 0.35, 0.0), "rw": 0.7, "fl": Vector3(-0.45, 0.35, 0.0), "hw": 0.7}],
		[0.75, {}]]},
}
