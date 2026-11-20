extends RefCounted
## The hand-over from a knocked-down Hunter's body to its Wisp, read frame by frame (--wisp-check): from the knock
## to a quarter second after the Wisp takes over, in every pose the hunter can be hit in (standing, running,
## gliding, in its own ultimate). Every frame must show the hero or the Wisp (never neither), the hero in a clip's
## pose (never the rig's bind/T-pose), and each of them near the hunter (never a mesh left at the world origin).

const DT := 1.0 / 60.0
const TAIL := 0.25            # s after the beat ends that are still read
const SEEN := 0.98            # transparency above this: the hero is gone; a Wisp fade below 1 - this: no Wisp
const BIND_EPS := 0.02        # rad / m a bone must be off its rest pose by in at least one bone
const NEAR := 2.5             # m the body or the Wisp may be from where the hunter went down or now is
const GLIDE_UP := 20.0        # m above the ground the glide start is teleported to
const POSES := ["idle", "run", "glide", "ult"]

var m: Match
var step_hook: Callable       # (p: Hunter) -> void: steps the hunter's clips (wisp_check's _sync)
var found: Array[String] = []  # one line per broken frame: "<hero> <pose> t=<s>: what"
var ult_cast := 0              # how many heroes had an ultimate running when they were knocked
var frames := 0
var _kinds := {}              # the kinds of break already recorded in this knock


func _init(match_: Match, sync: Callable) -> void:
	m = match_
	step_hook = sync


## Knocks `p` down from `pose`, reads every frame of the swap. `at`: where the hunter stands up.
func scan(p: Hunter, foe: Hunter, at: Vector3, pose: String) -> void:
	p.pos = at
	p.prev = at
	p.hp = p.max_hp
	p.down_hp = 1e6
	_pose_up(p, pose)
	m.knock(p, foe, {})
	var fall := HunterFall.of(p)
	_kinds.clear()
	var t := 0.0
	var end := 1.0
	while t < end:
		_frame(p, pose)
		t += DT
		fall = fall if fall else HunterFall.of(p)
		if fall and end == 1.0:
			end = fall.time + TAIL
		_read(p, fall, "%s %s t=%.2f" % [p.ak.id, pose, t])
	m.revive_hunter(p, null)
	for i in 40:
		_frame(p, "idle")
	p.inp["move"] = Vector2.ZERO


func _pose_up(p: Hunter, pose: String) -> void:
	for i in 6:
		_frame(p, "idle")
	if pose == "glide":
		p.teleport(p.pos + Vector3(0, GLIDE_UP, 0))
	elif pose == "ult":
		p.ult = 1.0
		p.ak.cd["x"] = 0.0
		ult_cast += 1 if p.ak.cast_ult() else 0
	for i in 12:
		_frame(p, pose)


func _frame(p: Hunter, pose: String) -> void:
	if pose == "run" or pose == "glide":
		p.inp["move"] = Vector2(1, 0)
		p.inp["aim"] = p.pos + Vector3(8, 0.9, 0)
	if pose == "glide":
		p.inp["jump"] = false
		p.inp["glide"] = true
		p.inp["glide_btn"] = true
	Sfx.listener = p.pos
	m.step(DT)
	for h in m.hunters:
		h.render(DT, 1.0)
	step_hook.call(p)
	frames += 1


func _read(p: Hunter, fall: HunterFall, tag: String) -> void:
	var wisp := HunterWisp.node_of(p)
	var body_on := _body_shown(p)
	var wisp_on := _wisp_shown(wisp)
	var anchor: Vector3 = Vector3(fall.from.x, p.position.y, fall.from.z) if fall else p.position
	if not body_on and not wisp_on:
		_flag(tag, "neither the body nor the Wisp shows (mode %s)" % HunterWisp.mode_of(p))
	if body_on and _bind_pose(p):
		_flag(tag, "the body is in its bind/T-pose")
	if body_on and _far(_centre(p), p.position, anchor):
		_flag(tag, "the body is far from the hunter (%.1f m)" % _centre(p).distance_to(p.position))
	if wisp_on and _far(wisp.global_position, p.position, anchor):
		_flag(tag, "the Wisp is far from the hunter (%.1f m)" % wisp.global_position.distance_to(p.position))


## Records a broken frame; the first of each kind in a knock is enough.
func _flag(tag: String, what: String) -> void:
	var line := "%s: %s" % [tag, what]
	var kind := what.get_slice(" (", 0)
	if not _kinds.has(kind):
		_kinds[kind] = true
		found.append(line)


static func _far(at: Vector3, here: Vector3, there: Vector3) -> bool:
	return at.distance_to(here) > NEAR and at.distance_to(there) > NEAR


func _meshes(p: Hunter) -> Array:
	return p.model.find_children("*", "MeshInstance3D", true, false) if p.model else []


func _body_shown(p: Hunter) -> bool:
	if not p.visible or p.model == null or not p.model.visible:
		return false
	for mesh in _meshes(p):
		var gi := mesh as GeometryInstance3D
		if gi.visible and gi.transparency < SEEN:
			return true
	return false


static func _wisp_shown(wisp: Node3D) -> bool:
	if wisp == null or not wisp.is_inside_tree() or not wisp.is_visible_in_tree():
		return false
	var mat := wisp.get_meta("mat") as ShaderMaterial
	return wisp.scale.x > 0.05 and float(mat.get_shader_parameter("fade")) > 1.0 - SEEN


## Where the body is: the middle of its bones (a skinned mesh's own node stays where the rig was imported).
func _centre(p: Hunter) -> Vector3:
	var skel := _skeleton(p)
	if skel == null or skel.get_bone_count() == 0:
		return p.model.global_position
	var sum := Vector3.ZERO
	for i in skel.get_bone_count():
		sum += (skel.global_transform * skel.get_bone_global_pose(i)).origin
	return sum / skel.get_bone_count()


## The hero's rig: the skeleton with the most bones.
func _skeleton(p: Hunter) -> Skeleton3D:
	var best: Skeleton3D = null
	for s in p.model.find_children("*", "Skeleton3D", true, false):
		if best == null or (s as Skeleton3D).get_bone_count() > best.get_bone_count():
			best = s
	return best


## Every bone of the rig sits on its rest pose: nothing is playing.
func _bind_pose(p: Hunter) -> bool:
	var skel := _skeleton(p)
	if skel == null:
		return false
	for i in skel.get_bone_count():
		var pose := skel.get_bone_pose(i)
		var rest := skel.get_bone_rest(i)
		if pose.origin.distance_to(rest.origin) > BIND_EPS or pose.basis.get_rotation_quaternion().angle_to(
				rest.basis.get_rotation_quaternion()) > BIND_EPS:
			return false
	return true
