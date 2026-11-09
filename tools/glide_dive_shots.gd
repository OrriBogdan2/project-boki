extends RefCounted
## --glide-dive-shots --shots-dir=<dir> [--heroes=a,b,c,d] [--size=360]: the glider's dive on each Hunter's own model,
## side on in the game's renderer: <dir>/<hero>_dive.png is one strip, left to right the glide, the plunge 0.05, 0.1,
## 0.3 and 0.8 s in, then the pull-out 0.08, 0.2, 0.4 and 0.9 s after release. Needs a renderer.

const DT := 1.0 / 60.0
const PLUNGE_AT := [0.05, 0.1, 0.3, 0.8]
const PULL_AT := [0.08, 0.2, 0.4, 0.9]
const HEROES := ["archer", "bulwark", "thief", "dolm"]      # a light, a heavy, a light and a medium body

var tree: SceneTree
var cam: Camera3D
var holder: Node3D
var px := 360

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := "."
	var ids: Array = HEROES
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--heroes="): ids = Array(a.substr(9).split(",", false))
		if a.begins_with("--size="): px = int(a.substr(7))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(px, px)
	main.get_viewport().size = Vector2i(px, px)
	_stage(main)
	for k in 30:
		await tree.process_frame
	for id in ids:
		await _strip(String(id), out)
	print("GLIDE_DIVE_SHOTS_DONE")
	tree.quit()

func _stage(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"),
		"horizon": Color("ffd2a8"), "stars": 0.0})
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.fov = 30.0
	cam.position = Vector3(8.0, 0.9, 0)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.make_current()

func _strip(id: String, out: String) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	model.rotation.y = 0.0       # (faces -z: the camera on +x sees it side on, the plunge's nose to the left)
	var anim := HunterAnim.new(model)
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var s := {"fired": 99.0, "face": model.rotation.y, "grounded": false, "gliding": true, "vel": Vector3(0, -1.5, 0)}
	var frames: Array[Image] = []
	for i in 40:
		_tick(anim, sync, s)
	frames.append(await _grab())
	s["gliding"] = false
	s["diving"] = true
	s["plunge"] = true
	s["vel"] = Vector3(0, -32.5, 0)
	await _marks(anim, sync, s, PLUNGE_AT, frames)
	s["gliding"] = true
	s["diving"] = false
	s["plunge"] = false
	s["vel"] = Vector3(0, -8.0, 0)
	await _marks(anim, sync, s, PULL_AT, frames)
	var sheet := Image.create(px * frames.size(), px, false, Image.FORMAT_RGB8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, px, px), Vector2i(i * px, 0))
	sheet.save_png(out.path_join("%s_dive.png" % id))
	model.queue_free()

## Steps the pose to each mark (s after the state changed) and grabs a frame there.
func _marks(anim: HunterAnim, sync: Node, s: Dictionary, marks: Array, frames: Array[Image]) -> void:
	var t := 0.0
	for mark in marks:
		while t < float(mark) - DT * 0.5:
			_tick(anim, sync, s)
			t += DT
		frames.append(await _grab())

func _tick(anim: HunterAnim, sync: Node, s: Dictionary) -> void:
	anim.update(DT, s)
	sync.call("_process", DT)

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return tree.root.get_texture().get_image()
