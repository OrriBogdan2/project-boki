extends RefCounted
## --parkour-check: the Training Grounds' parkour course, run by a scripted player with the real
## controls (ParkourBot) for every class (light, medium, heavy), each class's own dash charges and
## long dash. Every run must finish, every mantle must land on top, the player is never inside
## the ground or a cliff, the "Leaving the Training Grounds" toast never fires on the grounds (gaps,
## glides, air dashes, falls), a fall puts you back on the last checkpoint, and the best time is kept
## on the profile (a save that's never written). It also climbs the practice isle's wall with real
## key presses from each side. Never touches the save file.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	printerr("PKCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _stand(h, at: Vector3) -> void:
	h.climb = {}
	h.ppos = Vector3(at.x, 0, at.z)
	h.py = h._ground_h(at.x, at.z)
	h.pvy = 0.0; h.pvel = Vector3.ZERO; h.gliding = false; h.dash_t = 0.0
	h.player.position = h.ppos + Vector3(0, h.py, 0)

## One frame of play: the controls (the bot), the player's movement, the grounds.
func _frame(h, bot, d: float) -> void:
	if bot: bot.drive(d)
	h._move_player(d)
	h.training.tick(d)

## True if the body is inside the ground or a cliff (feet under the ground, or a wall in its radius).
func _clipped(h) -> float:
	if not h.climb.is_empty():
		return 0.0
	var g: float = h._ground_h(h.ppos.x, h.ppos.z)
	if g > World.VOID + 1.0 and h.py < g - 0.05:
		return g - h.py
	var o: float = h.world.occupy(h.ppos.x, h.ppos.z, 0.22, h.py, false)
	if o > 0.0 and o > h.py + 0.4:
		return o - h.py
	return 0.0

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	var save_path := Save.path_for(Save.slot)
	var before := FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else "<none>"
	Save.d = Save.fresh()
	var pk := Save.new_kin("zapple", "Pip"); Save.d["roster"].append(pk); Save.d["active"] = pk["uid"]
	Save.d["tutorial"]["home"] = true; Save.d["tutorial"]["day1_done"] = true
	Econ.ensure()
	var H = load("res://scripts/home/home.gd")
	var h = H.new()
	main.add_child(h)
	main.current = h
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	h.set_process(false)
	h._close_panel()
	printerr("PKCHECK home built")
	var c: HomeParkour = h.training.course
	var DT := 1.0 / 60.0
	# ---- the course is there, joined up, and the grounds are bigger than they were (8 x 4.4)
	var tiles := 0
	for i in h.world.kind.size():
		var iid := int(h.world.island[i])
		if iid >= 0 and String(h.world.islands[iid]["id"]).begins_with("training") and h.world.kind[i] != World.T_VOID: tiles += 1
	ok(tiles > 420, "the Training Grounds (practice isle and course) cover %d tiles (the old isle and islet were about 130)" % tiles)
	ok(h.world.island_id(52.0, 59.5) == "training_start" and h.world.island_id(70.5, 59.5) == "training_climb" and absf(h.world.ground_at(70.5, 59.5) - 5.6) < 0.01, "the Start isle and the 5.6m tower are carved in")
	# ---- the practice isle's climbing wall, with real key presses, from each side
	var wall_ok := 0
	var sides := [[Vector3(36.7, 0, 56.9), Vector2(-1, 0)], [Vector3(32.3, 0, 56.6), Vector2(1, 0)], [Vector3(34.4, 0, 55.2), Vector2(0, 1)], [Vector3(34.4, 0, 58.6), Vector2(0, -1)],
		[Vector3(36.9, 0, 55.4), Vector2(-0.7, 0.7)]]
	for sd in sides:
		_stand(h, sd[0])
		var top := false
		for i in 120:
			# walk into the wall, then press Space (held for a few frames, as a player does)
			h.sim_input = {"move": sd[1], "held": {"jump": i >= 20 and i < 26}, "just": {"jump": i == 20}}
			_frame(h, null, DT)
			if i > 20 and h.climb.is_empty() and h.pvy == 0.0 and absf(h.py - 1.6) < 0.02:
				top = true; break
		h.sim_input = {}
		if top: wall_ok += 1
		else: printerr("PKCHECK   wall from %s: ended at %s, height %.2f" % [sd[1], str(h.ppos), h.py])
	ok(wall_ok == sides.size(), "walking at the practice wall and pressing Space climbs it from every side and a corner (%d of %d)" % [wall_ok, sides.size()])
	# ---- the course, for each class
	var times := {}
	for cls in ["light", "medium", "heavy"]:
		Save.d["cls"] = cls
		_stand(h, Vector3(44.0, 0, 59.5))
		h.dash_charges = 9.0; h.ex_cd = 0.0
		h._move_player(0.0001)      # (tops the charges up to the class's count)
		h.training.tick(DT)
		for k in c.stats: c.stats[k] = 0
		var bot := ParkourBot.new(h)
		var t := 0.0
		var clip_n := 0; var worst := 0.0
		var out_zone := 0
		var climbing := false
		var climbs := 0; var climbs_ok := 0
		var heights: Array = []
		var min_ring := [99.0, 99.0]
		while not bot.done and t < 150.0:
			var was_climb: bool = not h.climb.is_empty()
			_frame(h, bot, DT)
			t += DT
			var cl := _clipped(h)
			if cl > 0.0:
				clip_n += 1; worst = maxf(worst, cl)
			if not h.training.in_zone: out_zone += 1
			if not was_climb and not h.climb.is_empty():
				climbs += 1; climbing = true
				heights.append(snappedf(float(h.climb["to"].y) - float(h.climb["from"].y), 0.01))
			if climbing and h.climb.is_empty():
				climbing = false
				if absf(h.py - h._ground_h(h.ppos.x, h.ppos.z)) < 0.02: climbs_ok += 1
			var body: Vector3 = h.ppos + Vector3(0, h.py + 0.8, 0)
			for ri in HomeParkour.RINGS.size():
				min_ring[ri] = minf(min_ring[ri], body.distance_to(HomeParkour.RINGS[ri]))
		bot.stop()
		await main.get_tree().process_frame
		var st: Dictionary = c.stats
		times[cls] = t
		printerr("PKCHECK   %s: phases %s; climbs %s; rings %d (closest %.2f, %.2f); falls %d" % [cls, str(bot.log), str(heights), st["rings"], min_ring[0], min_ring[1], st["falls"]])
		ok(bot.done and st["finished"] == 1, "%s finishes the course in %.1fs (phases %d of %d)" % [cls, t, bot.ph, ParkourBot.PH.size() - 1])
		ok(climbs >= 3 and climbs_ok == climbs, "%s: every mantle lands on top (%d of %d)" % [cls, climbs_ok, climbs])
		ok(clip_n == 0, "%s: never inside the ground or a cliff (%d frames, worst %.2fm)" % [cls, clip_n, worst])
		ok(st["leaves"] == 0 and out_zone == 0, "%s: no 'Leaving the Training Grounds' toast anywhere on the course (%d toasts, %d frames out)" % [cls, st["leaves"], out_zone])
		ok(st["rings"] >= 2 and st["pads"] >= 1 and st["falls"] == 0, "%s: both air rings and the jump pad, no falls" % cls)
	# ---- a fall mid-run puts you back on the last checkpoint, still on the grounds
	Save.d["cls"] = "medium"
	_stand(h, Vector3(49.0, 0, 59.5)); h.training.tick(DT)
	c.last_x = 49.0
	_stand(h, Vector3(52.0, 0, 59.5)); h.training.tick(DT)
	ok(c.running(), "walking through the Start gate starts the clock")
	_stand(h, Vector3(63.0, 0, 59.5)); h.training.tick(DT)
	ok(int(c.run.get("cp", 0)) == 1, "standing on the step reaches checkpoint 1")
	h.ppos = Vector3(60.5, 0, 59.5); h.py = 0.6; h.pvy = -2.0; h.pvel = Vector3.ZERO
	var fell := false
	for i in 240:
		h._move_player(DT); h.training.tick(DT)
		if c.stats["falls"] > 0: fell = true; break
	ok(fell and Vector2(h.ppos.x - 63.0, h.ppos.z - 59.5).length() < 0.1 and c.running() and h.training.in_zone and c.stats["leaves"] == 0,
		"falling into a gap puts you back on the checkpoint, the clock still running, never 'leaving' (at %.1f, %.1f)" % [h.ppos.x, h.ppos.z])
	# skipping ahead: the finish doesn't count until every checkpoint is reached
	_stand(h, Vector3(42.5, 0, 65.5)); c.last_x = 42.5; h.training.tick(DT)
	_stand(h, Vector3(41.0, 0, 65.5)); h.training.tick(DT)
	ok(c.running() and c.stats["finished"] == 0, "the Finish gate doesn't count with checkpoints missed")
	# leaving over the bridge ends the run, and says so once
	_stand(h, Vector3(39.5, 0, 48.0)); h.training.tick(DT)
	ok(not c.running() and not h.training.in_zone and c.stats["leaves"] == 1, "walking off the grounds over the bridge ends the run (one toast)")
	# ---- the best time is on the profile
	var pkd: Dictionary = Save.d.get("parkour", {})
	var bc: Dictionary = pkd.get("by_cls", {})
	var best := float(pkd.get("best", 0.0))
	ok(best > 0.0 and absf(best - minf(minf(float(bc.get("light", 99.0)), float(bc.get("medium", 99.0))), float(bc.get("heavy", 99.0)))) < 0.02 and bc.size() == 3,
		"the profile keeps the best time %s and one per class %s" % [HomeParkour.fmt(best), str(bc)])
	ok((pkd.get("ghost", []) as Array).size() > 50 and int(pkd.get("runs", 0)) == 3, "and the best run's path for its ghost (%d points), %d runs" % [(pkd.get("ghost", []) as Array).size(), int(pkd.get("runs", 0))])
	var after := FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else "<none>"
	ok(Save.no_write and before == after, "the save file on disk is untouched")
	# a new run shows the ghost of the best one
	_stand(h, Vector3(49.0, 0, 59.5)); c.last_x = 49.0; h.training.tick(DT)
	_stand(h, Vector3(52.0, 0, 59.5)); h.training.tick(DT)
	for i in 30: h.training.tick(DT)
	ok(is_instance_valid(c.ghost) and c.ghost.visible, "a new run races your best run's ghost")
	printerr("PARKOUR CHECK DONE, failures: %d" % bad)
	main.get_tree().quit()
