extends RefCounted
## --boki-idle-shots --shots-dir=<dir> [--px=192] [--species=a,b] [--frames=<s>]: every rigged Boki's idle in the
## engine, one row each: four frames of the breath, then four across its fidget. <dir>/idle_<id>.png per species and
## idle_all.png (a row per species). With --frames=6 it writes a 30 fps PNG sequence of that many seconds instead
## (a lead of breath, the fidget once, breath again) to <dir>/frames_<id>/f0000.png, for ffmpeg. Needs a renderer.

const Shots := preload("res://tools/boki_rig_shots.gd")
const Rig := preload("res://tools/boki_rig_check.gd")
const TILES := 4
const YAW := PI * 0.72
const FPS := 30
const LEAD_S := 0.6

var main: Node
var out := ""
var px := 192
var only: Array = []
var frames_s := 0.0


func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--px="):
			px = int(a.substr(5))
		if a.begins_with("--species="):
			only = Array(a.substr(10).split(","))
		if a.begins_with("--frames="):
			frames_s = float(a.substr(9))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var ids: Array = only if not only.is_empty() else Rig.SPECIES_LIST
	if frames_s > 0.0:
		for id in ids:
			await _film(String(id))
		print("BOKI_IDLE_SHOTS_DONE")
		main.get_tree().quit()
		return
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


## `frames_s` s at 30 fps of one species: LEAD_S of breath, its fidget played through once, breath again. The
## fidget clip is the idle tiled with the fidget laid in, so going back to "idle" at the same phase is seamless.
func _film(id: String) -> void:
	var s := Shots.new()
	s.main = main
	s.px = px
	s.species = id
	var vp := s._stage(Vector2i(px, px))
	s._close_cam(vp)
	var kr := s._kin(vp)
	var rig := kr[1] as BokiRig
	(kr[0] as Node3D).rotation.y = YAW
	var dir := out.path_join("frames_%s" % id)
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	var idle_len := rig.player.get_animation("idle").length
	var fid_len := rig.player.get_animation(BokiIdle.FIDGET).length
	for f in int(frames_s * FPS):
		var t := float(f) / FPS
		var in_fidget := t >= LEAD_S and t - LEAD_S < fid_len
		rig.set_clip(BokiIdle.FIDGET if in_fidget else "idle", 0.0)
		rig.set_face("neutral")
		rig.seek(t - LEAD_S if in_fidget else fposmod(t - LEAD_S, idle_len))
		var img: Image = await s._grab(vp)
		img.save_png(dir.path_join("f%04d.png" % f))
	vp.queue_free()
	print("BOKI_IDLE_FILM %s %d frames, idle %.2f s, fidget %.2f s" % [id, int(frames_s * FPS), idle_len, fid_len])
