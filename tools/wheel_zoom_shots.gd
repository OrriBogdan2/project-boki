extends RefCounted
## --wheel-zoom-shots --shots-dir=<dir>: the wheel zooming the hunter, as numbered frames (relics_NNN.png from the
## Relics viewer, match_NNN.png from a match: wheel in, wheel out, hold Ctrl, let go). Run under a renderer (jobq
## --needs gpu), then encode with ffmpeg -framerate 30 -i <dir>/relics_%03d.png. Never writes the save.

const WAIT := 4                  # frames between one scripted notch and the next
var dir := ""
var n := 0
var note: Label

func _grab(prefix: String) -> void:
	await RenderingServer.frame_post_draw
	var img := note.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("%s_%03d.png" % [prefix, n]))
	n += 1

func _hold(prefix: String, frames: int) -> void:
	for i in frames:
		await _grab(prefix)

func _wheel(button: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev

func run(main: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Engine.max_fps = 30
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["cls"] = "medium"
	d["arch"] = "gunslinger"
	d["classes"] = ClassUnlock.legacy()
	Save.d = d
	var layer := CanvasLayer.new()
	layer.layer = 100
	main.add_child(layer)
	note = Label.new()
	note.position = Vector2(24, 20)
	note.add_theme_font_size_override("font_size", 28)
	layer.add_child(note)
	if main.fade:
		await main.fade.reveal(0.01)     # the boot splash stays up when a tool starts a screen by hand
	await _relics(main)
	await _match(main)
	print("WHEELSHOTS DONE")
	main.get_tree().quit()

func _relics(main: Node) -> void:
	var bg := ColorRect.new()
	bg.color = Color("14122a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_child(bg)
	var v := HunterViewer.make("gunslinger", Vector2(640, 700), Vector2(200, 112), 2)
	v.position = Vector2(300, 20)
	bg.add_child(v)
	while v.model == null:
		await main.get_tree().process_frame
	n = 0
	note.text = "Relics page: mouse wheel over the hunter"
	await _hold("relics", 20)
	var steps := [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_UP,
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_DOWN,
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_DOWN,
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_DOWN]
	for s in steps:
		v.zoom.wheel(_wheel(s))
		note.text = "Relics page: wheel %s" % ("up (in)" if s == MOUSE_BUTTON_WHEEL_UP else "down (out)")
		await _hold("relics", WAIT)
	await _hold("relics", 25)
	bg.queue_free()

func _match(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 77, "no_drop": true})
	n = 0
	for i in 30:
		await main.get_tree().process_frame
	note.text = "Match: mouse wheel"
	await _hold("match", 20)
	for s in [-1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]:
		CamWheel.input(m, _wheel(MOUSE_BUTTON_WHEEL_UP if s < 0 else MOUSE_BUTTON_WHEEL_DOWN))
		note.text = "Match: wheel %s (zoom %.2f)" % ["up (in)" if s < 0 else "down (out)", m.cam.user_zoom]
		await _hold("match", WAIT)
	await _hold("match", 25)
	Input.action_press("crouch")
	note.text = "Match: hold Ctrl widens past the max"
	await _hold("match", 70)
	Input.action_release("crouch")
	note.text = "Match: let go, it eases back"
	await _hold("match", 70)
