extends RefCounted
## --boki-idle-shots --shots-dir=<dir> [--px=192] [--species=a,b]: every rigged Boki's idle in the engine, one row each:
## four frames of the breath, then four across its fidget. <dir>/idle_<id>.png per species and idle_all.png (a row
## per species). Needs a renderer.
## --film --shots-dir=<dir> [--species=a,b]: the same Bokis filmed live, FILM_S s each in one <dir>/idle_film.avi (a
## label names each), a fidget forced at FILM_FIDGET_S. The movie writer's flags are engine arguments, so a plain
## run re-launches itself as a child Godot under --write-movie (the child gets --film-child); cut it per species at
## FILM_S s multiples (ffmpeg -ss/-t). Run it on a GPU worker (jobq submit --needs gpu).
## --clip: instead, <dir>/clip_<id>/%04d.jpg, CLIP_S s at CLIP_FPS of each species as it plays in a match: the idle
## breathing, then one fidget (from CLIP_LEAD s), then the idle again. Encode: ffmpeg -framerate 30 -i
## <dir>/clip_<id>/%04d.jpg -c:v libx264 -crf 22 -pix_fmt yuv420p <id>.mp4

const Shots := preload("res://tools/boki_rig_shots.gd")
const Rig := preload("res://tools/boki_rig_check.gd")
const TILES := 4
const YAW := PI * 0.72
const FILM_S := 6.0
const FILM_FPS := 30
const FILM_FIDGET_S := 0.6
const FILM_RES := "1280x720"
const FILM_WARMUP := 120  # frames before the first species (the boot splash is still up)
const CLIP_S := 6.0
const CLIP_FPS := 30
const CLIP_LEAD := 1.0  # s of plain idle before the fidget

var main: Node
var out := ""
var px := 192
var only: Array = []
var clip := false


func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--px="):
			px = int(a.substr(5))
		if a == "--clip":
			clip = true
		if a.begins_with("--species="):
			only = Array(a.substr(10).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var ids: Array = only if not only.is_empty() else Rig.SPECIES_LIST
	if "--film" in OS.get_cmdline_user_args():
		if "--film-child" in OS.get_cmdline_user_args():
			await _film(ids)
		else:
			_record()
		return
	if clip:
		for id in ids:
			await _clip(String(id))
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


func _tile(vp: SubViewport, rig: BokiRig, s: Object, row: Image, clip_v: String, at: float, tile: int) -> void:
	rig.set_clip(clip_v, 0.0)
	rig.set_face("neutral")
	rig.seek(at)
	var img: Image = await s._grab(vp)
	img.convert(Image.FORMAT_RGBA8)
	row.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(tile * px, 0))


## Child: every species in turn on one stage, `FILM_S` s of the real clips (the rig steps itself), one fidget forced.
func _film(ids: Array) -> void:
	var s := Shots.new()
	s.main = main
	var wh := FILM_RES.split("x")
	var box := SubViewportContainer.new()
	box.size = Vector2(int(wh[0]), int(wh[1]))
	main.add_child(box)
	var vp := s._stage(Vector2i(int(wh[0]), int(wh[1])))
	main.remove_child(vp)
	box.add_child(vp)
	var cam := s._close_cam(vp)
	cam.position = Vector3(0, 0.7, 2.9)
	cam.look_at(Vector3(0, 0.36, 0))
	for w in FILM_WARMUP:
		await main.get_tree().process_frame  # the splash fades out before the first species
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 28)
	label.position = Vector2(24, 16)
	main.add_child(label)
	for id in ids:
		s.species = String(id)
		var kr := s._kin(vp)
		var rig := kr[1] as BokiRig
		rig.manual = true
		rig.set_clip("idle", 0.0)
		(kr[0] as Node3D).rotation.y = YAW
		label.text = "%s" % id
		print("IDLEFILM %s movie_frame=%d" % [id, Engine.get_frames_drawn()])
		for f in int(FILM_S * FILM_FPS):
			if f == int(FILM_FIDGET_S * FILM_FPS):
				rig.set_clip(BokiIdle.FIDGET, 0.15)
			elif rig.clip == BokiIdle.FIDGET and not rig.player.is_playing():
				rig.set_clip("idle", 0.15)
			await main.get_tree().process_frame
		(kr[0] as Node3D).queue_free()
	print("BOKI_IDLE_FILM_DONE")
	main.get_tree().quit()


## The movie writer's flags are engine arguments and the workers pass only user arguments: run this again as a child.
func _record() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var cfg := root.path_join("override.cfg")
	var wh := FILM_RES.split("x")
	var f := FileAccess.open(cfg, FileAccess.WRITE)
	f.store_string("[display]\n\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\n\n" % [wh[0], wh[1]])
	f.store_string("[editor]\n\nmovie_writer/mjpeg_quality=0.95\n")
	f.close()
	var args := ["--path", root, "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--resolution", FILM_RES,
		"--fixed-fps", str(FILM_FPS), "--write-movie", out.path_join("idle_film.avi"), "--"]
	args.append_array(OS.get_cmdline_user_args())
	args.append("--film-child")
	var res: Array = []
	var rc := OS.execute(OS.get_executable_path(), args, res, true)
	DirAccess.remove_absolute(cfg)
	for line in (String(res[0]) if res.size() > 0 else "").split("\n"):
		if line.begins_with("IDLEFILM") or line.begins_with("BOKI_IDLE") or line.contains("ERROR"):
			print(line)
	print("IDLEFILM child rc=%d" % rc)
	main.get_tree().quit(rc)


func _clip(id: String) -> void:
	var s := Shots.new()
	s.main = main
	s.px = px
	s.species = id
	var vp := s._stage(Vector2i(px, px))
	s._close_cam(vp)
	var kr := s._kin(vp)
	var rig := kr[1] as BokiRig
	(kr[0] as Node3D).rotation.y = YAW
	var dir := out.path_join("clip_%s" % id)
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	var fid_s := rig.player.get_animation(BokiIdle.FIDGET).length
	rig.set_face("neutral")
	var last := ""
	for f in int(CLIP_S * CLIP_FPS):
		var t := float(f) / CLIP_FPS
		var name := "idle"
		var at := t
		if t >= CLIP_LEAD and t < CLIP_LEAD + fid_s:
			name = BokiIdle.FIDGET
			at = t - CLIP_LEAD
		elif t >= CLIP_LEAD + fid_s:
			at = t - CLIP_LEAD - fid_s
		if name != last:
			rig.set_clip(name, 0.0)
			last = name
		rig.seek(fmod(at, rig.player.get_animation(name).length))
		var img: Image = await s._grab(vp)
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(dir.path_join("%04d.jpg" % f), 0.9)
	print("BOKI_IDLE_CLIP %s fidget %.1f s" % [id, fid_s])
	vp.queue_free()
