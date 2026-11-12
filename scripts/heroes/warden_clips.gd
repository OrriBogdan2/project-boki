class_name WardenClips
extends RefCounted
## A Hero's hand-keyed clips (ART-1, docs/art/wardens/CLIPS.md): the .glb's animations played through an AnimationTree
## so the moves flow. Which state plays what is data, content/rules/warden_anim/<art>.json; no file: it
## stays on HunterAnim. HunterAnim still runs and stays the source of truth for the state (it hands its state over
## as the model's meta STATE), the kit keeps its timing: a keyed move's clip is seeked to the kit's own kmove_t, so a
## clip can never drift from the hit it shows. States the data lists as "procedural" (ledges, stomps) blend back to the
## retargeted rig, and so does any Hero model played by something that feeds no state (galleries, portraits).
##
## The tree: loco (Blend2: the idle under the rings, a Blend2 of a walk ring and a run ring, each a BlendSpace2D of the
## directions; every weight rides a spring, so a start, stop or ring change never kinks a foot's path) > air (Blend2
## onto a BlendSpace1D of fall and rise, or the glide) > upper (Blend2 filtered to the torso and arms: moves that keep
## the legs running) > full (Blend2: moves that own the body). The action, and the upper-body move, are each two
## seekable channels crossfaded, so one move hands to the next without a pop (item 32).
##
## Data "crouch" (item 143): under air, a crouch layer (idle and a sneak ring) with a one-shot channel for the dip into
## and out of it. The game state's crouch (0..1) only says which way it is going; the layer has its own eased weight.
## A Hero with no "crouch" key stands through a crouch, as the clips have no pose for it.

const DIR := "res://content/rules/warden_anim/"
const DIAGONALS := ["fl", "fr", "bl", "br"]
const STATE := "anim_state"
const DEATH_T := "clip_death_t"   # root meta: s the death clip keeps a knocked-out Hero on screen (0: not at all)
const FADE := 0.1            # s: one clip into the next, and into or out of an action
const FADE_LOCO := 0.16      # s: an action back to the legs
const AIR_FADE := 0.12
const STILL := 0.25          # m/s: below this he is standing
const WEAPON_OUT := "weapon_out"   # root meta: the kit has the skinned weapon out of the hand (Breaker's thrown hammer)
const PHASE := "clip_phase"   # root meta 0..1: a kit's own loop phase; a hold move's loop follows it, not the clock
const HEADING_MIN := 2.0     # m/s: slower than this has no heading to lean into
const HEADING_MAX := 1.4     # rad: the most the root turns off the facing
const LEGS_MAX := 1.75       # rad: the most the legs turn off the aim ("legs_heading")
const HEADING_RATE := 14.0   # 1/s: how fast it turns
const TWIST_HYST := 0.1      # rad: the legs turn round this far past 90 deg off the aim and back this far inside it
const TWIST_MAX := PI / 2.0 + TWIST_HYST   # rad (~96 deg): the most the torso twists off the legs, forwards or back
const WEAPON_K := "weapon_k"  # root meta: the skinned weapon's size over its rest (the whirl)
const OUT_RATE := 10.0       # 1/s: the free-arm pose eases in and out
const CROUCH_IN := 0.12      # s: the layer eases over the body when no dip carries it
const CROUCH_ONE := 0.06     # s: the dip clip eases in and out of the layer
const CROUCH_MOVING := 0.6   # how much of the dip plays over a sneak: the legs keep some of their stride
const CROUCH_RATE_MAX := 2.0 # the sneak clip's fastest rate: a short stride quickens to keep its feet planted
const RUN_FROM := 1.3        # of walk_speed: faster than this shows the run ring (the two rings are never held
const RUN_BACK := 1.2        # half and half: out of step they cancel the feet); slower than RUN_BACK hands back
const BLEND_W := 18.0        # 1/s: the loco and sneak weights' critically damped spring (~0.2 s to a new goal)
const RATE_EASE := 10.0      # 1/s: the loops' playback rate eases to its goal (a step in it steps every foot's speed)
static var _data := {}       # art name -> its parsed file ({} when it has none)

var root: Node3D
var skel: Skeleton3D
var d: Dictionary
var tree: AnimationTree
var lib: AnimationLibrary
var alt_on := false          # this play of a move takes its "alt" clip
var alt_km := ""
var alt_t := 0.0
var cur := ""                # the clip on the live channel
var chan := 0                # which channel is live, 0 or 1
var xf := 0.0                # the crossfade between the channels (0: channel a)
var cur_u := ""              # the clip on the live upper-body channel
var chan_u := 0              # which upper-body channel is live, 0 or 1
var xf_u := 0.0              # the crossfade between the upper-body channels (0: channel ua)
var act_w := 0.0             # how much the action owns the body
var up_w := 0.0              # how much it owns the upper body only
var flinch_w := 0.0          # how much of the hit clip's flinch (its pose less its first frame) rides on the upper body
var air_w := 0.0
var glide_w := 0.0
var proc_w := 1.0            # how much of the procedural rig is shown
var rise_w := 0.0
var on_run := false          # the run ring is showing, not the walk
var loco_rate := 1.0         # the loops' playback rate now
var move_w := 0.0            # how much the rings show over the idle (0..1 of walk_speed)
var move_v := 0.0            # its rate (1/s)
var run_w := 0.0             # how much the run ring shows over the walk ring
var run_v := 0.0
var start_ph: Array = []     # [walk, run] 0..1: where the rings pick up when he moves off from idle (WardenStart)
var starting := false        # moving off: the rings are still fading in over the idle
var dir_pos := Vector2.ZERO  # the rings' blend position: the move off the facing (x his right, y forward)
var dir_v := Vector2.ZERO
var still_t := 0.0
var stance_w := 0.0
var was_air := false
var air_t := 0.0
var land_t := 99.0
var hit_seen := 99.0
var last_emote := ""
var head_turn := 0.0         # rad the root (the legs) is turned toward his heading
var head_v := 0.0            # its rate (rad/s) while the aim twist turns it
var torso_turn := 0.0        # rad the hips (the torso) turn with it: all of it for a "heading" move, none on the aim
var twist_on := false        # "loco.aim_twist": the legs run the way he goes, the torso stays on the aim
var twist_goal := 0.0        # rad the legs turn off the aim this frame (0 when he is not running)
var twist_back := false      # past the twist limit the legs turn round and run backwards
var twist_face := 0.0        # rad: the facing last frame, so the legs can hold their way while the aim swings
var force := {}              # a tool's pick ({clip, t}): skips the state (tools/clip_shots.gd)
var gait: WardenGait         # the stride and arm swing laid over the walk and run (scripts/heroes/warden_gait.gd)
var free_arm: WardenFreeArm  # the arm a move leaves unused hangs loose (scripts/heroes/warden_free_arm.gd)
var out_w := 0.0             # the "weapon_out" data: how far the free-arm pose lies over the clips
var out_pose: Array = []     # [bone index, rotation]: the free arm, sampled once from its clip
var weapon_bi := -1          # "weapon_bone": the bone a thrown weapon hides on
var bone_scales: Array = []  # "bone_scale": [bone index, its size], held over the clips
var crouch_on := false       # which way the state's crouch is going
var crouch_k := 0.0          # the state's crouch last frame
var crouch_w := 0.0          # how much the crouch layer owns the body
var crouch_from := 0.0       # crouch_w when it last turned
var crouch_t := 99.0         # s since it turned
var crouch_clip := ""        # the dip playing ("" none: turned round mid-dip, the layer just eases)
var crouch_seek := 0.0       # s into it
var one_w := 0.0             # how much of the layer the dip owns
var crouch_pos := Vector2.ZERO
var crouch_v := Vector2.ZERO

## The Hero's file, {} when it has none.
static func data(art_name: String) -> Dictionary:
	if not _data.has(art_name):
		var p := DIR + art_name + ".json"
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
		_data[art_name] = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _data[art_name]

## Clips for this model, or null when the .glb brought none.
## A hunter just eliminated whose Hero has a death clip: it stays visible until the clip has played.
static func dying(h: Hunter) -> bool:
	if not h.out or h.model == null or String(h.get_meta("died_why", "")) == "abyss":
		return false
	return h.m.time - float(h.get_meta("died_at", -99.0)) < float(h.model.get_meta(DEATH_T, 0.0))

static func make(model: Node3D, glb: Node3D, sk: Skeleton3D, art_name: String) -> WardenClips:
	var dd := data(art_name)
	var players: Array = glb.find_children("*", "AnimationPlayer", true, false)
	if dd.is_empty() or players.is_empty():
		return null
	var c := WardenClips.new()
	if not c._setup(model, glb, sk, dd, players[0]):
		return null
	return c

func _setup(model: Node3D, glb: Node3D, sk: Skeleton3D, dd: Dictionary, player: AnimationPlayer) -> bool:
	root = model
	skel = sk
	d = dd
	var names := player.get_animation_library_list()
	if names.is_empty():
		return false
	lib = player.get_animation_library(names[0])
	var contract: Array = []
	for b in WardenGlb.BONES:
		if b != "root" and WardenSkeleton.find(sk, b) >= 0:
			contract.append(sk.get_bone_name(WardenSkeleton.find(sk, b)))
	for nm in lib.get_animation_list():
		var a := lib.get_animation(nm)
		a.loop_mode = Animation.LOOP_LINEAR if _is_loop(String(nm)) else Animation.LOOP_NONE
		# (rotations only on the contract bones: their offsets and scale are the player's sliders, Sync._look_pose)
		for i in range(a.get_track_count() - 1, -1, -1):
			var bone_name := String(a.track_get_path(i).get_concatenated_subnames())
			# (data "offset_bones": a bone the clips do move and scale: Motley's hips ride his spring)
			if a.track_get_type(i) != Animation.TYPE_ROTATION_3D and bone_name in contract \
					and not bone_name in d.get("offset_bones", []):
				a.remove_track(i)
	tree = AnimationTree.new()
	tree.name = "Clips"
	glb.add_child(tree)
	tree.root_node = tree.get_path_to(glb)
	tree.add_animation_library("", lib)
	tree.tree_root = _build()
	start_ph = WardenStart.phases(lib, d["loco"], sk)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	twist_on = bool((d["loco"] as Dictionary).get("aim_twist", false))
	gait = WardenGait.new(sk, (d["loco"] as Dictionary).get("arm_swing", {}))
	free_arm = WardenFreeArm.new(sk, lib, String(d["loco"]["idle"]), d.get("free_arm", {}))
	_setup_out()
	return true

## "weapon_out": {"clip", "bones"}: an arm pose laid over everything while the weapon is out of the hand; "weapon_bone"
## scales to zero meanwhile. "bone_scale": {bone: size}: a skinned weapon's size against the sheet (item 137), the
## skinned twin of warden_look "weapon_scale": the bone and all it carries, its empties included.
func _setup_out() -> void:
	weapon_bi = WardenSkeleton.find(skel, String(d.get("weapon_bone", ""))) if d.has("weapon_bone") else -1
	var sizes: Dictionary = d.get("bone_scale", {})
	for nm in sizes:
		var bi := WardenSkeleton.find(skel, String(nm))
		if bi >= 0:
			bone_scales.append([bi, Vector3.ONE * float(sizes[nm])])
			skel.set_bone_pose_scale(bi, Vector3.ONE * float(sizes[nm]))
	var wo: Dictionary = d.get("weapon_out", {})
	if wo.is_empty() or not lib.has_animation(String(wo["clip"])):
		return
	var a := lib.get_animation(String(wo["clip"]))
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(a.track_get_path(i).get_concatenated_subnames())
		if bone in wo["bones"]:
			out_pose.append([skel.find_bone(bone), a.rotation_track_interpolate(i, 0.0)])

func _out(dt: float) -> void:
	var out := bool(root.get_meta(WEAPON_OUT, false))
	var k := float(root.get_meta(WEAPON_K, 1.0))     # (the whirl, on top of any "bone_scale")
	if weapon_bi >= 0:
		skel.set_bone_pose_scale(weapon_bi, Vector3.ZERO if out else Vector3.ONE * k)
	for b in bone_scales:
		if b[0] != weapon_bi:
			skel.set_bone_pose_scale(b[0], b[1])
		elif not out:
			skel.set_bone_pose_scale(b[0], b[1] * k)
	var busy := act_w > 0.5 or up_w > 0.5
	out_w = move_toward(out_w, 1.0 if out and not busy else 0.0, OUT_RATE * dt)
	if out_w > 0.0:
		for b in out_pose:
			var bi := int(b[0])
			skel.set_bone_pose_rotation(bi, skel.get_bone_pose_rotation(bi).slerp(b[1], out_w))

func _is_loop(nm: String) -> bool:
	var lc: Dictionary = d.get("loco", {})
	if nm == lc.get("idle") or nm == lc.get("stance") or nm in (lc.get("walk", {}) as Dictionary).values() \
			or nm in (lc.get("run", {}) as Dictionary).values():
		return true
	var cr: Dictionary = d.get("crouch", {})
	if cr.has("idle") and (nm == cr["idle"] or nm in (cr["walk"] as Dictionary).values()):
		return true
	return nm in ["fall", "glide", "stun"]

func _length(nm: String) -> float:
	return lib.get_animation(nm).length

func _anim(nm: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = nm
	return n

func _build() -> AnimationNodeBlendTree:
	var lc: Dictionary = d["loco"]
	var t := AnimationNodeBlendTree.new()
	var in_step := bool(lc.get("in_step", false))     # (a ring on one length and strike key: every loop keeps time)
	t.add_node("walk", _ring(lc["walk"], in_step))
	t.add_node("run", _ring(lc["run"], in_step))
	t.add_node("rings", AnimationNodeBlend2.new())
	for i in 2:
		var ring: String = ["walk", "run"][i]
		t.add_node(ring + "_seek", AnimationNodeTimeSeek.new())
		t.connect_node(ring + "_seek", 0, ring)
		t.connect_node("rings", i, ring + "_seek")
	t.add_node("loco_rate", AnimationNodeTimeScale.new())
	t.connect_node("loco_rate", 0, "rings")
	t.add_node("idle", _anim(String(lc["idle"])))
	t.add_node("idle_seek", AnimationNodeTimeSeek.new())
	t.connect_node("idle_seek", 0, "idle")
	t.add_node("loco", AnimationNodeBlend2.new())
	t.connect_node("loco", 0, "idle_seek")
	t.connect_node("loco", 1, "loco_rate")
	t.add_node("stance", _anim(String(lc["stance"])))
	t.add_node("stance_w", AnimationNodeBlend2.new())
	t.connect_node("stance_w", 0, "loco")
	t.connect_node("stance_w", 1, "stance")
	var ai: Dictionary = d["air"]
	var space := AnimationNodeBlendSpace1D.new()
	space.add_blend_point(_anim(String(ai["fall"])), 0.0)
	space.add_blend_point(_anim(String(ai["rise"])), 1.0)
	t.add_node("air_pose", space)
	t.add_node("glide", _anim(String(ai["glide"])))
	t.add_node("glide_w", AnimationNodeBlend2.new())
	t.connect_node("glide_w", 0, "air_pose")
	t.connect_node("glide_w", 1, "glide")
	t.add_node("air", AnimationNodeBlend2.new())
	t.connect_node("air", 0, _build_crouch(t) if d.has("crouch") else "stance_w")
	t.connect_node("air", 1, "glide_w")
	for ch in ["a", "b"]:
		t.add_node("anim_" + ch, _anim(String(lc["idle"])))
		t.add_node("seek_" + ch, AnimationNodeTimeSeek.new())
		t.connect_node("seek_" + ch, 0, "anim_" + ch)
		t.add_node("rate_" + ch, AnimationNodeTimeScale.new())
		t.connect_node("rate_" + ch, 0, "seek_" + ch)
	t.add_node("act", AnimationNodeBlend2.new())
	t.connect_node("act", 0, "rate_a")
	t.connect_node("act", 1, "rate_b")
	var up := AnimationNodeBlend2.new()
	up.filter_enabled = true
	for b in d.get("upper", []):
		up.set_filter_path(_track(String(b)), true)
	t.add_node("upper", up)
	for ch in ["ua", "ub"]:
		t.add_node("anim_" + ch, _anim(String(lc["idle"])))
		t.add_node("seek_" + ch, AnimationNodeTimeSeek.new())
		t.connect_node("seek_" + ch, 0, "anim_" + ch)
	t.add_node("act_u", AnimationNodeBlend2.new())
	t.connect_node("act_u", 0, "seek_ua")
	t.connect_node("act_u", 1, "seek_ub")
	t.connect_node("upper", 0, "air")
	t.connect_node("upper", 1, "act_u")
	_build_flinch(t)
	t.add_node("full", AnimationNodeBlend2.new())
	t.connect_node("full", 0, "flinch")
	t.connect_node("full", 1, "act")
	t.connect_node("output", 0, "full")
	return t

## The flinch layer over "upper": the hit clip less its own first frame, added on the spine and arms, so the run
## under it keeps swinging and the legs never leave the loco clip.
func _build_flinch(t: AnimationNodeBlendTree) -> void:
	for nm in ["hit", "hit0"]:
		t.add_node("anim_" + nm, _anim(String(d["loco"]["idle"])))
		t.add_node("seek_" + nm, AnimationNodeTimeSeek.new())
		t.connect_node("seek_" + nm, 0, "anim_" + nm)
	var sub := AnimationNodeSub2.new()
	var add := AnimationNodeAdd2.new()
	for node in [sub, add]:
		node.filter_enabled = true
		for b in d.get("upper", []):
			node.set_filter_path(_track(String(b)), true)
	t.add_node("flinch_delta", sub)
	t.connect_node("flinch_delta", 0, "seek_hit")
	t.connect_node("flinch_delta", 1, "seek_hit0")
	t.add_node("flinch", add)
	t.connect_node("flinch", 0, "upper")
	t.connect_node("flinch", 1, "flinch_delta")

## A ring of loops on the unit circle, one per direction off the facing (x his right, y forward): a Hero with its own
## diagonal loops gets them, else a diagonal blends its two neighbours. `centre`: a clip in the middle (the crouch
## idle; the walk and run rings have none, the idle lies under them on its own weight).
func _ring(loops: Dictionary, in_step: bool, centre := "") -> AnimationNodeBlendSpace2D:
	var bs := AnimationNodeBlendSpace2D.new()
	bs.min_space = Vector2(-1, -1)
	bs.max_space = Vector2(1, 1)
	bs.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	bs.sync = in_step
	if centre != "":
		bs.add_blend_point(_anim(centre), Vector2.ZERO)
	var dirs := {"f": Vector2(0, 1), "b": Vector2(0, -1), "l": Vector2(-1, 0), "r": Vector2(1, 0)}
	for k in dirs:
		bs.add_blend_point(_anim(String(loops[k])), dirs[k])
	for k in DIAGONALS:
		if loops.has(k):
			bs.add_blend_point(_anim(String(loops[k])), (dirs[k[0]] + dirs[k[1]]).normalized())
	return bs

## The crouch layer over stance_w: its own ring (the crouch idle at the centre, the sneak ring), the dip's seek channel.
func _build_crouch(t: AnimationNodeBlendTree) -> String:
	var cr: Dictionary = d["crouch"]
	# (loops of one length keep time: a ring from hunter_dir_gait.py crouch shares a strike key too)
	var lengths := {}
	for k in cr["walk"]:
		lengths[_length(String(cr["walk"][k]))] = true
	t.add_node("crouch_loco", _ring(cr["walk"], lengths.size() == 1, String(cr["idle"])))
	t.add_node("crouch_rate", AnimationNodeTimeScale.new())
	t.connect_node("crouch_rate", 0, "crouch_loco")
	t.add_node("crouch_anim", _anim(String(cr["in"])))
	t.add_node("crouch_dip", AnimationNodeTimeSeek.new())
	t.connect_node("crouch_dip", 0, "crouch_anim")
	t.add_node("crouch_one", AnimationNodeBlend2.new())
	t.connect_node("crouch_one", 0, "crouch_rate")
	t.connect_node("crouch_one", 1, "crouch_dip")
	t.add_node("crouch_w", AnimationNodeBlend2.new())
	t.connect_node("crouch_w", 0, "stance_w")
	t.connect_node("crouch_w", 1, "crouch_one")
	return "crouch_w"

## The animation track path of a bone.
func _track(bone: String) -> NodePath:
	var bi := WardenSkeleton.find(skel, bone)
	var path := String(tree.get_node(tree.root_node).get_path_to(skel))
	return NodePath("%s:%s" % [path, skel.get_bone_name(bi) if bi >= 0 else bone])

func _node(nm: String) -> AnimationNodeAnimation:
	return (tree.tree_root as AnimationNodeBlendTree).get_node(nm) as AnimationNodeAnimation

func _p(nm: String, v: Variant) -> void:
	tree.set("parameters/" + nm, v)

## What the state asks for: {clip, t (s, or -1: it plays on its own), upper} or {}; {"proc": true}: back to the rig.
func _pick(s: Dictionary, dt: float) -> Dictionary:
	var st: Dictionary = d.get("states", {})
	for k in d.get("procedural", []):
		var v = s.get(k, null)
		if (v is bool and v) or (v is float and v >= 0.0):
			return {"proc": true}
	if bool(s.get("dead", false)) and st.has("dead"):
		return {"clip": st["dead"], "t": float(s.get("dead_t", 0.0))}
	var km := String(s.get("kmove", ""))
	var moves: Dictionary = d.get("kmoves", {})
	if moves.has(km):
		var mv: Dictionary = moves[km]
		# ("lead": the cock is skipped, so the hit pose lands on the kit's hit)
		var tt := float(s.get("kmove_t", 0.0)) + float(mv.get("lead", 0.0))
		# ("alt": every other play of the move takes this clip: Motley's orbs, hand after hand)
		if km != alt_km or tt < alt_t:
			alt_on = not alt_on
		alt_km = km
		alt_t = tt
		var clip := String(mv["alt"] if mv.has("alt") and alt_on else mv["clip"])
		var length := lib.get_animation(clip).length
		# (a lead clip holds its last frame rather than ending before the move does)
		if mv.has("lead"):
			tt = minf(tt, length - 0.001)
		if mv.has("hold_from") and root.has_meta(PHASE):
			var start := float(mv["hold_from"])
			tt = start + float(root.get_meta(PHASE)) * (length - start - 0.001)
		elif tt >= length:
			if not mv.has("hold_from"):
				return {}
			var from := float(mv["hold_from"])
			tt = from + fmod(tt - from, maxf(length - from, 0.01)) if length > from + 0.02 else length - 0.001
		# ("upper": true, or "moving": the legs keep walking only while he walks)
		var up = mv.get("upper", false)
		if up is String:
			var vel: Vector3 = s.get("vel", Vector3.ZERO)
			up = Vector2(vel.x, vel.z).length() >= STILL
		return {"clip": clip, "t": tt, "upper": up, "heading": bool(mv.get("heading", false)),
				"fade": float(mv.get("fade", FADE)), "legs_heading": bool(mv.get("legs_heading", false)),
				"turn_max": float(mv.get("turn_max", HEADING_MAX)), "heading_off": float(mv.get("heading_off", 0.0))}
	if km != "":
		return {"proc": true}     # a move this Hero has no clip for: the rig plays it, with the procedural pose
	var act: Dictionary = d.get("act", {})
	if act.has(String(s.get("act", ""))):
		var clip := String(act[s["act"]])
		return {"clip": clip, "t": minf(float(s.get("act_t", 0.0)), lib.get_animation(clip).length - 0.001)}
	if bool(s.get("reviving", false)) and st.has("reviving"):
		return {"clip": st["reviving"], "t": -1.0}
	if bool(s.get("stun", false)) and st.has("stun"):
		return {"clip": st["stun"], "t": -1.0}
	var em := String(s.get("emote", ""))
	if em != "" and st.has("emote"):
		return {"clip": st["emote"], "t": float(s.get("emote_t", 0.0))}
	land_t += dt
	var ld: Dictionary = d.get("land", {})
	if land_t < float(ld.get("dur", 0.0)) and bool(s.get("grounded", true)):
		return {"clip": ld["clip"], "t": land_t}
	var hit := float(s.get("hit_t", 99.0))
	var hd: Dictionary = st.get("hit", {})
	if hit < float(hd.get("dur", 0.0)):
		var dir: Vector2 = s.get("hit_dir", Vector2.ZERO)
		var fw := Vector2(sin(float(s.get("face", 0.0))), cos(float(s.get("face", 0.0))))
		var vel: Vector3 = s.get("vel", Vector3.ZERO)
		var heavy := float(s.get("hit_k", 1.0)) >= Oomph.HEAVY_FLINCH
		var running := Vector2(vel.x, vel.z).length() >= STILL or not bool(s.get("grounded", true))
		# (a chip hit on the move flinches the spine and arms, the legs keep running; still or a stagger: whole body)
		return {"clip": hd["front" if dir.dot(fw) >= 0.0 else "back"], "t": hit, "flinch": running and not heavy}
	return {}

func step(dt: float) -> void:
	var s: Dictionary = root.get_meta(STATE, {})
	var want := force
	if want.is_empty():
		want = _pick(s, dt) if not s.is_empty() else {"proc": true}
	var proc := bool(want.get("proc", false))
	proc_w = move_toward(proc_w, 1.0 if proc else 0.0, dt / FADE)
	var flinching := not proc and bool(want.get("flinch", false))
	if flinching:
		for nm in ["hit", "hit0"]:
			_node("anim_" + nm).animation = String(want["clip"])
		_p("seek_hit/seek_request", float(want["t"]))
		_p("seek_hit0/seek_request", 0.0)
	flinch_w = move_toward(flinch_w, 1.0 if flinching else 0.0, dt / FADE)
	if flinching:
		act_w = move_toward(act_w, 0.0, dt / FADE_LOCO)
		up_w = move_toward(up_w, 0.0, dt / FADE_LOCO)
	elif not proc and bool(want.get("upper", false)):
		var clip_u := String(want["clip"])
		if clip_u != cur_u:
			cur_u = clip_u
			chan_u = 1 - chan_u
			_node("anim_u" + "ab"[chan_u]).animation = clip_u
			if up_w <= 0.0:
				xf_u = float(chan_u)     # (from the legs: no old clip to fade out of)
		_p("seek_u%s/seek_request" % "ab"[chan_u], float(want.get("t", 0.0)))
		up_w = move_toward(up_w, 1.0, dt / FADE)
		act_w = move_toward(act_w, 0.0, dt / FADE_LOCO)
	elif not proc and want.has("clip"):
		var clip := String(want["clip"])
		var tt := float(want.get("t", -1.0))
		if clip != cur:
			cur = clip
			chan = 1 - chan
			var ch := "a" if chan == 0 else "b"
			_node("anim_" + ch).animation = clip
			_p("seek_%s/seek_request" % ch, maxf(tt, 0.0))
		var live := "a" if chan == 0 else "b"
		if tt >= 0.0:
			_p("seek_%s/seek_request" % live, tt)
			_p("rate_%s/scale" % live, 0.0)
		else:
			_p("rate_%s/scale" % live, 1.0)
		act_w = move_toward(act_w, 1.0, dt / float(want.get("fade", FADE)))
		up_w = move_toward(up_w, 0.0, dt / FADE)
	else:
		act_w = move_toward(act_w, 0.0, dt / FADE_LOCO)
		up_w = move_toward(up_w, 0.0, dt / FADE_LOCO)
		if act_w <= 0.0 and up_w <= 0.0:
			cur = ""
	xf = move_toward(xf, float(chan), dt / float(want.get("fade", FADE)))
	xf_u = move_toward(xf_u, float(chan_u), dt / float(want.get("fade", FADE)))
	_p("act/blend_amount", xf)
	_p("act_u/blend_amount", xf_u)
	_p("upper/blend_amount", up_w)
	_p("flinch/add_amount", flinch_w)
	_p("full/blend_amount", act_w)
	_loco(s, dt)
	if d.has("crouch"):
		_crouch(s, dt)
	tree.advance(dt)
	var loco_k := (1.0 - act_w) * (1.0 - air_w) * (1.0 - crouch_w) * (1.0 if _moving(s) else 0.0)
	gait.apply(dt, loco_k, loco_k * (1.0 - up_w))
	var legs := bool(want.get("legs_heading", false))
	_turn_to_heading(s, want, legs, dt)
	_out(dt)
	free_arm.apply(dt, "" if proc else String(want.get("clip", "")))

## A move keyed "heading" leans where he is going, not where he faces (the Warchain's haul): the root turns toward
## his velocity on top of the clip, so the clip's lean follows it. "turn_max" lifts the limit (a dash clip that
## plays moving backwards turns all the way round); "heading_off" turns it that much further (a sideways cartwheel
## travelling forward turns its side to the way he goes).
## "legs_heading" (Vex's slide, aims_in_dash) and the aim twist: only the legs go: the hips take the turn back, so the
## torso and the arm on the aim keep their pose. The torso eases between the two, so a roll out of a twisted run turns
## him whole without a snap.
func _turn_to_heading(s: Dictionary, want: Dictionary, legs_only: bool, dt: float) -> void:
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var face := float(s.get("face", 0.0))
	var goal := 0.0
	var twisting := false
	if (bool(want.get("heading", false)) or legs_only) and Vector2(vel.x, vel.z).length() > HEADING_MIN:
		goal = wrapf(atan2(-vel.x, -vel.z) - face + float(want.get("heading_off", 0.0)), -PI, PI)
		var most := LEGS_MAX if legs_only else float(want.get("turn_max", HEADING_MAX))
		goal = clampf(goal, -most, most)
	elif twist_on:
		legs_only = true
		twisting = true
		goal = twist_goal * (1.0 - act_w) * (1.0 - air_w) * (1.0 - crouch_w)
		if twist_goal != 0.0:
			# running: the legs hold their way while the aim swings, but never twist him past the limit
			var held := head_turn - wrapf(face - twist_face, -PI, PI)
			head_turn = clampf(held, minf(head_turn, -TWIST_MAX), maxf(head_turn, TWIST_MAX))
	twist_face = face
	var follow := 1.0 - exp(-dt * HEADING_RATE)     # how far the turn eases toward its goal this frame
	if twisting:
		# (the twist swings the legs across his front, never round his back; on a spring, so a stop or a turn of the
		# legs round to run backwards never flicks them)
		var sp := _spring(head_turn, head_v, goal, dt)
		head_turn = sp[0]
		head_v = sp[1]
	else:
		head_turn = lerp_angle(head_turn, goal, follow)
		head_v = 0.0
	torso_turn = lerp_angle(torso_turn, 0.0 if legs_only else goal, follow)
	if absf(head_turn) < 0.002 and absf(torso_turn) < 0.002:
		return
	var bi := WardenSkeleton.find(skel, "root")
	var was := skel.get_bone_pose_rotation(bi)
	var turn := Quaternion(Vector3.UP, head_turn)
	skel.set_bone_pose_rotation(bi, turn * was)
	# (and the clip's own sway of the root turns with it: kept on the old axis it pushes a planted foot sideways)
	skel.set_bone_pose_position(bi, turn * skel.get_bone_pose_position(bi))
	if absf(torso_turn - head_turn) >= 0.002:     # the hips take back what the torso does not turn
		var hb := WardenSkeleton.find(skel, "hips")
		var back := Quaternion(Vector3.UP, torso_turn - head_turn)
		skel.set_bone_pose_rotation(hb, was.inverse() * back * was * skel.get_bone_pose_rotation(hb))

## The source's run-and-aim: the legs play the run forward and turn to where he goes while the torso stays on the aim,
## up to TWIST_MAX; beyond it the legs turn round and run backwards, so the torso never twists past TWIST_MAX.
## Returns the rings' direction (forward or back) and sets `twist_goal` for _turn_to_heading.
func _aim_twist(flat: Vector2, face: float) -> Vector2:
	var rel := wrapf(atan2(-flat.x, -flat.y) - face, -PI, PI)
	twist_back = absf(rel) > (PI - TWIST_MAX if twist_back else TWIST_MAX)
	twist_goal = rel - signf(rel) * PI if twist_back else rel
	return Vector2(0.0, -1.0 if twist_back else 1.0)

## One step of a critically damped spring (BLEND_W) of `x` (a float or a Vector2) at rate `v` toward `goal`: its
## path has no corner, so nothing it blends ever jumps speed. Returns [x, v].
func _spring(x: Variant, v: Variant, goal: Variant, dt: float) -> Array:
	v += (BLEND_W * BLEND_W * (goal - x) - 2.0 * BLEND_W * v) * dt
	return [x + v * dt, v]

func _moving(s: Dictionary) -> bool:
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	return Vector2(vel.x, vel.z).length() >= STILL

func _loco(s: Dictionary, dt: float) -> void:
	var lc: Dictionary = d["loco"]
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var flat := Vector2(vel.x, vel.z)
	var spd := flat.length()
	var face := float(s.get("face", 0.0))
	# (the model faces -Z at yaw 0: forward and right of the facing)
	var fw := Vector2(-sin(face), -cos(face))
	var rt := Vector2(cos(face), -sin(face))
	var walk := float(lc.get("walk_speed", 2.2))
	var moving := spd >= STILL
	on_run = spd >= walk * (RUN_BACK if on_run else RUN_FROM)
	twist_goal = 0.0
	var dir := dir_pos     # (standing: the rings keep their way, unseen)
	if moving:
		dir = _aim_twist(flat, face) if twist_on else Vector2((flat / spd).dot(rt), (flat / spd).dot(fw))
	# (the idle under the rings eases in to a stop, the walk ring over it up to walk_speed; the run ring shows, or the
	# walk ring: never held half and half, out of step they cancel the feet)
	var walk_len := _length(String(lc["walk"]["f"]))
	var run_len := _length(String(lc["run"]["f"]))
	if moving and move_w <= 0.001:     # (moving off: the rings pick up at the pose nearest the idle, WardenStart)
		_p("walk_seek/seek_request", float(start_ph[0]) * walk_len)
		_p("run_seek/seek_request", float(start_ph[1]) * run_len)
		starting = true
	elif on_run and run_w <= 0.001:     # (a ring at no weight stands still: the run comes in on the walk's stride)
		var walk_ph := float(tree.get("parameters/walk/current_position")) / walk_len
		_p("run_seek/seek_request", fposmod(walk_ph - float(start_ph[0]) + float(start_ph[1]), 1.0) * run_len)
	var w := _spring(move_w, move_v, minf(spd / walk, 1.0) if moving else 0.0, dt)
	move_w = w[0]
	move_v = w[1]
	var r := _spring(run_w, run_v, 1.0 if on_run else 0.0, dt)
	run_w = r[0]
	run_v = r[1]
	if move_w > 0.001:
		var p := _spring(dir_pos, dir_v, dir, dt)
		dir_pos = p[0]
		dir_v = p[1]
	else:
		dir_pos = dir     # (nothing of the rings shows: they turn at once)
		dir_v = Vector2.ZERO
	starting = starting and moving and move_w < 0.99
	if move_w >= 0.999:
		_p("idle_seek/seek_request", 0.0)     # (a stop starts the idle from its top, never mid-fidget)
	_p("loco/blend_amount", clampf(move_w, 0.0, 1.0))
	_p("rings/blend_amount", clampf(run_w, 0.0, 1.0))
	_p("walk/blend_position", dir_pos)
	_p("run/blend_position", dir_pos)
	var rate := gait.plan(spd, lc, clampf(run_w, 0.0, 1.0))
	# (a start plays the rings at the ground speed from the first frame: the clip's stride covers what the accel
	# carries him, so the first foot down lands on its contact key; after it the rate eases)
	loco_rate = rate if starting else lerpf(loco_rate, rate, 1.0 - exp(-dt * RATE_EASE))
	_p("loco_rate/scale", loco_rate)
	still_t = still_t + dt if spd < STILL and act_w <= 0.0 else 0.0
	stance_w = move_toward(stance_w, 1.0 if still_t > float(lc.get("stance_after", 6.0)) else 0.0, dt / 0.5)
	_p("stance_w/blend_amount", stance_w)
	var grounded := bool(s.get("grounded", true))
	var gliding := bool(s.get("gliding", false)) or bool(s.get("diving", false))
	air_w = move_toward(air_w, 0.0 if grounded else 1.0, dt / AIR_FADE)
	glide_w = move_toward(glide_w, 1.0 if gliding else 0.0, dt / AIR_FADE)
	rise_w = move_toward(rise_w, 1.0 if vel.y > 0.5 else 0.0, dt / AIR_FADE)
	_p("air/blend_amount", air_w)
	_p("glide_w/blend_amount", glide_w)
	_p("air_pose/blend_position", rise_w)
	if not grounded:
		air_t += dt
	elif was_air:
		if air_t >= float((d.get("land", {}) as Dictionary).get("min_fall", 0.0)):
			land_t = 0.0
		air_t = 0.0
	was_air = not grounded

## The crouch layer: the dip plays as the state turns, the weight eases, the sneak ring follows the velocity.
func _crouch(s: Dictionary, dt: float) -> void:
	var cr: Dictionary = d["crouch"]
	var k := float(s.get("crouch", 0.0))
	var on := crouch_on
	if k > crouch_k or k >= 1.0:
		on = true
	elif k < crouch_k or k <= 0.0:
		on = false
	crouch_k = k
	if on != crouch_on:
		crouch_on = on
		crouch_from = crouch_w
		crouch_t = 0.0
		crouch_clip = ""
		if one_w <= 0.0:      # (turned round mid-dip: the clip showing can't be swapped, so no second dip)
			crouch_clip = String(cr["in" if on else "out"])
			crouch_seek = 0.0
			_node("crouch_anim").animation = crouch_clip
			one_w = 1.0       # (from its first frame: under the fade the hold would drop him early)
	crouch_t += dt
	var length := lib.get_animation(crouch_clip).length if crouch_clip != "" else 0.0
	var fade := CROUCH_IN      # (with a dip: quick going down, under the clip; coming up, the clip's whole length)
	if length > 0.0:
		fade = CROUCH_ONE if on else length
	crouch_w = lerpf(crouch_from, 1.0 if on else 0.0, smoothstep(0.0, fade, crouch_t))
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var flat := Vector2(vel.x, vel.z)
	var spd := flat.length()
	var goal := 0.0
	if crouch_clip != "" and crouch_t < length:
		goal = CROUCH_MOVING if spd >= STILL else 1.0
	one_w = move_toward(one_w, goal, dt / CROUCH_ONE)
	if crouch_clip != "":
		crouch_seek = minf(crouch_seek + dt, maxf(length - 0.001, 0.0))
	if one_w > 0.0:
		_p("crouch_dip/seek_request", crouch_seek)
	_p("crouch_w/blend_amount", crouch_w)
	_p("crouch_one/blend_amount", one_w)
	var face := float(s.get("face", 0.0))
	var fw := Vector2(-sin(face), -cos(face))
	var rt := Vector2(cos(face), -sin(face))
	var speed := float(cr.get("speed", 2.4))
	var dir := flat / spd if spd > 0.01 else Vector2.ZERO
	var pos := Vector2(dir.dot(rt), dir.dot(fw)) * clampf(spd / speed, 0.0, 1.0) if spd >= STILL else Vector2.ZERO
	var c := _spring(crouch_pos, crouch_v, pos, dt)
	crouch_pos = c[0]
	crouch_v = c[1]
	_p("crouch_loco/blend_position", crouch_pos)
	_p("crouch_rate/scale", clampf(spd / speed, 0.7, CROUCH_RATE_MAX) if spd >= STILL else 1.0)
