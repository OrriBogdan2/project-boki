extends RefCounted
## --echo-steps-clip --shots-dir=<dir> [--media-secs=<s>] [--media-size=1920x1080]: a versus of Echo Steps
## (scripts/home/echo_steps.gd) on the base, recorded by the movie writer at 30 fps with its audio: the
## stones' notes, the bed, the hops. A bot answers on the beat and drops one step a phrase now and then,
## so hits, a miss and a streak all show. Writes <dir>/clip1.avi and <dir>/clip1.png. Run it on a GPU
## worker (jobq --needs gpu); recording reuses tools/gameplay_media.gd's child Godot. Never writes the save.

const LATE := 0.03               # s after the beat the bot presses (inside every hit window)
const DROP_EVERY := 5            # the bot leaves out every this many of your beats
const STILL_AT := 12.0           # s into the dance the still is saved
const ZOOM := 0.45               # the home camera's zoom on the stones (distance multiplier: closer)
const VIEW := Vector3(0, 0, 0.8)  # m from the stones' middle to the (hidden) player the camera follows

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
	var es := await _stage()
	await _dance(es, secs)
	print("MEDIA_DONE echo_steps frames=%d score=%s" % [Engine.get_frames_drawn(), es.run.score if es.run else "-"])
	main.get_tree().quit(0)

## The base with two rested Boki and the camera on the stones, the dance started.
func _stage() -> EchoSteps:
	var d := Save.fresh()
	for i in 2:
		var k := Save.new_kin(["zapple", "cindle"][i], ["Pip", "Ash"][i])
		k["level"] = 5
		Care.ensure(k)
		k["stats"]["focus"] = 40
		k["needs"]["energy"] = 90.0
		k["trust"] = 55.0
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "echo_practice": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	FarmUnlocks.rules()["base_mode"] = true
	var h = await main._hb_home()
	while not is_instance_valid(h.root_ui):
		await main.get_tree().process_frame
	h._close_panel()
	main.fade.reveal(0.01)
	var es: EchoSteps = h.hecho
	for k in h.kins:
		k.erase("indoors")
	h.ppos = es.middle.position + VIEW
	h.player.position = h.ppos
	h.player.visible = false
	h.cam.zoom_to = ZOOM
	h.cam.zoom = ZOOM
	h.cam.snap(es.middle.position)
	es.use()
	return es

## Presses your turns on the beat by the dance's own clock, for secs.
func _dance(es: EchoSteps, secs: float) -> void:
	var still := false
	var n := 0
	var handled := {}            # grid beats the bot has pressed or left out
	while es.run != null and es.clock < secs:
		await main.get_tree().process_frame
		if not still and es.clock >= STILL_AT:
			still = true
			var img := main.get_viewport().get_texture().get_image()
			if img:
				img.save_png(dir.path_join("clip1.png"))
		var r := es.run
		if r == null or not r.mine():
			continue
		for i in r.pattern.size():
			if r.done[i] or handled.has(r.first + i) or es.clock < r.at(r.first + i) + LATE:
				continue
			handled[r.first + i] = true
			n += 1
			if n % DROP_EVERY == 0:
				continue
			var press := InputEventAction.new()
			press.action = EchoSteps.KEYS[i % 4 if r.pattern[i] < 0 else r.pattern[i]]
			press.pressed = true
			es.input(press)
