extends RefCounted
## --egg-models-check [--shots-dir=<dir>]: the eggs' 3D shells (EggModels, docs/art/EGGS.md). Every egg
## family (each kin type, the Rare Egg, the mystery egg) has its model, 1 m tall at EggHatch's shape, cut
## at half height into a Cap above and a Cup below, light enough for a phone; every kin's type has one; a
## kin's EggHatch wears its type's shell (the mystery egg its own), and the nest's egg, the incubator's and
## the boss drop wear theirs and turn gently, the Rare Egg's seam ring in the kin's glow.
## With --shots-dir (needs a renderer): <dir>/lineup.png, all 17 at the hatch camera, and <dir>/frames/
## fNNNN.png (run it with --fixed-fps 30): the eggs turning, then a mystery egg hatching (ffmpeg -> eggs.mp4).

const TRIS_MAX := 3000         # triangles per egg (both halves): a dozen on screen stays cheap on a phone
const TEX_MAX := 512           # px: the colour map's side
const FIT := 0.02              # m per metre of egg: how close the bake's height, width and cut must land
const FPS := 30
const TURN_S := 4.0            # s of the lineup turning before the hatch

var bad := 0
var main: Node
var frame := 0                 # the next --shots-dir frame

func ok(cond: bool, what: String) -> void:
	print("EGGMODELS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_models()
	await _wearers()
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shots = a.substr(12)
	if shots != "":
		await _shots(shots)
	print("EGGMODELS DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _models() -> void:
	ok(EggModels.KINDS.size() == 17 and EggModels.TINT.size() == EggModels.KINDS.size(),
		"17 egg families, each with its tint")
	var themes := {}
	for sp in Data.KIN:
		themes[EggModels.kind_of(String(sp))] = true
	var missing := themes.keys().filter(func(t): return not EggModels.KINDS.has(t))
	ok(missing.is_empty(), "every kin's type has an egg (%d types; missing %s)" % [themes.size(), str(missing)])
	for kind in EggModels.KINDS:
		var cap := EggModels.half(kind, "Cap", null, 1.0)
		var cup := EggModels.half(kind, "Cup", null, 1.0)
		var a := cap.mesh.get_aabb()
		var b := cup.mesh.get_aabb()
		var tris := 0
		for mi in [cap, cup]:
			tris += (mi.mesh as ArrayMesh).surface_get_array_index_len(0) / 3
		var tex: Texture2D = EggModels.material(kind).get_shader_parameter("albedo_tex")
		var px := tex.get_width() if tex else 0
		var shape := absf(b.position.y) < FIT and absf(a.end.y - 1.0) < FIT and absf(a.position.y - 0.5) < FIT \
			and absf(b.end.y - 0.5) < FIT and absf(b.size.x - 0.736) < FIT * 2.0
		ok(shape and tris <= TRIS_MAX and px > 0 and px <= TEX_MAX,
			"%s: Cap %.2f..%.2f over Cup %.2f..%.2f m, %.2f wide, %d tris, %d px" % [kind, a.position.y, a.end.y,
			b.position.y, b.end.y, b.size.x, tris, px])
		cap.free()
		cup.free()

func _wearers() -> void:
	var tree := main.get_tree()
	var holder := Node3D.new()
	main.add_child(holder)
	var fx := Fx.new()
	holder.add_child(fx)
	var egg := EggHatch.new("cindle", fx, 0.32, 0.42, 1.0, {"species": "cindle"})
	holder.add_child(egg)
	var mys := EggHatch.new("cindle", fx, 0.32, 0.42, 1.0, {"species": "cindle"})
	mys.kind = "mystery"
	holder.add_child(mys)
	var want := EggModels.half("venom", "Cap", null, 1.0)
	var worn := (egg.cap.get_node("Cap") as MeshInstance3D).mesh
	ok(egg.kind == "venom" and worn == want.mesh, "Cindle's EggHatch wears the Venom Egg's shell")
	want.free()
	var cup := EggModels.half("mystery", "Cup", null, 1.0)
	var basket := (mys.cup.get_node("Cup") as MeshInstance3D).mesh
	ok(basket == cup.mesh, "the hatch scene's basket egg wears the mystery shell")
	cup.free()
	var nest := Models.nest_egg("ember")
	var small := Models.rare_egg_small(Color("6fa8ff"), 0.55)
	var drop := BossModels.rare_egg(Color("ff5a8a"))
	for n in [nest, small, drop]:
		holder.add_child(n)
	var shells: Array = [nest.get_node("Shell"), small.get_node("Shell"), drop.get_node("Spin/Shell")]
	var y0: Array = shells.map(func(s): return (s as Node3D).rotation.y)
	for i in 20:
		await tree.process_frame
	var turned := range(3).all(func(i): return absf((shells[i] as Node3D).rotation.y - float(y0[i])) > 0.001)
	ok(turned, "the nest's egg, the incubator's and the boss drop wear their shells and turn gently")
	var seam := ((shells[2] as Node3D).get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	var painted := float(seam.get_shader_parameter("recolor")) == 1.0
	painted = painted and seam.get_shader_parameter("recolor_to") == Color("ff5a8a")
	ok(painted, "the boss's Rare Egg has its seam ring in the kin's glow")
	holder.queue_free()
	await tree.process_frame

func _shots(dir: String) -> void:
	var tree := main.get_tree()
	DirAccess.make_dir_recursive_absolute(dir.path_join("frames"))
	main.get_window().size = Vector2i(1280, 720)
	if main.fade:
		main.fade.reveal(0.05)     # the boot splash stays up when a tool builds a scene by hand
	var holder := _stage()
	var cam := Camera3D.new()
	cam.fov = 40.0
	holder.add_child(cam)
	cam.make_current()
	cam.position = Vector3(0, 3.2, 9.5)
	cam.look_at(Vector3(0, 0.55, 0))
	var eggs := Node3D.new()
	holder.add_child(eggs)
	for i in EggModels.KINDS.size():
		var row := 0 if i < 9 else 1
		var x := float(i - 4) if row == 0 else float(i - 9) - 3.5
		var e := EggModels.shell(EggModels.KINDS[i], 0.8)
		e.position = Vector3(x * 1.05, 0.0, -1.6 * row)
		eggs.add_child(e)
	for i in 10:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(dir.path_join("lineup.png"))
	for i in int(TURN_S * FPS):
		await _frame(dir)
	eggs.queue_free()
	var fx := Fx.new()
	holder.add_child(fx)
	var egg := EggHatch.new("cindle", fx, 0.32, 0.42, 1.1, {"species": "cindle"})
	egg.kind = "mystery"
	egg.scale = Vector3.ONE * 2.2
	holder.add_child(egg)
	cam.position = Vector3(0, 2.2, 5.5)
	cam.look_at(Vector3(0, 0.9, 0))
	var done := [false]
	egg.done.connect(func(): done[0] = true)
	egg.start()
	while not done[0] and frame < FPS * 30:
		await _frame(dir)
	for i in FPS:
		await _frame(dir)
	print("EGGMODELS frames: ", frame)

## Sky, sun and a meadow floor, as the hatch dais.
func _stage() -> Node3D:
	var holder := Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	var sky := {"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "stars": 0.0}
	env.environment = Look.environment(sky)
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 30)
	Models.part(holder, pm, Models.toon(Color("7fb069"), false), Vector3.ZERO)
	return holder

func _frame(dir: String) -> void:
	await RenderingServer.frame_post_draw
	main.get_tree().root.get_texture().get_image().save_png(dir.path_join("frames/f%04d.png" % frame))
	frame += 1
