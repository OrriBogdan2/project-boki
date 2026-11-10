extends RefCounted
## --last-hit-colour-shots --shots-dir=<dir>: review frames for the last-hit death flash, in a live match
## under xvfb with a renderer. One monster dies to your squad and one to a rival squad, small and big:
##   hit_<kind>_<side>_a   the flash, first frames of the death
##   hit_<kind>_<side>_b   the dissolve and the spray, a beat later
## <dir>/captions.txt gets "file: caption" per file.

const DT := 1.0 / 60.0

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
	await _go(0.4)
	var foe: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	for kind in ["skitter", "brute"]:
		for side in [["yours", P], ["rival", foe]]:
			await _die(kind, side[0], side[1])
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("LASTHITSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

## A monster in front of the player dies to `by`; frames at the flash and the dissolve.
func _die(kind: String, side: String, by: Hunter) -> void:
	var at := P.pos + Vector3(0, 0, 3.0)
	var mb := m.spawn_mob(kind, Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	await _go(0.3)
	mb.hp = 0.0
	mb._on_zero(by, {})
	await _go(0.05)
	_take("hit_%s_%s_a" % [kind, side], "A %s dies to %s: the flash is the killer side's colour" % [kind, "your squad" if side == "yours" else "a rival squad"])
	await _go(0.1)
	_take("hit_%s_%s_b" % [kind, side], "The same death a beat later: dissolve and spray")
	await _go(0.6)

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
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var spot := m.world.random_ground()
	P.teleport(spot)
	var away := m.world.random_ground()
	for k in 500:
		if away.distance_to(spot) > 45.0:
			break
		away = m.world.random_ground()
	for h in m.hunters:
		if h != P:
			h.teleport(m.world.free_spot_near(away, [], 1.0, 0.4, 8.0))

func _go(secs: float, drift := Vector3.ZERO) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		P.pos += drift
		P.prev = P.pos
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame

func _take(file: String, caption: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
