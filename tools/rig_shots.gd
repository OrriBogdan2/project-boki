extends "res://tools/warden_shots.gd"
## --rig-shots --shots-dir=<dir> [--wardens=a,b]: one contact sheet per Hunter (sheet_<id>.png): idle, walk, run, a
## hit, the dash and the kit's moves at their middle, at the match camera (top) and close (below).

const MOVE_TABLES_ := [HunterAnim.KMOVES, KMovesPinBjorn.MOVES, KMovesDJ.MOVES, KMovesVV.MOVES, KMovesStone.MOVES,
	KMovesCare.MOVES, KMovesPair.MOVES]
const PREFIX_ := {"bulwark": "bul_", "archer": "arc_", "gunslinger": "gunslinger_", "mage": "mage_", "thief": "thf_",
	"dolm": "breah_", "ostra": "ostra_", "rimewright": "tm_", "ashwick": "as_", "juggernaut": "jug", "dredge": "dr_",
	"tender": "mm_"}
const TILES := 12

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var wardens := PREFIX_.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): wardens = Array(a.substr(10).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_stage(main)
	for id in wardens:
		WardenGlb.set_model(String(id), true)
	for id in wardens:
		await _sheet(String(id), out)
	print("RIG_SHOTS_DONE")
	tree.quit()

func _states(id: String) -> Array:
	var out: Array = [["idle", {}], ["walk", {"vel": 2.0}], ["run", {"vel": 4.6}], ["hit", {"hit": true}]]
	var moves: Array = []
	for t in MOVE_TABLES_:
		for mv in t:
			if String(mv).begins_with(PREFIX_[id]):
				moves.append(mv)
	moves.sort_custom(func(a, b): return ("dash" in a) and not ("dash" in b))
	var keep: Array = []
	for mv in moves:
		if "dash" in mv or keep.size() < TILES - 4 - 1:
			keep.append(mv)
		if keep.size() >= TILES - 4:
			break
	for mv in keep:
		var keys: Array = HunterAnim.km_def(mv)["keys"]
		out.append([String(mv).trim_prefix(PREFIX_[id]), {"kmove": mv, "kmove_t": float(keys[keys.size() / 2][0])}])
	return out

func _sheet(id: String, out: String) -> void:
	var sts := _states(id)
	var row := _row(id, sts.size())
	var caps: Array = []
	for i in row.size():
		var h := row[i] as Node3D
		h.rotation.y = PI * 0.78
		_state(anims[i][0], h, sts[i][1])
		caps.append(sts[i][0])
	var game := await _game_strip(row, false)
	var rows: Array = [game]
	for part in range(0, row.size(), 6):
		var sub := row.slice(part, part + 6)
		for h in row:
			(h as Node3D).visible = h in sub
		var shifted := sub.size()
		for k in shifted:
			(sub[k] as Node3D).position.x = (k - (shifted - 1) * 0.5) * GAP
		rows.append(await _close_strip(sub, false))
	var w := OUT_W
	var hgt := 0
	for r in rows:
		hgt += int((r as Image).get_height() * float(w) / (r as Image).get_width()) + 4
	var sheet := Image.create(w, hgt, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1c1a24"))
	var y := 0
	for r in rows:
		var img := r as Image
		img.resize(w, int(img.get_height() * float(w) / img.get_width()), Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(0, y))
		y += img.get_height() + 4
	sheet.convert(Image.FORMAT_RGB8)
	sheet.save_jpg(out.path_join("sheet_%s.jpg" % id), 0.85)
	var f := FileAccess.open(out.path_join("sheet_%s.txt" % id), FileAccess.WRITE)
	f.store_string(", ".join(caps) + "\n")
	f.close()
	_clear()

func _state(an: HunterAnim, h: Node3D, st: Dictionary) -> void:
	var fwd := Vector3(-sin(h.rotation.y), 0, -cos(h.rotation.y))
	for k in 70:
		var s := {"fired": 99.0, "face": h.rotation.y, "grounded": true}
		if st.has("vel"):
			s["vel"] = fwd * float(st["vel"])
		if st.has("kmove"):
			s["kmove"] = st["kmove"]
			s["kmove_t"] = st["kmove_t"]
		if st.has("hit"):
			s["hit_t"] = 99.0 if k < 60 else (k - 60) * 0.02
			s["hit_dir"] = Vector2(fwd.x, fwd.z)
		an.update(1.0 / 60.0, s)
