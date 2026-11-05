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

const DIR := "res://content/rules/warden_anim/"
const STATE := "anim_state"
const DEATH_T := "clip_death_t"   # root meta: how long the death clip keeps a knocked-out Hero on screen (s, 0: not at all)
const FADE := 0.1            # s: one clip into the next, and into or out of an action
const FADE_LOCO := 0.16      # s: an action back to the legs
const AIR_FADE := 0.12
const STILL := 0.25          # m/s: below this he is standing
const WEAPON_OUT := "weapon_out"   # root meta: the kit has the skinned weapon out of the hand (Breaker's thrown hammer)
const PHASE := "clip_phase"   # root meta 0..1: a kit's own loop phase; a hold move's loop follows it, not the clock
const OUT_RATE := 10.0       # 1/s: the free-arm pose eases in and out
static var _data := {}       # art name -> its parsed file ({} when it has none)

var root: Node3D
var skel: Skeleton3D
var d: Dictionary
var tree: AnimationTree
var lib: AnimationLibrary
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
var force := {}              # a tool's pick ({clip, t}): skips the state (tools/clip_shots.gd)
var out_w := 0.0             # the "weapon_out" data: how far the free-arm pose lies over the clips
var out_pose: Array = []     # [bone index, rotation]: the free arm, sampled once from its clip
var weapon_bi := -1          # "weapon_bone": the bone a thrown weapon hides on

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
			var kind := a.track_get_type(i)
			if kind != Animation.TYPE_ROTATION_3D and String(a.track_get_path(i).get_concatenated_subnames()) in contract:
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
## scales to zero meanwhile.
func _setup_out() -> void:
	weapon_bi = WardenSkeleton.find(skel, String(d.get("weapon_bone", ""))) if d.has("weapon_bone") else -1
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
	if weapon_bi >= 0:
		skel.set_bone_pose_scale(weapon_bi, Vector3.ZERO if out else Vector3.ONE)
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
	t.connect_node("air", 0, "stance_w")
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
	if bool(s.get("downed", false)) and st.has("downed"):
		return {"clip": st["downed"], "t": -1.0}
	var km := String(s.get("kmove", ""))
	var moves: Dictionary = d.get("kmoves", {})
	if moves.has(km):
		var mv: Dictionary = moves[km]
		var clip := String(mv["clip"])
		var tt := float(s.get("kmove_t", 0.0))
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
		return {"clip": clip, "t": tt, "upper": up}
	if km != "":
		return {"proc": true}     # a move this Hero has no clip for: the rig plays it, with the procedural pose
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
		act_w = move_toward(act_w, 1.0, dt / FADE)
		up_w = move_toward(up_w, 0.0, dt / FADE)
	else:
		act_w = move_toward(act_w, 0.0, dt / FADE_LOCO)
		up_w = move_toward(up_w, 0.0, dt / FADE_LOCO)
		if act_w <= 0.0 and up_w <= 0.0:
			cur = ""
	xf = move_toward(xf, float(chan), dt / FADE)
	_p("act/blend_amount", xf)
	_p("upper/blend_amount", up_w)
	_p("full/blend_amount", act_w)
	_loco(s, dt)
	tree.advance(dt)
	_out(dt)

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
