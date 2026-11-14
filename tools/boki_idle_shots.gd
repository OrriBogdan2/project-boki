extends RefCounted
## --boki-idle-shots --shots-dir=<dir> [--px=192] [--species=a,b]: every rigged Boki's idle in the engine, one row each:
## four frames of the breath, then four across its fidget. <dir>/idle_<id>.png per species and idle_all.png (a row
## per species). Needs a renderer.

const Shots := preload("res://tools/boki_rig_shots.gd")
const Rig := preload("res://tools/boki_rig_check.gd")
const TILES := 4
const YAW := PI * 0.72

var main: Node
var out := ""
var px := 192
var only: Array = []

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--px="): px = int(a.substr(5))
		if a.begins_with("--species="): only = Array(a.substr(10).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var ids: Array = only if not only.is_empty() else Rig.SPECIES_LIST
	var all := Image.create(px * TILES * 2, px * ids.size(), false, Image.FORMAT_RGBA8)
	for r in ids.size():
		var row: Image = await _row(String(ids[r]))
		row.save_png(out.path_join("idle_%s.png" % ids[r]))
		all.blit_rect(row, Rect2i(0, 0, row.get_width(), px), Vector2i(0, r * px))
	all.save_png(out.path_join("idle_all.png"))
	print("BOKI_IDLE_SHOTS_DONE")
	main.get_tree().quit()

func _row(id: String) -> Image:
	var s := Shots.new()
	s.main = main
	s.px = px
	s.species = id
	var vp := s._stage(Vector2i(px, px))
	s._close_cam(vp)
	var kr := s._kin(vp)
	var rig := kr[1] as BokiRig
	(kr[0] as Node3D).rotation.y = YAW
	var win: Dictionary = BokiIdle.config()["species"][id]["fidget"]
	var row := Image.create(px * TILES * 2, px, false, Image.FORMAT_RGBA8)
	await RenderingServer.frame_post_draw
	var idle_s := rig.player.get_animation("idle").length
	for i in TILES:
		await _tile(vp, rig, s, row, "idle", idle_s * i / TILES, i)
	for i in TILES:
		var at := float(win["at"]) + float(win["dur"]) * (i + 0.5) / TILES
		await _tile(vp, rig, s, row, BokiIdle.FIDGET, at, TILES + i)
	vp.queue_free()
	return row

func _tile(vp: SubViewport, rig: BokiRig, s: Object, row: Image, clip: String, at: float, tile: int) -> void:
	rig.set_clip(clip, 0.0)
	rig.set_face("neutral")
	rig.seek(at)
	var img: Image = await s._grab(vp)
	img.convert(Image.FORMAT_RGBA8)
	row.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(tile * px, 0))
