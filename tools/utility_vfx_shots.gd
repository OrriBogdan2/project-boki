extends RefCounted
## --utility-vfx-shots --shots-dir=<dir>: the belt items that change a fight, at match zoom (UtilityLook):
##   skyfall_start / skyfall_late   the fuse ring and warhead at 0.5 s and at 4.4 s of the 5 s fuse
##   blight_patch                   the Blight Flask patch edge, a rival standing in it
##   twin_gate                      the two portals and the link between them
##   warp_seed                      the Warp Seed anomaly
##   thorn_wall                     the Thorn Wall's spikes
## <dir>/captions.txt gets "file: caption" per file. Runs under xvfb with a renderer.

const DT := 1.0 / 60.0

var main: Node
var m: Match
var P: Hunter
var rival: Hunter
var dir := ""
var lines: Array = []

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	await _skyfall()
	await _item("blight_flask", "blight_patch", true, "Blight Flask: dark band and lime bubbles mark the patch edge")
	await _item("twin_gate", "twin_gate", false, "Twin Gate: two portals and a lit strip with running lights")
	await _item("warp_seed", "warp_seed", false, "Warp Seed: dark core, orbiting motes, beam, arcs on the ground")
	await _item("thorn_wall", "thorn_wall", false, "Thorn Wall: spikes along the top and out of both faces")
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("UVFXSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	rival = m.hunters.filter(func(x): return x != P)[0]
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	P.teleport(_roomy())
	rival.teleport(P.pos + Vector3(-60.0, 0, 0))
	await _go(0.4)

## Open, flat ground.
func _roomy() -> Vector3:
	for k in 3000:
		var g := m.world.random_ground()
		var flat := true
		for dx in range(-12, 13, 3):
			for dz in range(-12, 13, 3):
				if m.world.is_void(g.x + dx, g.z + dz) or absf(m.world.ground_at(g.x + dx, g.z + dz) - g.y) > 0.3:
					flat = false
		if flat:
			return g
	return m.world.random_ground()

func _use(id: String) -> void:
	P.hp = P.max_hp
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, id, 1)
	P.inp["aim"] = P.pos + Vector3(20.0, 0, 0)
	UtilityBelt.use_id(P, id)

func _item(id: String, file: String, with_rival: bool, caption: String) -> void:
	_use(id)
	if with_rival:
		rival.teleport(P.pos + Vector3(4.0, 0, 0))
	await _go(0.5)
	await _real(1.2)          # (the rings and orbits turn in real time)
	_take(file, caption)
	if with_rival:
		rival.teleport(P.pos + Vector3(-60.0, 0, 0))
	m.fields.clear()
	for w in m.verbs.walls:
		w["t"] = 0.0
	await _go(0.2)

func _skyfall() -> void:
	_use("skyfall_charge")
	await _real(0.6)
	_take("skyfall_start", "Skyfall, fuse start: rim up, disc begins to fill, warhead high")
	await _real(3.8)
	_take("skyfall_late", "Skyfall, last second: disc nearly fills the circle, rim blinks")
	await _go(1.5)
	await _go(3.5)

func _real(secs: float) -> void:
	await main.get_tree().create_timer(secs).timeout

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
