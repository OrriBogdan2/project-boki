extends RefCounted
## --bot-spacing-shots --shots-dir=<dir> [--bs-seed=<n>]: an all-bot expedition run until two bots of one
## squad fight a rival hunter together, then two frames of that fight 1.5 s apart from the game camera's
## angle (<dir>/fight_1.png, fight_2.png), on a real GPU (jobq submit --needs gpu). Prints the squadmates'
## distances and screen spots at each frame ("BOTSPACE ..."), for before/after frames of BotSquad.spread.

const CAM_UP := 15.0  # m: camera height over the fight
const CAM_BACK := 10.0  # m: camera distance back from the fight (about the match camera's tilt)
const MAX_T := 700.0  # s of match time to look for a fight in
const GAP_S := 1.5  # s of match time between the two frames
const FIGHT_T := 100.0  # s of match time before a fight counts (the ride and the drop are over)

var main: Node
var m: Match
var dir := ""


func run(main_node: Node) -> void:
	main = main_node
	var sd := 3
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--bs-seed="):
			sd = int(String(a).substr(10))
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 10, "squad": 3, "tier": 0, "seed": sd, "autoplay": true, "bot_diff": "medium"})
	m.set_process(false)
	m.hud.visible = false
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var squad: Array = []
	while m.time < MAX_T and not m.over and squad.is_empty():
		for i in 30:
			m.step(Match.DT)
		squad = _fight(m)
	if squad.is_empty():
		print("BOTSPACE no squad fight found by t=%d" % int(m.time))
		main.get_tree().quit(1)
		return
	var cam := Camera3D.new()
	cam.fov = 50.0
	main.add_child(cam)
	cam.make_current()
	for k in 2:
		if k == 1:
			for i in int(GAP_S / Match.DT):
				m.step(Match.DT)
		await _grab(cam, squad, "fight_%d" % (k + 1))
	main.get_tree().quit(0)


## Bots of one squad (two or more, on their feet, within 12 m) shooting the same rival hunter, once the squads
## have landed (FIGHT_T), or [].
func _fight(mm: Match) -> Array:
	for h in mm.hunters:
		var t = h.ai.get("tgt")
		if not (BotSquad.up(h) and t is Hunter and t.team != h.team and h.flat_dist(t) < 20.0):
			continue
		var side: Array = [h]
		for o in mm.hunters:
			if o != h and o.team == h.team and BotSquad.up(o) and o.ai.get("tgt") == t and h.flat_dist(o) < 12.0:
				side.append(o)
		if mm.time > FIGHT_T and side.size() >= 2:
			return side
	return []


func _grab(cam: Camera3D, squad: Array, file: String) -> void:
	var c := Vector3.ZERO
	for h in squad:
		c += (h as Hunter).pos / float(squad.size())
	cam.position = c + Vector3(0, CAM_UP, CAM_BACK)
	cam.look_at(c)
	var gaps: Array = []
	for h in squad:
		var nd := 99.0
		for o in squad:
			if o != h:
				nd = minf(nd, (h as Hunter).flat_dist(o))
		var sp := cam.unproject_position((h as Hunter).pos + Vector3(0, 0.9, 0))
		gaps.append("%.1f@%d,%d" % [nd, int(sp.x), int(sp.y)])
	for i in 6:
		for e in m.hunters:
			e.unseen = false
			e.render(Match.DT, 1.0)
		for e in m.mobs:
			e.render(Match.DT, 1.0)
		for e in m.kins:
			e.render(Match.DT, 1.0)
		m.render_shots(1.0)
		await main.get_tree().process_frame
	print("BOTSPACE %s t=%d squad %d nearest-mate m@screen %s" % [file, int(m.time), squad.size(), " ".join(gaps)])
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
