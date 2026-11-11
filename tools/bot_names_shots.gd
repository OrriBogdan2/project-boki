extends RefCounted
## --bot-names-shots --shots-dir=<dir>: a 10-trio match with the player beside a teammate squad and a rival
## squad, so the nameplates, the kill feed and the scoreboard show the bots' gamer tags (no hunter titles).

const DT := 1.0 / 60.0

var main: Node
var m: Match
var P: Hunter
var dir := ""

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 10, "squad": 3, "tier": 0, "length": 1e9, "seed": 31, "no_drop": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.lives = 3
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var home := m.world.random_ground()
	P.teleport(home)
	var i := 0
	for h in m.hunters:
		if h == P:
			continue
		var side := -1.0 if h.team == P.team else 1.0
		var at := home + Vector3(side * 3.0 + float(i % 3) * 0.2, 0, -3.5 - float(i % 3) * 2.2)
		h.teleport(m.world.free_spot_near(at + Vector3(2.5 * (side + 1.0), 0, 0), [], 0.8, 0.4, 3.0))
		i += 1
		if i >= 5:
			break
	P.inp["aim"] = home + Vector3(0, 0.9, -6)
	await _go(0.8)
	_take("plates")
	var rivals: Array = m.hunters.filter(func(x): return x.team != P.team)
	m.knock(rivals[0], P, {})
	m.knock(rivals[1], rivals[2], {})
	m.eliminate(rivals[0], P, "finished")
	await _go(0.5)
	_take("feed")
	print("BOTNAMESSHOTS ", ", ".join(m.feed.map(func(f): return f["text"])))
	main.get_tree().quit(0)

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame

func _take(file: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
