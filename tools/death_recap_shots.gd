extends RefCounted
## --death-recap-shots --shots-dir=<dir>: review screenshots of the down/death card (scripts/ui/death_recap.gd),
## in a live match under xvfb with a renderer:
##   recap_downed   knocked by a foe's ability, a teammate still up: who, the ability, the last 10 s
##   recap_out      out, a teammate still up: the card plus "Watching <teammate> (LMB: next teammate)"
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
	Save.no_write = true
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
	var foe: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	foe.arch = "thief"
	foe.pname = "Sable"
	var home := m.world.random_ground()
	P.teleport(home)
	foe.teleport(m.world.free_spot_near(home, [], 1.0, 0.4, 5.0))
	await _go(0.5)
	P.hurt(60.0, foe, {"src": "shot"})
	P.hurt(30.0, null, {"src": "fall"})
	P.hurt(P.max_hp * 2.0, foe, {"src": "abil", "ab": "utility", "tags": ["utility", "knife"]})
	await _go(0.4)
	_take("recap_downed", "Downed by a foe's ability: the Hunter in their colour, the ability, damage by source")
	m.eliminate(P, foe, "finished")
	await _go(3.0)
	_take("recap_out", "Out with a teammate up: the same card and the camera key to watch the next teammate")
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("DEATHRECAPSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame

func _take(file: String, caption: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
