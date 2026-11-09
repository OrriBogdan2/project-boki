extends RefCounted
## --wisp-shots --shots-dir=<dir>: review frames for the downed Wisp (docs/decisions/0019), in a live match
## under xvfb with a renderer. The player is knocked, drifts, then is revived:
##   wisp_0_hero      standing, before the knock
##   wisp_1_pop_a     the pop-in, first frames (flash and ring)
##   wisp_2_pop_b     the pop-in settling (puff, Wisp small)
##   wisp_3_idle      the Wisp bobbing, the hero gone
##   wisp_4_moving    the Wisp drifting: leaning, trailing
##   wisp_5_mate      a teammate's Wisp beside the player's
##   wisp_6_revive_a  the revive: the Wisp brightens, the hero small
##   wisp_7_revive_b  the hero scaling up
##   wisp_8_hero      the hero back at full size
## and the stolen Boki wisps (StolenWisp), beside the player:
##   stolen_0_loose   two loose wisps: the slow bob and soft pulse
##   stolen_1_held    a rival and a teammate each carry one: thin side-colour ring, tether to the carrier
##   stolen_2_scatter the rival dies: its wisp darts out on its own arc
##   stolen_3_home    match end: both fly home to the player, a ribbon behind each
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
	_take("wisp_0_hero", "The hero standing, before the knock")
	var foe: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	m.knock(P, foe, {})
	P.down_hp = 1e6
	await _go(0.07)
	_take("wisp_1_pop_a", "Pop-in, first frames: the flash and the ring where the hero was")
	await _go(0.1)
	_take("wisp_2_pop_b", "Pop-in settling: the puff drifts off, the Wisp grows to size")
	await _go(0.5)
	_take("wisp_3_idle", "The Wisp idling: bob and flicker, the hero model is hidden")
	await _go(0.5, Vector3(0.05, 0, 0.03))
	_take("wisp_4_moving", "The Wisp drifting: it leans into the move and sheds a trail")
	var mate: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	mate.teleport(P.pos + Vector3(2.0, 0, 0.0))
	m.knock(mate, foe, {})
	await _go(0.5)
	_take("wisp_5_mate", "A teammate's Wisp beside yours (the default look, tinted by team)")
	m.revive_hunter(P, null)
	await _go(0.08)
	_take("wisp_6_revive_a", "Revive: the Wisp brightens as the hero pops back in, small and squashed")
	await _go(0.12)
	_take("wisp_7_revive_b", "The hero scaling up, the Wisp fading")
	await _go(0.6)
	_take("wisp_8_hero", "The hero back at full size, no Wisp")
	await _stolen(foe, mate)
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("WISPSHOTS %d in %s" % [lines.size(), dir])
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

func _stolen(foe: Hunter, mate: Hunter) -> void:
	var front := P.pos + Vector3(0, 1.4, 0)
	var a := StolenWisp.spawn(m, "cindle", {}, front + Vector3(3, 0, -1))
	var b := StolenWisp.spawn(m, "puddlet", {}, front + Vector3(3, 0, 1.5))
	await _go(0.5)
	_take("stolen_0_loose", "Two loose Boki wisps: a slow bob and a soft pulse, grabbable")
	foe.teleport(m.world.free_spot_near(P.pos + Vector3(5, 0, 2), [], 1.0, 0.4, 8.0))
	mate.teleport(m.world.free_spot_near(P.pos + Vector3(5, 0, -3), [], 1.0, 0.4, 8.0))
	a.grab(foe, 0)
	b.grab(mate, 0)
	await _go(0.8, Vector3(0, 0, 0.04), foe)
	_take("stolen_1_held", "A rival and a teammate each carry one: a thin ring in their side colour and a tether")
	a.scatter(0, 1)
	await _go(0.3)
	_take("stolen_2_scatter", "The rival died: its wisp darts out on its own arc")
	await _go(0.7)
	a.go_home(P)
	b.go_home(P)
	await _go(0.35)
	_take("stolen_3_home", "Match end: the wisps fly home to their owner, a fading ribbon behind each")

func _go(secs: float, drift := Vector3.ZERO, who: Hunter = null) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		var mover := who if who else P
		mover.pos += drift
		mover.prev = mover.pos
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame

func _take(file: String, caption: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
