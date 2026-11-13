extends RefCounted
## --glide-trail-shots --shots-dir=<dir>: two squads of three gliding past each other high over the island, seen
## along the match camera's angle and lens from 40 m and 80 m (run under a renderer: jobq submit --needs gpu). The near
## squad is the player's (allies), the far one rivals; each trail is in its squad's colour. Files: glide_40m.png,
## glide_80m.png, and the same frames with the trails hidden (glide_<d>m_off.png) to judge what they add.

const DT := 1.0 / 60.0
const DISTS := [40.0, 80.0]     # m from the squads' middle to the camera
const HEIGHT := 22.0            # m over the ground the squads glide at
const SPEED := 9.0              # m/s: a drop glide, faster than a level one
const RUN_S := 1.5              # s of gliding before the frame: the trails are full length
const GAP := 4.0                # m between squad mates; the squads pass 10 m apart

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var gt := GlideTrail.of(m)
	gt.set_process(false)
	var mid: Vector3 = m.player.pos + Vector3(0, HEIGHT, 0)
	for layer in main.find_children("*", "CanvasLayer", true, false):
		layer.visible = false     # the HUD and the training drill panels sit over the middle of the frame
	var cam := Camera3D.new()
	main.add_child(cam)
	m.cam.snap(m.player.pos)
	await main.get_tree().process_frame
	cam.fov = m.cam.fov           # the match lens (32 deg), so 40 m and 80 m look as far as they do in play
	cam.far = DISTS.max() + 60.0
	var look := -main.get_viewport().get_camera_3d().global_basis.z
	for d in DISTS:
		_place(m, mid)
		cam.global_position = mid - look * d
		cam.look_at(mid)
		cam.current = true
		for i in int(RUN_S / DT):
			_fly(m, gt)
			await main.get_tree().process_frame
		var tag := "glide_%dm" % int(d)
		main.get_viewport().get_texture().get_image().save_png(dir.path_join(tag + ".png"))
		gt.visible = false
		await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png(dir.path_join(tag + "_off.png"))
		gt.visible = true
	print("GLIDETRAILSHOTS %d frames in %s" % [DISTS.size() * 2, dir])
	main.get_tree().quit(0)

## The player's squad in a line flying +x, the rival squad flying -x, 10 m further from the camera.
func _place(m: Match, mid: Vector3) -> void:
	var seen := {}
	for h in m.hunters:
		var side := 0 if h.team == m.player.team else 1
		var k: int = seen.get(side, 0)
		seen[side] = k + 1
		var dir := 1.0 if side == 0 else -1.0
		h.pos = mid + Vector3(-dir * (6.0 + GAP * k), 0, -10.0 * side + 1.5 * k)
		h.vel = Vector3(dir * SPEED, -1.0, 0)
		h.grounded = false
		h.gliding = true
		h.out = false
		h.rotation.y = -dir * PI / 2

## Moves every Hunter along its glide by hand (the sim would steer the bots elsewhere) and draws a frame.
func _fly(m: Match, gt: GlideTrail) -> void:
	for h in m.hunters:
		h.pos += h.vel * DT
		h.render(DT, 1.0)
	gt.step(DT)
