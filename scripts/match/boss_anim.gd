class_name BossAnim
extends RefCounted
## Keyed moves for the three lair bosses (BossModels), so each one shows every state on its body: sleep, wake,
## idle, walk, each attack's wind-up and strike, the phase change, stagger and death. Boss.render calls pose().
##
## MOVES[kind][move] is a list of tracks [pivots, channel, keys]:
##   pivots   pivot paths under "Body" ("." is Body itself); a leading "-" negates the value (mirrors the right side)
##   channel  rx ry rz (rotation, rad), px py pz (position, m), s (uniform scale), sy (height scale); offsets from rest
##   keys     flat [phase, value, phase, value ...] from 0 to 1
## A move named "<attack>_windup" runs 0..1 over the same seconds the ground telegraph fills (hit_t), so the body
## has gathered the frame the tell is full; "<attack>_strike" runs from there through the follow-through. The
## Colossus is a rigged pack model: its moves also pick the clip and which stretch of it plays (CLIP).
## A pivot follows its target with an exponential lag, so a change of move blends instead of popping.

const STATES := ["sleep", "wake", "idle", "walk", "stagger", "phase", "death"]
const ATTACKS := {
	"colossus": ["slam", "boulders", "fissure"],
	"serpent": ["dash", "storm", "static"],
	"brood": ["spit", "lob", "brood", "burrow"],
}
const WAKE_S := 1.5               # s: Lairs.wake holds its first attack back 1.6 s
const PHASE_S := 2.4              # s: the phase roar (Boss._phase_up)
const DEATH_S := 1.1              # s: the death move, then the body is handed to the dissolve
const DASH_GAP_S := 0.55          # s: the serpent's dash itself, before the next wind-up
const BURROW_HIT_S := 2.1         # s into a burrow when the Brood Mother bursts up under you
const BROOD_EGG_K := 0.5          # the egg sacs show at this share of the brood wind-up
## s the strike move runs: the blow plus the follow-through (the attack's length minus its wind-up)
const STRIKE_S := {"slam": 0.6, "boulders": 0.9, "fissure": 0.5, "dash": DASH_GAP_S, "storm": 0.5, "static": 0.6,
	"spit": 0.5, "lob": 0.9, "brood": 0.8, "burrow": 0.6}
const IDLE_S := {"colossus": 4.0, "serpent": 1.8, "brood": 2.4}      # s per idle loop
const STAGGER_S := 1.2            # s per stagger loop
const GAIT := {"colossus": 0.8, "serpent": 1.2, "brood": 1.4}        # walk cycles per radian of Boss.anim / TAU
const LOOP_RATE := {"sleep": 0.6, "stagger": 0.3}      # Colossus clip speed for the loops that are not at full speed
const WALK_MPS := 0.3             # m/s: above this the walk plays
const RATE_FAST := 30.0           # 1/s: how tightly a pivot follows wind-ups, strikes and the death
const RATE_SLOW := 8.0            # 1/s: for the loops and the wake
const CHANS := {"rx": 0, "ry": 1, "rz": 2, "px": 3, "py": 4, "pz": 5, "s": 6, "sy": 7}

## The Colossus clips (Assets.MOBS "colossus"): the spec key, and for a scrubbed move the stretch of the clip it plays.
const CLIP := {
	"sleep": ["idle"], "idle": ["idle"], "walk": ["walk"], "stagger": ["idle"],
	"wake": ["roar", 0.0, 1.0], "phase": ["roar", 0.0, 1.0], "death": ["die", 0.0, 1.0],
	"slam_windup": ["attack", 0.0, -1.0], "slam_strike": ["attack", -1.0, 1.0],
	"fissure_windup": ["attack", 0.0, -1.0], "fissure_strike": ["attack", -1.0, 1.0],
	"boulders_windup": ["throw", 0.0, -1.0], "boulders_strike": ["throw", -1.0, 1.0],
}

const SERP_WINGS := ["Head/WingL", "-Head/WingR"]
const BR_JAWS := ["Head/JawL", "-Head/JawR"]
const BR_LEGS := ["Legs/Leg01", "Legs/Leg11", "Legs/Leg21", "-Legs/Leg0-1", "-Legs/Leg1-1", "-Legs/Leg2-1"]
const BR_TRI_A := ["Legs/Leg01", "Legs/Leg21", "Legs/Leg1-1"]
const BR_TRI_B := ["Legs/Leg0-1", "Legs/Leg2-1", "Legs/Leg11"]
const B := ["."]
const SHIVER := [0.1, 0, 0.2, 0.15, 0.3, -0.15, 0.4, 0.15, 0.5, -0.15, 0.6, 0.1, 0.7, 0]

# The match camera looks almost straight down, so the big moves also turn (ry), swell (s) and shift (pz): lean and
# rise alone barely show from above.
const SLAM_W := [
	[B, "rx", [0, 0, 1, 0.4]], [B, "py", [0, 0, 1, 0.35]], [B, "ry", [0, 0, 1, 0.4]], [B, "s", [0, 0, 1, 0.1]],
]
const SLAM_S := [
	[B, "rx", [0, 0.4, 0.15, -0.45, 0.5, -0.2, 1, 0]], [B, "py", [0, 0.35, 0.15, -0.2, 0.5, -0.05, 1, 0]],
	[B, "ry", [0, 0.4, 0.15, -0.5, 0.5, -0.15, 1, 0]], [B, "s", [0, 0.1, 0.15, -0.04, 0.5, 0, 1, 0]],
]

const MOVES := {
	"colossus": {
		"sleep": [[B, "rx", [0, 0.25, 0.5, 0.27, 1, 0.25]], [B, "py", [0, -0.25, 0.5, -0.23, 1, -0.25]]],
		"wake": [[B, "s", [0, 0, 0.4, 0.1, 1, 0]], [B, "rx", [0, 0.25, 0.3, 0.45, 0.7, 0.1, 1, 0]],
			[B, "py", [0, -0.25, 0.3, -0.4, 0.6, 0.2, 0.85, 0.05, 1, 0]],
			[B, "rz", [0.55, 0, 0.65, 0.06, 0.75, -0.06, 0.85, 0.04, 1, 0]]],
		"idle": [[B, "py", [0, 0, 0.5, 0.03, 1, 0]], [B, "rx", [0, 0, 0.5, -0.01, 1, 0]]],
		"walk": [[B, "py", [0, 0, 0.25, 0.05, 0.5, 0, 0.75, 0.05, 1, 0]], [B, "rz", [0, 0.03, 0.5, -0.03, 1, 0.03]],
			[B, "rx", [0, -0.05, 1, -0.05]]],
		"stagger": [[B, "rx", [0, -0.35, 0.5, -0.4, 1, -0.35]], [B, "py", [0, -0.4, 0.5, -0.38, 1, -0.4]],
			[B, "rz", [0, 0.1, 0.5, -0.1, 1, 0.1]]],
		"phase": [[B, "s", [0, 0, 0.1, 0.12, 0.7, 0.12, 1, 0]], [B, "rx", [0, -0.3, 0.1, 0.55, 0.7, 0.55, 1, 0]],
			[B, "py", [0, -0.2, 0.1, 0.4, 0.7, 0.4, 1, 0]],
			[B, "rz", SHIVER]],
		"death": [[B, "rx", [0, 0, 0.4, -0.35, 1, -0.9]], [B, "py", [0, 0, 0.4, -0.5, 1, -1.2]],
			[B, "rz", [0, 0, 1, 0.3]]],
		"slam_windup": SLAM_W, "slam_strike": SLAM_S, "fissure_windup": SLAM_W, "fissure_strike": SLAM_S,
		"boulders_windup": [[B, "ry", [0, 0, 1, -0.35]], [B, "s", [0, 0, 1, 0.08]], [B, "rx", [0, 0, 1, 0.3]],
			[B, "py", [0, 0, 1, 0.2]], [B, "rz", [0, 0, 1, -0.1]]],
		"boulders_strike": [[B, "ry", [0, -0.35, 0.2, 0.4, 1, 0]], [B, "s", [0, 0.08, 0.2, -0.03, 1, 0]],
			[B, "rx", [0, 0.3, 0.2, -0.3, 1, 0]], [B, "py", [0, 0.2, 0.2, -0.05, 1, 0]],
			[B, "rz", [0, -0.1, 0.3, 0.05, 1, 0]]],
	},
	"serpent": {
		"sleep": [[["Head"], "py", [0, -0.8, 0.5, -0.78, 1, -0.8]], [["Head"], "rx", [0, 0.3, 1, 0.3]],
			[["Head/Jaw"], "rx", [0, 0.1, 1, 0.1]]],
		"wake": [[["Head"], "py", [0, -0.8, 0.35, 0.3, 0.6, 0.1, 1, 0.05]],
			[["Head"], "rx", [0, 0.3, 0.35, 0.7, 0.7, 0.3, 1, 0]],
			[["Head/Jaw"], "rx", [0, 0.1, 0.4, 0.7, 0.7, 0.7, 1, 0.1]],
				[SERP_WINGS, "rz", [0, 0, 0.4, 0.9, 0.7, 0.5, 1, 0]]],
		"idle": [[["Head"], "py", [0, 0.05, 0.25, 0.23, 0.5, 0.05, 0.75, -0.13, 1, 0.05]],
			[["Head/Jaw"], "rx", [0, 0.1, 0.5, 0.14, 1, 0.1]],
				[SERP_WINGS, "rz", [0, 0, 0.25, 0.35, 0.5, 0, 0.75, -0.35, 1, 0]]],
		"walk": [[["Head"], "py", [0, 0.05, 0.25, 0.23, 0.5, 0.05, 0.75, -0.13, 1, 0.05]],
			[["Head"], "rx", [0, -0.12, 1, -0.12]],
			[["Head/Jaw"], "rx", [0, 0.1, 1, 0.1]], [SERP_WINGS, "rz", [0, 0, 0.25, 0.45, 0.5, 0, 0.75, -0.45, 1, 0]]],
		"stagger": [[["Head"], "py", [0, -0.7, 0.5, -0.66, 1, -0.7]], [["Head"], "rx", [0, -0.6, 1, -0.6]],
			[["Head"], "ry", [0, 0.2, 0.5, -0.2, 1, 0.2]], [["Head/Jaw"], "rx", [0, 0.5, 1, 0.5]],
				[SERP_WINGS, "rz", [0, -0.5, 1, -0.5]]],
		"phase": [[["Head"], "s", [0, 0, 0.1, 0.25, 0.7, 0.25, 1, 0]],
			[["Head"], "py", [0, 0.1, 0.1, 0.9, 0.7, 0.9, 1, 0.05]],
			[["Head"], "rx", [0, 0, 0.1, 0.8, 0.7, 0.7, 1, 0]],
			[["Head"], "ry", SHIVER], [["Head/Jaw"], "rx", [0, 0.1, 0.1, 0.9, 0.7, 0.9, 1, 0.1]],
			[SERP_WINGS, "rz", [0, 0, 0.1, 1.0, 0.7, 1.0, 1, 0]]],
		"death": [[["Head"], "py", [0, 0, 0.5, -0.7, 1, -1.0]], [["Head"], "rx", [0, 0, 0.5, -0.7, 1, -0.9]],
			[["Head/Jaw"], "rx", [0, 0.1, 0.3, 0.9, 1, 0.8]], [SERP_WINGS, "rz", [0, 0, 1, -0.8]]],
		"dash_windup": [[["Head"], "s", [0, 0, 1, 0.15]], [["Head"], "pz", [0, 0, 1, 0.8]],
			[["Head"], "py", [0, 0.05, 1, -0.35]],
			[["Head"], "rx", [0, 0, 1, 0.55]],
			[["Head/Jaw"], "rx", [0, 0.1, 1, 0.8]], [SERP_WINGS, "rz", [0, 0, 1, 0.9]]],
		"dash_strike": [[["Head"], "s", [0, 0.15, 0.2, 0, 1, 0]], [["Head"], "pz", [0, 0.8, 0.2, -0.9, 1, 0]],
			[["Head"], "py", [0, -0.35, 0.2, -0.1, 1, 0.05]],
			[["Head"], "rx", [0, 0.55, 0.2, -0.5, 0.6, -0.3, 1, 0]], [["Head/Jaw"], "rx", [0, 0.8, 0.5, 0.9, 1, 0.1]],
			[SERP_WINGS, "rz", [0, 0.9, 0.2, 0.1, 1, 0]]],
		"storm_windup": [[["Head"], "s", [0, 0, 1, 0.25]], [["Head"], "py", [0, 0.05, 1, 0.9]],
			[["Head"], "rx", [0, 0, 1, 0.75]],
			[["Head/Jaw"], "rx", [0, 0.1, 1, 0.9]], [SERP_WINGS, "rz", [0, 0, 1, 1.0]]],
		"storm_strike": [[["Head"], "s", [0, 0.25, 0.25, 0, 1, 0]], [["Head"], "py", [0, 0.9, 0.25, 0.3, 1, 0.05]],
			[["Head"], "rx", [0, 0.75, 0.25, -0.2, 1, 0]],
			[["Head/Jaw"], "rx", [0, 0.9, 0.3, 0.2, 1, 0.1]], [SERP_WINGS, "rz", [0, 1.0, 0.3, 0.2, 1, 0]]],
		"static_windup": [[["Head"], "py", [0, 0.05, 1, -0.45]], [["Head"], "pz", [0, 0, 1, 0.5]],
			[["Head"], "rx", [0, 0, 1, -0.35]],
			[["Head"], "s", [0, 0, 1, -0.1]], [["Head/Jaw"], "rx", [0, 0.1, 1, 0.3]],
				[SERP_WINGS, "rz", [0, 0, 1, -0.5]]],
		"static_strike": [[["Head"], "py", [0, -0.45, 0.15, 0.3, 1, 0.05]], [["Head"], "pz", [0, 0.5, 0.15, 0, 1, 0]],
			[["Head"], "rx", [0, -0.35, 0.15, 0.6, 1, 0]], [["Head"], "s", [0, -0.1, 0.15, 0.35, 1, 0]],
			[["Head/Jaw"], "rx", [0, 0.3, 0.15, 1.0, 1, 0.1]], [SERP_WINGS, "rz", [0, -0.5, 0.15, 1.1, 1, 0]]],
	},
	"brood": {
		"sleep": [[B, "py", [0, -0.35, 1, -0.35]], [BR_LEGS, "rz", [0, -0.3, 1, -0.3]],
			[["Sac"], "s", [0, -0.02, 0.5, 0.02, 1, -0.02]],
			[BR_JAWS, "ry", [0, 0.15, 1, 0.15]]],
		"wake": [[B, "py", [0, -0.35, 0.4, 0.25, 0.7, -0.05, 1, 0]], [B, "rx", [0, 0, 0.4, 0.3, 0.7, -0.1, 1, 0]],
			[BR_LEGS, "rz", [0, -0.3, 0.4, 0.6, 1, 0]], [BR_JAWS, "ry", [0, 0.15, 0.4, 0.8, 0.8, 0.8, 1, 0.15]]],
		"idle": [[["Sac"], "s", [0, 0, 0.5, 0.04, 1, 0]], [BR_JAWS, "ry", [0, 0.15, 0.5, 0.2, 1, 0.15]]],
		"walk": [[BR_TRI_A, "ry", [0, 0, 0.25, 0.35, 0.75, -0.35, 1, 0]],
			[BR_TRI_B, "ry", [0, 0, 0.25, -0.35, 0.75, 0.35, 1, 0]],
			[BR_LEGS, "rz", [0, 0.2, 0.25, 0, 0.5, 0.2, 0.75, 0, 1, 0.2]],
				[B, "py", [0, 0, 0.25, 0.06, 0.5, 0, 0.75, 0.06, 1, 0]],
			[["Sac"], "s", [0, 0, 0.5, 0.04, 1, 0]]],
		"stagger": [[B, "py", [0, -0.3, 0.5, -0.28, 1, -0.3]], [B, "rx", [0, -0.1, 1, -0.1]],
			[BR_LEGS, "rz", [0, -0.4, 0.5, -0.3, 1, -0.4]],
			[BR_TRI_A, "ry", [0, 0.15, 0.5, -0.15, 1, 0.15]], [BR_JAWS, "ry", [0, 0.6, 1, 0.6]],
				[["Sac"], "s", [0, -0.05, 0.5, 0, 1, -0.05]]],
		"phase": [[B, "rx", [0, -0.1, 0.1, 0.6, 0.7, 0.6, 1, 0]], [B, "py", [0, 0, 0.1, 0.3, 0.7, 0.3, 1, 0]],
			[B, "ry", SHIVER], [BR_LEGS, "rz", [0, 0, 0.2, 0.7, 0.7, 0.7, 1, 0]],
				[["Head"], "rx", [0, 0, 0.1, 0.5, 0.7, 0.5, 1, 0]],
			[BR_JAWS, "ry", [0, 0.15, 0.1, 0.8, 0.7, 0.8, 1, 0.15]], [["Sac"], "s", [0, 0, 0.2, 0.2, 0.7, 0.2, 1, 0]]],
		"death": [[B, "py", [0, 0, 0.5, -0.5, 1, -0.85]], [B, "rx", [0, 0, 1, -0.1]], [BR_LEGS, "rz", [0, 0, 1, -0.9]],
			[BR_JAWS, "ry", [0, 0.15, 0.3, 0.8, 1, 0.7]], [["Sac"], "s", [0, 0, 1, -0.25]]],
		"spit_windup": [[B, "s", [0, 0, 1, 0.1]], [B, "rx", [0, 0, 1, 0.3]], [B, "py", [0, 0, 1, -0.2]],
			[["Head"], "rx", [0, 0, 1, 0.4]],
			[BR_JAWS, "ry", [0, 0.15, 1, 0.75]], [BR_LEGS, "rz", [0, 0, 1, 0.3]]],
		"spit_strike": [[B, "s", [0, 0.1, 0.2, -0.03, 1, 0]], [B, "rx", [0, 0.3, 0.2, -0.2, 1, 0]],
			[B, "py", [0, -0.2, 0.2, -0.05, 1, 0]],
			[["Head"], "rx", [0, 0.4, 0.2, -0.2, 1, 0]], [BR_JAWS, "ry", [0, 0.75, 0.25, 0.1, 1, 0.15]],
				[BR_LEGS, "rz", [0, 0.3, 1, 0]]],
		"lob_windup": [[B, "s", [0, 0, 1, 0.12]], [B, "rx", [0, 0, 1, 0.5]], [B, "py", [0, 0, 1, 0.1]],
			[["Sac"], "s", [0, 0, 1, 0.18]],
			[["Head"], "rx", [0, 0, 1, 0.6]], [BR_JAWS, "ry", [0, 0.15, 1, 0.8]], [BR_LEGS, "rz", [0, 0, 1, 0.4]]],
		"lob_strike": [[B, "s", [0, 0.12, 0.25, -0.04, 1, 0]], [B, "rx", [0, 0.5, 0.25, -0.3, 1, 0]],
			[B, "py", [0, 0.1, 0.25, -0.1, 1, 0]],
			[["Sac"], "s", [0, 0.18, 0.25, -0.1, 1, 0]], [["Head"], "rx", [0, 0.6, 0.25, -0.3, 1, 0]],
			[BR_JAWS, "ry", [0, 0.8, 0.3, 0.1, 1, 0.15]], [BR_LEGS, "rz", [0, 0.4, 1, 0]]],
		"brood_windup": [[B, "py", [0, 0, 1, -0.25]], [B, "rx", [0, 0, 1, -0.15]], [["Sac"], "s", [0, 0, 1, 0.25]],
			[BR_LEGS, "rz", [0, 0, 1, 0.3]], [BR_JAWS, "ry", [0, 0.15, 1, 0.3]]],
		"brood_strike": [[B, "py", [0, -0.25, 0.25, -0.1, 1, 0]], [B, "rx", [0, -0.15, 0.5, -0.05, 1, 0]],
			[["Sac"], "s", [0, 0.25, 0.25, -0.1, 0.5, 0.2, 0.75, -0.05, 1, 0]], [BR_LEGS, "rz", [0, 0.3, 1, 0]],
			[BR_JAWS, "ry", [0, 0.3, 1, 0.15]]],
		"burrow_windup": [[B, "py", [0, 0, 0.19, -1.6, 1, -1.6]], [B, "rx", [0, 0, 0.19, -0.4, 1, -0.4]],
			[BR_LEGS, "rz", [0, 0, 0.19, -0.5, 1, -0.5]], [BR_JAWS, "ry", [0, 0.15, 1, 0.15]]],
		"burrow_strike": [[B, "py", [0, -1.6, 0.25, 0.5, 0.6, -0.05, 1, 0]], [B, "rx", [0, -0.4, 0.25, 0.35, 1, 0]],
			[BR_LEGS, "rz", [0, -0.5, 0.25, 0.7, 1, 0]], [BR_JAWS, "ry", [0, 0.15, 0.2, 0.8, 0.6, 0.8, 1, 0.15]]],
	},
}

## Where one boss's posed pivots live: the nodes, their rest values, where each is now, where it is heading.
class Rig:
	extends RefCounted
	var nodes: Array[Node3D] = []
	var chans := PackedInt32Array()
	var base := PackedFloat32Array()
	var now := PackedFloat32Array()
	var aim := PackedFloat32Array()

static var _compiled := {}        # kind -> {"pairs": [[path, channel]], "moves": {move: [[idx, mirror, keys]]}}
static var cur_move := ""         # pick()'s answer for the boss it was asked about: the move playing...
static var cur_k := 0.0           # ...and how far through it (0..1)

## Seconds into the attack at which the blow lands: the frame its ground tell fills.
static func hit_t(b: Boss) -> float:
	if b.atk == "burrow":
		return BURROW_HIT_S
	var w := float(b.md["windup"])
	return w * BROOD_EGG_K if b.atk == "brood" else w

## Which move the boss is in, and how far through it. The loops run on the clock or the gait; the rest on the
## boss's own timers, so the body is always where the timers say.
static func pick(b: Boss) -> void:
	cur_k = 0.0
	if b.dead:
		cur_move = "death"
		cur_k = clampf(b.death_t / DEATH_S, 0.0, 1.0)
	elif b.dormant:
		cur_move = "sleep"
		cur_k = fposmod(b.m.time / (IDLE_S[b.mkind] * 1.5), 1.0)
	elif b.atk == "phase":
		cur_move = "phase"
		cur_k = clampf(b.atk_t / PHASE_S, 0.0, 1.0)
	elif b.stagger_t > 0.0:
		cur_move = "stagger"
		cur_k = fposmod(b.m.time / STAGGER_S, 1.0)
	elif b.atk != "":
		_pick_attack(b)
	elif b.awake_t < WAKE_S:
		cur_move = "wake"
		cur_k = b.awake_t / WAKE_S
	elif Vector2(b.vel.x, b.vel.z).length() > WALK_MPS:
		cur_move = "walk"
		cur_k = fposmod(b.anim * float(GAIT[b.mkind]) / TAU, 1.0)
	else:
		cur_move = "idle"
		cur_k = fposmod(b.m.time / float(IDLE_S[b.mkind]), 1.0)

static func _pick_attack(b: Boss) -> void:
	var hit := hit_t(b)
	var t := b.atk_t
	if b.atk == "dash":
		var cycle := hit + DASH_GAP_S
		t = t if t >= (1 + b.phase) * cycle else fmod(t, cycle)
	if t < hit:
		cur_move = b.atk + "_windup"
		cur_k = t / hit
	else:
		cur_move = b.atk + "_strike"
		cur_k = clampf((t - hit) / float(STRIKE_S[b.atk]), 0.0, 1.0)

## Poses the boss's body for this frame.
static func pose(b: Boss, delta: float) -> void:
	pick(b)
	var fresh := not b.model.has_meta("boss_rig")
	var rig := _rig_of(b)
	_aim(b.mkind, cur_move, cur_k, rig)
	if fresh:
		rig.now = rig.aim.duplicate()
	var follow := 1.0 - exp(-(RATE_FAST if _fast(cur_move) else RATE_SLOW) * delta)
	for i in rig.nodes.size():
		rig.now[i] += (rig.aim[i] - rig.now[i]) * follow
		_write(rig.nodes[i], rig.chans[i], rig.base[i] + rig.now[i])
	if b.mkind == "colossus":
		_clip(b, cur_move, cur_k)
	elif b.mkind == "serpent":
		_coils(b, delta)

static func _fast(move_name: String) -> bool:
	return move_name == "death" or move_name.ends_with("_windup") or move_name.ends_with("_strike")

static func _write(n: Node3D, chan: int, v: float) -> void:
	match chan:
		0: n.rotation.x = v
		1: n.rotation.y = v
		2: n.rotation.z = v
		3: n.position.x = v
		4: n.position.y = v
		5: n.position.z = v
		6: n.scale = Vector3.ONE * v
		7: n.scale.y = v

## The compiled tracks of one move: [indices into the rig, signs, keys] per track.
static func tracks(kind: String, move_name: String) -> Array:
	return (_tables(kind)["moves"] as Dictionary).get(move_name, [])

## Every [pivot path, channel] a kind ever poses, in rig order.
static func pairs(kind: String) -> Array:
	return _tables(kind)["pairs"]

static func _tables(kind: String) -> Dictionary:
	if _compiled.has(kind):
		return _compiled[kind]
	var pr: Array = []
	var index := {}
	var moves := {}
	for mv in MOVES[kind]:
		var out: Array = []
		for tr in MOVES[kind][mv]:
			var idx := PackedInt32Array()
			var mirror := PackedFloat32Array()
			for piv in tr[0]:
				var path := String(piv).trim_prefix("-")
				var key := "%s:%s" % [path, tr[1]]
				if not index.has(key):
					index[key] = pr.size()
					pr.append([path, String(tr[1])])
				idx.append(index[key])
				mirror.append(-1.0 if String(piv).begins_with("-") else 1.0)
			out.append([idx, mirror, PackedFloat32Array(tr[2])])
		moves[mv] = out
	_compiled[kind] = {"pairs": pr, "moves": moves}
	return _compiled[kind]

## One value on a key list at phase p (straight lines between keys).
static func sample(keys: PackedFloat32Array, p: float) -> float:
	var n := keys.size()
	if p <= keys[0]:
		return keys[1]
	for i in range(2, n, 2):
		if p <= keys[i]:
			var span := maxf(0.0001, keys[i] - keys[i - 2])
			return lerpf(keys[i - 1], keys[i + 1], (p - keys[i - 2]) / span)
	return keys[n - 1]

static func _aim(kind: String, move_name: String, p: float, rig: Rig) -> void:
	rig.aim.fill(0.0)
	for tr in tracks(kind, move_name):
		var v := sample(tr[2], p)
		var idx: PackedInt32Array = tr[0]
		var mirror: PackedFloat32Array = tr[1]
		for j in idx.size():
			rig.aim[idx[j]] = v * mirror[j]

static func _rig_of(b: Boss) -> Rig:
	if b.model.has_meta("boss_rig"):
		return b.model.get_meta("boss_rig")
	var rig := Rig.new()
	var body: Node3D = b.model.get_node("Body")
	for pc in pairs(b.mkind):
		var path := String(pc[0])
		var n: Node3D = body if path == "." else body.get_node(path)
		rig.nodes.append(n)
		rig.chans.append(CHANS[pc[1]])
		rig.base.append(rest_of(n, CHANS[pc[1]]))
	rig.now.resize(rig.nodes.size())
	rig.aim.resize(rig.nodes.size())
	b.model.set_meta("boss_rig", rig)
	return rig

static func rest_of(n: Node3D, chan: int) -> float:
	match chan:
		0: return n.rotation.x
		1: return n.rotation.y
		2: return n.rotation.z
		3: return n.position.x
		4: return n.position.y
		5: return n.position.z
		6: return n.scale.x
	return n.scale.y

## The Colossus's rigged clip: loops play on; a scrubbed stretch is held to the move's phase (the wind-up stops on
## the clip's own hit frame; the strike plays on from it).
static func _clip(b: Boss, move_name: String, p: float) -> void:
	var ap: AnimationPlayer = b.model.get_meta("anim") if b.model.has_meta("anim") else null
	if ap == null:
		return
	var spec: Dictionary = b.model.get_meta("clips")
	var cue: Array = CLIP[move_name]
	var clip_name := String(spec[cue[0]])
	if ap.current_animation != clip_name:
		ap.play(clip_name, 0.15)
	if cue.size() == 1:
		ap.speed_scale = _loop_rate(b, move_name)
		return
	var hit_k := _clip_hit(spec, cue[0])
	var from_k: float = hit_k if float(cue[1]) < 0.0 else float(cue[1])
	var to_k: float = hit_k if float(cue[2]) < 0.0 else float(cue[2])
	ap.speed_scale = 0.0
	ap.seek(ap.get_animation(clip_name).length * lerpf(from_k, to_k, p), true)

static func _loop_rate(b: Boss, move_name: String) -> float:
	if move_name == "walk":
		return clampf(Vector2(b.vel.x, b.vel.z).length() / 1.6, 0.5, 1.4)
	return float(LOOP_RATE.get(move_name, 1.0))

## Where in its clip the blow lands (0..1).
static func _clip_hit(spec: Dictionary, which: String) -> float:
	return float(spec["throw_hit"]) if which == "throw" else float(spec["hit"])

## The serpent's coils trail the head's path (Boss.trail); asleep they lie in a loose spiral; dying they sag.
static func _coils(b: Boss, delta: float) -> void:
	var sleep := 1.0 if b.dormant else 0.0
	var hover := (1.0 - sleep * 0.85) * (1.0 - (cur_k if b.dead else 0.0))
	var head := b.model.get_node("Body/Head") as Node3D
	var segs: Array = b.model.get_meta("segs", [])
	var time: float = b.m.time
	for i in segs.size():
		var s: Node3D = segs[i]
		var p: Vector3
		if b.trail.size() < 2 or sleep > 0.0:
			var a := b.face + i * 0.55
			var rr := 0.9 + i * 0.09
			p = b.position + Vector3(sin(a) * rr, 0.25 + 0.04 * i, cos(a) * rr)
		else:
			p = b.trail_at(0.62 * (i + 1))
			p.y = b.position.y + 0.3 + hover * (0.95 + sin(time * 2.2 - i * 0.45) * 0.3 - i * 0.03)
		var tw := 1.0 - exp(-14.0 * delta)
		s.global_position = s.global_position.lerp(p, tw) if s.global_position.length() > 0.01 else p
		var ahead: Vector3 = segs[i - 1].global_position if i > 0 else b.position + Vector3(0, head.position.y, 0)
		if s.global_position.distance_to(ahead) > 0.05:
			s.look_at(ahead, Vector3.UP)
