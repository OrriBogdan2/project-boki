extends RefCounted
## --garden-play-clip --shots-dir=<dir> [--media-secs=<s>] [--media-size=1920x1080]: four Boki at free play on the base
## (BaseLife: tag, a squabble, toys), recorded by the movie writer at 30 fps with its audio, to hear the quiet cues
## of play_sfx.gd. Two games of tag, a catch in each, and a run of squabbles inside one cap window (the zone holds the
## last back); each game ends in a cheer. Writes <dir>/clip1.avi and <dir>/clip1.png. Run it on a GPU worker
## (jobq --needs gpu); recording reuses tools/gameplay_media.gd's child Godot. Never writes the save.

const GAME_S := 7.0                 # s each game of tag lasts, so both end inside the clip
## s and what happens: "tag0"/"tag1" a game starts for pair 0 (Ash, Crag) or 1 (Moss, Pip), "catch0"/"catch1" the
## chaser reaches the other, "squabble0"/"squabble1" the pair bumps tempers (four cues inside one 3 s window)
const BEATS := [[1.0, "tag0"], [2.0, "tag1"], [4.5, "catch0"], [4.7, "catch1"], [5.0, "squabble0"],
		[5.3, "squabble1"], [14.0, "squabble0"]]
const STILL_AT := 6.0               # s: the still is saved
const ZOOM := 0.5                   # the home camera's distance multiplier (closer than the default)
const AWAY := Vector3(0.0, 0.0, 7.0)    # m from the Boki to the (hidden) player the camera follows

var main: Node
var dir := "/tmp/media"

func run(m: Node) -> void:
	main = m
	var media = load("res://tools/gameplay_media.gd").new()
	var secs := 20.0
	var res := "1920x1080"
	var child := false
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		child = child or arg == "--media-child"
		if arg.begins_with("--media-size="):
			res = arg.substr(13)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--media-secs="):
			secs = float(arg.substr(13))
	if dir.is_relative_path():
		dir = ProjectSettings.globalize_path("res://").path_join(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	if not child:
		media.main = main
		media.dir = dir
		media._record(res)
		return
	Save.no_write = true
	Record.set_level(1)
	Settings.v["tips"] = false
	seed(7)
	var h = await _stage()
	await _play(h, secs)
	print("MEDIA_DONE garden_play frames=%d dropped=%d heard=%s"
			% [Engine.get_frames_drawn(), h.life.sfx.dropped, GardenSfx.heard])
	main.get_tree().quit(0)

## The base with four rested Boki together (two hot tempers), the camera on them.
func _stage():
	var d := Save.fresh()
	var specs := [["cindle", "Ash", 0.95], ["basaltoad", "Crag", 0.95], ["burrlet", "Moss", 0.1],
			["zapple", "Pip", 0.1]]
	for spec in specs:
		var k := Save.new_kin(spec[0], spec[1])
		k["traits"]["temper"] = spec[2]
		k["level"] = 5
		Care.ensure(k)
		k["needs"]["energy"] = 90.0
		k["trust"] = 55.0
		d["roster"].append(k)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	FarmUnlocks.rules()["base_mode"] = true
	var h = await main._hb_home()
	while not is_instance_valid(h.root_ui):
		await main.get_tree().process_frame
	h._close_panel()
	main.fade.reveal(0.01)
	h.day_t = 0.4
	var mid: Vector3 = h.world.random_ground(0)
	for k in h.kins:
		k.erase("indoors")
		k["pos"] = h.world.free_spot_near(mid + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), [], 0.8)
		(k["node"] as Node3D).position = k["pos"]
	h.ppos = mid + AWAY
	h.player.position = h.ppos
	h.player.visible = false
	h.cam.zoom_to = ZOOM
	h.cam.zoom = ZOOM
	h.cam.snap(mid)
	return h

## Plays the beats at their times and lets the base run for secs.
func _play(h, secs: float) -> void:
	var t := 0.0
	var next := 0
	var still := false
	while t < secs:
		await main.get_tree().process_frame
		t += 1.0 / 30.0
		if not still and t >= STILL_AT:
			still = true
			var img := main.get_viewport().get_texture().get_image()
			if img:
				img.save_png(dir.path_join("clip1.png"))
		while next < BEATS.size() and t >= float(BEATS[next][0]):
			_beat(h, String(BEATS[next][1]))
			next += 1

func _beat(h, what: String) -> void:
	var pair: int = int(what.right(1))
	var a: Dictionary = h.kins[pair * 2]
	var b: Dictionary = h.kins[pair * 2 + 1]
	match what.left(what.length() - 1):
		"tag":
			for k in [a, b]:
				(k["life"] as Fsm).go(BaseLife.S.ROAM, "clip")
			BaseLife.add_bond(a["rec"], b["rec"], 0.5 - BaseLife.bond(a["rec"], b["rec"]))
			h.life._tag(a, b)
			for k in [a, b]:
				k["life_for"] = GAME_S
		"catch":
			var it: Dictionary = a if a.get("life_it", false) else b
			var other: Dictionary = b if it == a else a
			it["pos"] = other["pos"] + Vector3(0.4, 0, 0)
			(it["node"] as Node3D).position = it["pos"]
			h.life._tag_tick(it, it["life"])      # the catch lands now, not on the next 10 Hz look
		"squabble":
			h.life._squabble(a, b)
