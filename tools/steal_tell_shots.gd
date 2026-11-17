extends RefCounted
## --steal-tell-shots --shots-dir=DIR (GPU): the steal window at the match camera (StealTell). A lair
## boss's world bar above the line, in the window with our squad near (gold, STEAL mark), in the
## window with our squad past KillXp.SHARE_R (gold, no mark), and the top bar from inside its lair.

var main: Node
var m: Match
var dir := ""
var b: Boss


func _grab(file: String, hp_frac: float) -> void:
	for i in 20:
		b.hp = b.max_hp * hp_frac
		m.step(Match.DT)
		m.cam.snap(m.player.pos)
		for h in m.hunters:
			h.render(Match.DT, 1.0)
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("%s.png" % file))
	print(
		(
			"STEALTELL-SHOT %s boss %.0f%% near=%s top=%s"
			% [file, hp_frac * 100.0, StealTell.near(m, b, m.player.team), m.lairs.boss_for(m.player) == b]
		)
	)


func _spot(h: Hunter, at: Vector3) -> void:
	h.teleport(m.world.free_spot_near(at, [], 1.0, 0.45, 6.0))
	h.vel = Vector3.ZERO


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "seed": 21, "no_drop": true, "god": true, "length": 1e9})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	var C: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var Q: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var F: Dictionary = m.lairs.list[0]
	m.lairs.activate(F)
	for g in F["guards"]:
		if is_instance_valid(g):
			g.dead = true
	m.lairs.open(F, Q, "dial")
	b = F["boss_mob"]
	var out := Vector3(F["out"].x, 0, F["out"].y)
	var c: Vector3 = F["c"]
	_spot(C, c + out * 6.0)
	_spot(Q, c - out * 6.0)
	_spot(P, c + out * 20.0)
	await _grab("steal_1_above", 0.6)
	await _grab("steal_2_window_near", StealTell.at())
	_spot(C, c + out * (KillXp.SHARE_R + 8.0))
	_spot(P, c + out * (KillXp.SHARE_R + 4.0))
	await _grab("steal_3_window_far", StealTell.at())
	_spot(P, c + out * 4.0)
	await _grab("steal_4_top_bar", StealTell.at())
	main.get_tree().quit(0)
