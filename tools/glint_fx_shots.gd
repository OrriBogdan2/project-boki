extends RefCounted
## --glint-fx-shots --shots-dir=<dir> [--px=256]: <dir>/looks.png, the Glint Fishing looks (GlintFx) in the
## engine over a water sheet, a row each: the bobber's ripple, the waiting rings closing, the bite's splash and the
## catch glint at the three sizes (snack, item, rare). Needs a renderer.

const Shots := preload("res://tools/boki_rig_shots.gd")
const FRAMES := 5
const CATCH_SIZES := ["snack", "item", "rare"]
const CAM_AT := Vector3(0.0, 1.5, 1.9)       # m, the camera over the spot
const WATER := Color("2c6f9e")

var main: Node
var px := 256
var out := ""

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--px="): px = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var shots := Shots.new()
	shots.main = main
	var vp := shots._stage(Vector2i(px, px))
	var water := MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(8, 8)
	water.mesh = sheet
	water.material_override = BaseRace.mat(WATER)
	water.position.y = ZoneDress.SHEET_Y
	vp.add_child(water)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = 40.0
	cam.position = CAM_AT
	cam.look_at(Vector3(0.0, 0.1, 0.0))
	var root := Node3D.new()
	vp.add_child(root)
	var fx := GlintFx.new(root)
	var sheet_img := Image.create(px * FRAMES, px * 5, false, Image.FORMAT_RGBA8)
	var at := Vector3(0.0, ZoneDress.SHEET_Y, 0.0)
	var recs := GlintFx.recipes()
	for f in FRAMES:
		var k := float(f) / float(FRAMES - 1)
		fx.hide_all()
		fx.play("plop", at)
		fx.tick(float(recs["plop"]["life"]) * k * 0.8)
		await _put(vp, sheet_img, f, 0)
		fx.hide_all()
		fx.wait_rings(at, k)
		await _put(vp, sheet_img, f, 1)
		fx.hide_all()
		fx.play("bite", at)
		fx.tick(float(recs["bite"]["life"]) * k * 0.8)
		await _put(vp, sheet_img, f, 2)
		fx.hide_all()
		fx.play("catch", at, CATCH_SIZES[mini(f, CATCH_SIZES.size() - 1)])
		fx.tick(float(recs["catch"]["life"]) * 0.35)
		await _put(vp, sheet_img, f, 3)
		fx.hide_all()
		fx.play("catch", at, "rare")
		fx.tick(float(recs["catch"]["life"]) * k * 0.9)
		await _put(vp, sheet_img, f, 4)
	sheet_img.save_png(out.path_join("looks.png"))
	print("GLINT_FX_SHOTS_DONE")
	main.get_tree().quit()

func _put(vp: SubViewport, sheet_img: Image, col: int, row: int) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	sheet_img.blit_rect(vp.get_texture().get_image(), Rect2i(0, 0, px, px), Vector2i(px * col, px * row))
