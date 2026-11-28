extends "res://tools/warden_shots.gd"
## --held-props-check: every prop the native path hangs on a hand from attach data (warden_native.json "props" /
## "grip" / "holster": Kael's sword, Gil's swordfish, Grimble's gun) against the hand that holds it, in idle, run,
## LMB and the held abilities. Per pose: the prop's length as a fraction of the hunter's height (vs its 2D
## reference, +/-25%), the fist's distance to the prop's surface (float), the fist's distance to the prop's long
## axis (a gripped haft passes through the fist) and the angle between the haft and the knuckle line (a haft
## across the knuckles sits in the palm; one at 90 deg goes through the back of the hand). Works headless.
## --held-props-shots --shots-dir=<dir>: the same poses as close shots at the hand, <dir>/<id>_<pose>.png
## (front and side), one sheet per hunter. Before/after for a socket change is two runs of this.

const IDS := ["juggernaut", "gil", "dredge"]
## Length reference: prop length / hunter height in the owner-picked 2D art (DECISIONS: the size follows the splash).
## Kael: guard-to-tip 0.61 (kael_v2 sheet and splash; item 131b). Gil: tail stalk to bill tip, juggernaut splash
## (art/portraits/gil_splash.jpg, his lunge): fish ~370 px vs his standing ~520 px with the hat = 0.71 overall.
## Grimble: his splash and sheet show no gun (0 = no reference, length is reported only).
const REF := {"juggernaut": 0.61, "gil": 0.71, "dredge": 0.0}
const TOL := 0.25                # +/- of the reference
const FLOAT_CM := 3.0            # the fist further than this from the prop's surface: it floats
const AXIS_CM := 5.0             # a haft's axis further than this from the fist: not in the palm
const CROSS_DEG := 50.0          # the haft this far off the knuckle line: through the hand, not across the palm
const HOLD_POSES := {
	"juggernaut": [["idle", {}], ["run", {"vel": 4.6}], ["LMB 1", {"kmove": "jug_slash_r", "kmove_t": 0.1}],
		["LMB 2", {"kmove": "jug_slash_l", "kmove_t": 0.1}], ["Lunge hold", {"kmove": "jug_lunge_wind", "kmove_t": 0.45}],
		["Lunge", {"kmove": "jug_lunge", "kmove_t": 0.2}], ["Slam", {"kmove": "jug_slam", "kmove_t": 0.7}],
		["Rampage", {"kmove": "jug_dash", "kmove_t": 0.38}], ["Guard", {"kmove": "jug_guard", "kmove_t": 0.36}]],
	"gil": [["idle", {}], ["run", {"vel": 4.6}], ["LMB thrust", {"kmove": "gil_thrust_1", "kmove_t": 0.08}],
		["LMB lunge", {"kmove": "gil_lunge", "kmove_t": 0.12}], ["RMB toss", {"kmove": "gil_throw", "kmove_t": 0.16}],
		["E spin", {"kmove": "gil_spin", "kmove_t": 0.2}], ["R surf", {"kmove": "gil_surf", "kmove_t": 0.2}]],
	"dredge": [["idle", {}], ["run", {"vel": 4.6}], ["LMB fire", {"fired": 0.05}], ["LMB run fire", {"fired": 0.05,
		"vel": 4.6}], ["LMB fire late", {"fired": 0.3}]],
}
const HANDS := {"juggernaut": "RightHand", "gil": "RightHand", "dredge": "LeftHand"}  # warden_native.json "hand"
const PALM := 0.25               # forearm lengths from the wrist to the palm's middle (a rig without finger bones)
const GRIP_TIP := 20.0           # deg: the hilt across the knuckles, tipped this far toward the fingers
const GRIP_PER_BLADE := 0.25     # Kael's hilt behind the guard per blade length (kael_pieces: 0.15 / 0.61)
const FIST_AT := 0.75            # the fist's middle: this far from the wrist to the middle knuckle
const MAX_VERTS := 4000          # vertices sampled per prop

var fails := 0
var rows: Array = []             # [id, pose, len frac, ref, surf cm, axis cm, cross deg, verdict]

func run(main: Node, mode: String = "check") -> void:
	tree = main.get_tree()
	var out := ""
	var only: Array = IDS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--wardens="):
			only = Array(a.substr(10).split(","))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_stage(main)
	for id in only:
		await _hero(String(id), out if mode == "shots" else "", "")
	print("held-props-check: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	if mode == "shots":
		print("HELD_PROPS_SHOTS_DONE")
	tree.quit()

func _hero(id: String, out: String, _sheets: String) -> void:
	var h := _row(id, 1)[0] as Node3D
	h.rotation.y = PI
	await _settle(30)
	var sk := _skel(h)
	var hand_name := String(HANDS[id])
	var tall := _height(h)
	var frames: Array = []
	for p in HOLD_POSES.get(id, []):
		if (p[1] as Dictionary).has("kmove") and HunterAnim.km_def(String(p[1]["kmove"])).is_empty():
			print("HELD %-10s %-12s no such kit move %s" % [id, p[0], p[1]["kmove"]])
			continue
		for k in 70:
			_step(h, p[1])
		await tree.process_frame
		await tree.process_frame
		var props := _props(h)
		if props.is_empty():
			print("HELD %-10s %-12s no prop drawn" % [id, p[0]])
			rows.append([id, p[0], 0.0, REF[id], -1.0, -1.0, -1.0, "none"])
			continue
		var m := _measure(sk, hand_name, props)
		if id == "dredge" and not (p[1] as Dictionary).has("fired"):
			# (at rest Grimble's gun rides the hip socket, WardenGunProp: no hand to measure)
			print("HELD %-10s %-12s gun on the hip (len %.3f m)" % [id, p[0], m[0]])
			if out != "":
				frames.append([p[0], await _hand_shots(h, sk, hand_name, tall)])
			continue
		var frac := float(m[0]) / tall
		var ref := float(REF[id])
		var bad: Array = []
		if ref > 0.0 and absf(frac - ref) > ref * TOL:
			bad.append("length")
		if float(m[1]) > FLOAT_CM:
			bad.append("float")
		if id != "dredge" and float(m[2]) > AXIS_CM:
			bad.append("off-palm")
		if float(m[3]) > CROSS_DEG:
			bad.append("through-hand")
		var v := "ok" if bad.is_empty() else ",".join(bad)
		print("HELD %-10s %-12s len %.3f m = %.3f of %.2f m (ref %.2f) fist-surface %.1f cm, fist-axis %.1f cm, haft-knuckles %.0f deg: %s"
				% [id, p[0], m[0], frac, tall, ref, m[1], m[2], m[3], v])
		rows.append([id, p[0], frac, ref, m[1], m[2], m[3], v])
		if not bad.is_empty():
			fails += 1
		if out != "":
			frames.append([p[0], await _hand_shots(h, sk, hand_name, tall)])
		if p[0] == "idle" and "--held-frame" in OS.get_cmdline_user_args():
			print("HELD frame %s aabb %s" % [props[0].name, (props[0] as MeshInstance3D).mesh.get_aabb()])
		if p[0] == "idle" and "--held-fit" in OS.get_cmdline_user_args():
			_fit_grip(sk, hand_name, props[0])
	if out != "" and not frames.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		_sheet(frames).save_png(out.path_join(id + "_hand.png"))
	_clear()
	await tree.process_frame

func _step(h: Node3D, st: Dictionary) -> void:
	var fwd := Vector3(-sin(h.rotation.y), 0, -cos(h.rotation.y))
	var s := {"fired": 99.0, "face": h.rotation.y, "grounded": true}
	s.merge(st, true)
	if st.has("vel"):
		s["vel"] = fwd * float(st["vel"])
	(anims[0][0] as HunterAnim).update(1.0 / 60.0, s)

## The skeleton the hands are on: the one carrying the hand bone that is drawn (a model can hold a hidden one).
func _skel(h: Node3D) -> Skeleton3D:
	var best: Skeleton3D = null
	for n in h.find_children("*", "Skeleton3D", true, false):
		var sk := n as Skeleton3D
		if best == null and sk.is_visible_in_tree() and sk.find_bone("RightHand") >= 0:
			best = sk
	return best

## The hunter's standing height (m): the bounds of the skinned body meshes (hair and hat included).
func _height(h: Node3D) -> float:
	var box := AABB()
	var first := true
	for n in h.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		# (the skinned body only: FX cards and the team ring are not the hunter)
		if not mi.is_visible_in_tree() or mi.mesh == null or _is_prop(mi) or not (mi.get_parent() is Skeleton3D):
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.size.y

func _is_prop(mi: Node) -> bool:
	var n: Node = mi
	while n != null:
		if String(n.name).begins_with(WardenProps.PREFIX) or n.name == &"DredgeGun":
			return true
		n = n.get_parent()
	return false

func _props(h: Node3D) -> Array:
	var out: Array = []
	for n in h.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh != null and mi.is_visible_in_tree() and _is_prop(mi) and mi.global_transform.basis.get_scale().x > 0.01:
			out.append(mi)
	return out

## A bone's head in world space, read through a BoneAttachment3D as the props are (after the skeleton's modifiers).
func _bone_at(sk: Skeleton3D, bone: String) -> Vector3:
	var i := sk.find_bone(bone)
	if i < 0:
		return Vector3.INF
	var key := "probe_" + bone.validate_node_name()
	var at := sk.get_node_or_null(key) as BoneAttachment3D
	if at == null:
		at = BoneAttachment3D.new()
		at.name = key
		at.bone_name = bone
		sk.add_child(at)
		at.on_skeleton_update()
	return at.global_position

## [length m, fist->surface cm, fist->axis cm, haft vs knuckle line deg]
func _measure(sk: Skeleton3D, hand: String, props: Array) -> Array:
	var pts := PackedVector3Array()
	for mi: MeshInstance3D in props:
		for s in mi.mesh.get_surface_count():
			var v: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var stride := maxi(1, v.size() / MAX_VERTS)
			for i in range(0, v.size(), stride):
				pts.append(mi.global_transform * v[i])
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= maxf(1.0, pts.size())
	# long axis: the farthest point from the centre, then the farthest from that (two-pass diameter)
	var a := c
	for p in pts:
		if p.distance_squared_to(c) > a.distance_squared_to(c):
			a = p
	var b := a
	for p in pts:
		if p.distance_squared_to(a) > b.distance_squared_to(a):
			b = p
	var axis := (b - a).normalized()
	var length := a.distance_to(b)
	var blade_dir := Vector3.ZERO
	# (a sword's FX empties ride it, WardenProps: its blade, guard to tip, is what the art's size is measured on)
	for mi: MeshInstance3D in props:
		var r := mi.find_child("anchor_blade_root", true, false) as Node3D
		var t := mi.find_child(WardenGlb.WEAPON_MUZZLE, true, false) as Node3D
		if r != null and t != null:
			length = r.global_position.distance_to(t.global_position)
			blade_dir = (t.global_position - r.global_position).normalized()
			c = r.global_position
	var hh := _bone_at(sk, hand)
	var mid := _bone_at(sk, hand + "Middle1")
	var idx := _bone_at(sk, hand + "Index1")
	var pinky := _bone_at(sk, hand + "Pinky1")
	var fist := hh.lerp(mid, FIST_AT)
	if mid == Vector3.INF:
		# (no finger bones, Meshy's plain rig: the palm's middle lies on along the forearm's line, a quarter forearm out)
		var hi := sk.find_bone(hand)
		var fore := hh.distance_to(_bone_at(sk, sk.get_bone_name(sk.get_bone_parent(hi))))
		var along := (hh - _bone_at(sk, sk.get_bone_name(sk.get_bone_parent(hi)))).normalized()  # (the forearm's line)
		fist = hh + along * fore * PALM
	var surf := INF
	for p in pts:
		surf = minf(surf, p.distance_to(fist))
	# (the haft's line: the sword's blade root -> tip, else the tip-to-tail diameter)
	if blade_dir != Vector3.ZERO:
		axis = blade_dir
	var on := Geometry3D.get_closest_point_to_segment(fist, c - axis * length, c + axis * length)
	var cross := -1.0  # (no finger bones: no knuckle line)
	if idx != Vector3.INF and pinky != Vector3.INF:
		cross = rad_to_deg(acos(clampf(absf(axis.dot((idx - pinky).normalized())), 0.0, 1.0)))
	return [length, surf * 100.0, fist.distance_to(on) * 100.0, cross]

## --held-fit: the "grip" data (WardenProps) that lays a sword's hilt across the knuckle line, tipped GRIP_TIP toward
## the fingers (a diagonal hammer grip), its middle at the fist, with the blade out of the thumb side. Prints it.
func _fit_grip(sk: Skeleton3D, hand: String, mi: MeshInstance3D) -> void:
	var r := mi.find_child("anchor_blade_root", true, false) as Node3D
	var t := mi.find_child(WardenGlb.WEAPON_MUZZLE, true, false) as Node3D
	var idx := _bone_at(sk, hand + "Index1")
	if r == null or t == null or idx == Vector3.INF:
		print("HELD fit: needs a blade's anchors and finger bones")
		return
	var at := mi.get_parent() as Node3D
	var to_b := at.global_transform.affine_inverse()
	var hh := to_b * _bone_at(sk, hand)
	var mid := to_b * _bone_at(sk, hand + "Middle1")
	var knuck := (to_b * idx - to_b * _bone_at(sk, hand + "Pinky1")).normalized()
	var fwd := (mid - hh).normalized()
	var want := (knuck * cos(deg_to_rad(GRIP_TIP)) + fwd * sin(deg_to_rad(GRIP_TIP))).normalized()
	var now := (to_b * t.global_position - to_b * r.global_position).normalized()
	var ax := now.cross(want)
	var turn := ax.normalized() * now.angle_to(want) if ax.length() > 0.0001 else Vector3.ZERO
	# (the hilt's middle, in the part's frame, under the base turn the part has before "grip")
	var hilt := r.position + (r.position - t.position) * GRIP_PER_BLADE * 0.5
	var fist := hh.lerp(mid, FIST_AT)
	print("HELD fit %s: \"grip\": {\"part\": [%.4f, %.4f, %.4f], \"bone\": [%.4f, %.4f, %.4f], \"turn\": [%.4f, %.4f, %.4f]}"
			% [mi.name, hilt.x, hilt.y, hilt.z, fist.x, fist.y, fist.z, turn.x, turn.y, turn.z])

## Front and side close shots at the hand.
func _hand_shots(h: Node3D, sk: Skeleton3D, hand: String, tall: float) -> Image:
	var at := _bone_at(sk, hand)
	var mid := _bone_at(sk, hand + "Middle1")
	if mid != Vector3.INF:
		at = at.lerp(mid, FIST_AT)
	var imgs: Array = []
	# (front, then from the holding hand's own side)
	var side := -PI * 0.5 if hand.begins_with("Right") else PI * 0.5
	for yaw in [0.0, side]:
		var dir := Vector3(sin(h.rotation.y + PI + yaw), 0.3, cos(h.rotation.y + PI + yaw)).normalized()
		cam.fov = 40.0
		cam.global_position = at + dir * tall * 0.55
		cam.look_at(at, Vector3.UP)
		await tree.process_frame
		await tree.process_frame
		var img := tree.root.get_viewport().get_texture().get_image()
		var sq := mini(img.get_width(), img.get_height())
		img = img.get_region(Rect2i((img.get_width() - sq) / 2, (img.get_height() - sq) / 2, sq, sq))
		img.resize(400, 400)
		img.convert(Image.FORMAT_RGB8)
		imgs.append(img)
	var both := Image.create(800, 400, false, Image.FORMAT_RGB8)
	both.blit_rect(imgs[0], Rect2i(0, 0, 400, 400), Vector2i(0, 0))
	both.blit_rect(imgs[1], Rect2i(0, 0, 400, 400), Vector2i(400, 0))
	return both

func _sheet(frames: Array) -> Image:
	var out := Image.create(800, 400 * frames.size(), false, Image.FORMAT_RGB8)
	for i in frames.size():
		var img := frames[i][1] as Image
		img.convert(Image.FORMAT_RGB8)
		out.blit_rect(img, Rect2i(0, 0, 800, 400), Vector2i(0, 400 * i))
	return out
