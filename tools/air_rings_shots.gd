extends RefCounted
## --air-rings-shots --shots-dir=<dir>: stills for reading the air rings (docs/AIR_RINGS.md), GPU:
##   glide_match   gliding along the longest lane at the match camera, the next rings ahead
##   glide_far     the lane's take-off at the match camera: the first ring and the ones after it
##   lift_match    on the ground beside a lift ring at the match camera
##   skydive_lane  Cam.skydive high over the lane, heading along it
##   skydive_lift  Cam.skydive over a lift ring
## <dir>/captions.txt gets "file: caption" per file.

const DT := 1.0 / 60.0
const SKY_ALT := 40.0          # m over the lane for the skydive stills
const SKY_FRAMES := 120        # camera steps for the skydive view to settle

var main: Node
var m: Match
var P: Hunter
var dir := ""
var lines: Array = []

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var lane := _longest_lane()
	var lift: Dictionary = m.air_rings.list.filter(func(rg): return rg["lift"])[0]
	var dir2: Vector2 = lane[0]["dir"]
	var fwd := Vector3(dir2.x, 0, dir2.y)
	await _glide(lane[1]["pos"] - fwd * 4.0, fwd)
	await _take("glide_match", "gliding past ring 2 of the longest lane, match camera")
	await _glide(lane[0]["pos"] - fwd * 6.0, fwd)
	await _take("glide_far", "at the take-off of the longest lane, match camera")
	await _stand(lift["pos"] + Vector3(4, -lift["pos"].y, 0))
	await _take("lift_match", "on the ground beside a lift ring, match camera")
	await _sky(lane[1]["pos"] - fwd * 10.0, fwd)
	await _take("skydive_lane", "Cam.skydive %d m over the lane" % SKY_ALT)
	await _sky(lift["pos"] + Vector3(0, 0, 14), Vector3(0, 0, -1))
	await _take("skydive_lift", "Cam.skydive over a lift ring")
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("AIRRINGSSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

## The rings of the lane with the most rings, in order from its take-off.
func _longest_lane() -> Array:
	var best: Array = []
	for i in m.air_rings.lanes.size():
		var rings: Array = m.air_rings.list.filter(func(rg): return int(rg["lane"]) == i)
		if rings.size() > best.size():
			best = rings
	return best

func _setup() -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		if h != P:
			h.teleport(Vector3(0, -500, 0))
	P.ctrl = "idle"
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)

## Hold the player in the air at `at` (its body height), gliding along `fwd`.
func _glide(at: Vector3, fwd: Vector3) -> void:
	P.teleport(at - Vector3(0, AirRings.BODY_Y, 0))
	P.grounded = false
	P.gliding = true
	P.vel = fwd * 9.0
	await _settle(false, fwd)

func _stand(at: Vector3) -> void:
	P.teleport(at)
	P.gliding = false
	await _settle(false, Vector3.ZERO)

func _sky(at: Vector3, fwd: Vector3) -> void:
	P.teleport(at + Vector3(0, SKY_ALT, 0))
	P.gliding = false
	P.grounded = false
	await _settle(true, fwd)

## Frames until the camera has settled; the player is held still (no stepping), so what the camera sees is fixed.
func _settle(sky: bool, fwd: Vector3) -> void:
	m.cam.snap(P.pos)
	m.cam.yaw = 0.0
	for i in SKY_FRAMES:
		if sky:
			m.cam.skydive(P.pos, atan2(fwd.x, fwd.z), SKY_ALT, DT)
		else:
			m.cam.follow(P.pos, DT, false)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame

func _take(file: String, caption: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.save_jpg(dir.path_join(file + ".jpg"), 0.9)
	lines.append("%s.jpg: %s" % [file, caption])
