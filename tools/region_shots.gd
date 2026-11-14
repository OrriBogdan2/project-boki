extends RefCounted
## --region-shots --shots-dir=<dir>: review screenshots of The Hollow Crown's regions
## (docs/MAP_REGIONS.md), on a real GPU (jobq submit --needs gpu). For every region: from above
## (<dir>/region_<id>_top.png) and at eye height from its landing toward its landmark
## (<dir>/region_<id>_ground.png); then the drop map with the match's hot zone (<dir>/drop_map.png).

const TOP_H := 2.6        # camera height over a region, per metre of its island's radius
const EYE := 1.7          # m: eye height for the ground-level shot

var main: Node
var m: Match
var dir := ""

func _grab(file: String, frames := 8) -> void:
	for i in frames:
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	print("REGIONSHOT ", file)

func _start(no_drop: bool) -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 6, "squad": 3, "tier": 0, "seed": 77, "no_drop": no_drop, "autoplay": no_drop})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	await _start(true)
	m.hud.visible = false
	var w := m.world
	var cam := Camera3D.new()
	cam.far = 900.0
	main.add_child(cam)
	cam.make_current()
	for R in w.regions:
		var ii := -1
		for k in w.islands.size():
			if String(w.islands[k].get("id", "")) == String(R["islands"][0]):
				ii = k
		var I: Dictionary = w.islands[ii]
		var c := Vector3(I["c"].x + 0.5, 0, I["c"].y + 0.5)
		c.y = w.ground_at(c.x, c.z)
		cam.fov = 50.0
		cam.position = c + Vector3(0, float(I["r"]) * TOP_H, float(I["r"]) * 0.5)
		cam.look_at(c)
		await _grab("region_%s_top" % R["id"])
		# at eye height on its first landing (or its edge), looking across it toward its landmark
		var look := c
		for s in w.landmarks.spots if w.landmarks else []:
			if int(s["island"]) == ii: look = s["pos"]
		var away := (c - look).normalized() if look != c else Vector3(0, 0, 1)
		var from := c + away * float(I["r"]) * 0.6
		from = w.free_spot_near(from, [], 1.0, 0.5, 12.0)
		cam.fov = 70.0
		cam.position = from + Vector3(0, EYE, 0)
		cam.look_at(look + Vector3(0, 4.0, 0))
		await _grab("region_%s_ground" % R["id"])
	cam.queue_free()
	m.queue_free()
	await main.get_tree().process_frame
	await _start(false)
	m.hud.open_map(true)
	await _grab("drop_map", 20)
	main.get_tree().quit(0)
