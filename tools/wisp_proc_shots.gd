extends RefCounted
## --wisp-proc-shots --shots-dir=<dir>: GPU frames of the wisp proc cue (WispProc) at the match camera, in a live
## match. Each carried passive acts on the player (heal, shield, damage bonus, speed boost), the shot is taken 0.1 s
## after the cue: proc_<kind>.png, then a rival's wisp (proc_rival.png) and a shiny Boki's (proc_shiny.png).
## strip.png puts the crops side by side. Never touches the save.

const Check := preload("res://tools/wisp_proc_check.gd")
const DT := 1.0 / 60.0
const CROP := Vector2i(360, 300)    # px cut out round the screen centre for the strip
const KINDS := ["heal", "shield", "damage", "speed", "rival", "shiny"]

var main: Node
var m: Match
var dir := ""
var chk := Check.new()
var crops: Array[Image] = []

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true,
		"demo_kin": "cindle", "boki_wisps": true})
	m.set_process(false)
	chk.m = m
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var rival: Hunter = m.hunters.filter(func(x: Hunter): return x.team != m.player.team)[0]
	rival.teleport(m.world.free_spot_near(m.player.pos + Vector3(3.5, 0, 1.0), [], 1.0, 0.4, 8.0))
	await _go(0.4)
	for kind in KINDS:
		await _kind(kind, rival)
	var strip := Image.create(CROP.x * crops.size(), CROP.y, false, Image.FORMAT_RGBA8)
	for i in crops.size():
		strip.blit_rect(crops[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * i, 0))
	strip.save_png(dir.path_join("strip.png"))
	print("WISPPROCSHOTS %d in %s" % [crops.size(), dir])
	main.get_tree().quit(0)

func _kind(kind: String, rival: Hunter) -> void:
	var who: Hunter = rival if kind == "rival" else m.player
	var k: Kin = who.kin
	var stat: String = chk.STAT_OF["heal" if kind in ["rival", "shiny"] else kind]
	if kind == "shiny":
		k.rec["shimmer"] = true
		k.get_node("Proc").free()
	chk._carry(k, stat)
	m.time += 1.0
	chk._trigger(who, "heal" if kind in ["rival", "shiny"] else kind)
	await _go(0.1)
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("proc_%s.png" % kind))
	var mid := Vector2i(img.get_size()) / 2
	crops.append(img.get_region(Rect2i(mid - CROP / 2, CROP)))
	chk._carry(k, "")

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		m.cam.snap(m.player.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame
