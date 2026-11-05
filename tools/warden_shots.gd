extends RefCounted
## --warden-shots --shots-dir=<dir> [--wardens=bulwark,archer,juggernaut] [--sheets=<dir>] [--procedural]: the
## in-engine Warden models next to their concept sheets (concept phase 2). Per Hunter, under <dir>/<id>/:
## turnaround_game.png (front, 3/4, side, back, 3/4 back at the match camera: the true pixels, then
## enlarged 3x), front_34.png and back_34.png (full length), poses_game.png (idle, run, attack, cast, ult at the
## match camera), turnaround_close.png, closeup.png and closeup_front.png (head and shoulders, 3/4 and front),
## vs_sheet.png (the concept sheet beside the close turnaround) and moves_close_N.png (the run and the hero's own
## kit moves, frame by frame), plus captions.txt.
## --procedural shoots the procedural models of Wardens that have a 3D one (Settings: Warden models).
## --sheets names the folder holding the concept PNGs (<id>.png). Needs a renderer.

const YAWS := [PI, PI * 0.75, PI * 0.5, 0.0, -PI * 0.25]
const YAW_NAMES := ["front", "3/4", "side", "back", "3/4 back"]
const POSES := ["idle", "run", "attack", "cast", "ult"]
const GAP := 1.9              # m between hunters in a strip
const CAM_PITCH := 66.0       # degrees: the default match camera (CamRig STYLES "supervive")
const CAM_DIST := 23.0
const CAM_FOV := 32.0
const ENLARGE := 3            # the gameplay strip enlarged this many times (nearest, so the pixels stay honest)
const OUT_W := 1280
const MOVES_PER_STRIP := 4    # kit-move frames side by side in one close strip

var holder: Node3D
var cam: Camera3D
var anims: Array = []
var tree: SceneTree
var close_cfg := {}           # a Warden's warden_look "closeup" {fov, up}: a wider head shot (Motley's raised orb)

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var sheets := ""
	var wardens := ["bulwark", "archer", "juggernaut"]
	var procedural := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--sheets="): sheets = a.substr(9)
		if a.begins_with("--wardens="): wardens = Array(a.substr(10).split(","))
		if a == "--procedural": procedural = true
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_stage(main)
	for id in wardens:
		WardenGlb.set_model(String(id), not procedural)
	for id in wardens:
		await _hero(String(id), out.path_join(String(id)), sheets)
	print("WARDEN_SHOTS_DONE")
	tree.quit()

func _stage(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"),
		"stars": 0.0})
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 60)
	ground.mesh = pm
	ground.material_override = Models.toon(Color("4f7a3e"), false)
	holder.add_child(ground)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()

func _hero(id: String, dir: String, sheets: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var caps: Array = []
	var title := String(Arch.def(id).get("name", id))
	close_cfg = WardenGlb.look(WardenGlb.art(id)).get("closeup", {})
	# 1. the turnaround at the match camera, then close
	var row := _row(id, YAWS.size())
	for i in row.size():
		(row[i] as Node3D).rotation.y = YAWS[i]
	await _settle(40)
	var game := await _game_strip(row)
	game.save_png(dir.path_join("turnaround_game.png"))
	caps.append("turnaround_game.png: %s at the match camera (pitch %d, %d m, fov %d), %s; true pixels, then x%d"
			% [title, CAM_PITCH, CAM_DIST, CAM_FOV, ", ".join(YAW_NAMES), ENLARGE])
	var close := await _close_strip(row)
	close.save_png(dir.path_join("turnaround_close.png"))
	caps.append("turnaround_close.png: %s close, %s" % [title, ", ".join(YAW_NAMES)])
	var pair := await _pair(row, 0, 1)
	pair.save_png(dir.path_join("front_34.png"))
	caps.append("front_34.png: %s full length, front and three-quarter (as the sheet's two views)" % title)
	var back := await _pair(row, 3, 4)
	back.save_png(dir.path_join("back_34.png"))
	caps.append("back_34.png: %s full length, back and three-quarter back" % title)
	# 2. head and shoulders, three-quarter front
	var head := await _head(row[1])
	head.save_png(dir.path_join("closeup.png"))
	caps.append("closeup.png: %s head and shoulders, three-quarter front" % title)
	var face := await _head(row[0])
	face.save_png(dir.path_join("closeup_front.png"))
	caps.append("closeup_front.png: %s head and shoulders, from the front" % title)
	# 3. the concept sheet beside the model
	var sheet_path := sheets.path_join(id + ".png")
	if sheets != "" and FileAccess.file_exists(sheet_path):
		var vs := _beside(Image.load_from_file(sheet_path), pair, game)
		vs.save_png(dir.path_join("vs_sheet.png"))
		caps.append("vs_sheet.png: the approved concept sheet (left), the model's front and 3/4 (right), "
				+ "the match-camera strip below")
	_clear()
	# 4. the moves at the match camera
	row = _row(id, POSES.size())
	for i in row.size():
		(row[i] as Node3D).rotation.y = PI * 0.82
		_pose(anims[i][0], row[i], POSES[i], id)
	var poses := await _game_strip(row, false)
	poses.save_png(dir.path_join("poses_game.png"))
	caps.append("poses_game.png: %s at the match camera in %s (true pixels, then x%d)"
			% [title, ", ".join(POSES), ENLARGE])
	_clear()
	# 5. her own kit moves, frame by frame, close
	var frames := _move_frames(id)
	for part in range(0, frames.size(), MOVES_PER_STRIP):
		var some := frames.slice(part, part + MOVES_PER_STRIP)
		row = _row(id, some.size())
		for i in row.size():
			(row[i] as Node3D).rotation.y = PI * 0.7
			_frame(anims[i][0], row[i], some[i])
		var moves := await _close_strip(row, false)
		var nm := "moves_close_%d.png" % (part / MOVES_PER_STRIP + 1)
		moves.save_png(dir.path_join(nm))
		caps.append("%s: %s, left to right: %s" % [nm, title, ", ".join(some.map(func(f): return f[0]))])
		_clear()
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	f.store_string("\n".join(caps) + "\n")
	f.close()

func _row(id: String, count: int) -> Array:
	var out: Array = []
	var cls := Arch.weight(id)
	for i in count:
		var h := Models.hunter(cls, Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
		h.position = Vector3((i - (count - 1) * 0.5) * GAP, 0, 0)
		holder.add_child(h)
		anims.append([HunterAnim.new(h), h])
		out.append(h)
	return out

func _clear() -> void:
	for a in anims:
		(a[1] as Node3D).queue_free()
	anims.clear()

func _settle(frames: int, animate := true) -> void:
	for k in frames:
		if animate:
			for a in anims:
				(a[0] as HunterAnim).update(
					1.0 / 60.0,
					{"fired": 99.0, "face": (a[1] as Node3D).rotation.y, "grounded": true}
				)
		await tree.process_frame

func _grab() -> Image:
	await tree.process_frame
	await tree.process_frame
	var img := tree.root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

## The row at the match camera: the true-pixel crop on top, the same crop enlarged below.
func _game_strip(row: Array, animate := true) -> Image:
	var p := deg_to_rad(CAM_PITCH)
	var mid := Vector3(0, 1.0, 0)
	cam.fov = CAM_FOV
	cam.position = mid + Vector3(0, sin(p), cos(p)) * CAM_DIST
	cam.rotation = Vector3(-p, 0, 0)
	await _settle(6, animate)
	var img := await _grab()
	var a := cam.unproject_position((row[0] as Node3D).position + Vector3(-1.1, 3.0, -1.0))
	var b := cam.unproject_position((row[row.size() - 1] as Node3D).position + Vector3(1.1, -0.3, 1.6))
	var crop := img.get_region(Rect2i(Vector2i(a), Vector2i(b - a)))
	var big := crop.duplicate() as Image
	var k := clampi(OUT_W / crop.get_width(), 1, ENLARGE)
	big.resize(crop.get_width() * k, crop.get_height() * k, Image.INTERPOLATE_NEAREST)
	var out := Image.create(
		maxi(big.get_width(), crop.get_width()),
		crop.get_height() + big.get_height() + 8,
		false,
		Image.FORMAT_RGBA8
	)
	out.fill(Color("1c1a24"))
	out.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i((out.get_width() - crop.get_width()) / 2, 0))
	out.blit_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(0, crop.get_height() + 8))
	return _fit(out)

func _close_strip(row: Array, animate := true) -> Image:
	var span := (row.size() - 1) * GAP + 1.6
	cam.fov = 30.0
	var half_h := atan(tan(deg_to_rad(cam.fov * 0.5)) * 16.0 / 9.0)
	await _settle(1, animate)
	var tall := maxf(_top(row), 1.8)          # (the tallest piece, a hammer held high included, stays in)
	var dist := maxf(span * 0.5 / tan(half_h), (tall * 0.5 + 0.35) / tan(deg_to_rad(cam.fov * 0.5)))
	cam.position = Vector3(0, maxf(1.1, tall * 0.5), dist)
	cam.rotation = Vector3(-0.03, 0, 0)
	await _settle(4, animate)
	var img := await _grab()
	var top := int(cam.unproject_position(Vector3(0, maxf(2.9, tall + 0.15), 0)).y)
	var bottom := int(cam.unproject_position(Vector3(0, -0.15, 0.6)).y)
	return _fit(img.get_region(Rect2i(0, maxi(top, 0), img.get_width(), mini(bottom, img.get_height()) - maxi(top, 0))))

## The highest point of the hunters' visible meshes (m), so a tall model and its raised weapon stay in frame.
func _top(row: Array) -> float:
	var top := 0.0
	for h in row:
		for vi in (h as Node).find_children("*", "VisualInstance3D", true, false):
			var v := vi as VisualInstance3D
			if v.is_visible_in_tree() and not (v is Light3D):
				top = maxf(top, (v.global_transform * v.get_aabb()).end.y)
	return top

## Two hunters of the turnaround row (front and 3/4, or back and 3/4 back), each filling half the frame.
func _pair(row: Array, a: int, b: int) -> Image:
	var out := Image.create(OUT_W, 720, false, Image.FORMAT_RGBA8)
	for i in 2:
		var h := row[[a, b][i]] as Node3D
		cam.fov = 30.0
		var tall := maxf(_top([h]), 2.2)
		cam.position = Vector3(h.position.x, tall * 0.52, h.position.z + (tall * 0.5) / tan(deg_to_rad(15.0)))
		cam.rotation = Vector3(-0.04, 0, 0)
		await _settle(4)
		var img := await _grab()
		var half := img.get_width() / 4
		var crop := img.get_region(Rect2i(img.get_width() / 2 - half, 0, half * 2, img.get_height()))
		crop.resize(OUT_W / 2, 720, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(i * OUT_W / 2, 0))
	return out

func _head(h: Node3D) -> Image:
	var hp := (h.get_node("Rig/Torso/HeadPivot") as Node3D).global_position + Vector3(0, 0.12 * h.scale.y, 0)
	var back := 1.8
	# (a big chibi head, Pip's with its ears and flower ring: the frame centres between the neck and the head's
	# top and backs off, so the crown and ears stay in it)
	var top := WardenGlb.anchor(h, "anchor_head_top")
	var pivot := (h.get_node("Rig/Torso/HeadPivot") as Node3D).global_position
	if top and top.global_position.y - pivot.y > 0.32:
		var span := top.global_position.y - pivot.y
		hp.y = pivot.y + span * 0.5
		back *= span / 0.32
	# (a Warden's warden_look "closeup" {fov, up} frames its head shot: Motley's raised orb)
	var up := float(close_cfg.get("up", 0.0))
	cam.fov = float(close_cfg.get("fov", 24.0))
	cam.position = Vector3(h.position.x, hp.y + 0.1 + up, hp.z + back)
	cam.look_at(hp + Vector3(0, -0.08 + up, 0))
	await _settle(4)
	var img := await _grab()
	var w := img.get_height()
	return img.get_region(Rect2i((img.get_width() - w) / 2, 0, w, w))

## The concept sheet on the left, the close turnaround on the right, the match-camera strip below.
func _beside(sheet: Image, close: Image, game: Image) -> Image:
	var half := OUT_W / 2
	sheet.convert(Image.FORMAT_RGBA8)
	sheet.resize(half, int(sheet.get_height() * float(half) / sheet.get_width()), Image.INTERPOLATE_LANCZOS)
	var c := close.duplicate() as Image
	c.resize(half, int(c.get_height() * float(half) / c.get_width()), Image.INTERPOLATE_LANCZOS)
	var top := maxi(sheet.get_height(), c.get_height())
	var g := game.duplicate() as Image
	if g.get_width() > OUT_W:
		g.resize(OUT_W, int(g.get_height() * float(OUT_W) / g.get_width()), Image.INTERPOLATE_NEAREST)
	var out := Image.create(OUT_W, top + 6 + g.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color("1c1a24"))
	out.blit_rect(sheet, Rect2i(Vector2i.ZERO, sheet.get_size()), Vector2i.ZERO)
	out.blit_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i(half, 0))
	out.blit_rect(g, Rect2i(Vector2i.ZERO, g.get_size()), Vector2i((OUT_W - g.get_width()) / 2, top + 6))
	return out

## At most OUT_W wide.
func _fit(img: Image) -> Image:
	if img.get_width() > OUT_W:
		img.resize(OUT_W, int(img.get_height() * float(OUT_W) / img.get_width()), Image.INTERPOLATE_LANCZOS)
	return img

## Kit moves keyed under their own names (not <id>_lmb / _dash / _rmb): [caption, move, time (s)].
const OWN_MOVES := {
	"ashwick": [["Torch Lance", "as_lance", 0.2], ["Soot Ram", "as_leap", 0.08], ["Soot Ram, late", "as_leap", 0.2],
		["Cinder Shot aim", "as_aim", 0.3], ["Cinder Shot", "as_shot", 0.12], ["Furnace Cloak", "as_cloak", 0.15]],
}

## The run cycle at two phases, then the hero's own kit moves (<id>_lmb, _dash, _rmb) at key moments: [label,
## kit move, its time, running]. A hero without its own moves gets the run only.
func _move_frames(id: String) -> Array:
	var out: Array = [["run", "", 0.0, 0], ["run, other foot", "", 0.0, 9]]
	for f in OWN_MOVES.get(id, []):
		if not HunterAnim.km_def(String(f[1])).is_empty():
			out.append([f[0], f[1], f[2], -1])
	for f in [["shoot", "_lmb", 0.03], ["recoil", "_lmb", 0.08], ["dash", "_dash", 0.1], ["dash, low", "_dash", 0.4],
			["dash, up", "_dash", 0.62], ["RMB throw", "_rmb", 0.07]]:
		if not HunterAnim.km_def(id + String(f[1])).is_empty():
			out.append([f[0], id + String(f[1]), f[2], -1])
	for f in KIT_FRAMES.get(id, []):
		if not HunterAnim.km_def(String(f[1])).is_empty():
			out.append([f[0], f[1], f[2], -1])
	return out

## Heroes whose kit moves aren't named <id>_lmb / _dash / _rmb (KMovesStone, Hem's bow): [label, kit move, its time
## (s), arena_demo.gd's timings].
const KIT_FRAMES := {
	"archer": [["draw", "arc_draw", 0.8], ["loose", "arc_loose", 0.94], ["Spirit Walk roll", "pin_roll", 0.58],
		["Heavy Shot", "arc_heavy", 1.42]],
	"dolm": [["punch", "breah_punch", 0.12], ["throw", "breah_throw", 0.2], ["leap", "breah_leap", 0.2],
		["slam", "breah_slam", 0.1], ["sense", "breah_sense", 0.3], ["dash", "breah_hop", 0.15]],
	"ostra": [["orb", "ostra_orb", 0.1], ["snap", "ostra_snap", 0.1], ["swap", "ostra_swap", 0.3],
		["seed", "ostra_seed", 0.2], ["well", "ostra_well", 0.3], ["empower", "ostra_empower", 0.4]],
}

## Plays one move frame and holds it: a run (its extra steps set the stride's phase) or a kit move at its time.
func _frame(an: HunterAnim, h: Node3D, f: Array) -> void:
	var fwd := Vector3(-sin(h.rotation.y), 0, -cos(h.rotation.y))
	var running := int(f[3]) >= 0
	for k in 60 + maxi(0, int(f[3])):
		var s := {"fired": 99.0, "face": h.rotation.y, "grounded": true}
		if running:
			s["vel"] = fwd * 4.6
		else:
			s["kmove"] = f[1]
			s["kmove_t"] = float(f[2])
		an.update(1.0 / 60.0, s)

## Runs the animation into a pose and holds it (as tests/arch_gallery.gd's showcase does).
func _pose(an: HunterAnim, h: Node3D, pose: String, id: String) -> void:
	var s := {"fired": 99.0, "face": h.rotation.y, "grounded": true}
	var fwd := Vector3(-sin(h.rotation.y), 0, -cos(h.rotation.y))
	var steps := 90
	for k in steps:
		s["fired"] = 99.0
		match pose:
			"run":
				s["vel"] = fwd * (5.0 if Arch.weight(id) == "light" else 4.6)
			"attack":
				if k == steps - 9:
					s["swing_n"] = 1
					s["combo"] = 0
			"cast":
				if k >= steps - 12:
					s["cast"] = (k - (steps - 12)) / 60.0
					s["cast_slot"] = "utility"
			"ult":
				if k >= steps - 14:
					s["cast"] = (k - (steps - 14)) / 60.0
					s["cast_slot"] = "ult"
		an.update(1.0 / 60.0, s)
