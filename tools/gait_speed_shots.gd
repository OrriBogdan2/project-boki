extends "res://tools/clip_shots.gd"
## --gait-speed-shots --shots-dir=<dir> [--wardens=juggernaut,thief] [--size=240]: Heroes under a Slow crossing a
## still side camera over floor ticks every 0.25 m, the loops played by WardenClips at the slowed ground speed:
## <dir>/slowed_strip.png, a row of SHOTS frames per Hero at 20 fps. A planted foot holds over its tick.
## Needs a renderer.

const DT := 1.0 / 60.0
const SLOW := 0.65             # of the run speed: Hunter.slow_mult under a Slow
const SETTLE := 90             # frames at the speed before filming
const SHOTS := 10              # frames filmed per Hero
const EVERY := 3               # frames between them
const TICK := 0.25             # m between floor ticks
const VIEW := 3.0              # m the frame covers

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids := ["juggernaut", "thief"]
	frame_px = 240
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	_ticks()
	for k in 30:
		await tree.process_frame     # (past the splash)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = VIEW
	cam.position = Vector3(0.0, 1.4, 6.0)
	cam.look_at(Vector3(0.0, 0.9, 0.0))
	var sheet := Image.create(frame_px * SHOTS, frame_px * ids.size(), false, Image.FORMAT_RGBA8)
	for row in ids.size():
		var frames := await _film(String(ids[row]))
		for col in frames.size():
			var img: Image = frames[col]
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(col, row) * frame_px)
	DirAccess.make_dir_recursive_absolute(out)
	sheet.save_png(out.path_join("slowed_strip.png"))
	print("GAIT_SPEED_SHOTS_DONE ", ids)
	tree.quit()

## Pale ticks across the Hero's path.
func _ticks() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.004, 0.7)
	for k in range(-16, 17):
		var tick := MeshInstance3D.new()
		tick.mesh = box
		tick.material_override = Models.toon(Color("f2ead2"), false)
		tick.position = Vector3(k * TICK, 0.002, 0.0)
		holder.add_child(tick)

## One Hero running +X at its slowed speed, centred in the frame halfway through the filming: the frames.
func _film(id: String) -> Array:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var ring := m.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	var sync: Node = m.get_node("Warden/Sync")
	sync.set_process(false)
	var v := float(HunterMove.of(id)["speed"]) * SLOW
	var face := -PI * 0.5      # (the model faces -Z at yaw 0: this faces +X)
	m.rotation.y = face
	m.set_meta(WardenClips.STATE, {"vel": Vector3(v, 0.0, 0.0), "face": face, "grounded": true})
	var x0 := -v * DT * (SETTLE + EVERY * SHOTS * 0.5)
	var frames: Array = []
	for f in SETTLE + EVERY * SHOTS:
		m.position.x = x0 + v * DT * f
		sync.call("_process", DT)
		if f >= SETTLE and (f - SETTLE) % EVERY == 0:
			await RenderingServer.frame_post_draw
			frames.append(tree.root.get_texture().get_image())
	m.free()
	return frames
