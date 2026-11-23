extends RefCounted
## --boki-everywhere-check [--species=cindle,...,umbrathere] [--shots-dir=<abs dir>]: is a Boki the
## player meets its rigged Meshy model (BokiRig) or the old primitive body (KinModels' fallback)? Meant to run
## from an exported .pck (godot --main-pack <pck>), where a missing import remap would make has() false.
## Per species it prints the .glb, has(), and whether Models.kin (every place a 3D Boki is shown: wild, your
## own sent out, farm, egg hatch, starter pick, dex, box, portraits) and the hatch/starter reveal card
## (KinReveal) hold a BokiRig, with the model's triangle count. With a renderer and --shots-dir it also writes
## <sp>_game.png (what the game builds), <sp>_old.png (the primitive fallback, BokiRig off) and
## <sp>_reveal.png (the whole window with the reveal card up). Fails if any listed species is not rigged.
## No --species= lists every species with data (Data.KIN); KNOWN_NO_MODEL are the ones waiting for a body and must
## show FALLBACK (the check fails when one gets a .glb without leaving the list). The same run lists every Hunter
## (Arch.ORDER): its drawn .glb, and whether Models.hunter(arch) dressed in it (HUNTER_EVERYWHERE lines).
## Surface map: docs/art/BOKI_3D_SURFACES.md.

const PX := 512
## Species with data but no art/kin body yet (docs/art/kin/MESHY_BOKI_RECIPE.md): they must be the only FALLBACKs.
const KNOWN_NO_MODEL := ["basaltoad", "cindowary"]

var main: Node
var out := ""
var species := PackedStringArray()
var bad := 0


func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--species="):
			species = a.substr(10).split(",")
	if species.is_empty():
		species = PackedStringArray(Data.KIN.keys())
		species.sort()
	var shots := out != "" and DisplayServer.get_name() != "headless"
	if shots:
		DirAccess.make_dir_recursive_absolute(out)
	print("BOKI_EVERYWHERE pck=%s renderer=%s" % [ProjectSettings.globalize_path("res://"), DisplayServer.get_name()])
	for sp in species:
		var p := BokiRig.PATH % [sp, sp]
		var k := Models.kin(sp, {"level": 5})
		var rig := k.find_child("BokiRig", true, false)
		var reveal := KinReveal.new(sp, {"level": 5})
		main.add_child(reveal)
		var rev_rig := reveal.find_child("BokiRig", true, false)
		var waits := KNOWN_NO_MODEL.has(sp)
		print(
			(
				"BOKI_EVERYWHERE %s glb=%s exists=%s has=%s models_kin=%s reveal=%s visitor=%s tris=%d"
				% [
					sp,
					p,
					ResourceLoader.exists(p),
					BokiRig.has(sp),
					"rig" if rig else "FALLBACK",
					"rig" if rev_rig else "FALLBACK",
					"rig" if BokiRig.has(sp) else "FALLBACK",
					_tris(k)
				]
			)
		)
		if (rig == null or rev_rig == null) != waits or (waits and BokiRig.has(sp)):
			bad += 1
		if shots:
			await _shot(k, out.path_join(sp + "_game.png"))
			await _grab_window(out.path_join(sp + "_reveal.png"))
			BokiRig.enabled = false
			await _shot(Models.kin(sp, {"level": 5}), out.path_join(sp + "_old.png"))
			BokiRig.enabled = true
		else:
			k.free()
		reveal.queue_free()
		await main.get_tree().process_frame
	_hunters()
	print("BOKI_EVERYWHERE %s: %d of %d species and hunters off" % ["FAIL" if bad else "OK", bad, species.size()])
	main.get_tree().quit(1 if bad else 0)


## Every Hunter: Models.hunter(arch), as the match, home and lobby build it, must wear its .glb (a "Warden" node).
func _hunters() -> void:
	for arch in Arch.ORDER:
		var h := Models.hunter(Arch.weight(arch), Data.TEAM_COLORS[0], Arch.signature(arch), "", PlayerLook.neutral(), arch)
		var dressed := h.find_child("Warden", true, false) != null
		print(
			(
				"HUNTER_EVERYWHERE %s glb=%s exists=%s native=%s dressed=%s"
				% [arch, WardenGlb.path(arch), WardenGlb.has_model(arch), WardenNative.on(arch), "glb" if dressed else "FALLBACK"]
			)
		)
		if not dressed:
			bad += 1
		h.free()


func _tris(n: Node) -> int:
	var t := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t


## The model alone, front three-quarters, in a lit stage of its own.
func _shot(k: Node3D, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(PX, PX)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Look.environment(
		{"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "stars": 0.0}
	)
	vp.add_child(env)
	Look.lights(vp, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = 24.0
	cam.position = Vector3(0, 0.8, 3.3)
	cam.look_at(Vector3(0, 0.42, 0))
	vp.add_child(k)
	k.rotation.y = PI - 0.6
	for i in 4:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	vp.queue_free()


func _grab_window(path: String) -> void:
	for i in 30:  # the card's intro plays a moment before the Boki is in view
		await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(path)
