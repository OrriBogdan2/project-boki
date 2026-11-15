extends RefCounted
## --boki-nap-check: a Boki's nap moves (KinNap), for both bodies.
##   1. it settles down in KinNap.SETTLE (0.6 s) at heft 1; a bigger Boki is slower, a smaller one quicker
##   2. asleep it breathes one breath per BREATH * slow and flicks an ear within TWITCH_GAP once settled
##   3. waking it is up within WAKE * UP and stretches long, low and front down, done by WAKE
##   4. a primitive body (KinPuppet) curls lower asleep and stretches long waking
##   5. a rigged body (BokiRig) plays main's settle, nap and wake clips (BokiHomeClips) at 1 / slow, and twitches
##      only ear bones the nap clip keys, so the twitch never builds up on the pose
##   6. 30 Boki napping cost under COST_MS a frame
## --boki-nap-shots --shots-dir=<dir> [--px=384]: two Boki side by side (a rigged one and a primitive one, the
## second a size bigger) awake, settling, asleep and stretching awake: <dir>/nap_pair.png. Needs a renderer.
## Never touches the save.

const STEP := 1.0 / 60.0
const COST_MS := 1.0           # ms per frame for 30 Boki's naps (one KinNap each in both drivers: 60 updates)
const RIGGED := "cindle"
const PRIMITIVE := "basaltoad"
const SHOT_AT := [["awake", 0.0], ["settling", 0.3], ["asleep", 2.0], ["stretch", 0.55]]
const BIG := 1.5               # the second Boki's scale in the shot

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BOKINAP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node, mode := "check") -> void:
	main = m
	Save.no_write = true
	if mode == "shots":
		await _shots()
		main.get_tree().quit()
		return
	_settle()
	_sleep()
	_wake()
	await _puppet()
	await _rig()
	_cost()
	print("BOKINAP DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _sized(s: float) -> Node3D:
	var n := Node3D.new()
	n.scale = Vector3.ONE * s
	return n

## Seconds of `sleep` until `done` says so, at most `cap`.
func _time_to(nap: KinNap, root: Node3D, sleep: bool, done: Callable, cap := 10.0) -> float:
	var t := 0.0
	while t < cap and not done.call():
		nap.update(root, sleep, STEP)
		t += STEP
	return t

func _settle() -> void:
	var r := _sized(1.0)
	var nap := KinNap.new("")
	var t := _time_to(nap, r, true, func() -> bool: return nap.lie >= 1.0)
	ok(absf(t - KinNap.SETTLE) <= STEP * 1.5 and is_equal_approx(nap.slow, 1.0), "heft 1 settles in %.2f s" % t)
	var big := _sized(1.8)
	var nb := KinNap.new("")
	var tb := _time_to(nb, big, true, func() -> bool: return nb.lie >= 1.0)
	var small := _sized(0.6)
	var ns := KinNap.new("")
	var ts := _time_to(ns, small, true, func() -> bool: return ns.lie >= 1.0)
	ok(tb > t + 0.1 and ts < t - 0.03, "bigger settles slower, smaller quicker: %.2f / %.2f / %.2f s" % [ts, t, tb])
	ok(tb <= KinNap.SETTLE * KinNap.SLOW_MAX + STEP * 2.0, "even the biggest is down within %.2f s" % tb)
	for n in [r, big, small]:
		n.free()

func _sleep() -> void:
	for s in [1.0, 1.8]:
		var r := _sized(s)
		var nap := KinNap.new("")
		_time_to(nap, r, true, func() -> bool: return nap.lie >= 1.0)
		var ups := 0
		var prev := nap.breath
		var top := 0.0
		var twitch_at := -1.0
		var t := 0.0
		var span := KinNap.BREATH * nap.slow * 4.0
		while t < maxf(span, KinNap.TWITCH_GAP.y * nap.slow):
			nap.update(r, true, STEP)
			t += STEP
			if prev < 0.0 and nap.breath >= 0.0 and t <= span:
				ups += 1
			prev = nap.breath
			top = maxf(top, absf(nap.breath))
			if twitch_at < 0.0 and nap.twitch > 0.0:
				twitch_at = t
		ok(ups >= 3 and ups <= 5, "scale %.1f: %d breaths in %.1f s (one per %.1f s)" % [s, ups, span, span / 4.0])
		ok(top <= KinNap.BREATH_DEPTH + 0.001 and top > KinNap.BREATH_DEPTH * 0.9, "breath depth %.3f" % top)
		ok(twitch_at > 0.0, "an ear twitches %.1f s after it settles" % twitch_at)
		r.free()

func _wake() -> void:
	var r := _sized(1.0)
	var nap := KinNap.new("")
	_time_to(nap, r, true, func() -> bool: return nap.lie >= 1.0)
	var up := _time_to(nap, r, false, func() -> bool: return nap.lie <= 0.0)
	ok(absf(up - KinNap.WAKE * KinNap.UP) <= STEP * 1.5, "up in %.2f s" % up)
	var peak := 0.0
	var low_bow := true
	var t := up
	while t < KinNap.WAKE * 1.2:
		nap.update(r, false, STEP)
		t += STEP
		peak = maxf(peak, nap.long)
		low_bow = low_bow and (nap.long <= 0.0 or (nap.low > 0.0 and nap.bow > 0.0))
	ok(peak > KinNap.STRETCH_LONG * 0.95, "stretches to %.3f of its length" % peak)
	ok(low_bow, "the stretch is low and front down all the way")
	ok(nap.long == 0.0 and nap.low == 0.0 and nap.bow == 0.0, "and stands normal again by %.1f s" % KinNap.WAKE)
	r.free()

func _puppet() -> void:
	var k := Models.kin(PRIMITIVE, {})
	main.add_child(k)
	await main.get_tree().process_frame
	var pup := _puppet_of(k)
	ok(pup != null and not k.has_node("Body/Flex/BokiRig"), "%s is a primitive body" % PRIMITIVE)
	pup.set_process(false)
	var flex: Node3D = pup.flex
	_run_pup(pup, 1.0)
	var awake_y := flex.scale.y
	var base_z := flex.scale.z
	k.set_meta("kstate", "sleep")
	_run_pup(pup, 2.0)
	ok(flex.scale.y < awake_y * 0.85, "asleep it curls lower: height %.2f of awake" % (flex.scale.y / awake_y))
	k.set_meta("kstate", "")
	_run_pup(pup, KinNap.WAKE * 0.5 * pup.nap.slow)
	ok(flex.scale.z > base_z * 1.08, "waking it stretches long: %.2f of its length" % (flex.scale.z / base_z))
	k.queue_free()

func _run_pup(pup: KinPuppet, secs: float) -> void:
	var t := 0.0
	while t < secs:
		pup._process(STEP)
		t += STEP

func _puppet_of(k: Node3D) -> KinPuppet:
	for c in k.get_children():
		if c is KinPuppet:
			return c
	return null

func _rig() -> void:
	var k := Models.kin(RIGGED, {})
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node_or_null("Body/Flex/BokiRig") as BokiRig
	ok(rig != null, "%s is a rigged body" % RIGGED)
	if rig == null:
		k.queue_free()
		return
	_puppet_of(k).set_process(false)
	rig.set_process(false)
	_run_rig(rig, 0.5)
	k.set_meta("kstate", "sleep")
	_run_rig(rig, STEP)
	ok(rig.clip == "settle", "kstate sleep plays the settle clip")
	ok(is_equal_approx(rig.player.speed_scale, 1.0 / rig._nap.slow), "at 1 / slow (%.2f)" % rig._nap.slow)
	var settle_s := rig.player.get_animation("settle").length * rig._nap.slow
	ok(absf(rig._shot_left - settle_s) < 0.001, "and holds it %.2f s" % settle_s)
	_run_rig(rig, settle_s)
	ok(rig.clip == "nap", "then the nap clip")
	ok(rig._ears.size() > 0, "%s has ear bones keyed in its nap clip: %d" % [RIGGED, rig._ears.size()])
	var t := 0.0
	while t < KinNap.SETTLE * 2.0 + KinNap.TWITCH_GAP.y * KinNap.SLOW_MAX and absf(rig._nap.twitch - 0.75) > 0.05:
		_run_rig(rig, STEP)
		t += STEP
	ok(absf(rig._nap.twitch - 0.75) <= 0.05, "an ear twitches asleep, %.1f s in" % t)
	if rig._ears.size() > 0:
		var b := rig._ears[0]
		var flicked := rig._skel.get_bone_pose_rotation(b)
		rig.player.advance(0.0)
		var clip_q := rig._skel.get_bone_pose_rotation(b)
		ok(flicked.angle_to(clip_q) > BokiRig.EAR_TWITCH * 0.8, "the flick shows: %.2f rad" % flicked.angle_to(clip_q))
		rig.player.advance(0.0)
		ok(rig._skel.get_bone_pose_rotation(b).angle_to(clip_q) < 0.001, "and the clip sets the ear back each frame")
	k.set_meta("kstate", "")
	_run_rig(rig, STEP)
	ok(rig.clip == "wake", "awake it plays the wake clip (its stretch)")
	_run_rig(rig, rig.player.get_animation("wake").length * rig._nap.slow)
	ok(rig.clip == "idle", "then idle")
	ok(rig._nap.twitch <= 0.0 or rig.clip != "nap", "no ear twitch awake")
	k.queue_free()

func _run_rig(rig: BokiRig, secs: float) -> void:
	var t := 0.0
	while t < secs:
		rig.player.advance(STEP)
		rig._process(STEP)
		t += STEP

func _cost() -> void:
	var roots: Array[Node3D] = []
	var naps: Array[KinNap] = []
	for i in 60:
		roots.append(_sized(0.7 + 0.02 * i))
		naps.append(KinNap.new(RIGGED))
	var frames := 300
	var t0 := Time.get_ticks_usec()
	for f in frames:
		for i in 60:
			naps[i].update(roots[i], f % 200 < 150, STEP)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / frames
	ok(ms < COST_MS, "30 Boki napping: %.3f ms a frame" % ms)
	for r in roots:
		r.free()

## Two Boki side by side through the nap, one picture per SHOT_AT row, left to right.
func _shots() -> void:
	var out := "/tmp/boki_nap"
	var px := 384
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--px="): px = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var vp := SubViewport.new()
	vp.size = Vector2i(px * 2, px)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(vp)
	var env := WorldEnvironment.new()
	vp.add_child(env)
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"),
		"horizon": Color("ffd2a8"), "stars": 0.0})
	Look.lights(vp, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = 26.0
	cam.position = Vector3(0, 1.4, 4.6)
	cam.look_at(Vector3(0, 0.35, 0))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("7fa860")
	ground.material_override = gm
	vp.add_child(ground)
	var pair: Array[Node3D] = [Models.kin(RIGGED, {}), Models.kin(PRIMITIVE, {})]
	pair[0].position = Vector3(-0.55, 0, 0)
	pair[1].position = Vector3(0.6, 0, 0)
	pair[1].scale *= BIG
	for k in pair:
		vp.add_child(k)
		k.rotation.y = PI - 0.5      # three-quarters toward the camera (front is -z)
	await main.get_tree().process_frame
	for k in pair:
		_puppet_of(k).set_process(false)
		var rig := k.get_node_or_null("Body/Flex/BokiRig") as BokiRig
		if rig:
			rig.set_process(false)
	var sheet := Image.create(px * 2, px * SHOT_AT.size(), false, Image.FORMAT_RGBA8)
	for i in SHOT_AT.size():
		var row: Array = SHOT_AT[i]
		var sleep := String(row[0]) in ["settling", "asleep"]
		for k in pair:
			k.set_meta("kstate", "sleep" if sleep else "")
		_step_pair(pair, float(row[1]))
		for f in 3:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, px * 2, px), Vector2i(0, i * px))
		img.save_png(out.path_join("nap_%s.png" % row[0]))
	sheet.save_png(out.path_join("nap_pair.png"))
	print("BOKI_NAP_SHOTS_DONE")

func _step_pair(pair: Array[Node3D], secs: float) -> void:
	var t := 0.0
	while t < secs:
		for k in pair:
			_puppet_of(k)._process(STEP)
			var rig := k.get_node_or_null("Body/Flex/BokiRig") as BokiRig
			if rig:
				rig.player.advance(STEP)
				rig._process(STEP)
		t += STEP
