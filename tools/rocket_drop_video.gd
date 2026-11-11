extends RefCounted
## --rocket-drop-video --media-clip=<1-3> --shots-dir=<dir>: the squad rocket drop (DropRocket) through the game's own
## camera and HUD, for the owner's review. Recorded like tools/gameplay_media.gd (a child Godot under the movie writer,
## 30 fps, <dir>/clip<N>.avi); encode with tools/gameplay_media.sh. Run it on a GPU worker (jobq --needs gpu).
##   1 ride     the leader launches and does nothing: the squad rides the rocket down and lands together
##   2 fall     jump out early and free-fall forward (the glider opens by itself near the ground)
##   3 glide    jump out early and open the glider at once, flying on forward

const LAUNCH_AT := 6.0           # s into the ship's run: over the islands on this seed
const OUT_AT := 1.0              # s after the launch the player jumps out (clips 2 and 3)
const AFTER_S := 2.5             # s kept after landing
const CAP_S := 40.0              # s at most

var main: Node

func run(main_node: Node) -> void:
	main = main_node
	var gm = load("res://tools/gameplay_media.gd").new()
	gm.main = main
	var child := false
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		child = child or arg == "--media-child"
		if arg.begins_with("--shots-dir="):
			gm.dir = arg.substr(12)
		if arg.begins_with("--media-clip="):
			gm.clip = int(arg.substr(13))
	if String(gm.dir).is_relative_path():
		gm.dir = ProjectSettings.globalize_path("res://").path_join(gm.dir)
	DirAccess.make_dir_recursive_absolute(gm.dir)
	if not child:
		gm._record("1920x1080")
		return
	Save.no_write = true
	Settings.v["tips"] = false
	await _drop(int(gm.clip))
	print("MEDIA_DONE clip=%d" % gm.clip)
	main.get_tree().quit(0)

## The match runs on its own (its camera, its HUD); the script only launches, jumps out and holds forward.
func _drop(clip: int) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1500.0, "seed": 4242, "no_plan": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	while m.time < LAUNCH_AT:
		await main.get_tree().process_frame
	m.ship_jump(P)
	print("MEDIA_MARK launch t=%.1f" % m.time)
	var t0 := m.time
	var down_at := -1.0
	while m.time - t0 < CAP_S and (down_at < 0.0 or m.time - down_at < AFTER_S):
		if clip > 1 and P.rocket != null and m.time - t0 >= OUT_AT:
			m.skydrop.detach(P)
			Input.action_press("up")
			print("MEDIA_MARK out t=%.1f" % m.time)
			if clip == 3:
				P.do_jump()
		if down_at < 0.0 and P.grounded and not P.riding and not P.dropping:
			down_at = m.time
			Input.action_release("up")
			print("MEDIA_MARK down t=%.1f" % m.time)
		await main.get_tree().process_frame
