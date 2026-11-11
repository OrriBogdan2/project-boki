extends RefCounted
## --incubator-shots --shots-dir=<dir> [--shots-secs=<s>] [--shots-fps=<n>]: the egg stages on the eggs
## themselves, for the owner video. Five Rare Eggs in the cradles, warmed at different paces (egg 1 at full,
## egg 5 at a fifth) over `secs` seconds of film (default 12, 24 fps), so 20 minutes of play plays in
## `secs`. Writes <dir>/frames/NNNNN.jpg; make the clip off the box:
##   ffmpeg -framerate 24 -i <dir>/frames/%05d.jpg -c:v libx264 -pix_fmt yuv420p <dir>/egg_stages.mp4
## Run under xvfb with a renderer. Never touches the real save.

const PACES := [1.0, 0.8, 0.6, 0.4, 0.2]      # each cradle's share of the full warmth by the last frame
const FRAME_W := 960                          # px wide

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
	home.day_t = 0.5
	var at: Vector3 = home.hinc.at()
	home.ppos = at + Vector3(0, 0, 3.0)
	home.player.position = home.ppos
	home.cam.snap(at + Vector3(0, 0, 0.5))
	var n := int(secs * fps)
	for f in n:
		var frac := float(f) / float(n - 1)
		for e in Incubator.eggs():
			e["heat"] = Incubator.need() * frac * float(PACES[int(e["slot"])])
		home.hinc.film_t = float(f) / fps
		await main.get_tree().process_frame
		var img: Image = main.get_viewport().get_texture().get_image()
		img.resize(FRAME_W, int(FRAME_W * float(img.get_height()) / float(img.get_width())))
		img.save_jpg(dir.path_join("frames/%05d.jpg" % f), 0.85)
	print("INCUBATOR SHOTS DONE, frames: ", n)
	main.get_tree().quit()
