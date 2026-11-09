class_name WardenClips
extends RefCounted
## A Hero's hand-keyed clips (ART-1, docs/art/wardens/CLIPS.md): the .glb's animations played through an AnimationTree
## so the moves flow. Which state plays what is data, content/rules/warden_anim/<art>.json; no file: it
## stays on HunterAnim. HunterAnim still runs and stays the source of truth for the state (it hands its state over
## as the model's meta STATE), the kit keeps its timing: a keyed move's clip is seeked to the kit's own kmove_t, so a
## clip can never drift from the hit it shows. States the data lists as "procedural" (ledges, stomps) blend back to the
## retargeted rig, and so does any Hero model played by something that feeds no state (galleries, portraits).
##
## The tree: loco (BlendSpace2D: idle at the centre, a walk ring, a run ring) > air (Blend2 onto a BlendSpace1D of fall
## and rise, or the glide) > upper (Blend2 filtered to the torso and arms: moves that keep the legs running) > full
## (Blend2: moves that own the body). The action itself is two seekable channels crossfaded, so one move hands to the
## next without a pop (item 32).
##
## Data "crouch" (item 143): under air, a crouch layer (idle and a sneak ring) with a one-shot channel for the dip into
## and out of it. The game state's crouch (0..1) only says which way it is going; the layer has its own eased weight.
## A Hero with no "crouch" key stands through a crouch, as the clips have no pose for it.

const DIR := "res://content/rules/warden_anim/"
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
const WEAPON_K := "weapon_k"  # root meta: the skinned weapon's size over its rest (the whirl)
const OUT_RATE := 10.0       # 1/s: the free-arm pose eases in and out
const CROUCH_IN := 0.12      # s: the layer eases over the body when no dip carries it
const CROUCH_ONE := 0.06     # s: the dip clip eases in and out of the layer
const CROUCH_MOVING := 0.6   # how much of the dip plays over a sneak: the legs keep some of their stride
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
var act_w := 0.0             # how much the action owns the body
var up_w := 0.0              # how much it owns the upper body only
var air_w := 0.0
var glide_w := 0.0
var proc_w := 1.0            # how much of the procedural rig is shown
var rise_w := 0.0
var loco_pos := Vector2.ZERO
var still_t := 0.0
var stance_w := 0.0
var was_air := false
var air_t := 0.0
var land_t := 99.0
var hit_seen := 99.0
var last_emote := ""
var legs_was := false        # the turn on now is a legs_heading one
var head_turn := 0.0         # rad the root is turned toward his heading
var force := {}              # a tool's pick ({clip, t}): skips the state (tools/clip_shots.gd)
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
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
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
	return nm in ["fall", "glide", "stun", "downed"]

func _anim(nm: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = nm
	return n

func _build() -> AnimationNodeBlendTree:
	var lc: Dictionary = d["loco"]
	var bs := AnimationNodeBlendSpace2D.new()
	bs.min_space = Vector2(-1, -1)
	bs.max_space = Vector2(1, 1)
	bs.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	bs.add_blend_point(_anim(String(lc["idle"])), Vector2.ZERO)
	var dirs := {"f": Vector2(0, 1), "b": Vector2(0, -1), "l": Vector2(-1, 0), "r": Vector2(1, 0)}
	for k in dirs:
		bs.add_blend_point(_anim(String(lc["walk"][k])), dirs[k] * 0.45)
		bs.add_blend_point(_anim(String(lc["run"][k])), dirs[k])
	var t := AnimationNodeBlendTree.new()
	t.add_node("loco", bs)
	t.add_node("loco_rate", AnimationNodeTimeScale.new())
	t.connect_node("loco_rate", 0, "loco")
	t.add_node("stance", _anim(String(lc["stance"])))
	t.add_node("stance_w", AnimationNodeBlend2.new())
	t.connect_node("stance_w", 0, "loco_rate")
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
	t.add_node("anim_u", _anim(String(lc["idle"])))
	t.add_node("seek_u", AnimationNodeTimeSeek.new())
	t.connect_node("seek_u", 0, "anim_u")
	t.connect_node("upper", 0, "air")
	t.connect_node("upper", 1, "seek_u")
	t.add_node("full", AnimationNodeBlend2.new())
	t.connect_node("full", 0, "upper")
	t.connect_node("full", 1, "act")
	t.connect_node("output", 0, "full")
	return t

## The crouch layer over stance_w: its own BlendSpace2D (idle at the centre, the sneak ring), the dip's seek channel.
func _build_crouch(t: AnimationNodeBlendTree) -> String:
	var cr: Dictionary = d["crouch"]
	var bs := AnimationNodeBlendSpace2D.new()
	bs.min_space = Vector2(-1, -1)
	bs.max_space = Vector2(1, 1)
	bs.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	bs.add_blend_point(_anim(String(cr["idle"])), Vector2.ZERO)
	var dirs := {"f": Vector2(0, 1), "b": Vector2(0, -1), "l": Vector2(-1, 0), "r": Vector2(1, 0)}
	for k in dirs:
		bs.add_blend_point(_anim(String(cr["walk"][k])), dirs[k])
	t.add_node("crouch_loco", bs)
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
		var tt := float(s.get("kmove_t", 0.0))
		# ("alt": every other play of the move takes this clip: Motley's orbs, hand after hand)
		if km != alt_km or tt < alt_t:
			alt_on = not alt_on
		alt_km = km
		alt_t = tt
		var clip := String(mv["alt"] if mv.has("alt") and alt_on else mv["clip"])
		var length := lib.get_animation(clip).length
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
				"fade": float(mv.get("fade", FADE)), "legs_heading": bool(mv.get("legs_heading", false))}
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
		return {"clip": hd["front" if dir.dot(fw) >= 0.0 else "back"], "t": hit, "upper": true}
	return {}

func step(dt: float) -> void:
	var s: Dictionary = root.get_meta(STATE, {})
	var want := force
	if want.is_empty():
		want = _pick(s, dt) if not s.is_empty() else {"proc": true}
	var proc := bool(want.get("proc", false))
	proc_w = move_toward(proc_w, 1.0 if proc else 0.0, dt / FADE)
	if not proc and bool(want.get("upper", false)):
		_node("anim_u").animation = String(want["clip"])
		_p("seek_u/seek_request", float(want.get("t", 0.0)))
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
	_p("act/blend_amount", xf)
	_p("upper/blend_amount", up_w)
	_p("full/blend_amount", act_w)
	_loco(s, dt)
	if d.has("crouch"):
		_crouch(s, dt)
	tree.advance(dt)
	var legs := bool(want.get("legs_heading", false))
	_turn_to_heading(s, bool(want.get("heading", false)) or legs, legs, dt)
	_out(dt)

## A move keyed "heading" leans where he is going, not where he faces (the Warchain's haul): the root turns toward
## his velocity on top of the clip, so the clip's lean follows it.
## "legs_heading" (Vex's slide, aims_in_dash): only the legs go: the hips take the turn back, so the torso
## and the arm on the aim keep their pose.
func _turn_to_heading(s: Dictionary, on: bool, legs_only: bool, dt: float) -> void:
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var goal := 0.0
	if on and Vector2(vel.x, vel.z).length() > HEADING_MIN:
		goal = wrapf(atan2(-vel.x, -vel.z) - float(s.get("face", 0.0)), -PI, PI)
		goal = clampf(goal, -LEGS_MAX, LEGS_MAX) if legs_only else clampf(goal, -HEADING_MAX, HEADING_MAX)
	head_turn = lerp_angle(head_turn, goal, 1.0 - exp(-dt * HEADING_RATE))
	legs_was = legs_only or (legs_was and absf(head_turn) >= 0.002)     # (it unwinds the same way after the slide)
	if absf(head_turn) < 0.002:
		return
	var bi := WardenSkeleton.find(skel, "root")
	var was := skel.get_bone_pose_rotation(bi)
	var turn := Quaternion(Vector3.UP, head_turn)
	skel.set_bone_pose_rotation(bi, turn * was)
	if legs_only or legs_was:
		var hb := WardenSkeleton.find(skel, "hips")
		skel.set_bone_pose_rotation(hb, was.inverse() * turn.inverse() * was * skel.get_bone_pose_rotation(hb))

func _loco(s: Dictionary, dt: float) -> void:
	var lc: Dictionary = d["loco"]
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var flat := Vector2(vel.x, vel.z)
	var spd := flat.length()
	var face := float(s.get("face", 0.0))
	# (the model faces -Z at yaw 0: forward and right of the facing)
	var fw := Vector2(-sin(face), -cos(face))
	var rt := Vector2(cos(face), -sin(face))
	var run := float(lc.get("run_speed", 4.6))
	var walk := float(lc.get("walk_speed", 2.2))
	var k := clampf(spd / run, 0.0, 1.0) if spd >= STILL else 0.0
	var dir := flat / spd if spd > 0.01 else Vector2.ZERO
	var goal := Vector2(dir.dot(rt), dir.dot(fw)) * k
	loco_pos = loco_pos.lerp(goal, 1.0 - exp(-dt * 12.0))
	_p("loco/blend_position", loco_pos)
	var gait := lerpf(walk, run, clampf((spd - walk) / maxf(run - walk, 0.1), 0.0, 1.0))
	_p("loco_rate/scale", clampf(spd / gait, 0.6, 1.5) if spd >= STILL else 1.0)
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
	crouch_pos = crouch_pos.lerp(pos, 1.0 - exp(-dt * 12.0))
	_p("crouch_loco/blend_position", crouch_pos)
	_p("crouch_rate/scale", clampf(spd / speed, 0.7, 1.4) if spd >= STILL else 1.0)
