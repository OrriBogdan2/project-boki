extends RefCounted
## --native-stream-check (docs/art/wardens/MESHY_NATIVE.md, data "stream"): a native Hunter holding a stream of shots
## (Neve's darts, one every 0.18 s, the hand alternating) on the spot and on the run. While it streams no upper-body
## bone jumps (MAX_STEP a frame: the attack clip restarting from its first frame turned the arms 20+ degrees in one
## frame; nor while it eases in or out), the hips keep their height (the attack clip's lunge dropped them 17 cm), the attack clip never takes the
## body; DONE_IN s after the last shot the pose has eased out. Prints NSTREAM lines and a DONE line.

const DT := 1.0 / 60.0
const SHOT := 0.18  # s between the stream's shots (Neve's wpn.rate)
const SECS := 1.5  # s of stream
const MAX_STEP := 6.0  # degrees an upper-body bone may turn in one frame (360 deg/s; or 1.25x the loop clip's own)
const HIPS_TOL := 0.03  # m the hips may rise or sink while it streams
const DONE_IN := 0.6  # s after the last shot the stream's pose is gone
const BONES := ["Spine02", "RightArm", "RightForeArm", "LeftArm", "LeftForeArm", "Head"]

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("NSTREAM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	var holder := Node3D.new()
	main.add_child(holder)
	var any := false
	for a in Arch.ids():
		if not WardenNative.on(a) or not WardenNative.entry(WardenGlb.art(a)).has("stream"):
			continue
		any = true
		for vel in [Vector3.ZERO, Vector3(0, 0, -4.6)]:
			var m := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", PlayerLook.neutral(), a)
			holder.add_child(m)
			await main.get_tree().process_frame
			_stream(a, m, vel)
			m.free()
	ok(any, "a native Hunter has a stream (Neve)")
	print("NSTREAM DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _stream(a: String, m: Node3D, vel: Vector3) -> void:
	var nat := m.get_node("Warden/Native") as WardenNative
	nat.set_process(false)
	var moves: Array = nat.d["stream"]["kmoves"]
	var sk := nat.skel
	var ids := BONES.map(func(b): return sk.find_bone(b))
	var hips := sk.find_bone("Hips")
	var base := {"grounded": true, "cast": 99.0, "vel": vel, "kmove": "", "kmove_t": 99.0, "recoil": 0.0}
	var prev := _rots(sk, ids)
	var own := 0.0  # degrees a frame the loop clip itself turns them (a run swings the arms)
	for i in 60:
		_feed(m, nat, base)
		var was: Array = prev
		prev = _rots(sk, ids)
		for k in ids.size():
			own = maxf(own, rad_to_deg((was[k] as Quaternion).angle_to(prev[k])) if i > 0 else 0.0)
	var y0 := sk.get_bone_pose_position(hips).y
	var worst := 0.0
	var sink := 0.0
	var took := false
	var t := 0.0
	var n := 0
	while t < SECS:
		var s := base.duplicate()
		var since := fmod(t, SHOT)
		s["kmove"] = moves[int(t / SHOT) % 2]
		s["kmove_t"] = since
		s["recoil"] = float(int(t / SHOT) + 1)
		_feed(m, nat, s)
		var now := _rots(sk, ids)
		for k in ids.size():
			worst = maxf(worst, rad_to_deg((prev[k] as Quaternion).angle_to(now[k])))
		prev = now
		sink = maxf(sink, absf(sk.get_bone_pose_position(hips).y - y0)) if vel == Vector3.ZERO else sink
		took = took or nat.player.current_animation == String(nat.plays["attack"])
		t += DT
		n += 1
	var after := base.merged({"kmove": moves[0], "kmove_t": SHOT}, true)
	var left := DONE_IN
	while left > 0.0:  # (the ease out is held to the same per-frame step)
		after["kmove_t"] = float(after["kmove_t"]) + DT
		_feed(m, nat, after)
		var now := _rots(sk, ids)
		for k in ids.size():
			worst = maxf(worst, rad_to_deg((prev[k] as Quaternion).angle_to(now[k])))
		prev = now
		left -= DT
	var how := "standing" if vel == Vector3.ZERO else "running"
	ok(
		worst <= maxf(MAX_STEP, own * 1.25),
		"%s %s: no upper-body bone jumps (worst %.1f deg a frame, the loop's own %.1f)" % [a, how, worst, own]
	)
	ok(sink <= HIPS_TOL, "%s %s: the hips hold their height (%.3f m)" % [a, how, sink])
	ok(not took, "%s %s: the attack clip never takes the body over %d frames" % [a, how, n])
	ok(nat.upper.w <= 0.0, "%s %s: %.1f s after the last shot the stream's pose has eased out" % [a, how, DONE_IN])


func _feed(m: Node3D, nat: WardenNative, s: Dictionary) -> void:
	m.set_meta(WardenClips.STATE, s)
	nat._process(DT)


func _rots(sk: Skeleton3D, ids: Array) -> Array:
	return ids.map(func(b): return sk.get_bone_pose_rotation(b))
