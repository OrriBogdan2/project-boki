extends RefCounted
## --prop-draws-check (perf, 11-11): the props whose plain parts merge into one mesh per material
## (Models.merge_static / merge_tree) stay at the draws they were measured at, and keep every named
## node the game finds them by (HomeIncubator's cradles, pebbles and grates, the burrow's windows and
## light, a chest's two padlocks). A draw is a mesh surface plus its outline pass.
## With --shots-dir=<dir> it also renders them in a lit row with shadows on and saves lineup.png,
## for a before/after look:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -- --prop-draws-check --shots-dir=/tmp/s

## Draws per model as measured on 11-11 (before the merges: chest with its padlocks 37, key 10,
## stall L1 32, L3 69, nook 60, incubator 235, burrow 67).
const MAX_DRAWS := {"chest": 29, "key": 6, "stall1": 20, "stall3": 38, "nook": 17, "incubator": 173, "burrow": 37}

var fails := 0

func ok(cond: bool, what: String) -> void:
	print("PROPDRAWS %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main: Node) -> void:
	var models := {"chest": Models.chest(), "key": KeyModels.pickup(), "stall1": StallModels.build(1),
		"stall3": StallModels.build(3), "nook": Models.nesting_nook(), "incubator": Models.incubator(),
		"burrow": KinBurrow.model(2)}
	KeyChest.dress(models["chest"])
	for id in MAX_DRAWS:
		var d := draws(models[id])
		ok(d <= int(MAX_DRAWS[id]), "%s draws %d (at most %d)" % [id, d, MAX_DRAWS[id]])
	var inc: Node3D = models["incubator"]
	var names := ["Shelf", "Embers", "Glow"]
	for i in 8:
		names.append_array(["C%d" % i, "C%d/Egg" % i, "C%d/Lock" % i, "C%d/Nest" % i])
		for j in 6: names.append("C%d/P%d" % [i, j])
	for i in 6: names.append("Shelf/S%d" % i)
	ok(names.all(func(nm): return inc.has_node(nm)), "incubator keeps its %d named nodes" % names.size())
	ok(inc.get_node("C0/P0") is MeshInstance3D, "a cradle's pebble is still its own mesh (it lights up)")
	var bur: Node3D = models["burrow"]
	var bur_names := ["Mound", "Turf", "Door", "Lantern", "Glow", "Window0"]
	ok(bur_names.all(func(nm): return bur.has_node(nm)), "burrow keeps its named parts")
	var ch: Node3D = models["chest"]
	ok(ch.has_node("Body/Lock") and ch.has_node("LockTag"), "a locked chest wears both padlocks")
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shots = a.substr(12)
	if shots != "":
		await _lineup(main, models.values(), shots)
	else:
		for n in models.values(): (n as Node).free()
	print("PROPDRAWS DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

## Mesh draws in a model: each visible surface, plus its outline (next pass).
static func draws(n: Node) -> int:
	var d := 0
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or not mi.visible: continue
		for si in mi.mesh.get_surface_count():
			var m: Material = mi.material_override if mi.material_override else mi.get_active_material(si)
			while m:
				d += 1
				m = m.next_pass
	return d

## The models in a row under a low sun with shadows on, seen from the farm camera's angle.
func _lineup(main: Node, nodes: Array, dir: String) -> void:
	var root := Node3D.new()
	main.add_child(root)
	var x := 0.0
	for n in nodes:
		root.add_child(n)
		(n as Node3D).position = Vector3(x, 0, 0)
		x += 4.0
	var ground := MeshInstance3D.new()
	ground.mesh = Models.box(x + 6.0, 0.1, 10.0)
	ground.material_override = Models.toon(Color("6f8f55"), false)
	ground.position = Vector3(x * 0.5 - 2.0, -0.05, 0)
	root.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation = Vector3(-0.9, 0.6, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 40.0
	cam.position = Vector3(x * 0.5 - 2.0, 7.0, 9.0)
	cam.look_at(Vector3(x * 0.5 - 2.0, 0.6, 0))
	cam.make_current()
	if main.get("fade") != null:
		main.fade.reveal(0.01)      # (the boot splash covers the screen until a first screen is up)
	main.get_window().size = Vector2i(1600, 600)
	for i in 20:
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("lineup.png"))
	print("PROPDRAWS shot %s" % dir.path_join("lineup.png"))
	root.queue_free()
