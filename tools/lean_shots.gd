extends "res://tools/boki_rig_shots.gd"
## --lean-shots --shots-dir=<dir> [--species=a,b] [--foods=a,b,c]: the food lean (Lean) at the garden camera (Home's
## default framing, as farm.png). Each species is one row with base_mode on: fresh, three snacks of each food (from
## fresh), then the part each of those leans grows at a form (Lean.grow_part) on this body. <dir>/lean_<species>.png
## is one row, lean.png all rows stacked. Needs a renderer.

const SPECIES := ["cindle", "puddlet", "burrlet", "zephyrak", "caecilith", "cairnback", "kestrike", "selenfin",
	"hivara", "gloamshell"]
const FOODS := ["emberberry", "tidebloom", "sunroot"]
const SNACKS := 3            # snacks of one food per Boki
const SHOT_ENLARGE := 3      # crop scale-up (nearest), so a fleck a few pixels wide reads on the sheet

func run(m: Node) -> void:
	main = m
	var all: Array = SPECIES
	var foods: Array = FOODS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--species="): all = Array(a.substr(10).split(","))
		if a.begins_with("--foods="): foods = Array(a.substr(8).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	var rows: Array = []
	for sp in all:
		rows.append(await _row(String(sp), foods))
	var sheet := Image.create(rows[0].get_width(), rows[0].get_height() * rows.size(), false, Image.FORMAT_RGBA8)
	for i in rows.size():
		sheet.blit_rect(rows[i], Rect2i(Vector2i.ZERO, rows[i].get_size()), Vector2i(0, i * rows[0].get_height()))
	sheet.save_png(out.path_join("lean.png"))
	print("LEAN_SHOTS_DONE")
	main.get_tree().quit()

## The records of one row: fresh, fed each food, then each of those at its form.
func _recs(sp: String, foods: Array) -> Array:
	var fed: Array = []
	for f in foods:
		var rec := Save.new_kin(sp, "Lean", 7)
		for n in SNACKS:
			Evo.eat(rec, String(f))
		fed.append(rec)
	var formed: Array = []
	for rec in fed:
		var grown: Dictionary = rec.duplicate(true)
		Lean.grow_part(grown)
		formed.append(grown)
	return [Save.new_kin(sp, "Lean", 7)] + fed + formed

func _row(sp: String, foods: Array) -> Image:
	var recs := _recs(sp, foods)
	var vp := _stage(Vector2i(1920, 1080))
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = MATCH_FOV
	var p := deg_to_rad(MATCH_PITCH)
	cam.position = Vector3(0, sin(p), cos(p)) * FARM_DIST
	cam.rotation = Vector3(-p, 0, 0)
	var gap := 1.5 * FARM_BOKI_SCALE
	var half_w := gap * recs.size() * 0.5
	for i in recs.size():
		var k := rigged_kin(sp, recs[i])
		vp.add_child(k)
		k.position = Vector3((i - (recs.size() - 1) * 0.5) * gap, 0, 0)
		var turn := Basis(Vector3.RIGHT, -LEAN) * Basis(Vector3.UP, PI * 0.8)
		k.basis = turn * Basis.from_scale(Vector3.ONE * FARM_BOKI_SCALE)
		var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
		rig.manual = true
		await RenderingServer.frame_post_draw
		rig.set_clip("idle", 0.0)
		rig.seek(0.5)
	var img: Image = await _grab(vp)
	var left := Vector2i(cam.unproject_position(Vector3(-half_w, 2.6, -0.6)))
	var right := Vector2i(cam.unproject_position(Vector3(half_w, -0.2, 0.9)))
	var crop := img.get_region(Rect2i(left, right - left))
	crop.convert(Image.FORMAT_RGBA8)
	crop.resize(crop.get_width() * SHOT_ENLARGE, crop.get_height() * SHOT_ENLARGE, Image.INTERPOLATE_NEAREST)
	crop.save_png(out.path_join("lean_%s.png" % sp))
	vp.queue_free()
	return crop
