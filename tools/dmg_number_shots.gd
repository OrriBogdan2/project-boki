extends RefCounted
## --dmg-number-shots --shots-dir=<dir>: the match camera in a crowded fight, to compare damage numbers
## before and after the roll-up. Five rivals stand in front of the player; each takes a zone tick every
## quarter second for two seconds, one a crit and one a heavy hit, the reticle on the nearest.
##   dmgnum_0_ticks   mid-fight, ticks landing
##   dmgnum_1_end     the last tick, numbers at their totals
## <dir>/captions.txt gets "file: caption" per file.

const DT := 1.0 / 60.0
const TICK_EVERY := 15     # frames: a quarter second

var main: Node
var m: Match
var P: Hunter
var fx: Fx
var dir := ""
var foes: Array = []

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var lines: Array = []
	for f in 120:
		if f % TICK_EVERY == 0:
			_tick(f)
		await _frame()
		if f == 70:
			_take("dmgnum_0_ticks", lines, "Mid-fight: five rivals taking ticks, reticle on the nearest")
	_take("dmgnum_1_end", lines, "After two seconds of ticks, a crit and a heavy hit")
	var cap := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		cap.store_line(l)
	cap.close()
	print("DMGNUMSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 5, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	P = m.player
	fx = m.fx
	fx.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	P.teleport(m.world.random_ground())
	var i := 0
	for h in m.hunters.filter(func(x): return x.team != P.team):
		h.max_hp = 1e6
		h.hp = 1e6
		var ring := Vector3(1, 0, 0).rotated(Vector3.UP, i * TAU / 5.0) * 3.5
		h.teleport(m.world.free_spot_near(P.pos + ring, [], 1.0, 0.4, 6.0))
		foes.append(h)
		i += 1
	await _frame()
	print("DMGNUMSHOTS foes at ", foes.map(func(h): return h.pos.snapped(Vector3(0.1, 0.1, 0.1))))
	var cam := main.get_viewport().get_camera_3d()
	main.get_viewport().warp_mouse(cam.unproject_position(foes[0].pos + Vector3(0, 1.5, 0)))

func _tick(f: int) -> void:
	for h in foes:
		h.hurt(6.0, P, {"src": "abil", "tags": ["ult", "cinder_zone"]})
	if f == 60:
		foes[1].hurt(40.0, P, {"src": "shot", "crit": true})
		foes[2].hurt(240.0, P, {"src": "shot"})

func _frame() -> void:
	m.step(DT)
	fx._process(DT)
	m.cam.snap(P.pos)
	for h in m.hunters:
		h.render(DT, 1.0)
	await main.get_tree().process_frame

func _take(file: String, lines: Array, caption: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
