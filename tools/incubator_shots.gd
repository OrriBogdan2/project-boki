extends RefCounted
## --incubator-shots --shots-dir=<dir> [--shots-secs=<s>] [--shots-fps=<n>]: the egg stages on the eggs
## themselves, for the owner video. Five Rare Eggs in the cradles, warmed at different paces (egg 1 at full,
## egg 5 at a fifth) over `secs` seconds of film (default 12, 24 fps), so 20 minutes of play plays in
## `secs`, then HOLD seconds on the end. Writes <dir>/frames/NNNNN.jpg; make the clip off the box:
##   ffmpeg -framerate 24 -i <dir>/frames/%05d.jpg -c:v libx264 -pix_fmt yuv420p <dir>/egg_stages.mp4
## No GPU free? Software GL works (slow but fine for this):
##   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 ...
## Run under xvfb with a renderer. Never touches the real save.

const PACES := [1.0, 0.8, 0.6, 0.4, 0.2]      # each cradle's share of the full warmth by the last frame
const FRAME_W := 960                          # px wide
const ZOOM := 0.22                            # close on the cradles (the Nook demo's close-up is 0.42)
const HOLD := 2.0                             # seconds of film held at the end: the ready egg rattles
const SETTLE := 20                            # frames for the cover, light and camera to settle first

var main: Node

func run(m: Node) -> void:
	main = m
	var dir := ""
	var secs := 12.0
	var fps := 24
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
		if String(a).begins_with("--shots-secs="): secs = float(String(a).substr(13))
		if String(a).begins_with("--shots-fps="): fps = int(String(a).substr(12))
	DirAccess.make_dir_recursive_absolute(dir.path_join("frames"))
	Save.no_write = true
	Save.d = Save.fresh()
	var k := Save.new_kin("puddlet", "Drip")
	k["starter"] = true
	Save.d["roster"] = [k]
	Save.d["active"] = k["uid"]
	Save.d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	for i in PACES.size():
		Incubator.add(String(Data.common_kin()[i % Data.common_kin().size()]))
	var home = await main._hb_home()
	if main.get("fade") != null:
		main.fade.reveal(0.01)      # lift the boot cover, or every frame is the logo
		home.day_t = 0.5
	var mid := Vector3.ZERO
	for i in PACES.size():
		mid += home.hinc.slot_pos(i) / PACES.size()
	home.ppos = Vector3(mid.x, 0, mid.z)      # the camera follows you: stand among the eggs, unseen
	home.player.position = home.ppos
	home.player.visible = false
	home.cam.snap(home.ppos)
	home.cam.zoom_to = ZOOM
	home.cam.zoom = ZOOM
	for _f in SETTLE:
		await main.get_tree().process_frame
	var n := int(secs * fps)
	for f in n + int(HOLD * fps):
		var frac := minf(1.0, float(f) / float(n - 1))
		for e in Incubator.eggs():
			e["heat"] = Incubator.need() * frac * float(PACES[int(e["slot"])])
		home.hinc.film_t = float(f) / fps
		await main.get_tree().process_frame
		var img: Image = main.get_viewport().get_texture().get_image()
		img.resize(FRAME_W, int(FRAME_W * float(img.get_height()) / float(img.get_width())))
		img.save_jpg(dir.path_join("frames/%05d.jpg" % f), 0.85)
	print("INCUBATOR SHOTS DONE, frames: ", n + int(HOLD * fps))
	main.get_tree().quit()
