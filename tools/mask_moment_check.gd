extends RefCounted
## --mask-moment-check: putting on a Mask is a short cinematic (item 83; MaskBeat, content/rules/mask_moment.json).
##   1. the data: every Hunter has a whisper and a sting key, the sounds exist, the full beat runs 4-6 s
##   2. the first time, played through: build-up (the camera eases in, music ducked), the Mask rises to the face,
##      black on contact, the memory frames of the fallen Hunter with the whisper, the snap back (impact, ripple,
##      the Hunter's model in place), the name and title, the scene's camera back; it can't be skipped
##   3. the next time interact skips it straight to the end; the farm's short cut keeps the body you had
## With --shots-dir=<dir>: mask_beat_1_buildup, _2_rise, _3_black, _4_memory, _5_reveal (a renderer is needed).

const SOUNDS := ["mask_swell", "mask_heart", "mask_whisper", "mask_impact", "mask_sting"]

var main: Node
var bad := 0
var shots := ""
var host: Node3D
var scene_cam: Camera3D

func ok(cond: bool, what: String) -> void:
	print("MASKBEAT %s %s" % ["ok  " if cond else "FAIL", what])
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
	_data()
	await _first_time()
	await _again()
	print("MASKBEAT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _data() -> void:
	var r := Content.rules(MaskBeat.RULES)
	var missing: Array = []
	for a in Arch.ids():
		if not (r["whispers"] as Dictionary).has(a) or not (r["sting_semitones"] as Dictionary).has(a):
			missing.append(a)
	ok(missing.is_empty(), "every Hunter has a whisper and a sting key (%s)" % str(missing))
	ok(SOUNDS.all(func(s): return ResourceLoader.exists("res://audio/%s.wav" % s)), "the beat's own sounds exist")
	var full: Dictionary = r["full"]
	var total := float(full["build_s"]) + float(full["rise_s"]) + float(full["black_s"]) + float(full["reveal_s"])
	for s in full["memory_s"]:
		total += float(s)
	ok(total >= 4.0 and total <= 6.0 and float(full["black_s"]) >= 0.6 and float(full["black_s"]) <= 0.8,
			"the full beat runs %.1f s with %.2f s of black" % [total, float(full["black_s"])])
	ok((full["memory_s"] as Array).size() in [2, 3], "two or three memory frames")

## A stage: a lit floor, a camera, and you (the Empty) facing it with Vex's Mask hovering beside your face.
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
	scene_cam.global_transform = Transform3D(Basis(), Vector3(0.4, 1.6, 4.5)).looking_at(Vector3(0, 1.1, 0))
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
	Save.d = Save.fresh()
	Save.d["look"] = Unmasked.default_look()
	var parts := _stage()
	var got := [null]
	var t0 := Time.get_ticks_msec()
	var beat := MaskBeat.play(parts[1], parts[0], func(b): got[0] = b)
	var planned := _planned_s(beat)
	var clock := [0.0, 0.0]      # [the beat's own seconds (the frames' deltas), the longest frame]
	var tick := func():
		var dt := main.get_process_delta_time()
		clock[0] += dt
		clock[1] = maxf(clock[1], dt)
	tree.process_frame.connect(tick)
	await tree.process_frame
	ok(not MaskBeat.seen() and beat.skip_hint == null and beat.cam.current, "the first time: no skip, its own camera")
	var cam_from := beat.cam.global_position
	await _until(tree, beat, "rise")
	ok(beat.cam.global_position.distance_to(beat._head) < cam_from.distance_to(beat._head) - 0.3,
			"build-up: the camera has eased in on you")
	await _shot(tree, "mask_beat_1_buildup")
	await tree.create_timer(0.9).timeout
	ok(beat.phase == "rise" and beat._ghost != null and beat.mask.global_position.distance_to(beat._head) < 1.0,
			"the Mask rises to the face and a ghostly face flickers over yours")
	await _shot(tree, "mask_beat_2_rise")
	await _until(tree, beat, "black")
	ok(beat.black.color.a >= 1.0 and not beat._swell.playing and not beat._heart.playing,
			"contact: black, and the swell and heartbeat cut off")
	ok(String(beat.body.get_meta("arch", "")) == "gunslinger", "behind the black you have become Vex")
	await _shot(tree, "mask_beat_3_black")
	await _until(tree, beat, "memory")
	await tree.create_timer(0.12).timeout
	ok(beat.memory.visible and beat.memory.texture != null and beat.whisper_line.text != "",
			"a memory of the fallen Hunter in the black, and her whisper: \"%s\"" % beat.whisper_line.text)
	await _shot(tree, "mask_beat_4_memory")
	await _until(tree, beat, "reveal")
	ok(beat.black.color.a == 0.0 and beat._ripple != null, "the snap back: the world again, a ripple of light")
	await tree.create_timer(0.7).timeout
	var named: Node = beat.name_box
	ok(named != null and _texts(named).has(HunterViewer.display_name("gunslinger")), "her name and title on screen")
	await _shot(tree, "mask_beat_5_reveal")
	while got[0] == null and Time.get_ticks_msec() - t0 < 30000:
		await tree.process_frame
	tree.process_frame.disconnect(tick)
	var secs := float(clock[0])
	ok(got[0] != null and String((got[0] as Node3D).get_meta("arch", "")) == "gunslinger",
			"done hands back Vex's model, standing where you stood")
	if shots == "":      # (a phase ends on a frame: a slow rasterizer stretches each by up to one frame)
		ok(secs >= planned - 0.3 and secs <= planned + 6.0 * float(clock[1]),
				"it ran %.1f s of the %.1f s planned (longest frame %.2f s)" % [secs, planned, clock[1]])
	ok(scene_cam.current and MaskBeat.seen(), "the scene's camera is back and the beat is marked seen")
	host.queue_free()
	await tree.process_frame

func _again() -> void:
	var tree := main.get_tree()
	var parts := _stage()
	var you: Node3D = parts[0]
	var got := [null]
	var beat := MaskBeat.play(parts[1], you, func(b): got[0] = b, false, true)
	await tree.process_frame
	var key := Settings.key_cap("interact")
	ok(beat.skip_hint != null and _texts(beat.skip_hint).any(func(s): return String(s).contains(key)),
			"seen before: a skip hint with the interact key")
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	beat._unhandled_input(press)
	await tree.process_frame
	ok(got[0] == you and is_instance_valid(you) and scene_cam.current,
			"interact skips it; the farm's cut keeps the body you had")
	host.queue_free()
	await tree.process_frame

## The seconds the beat's phases add up to.
func _planned_s(beat: MaskBeat) -> float:
	var t: Dictionary = beat._times
	var total := float(t["build_s"]) + float(t["rise_s"]) + float(t["black_s"]) + float(t["reveal_s"])
	for s in t["memory_s"]:
		total += float(s)
	return total

func _until(tree: SceneTree, beat: MaskBeat, phase: String) -> void:
	var t0 := Time.get_ticks_msec()
	while beat.phase != phase and Time.get_ticks_msec() - t0 < 8000:
		await tree.process_frame

func _shot(tree: SceneTree, file: String) -> void:
	if shots == "":
		return
	await tree.process_frame
	tree.root.get_texture().get_image().save_png(shots.path_join(file + ".png"))

func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		out.append_array(_texts(c))
	return out
