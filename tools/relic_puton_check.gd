extends RefCounted
## --relic-puton-check: putting on a Relic is one short beat (MaskBeat):
##   1. the first time, played through: reach (the arm comes up, the Relic glides to the face), flicker (the
##      ghost face lights three times), fade (the Hunter comes in from the feet up while the Empty goes the same
##      way, then idles), in that order and about 5 s in all (BEAT_S); the name and title come up and stay up
##      long enough to read (3 s or more)
##   2. the farm's cut (no swap) ends after the flicker and keeps the body you had
##   3. the next time any key skips it straight to the end
##   4. its sounds follow the beats, never the clock: a chime on each of the three flickers (at the flicker's
##      own fractions, rising in pitch), the swell begins with the fade and rises through it, the settle ends
##      it; the same fractions whether stepped in 4 ms or 50 ms frames; the farm's cut chimes and settles
##      without the swell; a skip makes no sound
## With --shots-dir=<dir>: puton_1_reach, _2_flicker, _3_fade_feet, _4_fade_half, _5_done (a renderer is needed).

const BEAT_S := Vector2(4.5, 5.5)   # s: the whole beat, slow enough to read

var main: Node
var bad := 0
var shots := ""
var host: Node3D
var scene_cam: Camera3D

func ok(cond: bool, what: String) -> void:
	print("PUTON %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	if main.fade:
		main.fade.reveal(0.05)
	await _first_time()
	await _farm()
	await _skip()
	await _sounds()
	print("PUTON DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A stage: a lit floor, a camera, and you (the Empty) facing it with Vex's Relic hovering beside your face.
func _stage() -> Array:
	host = Node3D.new()
	main.add_child(host)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	host.add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = Models.flat_quad(30.0)
	ground.material_override = Models.toon(Color("4d6b3e"))
	host.add_child(ground)
	scene_cam = Camera3D.new()
	host.add_child(scene_cam)
	scene_cam.global_transform = Transform3D(Basis(), Vector3(0.4, 1.5, 3.2)).looking_at(Vector3(0, 1.0, 0))
	scene_cam.current = true
	var you := Models.hunter(Data.class_of_save(), Data.TEAM_COLORS[0], "", "", Unmasked.default_look())
	you.rotation.y = PI
	host.add_child(you)
	var relic := MaskRelic.make("gunslinger")
	host.add_child(relic)
	relic.global_position = (you.get_node("Rig/Torso/HeadPivot") as Node3D).global_position + Vector3(0.55, -0.1, 0.6)
	return [you, relic]

func _first_time() -> void:
	var tree := main.get_tree()
	var parts := _stage()
	var you: Node3D = parts[0]
	var relic: MaskRelic = parts[1]
	var arm := you.get_node("Rig/Torso/ArmRPivot") as Node3D
	var arm_rest := arm.rotation.x
	var got := [null]
	Save.d["tutorial"]["mask_seen"] = false
	var beat := MaskBeat.play(relic, you, func(b): got[0] = b)
	ok(not MaskBeat.seen() and beat.skip_hint == null, "the first time: no skip hint")
	var planned := MaskBeat.REACH_S + MaskBeat.FLICKER_S + MaskBeat.FADE_S
	ok(planned >= BEAT_S.x and planned <= BEAT_S.y, "the planned beats add up to %.1f s (%.1f-%.1f)" % [planned,
			BEAT_S.x, BEAT_S.y])
	var order: Array = []
	var lit := 0
	var was_lit := false
	var arm_top := arm_rest
	var feet_first := false
	var hunter: Node3D = beat._hunter
	var anim: HunterAnim = beat._anim
	var parts_h: Array = beat._to_tiers
	var t0 := 0
	var name_t0 := 0
	var shot_done := {}
	while is_instance_valid(beat) and beat.phase != "done":
		await tree.process_frame
		if not is_instance_valid(beat):
			break
		if order.is_empty() or order[-1] != beat.phase:
			order.append(beat.phase)
			if t0 == 0:
				t0 = Time.get_ticks_msec()
		arm_top = maxf(arm_top, arm.rotation.x) if is_instance_valid(arm) else arm_top
		if is_instance_valid(beat._ghost):
			var a := ((beat._ghost.material_override as ShaderMaterial).get_shader_parameter("color") as Color).a
			if a > 0.3 and not was_lit:
				lit += 1
			was_lit = a > 0.3
		if name_t0 == 0 and _has_name():
			name_t0 = Time.get_ticks_msec()
		if beat.phase == "fade" and not feet_first:
			feet_first = _feet_first(parts_h)
		await _strip(beat, shot_done)
	await tree.process_frame
	var total_s := (Time.get_ticks_msec() - t0) / 1000.0
	ok(order == ["reach", "flicker", "fade"], "the beats run in order: %s" % str(order))
	ok((total_s >= BEAT_S.x and total_s <= BEAT_S.y + 0.3) or shots != "",
			"all of it in %.2f s (frame grabs slow a strip)" % total_s)
	ok(arm_top > arm_rest + 1.0, "the hand reaches out (arm up %.2f rad)" % (arm_top - arm_rest))
	ok(lit == MaskBeat.FLICKERS, "the ghost face flickers %d times" % lit)
	ok(feet_first, "the Hunter comes in from the feet up")
	ok(got[0] == hunter and is_instance_valid(hunter) and not is_instance_valid(you) and not is_instance_valid(relic),
			"the Relic is spent, the Empty is gone, the Hunter stands there")
	ok(parts_h.all(func(p): return (p[0] as MeshInstance3D).visible and (p[0] as MeshInstance3D).transparency == 0.0),
			"every part of the Hunter is solid at the end")
	ok(anim != null and MaskBeat.seen() and _has_name(), "idling, the name is up, and the beat is marked seen")
	await _snap("puton_5_done")
	while _has_name():
		await tree.process_frame
	var name_s := (Time.get_ticks_msec() - name_t0) / 1000.0
	ok(name_t0 > 0 and name_s >= MaskBeat.READ_MIN_S,
			"the name and title stay up %.1f s, long enough to read (%.0f s or more)" % [name_s, MaskBeat.READ_MIN_S])
	host.queue_free()
	await tree.process_frame

## The Hunter's lowest part is in before its highest has started.
func _feet_first(tiers: Array) -> bool:
	var low: Array = tiers[0]
	var high: Array = tiers[0]
	for p in tiers:
		low = p if p[1] < low[1] else low
		high = p if p[1] > high[1] else high
	return (low[0] as MeshInstance3D).visible and not (high[0] as MeshInstance3D).visible

func _has_name() -> bool:
	return not main.get_tree().root.find_children("*", "VBoxContainer", true, false).filter(
			func(n): return n.has_meta("mask_name")).is_empty()

func _farm() -> void:
	var tree := main.get_tree()
	var parts := _stage()
	var you: Node3D = parts[0]
	var got := [null]
	var beat := MaskBeat.play(parts[1], you, func(b): got[0] = b, false)
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(beat):
		await tree.process_frame
	var s := (Time.get_ticks_msec() - t0) / 1000.0
	ok(got[0] == you and is_instance_valid(you) and s < MaskBeat.REACH_S + MaskBeat.FLICKER_S + 0.4,
			"the farm's cut ends after the flicker (%.2f s) and keeps the body you had" % s)
	host.queue_free()
	await tree.process_frame

func _skip() -> void:
	var tree := main.get_tree()
	var parts := _stage()
	var got := [null]
	var beat := MaskBeat.play(parts[1], parts[0], func(b): got[0] = b)
	await tree.process_frame
	ok(beat.skip_hint != null, "seen before: a skip hint")
	var press := InputEventKey.new()
	press.keycode = KEY_SPACE
	press.pressed = true
	beat._unhandled_input(press)
	await tree.process_frame
	ok(got[0] != null and got[0] != parts[0] and got[0].get_parent() == host,
			"any key skips to the Hunter standing there")
	host.queue_free()
	await tree.process_frame

## Steps a beat by hand in frames of `dt` s (nothing else drives it), and returns it once it is done.
func _drive(dt: float, swap: bool, probe := {}) -> MaskBeat:
	var parts := _stage()
	var beat := MaskBeat.play(parts[1], parts[0], func(_b): pass, swap)
	beat.set_process(false)
	var rises := []
	while beat.phase != "done":
		beat._process(dt)
		if beat.phase == "fade" and Sfx.loop_on("mask_swell"):
			rises.append((Sfx.loops["mask_swell"]["p"] as AudioStreamPlayer).pitch_scale)
	probe["swell_pitch"] = rises
	return beat

func _sounds() -> void:
	var tree := main.get_tree()
	Save.d["tutorial"]["mask_seen"] = false
	var coarse := {}
	var fine := {}
	var a: MaskBeat = await _drive(0.05, true, coarse)
	var b: MaskBeat = await _drive(0.004, true, fine)
	for run in [[a, 0.05, "50 ms frames"], [b, 0.004, "4 ms frames"]]:
		var heard: Array = run[0].heard
		var slack: float = run[1] / MaskBeat.FLICKER_S
		var chimes := heard.filter(func(h): return h[0] == "mask_flicker")
		var on_beat := chimes.size() == MaskBeat.FLICKERS
		for i in chimes.size():
			on_beat = on_beat and chimes[i][1] == "flicker" and chimes[i][2] >= MaskBeat.chime_k(i) \
					and chimes[i][2] <= MaskBeat.chime_k(i) + slack + 0.001
		ok(on_beat, "%s: a chime on each of the %d flickers, at %s of the flicker" % [run[2], MaskBeat.FLICKERS,
				str(range(MaskBeat.FLICKERS).map(func(i): return snappedf(MaskBeat.chime_k(i), 0.01)))])
		var swell := heard.filter(func(h): return h[0] == "mask_swell")
		var settle := heard.filter(func(h): return h[0] == "mask_settle")
		ok(swell.size() == 1 and swell[0][1] == "fade" and swell[0][2] <= slack * 4.0 + 0.001
				and settle.size() == 1 and settle[0][1] == "fade" and settle[0][2] == 1.0,
				"%s: the swell begins with the fade and the settle is its last beat" % run[2])
		var order := ["mask_flicker", "mask_flicker", "mask_flicker", "mask_swell", "mask_settle"]
		ok(heard.map(func(h): return h[0]) == order,
				"%s: chime, chime, chime, swell, settle, in that order" % run[2])
	var rise: Array = fine["swell_pitch"]
	ok(rise.size() > 20 and rise[0] < 0.75 and rise[-1] > 1.4
			and range(1, rise.size()).all(func(i): return rise[i] >= rise[i - 1]),
			"the swell rises through the fade (pitch %.2f to %.2f)" % [rise[0], rise[-1]])
	ok(not Sfx.loop_on("mask_swell"), "and it is stopped when the beat ends")
	var farm: MaskBeat = await _drive(0.02, false)
	ok(farm.heard.map(func(h): return h[0]) == ["mask_flicker", "mask_flicker", "mask_flicker", "mask_settle"],
			"the farm's cut: the chimes and the settle, no swell")
	Save.d["tutorial"]["mask_seen"] = true
	var parts := _stage()
	var skipped := MaskBeat.play(parts[1], parts[0], func(_b): pass)
	skipped.skip_now()
	ok(skipped.heard.is_empty() and not Sfx.loop_on("mask_swell"), "a skip makes no sound")
	host.queue_free()
	await tree.process_frame

## Frames for the strip, once each as the beat reaches the time.
func _strip(beat: MaskBeat, done: Dictionary) -> void:
	var want := {"puton_1_reach": ["reach", 0.6 * MaskBeat.REACH_S],
			"puton_2_flicker": ["flicker", 0.17 * MaskBeat.FLICKER_S],
			"puton_3_fade_feet": ["fade", 0.2 * MaskBeat.FADE_S], "puton_4_fade_half": ["fade", 0.56 * MaskBeat.FADE_S]}
	for file in want:
		if not done.has(file) and beat.phase == want[file][0] and beat.t >= want[file][1]:
			done[file] = true
			await _snap(file)

func _snap(file: String) -> void:
	if shots == "":
		return
	await main.get_tree().process_frame
	main.get_tree().root.get_texture().get_image().save_png(shots.path_join(file + ".png"))
