extends RefCounted
## --revive-bake --wardens=<art>,<art> --out=<dir>: keys a Hero's `revive` loop (the reviver's clip, played while
## standing on a teammate's Wisp) on its own crouch_idle: the torso leans over a Wisp at its hover height, both
## hands go onto its near top (a two-bone solve, elbows out) and press on a slow beat, the head looks down at it.
## Writes <dir>/<art>_revive.json (30 fps local bone keys, last frame = first); tools/art1/glb_add_clips.py puts
## it in the .glb. The 9 Heroes whose `revive` was the downed get-up (decision 0019 retired that) come from here.
## Never touches the save.

const FPS := 30
const WISP_HOVER := 0.4        # m: the Wisp's centre over the ground (content/rules/wisp_looks.json, default)
const WISP_R := 0.26           # m: its round body's half height (radius 0.3 x squash 0.85)
const HAND_GAP := 0.11         # m: each hand this far off the Wisp's centre line
const NEAR := 0.2              # m: the hands on its near side, this far short of its centre
const MIN_AHEAD := 0.35        # m: the hands at least this far ahead (the Wisp clears his knees)
const REACH := 0.86            # of the arm's length: the hands reach, the elbows stay soft
const LEAN := 0.42             # rad: the torso over the Wisp (more if the hands still fall short)
const BEAT := 1.05             # s: about one press per this (the loop holds a whole number of them)
const PUSH := 0.3              # of a beat: the push in; the rest lets go
const PRESS_M := 0.035         # m: how far a press pushes the hands into the Wisp
const PRESS_LEAN := 0.05       # rad: the torso goes with it
const HEAD_DOWN := 0.3         # rad: the head looks down at it

var bad := 0

func run(main: Node) -> void:
	Save.no_write = true
	var out := "user://revive_bake"
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		if a.begins_with("--wardens="): only = a.substr(10).split(",")
	DirAccess.make_dir_recursive_absolute(out)
	var holder := Node3D.new()
	main.add_child(holder)
	for id in Arch.ids():
		var art_name := WardenGlb.art(String(id))
		if art_name in only:
			_bake(holder, String(id), art_name, out)
	print("REVIVE_BAKE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _bake(holder: Node3D, id: String, art_name: String, out: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var dd := WardenClips.data(art_name)
	var base := clips.lib.get_animation(String(dd["crouch"]["idle"]))
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var to_sk := sk.global_transform.affine_inverse()
	var fwd := (to_sk.basis * Vector3.FORWARD).normalized()
	var up := (to_sk.basis * Vector3.UP).normalized()
	var beats := maxi(1, roundi(base.length / BEAT))
	var hover = null      # (a hover: the root's pose the Rig gives it, as Sync plays the clips)
	if bool(dd.get("rig_root", false)):
		clips.force = {"clip": String(dd["crouch"]["idle"]), "t": 0.0}
		for k in 10:
			sync.call("_process", 1.0 / FPS)
		hover = sk.get_bone_pose(WardenSkeleton.find(sk, "root"))
	var fit := _fit(sk, base, to_sk, fwd, up, hover)
	var bones := {}        # bone -> keys its position too
	for b in ["hips", "head", "upper_arm.L", "forearm.L", "upper_arm.R", "forearm.R"]:
		bones[sk.get_bone_name(WardenSkeleton.find(sk, b))] = false
	for tr in base.get_track_count():
		var b := String(base.track_get_path(tr).get_concatenated_subnames())
		bones[b] = bones.get(b, false) or base.track_get_type(tr) == Animation.TYPE_POSITION_3D
	var keys := {}
	var n := roundi(base.length * FPS)
	for i in n + 1:
		var t := base.length * float(i % n) / n      # (the last frame is the first: the loop closes)
		var ph := fmod(beats * t / base.length, 1.0)
		var press := smoothstep(0.0, 1.0, ph / PUSH)
		if ph >= PUSH:
			press = 1.0 - smoothstep(0.0, 1.0, (ph - PUSH) / (1.0 - PUSH))
		_pose(sk, base, t, fit, press, to_sk, fwd, up)
		for b in bones:
			var bi := sk.find_bone(String(b))
			var q := sk.get_bone_pose_rotation(bi)
			if not keys.has(b):
				keys[b] = {"rotation": []}
				if bones[b]:
					keys[b]["translation"] = []
			keys[b]["rotation"].append([q.x, q.y, q.z, q.w])
			if bones[b]:
				var p := sk.get_bone_pose_position(bi)
				keys[b]["translation"].append([p.x, p.y, p.z])
	var f := FileAccess.open("%s/%s_revive.json" % [out, art_name], FileAccess.WRITE)
	f.store_string(JSON.stringify({"name": "revive", "fps": FPS, "frames": n + 1, "bones": keys}))
	print("REVIVE_BAKE %s (%s): %.2f s, %d beats, Wisp %.2f m ahead, hands at %.2f m, lean %.2f rad, reach off %.2f" % [
			id, art_name, base.length, beats, float(fit["d"]) + NEAR, fit["h"], fit["lean"], fit["want"]])
	if float(fit["want"]) > 0.03:
		bad += 1
	m.free()

## Where the hands go (their distance ahead, kept so the Wisp clears his knees, and their height: its top, or its
## side for a Hero smaller than it) and how far he leans so both hands reach it at REACH of the arm.
func _fit(sk: Skeleton3D, base: Animation, to_sk: Transform3D, fwd: Vector3, up: Vector3, hover: Variant) -> Dictionary:
	var best := {}
	for h in [WISP_HOVER + WISP_R * 0.6, WISP_HOVER + WISP_R * 0.3, WISP_HOVER]:
		for li in 7:
			var lean := LEAN + 0.08 * li
			for di in 16:
				var fit := {"d": MIN_AHEAD + 0.05 * di, "lean": lean, "h": h}
				if hover != null:
					fit["root"] = hover
				var want := absf(_pose(sk, base, 0.0, fit, 0.0, to_sk, fwd, up))
				if best.is_empty() or want < float(best["want"]) - 0.005:
					best = fit
					best["want"] = want
			if float(best["want"]) < 0.01:
				return best
	return best

## The crouch at t, leaned and with both hands on the Wisp. Returns how much further the hands would have to
## reach than REACH of the arm (negative: the arms bunch up).
func _pose(sk: Skeleton3D, base: Animation, t: float, fit: Dictionary, press: float, to_sk: Transform3D,
		fwd: Vector3, up: Vector3) -> float:
	sk.reset_bone_poses()
	for tr in base.get_track_count():
		var bi := sk.find_bone(String(base.track_get_path(tr).get_concatenated_subnames()))
		match base.track_get_type(tr):
			Animation.TYPE_ROTATION_3D: sk.set_bone_pose_rotation(bi, base.rotation_track_interpolate(tr, t))
			Animation.TYPE_POSITION_3D: sk.set_bone_pose_position(bi, base.position_track_interpolate(tr, t))
			Animation.TYPE_SCALE_3D: sk.set_bone_pose_scale(bi, base.scale_track_interpolate(tr, t))
	if fit.has("root"):
		sk.set_bone_pose(WardenSkeleton.find(sk, "root"), fit["root"])     # (data "rig_root": the Rig holds it up)
	var side := up.cross(fwd).normalized()      # (his left)
	_turn(sk, WardenSkeleton.find(sk, "hips"), Basis(side, float(fit["lean"]) + PRESS_LEAN * press))
	_turn(sk, WardenSkeleton.find(sk, "head"), Basis(side, HEAD_DOWN))
	var wisp := to_sk * Vector3(0, float(fit["h"]) - PRESS_M * press, -float(fit["d"]))
	var short := -INF
	for s in ["L", "R"]:
		var toward := side if s == "L" else -side
		var hand := wisp + toward * HAND_GAP * to_sk.basis.get_scale().x
		short = maxf(short, _reach(sk, s, hand, toward, fwd, up))
	return short

## Rotates bone bi by `by` in skeleton space about its own head.
func _turn(sk: Skeleton3D, bi: int, by: Basis) -> void:
	var g := sk.get_bone_global_pose(bi)
	g.basis = by * g.basis
	sk.set_bone_global_pose(bi, g)

## A two-bone solve: the upper arm and forearm put the hand on `at`, the elbow out to the side and up.
func _reach(sk: Skeleton3D, s: String, at: Vector3, out_dir: Vector3, fwd: Vector3, up: Vector3) -> float:
	var ua := WardenSkeleton.find(sk, "upper_arm." + s)
	var fa := WardenSkeleton.find(sk, "forearm." + s)
	var hd := WardenSkeleton.find(sk, "hand." + s)
	var a := sk.get_bone_global_pose(ua).origin
	var l1 := a.distance_to(sk.get_bone_global_pose(fa).origin)
	var l2 := sk.get_bone_global_pose(fa).origin.distance_to(sk.get_bone_global_pose(hd).origin)
	var want := a.distance_to(at)
	var short := want - REACH * (l1 + l2)
	var d := clampf(want, absf(l1 - l2) + 0.001, (l1 + l2) * 0.999)
	var u := (at - a).normalized()
	var pole := out_dir * 0.8 + up * 0.3 - fwd * 0.2
	var p := (pole - u * pole.dot(u)).normalized()
	var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var elbow := a + u * along + p * sqrt(maxf(l1 * l1 - along * along, 0.0))
	_aim(sk, ua, sk.get_bone_global_pose(fa).origin, elbow)
	_aim(sk, fa, sk.get_bone_global_pose(hd).origin, a + u * d)
	return short

## Turns bone bi about its head so the point `from` (a child's head) goes to `to`.
func _aim(sk: Skeleton3D, bi: int, from: Vector3, to: Vector3) -> void:
	var o := sk.get_bone_global_pose(bi).origin
	var v1 := (from - o).normalized()
	var v2 := (to - o).normalized()
	if v1.cross(v2).length() < 1e-5:
		return
	_turn(sk, bi, Basis(Quaternion(v1, v2)))
