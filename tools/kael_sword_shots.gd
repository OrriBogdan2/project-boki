extends "res://tools/warden_shots.gd"
## --kael-sword-check: Kael's skinned sword against his body in every pose (item 131b): its blade as a fraction of
## his height, where the support hand sits on the hilt, and that the blade's FX anchors exist. Works
## headless. --kael-sword-shots --shots-dir=<dir>: the same poses in the renderer: match.png, hero.png, rmb_hold.png
## (four frames, front and side) and poses.png. Item 131b's before/after sheets are two runs of this.

# guard to tip against his height: the v2 sheet and splash blade, 0.61 (DECISIONS: the size follows the splash)
const WANT_FRAC := [0.5, 0.65]
const ON_HILT := 0.1             # m: how far the sword hand's bone may sit off the hilt (v1's bound)
const GRIP_PER_BLADE := 0.25     # the hilt behind the guard per blade length (kael_pieces: 0.15 / 0.61)
const SWORD_POSES := [["carried", {}], ["walk", {"vel": 2.0}], ["run", {"vel": 4.6}],
	["LMB swing 1", {"kmove": "jug_slash_r", "kmove_t": 0.1}],
	["LMB swing 2", {"kmove": "jug_slash_l", "kmove_t": 0.1}],
	["Wave wind-up", {"kmove": "jug_wave_wind", "kmove_t": 0.3}], ["Wave", {"kmove": "jug_wave", "kmove_t": 0.2}],
	["Lunge hold 0.10", {"kmove": "jug_lunge_wind", "kmove_t": 0.1}],
	["Lunge hold 0.28", {"kmove": "jug_lunge_wind", "kmove_t": 0.28}],
	["Lunge hold 0.45", {"kmove": "jug_lunge_wind", "kmove_t": 0.45}],
	["Lunge hold 1.20", {"kmove": "jug_lunge_wind", "kmove_t": 1.2}],
	["Lunge", {"kmove": "jug_lunge", "kmove_t": 0.2}],
	["Slam wind-up", {"kmove": "jug_slam", "kmove_t": 0.56}],
	["Slam", {"kmove": "jug_slam", "kmove_t": 0.7}],
	["Rampage drive", {"kmove": "jug_dash", "kmove_t": 0.21}],
	["Rampage tip", {"kmove": "jug_dash", "kmove_t": 0.38}],
	["Rampage drag", {"kmove": "jug_dash", "kmove_t": 0.6}],
	["Guard", {"kmove": "jug_guard", "kmove_t": 0.36}]]
const SMOKE_FRAMES := 200
const HOLDS := ["Lunge hold 0.10", "Lunge hold 0.28", "Lunge hold 0.45", "Lunge hold 1.20"]

var fails := 0

func run(main: Node, mode: String = "check") -> void:
	tree = main.get_tree()
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_stage(main)
	WardenGlb.set_model("juggernaut", true)
	await _measure()
	if mode == "shots":
		DirAccess.make_dir_recursive_absolute(out)
		await _shots(out)
		print("KAEL_SWORD_SHOTS_DONE")
	print("kael-sword-check: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	tree.quit()

func _hold(i: int, st: Dictionary) -> void:
	for k in 60:
		_step(i, st)

func _step(i: int, st: Dictionary) -> void:
	var h := anims[i][1] as Node3D
	var fwd := Vector3(-sin(h.rotation.y), 0, -cos(h.rotation.y))
	var s := {"fired": 99.0, "face": h.rotation.y, "grounded": true}
	s.merge(st)
	if st.has("vel"):
		s["vel"] = fwd * float(st["vel"])
	(anims[i][0] as HunterAnim).update(1.0 / 60.0, s)

## The skinned sword's FX empties on hand.R (kael.glb v2): the blade's root at the guard and its tip.
func _blade(h: Node3D) -> Array:
	var root := h.find_child("anchor_blade_root", true, false) as Node3D
	return [root, h.find_child(WardenGlb.WEAPON_MUZZLE, true, false) as Node3D]

func _measure() -> void:
	var row := _row("juggernaut", 1)
	var h := row[0] as Node3D
	await _settle(4)
	var bl := _blade(h)
	if bl[0] == null or bl[1] == null:
		print("FAIL: no anchor_blade_root / weapon_muzzle on the sword")
		fails += 1
		_clear()
		return
	# sole to the top of his hair, standing (the bind pose; the mane is part of Body)
	var box := h.find_child("Body", true, false) as VisualInstance3D
	var aabb := box.global_transform * box.get_aabb()
	var tall := aabb.end.y - aabb.position.y
	var sk := WardenGlb.skeleton(h.get_node("Warden"))
	print("SWORD model scale %.3f, height %.3f m" % [h.scale.y, tall])
	for p in SWORD_POSES:
		_hold(0, p[1])
		await tree.process_frame
		await tree.process_frame
		var root := (bl[0] as Node3D).global_position
		var tip := (bl[1] as Node3D).global_position
		var blade := root.distance_to(tip)
		var hilt_end := root + (root - tip) * GRIP_PER_BLADE
		var r := _hand_off(sk, root, hilt_end, "hand.R")
		var l := _hand_off(sk, root, hilt_end, "hand.L")
		print("SWORD %-16s blade %.3f m = %.3f of height, hand R %.3f L %.3f off the hilt"
				% [p[0], blade, blade / tall, r, l])
		if r > ON_HILT:
			print("FAIL: %s right hand %.3f m off the hilt" % [p[0], r])
			fails += 1
		if blade / tall < WANT_FRAC[0] or blade / tall > WANT_FRAC[1]:
			print("FAIL: %s blade is %.3f of his height" % [p[0], blade / tall])
			fails += 1
	_clear()
	await tree.process_frame

## A hand bone's distance from the hilt's line (m).
func _hand_off(sk: Skeleton3D, a: Vector3, b: Vector3, bone: String) -> float:
	var at := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
	return at.distance_to(Geometry3D.get_closest_point_to_segment(at, a, b))

func _posed(names: Array, yaw: float) -> Array:
	var row := _row("juggernaut", names.size())
	for i in row.size():
		(row[i] as Node3D).rotation.y = yaw
	for k in SMOKE_FRAMES:      # (held there: a new emitter's first puffs sit in a dark ball at the hilt)
		for i in row.size():
			for p in SWORD_POSES:
				if p[0] == names[i]:
					_step(i, p[1])
		await tree.process_frame
	return row

func _shots(out: String) -> void:
	# the match camera: carried, the Lunge hold, a swing, a Slam; true pixels then enlarged
	var row := await _posed(["carried", "Lunge hold 1.20", "LMB swing 1", "Slam wind-up"], PI * 0.78)
	(await _game_strip(row, false)).save_png(out.path_join("match.png"))
	_clear()
	await tree.process_frame
	# the hero view: full length, front and 3/4
	row = await _posed(["carried", "carried"], PI)
	(row[1] as Node3D).rotation.y = PI * 0.62
	_hold(1, {})
	(await _pair(row, 0, 1)).save_png(out.path_join("hero.png"))
	_clear()
	await tree.process_frame
	# the RMB hold, four frames, front and side
	var rows: Array = []
	for yaw in [PI, PI * 0.5]:
		row = await _posed(HOLDS, yaw)
		rows.append(await _close_strip(row, false))
		_clear()
		await tree.process_frame
	_stack(rows).save_png(out.path_join("rmb_hold.png"))
	# every pose, close
	rows = []
	var names: Array = []
	for p in SWORD_POSES:
		names.append(p[0])
	for part in range(0, names.size(), 6):
		row = await _posed(names.slice(part, part + 6), PI * 0.78)
		rows.append(await _close_strip(row, false))
		_clear()
		await tree.process_frame
	_stack(rows).save_png(out.path_join("poses.png"))

func _stack(imgs: Array) -> Image:
	var w := 0
	var hh := 0
	for i in imgs:
		w = maxi(w, (i as Image).get_width())
		hh += (i as Image).get_height() + 6
	var out := Image.create(w, hh, false, Image.FORMAT_RGBA8)
	out.fill(Color("1c1a24"))
	var y := 0
	for i in imgs:
		out.blit_rect(i, Rect2i(Vector2i.ZERO, (i as Image).get_size()), Vector2i(0, y))
		y += (i as Image).get_height() + 6
	return out
