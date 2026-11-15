extends RefCounted
## --box-revive-shots --shots-dir=<dir>: review screenshots for box revives and beacons
## (docs/decisions/0018), in a live extraction match under xvfb with a renderer:
##   boxes_world      a teammate's box (their colour, face and name) beside a rival's (red)
##   boxes_minimap    the same two on the minimap (a crop of the top left)
##   boxes_full_map   the same two on the full map, zoomed in
##   revive_read_NN   from READ_M away, a teammate bringing the fallen one back at NN %: tether, core, rings
##   beacon_notice    a rival lights a beacon far off: the toast, the edge arrow, the minimap pulse
##   beacon_full_map  the lit beacon pulsing on the full map
## <dir>/captions.txt gets "file: caption" per file.

const DT := 1.0 / 60.0
const READ_M := 8.0          # m from the box you watch from: an onlooker, the box well inside the match-zoom view
const READ_ANGLES := [180, 160, 200, 0]   # degrees off east: west of the box puts it right of centre, clear of the HUD
const READ_AT := [0.25, 0.5, 0.9]   # progress points shot

var main: Node
var m: Match
var P: Hunter
var dir := ""
var home := Vector3.ZERO
var lines: Array = []

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	await _boxes()
	await _ring()
	await _beacon()
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("BOXREVIVESHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.lives = 1
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	home = _roomy()
	P.teleport(home)
	var away := m.world.random_ground()
	for k in 500:
		if away.distance_to(home) > 45.0:
			break
		away = m.world.random_ground()
	for h in m.hunters:
		if h != P:
			h.teleport(m.world.free_spot_near(away, [], 1.0, 0.4, 8.0))
	await _go(0.5)

## Open, flat ground away from the beacons, with ground to watch the mate's box (_boxes) from READ_M away.
func _roomy() -> Vector3:
	for k in 3000:
		var g := m.world.random_ground()
		var flat := true
		for dx in range(-8, 9, 2):
			for dz in range(-8, 9, 2):
				if m.world.is_void(g.x + dx, g.z + dz) or absf(m.world.ground_at(g.x + dx, g.z + dz) - g.y) > 0.3:
					flat = false
		var far: bool = m.beacons.all(func(bc): return g.distance_to(bc["pos"]) > 30.0)
		if flat and far and _watch_spot(g + Vector3(2.5, 0, -1.0)) != Vector3.INF:
			return g
	return m.world.random_ground()

func _mate() -> Hunter:
	return m.hunters.filter(func(x): return x.team == P.team and x != P)[0]

func _rival() -> Hunter:
	return m.hunters.filter(func(x): return x.team != P.team)[0]

func _boxes() -> void:
	var B := _mate()
	var E := _rival()
	B.teleport(home + Vector3(2.5, 0, -1.0))
	E.teleport(home + Vector3(-2.5, 0, -1.0))
	await _go(0.2)
	m.eliminate(B, null, "finished")
	m.eliminate(E, null, "finished")
	P.inp["aim"] = home + Vector3(0, 0.9, -4)
	await _go(1.0)
	_take("boxes_world", "A teammate's box (left: their squad colour, face, name, soul timer) and a rival's (red)")
	_crop_take("boxes_minimap", Rect2i(0, 0, 250, 250), 2.0, "The minimap: the teammate's box in their colour"
		+ " (bright rim: it can still be revived), the rival's in red, beacons as mint diamonds")
	m.hud.full_map.open()
	m.hud.full_map.zoom = 5.0
	m.hud.full_map.zoom_to = 5.0
	m.hud.full_map.center = Vector2(home.x, home.z)
	await _go(0.3)
	_take("boxes_full_map", "The full map, zoomed in: the teammate's box with their name, the rival's in red")
	m.hud.full_map.close()

## A teammate brings the fallen one back while you watch from READ_M away at match zoom: the tether, the core and
## the rings at three points of the channel.
func _ring() -> void:
	var B := _mate()
	var C: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P and x != B)[0]
	var b := Life.box_of(m, B)
	C.teleport(b["pos"] + Vector3(0.6, 0, 0.4))
	P.teleport(_watch_spot(b["pos"]))
	P.inp["aim"] = b["pos"]
	m.hud.guide_hidden = true       # the opening kit card would cover the box at the screen's edge
	C.inp["interact"] = true
	var done := 0.0
	for at in READ_AT:
		await _go(BoxRevive.time_for(B) * (float(at) - done))
		done = float(at)
		var what := "Watching from %d m: %s bringing %s back at %d%%" % [roundi(P.pos.distance_to(b["pos"])), C.pname,
			B.pname, int(at * 100.0)]
		_take("revive_read_%d" % int(at * 100.0), what + ": the tether, the soul's core filling, the rings")
	C.inp["interact"] = false
	await _go(0.2)

## Solid ground READ_M from the box, near its height, so you stand and watch rather than fall (INF if none).
func _watch_spot(at: Vector3) -> Vector3:
	for deg in READ_ANGLES:
		var p := at + Vector3(READ_M, 0, 0).rotated(Vector3.UP, deg_to_rad(float(deg)))
		var solid := true
		for dx in [-1.0, 0.0, 1.0]:
			for dz in [-1.0, 0.0, 1.0]:
				solid = solid and not m.world.is_void(p.x + dx, p.z + dz)
		if solid and absf(m.world.ground_at(p.x, p.z) - at.y) < 2.0:
			return Vector3(p.x, m.world.ground_at(p.x, p.z), p.z)
	return Vector3.INF

func _beacon() -> void:
	var bc: Dictionary = m.beacons[0]
	var rivals: Array = m.hunters.filter(func(x): return x.team != P.team and not x.out)
	(rivals[0] as Hunter).teleport(bc["pos"])
	await _go(0.15)          # (the toast lives 1.8 s of real time, and frames are slow here)
	_take("beacon_notice", "A rival lights a beacon far away: the toast with the direction, the edge arrow with the"
		+ " distance, the pulsing diamond and arrow on the minimap")
	m.hud.full_map.open()
	await _go(0.3)
	_take("beacon_full_map", "The full map: the lit beacon pulses; the others and the boxes show too")
	m.hud.full_map.close()

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame

func _take(file: String, caption: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])

func _crop_take(file: String, r: Rect2i, zoom: float, caption: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	var crop := img.get_region(r.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	crop.resize(int(r.size.x * zoom), int(r.size.y * zoom), Image.INTERPOLATE_BILINEAR)
	crop.save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
