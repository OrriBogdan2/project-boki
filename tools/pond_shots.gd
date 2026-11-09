extends "res://tools/clip_shots.gd"
## --pond-shots --shots-dir=<dir> [--wardens=a,b] [--size=320] [--every=9]: every Hunter on the scripted pond walk
## (tools/pond_walk.gd: bank, shallow channel, deep pond, treading water, out the far side), seen from the side with
## the waterline cut across it. Per Hunter: <dir>/<id>/f000.png... one frame every --every steps (1/30 s each),
## and <dir>/<id>/phases.txt naming each frame's phase. Needs a renderer. A montage script strips them.

const PondWalk := preload("res://tools/pond_walk.gd")
const WATER_COL := Color(0.25, 0.55, 0.85, 0.55)
const BED_DEPTH := 1.2         # m the pond bed lies below the surface

var water: MeshInstance3D
var ground: MeshInstance3D

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = Arch.ORDER.duplicate()
	var every := 9
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
		if a.begins_with("--every="): every = int(a.substr(8))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	ground = holder.get_child(holder.get_child_count() - 2) as MeshInstance3D      # (_stage: ground, then camera)
	water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 60)
	water.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WATER_COL
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = mat
	holder.add_child(water)
	cam.fov = 30.0
	for id in ids:
		await _hunter(String(id), out.path_join(String(id)), every)
	print("POND_SHOTS_DONE ", ids.size())
	tree.quit()

func _hunter(id: String, dir: String, every: int) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	for k in 30:
		await tree.process_frame
	var tall := 1.6 * absf(model.scale.y)
	cam.position = Vector3(tall * 2.4, tall * 0.5, 0)
	cam.look_at(Vector3(0, tall * 0.45, 0))
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	DirAccess.make_dir_recursive_absolute(dir)
	var seen := {"i": 0, "names": ""}      # (a Dictionary: the callback fills it)
	var film := func(info: Dictionary) -> void:
		var wet: bool = info["depth"] > 0
		water.visible = wet
		ground.position.y = -BED_DEPTH if wet else 0.0
		var n: int = seen["i"]
		seen["i"] = n + 1
		if n % every == 0:
			await _grab(dir.path_join("f%03d.png" % (n / every)))
			seen["names"] += "%s\n" % info["phase"]
	await PondWalk.new().walk(tree, model, sync, HunterAnim.new(model), film)
	var f := FileAccess.open(dir.path_join("phases.txt"), FileAccess.WRITE)
	f.store_string(seen["names"])
	f.close()
	model.queue_free()
	await tree.process_frame
