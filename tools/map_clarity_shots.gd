extends RefCounted
## --map-clarity-shots --shots-dir=<dir> [--view=WxH]: how readable is each thing on the map? One game-view frame per
## interactable (the player 5 m off, the default match camera), then the minimap as it plays, the minimap with Tab
## held and the full map (M). GPU run under xvfb. <dir>/captions.txt gets "file: caption" per file.

const DT := 1.0 / 60.0
const STAND_OFF := Vector3(0, 0, 5)  # m: where the player stands from a thing, south of it (toward the camera)

var main: Node
var m: Match
var dir := ""
var lines: Array = []


func run(main_node: Node) -> void:
	main = main_node
	var view := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--view="):
			var wh := String(a).substr(7).split("x")
			view = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	DisplayServer.window_set_size(view)
	await main.get_tree().process_frame
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var camp_mobs: Array = []
	for cp in m.camps.list:
		camp_mobs.append_array(cp["mobs"])
	for mb in m.mobs.duplicate():
		if not mb in camp_mobs:
			mb.queue_free()
			m.mobs.erase(mb)
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	for t in _targets():
		m.player.teleport(m.world.free_spot_near(t["pos"] + STAND_OFF, [], 1.0, 0.5, 8.0))
		await _frames(40)
		_take("world_" + String(t["id"]), String(t["id"]))
	await _frames(10)
	_take("minimap_play", "minimap as it plays (full frame)")
	Input.action_press("scores")
	await _frames(10)
	_take("minimap_held", "minimap, Tab held (full frame)")
	Input.action_release("scores")
	m.hud.full_map.open()
	await _frames(20)
	_take("full_map", "the M map")
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	var kinds := {}
	for r in MapMarks.rows(m):
		kinds[r["id"]] = int(kinds.get(r["id"], 0)) + 1
	print("MAPCLARITYSHOTS %d in %s, things %s" % [lines.size(), dir, kinds])
	main.get_tree().quit(0)


## One {id, pos} per kind of thing the match has, the first of each.
func _targets() -> Array:
	var out: Array = []
	if not m.camps.list.is_empty():
		out.append({"id": "camp", "pos": m.camps.list[0]["pos"]})
	var shops := Shops.list(m)
	if not shops.is_empty():
		out.append({"id": "shop", "pos": shops[0]["pos"]})
	if not m.world.pads.is_empty():
		out.append({"id": "jump_pad", "pos": m.world.pads[0]["pos"]})
	if not m.chests.is_empty():
		out.append({"id": "chest", "pos": m.chests[0]["pos"]})
	if m.exits != null and not m.exits.list.is_empty():
		out.append({"id": "extraction", "pos": m.exits.list[0]["pos"]})
	if not m.shrines.is_empty():
		out.append({"id": "shrine", "pos": m.shrines[0]["pos"]})
	if not m.beacons.is_empty():
		out.append({"id": "beacon", "pos": m.beacons[0]["pos"]})
	if m.lairs != null and not m.lairs.list.is_empty():
		out.append({"id": "boss_lair", "pos": m.lairs.list[0]["c"]})
	return out


func _frames(count: int) -> void:
	for i in count:
		m.step(DT)
		m.cam.snap(m.player.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame


func _take(file: String, caption: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
