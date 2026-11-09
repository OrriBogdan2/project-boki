class_name BokiRig
extends Node
## A Boki species drawn from a rigged model (art/kin/<species>/<species>.glb, tools/boki/build_boki.py) instead of
## KinModels' primitives. This node lives beside the model: it picks the body clip from the metas KinPuppet
## already reads, plus "kwork" (chop, mine, carry) and "kact" (eat, pet), and plays the face on top of whatever
## the body does. A match hit ("hit" meta) is a flinch layer on Flex over whatever clip runs; a downed Boki
## (kstate "faint") lies in the sleep clip with its eyes shut.
## A meta "face" (happy, sad, sleepy, angry) overrides the clip's expression. See docs/art/kin/RIGGED_BOKI.md.

const PATH := "res://art/kin/%s/%s.glb"
## Where the eyes and the top of the head sit (m), per species: what KinModels.build returns for the accessories.
## "hip" is the height its legs hold it at, which the limb roll stretches: 0 for a Boki without legs. One that "hover"s
## gets a soft shadow on the ground under it.
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
	"cairnback": {"head": Vector3(0, 0.30, -0.39), "top": 0.56, "carry": Vector3(0, 0.47, 0.23),
		"ear_tip": Vector3(0.24, 0.345, -0.25), "tail_tip": Vector3(0, 0.095, 0.375), "tip_bone": "tail2", "hip": 0.15,
		"marks": {"left flank": Vector3(-0.235, 0.26, 0.05), "right flank": Vector3(0.235, 0.26, 0.05),
			"back": Vector3(0, 0.45, 0.22), "chest": Vector3(0, 0.19, -0.2)}},
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
	"glomwort": {"head": Vector3(0, 0.26, -0.22), "top": 0.42, "carry": Vector3(0, 0.5, 0.08),
		"ear_tip": Vector3(0.085, 0.42, 0.07), "tail_tip": Vector3(0, 0.12, 0.28), "tip_bone": "hips", "hip": 0.0,
		"marks": {"left flank": Vector3(-0.21, 0.13, 0.04), "right flank": Vector3(0.21, 0.13, 0.04),
			"back": Vector3(0, 0.28, 0.14), "chest": Vector3(0, 0.1, -0.2)}},
	"kestrike": {"head": Vector3(0, 0.46, -0.22), "top": 0.59, "carry": Vector3(0, 0.5, 0.16), "hip": 0.11,
		"ear_tip": Vector3(0.147, 0.57, 0.124), "tail_tip": Vector3(0, 0.057, 0.342), "tip_bone": "tail2",
		"marks": {"left flank": Vector3(-0.135, 0.15, 0.03), "right flank": Vector3(0.135, 0.15, 0.03),
			"back": Vector3(0, 0.3, 0.125), "chest": Vector3(0, 0.275, -0.152)}},
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
const FADE := 0.14            # s between body clips
const FACE_RATE := 14.0       # 1/s the expression eases at
const WALK_SPEED := 0.5       # m/s: below this it stands
const RUN_SPEED := 3.2        # m/s: from here it gallops
const RUN_STRIDE := 2.9       # m/s the run clip covers at speed 1 (Vespyx: reach 1.3, pace 1.06)
const WALK_STRIDE := 1.5
const INK_WIDTH := 0.0011     # the outline per metre of camera distance
const INK_FAR_THIN := 0.5
## Softer than the Hunters' painted look (WardenGlb.PAINTED): fur, not armour, and no wash-out at the match zoom.
const COAT_LOOK := {"far_lift": 0.12, "fres": 0.55, "top_light": 0.45, "rim_amount": 0.25}
const EYE_VALUE := 0.86       # iris brightness: the eye is the first thing read on a small face
## Godot's LODs are cut from the rest pose, where the lids lie folded: they would drop the rows that cover the eye.
const FACE_LOD_BIAS := 1000.0
## The ground shadow of a Boki that hovers: its size (m, across and along it) and darkness, and how far off the
## ground it lies (m) so it never fights the ground for depth.
const SHADOW_SIZE := Vector2(0.5, 0.86)
const SHADOW_ALPHA := 0.42
const SHADOW_LIFT := 0.012
const OWN_BODY := ["chop", "mine", "carry", "tend"]
const HIT_WINDOW := 0.15      # s a hit keeps the flinch asked for
const HIT_RATE := 8.0         # 1/s the flinch eases in and out at (in within 0.13 s, never a pop)
const HIT_LEAN := 0.3         # rad it rocks back at full flinch
const HIT_SQUASH := 0.12      # how much shorter and wider it squats at full flinch
const LOOPED := ["idle", "walk", "run", "hop", "sleep", "eat", "pet", "chop", "mine", "carry", "tend"]
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
}
## Match body language (KinPuppet's "pose" meta) that shows on the face.
const POSE_FACE := {"growl": "angry", "guard": "focus", "whine": "sad", "nudge": "sad", "comfort": "happy"}

static var enabled := true

var species := ""
var manual := false            # tools pose it by hand: set_clip, seek and set_face, nothing automatic
var root: Node3D
var flex: Node3D
var model: Node3D
var player: AnimationPlayer
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
var _hit_left := 0.0           # s of the flinch still asked for
var _hit_k := 0.0              # the flinch layer, 0..1
var _hit_was := false
var _blink_t := 2.0
var _blink := 0.0
var _look_t := 1.0
var _look := Vector2.ZERO
var _look_to := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _coat: ShaderMaterial
var _shadow: MeshInstance3D
static var _shadow_mat: StandardMaterial3D

## True when this species has a rigged model.
static func has(kin_id: String) -> bool:
	return enabled and FRAME.has(kin_id) and ResourceLoader.exists(PATH % [kin_id, kin_id])

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
	var model_root := (load(PATH % [kin_id, kin_id]) as PackedScene).instantiate() as Node3D
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
	for n in LOOPED:
		player.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_pos_prev = root.global_position if root.is_inside_tree() else Vector3.ZERO
	_copy_coat()
	set_clip("idle")

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
	for s in _shapes:
		_now[s] = float(_want.get(s, 0.0))
		face.set_blend_shape_value(int(_shapes[s]), float(_now[s]))

func _process(dt: float) -> void:
	if manual or dt <= 0.0:
		return
	var seen := root.is_visible_in_tree()
	player.active = seen
	if not seen:
		return
	_keep_flex()
	_track_speed(dt)
	_pick_clip(dt)
	_face_step(dt)

## KinPuppet squashes and leans Flex for primitive bodies; here the clips do that, so only its width roll stays.
func _keep_flex() -> void:
	var girth := float(root.get_meta("girth", 1.0))
	var squat := _hit_k * HIT_SQUASH
	flex.rotation = Vector3(_hit_k * HIT_LEAN, 0.0, 0.0)
	flex.scale = Vector3(girth * (1.0 + squat * 0.5), 1.0 - squat, lerpf(1.0, girth, 0.5) * (1.0 + squat * 0.5))
	flex.position = Vector3(0, _flex_y, 0)
	var body := flex.get_parent() as Node3D
	if clip in OWN_BODY:
		body.rotation = Vector3.ZERO          # home's work poses swing Body: here the clip does the swinging
	if clip == "carry":
		var held := root.get_node_or_null("Held") as Node3D
		if held:
			held.position = FRAME[species]["carry"]
	model.position.y = -body.position.y if clip == "hop" else 0.0       # the clip does the hopping, not home
	if _shadow:
		_shadow.global_position.y = root.global_position.y + SHADOW_LIFT
	var cam := get_viewport().get_camera_3d() as CamRig
	if cam:
		model.global_basis = cam.char_lean() * flex.global_basis      # toward the camera, like the Hunters: faces read

func _track_speed(dt: float) -> void:
	var gp := root.global_position
	var v := (gp - _pos_prev).length() / dt
	_pos_prev = gp
	_speed = lerpf(_speed, v, 1.0 - exp(-10.0 * dt))

func _pick_clip(dt: float) -> void:
	var p: int = root.get_meta("pulse", 0)
	if p != _pulse:
		_pulse = p
		_start_shot("ability")
	if String(root.get_meta("kstate", "")) == "attack":
		_start_shot("attack")
	_shot_left -= dt
	var hit: bool = root.get_meta("hit", false)
	if hit and not _hit_was:
		_hit_left = HIT_WINDOW
	_hit_was = hit
	_hit_left -= dt
	_hit_k = move_toward(_hit_k, 1.0 if _hit_left > 0.0 else 0.0, HIT_RATE * dt)
	var want := _state_clip()
	set_clip(want)
	player.speed_scale = 1.0
	if want == "run":
		player.speed_scale = clampf(_speed / RUN_STRIDE, 0.7, 1.6)
	elif want == "walk" or want == "carry":
		player.speed_scale = clampf(_speed / WALK_STRIDE, 0.6, 1.6)

func _start_shot(which: String) -> void:
	_shot = which
	_shot_left = player.get_animation(which).length

func _state_clip() -> String:
	if String(root.get_meta("kstate", "")) in ["sleep", "faint"]:
		return "sleep"
	var work := String(root.get_meta("kwork", ""))
	if work != "":
		return work
	var act := String(root.get_meta("kact", ""))
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
	if String(root.get_meta("kstate", "")) == "faint":
		return "asleep"
	if _hit_k > 0.3:
		return "sad"
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
		var w := lerpf(float(_now[s]), goal, k if s != "blink" else 1.0)
		_now[s] = w
		face.set_blend_shape_value(int(_shapes[s]), w)
	_look_t -= dt
	if _look_t <= 0.0:
		_look_t = _rng.randf_range(1.2, 3.8)
		_look_to = Vector2(_rng.randf_range(-0.09, 0.09), _rng.randf_range(-0.05, 0.05))
	_look = _look.lerp(_look_to, 1.0 - exp(-12.0 * dt))
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
	for k in COAT_LOOK:
		m.set_shader_parameter(k, COAT_LOOK[k])
	m.set_shader_parameter("rim_color", (c["body"] as ShaderMaterial).get_shader_parameter("rim_color"))
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
