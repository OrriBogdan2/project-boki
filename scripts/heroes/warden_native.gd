class_name WardenNative
extends Node
## A Hunter drawn on Meshy's own skeleton and playing Meshy's own clips (docs/art/wardens/MESHY_NATIVE.md). Only the
## Hunters switched on in content/rules/warden_native.json ("meshy_native") take this path; every other one keeps the
## contract model (WardenGlb, WardenSync, WardenClips) untouched. Meshy's bones are never renamed, retargeted or merged
## onto the contract: the clips play on them as Meshy keyed them, and the contract's procedural bone layers (springs,
## orbits, carry, look-at, drop pose, squash) are not built. The contract's anchor empties hang on Meshy's bones as
## BoneAttachment3D nodes (data "anchors"), and the weapon's aim node rides Meshy's hand bone. HunterAnim still runs
## on the hidden rig and hands over its state (WardenClips.STATE) each frame.

const DATA_PATH := "res://content/rules/warden_native.json"
const META := "meshy_native"  # root meta: this Hunter is drawn on Meshy's skeleton
const STILL := 0.25  # m/s: below this he is standing
const FADE := 0.15  # s: one clip into the next
const RATE_MIN := 0.6  # the walk, run and sneak clips' slowest rate, of their keyed pace
const RATE_MAX := 1.8  # and their fastest: a quicker stride keeps the feet nearer the ground speed
const ATTACK_AGAIN := 0.6  # share of the attack clip after which a new hit starts it over
const LOOPS := ["idle", "walk", "run", "crouch"]
static var _data = null  # art name -> its entry (parsed once)

var root: Node3D
var player: AnimationPlayer
var d: Dictionary
var skel: Skeleton3D
var hand := -1  # Meshy's weapon-hand bone (data "hand"): the rig's Gun follows it
var gun: Node3D
var built := 0  # the rig weapon last hidden (instance id): Hunter.equip rebuilds it
var cur := ""  # the game state playing ("idle", "walk", ...)
var attack_left := 0.0  # s the attack clip still owns the body
var last := {"kmove": "", "swing_n": 0, "cast": INF, "recoil": 0.0}


## The art's entry in warden_native.json ({} when it has none).
static func entry(art_name: String) -> Dictionary:
	if _data == null:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return (_data as Dictionary).get(art_name, {})


## Whether this archetype's Hunter is switched onto Meshy's own skeleton (and its file is there).
static func on(arch: String) -> bool:
	var e := entry(WardenGlb.art(arch))
	return bool(e.get("meshy_native", false)) and ResourceLoader.exists(file(arch))


## The Meshy-skeleton .glb, beside the contract one: art/wardens/<art>/<art>_meshy.glb.
static func file(arch: String) -> String:
	var nm := WardenGlb.art(arch)
	return "%s/%s/%s_meshy.glb" % [WardenGlb.DIR, nm, nm]


## Dresses the procedural hunter `model` (built rig-only) in its Meshy model; the rig stays as HunterAnim's state.
static func dress(model: Node3D, arch: String, scene: PackedScene) -> void:
	var e := entry(WardenGlb.art(arch))
	var glb := scene.instantiate() as Node3D
	glb.name = "Warden"
	glb.rotation.y = PI  # (Meshy faces +Z; a Hunter's model faces -Z)
	glb.scale = Vector3.ONE * float(e.get("scale", 1.0))
	model.add_child(glb)
	var nat := WardenNative.new()
	nat.name = "Native"
	nat.setup(model, glb, e)
	glb.add_child(nat)
	model.set_meta(META, true)


func setup(model: Node3D, glb: Node3D, data: Dictionary) -> void:
	root = model
	d = data
	process_priority = 10  # (after Match renders the hunters: HunterAnim.update)
	player = glb.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var clips: Dictionary = d["clips"]
	for st in LOOPS:
		player.get_animation(String(clips[st])).loop_mode = Animation.LOOP_LINEAR
	skel = WardenGlb.skeleton(glb)
	hand = skel.find_bone(String(d.get("hand", "RightHand")))
	var anchors: Dictionary = d.get("anchors", {})
	for an in anchors:
		var at := BoneAttachment3D.new()
		at.name = String(an)
		at.bone_name = String(anchors[an])
		skel.add_child(at)
	gun = root.get_node_or_null("Rig/Torso/Aim/Gun") as Node3D
	_play("idle", 1.0)


func _process(dt: float) -> void:
	_hide_rig_weapon()
	var s: Dictionary = root.get_meta(WardenClips.STATE, {})
	attack_left -= dt
	if _attacked(s):
		attack_left = _clip_len("attack") / float(d.get("attack_rate", 1.0))
		_play("attack", float(d.get("attack_rate", 1.0)), true)
	elif attack_left <= 0.0:
		_loco(s)
	if gun and gun.is_inside_tree() and hand >= 0:
		gun.global_position = hand_position()


## Meshy's weapon hand this frame (world), from the pose the clip just set: an attachment would follow a frame late.
func hand_position() -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(hand).origin


## The clip for standing, moving, crouching and the air, at a rate that follows the ground speed.
func _loco(s: Dictionary) -> void:
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var ground := Vector2(vel.x, vel.z).length()
	if bool(s.get("dead", false)):
		_play("idle", 0.0)
	elif not bool(s.get("grounded", true)):
		_play("jump", float(d.get("jump_rate", 1.0)))
	elif float(s.get("crouch", 0.0)) > 0.5:
		_play("crouch", _rate(ground, "crouch_mps", 0.0))
	elif ground >= float(d.get("run_from", 3.0)):
		_play("run", _rate(ground, "run_mps", RATE_MIN))
	elif ground >= STILL:
		_play("walk", _rate(ground, "walk_mps", RATE_MIN))
	else:
		_play("idle", 1.0)


## A new hit, cast or kit move this frame (state counters moved on since the last frame).
func _attacked(s: Dictionary) -> bool:
	var now := {
		"kmove": String(s.get("kmove", "")),
		"swing_n": int(s.get("swing_n", 0)),
		"cast": float(s.get("cast", INF)),
		"recoil": float(s.get("recoil", 0.0)),
	}
	var hit: bool = (
		(now["kmove"] != "" and now["kmove"] != last["kmove"])
		or now["swing_n"] != last["swing_n"]
		or now["cast"] < last["cast"]
		or now["recoil"] > last["recoil"]
	)
	last = now
	var fresh := attack_left <= _clip_len("attack") * (1.0 - ATTACK_AGAIN) / float(d.get("attack_rate", 1.0))
	return hit and fresh


## The loop's rate for this ground speed against the speed it was keyed at (data, m/s), clamped to the clip's range.
func _rate(ground: float, key: String, lo: float) -> float:
	return clampf(ground / float(d.get(key, 1.5)), lo, RATE_MAX)


func _clip_len(st: String) -> float:
	return player.get_animation(String(d["clips"][st])).length


## The game state's clip, crossfaded in when it changes (restart: a new attack plays it from the start).
func _play(st: String, rate: float, restart := false) -> void:
	if st != cur or restart:
		player.play(String(d["clips"][st]), FADE)
		if restart:
			player.seek(0.0, true)
		cur = st
	player.speed_scale = rate


## Meshy's model carries its weapon in the mesh: the rig's procedural weapon stays hidden, even after a re-equip.
func _hide_rig_weapon() -> void:
	if gun == null or gun.get_child_count() == 0:
		return
	var id := gun.get_child(gun.get_child_count() - 1).get_instance_id()
	if id != built:
		built = id
		WardenGlb._skinned_weapon(root)
