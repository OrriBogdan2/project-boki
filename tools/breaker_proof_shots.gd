extends RefCounted
## --breaker-proof-shots --shots-dir=<dir>: on-screen proof for Breaker's fidelity rows. chain_*.png: a real arena
## throw at the match camera, the chain from his wrist to the flying hammer. fish_*.png: the anglerfish close up:
## walking (bob), a blocked hit (shiver), the ult (flare); prints how far it moved. Needs a renderer.

const DT := 1.0 / 60.0
const STRIP := 6

var out := ""

func _grab(main: Node, nm: String) -> void:
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(out.path_join(nm))

func run(main: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	await _chain(main)
	await _fish(main)
	print("BREAKER_PROOF_DONE")
	main.get_tree().quit()

func _chain(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("bulwark"))
	m.set_process(false)
	var P: Hunter = m.player
	P.fire_cd = 0.0
	P.inp["aim"] = P.pos + Vector3(7, 0, 0)
	for i in 70:
		P.inp["fire"] = i < 5
		m.step(DT)
		if i % 11 == 10:
			await main.get_tree().process_frame
			await _grab(main, "chain_%02d.png" % i)
	m.queue_free()
	await main.get_tree().process_frame

func _fish(main: Node) -> void:
	var holder := Node3D.new()
	main.add_child(holder)
	var a := "bulwark"
	var model := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", PlayerLook.neutral(), a)
	holder.add_child(model)
	model.rotation.y = 0.0
	var sync := model.get_node("Warden/Sync") as WardenGlb.Sync
	var an := HunterAnim.new(model)
	var cam := Camera3D.new()
	holder.add_child(cam)
	cam.position = Vector3(1.4, 2.2, -3.4)
	cam.look_at_from_position(cam.position, Vector3(1.4, 2.1, 0.0), Vector3.UP)
	cam.fov = 40.0
	cam.current = true
	var sk := WardenGlb.skeleton(model.get_node("Warden"))
	var fish := WardenSkeleton.find(sk, "x_fish")
	var st := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}
	for i in 40:
		an.update(DT, st)
		sync._process(DT)
	var rest := sk.get_bone_global_pose(fish).origin
	var far := 0.0
	for i in 60:      # walking: the root sways as a step does, the line swings
		model.position.x = 0.12 * sin(i * 0.3)
		an.update(DT, st)
		sync._process(DT)
		far = maxf(far, sk.get_bone_global_pose(fish).origin.distance_to(rest))
		if i % 12 == 0:
			await _grab(main, "fish_bob_%02d.png" % i)
	print("BREAKER_PROOF fish swing %.2f m" % far)
	model.position.x = 0.0
	WardenMood.poke(model)
	for i in 6:
		an.update(DT, st)
		sync._process(DT)
		await _grab(main, "fish_shiver_%02d.png" % i)
	await _grab(main, "fish_calm.png")
	model.set_meta(WardenMood.FLARE, true)
	for i in 40:
		an.update(DT, st)
		sync._process(DT)
	await _grab(main, "fish_flare.png")
	model.set_meta(WardenMood.FLARE, false)
	holder.queue_free()
