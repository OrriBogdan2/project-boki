extends RefCounted
## --teach-hold-clip --shots-dir=<dir> [--media-size=1280x720]: the HOLD teaching on film (HoldTeach, HoldPrompt).
## The farm: two taps of F at a tree (the ring flashes, "Hold" pops, then "Hold F to chop"), then F held
## until the tree falls. A match: two taps of Space in the air (the ring beside you, then "Hold Space to
## glide" in the message lane), then Space held and the glider opens. Real input actions are pressed and
## the game runs its own frames; HoldTeach's clock follows the fixed 30 fps so a tap stays a tap however
## slowly the frames render. Writes <dir>/clip1.avi (tools/gameplay_media.gd's child Godot records it).
## Never writes the save or the settings file.

const FPS := 30.0  # the movie writer's fixed rate (gameplay_media)
const TAP := 3  # frames a tap holds its key (0.1 s, under HoldTeach.TAP_S)
const ZOOM := 0.55  # the farm camera's zoom on the tree (distance multiplier: closer)
const UP := 22.0  # m above the ground the glide part starts, so the taps have air under them

var main: Node
var dir := "/tmp/media"


func run(m: Node) -> void:
	main = m
	var media = load("res://tools/gameplay_media.gd").new()
	var res := "1280x720"
	var child := false
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		child = child or arg == "--media-child"
		if arg.begins_with("--media-size="):
			res = arg.substr(13)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
	if dir.is_relative_path():
		dir = ProjectSettings.globalize_path("res://").path_join(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	if not child:
		media.main = main
		media.dir = dir
		media._record(res)
		return
	Save.no_write = true
	Record.set_level(0)  # the hint lines are tips: a clean recording would hide them
	Settings.set_v(HoldTeach.SETTING, {}, false)
	HoldTeach.reset_session()
	HoldTeach.clock = 0.0
	await _farm()
	await _glide()
	print("MEDIA_DONE teach_hold chop=%d glide=%d" % [HoldTeach.count("chop"), HoldTeach.count("glide")])
	main.get_tree().quit(0)


## n frames with these keys down; HoldTeach's clock moves with the movie's.
func _frames(n: int, keys: Array = []) -> void:
	for action in ["interact", "jump"]:
		if action in keys:
			Input.action_press(action)
		else:
			Input.action_release(action)
	for i in n:
		await main.get_tree().process_frame
		HoldTeach.clock += 1.0 / FPS


func _secs(s: float, keys: Array = []) -> void:
	await _frames(int(s * FPS), keys)


# ------------------------------------------------------------------ the farm: chop
func _farm() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("cindle", "Pip")
	k["starter"] = true
	Care.ensure(k)
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(Save.d)
	var h = await main._hb_home()
	while not is_instance_valid(h.root_ui):
		await main.get_tree().process_frame
	h._close_panel()
	main.fade.reveal(0.01)
	HomeGather.give_tool("axe")
	var hg: HomeGather = h.hg
	var tile := -1
	for i in h.hb.wild_t:
		if h.hb.wild_t[i] != "tree":
			continue
		var b := hg.beside(i, HomeLayout.LANDING)
		if b != Vector3.INF and int(hg.find(Vector2(b.x, b.z)).get("i", -1)) == i:
			tile = i
			h.ppos = b
			h.player.position = b
			break
	if tile < 0:
		print("MEDIA_ERROR no tree beside the landing")
		return
	h.cam.zoom_to = ZOOM
	h.cam.zoom = ZOOM
	h.cam.snap(h.ppos)
	await _secs(1.5)
	for n in 2:
		await _frames(TAP, ["interact"])
		await _secs(2.0 if n == 0 else 3.0)
	for i in int(5.0 * FPS):
		await _frames(1, ["interact"])
		if not h.hb.wild_t.has(tile):
			break
	await _secs(2.0)
	h.queue_free()
	await main.get_tree().process_frame


# ------------------------------------------------------------------ a match: glide
func _glide() -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var p: Hunter = m.player
	m.opts["god"] = true
	await _secs(1.5)
	for n in 2:
		_lift(p)
		await _secs(0.4)
		await _frames(TAP, ["jump"])
		await _secs(2.2)
	_lift(p)
	await _secs(0.3)
	await _secs(3.0, ["jump"])
	await _secs(1.5)


## Up into the air, still, so a Space press there is the glide press (not the jump).
func _lift(p: Hunter) -> void:
	p.teleport(p.pos + Vector3(0, UP, 0))
	p.grounded = false
	p.vel = Vector3.ZERO
	p.gliding = false
	p.glide_fuel = 1.0
