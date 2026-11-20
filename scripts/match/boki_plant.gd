class_name BokiPlant
extends RefCounted
## A rigged Boki's planted paws in its walk or run (docs/art/kin/RIGGED_BOKI.md "Planted paws"). The clips swing
## each leg from the hip on a sine, so a paw on the ground slows to a stop at both ends of its step and no single
## clip rate keeps it still. BokiRig re-times each leg's bones on their own: the stance moves the paw back at the
## ground's speed, evenly, and the swing brings it forward in the time left. Only the timing changes, so each
## species' clips and BokiRig.STRIDE stay as they are. One per species and clip, shared by every Boki of it.

const SAMPLES := 48           # poses per loop read to find each paw's step
const DUTY_MIN := 0.25        # of a step: the shortest a paw stays down (a gallop's), once the clip is at full cadence
const DUTY_MAX := 0.75        # of a step: the longest (a slow stroll's), so the swing keeps time to lift the paw
const STEP_MIN := 0.1         # m/s at clip speed 1: a paw sweeping back slower than this is folded, not stepping
const REPEAT := 0.05          # of its reach: a paw back this close a part-loop on is stepping again (a scurry)
const NOT_LEG := ["root", "hips", "spine", "neck", "head"]

## One leg: its bones, and when and where the clip moves its paw back.
class Leg:
	var bones := PackedInt32Array()     # the leg's bones with a rotation track, hip to paw
	var tracks := PackedInt32Array()    # each one's rotation track
	var base := -1                      # the body bone the leg hangs from
	var period := 0.0                   # s of clip per step: the loop, or a part of it for a scurry
	var span := 0.0                     # m (model scale 1) the paw moves back while it is down
	var front := 0.0                    # s into the clip the paw lands, furthest forward
	var stance := 0.0                   # s of clip the paw takes to move back
	var reach := PackedVector3Array()   # the paw from `base` at each sample of its stance
	var at := 0.0                       # pose()'s clip time for the leg this frame

var anim: Animation
var legs: Array[Leg] = []
var _to_model := Transform3D.IDENTITY # skeleton space to the model's
var _h := 0.0                         # s between samples

static var _cache := {}       # "species clip" -> BokiPlant

## The planted paws of `species`' `clip` in `model`, read from the clip once per species.
static func of(species: String, model: Node3D, skel: Skeleton3D, clip: String) -> BokiPlant:
	var key := "%s %s" % [species, clip]
	if not _cache.has(key):
		_cache[key] = BokiPlant.new(model, skel, model.find_child("AnimationPlayer", true, false).get_animation(clip))
	return _cache[key]

func _init(model: Node3D, skel: Skeleton3D, clip_anim: Animation) -> void:
	anim = clip_anim
	_h = anim.length / SAMPLES
	var n: Node = skel
	while n != model:
		_to_model = (n as Node3D).transform * _to_model
		n = n.get_parent()
	var tracks := _bone_tracks()
	for paw in skel.get_bone_count():
		if skel.get_bone_name(paw).contains("paw"):
			var leg := _leg(skel, paw, tracks)
			if leg:
				legs.append(leg)

## Bone name -> [position, rotation, scale] track (-1 without one).
func _bone_tracks() -> Dictionary:
	var out := {}
	for t in anim.get_track_count():
		var at := [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D].find(
				anim.track_get_type(t))
		if at < 0:
			continue
		var bone := String(anim.track_get_path(t).get_concatenated_subnames())
		if not out.has(bone):
			out[bone] = [-1, -1, -1]
		out[bone][at] = t
	return out

## The leg ending in `paw`, or null when its paw does not step.
func _leg(skel: Skeleton3D, paw: int, tracks: Dictionary) -> Leg:
	var leg := Leg.new()
	leg.base = paw
	while leg.base >= 0 and not skel.get_bone_name(leg.base) in NOT_LEG:
		var rot: int = tracks.get(skel.get_bone_name(leg.base), [-1, -1, -1])[1]
		if rot >= 0:
			leg.bones.insert(0, leg.base)
			leg.tracks.insert(0, rot)
		leg.base = skel.get_bone_parent(leg.base)
	if leg.bones.is_empty() or leg.base < 0:
		return null
	var path: Array[Vector3] = []     # in the model
	var hung: Array[Vector3] = []     # from the base
	for i in SAMPLES:
		var body := _bone_at(skel, leg.base, tracks, i * _h)
		var foot := _bone_at(skel, paw, tracks, i * _h).origin
		path.append(_to_model * foot)
		hung.append(body.affine_inverse() * foot)
	var each := SAMPLES / _steps_per_loop(hung)
	var front := 0
	var back := 0
	for i in each:
		front = i if path[i].z < path[front].z else front
		back = i if path[i].z > path[back].z else back
	var count := posmod(back - front, each)
	leg.period = each * _h
	leg.front = front * _h
	leg.stance = count * _h
	leg.span = path[back].z - path[front].z
	if count < 2 or leg.span / leg.stance < STEP_MIN or not _one_sweep(path.slice(0, each), front, count):
		return null
	for i in count + 1:
		leg.reach.append(hung[(front + i) % each])
	return leg

## How many steps a leg takes per loop of the clip (a scurry steps more than once), from its paw's path: 1 to 3.
static func _steps_per_loop(path: Array[Vector3]) -> int:
	var reach := 0.0
	for p in path:
		reach = maxf(reach, p.distance_to(path[0]))
	for n in [3, 2]:
		var off: int = SAMPLES / n
		var same := true
		for i in SAMPLES:
			same = same and path[i].distance_to(path[(i + off) % SAMPLES]) < REPEAT * reach
		if same:
			return n
	return 1

## True when the paw only moves back from `front` for `count` samples and only forward the rest of its step (by up
## to REPEAT of its reach): one stance and one swing, which re-timing can even out. A hop or a shuffle is left be.
static func _one_sweep(path: Array[Vector3], front: int, count: int) -> bool:
	var n := path.size()
	var slack := REPEAT * (path[(front + count) % n].z - path[front].z)
	for i in n:
		var dz := path[(front + i + 1) % n].z - path[(front + i) % n].z
		if (dz < -slack if i < count else dz > slack):
			return false
	return true

## The skeleton-space pose of `bone` at `t` s into the clip, from its tracks and its ancestors'.
func _bone_at(skel: Skeleton3D, bone: int, tracks: Dictionary, t: float) -> Transform3D:
	var rest := skel.get_bone_rest(bone)
	var own: Array = tracks.get(skel.get_bone_name(bone), [-1, -1, -1])
	var pos: Vector3 = rest.origin if own[0] < 0 else anim.position_track_interpolate(own[0], t)
	var rot: Quaternion = rest.basis.get_rotation_quaternion() if own[1] < 0 \
			else anim.rotation_track_interpolate(own[1], t)
	var scl: Vector3 = rest.basis.get_scale() if own[2] < 0 else anim.scale_track_interpolate(own[2], t)
	var local := Transform3D(Basis(rot).scaled(scl), pos)
	var parent := skel.get_bone_parent(bone)
	return local if parent < 0 else _bone_at(skel, parent, tracks, t) * local

## Poses the legs at `at` s into the clip, which plays at `rate` x while the body moves at `speed` m/s at world scale
## `grown`, over the clip's own pose by `weight`. Per frame: no allocation.
func pose(skel: Skeleton3D, at: float, rate: float, speed: float, grown: float, weight: float) -> void:
	for leg in legs:            # every leg's time first, while the body bones they hang from are still the clip's
		var each := leg.period
		# s of clip the paw stays down so it moves back at `speed`
		var down := clampf(leg.span * grown * rate / maxf(speed, 0.01), DUTY_MIN * each, DUTY_MAX * each)
		var since := fposmod(at - leg.front - (leg.stance - down) * 0.5, each)
		var t := leg.front + leg.stance + (since - down) / (each - down) * (each - leg.stance)
		if since < down:
			t = leg.front + _stance_time(skel, leg, since / down)
		leg.at = fposmod(t, each)        # every step of the leg is the same, so the first one stands for them all
	for leg in legs:
		for b in leg.bones.size():
			var q := anim.rotation_track_interpolate(leg.tracks[b], leg.at)
			if weight < 1.0:
				q = skel.get_bone_pose_rotation(leg.bones[b]).slerp(q, weight)
			skel.set_bone_pose_rotation(leg.bones[b], q)

## s of clip past the landing at which the paw is `part` of the way back, evenly, from where the body is now: the
## body bones keep the clip's own time, so the paw is found against them.
func _stance_time(skel: Skeleton3D, leg: Leg, part: float) -> float:
	var body := _to_model * skel.get_bone_global_pose(leg.base)
	var lo := 0
	var hi := leg.reach.size() - 1
	var goal := lerpf((body * leg.reach[lo]).z, (body * leg.reach[hi]).z, part)
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if (body * leg.reach[mid]).z < goal:
			lo = mid
		else:
			hi = mid
	var z_lo := (body * leg.reach[lo]).z
	var z_hi := (body * leg.reach[hi]).z
	return (lo + clampf((goal - z_lo) / maxf(z_hi - z_lo, 0.00001), 0.0, 1.0)) * _h
