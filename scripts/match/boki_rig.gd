class_name BokiRig
extends Node
## A Boki species drawn from a rigged model (art/kin/<species>/<species>.glb, tools/boki/build_boki.py) instead of
## KinModels' primitives. This node lives beside the model: it picks the body clip from the metas KinPuppet
## already reads, plus "kwork" (chop, mine, carry), "kact" (eat, pet, hop while it leaps or is thrown), "kburst"
## (a factor on the gait's cadence) and a flier's "aloft" and "lift" (BokiFly: hover or glide up there, a flare
## coming down), and plays the face on top of whatever the body does.
## A meta "face" (happy, sad, sleepy, angry) overrides the clip's expression. See docs/art/kin/RIGGED_BOKI.md.

const PATH := "res://art/kin/%s/%s.glb"
## Where the eyes and the top of the head sit (m), per species: what KinModels.build returns for the accessories.
## "hip" is the height its legs hold it at, which the limb roll stretches: 0 for a Boki without legs. One that "hover"s
## gets a soft shadow on the ground under it. "coat" overrides COAT_LOOK (a matte skin: less fresnel, rim and top
## light, no sheen).
const FRAME := {
	"cindle": {"head": Vector3(0, 0.45, -0.34), "top": 0.72, "carry": Vector3(0, 0.3, -0.34),
		"ear_tip": Vector3(0.218, 0.838, -0.081), "tail_tip": Vector3(0, 0.77, 0.10), "tip_bone": "tail7", "hip": 0.22,
		"marks": {"left flank": Vector3(-0.115, 0.25, 0.09), "right flank": Vector3(0.115, 0.25, 0.09),
			"back": Vector3(0, 0.335, 0.10), "chest": Vector3(0, 0.235, -0.165)}},
	"puddlet": {"head": Vector3(0, 0.3, -0.36), "top": 0.45, "carry": Vector3(0, 0.42, 0.1),
		"ear_tip": Vector3(0.36, 0.56, -0.13), "tail_tip": Vector3(0, 0.34, 0.86), "tip_bone": "tail5", "hip": 0.14,
		"marks": {"left flank": Vector3(-0.12, 0.2, 0.1), "right flank": Vector3(0.12, 0.2, 0.1),
			"back": Vector3(0, 0.3, 0.1), "chest": Vector3(0, 0.15, -0.14)}},
	"burrlet": {"head": Vector3(0, 0.28, -0.33), "top": 0.42, "carry": Vector3(0, 0.56, 0.05),
		"ear_tip": Vector3(0.16, 0.43, -0.14), "tail_tip": Vector3(0, 0.34, 0.55), "tip_bone": "tail2", "hip": 0.11,
		"marks": {"left flank": Vector3(-0.225, 0.2, 0.1), "right flank": Vector3(0.225, 0.2, 0.1),
			"back": Vector3(0, 0.5, 0.1), "chest": Vector3(0, 0.16, -0.2)}},
	"glintmole": {"head": Vector3(0, 0.3, -0.33), "top": 0.45, "carry": Vector3(0, 0.64, 0.05),
		"ear_tip": Vector3(0.15, 0.41, -0.15), "tail_tip": Vector3(0, 0.19, 0.43), "tip_bone": "tail2", "hip": 0.11,
		"marks": {"left flank": Vector3(-0.25, 0.22, 0.1), "right flank": Vector3(0.25, 0.22, 0.1),
			"back": Vector3(0, 0.4, 0.26), "chest": Vector3(0, 0.17, -0.22)}},
	"rimeshrew": {"head": Vector3(0, 0.29, -0.32), "top": 0.43, "carry": Vector3(0, 0.5, 0.05),
		"ear_tip": Vector3(0.11, 0.43, -0.16), "tail_tip": Vector3(0, 0.345, 0.59), "tip_bone": "tail5", "hip": 0.13,
		"marks": {"left flank": Vector3(-0.145, 0.22, 0.08), "right flank": Vector3(0.145, 0.22, 0.08),
			"back": Vector3(0, 0.33, 0.12), "chest": Vector3(0, 0.17, -0.16)}},
	"zephyrak": {"head": Vector3(0, 0.36, -0.4), "top": 0.5, "carry": Vector3(0, 0.36, 0.06),
		"ear_tip": Vector3(0.261, 0.414, -0.113), "tail_tip": Vector3(0, 0.225, 0.369), "tip_bone": "tail6", "hip": 0.0,
		"hover": true,
		"marks": {"left flank": Vector3(-0.078, 0.158, 0.054), "right flank": Vector3(0.078, 0.158, 0.054),
			"back": Vector3(0, 0.244, 0.054), "chest": Vector3(0, 0.16, -0.08)}},
	"pebbit": {"head": Vector3(0, 0.295, -0.41), "top": 0.52, "carry": Vector3(0, 0.54, 0.05),
		"ear_tip": Vector3(0.125, 0.45, -0.28), "tail_tip": Vector3(0, 0.057, 0.48), "tip_bone": "tail4", "hip": 0.15,
		"marks": {"left flank": Vector3(-0.245, 0.28, 0.03), "right flank": Vector3(0.245, 0.28, 0.03),
			"back": Vector3(0, 0.49, 0.05), "chest": Vector3(0, 0.18, -0.21)}},
	"cairnback": {"head": Vector3(0, 0.234, -0.244), "top": 0.72, "carry": Vector3(0, 0.73, 0.05),
		"ear_tip": Vector3(0.221, 0.257, -0.21), "tail_tip": Vector3(0, 0.091, 0.28), "tip_bone": "tail2", "hip": 0.146,
		"marks": {"left flank": Vector3(-0.216, 0.221, -0.041), "right flank": Vector3(0.216, 0.221, -0.041),
			"back": Vector3(0, 0.483, 0.095), "chest": Vector3(0, 0.182, -0.191)}},
	"wisplet": {"head": Vector3(0, 0.44, -0.24), "top": 0.64, "carry": Vector3(0, 0.68, -0.02), "hip": 0.14,
		"ear_tip": Vector3(0.204, 0.665, -0.038), "tail_tip": Vector3(0, 0.114, 0.257), "tip_bone": "tail1",
		"marks": {"left flank": Vector3(-0.18, 0.22, 0.03), "right flank": Vector3(0.18, 0.22, 0.03),
			"back": Vector3(0, 0.3, 0.18), "chest": Vector3(0, 0.25, -0.17)}},
	"gloamshell": {"head": Vector3(0, 0.33, -0.35), "top": 0.6, "carry": Vector3(0, 0.56, 0.1),
		"ear_tip": Vector3(0.085, 0.56, -0.29), "tail_tip": Vector3(0, 0.04, 0.42), "tip_bone": "tail2", "hip": 0.0,
		"marks": {"left flank": Vector3(-0.15, 0.09, -0.05), "right flank": Vector3(0.15, 0.09, -0.05),
			"back": Vector3(0, 0.16, 0.26), "chest": Vector3(0, 0.2, -0.3)}},
	"selenfin": {"head": Vector3(0, 0.5, -0.27), "top": 0.66, "carry": Vector3(0, 0.74, 0.04),
		"ear_tip": Vector3(0.19, 0.36, -0.03), "tail_tip": Vector3(0, 0.5, 0.43), "tip_bone": "tail3", "hip": 0.0,
		"hover": true,
		"marks": {"left flank": Vector3(-0.09, 0.42, 0.06), "right flank": Vector3(0.09, 0.42, 0.06),
			"back": Vector3(0, 0.57, 0.04), "chest": Vector3(0, 0.33, -0.12)}},
	"zapple": {"head": Vector3(0, 0.43, -0.32), "top": 0.6, "carry": Vector3(0, 0.42, 0.06),
		"ear_tip": Vector3(0.135, 0.86, -0.087), "tail_tip": Vector3(0, 0.285, 0.295), "tip_bone": "tail2", "hip": 0.2,
		"marks": {"left flank": Vector3(-0.165, 0.19, 0.07), "right flank": Vector3(0.165, 0.19, 0.07),
			"back": Vector3(0, 0.32, 0.06), "chest": Vector3(0, 0.2, -0.16)}},
	"hivara": {"head": Vector3(0, 0.43, -0.34), "top": 0.6, "carry": Vector3(0, 0.27, -0.3),
		"ear_tip": Vector3(0.16, 0.72, -0.3), "tail_tip": Vector3(0, 0.21, 0.4), "tip_bone": "tail2", "hip": 0.17,
		"marks": {"left flank": Vector3(-0.145, 0.26, 0.15), "right flank": Vector3(0.145, 0.26, 0.15),
			"back": Vector3(0, 0.39, 0.16), "chest": Vector3(0, 0.24, -0.14)}},
	"caecilith": {"head": Vector3(0, 0.465, -0.263), "top": 0.555, "carry": Vector3(0, 0.17, 0.09),
		"ear_tip": Vector3(0.059, 0.535, -0.13), "tail_tip": Vector3(0, 0.027, 0.234), "tip_bone": "tail6", "hip": 0.0,
		"coat": {"fres": 0.15, "rim_amount": 0.1, "top_light": 0.1, "sheen": 0.0},
		"marks": {"left flank": Vector3(-0.09, 0.225, -0.126), "right flank": Vector3(0.09, 0.225, -0.126),
			"back": Vector3(0, 0.27, -0.03), "chest": Vector3(0, 0.225, -0.22)}},
	"gibbelle": {"head": Vector3(0, 0.37, -0.15), "top": 0.52, "carry": Vector3(0, 0.6, 0.03),
		"ear_tip": Vector3(0.155, 0.365, -0.05), "tail_tip": Vector3(0, 0.1, 0.17), "tip_bone": "hips", "hip": 0.0,
		"marks": {"left flank": Vector3(-0.16, 0.15, 0.02), "right flank": Vector3(0.16, 0.15, 0.02),
			"back": Vector3(0, 0.25, 0.16), "chest": Vector3(0, 0.24, -0.12)}},
	"glomwort": {"head": Vector3(0, 0.26, -0.22), "top": 0.42, "carry": Vector3(0, 0.5, 0.08),
		"ear_tip": Vector3(0.085, 0.42, 0.07), "tail_tip": Vector3(0, 0.12, 0.28), "tip_bone": "hips", "hip": 0.0,
		"marks": {"left flank": Vector3(-0.21, 0.13, 0.04), "right flank": Vector3(0.21, 0.13, 0.04),
			"back": Vector3(0, 0.28, 0.14), "chest": Vector3(0, 0.1, -0.2)}},
	"kestrike": {"head": Vector3(0, 0.4, -0.246), "top": 0.5, "carry": Vector3(0, 0.435, 0.07), "hip": 0.084,
		"ear_tip": Vector3(0.09, 0.47, -0.04), "tail_tip": Vector3(0, 0.07, 0.24), "tip_bone": "tail2",
		"marks": {"left flank": Vector3(-0.174, 0.151, -0.083), "right flank": Vector3(0.174, 0.151, -0.083),
			"back": Vector3(0, 0.253, 0.025), "chest": Vector3(0, 0.238, -0.197)}},
	"kindlewren": {"head": Vector3(0, 0.4, -0.22), "top": 0.6, "carry": Vector3(0, 0.64, -0.04), "hip": 0.12,
		"ear_tip": Vector3(0.027, 0.616, -0.067), "tail_tip": Vector3(0, 0.49, 0.255), "tip_bone": "tail2",
		"marks": {"left flank": Vector3(-0.165, 0.15, -0.02), "right flank": Vector3(0.165, 0.15, -0.02),
			"back": Vector3(0, 0.33, 0.1), "chest": Vector3(0, 0.22, -0.175)}},
	"lodestick": {"head": Vector3(0, 0.35, -0.45), "top": 0.47, "carry": Vector3(0, 0.33, 0.05),
		"ear_tip": Vector3(0.19, 0.608, -0.437), "tail_tip": Vector3(0, 0.276, 0.523), "tip_bone": "tail3", "hip": 0.18,
		"marks": {"left flank": Vector3(-0.048, 0.19, 0.076), "right flank": Vector3(0.048, 0.19, 0.076),
			"back": Vector3(0, 0.24, 0.076), "chest": Vector3(0, 0.16, -0.1)}},
	"marchleaf": {"head": Vector3(0, 0.35, -0.3), "top": 0.47, "carry": Vector3(0, 0.42, 0.18),
		"ear_tip": Vector3(0.19, 0.61, -0.34), "tail_tip": Vector3(0, 0.29, 0.32), "tip_bone": "tail1", "hip": 0.15,
		"marks": {"left flank": Vector3(-0.12, 0.24, 0.19), "right flank": Vector3(0.12, 0.24, 0.19),
			"back": Vector3(0, 0.35, 0.18), "chest": Vector3(0, 0.19, -0.1)}},
	"mossgrade": {"head": Vector3(0, 0.29, -0.33), "top": 0.43, "carry": Vector3(0, 0.53, 0.05),
		"ear_tip": Vector3(0.125, 0.42, -0.19), "tail_tip": Vector3(0, 0.22, 0.3), "tip_bone": "hips", "hip": 0.1,
		"marks": {"left flank": Vector3(-0.205, 0.24, 0.05), "right flank": Vector3(0.205, 0.24, 0.05),
			"back": Vector3(0, 0.37, 0.22), "chest": Vector3(0, 0.15, -0.22)}},
	"nettlynx": {"head": Vector3(0, 0.32, -0.32), "top": 0.46, "carry": Vector3(0, 0.47, 0.05),
		"ear_tip": Vector3(0.175, 0.62, -0.143), "tail_tip": Vector3(0, 0.363, 0.322), "tip_bone": "tail3", "hip": 0.15,
		"marks": {"left flank": Vector3(-0.14, 0.22, 0.055), "right flank": Vector3(0.14, 0.22, 0.055),
			"back": Vector3(0, 0.34, 0.1), "chest": Vector3(0, 0.2, -0.17)}},
	"thrumbird": {"head": Vector3(0, 0.84, -0.2), "top": 0.96, "carry": Vector3(0, 0.24, -0.03),
		"ear_tip": Vector3(0.034, 0.6, 0.133), "tail_tip": Vector3(0, 0.133, 0.261), "tip_bone": "tail1", "hip": 0.12,
		"hover": true,
		"marks": {"left flank": Vector3(-0.105, 0.2, 0.05), "right flank": Vector3(0.105, 0.2, 0.05),
			"back": Vector3(0, 0.3, 0.05), "chest": Vector3(0, 0.26, -0.14)}},
}
## m/s a foot on the ground moves back at speed 1 and model scale 1: [walk, run]. Measured by --boki-anim-audit.
const STRIDE := {
	"cindle": [0.80, 1.60],
	"puddlet": [0.58, 1.15],
	"burrlet": [0.50, 1.02],
	"glintmole": [0.49, 1.04],
	"rimeshrew": [0.56, 1.09],
	"zephyrak": [1.50, 2.90],
	"pebbit": [0.48, 1.10],
	"cairnback": [0.29, 0.90],
	"wisplet": [0.45, 0.42],
	"gloamshell": [1.50, 2.90],
	"selenfin": [1.50, 2.90],
	"zapple": [0.75, 1.74],
	"hivara": [0.63, 1.42],
	"caecilith": [0.14, 0.35],
	"glomwort": [1.50, 2.90],
	"kestrike": [0.30, 0.42],
	"kindlewren": [0.39, 0.50],
	"lodestick": [0.22, 0.62],
	"marchleaf": [0.51, 2.02],
	"mossgrade": [0.12, 0.74],
	"nettlynx": [0.54, 1.07],
	"thrumbird": [1.50, 2.90],
}
## s into the attack clip at speed 1 where the bite or pincers connect, per species (its forms wear the same clip).
## The clip plays at CONTACT / Kin.STRIKE_WINDUP so the contact lands on the hit. Measured by --boki-anim-audit.
const CONTACT := {"cindle": 0.333, "puddlet": 0.367, "burrlet": 0.367}
const FADE := 0.14            # s between body clips
## s between idle, walk and run for a Boki whose gaits hold it at a different stance: the hoverer tips into flight
## and back over a few wingbeats instead of snapping (the idle-to-walk pop, --boki-anim-audit).
const GAIT_FADE := {"thrumbird": 0.45}
const GAITS := ["idle", "walk", "run"]
const FACE_RATE := 14.0       # 1/s the expression eases at
const FACE_SNAP := 0.002      # blend weight: this close to its goal, a face shape stops easing (and being written)
const LOOK_SNAP := 0.0005     # eye UV offset: this close, the eyes stop drifting and their uniform stops being set
const WALK_SPEED := 0.5       # m/s: below this it stands
const RUN_SPEED := 2.2        # m/s: from here it gallops (a walk clip sped up past MAX_CADENCE blurs)
const MAX_CADENCE := 6.0      # step cycles/s a gait may be sped up to: small animals gallop at 6-8, past it blurs
const INK_WIDTH := 0.0011     # the outline per metre of camera distance
const INK_FAR_THIN := 0.5
## Softer than the Hunters' painted look (WardenGlb.PAINTED): fur, not armour, and no wash-out at the match zoom.
const COAT_LOOK := {"far_lift": 0.12, "fres": 0.55, "top_light": 0.45, "rim_amount": 0.25}
const EYE_VALUE := 0.86       # iris brightness: the eye is the first thing read on a small face
## Godot's LODs are cut from the rest pose, where the lids lie folded: they would drop the rows that cover the eye.
const FACE_LOD_BIAS := 1000.0
## The ground shadow of a Boki that hovers or has flown: its size (m, across and along it) and darkness, and how
## far off the ground it lies (m) so it never fights the ground for depth.
const SHADOW_SIZE := Vector2(0.5, 0.86)
const SHADOW_ALPHA := 0.42
const SHADOW_LIFT := 0.012
const OWN_BODY := ["chop", "mine", "carry", "tend", "settle", "nap", "wake", "munch", "nudge", "climb", "splash",
	"rush", "brace", "dodge", "stonehop", "spin", "strut", "pose", "bow", "hover", "glide", "flare"]
## Clips that carry the body themselves: home's walking bounce of Body is taken back out under them.
const OWN_HEIGHT := ["hop", "hover", "glide", "flare"]
const LOOPED := ["idle", "walk", "run", "hop", "sleep", "eat", "pet", "chop", "mine", "carry", "tend"]
## The strut takes steps this much quicker than a walk at the same ground speed (a high, proud step).
const STRUT_CADENCE := 1.25
## Home's job kinds that have their own clip.
const WORK_KINDS := {"chop": "chop", "ore": "mine", "carry": "carry"}
## Blend shapes each expression pushes.
const FACES := {
	"neutral": {},
	"happy": {"happy": 1.0, "m_smile": 1.0},
	"sad": {"sad": 1.0, "m_frown": 1.0},
	"sleepy": {"sleepy": 1.0, "m_o": 0.3},
	"angry": {"angry": 1.0, "m_snarl": 1.0},
	"focus": {"angry": 0.45},
	"cheer": {"m_smile": 0.8},
	"bliss": {"closed": 1.0, "m_smile": 0.55},
	"asleep": {"closed": 1.0, "m_o": 0.22},
	"chew": {"m_chomp": 1.0},
}
## The clip's own expression, or a list of [from, expression] beats over its length (0..1).
const CLIP_FACE := {
	"run": "cheer", "hop": "happy", "attack": "angry", "ability": "angry", "sleep": "asleep", "pet": "bliss",
	"chop": "focus", "mine": "focus", "carry": "cheer", "tend": "focus",
	"eat": [[0.0, "chew"], [0.16, "cheer"], [0.33, "chew"], [0.5, "cheer"], [0.66, "chew"], [0.83, "cheer"]],
	"settle": [[0.0, "sleepy"], [0.6, "asleep"]], "nap": "asleep",
	"wake": [[0.0, "asleep"], [0.2, "sleepy"], [0.7, "cheer"]],
	"munch": "chew", "nudge": "cheer", "climb": "focus", "splash": "happy",
	"rush": "angry", "brace": "focus", "dodge": "cheer", "stonehop": "happy", "spin": "happy",
	"strut": "cheer", "pose": "cheer", "bow": "cheer",
	"crouch": "focus", "burst": "cheer", "sulk": "sad",
	"glide": "cheer", "flare": "focus",
}
## Match body language (KinPuppet's "pose" meta) that shows on the face.
const POSE_FACE := {"growl": "angry", "guard": "focus", "whine": "sad", "nudge": "sad", "comfort": "happy"}

static var enabled := true
## How deep a body's baked normal map cuts (a Meshy body has one, docs/art/kin/MESHY_BOKI_RECIPE.md); 0 leaves it out.
static var normal_k := 1.0

var species := ""
var manual := false            # tools pose it by hand: set_clip, seek and set_face, nothing automatic
var root: Node3D
var flex: Node3D
var model: Node3D
var player: AnimationPlayer
var _skel: Skeleton3D
var pace: RigPace              # how often the seen rig (clip, skeleton, face) steps
var face: MeshInstance3D
var eye_mat: ShaderMaterial
var clip := ""
var _shapes := {}              # blend shape name -> index
var _now := {}                 # blend shape name -> weight
var _want := {}
var _face_name := "neutral"
var _flex_y := 0.0
var _pos_prev := Vector3.ZERO
var _speed := 0.0
var _pulse := 0
var _shot_left := 0.0
var _shot := ""
var _shot_rate := 1.0          # the speed the shot plays at
var _attacking := false
var _asleep := false
var _aloft := false             # a flier in the air (BokiFly's "aloft" meta)
var _blink_t := 2.0
var _blink := 0.0
var _look_t := 1.0
var _look := Vector2.ZERO
var _look_to := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _coat: ShaderMaterial
var _shadow: MeshInstance3D
var _flinch := KinFlinch.new()
static var _shadow_mat: StandardMaterial3D

## True when this species has a rigged model.
static func has(kin_id: String) -> bool:
	return enabled and FRAME.has(kin_id) and ResourceLoader.exists(PATH % [kin_id, kin_id])

## Starts reading every common species' model on a loader thread (a match's start: bots' and wild Boki), so the
## builds take them ready instead of each species' first build reading its .glb on the main thread (~60 ms).
static func fetch_common() -> void:
	if not BackgroundWork.can_read_ahead():
		return
	for sp in Data.common_kin():
		var p := PATH % [sp, sp]
		if has(String(sp)) and not _scenes.has(p) \
				and ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			BackgroundWork.request(p)

static var _scenes := {}       # path -> PackedScene, kept so a species' next build doesn't read it again
static func _scene(kin_id: String) -> PackedScene:
	var p := PATH % [kin_id, kin_id]
	if not _scenes.has(p):
		var asked := ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		_scenes[p] = BackgroundWork.take(p) if asked else load(p)
	return _scenes[p] as PackedScene

## The work clip for a farm Boki (home's kin dictionary, its "job"), or "" when it isn't doing one.
static func work_clip(k: Dictionary) -> String:
	if not k.has("job"):
		return ""
	var job: Dictionary = k["job"]
	if String(job["phase"]) == "to":
		return "carry"
	if String(job["phase"]) != "work":
		return ""
	return String(WORK_KINDS.get(String(job["kind"]), "tend"))

## Adds the model and its driver under `flex`; `c` is KinModels' material set. Returns the head frame, as
## KinModels.build.
static func build(kin_id: String, flex_node: Node3D, c: Dictionary, mats: Array) -> Dictionary:
	var model_root := _scene(kin_id).instantiate() as Node3D
	model_root.name = "Rig"
	flex_node.add_child(model_root)
	var rig := BokiRig.new()
	rig.name = "BokiRig"
	rig.species = kin_id
	rig.model = model_root
	rig._dress(c, mats)
	if FRAME[kin_id].get("hover", false):
		rig._shadow = _ground_shadow(flex_node)
	flex_node.add_child(rig)
	return FRAME[kin_id]

func _ready() -> void:
	process_priority = 10          # after KinPuppet: this rig poses Flex itself
	flex = get_parent() as Node3D
	root = flex.get_parent().get_parent() as Node3D
	_flex_y = flex.position.y
	_rng.seed = hash(get_instance_id())
	_blink_t = _rng.randf_range(0.8, 3.5)
	player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_skel = skeleton()
	# BokiDna's modifier would otherwise re-pose (and re-skin) the rig every frame, stepped or not
	_skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	pace = RigPace.new(get_instance_id())
	BokiHomeClips.install(species, player, _skel)
	for n in LOOPED:
		player.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_pos_prev = root.global_position if root.is_inside_tree() else Vector3.ZERO
	_flinch.plan = String(KinPuppet.BODY.get(species, "blob"))
	_copy_coat()
	set_clip("idle")

## Moves the rig on by `dt`: the clip, then the skeleton's modifiers (BokiDna) over it. The only way it moves.
func advance(dt: float) -> void:
	player.advance(dt)
	_skel.advance(dt)

## The model's skeleton.
func skeleton() -> Skeleton3D:
	return model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

## The expression right now: one of FACES.
func set_face(which: String) -> void:
	_face_name = which
	_want = FACES.get(which, {})

## Plays a body clip by name, crossfading from the last one.
func set_clip(which: String, fade := FADE) -> void:
	if which == clip:
		return
	clip = which
	player.play(which, fade)

## Tools: holds the body at `at` (s) of the current clip and the face fully on its expression.
func seek(at: float) -> void:
	player.seek(at, true)
	_skel.advance(0.0)
	for s in _shapes:
		_now[s] = float(_want.get(s, 0.0))
		face.set_blend_shape_value(int(_shapes[s]), float(_now[s]))

func _process(dt: float) -> void:
	if dt <= 0.0:
		return
	if manual:
		advance(dt)
		return
	if not root.is_visible_in_tree():
		return
	_flinch.update(root, dt)
	_keep_flex()
	_track_speed(dt)
	_pick_clip(dt)
	var t := pace.step(dt)
	if t > 0.0:
		_face_step(t)
		advance(t)

## KinPuppet squashes and leans Flex for primitive bodies; here the clips do that, so only its width roll and
## the jolt of a hit (KinFlinch) stay.
func _keep_flex() -> void:
	var girth := float(root.get_meta("girth", 1.0))
	flex.rotation = _flinch.rot
	flex.scale = Vector3(girth * _flinch.wide, _flinch.tall, lerpf(1.0, girth, 0.5) * _flinch.wide)
	flex.position = Vector3(0, _flex_y, 0) + _flinch.shove
	var body := flex.get_parent() as Node3D
	if clip in OWN_BODY:
		body.rotation = Vector3.ZERO          # home's work poses swing Body: here the clip does the swinging
	if clip == "carry":
		var held := root.get_node_or_null("Held") as Node3D
		if held:
			held.position = FRAME[species]["carry"]
	model.position.y = -body.position.y if clip in OWN_HEIGHT else 0.0       # the clip does the hopping, not home
	var lift := float(root.get_meta("lift", 0.0))
	if lift > 0.0 and _shadow == null:
		_shadow = _ground_shadow(flex)           # a flier's first time up: from now on its shadow marks the ground
	if _shadow:
		_shadow.global_position.y = root.global_position.y - lift + SHADOW_LIFT
	var cam := get_viewport().get_camera_3d() as CamRig
	if cam:
		model.global_basis = cam.char_lean() * flex.global_basis      # toward the camera, like the Hunters: faces read

func _track_speed(dt: float) -> void:
	var gp := root.global_position
	var v := Vector2(gp.x - _pos_prev.x, gp.z - _pos_prev.z).length() / dt      # rising or sinking is no stride
	_pos_prev = gp
	_speed = lerpf(_speed, v, 1.0 - exp(-10.0 * dt))

func _pick_clip(dt: float) -> void:
	var p: int = root.get_meta("pulse", 0)
	if p != _pulse:
		_pulse = p
		_start_shot("ability")
	var attacking := String(root.get_meta("kstate", "")) == "attack"
	if attacking and not _attacking:
		_start_shot("attack", float(CONTACT.get(species, Kin.STRIKE_WINDUP)) / Kin.STRIKE_WINDUP)
	_attacking = attacking
	_shot_left -= dt
	var asleep := String(root.get_meta("kstate", "")) == "sleep"
	if asleep != _asleep:
		_asleep = asleep
		if _speed < WALK_SPEED:
			_start_shot("settle" if asleep else "wake")
	var aloft := bool(root.get_meta("aloft", false))
	if aloft != _aloft:
		_aloft = aloft
		if not aloft:
			_start_shot("flare")
		elif _shot == "flare":
			_shot_left = 0.0          # up again before the flare is done
	var want := _state_clip()
	set_clip(want, gait_fade() if want in GAITS and clip in GAITS else FADE)
	player.speed_scale = _shot_rate if want == _shot and _shot_left > 0.0 else 1.0
	if want not in ["run", "walk", "carry", "strut"]:
		return
	# the world scale: a size roll's bigger Boki takes longer steps
	var stride: float = ((STRIDE.get(species, [1.5, 2.9]) as Array)[1 if want == "run" else 0]
			* model.global_basis.z.length())
	var quick := STRUT_CADENCE if want == "strut" else 1.0
	var burst := float(root.get_meta("kburst", 1.0))      # the Relay Cup's launch: the legs go faster for a moment
	player.speed_scale = clampf(quick * _speed / stride * burst, 0.6, MAX_CADENCE * player.get_animation(want).length)

## s the rig takes to hand one gait over to another.
func gait_fade() -> float:
	return GAIT_FADE.get(species, FADE)

## Plays a one-off clip, at `rate` times its speed.
func _start_shot(which: String, rate := 1.0) -> void:
	_shot = which
	_shot_rate = rate
	_shot_left = player.get_animation(which).length / rate

func _state_clip() -> String:
	if _aloft:
		return "glide" if _speed >= WALK_SPEED else "hover"
	if _shot == "flare" and _shot_left > 0.0:
		return _shot          # it touches down before it does what it came down for
	if String(root.get_meta("kstate", "")) == "sleep":
		return _shot if _shot == "settle" and _shot_left > 0.0 else "nap"
	var work := String(root.get_meta("kwork", ""))
	if work != "":
		return work
	var act := String(root.get_meta("kact", ""))
	if act == "hop" and not player.has_animation("hop"):
		return "run"          # a Boki in the air (Kin.render) without a hop clip runs through it
	if act != "":
		return act
	if _shot_left > 0.0:
		return _shot
	if root.get_meta("happy", false):
		return "hop"
	if _speed >= RUN_SPEED:
		return "run"
	return "walk" if _speed >= WALK_SPEED else "idle"

func _clip_face() -> String:
	var over := String(root.get_meta("face", ""))
	if over != "":
		return over
	if root.get_meta("dazed", false):
		return "sad"
	var cf: Variant = CLIP_FACE.get(clip, "")
	if cf is Array:
		var length := player.current_animation_length
		var k := fposmod(player.current_animation_position, length) / length
		var best := "neutral"
		for beat in cf:
			if float(beat[0]) <= k:
				best = String(beat[1])
		return best
	if String(cf) != "":
		return String(cf)
	return String(POSE_FACE.get(String(root.get_meta("pose", "")), "neutral"))

func _face_step(dt: float) -> void:
	set_face(_clip_face())
	_blink_t -= dt
	if _blink_t <= 0.0:
		_blink_t = _rng.randf_range(1.8, 4.6)
		_blink = 1.0
	_blink = maxf(0.0, _blink - dt * 7.0)
	var k := 1.0 - exp(-FACE_RATE * dt)
	var shut_already := _want.has("closed") or _want.has("happy")
	for s in _shapes:
		var goal := float(_want.get(s, 0.0))
		if s == "blink" and not shut_already:
			goal = sin(_blink * PI)
		var was := float(_now[s])
		var w := lerpf(was, goal, k if s != "blink" else 1.0)
		if absf(w - goal) < FACE_SNAP:
			w = goal
		if w != was:       # an unchanged weight isn't written: the face mesh is only re-deformed while it moves
			_now[s] = w
			face.set_blend_shape_value(int(_shapes[s]), w)
	_look_t -= dt
	if _look_t <= 0.0:
		_look_t = _rng.randf_range(1.2, 3.8)
		_look_to = Vector2(_rng.randf_range(-0.09, 0.09), _rng.randf_range(-0.05, 0.05))
	if _look != _look_to:
		_look = _look.lerp(_look_to, 1.0 - exp(-12.0 * dt))
		if _look.distance_to(_look_to) < LOOK_SNAP:
			_look = _look_to
		eye_mat.set_shader_parameter("look", _look)

## Wears the game's materials: the painted atlas under the Boki toon light, the glow and the eye in its own colours.
func _dress(c: Dictionary, mats: Array) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if inst.get_blend_shape_count() > 0 or inst.mesh.get_blend_shape_count() > 0:
			face = inst
			inst.lod_bias = FACE_LOD_BIAS
			for i in inst.mesh.get_blend_shape_count():
				var nm := String(inst.mesh.get_blend_shape_name(i))
				_shapes[nm] = i
				_now[nm] = 0.0
		for si in inst.mesh.get_surface_count():
			inst.set_surface_override_material(si, _material_for(inst.mesh.surface_get_material(si), c, mats))

func _material_for(src: Material, c: Dictionary, mats: Array) -> Material:
	var id := String(src.resource_name)
	if id == "boki_glow":
		return c["glow"]
	if id == "boki_eye":
		eye_mat = ShaderMaterial.new()
		eye_mat.shader = preload("res://shaders/boki_eye.gdshader")
		var iris := c["eye"].get_meta("iris", Color("9de23a")) as Color
		eye_mat.set_shader_parameter("iris", Color.from_hsv(iris.h, minf(iris.s * 1.15, 1.0), EYE_VALUE))
		return eye_mat
	if id == "boki_lit":
		return _lit_material(src, c)
	var m := Models.toon(Color.WHITE, false)
	Models.hero_look(m)
	m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("albedo_tex", (src as BaseMaterial3D).albedo_texture)
	for k in WardenGlb.PAINTED:
		m.set_shader_parameter(k, WardenGlb.PAINTED[k])
	var look: Dictionary = COAT_LOOK.merged(FRAME[species].get("coat", {}), true)
	for k in look:
		m.set_shader_parameter(k, look[k])
	m.set_shader_parameter("rim_color", (c["body"] as ShaderMaterial).get_shader_parameter("rim_color"))
	var relief := (src as BaseMaterial3D).normal_texture
	if relief and normal_k > 0.0:
		m.set_shader_parameter("normal_tex", relief)
		m.set_shader_parameter("use_nrm", true)
		m.set_shader_parameter("normal_k", normal_k)
	if id == "boki_coat":
		_coat = m
		m.next_pass = _ink()
	mats.append(m)
	return m

## A painted part that glows: its own colours, shifted with the species' glow (a shimmer's caps).
func _lit_material(src: Material, c: Dictionary) -> Material:
	var m := Models.toon(Color.WHITE, false, 0.55)
	m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("albedo_tex", (src as BaseMaterial3D).albedo_texture)
	var base: Color = Data.KIN[species]["glow"]
	var now := (c["glow"] as ShaderMaterial).get_shader_parameter("albedo") as Color
	m.set_shader_parameter("albedo", _tint(now, base))
	return m

## A soft dark oval on the ground under `flex`: what keeps a floating body reading as standing there.
static func _ground_shadow(flex_node: Node3D) -> MeshInstance3D:
	if _shadow_mat == null:
		var grad := GradientTexture2D.new()
		grad.fill = GradientTexture2D.FILL_RADIAL
		grad.fill_from = Vector2(0.5, 0.5)
		grad.fill_to = Vector2(1.0, 0.5)
		grad.gradient = Gradient.new()
		grad.gradient.set_color(0, Color(0, 0, 0, 1))
		grad.gradient.set_color(1, Color(0, 0, 0, 0))
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.albedo_texture = grad
		_shadow_mat.albedo_color = Color(0, 0, 0, SHADOW_ALPHA)
	var plane := PlaneMesh.new()
	plane.size = SHADOW_SIZE
	var shadow := Models.part(flex_node, plane, _shadow_mat, Vector3(0, SHADOW_LIFT, 0), Vector3.ONE, Vector3.ZERO,
		"GroundShadow")
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shadow

static func _ink() -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = Models.OUTLINE
	ink.set_shader_parameter("width", INK_WIDTH)
	ink.set_shader_parameter("far_thin", INK_FAR_THIN)
	return ink

## Coat marks and the colour shift land on KinModels' body material (Unique.dress, after build): take them on.
func _copy_coat() -> void:
	var mats: Array = root.get_meta("mats", [])
	if mats.is_empty() or _coat == null:
		return
	var body := mats[0] as ShaderMaterial
	var base: Color = Data.KIN[species]["color"]
	var now := body.get_shader_parameter("albedo") as Color
	_coat.set_shader_parameter("albedo", _tint(now, base))
	if body.get_shader_parameter("mark_kind") == null:
		return
	var marks := ShaderMaterial.new()
	marks.shader = preload("res://shaders/boki_marks.gdshader")
	for k in ["mark_kind", "mark_color", "mark_seed", "mark_scale", "mark_amt", "mark_glow"]:
		marks.set_shader_parameter(k, body.get_shader_parameter(k))
	marks.next_pass = _coat.next_pass
	_coat.next_pass = marks

## How far a colour has moved from the species' own (white: not at all), to multiply a painted atlas with.
static func _tint(now: Color, base: Color) -> Color:
	return Color(now.r / maxf(base.r, 0.01), now.g / maxf(base.g, 0.01), now.b / maxf(base.b, 0.01))
