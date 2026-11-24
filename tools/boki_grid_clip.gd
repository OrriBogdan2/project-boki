extends RefCounted
## PRIVATE scratch. --boki-grid-clip --shots-dir=<dir> --species=a,b,.. [--muts=a,b] [--secs=6] [--fps=60]: a row of Boki (the species
## list, then one species in each mutation) all turning on one stage, frames <dir>/%04d.jpg.
const Shots := preload("res://tools/boki_rig_shots.gd")

func run(main: Node) -> void:
	var out := ""
	var ids: Array = ["cindle"]
	var muts: Array = []
	var secs := 6.0
	var fps := 60
	var gap := 1.7
	var tight := 1.0
	var look_y := 0.55
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--species="): ids = Array(a.substr(10).split(","))
		if a.begins_with("--muts="): muts = Array(a.substr(7).split(",")) if a.substr(7) != "" else []
		if a.begins_with("--secs="): secs = float(a.substr(7))
		if a.begins_with("--fps="): fps = int(a.substr(6))
		if a.begins_with("--gap="): gap = float(a.substr(6))
		if a.begins_with("--tight="): tight = float(a.substr(8))
		if a.begins_with("--look-y="): look_y = float(a.substr(9))
	main.get_window().size = Vector2i(1920, 1080)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	for _w in 90:
		await RenderingServer.frame_post_draw
	var s := Shots.new()
	s.main = main
	s.px = 1080
	var vp := s._stage(Vector2i(1920, 1080))
	var cam := s._close_cam(vp)
	var items: Array = []
	for id in ids:
		items.append({"sp": String(id), "rec": {}})
	for mu in muts:
		var sp := String(ids[0])
		var rec := {"species": sp, "mutations": [String(mu)]} if String(mu) != "shiny" else {"species": sp, "shimmer": true}
		items.append({"sp": sp, "rec": rec})
	var rigs: Array = []
	var n := items.size()
	for i in n:
		var it: Dictionary = items[i]
		var k := Shots.rigged_kin(it["sp"], it["rec"])
		vp.add_child(k)
		k.position = Vector3((i - (n - 1) * 0.5) * gap, 0, 0)
		rigs.append([k, k.get_node("Body/Flex/BokiRig") as BokiRig])
		(rigs[i][1] as BokiRig).manual = true
		(rigs[i][1] as BokiRig).set_clip("idle", 0.0)
	cam.fov = 30.0
	var width := (n - 1) * gap + 2.2
	var dist := width * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) / (16.0 / 9.0) * tight + 1.0
	cam.position = Vector3(0, 1.0 + dist * 0.08, dist)
	cam.look_at(Vector3(0, look_y, 0))
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out)
	var total := int(secs * fps)
	for f in total:
		var t := float(f) / fps
		for i in n:
			(rigs[i][0] as Node3D).rotation.y = deg_to_rad(200.0 + 360.0 * t / secs)
			var r := rigs[i][1] as BokiRig
			r.seek(fmod(t, r.player.get_animation("idle").length))
		var img: Image = await s._grab(vp)
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(out.path_join("%04d.jpg" % f), 0.92)
	print("BOKI_GRID_DONE n=%d" % n)
	main.get_tree().quit()
