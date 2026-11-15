extends "res://tools/warden_shots.gd"
## --sable-wings-check: Sable's moth wings against her body (docs/SABLE_WINGS.md). In each pose, folded and raised,
## standing, running and shooting, it skins the wing cards and her body on the CPU and counts the card vertices that
## sit inside her coat, braid or head (her back's depth per 3 cm column; round each wing's root, which sits under the
## coat by design, nothing is counted; the loose spring chains, her braid and coat tails, hang behind them and are
## left out), and how far a card's edges stretch past their rest length (tearing).
## Works headless. --sable-wings-shots --shots-dir=<dir>: the same in the renderer: game.png (folded and raised at
## the match camera), poses.png (the poses close, from behind) and open_close.png (the slow open and close, frame by
## frame, from behind).

const DT := 1.0 / 60.0
const CELL := 0.03            # m: the body's depth columns
const ROOT_M := 0.08          # m round a wing's root that is under the coat by design (as tools/art1/sable_wings.py)
const MAX_INSIDE := 4         # card vertices inside the body a pose may have (the approved art has 2 near the edge)
const MAX_STRETCH := 1.35     # a card edge at most this many times its rest length (past it, the card tears)
const WING_POSES := [["folded", 0.0, {}], ["raised", -1.0, {}], ["run", 0.0, {"vel": 5.0}],
	["shoot", 0.0, {"kmove": "thf_lmb_r", "kmove_t": 0.15}],
	["shoot raised", -1.0, {"kmove": "thf_lmb_r", "kmove_t": 0.15}],
	["flip", -1.0, {"kmove": "thf_vault_f", "kmove_t": 0.25, "grounded": false}]]
const BEHIND := 0.35         # rad: her back to the camera, turned a little to show the wings' depth
const OPEN_FRAMES := [0.0, -0.2, -0.45, -0.7, -0.9, -1.0, -0.6, -0.15]

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
	WardenGlb.set_model("thief", true)
	var row := _row("thief", 1)
	for p in WING_POSES:
		await _hold(0, p[1], p[2], 70)
		var r := _measure(row[0] as Node3D)
		var good: bool = r[0] <= MAX_INSIDE and r[1] <= MAX_STRETCH
		fails += 0 if good else 1
		print("WINGS %s %s: %d card vertices inside the body (worst %.1f cm), edges stretch x%.2f at most"
				% ["ok  " if good else "FAIL", p[0], r[0], r[2] * 100.0, r[1]])
	_clear()
	if mode == "shots":
		DirAccess.make_dir_recursive_absolute(out)
		await _shots(out)
		print("SABLE_WINGS_SHOTS_DONE")
	print("sable-wings-check: %s (%d fails)" % ["PASS" if fails == 0 else "FAIL", fails])
	tree.quit(1 if fails > 0 else 0)

## n frames of a pose with the wings held at `fold` (WING_FOLD: 0 folded, -1 raised), the springs settling.
func _hold(i: int, fold: float, st: Dictionary, n: int) -> void:
	var h := anims[i][1] as Node3D
	var fwd := Vector3(-sin(h.rotation.y), 0, -cos(h.rotation.y))
	for k in n:
		var s := {"fired": 99.0, "face": h.rotation.y, "grounded": true}
		s.merge(st, true)
		if st.has("vel"):
			s["vel"] = fwd * float(st["vel"])
		(anims[i][0] as HunterAnim).update(DT, s)
		h.set_meta(WardenGlb.WING_FOLD, fold)
		await tree.process_frame

## [card vertices inside the body, the most a card edge stretches over its rest length, the worst depth m].
func _measure(h: Node3D) -> Array:
	var sk := WardenGlb.skeleton(h.get_node("Warden"))
	var g := {}
	var cards: Array = []
	var rest: Array = []
	var idx := PackedInt32Array()
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null or m.mesh == null:
			continue
		var binds: Array = []
		var loose := PackedByteArray()
		for b in m.skin.get_bind_count():
			var bone := m.skin.get_bind_bone(b)
			if bone < 0:
				bone = sk.find_bone(m.skin.get_bind_name(b))
			binds.append(sk.get_bone_global_pose(bone) * m.skin.get_bind_pose(b))
			loose.append(1 if sk.get_bone_name(bone).begins_with("spring_") else 0)
		for si in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(si)
			var nm := String(mat.resource_name) if mat else ""
			var ar := m.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
			var bo: PackedInt32Array = ar[Mesh.ARRAY_BONES]
			var we: PackedFloat32Array = ar[Mesh.ARRAY_WEIGHTS]
			if bo.is_empty():
				continue
			var k := bo.size() / v.size()
			var wing := nm.begins_with("card-wing")
			for vi in v.size():
				var p := Vector3.ZERO
				var top := 0
				for j in k:
					p += (binds[bo[vi * k + j]] as Transform3D) * v[vi] * we[vi * k + j]
					if we[vi * k + j] > we[vi * k + top]:
						top = j
				if wing:
					cards.append(p)
					rest.append(v[vi])
				elif not nm.begins_with("card") and loose[bo[vi * k + top]] == 0:
					var c := Vector2i(roundi(p.x / CELL), roundi(p.y / CELL))
					var lohi: Vector2 = g.get(c, Vector2(9.0, -9.0))
					g[c] = Vector2(minf(lohi.x, p.z), maxf(lohi.y, p.z))
			if wing:
				idx = ar[Mesh.ARRAY_INDEX]
	var roots := [sk.get_bone_global_pose(sk.find_bone("spring_wingR_0")).origin,
		sk.get_bone_global_pose(sk.find_bone("spring_wingL_0")).origin]
	var n := 0
	var worst := 0.0
	for p in cards:
		var q := p as Vector3
		if q.distance_to(roots[0]) < ROOT_M or q.distance_to(roots[1]) < ROOT_M:
			continue
		var lohi: Vector2 = g.get(Vector2i(roundi(q.x / CELL), roundi(q.y / CELL)), Vector2(9.0, -9.0))
		if q.z > lohi.x and q.z < lohi.y:
			n += 1
			worst = maxf(worst, lohi.y - q.z)
	var stretch := 1.0
	for t in range(0, idx.size(), 3):
		for e in 3:
			var a := idx[t + e]
			var b := idx[t + (e + 1) % 3]
			var r0 := ((rest[a] as Vector3) - (rest[b] as Vector3)).length()
			if r0 > 0.005:
				stretch = maxf(stretch, ((cards[a] as Vector3) - (cards[b] as Vector3)).length() / r0)
	return [n, stretch, worst]

func _shots(out: String) -> void:
	# 1. folded and raised at the match camera, three-quarter back and back
	var row := _row("thief", 4)
	var folds := [0.0, -1.0, 0.0, -1.0]
	for i in row.size():
		(row[i] as Node3D).rotation.y = PI * 0.25 if i < 2 else -PI * 0.25
	for k in 60:
		for i in row.size():
			await _hold(i, folds[i], {}, 1)
	(await _game_strip(row, false)).save_png(out.path_join("game.png"))
	_clear()
	# 2. the poses close, from behind
	row = _row("thief", WING_POSES.size())
	for k in 70:
		for i in row.size():
			(row[i] as Node3D).rotation.y = BEHIND
			await _hold(i, WING_POSES[i][1], WING_POSES[i][2], 1)
	(await _close_strip(row, false)).save_png(out.path_join("poses.png"))
	_clear()
	# 3. the open and close, frame by frame (WardenWings' slow open, eased, then the fold back)
	row = _row("thief", OPEN_FRAMES.size())
	for k in 70:
		for i in row.size():
			(row[i] as Node3D).rotation.y = BEHIND
			await _hold(i, OPEN_FRAMES[i], {}, 1)
	(await _close_strip(row, false)).save_png(out.path_join("open_close.png"))
	_clear()
	var f := FileAccess.open(out.path_join("captions.txt"), FileAccess.WRITE)
	f.store_string(("game.png: Sable at the match camera (pitch %d, %d m, fov %d): folded, raised (3/4 back), "
			+ "folded, raised (3/4 back, the other side); true pixels, then enlarged\n")
			% [CAM_PITCH, CAM_DIST, CAM_FOV]
			+ "poses.png: %s, from behind\n" % ", ".join(WING_POSES.map(func(p): return p[0]))
			+ "open_close.png: the open and close, WING_FOLD %s\n" % str(OPEN_FRAMES))
	f.close()
