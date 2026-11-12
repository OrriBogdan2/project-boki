extends "res://tools/clip_shots.gd"
## --stride-shots --shots-dir=<dir> [--wardens=gunslinger,bulwark,rimewright] [--size=240]: a Hero stopping from a run
## in the game's renderer, from the side, with the stride on (after) and off (before): <dir>/<id>_<mode>/fNN.png at
## PICK frames from the let-go. The Hero stands, runs up at its own speed and acceleration, lets go and brakes as
## HunterMove does; the model is drawn a step ahead of the physics like the local player. Needs a renderer.

const DT := 1.0 / 60.0
const STAND := 120             # frames standing first (the idle feet are read there)
const RUN := 40                # frames at full run before the let-go
const TAIL := 40               # frames standing after the stop
const PICK := [-4, 0, 2, 4, 6, 8, 10, 14, 18, 24]     # frames from the let-go that are filmed
const FRAME := 1.25            # of the Hero's height: what the square frame covers
const FOV := 36.0

## The strip's "before": the same clips without the start and stop.
class Off extends WardenStride:
	func step(_dt: float, _s: Dictionary, _clips: WardenClips) -> void:
		pass

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids := ["gunslinger", "bulwark", "rimewright"]
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
	for id in ids:
		for mode in ["before", "after"]:
			await _film(String(id), mode, out.path_join("%s_%s" % [id, mode]))
	print("STRIDE_SHOTS_DONE")
	tree.quit()

## The speed each frame: stand, run up, run, let go and brake, stand again. Returns [speeds, the let-go frame].
func _speeds(id: String) -> Array:
	var row := HunterMove.of(id)
	var top := float(row["speed"])
	var v := PackedFloat32Array()
	var s := 0.0
	for f in STAND:
		v.append(0.0)
	while s < top:
		s = minf(top, s + float(row["accel"]) * DT)
		v.append(s)
	for f in RUN:
		v.append(top)
	var let_go := v.size()
	while s > 0.0:
		s = HunterMove.brake(Vector2(s, 0.0), top, 1.0, DT).x
		v.append(s)
	for f in TAIL:
		v.append(0.0)
	return [v, let_go]

## The standing model's height in metres, off its meshes.
func _height(model: Node3D) -> float:
	var top := 0.0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var n := mi as MeshInstance3D
		if n.visible and n.mesh != null:
			top = maxf(top, (n.global_transform * n.get_aabb()).end.y)
	return maxf(top, 1.0)

func _film(id: String, mode: String, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	if mode == "before":
		clips.stride = Off.new()
	var sp := _speeds(id)
	var speeds: PackedFloat32Array = sp[0]
	var let_go: int = sp[1]
	var z := 0.0
	var zs := PackedFloat32Array()
	for v in speeds:
		z -= v * DT
		zs.append(z)
	var tall := _height(model)
	cam.fov = FOV
	cam.position = Vector3(FRAME * tall / (2.0 * tan(deg_to_rad(FOV) * 0.5)), tall * 0.5, zs[let_go] - 0.05)
	cam.look_at(Vector3(0.0, tall * 0.5, zs[let_go] - 0.05))
	for k in 30:
		await tree.process_frame       # (past the title's fade)
	for f in speeds.size():
		var v := speeds[f]
		model.position = Vector3(0.0, 0.0, zs[f] - v * DT)     # (drawn a step ahead of the physics)
		model.set_meta(WardenClips.STATE, {"vel": Vector3(0.0, 0.0, -v), "face": 0.0, "grounded": true})
		sync.call("_process", DT)
		var at := PICK.find(f - let_go)
		if at >= 0:
			await _grab(dir.path_join("f%02d.png" % at))
	model.queue_free()
