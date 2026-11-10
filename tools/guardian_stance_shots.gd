extends RefCounted
## --guardian-stance-shots --shots-dir=<dir>: one strip per body plan (quad cindle, biped zapple, flyer wisplet) of
## the guardian Boki in a live match under xvfb with a renderer (KinGuardStance):
##   <species>_1_burst   just out of the wisp, already facing the threat
##   <species>_2_stance  standing guard, low and wide, nothing near
##   <species>_3_turn    the threat is on its other side: it has swung round
##   <species>_4_strike  it lunges with its attack clip
##   <species>_5_fold    the window is over: it shrinks back into the wisp
## <dir>/captions.txt gets "file: caption" per file.

const DT := 1.0 / 60.0
const PLANS := {"quad": "cindle", "biped": "zapple", "flyer": "wisplet"}
const ZOOM := 0.45   # close, so the pose reads

var main: Node
var m: Match
var p: Hunter
var k: Kin
var foe: Hunter
var dir := ""
var lines: Array = []

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	for plan in PLANS:
		await _strip(plan, PLANS[plan])
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("GUARDSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _strip(plan: String, species: String) -> void:
	await _setup(species)
	_foe_to(Vector3(4.0, 0, 0))
	m.knock(p, foe, {})
	p.down_hp = 1e6
	await _go(0.12)
	_take(species + "_1_burst", "%s (%s): bursts out of the wisp already facing the threat" % [species, plan])
	_foe_to(Vector3(40.0, 0, 0))
	k.target = null
	await _go(1.2)
	_take(species + "_2_stance", "%s: nothing near, a low, wide, alert stance by the Hunter Wisp" % species)
	_foe_to(Vector3(-4.0, 0, 0))
	await _go(0.25)
	_take(species + "_3_turn", "%s: the threat moved to its other side, it has turned to face it" % species)
	_foe_to(Vector3(-1.4, 0, 0))
	for i in 180:
		await _go(DT)
		if k.lunge_t > 0.0:
			break
	_take(species + "_4_strike", "%s: it strikes with its attack clip, the stance dropped" % species)
	_foe_to(Vector3(40.0, 0, 0))
	k.summon.left = 0.05
	await _go(0.2)
	_take(species + "_5_fold", "%s: the window is over, it shrinks back into the wisp" % species)

func _setup(species: String) -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "demo_kin": species,
		"boki_wisps": true})
	m.set_process(false)
	p = m.player
	k = p.kin
	foe = m.hunters.filter(func(x): return x.team != p.team)[0]
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	p.teleport(m.world.random_ground())
	m.cam.zoom_to = ZOOM
	m.cam.zoom = ZOOM
	await _go(0.4)

func _foe_to(offset: Vector3) -> void:
	foe.pos = p.pos + offset
	foe.prev = foe.pos

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		m.cam.snap(p.pos + Vector3(0, 0.6, 0))
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame

func _take(file: String, caption: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
