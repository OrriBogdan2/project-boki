class_name BokiHomeClips
extends RefCounted
## Runtime clips for a rigged Boki's life at home (no Blender): settle, nap, wake, munch, nudge, climb, splash.
## Each is the species' baked idle (or sleep) with BokiHomePoses' deltas laid over it, sampled into a new Animation,
## so every Boki keeps its own rest shape and idle motion. Built once per species and shared.

const NAMES := ["settle", "nap", "wake", "munch", "nudge", "climb", "splash"]
const LOOPED := ["nap", "munch", "nudge", "climb", "splash"]
const SETTLE_SECS := 1.5
const WAKE_SECS := 1.7
const STEP := 0.05                  # s between keys
const ROT := Animation.TYPE_ROTATION_3D
const POS := Animation.TYPE_POSITION_3D
const SCL := Animation.TYPE_SCALE_3D

static var _cache := {}             # species -> {clip: Animation}

static func install(species: String, player: AnimationPlayer, skel: Skeleton3D) -> void:
	if not _cache.has(species):
		_cache[species] = _build(species, player, skel)
	var lib := player.get_animation_library(&"")
	for n in _cache[species]:
		if not lib.has_animation(n):
			lib.add_animation(n, _cache[species][n])

static func _build(species: String, player: AnimationPlayer, skel: Skeleton3D) -> Dictionary:
	var names := {}
	for i in skel.get_bone_count():
		names[skel.get_bone_name(i)] = i
	var idle := player.get_animation("idle")
	var sleep := player.get_animation("sleep")
	var pose := BokiHomePoses.new(names, species)
	var il := idle.length
	var out := {}
	out["settle"] = _clip(skel, pose, "settle", idle, sleep, SETTLE_SECS)
	out["wake"] = _clip(skel, pose, "wake", sleep, idle, WAKE_SECS)
	out["nap"] = _clip(skel, pose, "nap", sleep, null, sleep.length)
	for n in ["munch", "nudge", "climb", "splash"]:
		out[n] = _clip(skel, pose, n, idle, null, il, BokiHomePoses.cycles(n, il))
	return out

## `a` is the base (and `b` what it turns into over the clip, for settle and wake).
static func _clip(skel: Skeleton3D, pose: BokiHomePoses, which: String, a: Animation, b: Animation, length: float,
		beats := 1) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if which in LOOPED else Animation.LOOP_NONE
	var n := maxi(2, ceili(length / STEP) + 1)
	var poses := []
	for i in n:
		pose.at(which, float(i) / float(n - 1), beats)
		poses.append([pose.d.duplicate(), pose.move, pose.squash])
	var seen := {}
	for src in [a, b]:
		if src == null:
			continue
		for t in src.get_track_count():
			var key := "%d|%s" % [src.track_get_type(t), src.track_get_path(t)]
			if seen.has(key) or src.track_get_type(t) not in [ROT, POS, SCL]:
				continue
			seen[key] = true
			_track(anim, skel, src.track_get_type(t), src.track_get_path(t), a, b, length, n, poses)
	# a bone the base never animates but the pose moves
	var prefix := String(a.track_get_path(0)).get_slice(":", 0)
	for bone in pose.names:
		if not seen.has("%d|%s:%s" % [ROT, prefix, bone]) and poses.any(func(p: Array) -> bool: return p[0].has(bone)):
			_track(anim, skel, ROT, NodePath("%s:%s" % [prefix, bone]), a, b, length, n, poses)
	return anim

static func _track(anim: Animation, skel: Skeleton3D, type: int, path: NodePath, a: Animation, b: Animation,
		length: float, n: int, poses: Array) -> void:
	var bone := String(path).get_slice(":", 1)
	var id := skel.find_bone(bone)
	if id < 0:
		return
	var parent := skel.get_bone_parent(id)
	var pg := skel.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
	var rest := skel.get_bone_rest(id)
	var ta := _find(a, path, type)
	var tb := _find(b, path, type) if b else -1
	var idx := anim.add_track(type)
	anim.track_set_path(idx, path)
	var is_root: bool = bone == "root"
	var moving: bool = is_root or poses.any(func(p: Array) -> bool: return p[0].has(bone))
	var still := ta >= 0 and a.track_get_key_count(ta) == 1 and (b == null or tb < 0 or b.track_get_key_count(tb) == 1)
	for i in (1 if still and not moving else n):
		var t := length * float(i) / float(n - 1)
		var u := float(i) / float(n - 1)
		var delta: Vector3 = poses[i][0].get(bone, Vector3.ZERO)
		var w := 0.0
		if b:
			w = smoothstep(0.0, 1.0, u)
		var at_b := fposmod(t - length, b.length) if b else 0.0       # b ends on its own start, so the next clip joins
		match type:
			ROT:
				var q := _rot(a, ta, t, rest.basis.get_rotation_quaternion())
				if b:
					q = q.slerp(_rot(b, tb, at_b, rest.basis.get_rotation_quaternion()), w)
				if delta != Vector3.ZERO:
					q = Quaternion(pg.inverse() * Basis.from_euler(delta) * pg) * q
				anim.rotation_track_insert_key(idx, t, q)
			POS:
				var v := _vec(a, ta, t, rest.origin, POS)
				if b:
					v = v.lerp(_vec(b, tb, at_b, rest.origin, POS), w)
				if is_root:
					v += poses[i][1]
				anim.position_track_insert_key(idx, t, v)
			_:
				var s := _vec(a, ta, t, rest.basis.get_scale(), SCL)
				if b:
					s = s.lerp(_vec(b, tb, at_b, rest.basis.get_scale(), SCL), w)
				if is_root:
					s *= poses[i][2]
				anim.scale_track_insert_key(idx, t, s)

static func _find(anim: Animation, path: NodePath, type: int) -> int:
	return anim.find_track(path, type) if anim else -1

static func _rot(anim: Animation, tr: int, at: float, rest: Quaternion) -> Quaternion:
	return anim.rotation_track_interpolate(tr, fposmod(at, anim.length)) if tr >= 0 else rest

static func _vec(anim: Animation, tr: int, at: float, rest: Vector3, type: int) -> Vector3:
	if tr < 0:
		return rest
	var t := fposmod(at, anim.length)
	return anim.position_track_interpolate(tr, t) if type == POS else anim.scale_track_interpolate(tr, t)
