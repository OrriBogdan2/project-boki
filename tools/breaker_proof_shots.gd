extends RefCounted
## --breaker-proof-shots --shots-dir=<dir> [--parts=chain,fish,guard,ult]: on-screen proof for Breaker's fidelity
## rows. chain_*.png: a real arena throw at the match camera, the chain from his wrist to the flying hammer.
## fish_*.png: the anglerfish close up: walking (bob), a blocked hit (shiver), the ult (flare); prints how far it
## moved. guard_*.png: the aegis raised (his wooden shield up) at the match camera and close up. ult_*.png: the
## Faultline wind-up, slam and eruption at the match camera. Needs a renderer.

const DT := 1.0 / 60.0
const STRIP := 6

var out := ""
var parts := ["chain", "fish", "guard", "ult"]


func _grab(main: Node, nm: String) -> void:
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(out.path_join(nm))


func run(main: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		elif a.begins_with("--parts="):
			parts = Array(a.substr(8).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	if "chain" in parts:
		await _chain(main)
	if "fish" in parts:
		await _fish(main)
	if "guard" in parts:
		await _guard(main)
	if "ult" in parts:
		await _ult(main)
	print("BREAKER_PROOF_DONE")
	main.get_tree().quit()


func _chain(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start(Match.arena_opts("bulwark"))
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
	for i in 60:  # walking: the root sways as a step does, the line swings
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


## One match step, then his pose as the match's frame draws it (Match._process is off: Hunter.render poses him).
func _tick(main: Node, m: Match) -> void:
	m.step(DT)
	(m.player as Hunter).render(DT, 1.0)
	await main.get_tree().process_frame


func _arena(main: Node) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start(Match.arena_opts("bulwark"))
	m.set_process(false)
	if m.hud:
		m.hud.visible = false
	for layer in m.find_children("*", "CanvasLayer", true, false):  # the drill card and the zone's buttons
		(layer as CanvasLayer).visible = false
	return m


## The aegis held toward the screen's right and toward the camera at the match camera, then close up from his front
## left at three heights (high, eye, knee), the wall hidden at the last, then straight down from above.
func _guard(main: Node) -> void:
	var m := _arena(main)
	var p: Hunter = m.player
	for aim in [Vector3(7, 0, 0), Vector3(2, 0, 7)]:
		p.inp["aim"] = p.pos + aim
		p.inp["sec_hold"] = true
		p.ak.press_rmb()
		for i in 40:
			p.inp["sec_hold"] = true
			await _tick(main, m)
		await _grab(main, "guard_match_%s.png" % ("side" if aim.z == 0.0 else "front"))
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.fov = 34.0
	var fwd := Vector3(p.aim_dir().x, 0, p.aim_dir().y)
	cam.current = true
	var heights := {"guard_close": 2.2, "guard_eye": 1.4, "guard_knee": 0.45}
	for shot: String in heights:
		var from := p.pos + fwd * 5.5 + fwd.cross(Vector3.UP) * 2.0 + Vector3(0, float(heights[shot]), 0)
		cam.look_at_from_position(from, p.pos + Vector3(0, 1.1, 0), Vector3.UP)
		for i in 6:
			p.inp["sec_hold"] = true
			await _tick(main, m)
		await _grab(main, "%s.png" % shot)
	var aegis := (p.ak as BulwarkKit).fx.aegis
	aegis.visible = false
	await _grab(main, "guard_knee_nowall.png")
	aegis.visible = true
	cam.look_at_from_position(p.pos + Vector3(0, 9.0, 0.01), p.pos, Vector3.UP)
	await _grab(main, "guard_top.png")
	p.inp["sec_hold"] = false
	m.queue_free()
	await main.get_tree().process_frame


## Faultline toward the screen's right: the wind-up, the slam and the eruption, timed from the press.
func _ult(main: Node) -> void:
	var m := _arena(main)
	var p: Hunter = m.player
	p.lvl = 6
	p.ak.cd["x"] = 0.0
	p.inp["aim"] = p.pos + Vector3(7, 0, 2)
	HunterKeys.ult_pressed(p)
	var shots := {12: "ult_wind", 27: "ult_slam", 36: "ult_erupt", 54: "ult_late"}
	for i in 60:
		await _tick(main, m)
		if shots.has(i):
			await _grab(main, "%s.png" % shots[i])
	m.queue_free()
	await main.get_tree().process_frame
