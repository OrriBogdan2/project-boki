class_name WardenArmRaise
extends RefCounted
## An arm a held clip keys too low, raised (Albert's aegis, owner 11-26: his own wooden shield pulled up in front of
## him). While one of the data's clips plays, a two-bone reach puts the wrist at the data's point and the hand keeps
## the clip's own turn, so what rides it (his shield on x_shield) still faces the way the clip holds it.
## Data "arm_raise": {"clips": [clip, ...], "bones": [upper arm, forearm, hand], "hand": [x, y, z] (skeleton units,
## the wrist off the shoulder), "pole": [x, y, z] (the way the elbow bends out)}.

const RATE := 12.0  # 1/s: the arm eases up into the raise and back to the clips (0.08 s)

var skel: Skeleton3D
var clips: Array = []
var bones: Array = []  # [upper arm, forearm, hand] bone indices
var hand := Vector3.ZERO
var pole := Vector3.ZERO
var w := 0.0  # how much the raise owns the arm


## Null when the data has no "arm_raise".
static func make(sk: Skeleton3D, d: Dictionary) -> WardenArmRaise:
	var rd: Dictionary = d.get("arm_raise", {})
	if rd.is_empty():
		return null
	var r := WardenArmRaise.new()
	r.skel = sk
	r.clips = rd["clips"]
	for b in rd["bones"]:
		r.bones.append(WardenSkeleton.find(sk, String(b)))
	if r.bones.has(-1):
		return null
	r.hand = Vector3(rd["hand"][0], rd["hand"][1], rd["hand"][2])
	r.pole = Vector3(rd["pole"][0], rd["pole"][1], rd["pole"][2]).normalized()
	return r


## After the clips. `clip`: the move that is playing ("" when none).
func apply(dt: float, clip: String) -> void:
	w = move_toward(w, 1.0 if clips.has(clip) else 0.0, RATE * dt)
	if w <= 0.0:
		return
	var now: Array = bones.map(func(bi: int) -> Transform3D: return skel.get_bone_global_pose(bi))
	var shoulder: Vector3 = now[0].origin
	var upper_len := shoulder.distance_to(now[1].origin)
	var fore_len := (now[1].origin as Vector3).distance_to(now[2].origin)
	var reach := clampf(hand.length(), absf(upper_len - fore_len) + 0.001, upper_len + fore_len - 0.001)
	var dir := hand.normalized()
	# (the elbow's angle off the shoulder-to-wrist line, law of cosines; it bends out toward the pole)
	var cos_a := (upper_len * upper_len + reach * reach - fore_len * fore_len) / (2.0 * upper_len * reach)
	var out := (pole - dir * pole.dot(dir)).normalized()
	var elbow := shoulder + (dir * cos_a + out * sqrt(maxf(0.0, 1.0 - cos_a * cos_a))) * upper_len
	var wrist := shoulder + dir * reach
	_lay(bones[0], now[0], shoulder, elbow - shoulder)
	_lay(bones[1], now[1], elbow, wrist - elbow)
	skel.set_bone_global_pose(bones[2], now[2].interpolate_with(Transform3D(now[2].basis, wrist), w))


## Bone `bi` (the clip's pose `now`) laid at `at` along `along_to` (its +Y), turned the shortest way so it keeps the
## clip's roll; mixed over the clip's pose by `w`.
func _lay(bi: int, now: Transform3D, at: Vector3, along_to: Vector3) -> void:
	var along := now.basis.y.normalized()
	var to := along_to.normalized()
	var turn := Basis(Quaternion(along, to)) if along.dot(to) > -0.999 else Basis(now.basis.x.normalized(), PI)
	skel.set_bone_global_pose(bi, now.interpolate_with(Transform3D(turn * now.basis, at), w))
