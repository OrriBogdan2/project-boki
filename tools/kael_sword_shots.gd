extends "res://tools/warden_shots.gd"
## --kael-sword-check: Kael's held sword against his body in every pose (item 131b): its length as a fraction of
## his height, where the hands sit on the hilt, and that the blade's FX anchors are still on the blade. Works
## headless. --kael-sword-shots --shots-dir=<dir>: the same poses in the renderer: match.png, hero.png, rmb_hold.png
## (four frames, front and side) and poses.png. Item 131b's before/after sheets are two runs of this.

const WANT_FRAC := [0.3, 0.4]    # the owner's 0.60 of main's sword (0.34): pommel to tip against his height
const ON_HILT := 0.1             # m: how far a gripping hand's bone may sit off the hilt
const TIP_SLACK := 0.03          # m: the blade_tip FX anchor against the blade's real tip
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
const POMMEL := Vector3(0, 0, 0.155)     # kael.glb's weapon mesh: pommel end, tip, guard (model units)
const TIP := Vector3(0, 0, -0.62)
const GUARD := Vector3(0, 0, -0.055)
const HILT_END := Vector3(0, 0, 0.125)

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

func _sword(h: Node3D) -> MeshInstance3D:
	return h.get_node_or_null("Rig/Torso/Aim/Gun/" + WardenGlb.WEAPON) as MeshInstance3D

func _measure() -> void:
	var row := _row("juggernaut", 1)
	var h := row[0] as Node3D
	await _settle(4)
	var w := _sword(h)
	if w == null:
		print("FAIL: no .glb sword in the Gun")
		fails += 1
		_clear()
		return
	# sole to the top of his hair, standing (the bind pose; anchor_head_top sits above the hair)
	var box := (h.find_child("Body", true, false) as VisualInstance3D)
	var hair := (h.find_child("Mane", true, false) as VisualInstance3D)
	var tall := (hair.global_transform * hair.get_aabb()).end.y - (box.global_transform * box.get_aabb()).position.y
	var sk := WardenGlb.skeleton(h.get_node("Warden"))
	var hip := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hips")).origin).y
	var shoulder := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("upper_arm.R")).origin).y
	print("SWORD model scale %.3f, Gun scale %.3f, weapon scale %.3f, height %.3f m, hips %.3f m, shoulder %.3f m"
			% [h.scale.y, anims[0][0].gun_scl, w.scale.x, tall, hip, shoulder])
	var anchors := _vfx_anchors()
	for p in SWORD_POSES:
		_hold(0, p[1])
		await tree.process_frame
		await tree.process_frame
		var x := w.global_transform
		var whole := (x * POMMEL).distance_to(x * TIP)
		var blade := (x * GUARD).distance_to(x * TIP)
		var r := _hand_off(sk, x, "hand.R")
		var l := _hand_off(sk, x, "hand.L")
		var gun := w.get_parent() as Node3D
		var a: Array = anchors.get("blade_tip", {}).get("gun", [0, 0, -0.53])
		var tip_off := (gun.global_transform * Vector3(a[0], a[1], a[2])).distance_to(x * TIP)
		print("SWORD %-16s sword %.3f m = %.3f of height, blade %.3f m, hand R %.3f L %.3f off the hilt, tip FX %.3f"
				% [p[0], whole, whole / tall, blade, r, l, tip_off])
		if whole / tall < WANT_FRAC[0] or whole / tall > WANT_FRAC[1]:
			print("FAIL: %s sword is %.3f of his height" % [p[0], whole / tall])
			fails += 1
		if r > ON_HILT:
			print("FAIL: %s right hand %.3f m off the hilt" % [p[0], r])
			fails += 1
		if tip_off > TIP_SLACK:
			print("FAIL: %s blade_tip FX anchor %.3f m off the blade's tip" % [p[0], tip_off])
			fails += 1
	_clear()
	await tree.process_frame

func _vfx_anchors() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/vfx/juggernaut.json"))
	return d.get("anchors", {})

## A hand bone's distance from the hilt's line (m).
func _hand_off(sk: Skeleton3D, weapon_x: Transform3D, bone: String) -> float:
	var bi := sk.find_bone(bone)
	var at := sk.global_transform * sk.get_bone_global_pose(bi).origin
	var a := weapon_x * GUARD
	var b := weapon_x * HILT_END
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
