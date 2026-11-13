class_name MobAnim
extends RefCounted
## Keyed procedural moves for the sculpted monsters (MobModels), so every kind shows every state on the body:
## idle, walk, run, windup, strike, stagger, flinch and death. Mob.render calls pose() once a frame.
##
## MOVES[kind][state] is a list of tracks [pivots, channel, keys, phase offset]:
##   pivots   pivot names under "Body"; a leading "-" negates that pivot's value (mirrors the right side)
##   channel  rx ry rz (rotation), px py pz (position), sx sy sz sxz sa (scale: x, y, z, x and z, all), wy (spin rad/s);
##            all are offsets from the pivot's rest pose
##   keys     flat [phase, value, phase, value ...] from 0 to 1, value in rad, m, scale or rad/s
## Phases: idle, walk, run and stagger loop (walk/run by gait distance); windup is windup_k(), the same number the
## ground telegraph fills with, so the body gathers exactly as the tell fills; strike runs the blow plus its
## follow-through; flinch is the hit flash; death runs DEATH_S. run is walk at RUN_AMP when it has no table of its own.
## Tables are baked once into 32-sample curves; a frame is table lookups only, no allocation.

const IDLE := 0
const WALK := 1
const RUN := 2
const WINDUP := 3
const STRIKE := 4
const STAGGER := 5
const FLINCH := 6
const DEATH := 7
const STATES := ["idle", "walk", "run", "windup", "strike", "stagger", "flinch", "death"]
const LOOPS := [true, true, true, false, false, true, false, false]
## 1/s: how fast a pivot follows its target in each state
const RATE := [8.0, 14.0, 14.0, 40.0, 45.0, 12.0, 60.0, 30.0]

const LUNGE_S := 0.2              # s: a skitter's lunge, then LUNGE_REC of recovery
const LUNGE_REC := 0.45           # s
const RECOVER_S := {"spit": 0.5, "volley": 0.6, "slam": 0.8}      # s: follow-through after the blow, by attack
const DEATH_S := 0.32             # s: the death move, then the monster is gone
const FLASH_S := 0.12             # s: the hit flash Ent sets; the flinch rides it
const RUN_SPEED := 3.6            # m/s: above this the run table plays
const RUN_AMP := 1.4              # run = walk x this when a kind has no run table
## s per idle loop
const IDLE_S := {"brute": 5.0, "spitter": 3.0, "skitter": 2.5, "bomber": 2.2, "sentinel": 4.0, "glimmer": 2.0}
const STAGGER_S := 2.0            # s per stagger loop
## gait cycles per radian of Mob.anim / TAU
const GAIT := {"skitter": 1.6, "spitter": 1.0, "brute": 0.9, "bomber": 1.0, "sentinel": 1.0, "glimmer": 1.3}
const FAR_M := 30.0               # m from the camera focus: beyond this the body is not posed
const SAMPLES := 32
const STRIDE := 10                # floats per pivot in Rig.acc: rx ry rz px py pz sx sy sz wy
const CHANS := {"rx": [0], "ry": [1], "rz": [2], "px": [3], "py": [4], "pz": [5], "sx": [6], "sy": [7], "sz": [8],
	"sxz": [6, 8], "sa": [6, 7, 8], "wy": [9]}
## per channel: which of rotation, position, scale, spin a pivot needs
const KIND_BIT := [1, 1, 1, 2, 2, 2, 4, 4, 4, 8]

const SK_A := ["Leg0-1", "Leg2-1", "Leg11"]            # skitter tripods
const SK_B := ["Leg01", "Leg21", "Leg1-1"]
const SK_AS := ["-Leg0-1", "-Leg2-1", "Leg11"]         # the same legs, signed so the left side mirrors
const SK_BS := ["Leg01", "Leg21", "-Leg1-1"]
const SK_ALL := ["Leg0-1", "Leg2-1", "Leg11", "Leg01", "Leg21", "Leg1-1"]
const SK_ALLS := ["-Leg0-1", "-Leg2-1", "Leg11", "Leg01", "Leg21", "-Leg1-1"]
const JAWS := ["JawL", "-JawR"]
const LEAF_A := ["Leaf0", "Leaf2"]
const LEAF_B := ["Leaf1", "Leaf3"]
const LEAVES := ["Leaf0", "Leaf1", "Leaf2", "Leaf3"]
const ARMS := ["ArmL", "ArmR"]
const ARMS_Z := ["ArmL", "-ArmR"]                      # outward/inward swing, mirrored
const LEGS := ["LegL", "LegR"]
const FINS := ["FinL", "-FinR"]
const EARS := ["EarL", "EarR"]

const MOVES := {
	"skitter": {
		"idle": [
			[SK_A, "ry", [0, 0.04, 0.5, -0.04, 1, 0.04], 0.0],
			[SK_B, "ry", [0, 0.04, 0.5, -0.04, 1, 0.04], 0.5],
			[JAWS, "ry", [0, 0.25, 0.5, 0.31, 1, 0.25], 0.0],
			[["Body"], "py", [0, 0, 0.5, 0.012, 1, 0], 0.0],
		],
		"walk": [
			[SK_A, "ry", [0, 0, 0.25, 0.45, 0.75, -0.45, 1, 0], 0.0],
			[SK_B, "ry", [0, 0, 0.25, 0.45, 0.75, -0.45, 1, 0], 0.5],
			[SK_AS, "rz", [0, 0.35, 0.25, 0, 0.75, 0, 1, 0.35], 0.0],
			[SK_BS, "rz", [0, 0.35, 0.25, 0, 0.75, 0, 1, 0.35], 0.5],
			[JAWS, "ry", [0, 0.25, 0.5, 0.33, 1, 0.25], 0.0],
			[["Body"], "py", [0, 0, 0.25, 0.05, 0.5, 0, 0.75, 0.05, 1, 0], 0.0],
		],
		"windup": [
			[SK_ALLS, "rz", [0, 0, 1, -0.3], 0.0],
			[SK_ALL, "rx", [0, 0, 1, 0.3], 0.0],
			[JAWS, "ry", [0, 0.25, 1, 0.75], 0.0],
			[["Body"], "py", [0, 0, 1, -0.05], 0.0],
			[SK_A, "ry", [0, 0, 0.6, 0, 0.7, 0.1, 0.8, -0.1, 0.9, 0.1, 1, -0.1], 0.0],
		],
		"strike": [
			[JAWS, "ry", [0, 0.85, 0.3, 0.9, 0.4, 0.15, 1, 0.25], 0.0],
			[SK_ALL, "rx", [0, -0.55, 0.31, -0.6, 0.5, 0.1, 1, 0], 0.0],
			[SK_ALLS, "rz", [0, -0.3, 0.31, -0.1, 1, 0], 0.0],
			[["Body"], "py", [0, 0, 0.15, 0.14, 0.31, 0.04, 0.45, 0, 1, 0], 0.0],
		],
		"stagger": [
			[SK_ALLS, "rz", [0, -0.45, 0.5, -0.35, 1, -0.45], 0.0],
			[SK_ALL, "rx", [0, 0.15, 0.5, 0.25, 1, 0.15], 0.0],
			[JAWS, "ry", [0, 0.55, 0.5, 0.65, 1, 0.55], 0.0],
			[["Body"], "py", [0, -0.07, 0.5, -0.06, 1, -0.07], 0.0],
			[SK_A, "ry", [0, 0, 0.125, 0.2, 0.25, 0, 0.375, -0.2, 0.5, 0, 0.625, 0.2, 0.75, 0, 0.875, -0.2, 1, 0], 0.0],
		],
		"flinch": [
			[JAWS, "ry", [0, 0.25, 0.3, 0.9, 1, 0.25], 0.0],
			[SK_ALLS, "rz", [0, 0, 0.3, 0.45, 1, 0], 0.0],
			[["Body"], "py", [0, 0, 0.3, -0.04, 1, 0], 0.0],
			[["Body"], "ry", [0, 0, 0.3, 0.15, 1, 0], 0.0],
		],
		"death": [
			[SK_ALLS, "rz", [0, 0, 0.5, 1.1, 1, 1.4], 0.0],
			[SK_ALL, "rx", [0, 0, 1, 0.4], 0.0],
			[JAWS, "ry", [0, 0.25, 0.3, 1.0, 1, 0.9], 0.0],
			[["Body"], "py", [0, 0, 0.3, 0.1, 1, 0], 0.0],
		],
	},
	"spitter": {
		"idle": [
			[["Bulb"], "sy", [0, -0.1, 0.5, -0.07, 1, -0.1], 0.0],
			[["Bulb"], "sxz", [0, 0, 0.5, 0.03, 1, 0], 0.0],
			[["Body"], "ry", [0, 0, 0.25, 0.05, 0.75, -0.05, 1, 0], 0.0],
			[LEAF_A, "rz", [0, 0, 0.25, 0.08, 0.75, -0.08, 1, 0], 0.0],
			[LEAF_B, "rz", [0, 0, 0.25, 0.08, 0.75, -0.08, 1, 0], 0.4],
		],
		"walk": [
			[["Body"], "py", [0, 0, 0.5, 0.12, 1, 0], 0.0],
			[["Bulb"], "rx", [0, 0.12, 0.5, -0.1, 1, 0.12], 0.0],
			[["Bulb"], "sy", [0, -0.12, 0.15, -0.2, 0.5, -0.05, 1, -0.12], 0.0],
			[["Body"], "ry", [0, 0, 0.25, 0.1, 0.75, -0.1, 1, 0], 0.0],
			[LEAF_A, "rz", [0, 0, 0.25, 0.2, 0.75, -0.2, 1, 0], 0.0],
			[LEAF_B, "rz", [0, 0, 0.25, 0.2, 0.75, -0.2, 1, 0], 0.5],
		],
		"windup": [
			[["Bulb"], "sy", [0, -0.1, 1, 0.3], 0.0],
			[["Bulb"], "sxz", [0, 0, 1, -0.15], 0.0],
			[["Bulb"], "rx", [0, 0, 1, -0.5], 0.0],
			[LEAVES, "rz", [0, 0, 1, 0.45], 0.0],
			[["Body"], "py", [0, 0, 1, 0.04], 0.0],
		],
		"strike": [
			[["Bulb"], "rx", [0, -0.5, 0.12, 0.7, 0.4, 0.2, 1, 0], 0.0],
			[["Bulb"], "sy", [0, 0.3, 0.12, -0.35, 0.5, -0.1, 1, -0.1], 0.0],
			[["Bulb"], "sxz", [0, -0.15, 0.12, 0.2, 1, 0], 0.0],
			[LEAVES, "rz", [0, 0.45, 0.12, -0.25, 0.5, 0.1, 1, 0], 0.0],
			[["Body"], "py", [0, 0.04, 0.12, -0.05, 1, 0], 0.0],
		],
		"stagger": [
			[["Bulb"], "rx", [0, 0.55, 0.5, 0.7, 1, 0.55], 0.0],
			[["Bulb"], "sy", [0, -0.25, 0.5, -0.2, 1, -0.25], 0.0],
			[LEAF_A, "rz", [0, 0.7, 0.5, 0.8, 1, 0.7], 0.0],
			[LEAF_B, "rz", [0, 0.7, 0.5, 0.8, 1, 0.7], 0.5],
			[["Body"], "ry", [0, 0, 0.25, 0.12, 0.75, -0.12, 1, 0], 0.0],
		],
		"flinch": [
			[["Bulb"], "sy", [0, -0.1, 0.3, -0.35, 1, -0.1], 0.0],
			[["Bulb"], "sxz", [0, 0, 0.3, 0.2, 1, 0], 0.0],
			[LEAVES, "rz", [0, 0, 0.3, 0.6, 1, 0], 0.0],
			[["Body"], "ry", [0, 0, 0.3, 0.2, 1, 0], 0.0],
		],
		"death": [
			[["Bulb"], "rx", [0, 0, 1, 1.0], 0.0],
			[["Bulb"], "sy", [0, -0.1, 1, -0.6], 0.0],
			[LEAVES, "rz", [0, 0, 1, 1.3], 0.0],
			[["Body"], "py", [0, 0, 1, -0.1], 0.0],
		],
	},
	"brute": {
		"idle": [
			[["Torso"], "sxz", [0, 0, 0.5, 0.025, 1, 0], 0.0],
			[["Torso"], "sy", [0, 0, 0.5, 0.015, 1, 0], 0.0],
			[["Head"], "ry", [0, 0, 0.25, 0.25, 0.75, -0.25, 1, 0], 0.0],
			[ARMS_Z, "rz", [0, -0.15, 1, -0.15], 0.0],
			[ARMS, "rx", [0, 0, 0.5, 0.05, 1, 0], 0.0],
		],
		"walk": [
			[LEGS, "rx", [0, 0, 0.25, 0.5, 0.75, -0.5, 1, 0], 0.0],
			[["-ArmL", "ArmR"], "rx", [0, 0, 0.25, 0.3, 0.75, -0.3, 1, 0], 0.0],
			[ARMS_Z, "rz", [0, -0.15, 1, -0.15], 0.0],
			[["Torso"], "ry", [0, 0, 0.25, 0.12, 0.75, -0.12, 1, 0], 0.0],
			[["Torso"], "rx", [0, -0.12, 1, -0.12], 0.0],
			[["Body"], "py", [0, 0.06, 0.25, 0, 0.5, 0.06, 0.75, 0, 1, 0.06], 0.0],
		],
		"windup": [
			[ARMS, "rx", [0, 0, 1, 2.7], 0.0],
			[ARMS_Z, "rz", [0, -0.15, 1, -0.35], 0.0],
			[["Torso"], "rx", [0, 0, 1, 0.15], 0.0],
			[["LegL"], "rx", [0, 0, 1, -0.3], 0.0],
			[["LegR"], "rx", [0, 0, 1, 0.2], 0.0],
			[["Body"], "py", [0, 0, 1, -0.1], 0.0],
			[["Head"], "rx", [0, 0, 1, -0.2], 0.0],
		],
		"strike": [
			[ARMS, "rx", [0, 2.7, 0.12, 0.9, 0.5, 0.9, 1, 0], 0.0],
			[ARMS_Z, "rz", [0, -0.35, 0.12, -0.15, 1, -0.15], 0.0],
			[["Torso"], "rx", [0, 0.15, 0.12, 0.45, 0.5, 0.3, 1, 0], 0.0],
			[["Body"], "py", [0, -0.1, 0.12, -0.22, 0.5, -0.1, 1, 0], 0.0],
			[["Head"], "rx", [0, -0.2, 0.12, 0.3, 1, 0], 0.0],
			[LEGS, "rx", [0, -0.1, 0.12, 0.35, 1, 0], 0.0],
		],
		"stagger": [
			[ARMS, "rx", [0, 0.15, 0.5, 0.2, 1, 0.15], 0.0],
			[["Torso"], "rx", [0, 0.25, 0.5, 0.35, 1, 0.25], 0.0],
			[["Head"], "rx", [0, 0.4, 0.5, 0.5, 1, 0.4], 0.0],
			[["Torso"], "ry", [0, 0, 0.25, 0.1, 0.75, -0.1, 1, 0], 0.0],
			[["Body"], "py", [0, -0.12, 0.5, -0.1, 1, -0.12], 0.0],
			[LEGS, "rx", [0, 0.2, 0.5, 0.26, 1, 0.2], 0.0],
		],
		"flinch": [
			[["Torso"], "rx", [0, 0, 0.3, -0.25, 1, 0], 0.0],
			[["Head"], "rx", [0, 0, 0.3, -0.4, 1, 0], 0.0],
			[ARMS, "rx", [0, 0, 0.3, 0.5, 1, 0], 0.0],
			[ARMS_Z, "rz", [0, -0.15, 0.3, -0.55, 1, -0.15], 0.0],
		],
		"death": [
			[["Torso"], "rx", [0, 0, 1, 0.8], 0.0],
			[["Head"], "rx", [0, 0, 1, 0.8], 0.0],
			[ARMS, "rx", [0, 0, 1, 0.5], 0.0],
			[LEGS, "rx", [0, 0, 1, 0.6], 0.0],
			[["Body"], "py", [0, 0, 1, -0.4], 0.0],
		],
	},
	"bomber": {
		"idle": [
			[["Puff"], "sa", [0, 0, 0.5, 0.04, 1, 0], 0.0],
			[["Body"], "py", [0, 0, 0.5, 0.03, 1, 0], 0.0],
			[FINS, "rz", [0, 0.3, 0.5, -0.3, 1, 0.3], 0.0],
			[["Spark"], "sa", [
				0, -0.15, 0.1, 0.2, 0.2, -0.1, 0.3, 0.15, 0.4, -0.15, 0.5, 0.2, 0.6, -0.1, 0.7, 0.15, 0.8, -0.15,
				0.9, 0.2, 1, -0.15
			], 0.0],
		],
		"walk": [
			[["Body"], "py", [0, 0, 0.25, 0.1, 0.5, 0, 0.75, 0.1, 1, 0], 0.0],
			[["Puff"], "sy", [0, -0.06, 0.25, 0.05, 0.5, -0.06, 0.75, 0.05, 1, -0.06], 0.0],
			[FINS, "rz", [0, 0.5, 0.25, -0.5, 0.5, 0.5, 0.75, -0.5, 1, 0.5], 0.0],
			[["Puff"], "rx", [0, -0.1, 1, -0.1], 0.0],
			[["Spark"], "sa", [0, -0.1, 0.25, 0.25, 0.5, -0.1, 0.75, 0.25, 1, -0.1], 0.0],
		],
		"windup": [
			[["Puff"], "sa", [0, 0, 0.55, 0.25, 0.65, 0.2, 0.75, 0.32, 0.85, 0.28, 0.95, 0.42, 1, 0.45], 0.0],
			[FINS, "rz", [0, 0.35, 0.2, -0.4, 0.4, 0.5, 0.6, -0.6, 0.8, 0.7, 1, -0.8], 0.0],
			[["Spark"], "sa", [0, -0.15, 1, 0.9], 0.0],
			[["Body"], "py", [0, 0, 1, 0.06], 0.0],
		],
		"stagger": [
			[["Puff"], "sy", [0, -0.2, 0.5, -0.15, 1, -0.2], 0.0],
			[["Puff"], "sxz", [0, 0.1, 0.5, 0.13, 1, 0.1], 0.0],
			[FINS, "rz", [0, -0.8, 0.5, -0.9, 1, -0.8], 0.0],
			[["Spark"], "sa", [0, -0.5, 0.5, -0.4, 1, -0.5], 0.0],
			[["Body"], "py", [0, -0.05, 0.5, -0.04, 1, -0.05], 0.0],
		],
		"flinch": [
			[["Puff"], "sa", [0, 0, 0.3, -0.2, 1, 0], 0.0],
			[FINS, "rz", [0, 0, 0.3, 1.0, 1, 0], 0.0],
			[["Spark"], "sa", [0, 0, 0.3, 0.6, 1, 0], 0.0],
			[["Body"], "py", [0, 0, 0.3, 0.05, 1, 0], 0.0],
		],
		"death": [
			[["Puff"], "sa", [0, 0.45, 0.25, 0.9, 1, -0.5], 0.0],
			[FINS, "rz", [0, 0.9, 1, 1.6], 0.0],
			[["Spark"], "sa", [0, 0.9, 0.3, 2.0, 1, 0], 0.0],
			[["Body"], "py", [0, 0.06, 0.3, 0.2, 1, 0], 0.0],
		],
	},
	"sentinel": {
		"idle": [
			[["Crystal"], "py", [0, 0, 0.5, 0.08, 1, 0], 0.0],
			[["Crystal"], "wy", [0, 1.5, 1, 1.5], 0.0],
			[["Shards"], "wy", [0, -2.5, 1, -2.5], 0.0],
			[["Crystal"], "sa", [0, 0, 0.5, 0.03, 1, 0], 0.0],
			[["Crystal"], "rz", [0, 0, 0.25, 0.05, 0.75, -0.05, 1, 0], 0.0],
		],
		"walk": [
			[["Crystal"], "rx", [0, 0, 0.25, 0.2, 0.75, -0.2, 1, 0], 0.0],
			[["Crystal"], "wy", [0, 3, 1, 3], 0.0],
			[["Shards"], "wy", [0, -5, 1, -5], 0.0],
			[["Body"], "py", [0, 0, 0.5, 0.02, 1, 0], 0.0],
		],
		"windup": [
			[["Crystal"], "py", [0, 0, 1, 0.25], 0.0],
			[["Crystal"], "wy", [0, 1.5, 1, 11.5], 0.0],
			[["Shards"], "wy", [0, -2.5, 1, -14.5], 0.0],
			[["Crystal"], "sa", [0, 0, 1, 0.12], 0.0],
			[["Crystal"], "rx", [0, 0, 1, -0.2], 0.0],
		],
		"strike": [
			[["Crystal"], "py", [0, 0.25, 0.15, 0.1, 1, 0], 0.0],
			[["Crystal"], "wy", [0, 11.5, 0.3, 6, 1, 1.5], 0.0],
			[["Shards"], "wy", [0, -14.5, 0.3, -8, 1, -2.5], 0.0],
			[["Crystal"], "sa", [0, 0.12, 0.1, -0.1, 0.4, 0.03, 1, 0], 0.0],
			[["Crystal"], "rx", [0, -0.2, 0.1, 0.35, 1, 0], 0.0],
		],
		"stagger": [
			[["Crystal"], "py", [0, -0.25, 0.5, -0.22, 1, -0.25], 0.0],
			[["Crystal"], "wy", [0, 0.25, 1, 0.25], 0.0],
			[["Shards"], "wy", [0, -0.3, 1, -0.3], 0.0],
			[["Crystal"], "rz", [0, 0.25, 0.5, 0.3, 1, 0.25], 0.0],
		],
		"flinch": [
			[["Crystal"], "rz", [0, 0, 0.3, 0.3, 1, 0], 0.0],
			[["Crystal"], "py", [0, 0, 0.3, -0.1, 1, 0], 0.0],
			[["Shards"], "wy", [0, -2.5, 0.3, -8, 1, -2.5], 0.0],
			[["Crystal"], "wy", [0, 1.5, 1, 1.5], 0.0],
		],
		"death": [
			[["Crystal"], "py", [0, 0, 0.3, 0.3, 1, -0.6], 0.0],
			[["Crystal"], "wy", [0, 8, 1, 0], 0.0],
			[["Shards"], "sa", [0, 0, 1, 1.2], 0.0],
			[["Crystal"], "sa", [0, 0, 0.4, 0.2, 1, -0.6], 0.0],
			[["Body"], "py", [0, 0, 1, -0.15], 0.0],
		],
	},
	"glimmer": {
		"idle": [
			[["Body"], "py", [0, 0, 0.5, 0.03, 1, 0], 0.0],
			[EARS, "rx", [0, 0.25, 0.5, 0.35, 1, 0.25], 0.0],
			[["EarL"], "rz", [0, 0, 0.9, 0, 0.95, 0.2, 1, 0], 0.0],
			[["EarR"], "rz", [0, 0, 0.9, 0, 0.95, -0.2, 1, 0], 0.4],
		],
		"walk": [
			[["Body"], "py", [0, 0, 0.25, 0.16, 0.5, 0, 0.75, 0.16, 1, 0], 0.0],
			[EARS, "rx", [0, 0.5, 0.25, 0.1, 0.5, 0.5, 0.75, 0.1, 1, 0.5], 0.0],
			[["EarL"], "rz", [0, -0.1, 0.5, 0.1, 1, -0.1], 0.0],
			[["EarR"], "rz", [0, 0.1, 0.5, -0.1, 1, 0.1], 0.0],
		],
		"stagger": [
			[EARS, "rx", [0, 0.9, 0.5, 1.0, 1, 0.9], 0.0],
			[["EarL"], "rz", [0, -0.3, 0.5, -0.4, 1, -0.3], 0.0],
			[["EarR"], "rz", [0, 0.3, 0.5, 0.4, 1, 0.3], 0.0],
			[["Body"], "py", [0, -0.05, 0.5, -0.04, 1, -0.05], 0.0],
		],
		"flinch": [
			[EARS, "rx", [0, 0.25, 0.3, 0.9, 1, 0.25], 0.0],
			[["Body"], "py", [0, 0, 0.3, 0.08, 1, 0], 0.0],
		],
		"death": [
			[EARS, "rx", [0, 0.25, 1, 1.2], 0.0],
			[["Body"], "py", [0, 0, 0.3, 0.2, 1, -0.1], 0.0],
		],
	},
}

## Baked tables: kind -> {"slots": [pivot names], "mask": PackedInt32Array per slot, "states": [per state: tracks]},
## a track being [targets (slot * STRIDE + channel), signs, curve, phase offset].
static var _baked := {}

class Rig:
	var nodes: Array[Node3D] = []
	var rest_r := PackedVector3Array()
	var rest_p := PackedVector3Array()
	var mask := PackedInt32Array()
	var acc := PackedFloat32Array()
	var def: Dictionary
	var desync := 0.0      # per-monster offset so a camp does not breathe in step

static func base_kind(kind: String) -> String:
	return "brute" if kind == "warden" else kind

## True when this kind has keyed moves.
static func has_kind(kind: String) -> bool:
	return MOVES.has(base_kind(kind))

## The tracks a kind plays in a state (run falls back to walk); empty when the kind has none.
static func tracks(kind: String, state: int) -> Array:
	var d := table(kind)
	var t: Array = d["states"][state]
	return d["states"][WALK] if t.is_empty() and state == RUN else t

## Which states the kind can be in: a monster with no attack never winds up or strikes.
static func state_needed(kind: String, state: int) -> bool:
	if state != WINDUP and state != STRIKE:
		return true
	var atk := String(Data.MOBS[kind]["attack"])
	if state == WINDUP:
		return atk != "none"
	return atk == "lunge" or RECOVER_S.has(atk)

static func table(kind: String) -> Dictionary:
	var k := base_kind(kind)
	if _baked.has(k):
		return _baked[k]
	var slots: Array = []
	var mask := PackedInt32Array()
	var states: Array = []
	for s in STATES.size():
		var out: Array = []
		for tr in MOVES[k].get(STATES[s], []):
			var targets := PackedInt32Array()
			var signs := PackedFloat32Array()
			for nm in tr[0]:
				var neg := String(nm).begins_with("-")
				var slot := slots.find(String(nm).trim_prefix("-"))
				if slot < 0:
					slots.append(String(nm).trim_prefix("-"))
					mask.append(0)
					slot = slots.size() - 1
				for ch in CHANS[tr[1]]:
					targets.append(slot * STRIDE + ch)
					signs.append(-1.0 if neg else 1.0)
					mask[slot] |= KIND_BIT[ch]
			out.append([targets, signs, _bake(tr[2], LOOPS[s]), float(tr[3])])
		states.append(out)
	var d := {"slots": slots, "mask": mask, "states": states}
	_baked[k] = d
	return d

## Keys to SAMPLES + 1 evenly spaced values: eased between keys on loops, straight on one-shots.
static func _bake(keys: Array, loop: bool) -> PackedFloat32Array:
	var c := PackedFloat32Array()
	for i in SAMPLES + 1:
		var t := float(i) / SAMPLES
		var j := 0
		while j < keys.size() - 4 and t > float(keys[j + 2]):
			j += 2
		var span := float(keys[j + 2]) - float(keys[j])
		var f := clampf((t - float(keys[j])) / span, 0.0, 1.0) if span > 0.0 else 1.0
		c.append(lerpf(float(keys[j + 1]), float(keys[j + 3]), smoothstep(0.0, 1.0, f) if loop else f))
	return c

# ------------------------------------------------------------------ state and phase

## The same fraction the ground telegraph fills with: 0 as the wind-up starts, 1 as the blow lands.
static func windup_k(st_t: float, windup: float) -> float:
	return clampf(1.0 - st_t / windup, 0.0, 1.0)

## How far through the blow and its follow-through the monster is, 0..1.
static func strike_k(attack: String, st: String, st_t: float) -> float:
	if attack == "lunge":
		var total := LUNGE_S + LUNGE_REC
		var left := st_t + (LUNGE_REC if st == "lunge" else 0.0)       # the lunge leaves its recovery still to run
		return clampf(1.0 - left / total, 0.0, 1.0)
	var len_s := float(RECOVER_S.get(attack, 0.0))
	return clampf(1.0 - st_t / len_s, 0.0, 1.0) if len_s > 0.0 else 0.0

static func state_of(mb: Mob) -> int:
	if mb.dead: return DEATH
	if mb.stagger_t > 0.0 or mb.stun_t > 0.0: return STAGGER
	if mb.st == "windup": return WINDUP
	if mb.st == "lunge" or mb.st == "recover": return STRIKE
	if mb.flash_t > 0.0: return FLINCH
	var spd := Vector2(mb.vel.x, mb.vel.z).length()
	if spd <= 0.3: return IDLE
	return RUN if spd > RUN_SPEED else WALK

static func phase_of(mb: Mob, state: int, desync: float) -> float:
	var k := base_kind(mb.mkind)
	match state:
		IDLE: return fposmod(float(mb.m.time) / float(IDLE_S.get(k, 2.5)) + desync, 1.0)
		WALK, RUN: return fposmod(mb.anim * float(GAIT.get(k, 1.0)) / TAU, 1.0)
		WINDUP: return windup_k(mb.st_t, float(mb.md["windup"]))
		STRIKE: return strike_k(String(mb.md["attack"]), mb.st, mb.st_t)
		STAGGER: return fposmod(float(mb.m.time) / STAGGER_S + desync, 1.0)
		FLINCH: return clampf(1.0 - mb.flash_t / FLASH_S, 0.0, 1.0)
	return clampf(mb.death_t / DEATH_S, 0.0, 1.0)

# ------------------------------------------------------------------ posing

## A named pivot under the model's Body (Body itself included); null when the model lacks it.
static func pivot(body: Node, nm: String) -> Node3D:
	return body as Node3D if nm == "Body" else body.find_child(nm, true, false) as Node3D

static func _rig(model: Node3D, kind: String) -> Rig:
	if model.has_meta("mob_rig"):
		return model.get_meta("mob_rig")
	var rig := Rig.new()
	rig.def = table(kind)
	var body := model.get_node("Body")
	for nm in rig.def["slots"]:
		var n := pivot(body, String(nm))
		rig.nodes.append(n)
		rig.rest_r.append(n.rotation if n else Vector3.ZERO)
		rig.rest_p.append(n.position if n else Vector3.ZERO)
	rig.mask = rig.def["mask"]
	rig.acc.resize(rig.nodes.size() * STRIDE)
	rig.desync = float(absi(hash(kind + str(model.get_instance_id()))) % 1000) / 1000.0
	model.set_meta("mob_rig", rig)
	return rig

## Samples the monster's current state into its pivots. False when this body has no keyed moves (pack models, bosses).
static func pose(mb: Mob, delta: float) -> bool:
	if mb.model == null or not mb.model.has_meta("sculpted") or not has_kind(mb.mkind):
		return false
	var cam = mb.m.get("cam")
	if cam != null and Vector2(mb.pos.x - cam.focus.x, mb.pos.z - cam.focus.z).length() > FAR_M:
		return true
	var rig := _rig(mb.model, mb.mkind)
	var state := state_of(mb)
	var ph := phase_of(mb, state, rig.desync)
	var amp := 1.0
	var trs: Array = rig.def["states"][state]
	if trs.is_empty() and state == RUN:
		trs = rig.def["states"][WALK]
		amp = RUN_AMP
	var acc := rig.acc
	acc.fill(0.0)
	var loop: bool = LOOPS[state]
	for tr in trs:
		var p: float = ph + float(tr[3])
		p = fposmod(p, 1.0) if loop else minf(p, 1.0)
		var x := p * SAMPLES
		var i := mini(int(x), SAMPLES - 1)
		var cv: PackedFloat32Array = tr[2]
		var v := (cv[i] + (cv[i + 1] - cv[i]) * (x - i)) * amp
		var tg: PackedInt32Array = tr[0]
		var sg: PackedFloat32Array = tr[1]
		for j in tg.size():
			acc[tg[j]] += v * sg[j]
	var a := 1.0 - exp(-float(RATE[state]) * delta)
	for k in rig.nodes.size():
		var n := rig.nodes[k]
		var b := k * STRIDE
		var mk := rig.mask[k]
		if mk & 1 or mk & 8:
			var rr := rig.rest_r[k]
			var r := n.rotation
			r.x = lerpf(r.x, rr.x + acc[b], a)
			r.z = lerpf(r.z, rr.z + acc[b + 2], a)
			r.y = r.y + acc[b + 9] * delta if mk & 8 else lerpf(r.y, rr.y + acc[b + 1], a)
			n.rotation = r
		if mk & 2:
			var rp := rig.rest_p[k]
			n.position = n.position.lerp(Vector3(rp.x + acc[b + 3], rp.y + acc[b + 4], rp.z + acc[b + 5]), a)
		if mk & 4:
			n.scale = n.scale.lerp(Vector3(1.0 + acc[b + 6], 1.0 + acc[b + 7], 1.0 + acc[b + 8]), a)
	return true
