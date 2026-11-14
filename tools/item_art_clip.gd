extends RefCounted
## --item-art-clip --shots-dir=<dir>: frames for a short review clip of each sculpted set piece in a live match
## (xvfb with a renderer): the player walks a slow circle round a revive beacon, a shrine and an armor shard
## pickup. Writes <dir>/<item>_NNN.png at 30 fps; ffmpeg turns each set into an MP4.

const DT := 1.0 / 60.0
const SECS := 4.0  # seconds of clip per item
const RADIUS := 4.5  # metres the player circles at (outside pickup reach)

var main: Node
var m: Match
var player: Hunter
var dir := ""


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	player = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	await _circle("revive_beacon", m.beacons[0]["pos"])
	if not m.shrines.is_empty():
		await _circle("shrine", m.shrines[0]["pos"])
	var at := m.world.random_ground()
	m.drop("armor", at + Vector3(0, 0.6, 0), 1, "", "", Vector3.ZERO)
	await _circle("armor_shard", at)
	print("ITEMARTCLIP done in %s" % dir)
	main.get_tree().quit(0)


func _circle(item: String, at: Vector3) -> void:
	var steps := int(SECS / DT)
	for i in steps:
		var a := TAU * 0.35 * i / steps
		player.teleport(m.world.free_spot_near(at + Vector3(cos(a), 0, sin(a)) * RADIUS, [], 0.5, 0.4, 3.0))
		player.inp["aim"] = at + Vector3(0, 0.8, 0)
		m.step(DT)
		m.cam.snap(player.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame
		if i % 2 == 0:
			main.get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%03d.png" % [item, i / 2]))
