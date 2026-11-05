class_name WardenClips
extends RefCounted
## A Hunter's hand-keyed clips (ART-1): the .glb's own animations played through an AnimationTree on top of the
## procedural rig. The rig keeps running underneath, unseen: gameplay, hits and FX read it, and whatever a Hunter has
## no clip for stays procedural (a mantle, a chop). Which clip plays when is data, content/rules/warden_clips.json,
## keyed by the art name (WardenGlb.art), so a Hunter only adds its .glb and a block there:
##   "moves": kit move id -> {"clip", "mask": "full" | "upper" | "auto", "loop_from"}   (kit time drives the clip, so
##            it stays on the kit's real timings; hold moves loop from loop_from to the clip's end)
##   "loco": {"idle", "stance", "walk": [f, b, l, r], "run": [f, b, l, r], "walk_speed", "run_speed"}
##   "body": state -> clip, for "jump", "fall", "glide", "dive", "downed", "stun", "revive"
##   "over": one-shots over everything: "land", "hit", "emote", "fuse"
##   "free_r": a right-arm pose laid over everything while the weapon is out of the hand
## The tree: loco (BlendSpace2D) -> stance Blend2 -> body Transition -> action Blend2 (whole or filtered) -> free arm.

const PATH := "res://content/rules/warden_clips.json"
const WEAPON_OUT := "weapon_out"   # root meta: the kit has the weapon out of the hand (the free-arm pose lies over all)
const FADE := 12.0              # 1/s: how fast the clips take over from the procedural pose and hand it back
const UPPER := ["hips", "head", "upper_arm", "forearm", "hand", "pauldron", "x_fing", "x_thumb", "x_weapon", "x_shield",
	"x_jaw", "x_lid", "x_brow", "skirt"]
const RIGHT := ["upper_arm.R", "forearm.R", "hand.R", "x_fing", "x_thumb", "x_weapon"]
static var _data = null

var root: Node3D
var skel: Skeleton3D
var cfg: Dictionary
var tree: AnimationTree
var player: AnimationPlayer
var w := 0.0                    # the clips' share of the pose
var cur := ""                   # the action clip playing
var action_k := 0.0
var action: AnimationNodeBlend2
var stance_k := 0.0
var free_k := 0.0
var over_t := -1.0
var over := ""
var over_len := 0.0
var last_hit := 99.0
var was_grounded := true
var bones: Array = []           # [bone index, saved position, rotation] of what the clips drive
var seek_nodes := {}

## The data block of an art name, {} for none.
static func data(art_name: String) -> Dictionary:
	if _data == null:
		var p = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = p if typeof(p) == TYPE_DICTIONARY else {}
	return (_data as Dictionary).get(art_name, {})

## Clips for this dressed model, or null when it has no block or no animations.
static func setup(model: Node3D, glb: Node3D, sk: Skeleton3D, art_name: String) -> WardenClips:
	var d := data(art_name)
	var ap := glb.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if d.is_empty() or ap == null:
		return null
	var c := WardenClips.new()
	c.root = model
	c.skel = sk
	c.cfg = d
	c.player = ap
	c._build(glb)
	return c

func _has(clip: String) -> bool:
	return clip != "" and player.has_animation(clip)

func _anim(clip: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = clip
	return n

## An AnimationNode that shows a clip at a time set from outside (the kit's clock).
func _seeked(bt: AnimationNodeBlendTree, nm: String, clip: String) -> void:
	bt.add_node(nm + "_a", _anim(clip))
	bt.add_node(nm, AnimationNodeTimeSeek.new())
	bt.connect_node(nm, 0, nm + "_a")
	seek_nodes[clip] = "parameters/%s/seek_request" % nm

func _filter(node: AnimationNodeBlend2, names: Array) -> void:
	node.filter_enabled = true
	var a: Animation = player.get_animation(String(cfg["loco"]["idle"]))
	for i in a.get_track_count():
		var path := a.track_get_path(i)
		var bone := String(path.get_concatenated_subnames())
		for nm in names:
			if bone.begins_with(String(nm)):
				node.set_filter_path(path, true)

func _loco(bt: AnimationNodeBlendTree) -> void:
	var lc: Dictionary = cfg["loco"]
	var bs := AnimationNodeBlendSpace2D.new()
	bs.min_space = Vector2(-1.0, -1.0)
	bs.max_space = Vector2(1.0, 1.0)
	bs.add_blend_point(_anim(String(lc["idle"])), Vector2.ZERO)
	var dirs := [Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)]
	for k in [["walk", 0.5], ["run", 1.0]]:
		var names: Array = lc[k[0]]
		for i in 4:
			bs.add_blend_point(_anim(String(names[i])), dirs[i] * float(k[1]))
	bt.add_node("loco", bs)

func _build(glb: Node3D) -> void:
	var bt := AnimationNodeBlendTree.new()
	_loco(bt)
	var last := "loco"
	var lc: Dictionary = cfg["loco"]
	if _has(String(lc.get("stance", ""))):
		bt.add_node("stance_a", _anim(String(lc["stance"])))
		bt.add_node("stance", AnimationNodeBlend2.new())
		bt.connect_node("stance", 0, last)
		bt.connect_node("stance", 1, "stance_a")
		last = "stance"
	# the body's states
	var tr := AnimationNodeTransition.new()
	tr.xfade_time = 0.14
	tr.input_count = 1
	tr.set_input_name(0, "ground")
	var body: Dictionary = cfg.get("body", {})
	var names := body.keys()
	tr.input_count = names.size() + 1
	bt.add_node("body", tr)
	bt.connect_node("body", 0, last)
	for i in names.size():
		tr.set_input_name(i + 1, String(names[i]))
		bt.add_node("b_" + names[i], _anim(String(body[names[i]])))
		bt.connect_node("body", i + 1, "b_" + names[i])
	last = "body"
	# the actions: one Transition of seeked clips, mixed in whole or from the waist up
	var acts: Array = []
	var moves: Dictionary = cfg.get("moves", {})
	for k in moves:
		var cl := String((moves[k] as Dictionary).get("clip", ""))
		if _has(cl) and not cl in acts:
			acts.append(cl)
	for k in cfg.get("over", {}):
		var cl2 := String(cfg["over"][k])
		if _has(cl2) and not cl2 in acts:
			acts.append(cl2)
	var at := AnimationNodeTransition.new()
	at.xfade_time = 0.05
	at.input_count = acts.size()
	bt.add_node("acts", at)
	for i in acts.size():
		at.set_input_name(i, String(acts[i]))
		_seeked(bt, "s%d" % i, String(acts[i]))
		bt.connect_node("acts", i, "s%d" % i)
	# (one node for both masks: an AnimationNode's output feeds one input, so the filter is switched instead)
	action = AnimationNodeBlend2.new()
	_filter(action, UPPER)
	bt.add_node("action", action)
	bt.connect_node("action", 0, last)
	bt.connect_node("action", 1, "acts")
	last = "action"
	if _has(String(cfg.get("free_r", ""))):
		var fr := AnimationNodeBlend2.new()
		_filter(fr, RIGHT)
		bt.add_node("free", fr)
		bt.add_node("free_a", _anim(String(cfg["free_r"])))
		bt.connect_node("free", 0, last)
		bt.connect_node("free", 1, "free_a")
		last = "free"
	bt.connect_node("output", 0, last)
	tree = AnimationTree.new()
	tree.name = "ClipTree"
	glb.add_child(tree)
	tree.root_node = tree.get_path_to(player.get_parent())
	tree.anim_player = tree.get_path_to(player)
	tree.tree_root = bt
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.deterministic = false
	tree.active = true
	var a: Animation = player.get_animation(String(lc["idle"]))
	for i in a.get_track_count():
		var bi := skel.find_bone(String(a.track_get_path(i).get_concatenated_subnames()))
		if bi >= 0 and not _listed(bi):
			bones.append([bi, Vector3.ZERO, Quaternion.IDENTITY])

func _listed(bi: int) -> bool:
	for b in bones:
		if int(b[0]) == bi:
			return true
	return false

## Which clip a body state asks for ("" on the ground).
func _body_state(an: HunterAnim, s: Dictionary) -> String:
	var body: Dictionary = cfg.get("body", {})
	var pick := ""
	if bool(s.get("downed", false)):
		pick = "downed"
	elif bool(s.get("stun", false)):
		pick = "stun"
	elif bool(s.get("reviving", false)) and an.revive_k > 0.5:
		pick = "revive"
	elif bool(s.get("gliding", false)):
		pick = "glide"
	elif bool(s.get("diving", false)):
		pick = "dive"
	elif not bool(s.get("grounded", true)):
		var vel: Vector3 = s.get("vel", Vector3.ZERO)
		pick = "jump" if vel.y > 0.5 else "fall"
	return pick if body.has(pick) else ""

## What the rig is doing that no clip covers: stay procedural.
func _unmapped(an: HunterAnim, s: Dictionary) -> bool:
	if an.km_id != "" and not (cfg.get("moves", {}) as Dictionary).has(an.km_id):
		return true
	return float(s.get("mantle", -1.0)) >= 0.0 or bool(s.get("ledge", false)) or an.act_k > 0.3 or an.drink_k > 0.2 \
		or an.flipping or bool(s.get("rolling", false)) and an.km_id == ""

func _clip_time(mv: Dictionary, clip: String, tt: float) -> float:
	var ln := player.get_animation(clip).length
	if mv.has("loop_from") and tt > ln:
		var a := float(mv["loop_from"])
		return a + fmod(tt - a, maxf(ln - a, 0.05))
	return minf(tt, ln - 0.001)

## One frame, after the procedural pose has gone on the bones.
func step(dt: float, an: HunterAnim) -> void:
	if an == null or an.last_s.is_empty():
		return
	var s: Dictionary = an.last_s
	var on := not _unmapped(an, s)
	w = move_toward(w, 1.0 if on else 0.0, FADE * dt)
	if w <= 0.0:
		return
	var moves: Dictionary = cfg.get("moves", {})
	var lc: Dictionary = cfg["loco"]
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var face := float(s.get("face", root.rotation.y))
	# the model faces -Z turned by `face`: local velocity, +Y forward, +X its right
	var loc := Vector3(vel.x, 0, vel.z).rotated(Vector3.UP, -face)
	var spd := loc.length()
	var run_s := float(lc.get("run_speed", 5.0))
	var walk_s := float(lc.get("walk_speed", 2.2))
	var amt := 0.0 if spd < 0.25 else (remap(spd, 0.0, walk_s, 0.0, 0.5) if spd < walk_s else remap(spd, walk_s, run_s, 0.5, 1.0))
	var bl := Vector2(loc.x, -loc.z).normalized() * clampf(amt, 0.0, 1.0) if spd > 0.01 else Vector2.ZERO
	tree.set("parameters/loco/blend_position", bl)
	# the signature stance when he has just been fighting and stands
	var ks := 1.0 if an.aim_k > 0.3 else 0.0
	stance_k = move_toward(stance_k, ks * (1.0 - clampf(amt * 3.0, 0.0, 1.0)), 5.0 * dt)
	if tree.tree_root.has_node("stance"):
		tree.set("parameters/stance/blend_amount", stance_k)
	var st := _body_state(an, s)
	tree.set("parameters/body/transition_request", st if st != "" else "ground")
	# the one-shots: a landing, a hit, an emote, the Fusion
	_overs(dt, an, s)
	# the kit's move, on the kit's clock
	var mv: Dictionary = moves.get(an.km_id, {}) if an.km_id != "" else {}
	var clip := String(mv.get("clip", ""))
	var tt := an.km_prev_t
	var mask := String(mv.get("mask", "full"))
	if not _has(clip) and over != "":
		clip = over
		tt = over_t
		mask = "full"
	var act := _has(clip)
	if act:
		if clip != cur:
			tree.set("parameters/acts/transition_request", clip)
			cur = clip
		tree.set(String(seek_nodes[clip]), _clip_time(mv, clip, tt))
	var moving := amt > 0.1
	var upper := mask == "upper" or mask == "auto" and moving
	action.filter_enabled = upper
	action_k = move_toward(action_k, 1.0 if act else 0.0, 16.0 * dt)
	tree.set("parameters/action/blend_amount", action_k)
	var out := bool(root.get_meta(WEAPON_OUT, false))
	free_k = move_toward(free_k, 1.0 if out and not act else 0.0, 10.0 * dt)
	if tree.tree_root.has_node("free"):
		tree.set("parameters/free/blend_amount", free_k)
	if w < 1.0:
		_save()
	tree.advance(dt)
	if w < 1.0:
		_restore()

func _overs(dt: float, an: HunterAnim, s: Dictionary) -> void:
	var ov: Dictionary = cfg.get("over", {})
	var grounded := bool(s.get("grounded", true))
	var fire := ""
	if grounded and not was_grounded and ov.has("land"):
		fire = "land"
	was_grounded = grounded
	var hit := float(s.get("hit_t", 99.0))
	if hit < last_hit and hit < 0.1 and ov.has("hit"):
		fire = "hit"
	last_hit = hit
	if String(s.get("emote", "")) != "" and ov.has("emote") and over == "":
		fire = "emote"
	if fire != "" and _has(String(ov[fire])):
		over = String(ov[fire])
		over_t = 0.0
		over_len = player.get_animation(over).length
	elif over != "":
		over_t += dt
		if over_t >= over_len or an.km_id != "":
			over = ""

func _save() -> void:
	for b in bones:
		b[1] = skel.get_bone_pose_position(int(b[0]))
		b[2] = skel.get_bone_pose_rotation(int(b[0]))

## Mixes what the clips wrote with the procedural pose saved before them, by w.
func _restore() -> void:
	for b in bones:
		var bi := int(b[0])
		skel.set_bone_pose_position(bi, (b[1] as Vector3).lerp(skel.get_bone_pose_position(bi), w))
		skel.set_bone_pose_rotation(bi, (b[2] as Quaternion).slerp(skel.get_bone_pose_rotation(bi), w))
