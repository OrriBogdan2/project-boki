extends RefCounted
## --warden-stance-check: every Warden stands in its own signature stance (content/rules/warden_stance.json,
## WardenStance). Each of the 12 has one; standing, no spine is straight (a lean or a hip shift over the
## thresholds); every pair of stances differs; the idle cycle moves (the breath, a weight shift, the
## signature fidget within the limit); the stance applies on the procedural model (the pose differs from the
## same Warden with none); and firing brings the weapon up to the same aim as with no stance. A Warden whose
## 3D model (.glb) loads is checked on its armature too: the stance moves its bones. Never touches the save.

const DT := 1.0 / 60.0
const SETTLE := 3.0            # s standing before the stance is measured (before any fidget)
const CYCLE := 16.0            # s of idle watched for the breath, the weight shift and the fidget
const AIM_T := 0.3             # s after a shot when the aim is compared
const AIM_DIR_MAX := 0.12      # rad: the muzzle's direction, stance against none, once aimed
const CARRY_GONE := 0.05       # the carry's weight this soon after a shot
const BONE_MIN := 0.03         # rad: how far the stance must turn the 3D model's hips bone

var bad := 0
var holder: Node3D
var tree: SceneTree

func ok(cond: bool, what: String) -> void:
	print("STANCECHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	tree = main.get_tree()
	holder = Node3D.new()
	main.add_child(holder)
	var lim: Dictionary = Content.rules(WardenStance.RULES)["check"]
	var ids := Arch.ids()
	ok(ids.size() == 12, "12 Wardens (%d)" % ids.size())
	var poses := {}
	for id in ids:
		ok(WardenStance.new(id).has_stance(), "%s has a stance" % id)
		poses[id] = await _warden(String(id), lim)
	var worst := INF
	var pair := ""
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var d := _dist(poses[ids[i]], poses[ids[j]])
			if d < worst:
				worst = d
				pair = "%s / %s" % [ids[i], ids[j]]
	ok(worst > float(lim["min_diff"]), "every pair of stances differs: closest %s by %.3f (> %.2f)"
			% [pair, worst, float(lim["min_diff"])])
	print("WARDEN STANCE CHECK DONE, failures: ", bad)
	tree.quit(1 if bad > 0 else 0)

## One Warden: the stance measured standing, against none, through the idle cycle and on firing.
func _warden(id: String, lim: Dictionary) -> PackedFloat32Array:
	var with := _model(id)
	var none := _model(id)
	none[0].ws = WardenStance.new("")
	await _idle([with, none], SETTLE)
	var pose := _pose(with)
	var torso := (with[0] as HunterAnim).torso
	var rig := (with[0] as HunterAnim).rig
	var up := (rig.basis * torso.basis).y.normalized()
	var lean := up.angle_to(Vector3.UP)
	var shift := absf(rig.position.x)
	var straight := lean < float(lim["min_spine"]) and shift < float(lim["min_hip"])
	ok(not straight, "%s: standing spine %.3f rad off upright, hips %.3f m over (>= %.2f or >= %.2f)"
			% [id, lean, shift, float(lim["min_spine"]), float(lim["min_hip"])])
	if id == "archer":
		# owner item 114: Lisette stands upright with her weight forward, never leaning back, the bow low
		var ref := (none[0] as HunterAnim)
		var up0 := (ref.rig.basis * ref.torso.basis).y.normalized()
		var tip := up.dot(Vector3.BACK) - up0.dot(Vector3.BACK)
		ok(tip < -0.1 and lean < 0.35, "archer: the torso pitched forward (%.3f), %.3f rad off upright (under 0.35)"
				% [tip, lean])
		var carry: Array = Content.rules(WardenStance.RULES)["archer"]["pose"]["carry"]["pos"]
		ok(float(carry[1]) <= -0.35, "archer: the bow carried low (%.2f m)" % float(carry[1]))
	var applied := _dist(pose, _pose(none))
	ok(applied > float(lim["min_diff"]), "%s: the stance moves the procedural model by %.3f" % [id, applied])
	await _glb(id, with, none)
	await _cycle(id, with, float(lim["fidget_within"]))
	await _fire(id, with, none)
	(with[1] as Node3D).queue_free()
	(none[1] as Node3D).queue_free()
	return pose

func _model(id: String) -> Array:
	var h := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", {}, id)
	h.set_meta("anim_seed", 7)
	holder.add_child(h)
	return [HunterAnim.new(h), h]

## Animates the models standing for `secs` (fired: seconds since a shot).
func _idle(models: Array, secs: float, fired := 99.0) -> void:
	var n := int(secs / DT)
	for k in n:
		for m in models:
			(m[0] as HunterAnim).update(DT, {"fired": fired + k * DT, "grounded": true, "face": 0.0})
		if k % 30 == 0:
			await tree.process_frame

## The pose in numbers: the torso's and head's turns, the rig's offset, the legs, and the weapon's place.
func _pose(m: Array) -> PackedFloat32Array:
	var a: HunterAnim = m[0]
	var out := PackedFloat32Array()
	for v in [a.torso.rotation, a.rig.position * 4.0, a.head.rotation, a.leg_l.rotation, a.leg_r.rotation]:
		out.append_array([v.x, v.y, v.z])
	out.append_array([a.knee_l.rotation.x, a.knee_r.rotation.x])
	if a.gun:
		var g := _in_model(m, a.gun).origin * 2.0
		out.append_array([g.x, g.y, g.z])
	return out

func _dist(p: PackedFloat32Array, q: PackedFloat32Array) -> float:
	var s := 0.0
	for i in mini(p.size(), q.size()):
		s += (p[i] - q[i]) * (p[i] - q[i])
	return sqrt(s)

func _in_model(m: Array, n: Node3D) -> Transform3D:
	return (m[1] as Node3D).global_transform.affine_inverse() * n.global_transform

## The idle cycle: the breath, the weight leaving the signature leg and coming back, the fidget in time.
func _cycle(id: String, m: Array, within: float) -> void:
	var a: HunterAnim = m[0]
	var lo := INF
	var hi := -INF
	var side0 := signf(a.weight)
	var shifted := false
	var fid_at := -1.0
	var n := int(CYCLE / DT)
	for k in n:
		a.update(DT, {"fired": 99.0, "grounded": true, "face": 0.0})
		lo = minf(lo, a.torso.scale.y)
		hi = maxf(hi, a.torso.scale.y)
		shifted = shifted or signf(a.weight) != side0
		if fid_at < 0.0 and a.ws.fidgets > 0:
			fid_at = SETTLE + k * DT
	ok(hi - lo > 0.005, "%s: breathes (torso height moves %.4f)" % [id, hi - lo])
	ok(shifted, "%s: the weight shifts to the other leg within %.0f s" % [id, SETTLE + CYCLE])
	ok(fid_at > 0.0 and fid_at <= within, "%s: the signature fidget plays at %.1f s (<= %.0f s)" % [id, fid_at, within])

## Firing: the carry gives way at once and the muzzle points where it does with no stance.
func _fire(id: String, with: Array, none: Array) -> void:
	await _idle([with, none], 0.1, 0.0)
	var cw := (with[0] as HunterAnim).ws.carry_w
	ok(cw < CARRY_GONE, "%s: 0.1 s after a shot the carry is %.3f (< %.2f)" % [id, cw, CARRY_GONE])
	await _idle([with, none], AIM_T - 0.1, 0.1)
	var g1: Node3D = (with[0] as HunterAnim).gun
	var g0: Node3D = (none[0] as HunterAnim).gun
	if g1 == null or (with[0] as HunterAnim).hold in ["sword", "great", "twin"]:
		return
	var d1 := -_in_model(with, g1).basis.z
	var d0 := -_in_model(none, g0).basis.z
	var off := d1.angle_to(d0)
	ok(off < AIM_DIR_MAX, "%s: aimed, the muzzle is %.3f rad off the no-stance aim (< %.2f)" % [id, off, AIM_DIR_MAX])

## A Warden dressed in its 3D model (a .glb, when it loads): the stance turns the armature's hips.
func _glb(id: String, with: Array, none: Array) -> void:
	var w := (with[1] as Node3D).get_node_or_null("Warden")
	var w0 := (none[1] as Node3D).get_node_or_null("Warden")
	if w == null or w0 == null or not WardenClips.data(WardenGlb.art(id)).is_empty():
		return      # (a Hero with hand-keyed clips: its stance is the clip, --clip-check)
	await tree.process_frame
	var s1 := w.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var s0 := w0.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var bone := s1.find_bone("hips")
	var turn := s1.get_bone_global_pose(bone).basis.get_rotation_quaternion().angle_to(
			s0.get_bone_global_pose(bone).basis.get_rotation_quaternion())
	ok(turn > BONE_MIN, "%s: on the 3D model the stance turns the hips bone %.3f rad (> %.2f)" % [id, turn, BONE_MIN])
