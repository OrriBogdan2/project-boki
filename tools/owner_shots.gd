extends "res://tools/gameplay_media.gd"
## --owner-shots --mode=hunters|boki|arena --shots-dir=<dir> [--heroes=a,b] [--species=a,b]: the owner's in-game
## GPU stills. hunters: each Hunter alone on Dusk Isles under the match camera, idle / run / attack (a rival dummy
## in front). boki: the farm with a row of Boki as the player sees them. arena: a squad fight at the match camera.

const SIZE := Vector2i(1600, 900)
const ALL := ["gunslinger", "thief", "ashwick", "juggernaut", "rimewright", "archer", "bulwark", "mage", "dolm",
		"dredge", "gil", "ostra", "tender"]
const SPECIES := ["lilybara", "umbrathere", "cindle", "glintmole", "kindlewren", "nettlynx", "pebbit", "zapple"]
const ZOOM := 0.32

func run(main_node: Node) -> void:
	main = main_node
	var mode := "hunters"
	var heroes: Array = ALL.duplicate()
	var species: Array = SPECIES.duplicate()
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--mode="): mode = s.substr(7)
		if s.begins_with("--heroes="): heroes = Array(s.substr(9).split(","))
		if s.begins_with("--species="): species = Array(s.substr(10).split(","))
		if s.begins_with("--shots-dir="): dir = s.substr(12)
	main.get_window().size = SIZE
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	match mode:
		"hunters": await _hunters(heroes)
		"boki": await _boki(species)
		"arena":
			fight_zoom = 1.0
			still_at = 5.0
			await _fight(7.0)
			DirAccess.rename_absolute(dir.path_join("clip1.png"), dir.path_join("arena.png"))
	print("OWNERSHOTS done %s" % mode)
	main.get_tree().quit(0)

func _save_shot(file: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))

## Runs the match for `secs` (the player holds `move`/`fire`, aiming at `aim_at` when given) and returns.
func _run_for(secs: float, move: Vector2, fire: bool, aim_at, shots: Array, prefix: String) -> void:
	var P := m.player
	var t := 0.0
	var k := 0
	while t < secs:
		_purge()
		P.inp["move"] = move
		P.inp["fire"] = fire
		if aim_at != null:
			P.inp["aim"] = aim_at
		elif move != Vector2.ZERO:
			P.inp["aim"] = P.pos + Vector3(move.x, 0, move.y) * 8.0 + Vector3(0, 0.9, 0)
		for _i in 2:
			m.step(STEP)
		m.cam.follow(P.pos, FRAME, false)
		for h in m.hunters:
			h.render(FRAME, 1.0)
		await main.get_tree().process_frame
		t += FRAME
		if k < shots.size() and t >= shots[k]:
			_save_shot("%s_%d.png" % [prefix, k])
			k += 1

func _hunters(heroes: Array) -> void:
	for hero in heroes:
		if m:
			m.queue_free()
		await _start(hero, "cindle")
		var P := m.player
		P.ctrl = "idle"
		var lane: Vector3 = MoveSpeedCheck.flat_lane(m.world, P.pos, 26)
		P.teleport(lane)
		if m.hud:
			m.hud.set("visible", false)
		var foe := _hunter("dummy", 1, "archer" if hero == "bulwark" else "bulwark", "pebbit", lane + Vector3(4.0, 0, 0))
		foe.ctrl = "idle"
		foe.ai = {}
		foe.teleport(foe.pos)
		_zoom(ZOOM)
		m.cam.snap(P.pos)
		# idle: facing the foe, settled
		await _run_for(1.5, Vector2.ZERO, false, foe.pos + Vector3(0, 0.9, 0), [1.5], hero + "_idle")
		# attack: fire at the foe, three frames
		await _run_for(0.9, Vector2.ZERO, true, foe.pos + Vector3(0, 0.9, 0), [0.3, 0.55, 0.8], hero + "_atk")
		await _run_for(0.5, Vector2.ZERO, false, null, [], "x")
		# run: away from the foe
		P.teleport(lane)
		await _run_for(1.4, Vector2(1, 0), false, null, [1.0, 1.3], hero + "_run")
		print("OWNERSHOTS %s done" % hero)

func _boki(species: Array) -> void:
	var d := Save.fresh()
	var first := true
	for sp in species:
		var k := Save.new_kin(sp, String(sp).capitalize())
		k["starter"] = first
		if first:
			d["active"] = k["uid"]
		first = false
		d["roster"].append(k)
	d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	d["gems"] = 5000
	Save.d = d
	var home = await main._hb_home()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for i in 90:
		await main.get_tree().process_frame
	if home.has_method("_close_panel"):
		home._close_panel()
	home.set_process(false)
	home.set_physics_process(false)
	var base: Vector3 = home.ppos
	var n: int = home.kins.size()
	var mid := Vector3.ZERO
	for i in n:
		var kd: Dictionary = home.kins[i]
		var at: Vector3 = home.world.free_spot_near(base + Vector3((i - (n - 1) * 0.5) * 1.4, 0, 2.5), [], 0.6, 0.3, 3.0)
		at.y = home.world.ground_at(at.x, at.z)
		var node: Node3D = kd["node"]
		node.position = at
		node.rotation.y = 0.0
		kd["pos"] = at
		kd["goal"] = Vector3.INF
		mid += at / float(n)
		print("OWNERSHOTS kin %s at %s" % [kd["rec"]["species"], at])
	home.player.visible = false
	await _farm_shot(home, mid, 0.8, "boki_farm")
	home.ui.visible = false
	await _farm_shot(home, mid + Vector3(-2.6, 0, 0), 0.4, "boki_farm_a")
	await _farm_shot(home, mid + Vector3(2.6, 0, 0), 0.4, "boki_farm_b")

func _farm_shot(home, at: Vector3, z: float, file: String) -> void:
	home.cam.zoom_to = z
	home.cam.zoom = z
	home.cam.snap(at + Vector3(0, 0, 0.6))
	for i in 30:
		await main.get_tree().process_frame
	_save_shot(file + ".png")
