extends "res://tools/clip_shots.gd"
## --idle-shots --shots-dir=<dir> [--wardens=a,b] [--frames=12] [--size=320]: every Hunter standing still, for the
## idle audit (docs/art/IDLE_AUDIT.md) and the before/after strips of an idle rework. Per Hunter, in <dir>/<id>/:
## idle_<view>/ and stance_<view>/ (the keyed clip at --frames even steps; the last frame is the clip's end, so
## f000 against the last shows the loop seam), views front (3/4) and side; and live/, the game's own hand-off while
## the Hunter stands (HunterAnim still state, idle into stance after the warden_anim "stance_after"), every 0.5 s.
## A Hunter with no keyed clips (procedural) gets live/ only. Needs a renderer.

const VIEWS := {"front": 155.0, "side": 90.0}     # model yaw, degrees
const LIVE_STEP := 0.5        # s between live frames
const LIVE_TAIL := 4.0        # s of stance filmed after the hand-off
const DT := 1.0 / 30.0

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = Arch.ORDER.duplicate()
	var frames := 12
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--frames="): frames = int(a.substr(9))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 30.0
	for id in ids:
		await _hunter(String(id), out.path_join(String(id)), frames)
	print("IDLE_SHOTS_DONE ", ids.size())
	tree.quit()

func _hunter(id: String, dir: String, frames: int) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	var anim := HunterAnim.new(model)
	for k in 30:
		await tree.process_frame
	var tall := _height(model)
	cam.position = Vector3(0, tall * 0.55, tall * 2.6)
	cam.look_at(Vector3(0, tall * 0.48, 0))
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	if clips != null:
		for clip in ["idle", "stance"]:
			var anim_name := String(clips.d.get("loco", {}).get(clip, clip))
			if clips.lib.has_animation(anim_name):
				await _clip(model, sync, clips, anim_name, dir, clip, frames)
		clips.force = {}
	model.rotation.y = deg_to_rad(VIEWS["front"])
	var after := float(clips.d.get("loco", {}).get("stance_after", 6.0)) if clips != null else 4.0
	var live := dir.path_join("live")
	DirAccess.make_dir_recursive_absolute(live)
	var t := 0.0
	var i := 0
	while t < after + LIVE_TAIL:
		anim.update(DT, {"vel": Vector3.ZERO, "face": model.rotation.y, "grounded": true, "fired": 99.0})
		sync.call("_process", DT)
		if t >= i * LIVE_STEP:
			await _grab(live.path_join("f%03d.png" % i))
			i += 1
		t += DT
	model.queue_free()
	await tree.process_frame

func _clip(model: Node3D, sync: Node, clips: WardenClips, anim_name: String, dir: String, clip: String,
		frames: int) -> void:
	var length := clips.lib.get_animation(anim_name).length
	for view in VIEWS:
		model.rotation.y = deg_to_rad(float(VIEWS[view]))
		var sub := dir.path_join("%s_%s" % [clip, view])
		DirAccess.make_dir_recursive_absolute(sub)
		for i in frames + 1:
			clips.force = {"clip": anim_name, "t": minf(length * i / frames, length - 0.001)}
			for k in 3:
				sync.call("_process", DT)
			await _grab(sub.path_join("f%03d.png" % i))

## The model's standing height (m): the top of its visible meshes.
func _height(model: Node3D) -> float:
	var top := 1.0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.is_visible_in_tree():
			var box := m.global_transform * m.get_aabb()
			top = maxf(top, box.end.y)
	return minf(top, 4.0)
