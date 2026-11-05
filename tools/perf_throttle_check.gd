extends RefCounted
## --perf-throttle-check, item 94's script throttles: an idle monster with nobody within Mob.NAP_M stops
## simulating and wakes when a Hunter comes close; a bot further than Bot.FAR_M from the local player decides
## and roaming decides every Bot.FAR_EVERY steps (the skipped time added in), a near one every step.

var main: Node
var fails := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("PERFTHROTTLE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	await main.get_tree().process_frame
	_mob_naps()
	_far_bots()
	print("PERFTHROTTLE DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _step(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT

func _mob_naps() -> void:
	var mb: Mob = null
	for x in m.mobs:
		if not x.dead and x.st == "idle":
			mb = x
			break
	ok(mb != null, "setup: an idle camp monster")
	if mb == null:
		return
	for h in m.hunters:
		if h.flat_dist(mb) < Mob.NAP_M + 10.0:
			h.teleport(mb.pos + Vector3(Mob.NAP_M + 20.0, 0, 0))
	for k in m.kins:
		k.pos = mb.pos + Vector3(Mob.NAP_M + 20.0, 0, 0)
	_step(1.0)
	var at := mb.pos
	_step(2.0)
	ok(mb.pos == at and mb.st == "idle", "with nobody within %.0f m it sleeps where it stands" % Mob.NAP_M)
	m.player.teleport(mb.pos + Vector3(4.0, 0, 0))
	for k in m.kins:
		k.pos = m.player.pos
	_step(1.5)
	ok(mb.st != "idle" or mb.pos != at, "a Hunter walking up wakes it (%s)" % mb.st)

func _far_bots() -> void:
	var b: Hunter = null
	for h in m.hunters:
		if h.ctrl == "bot":
			b = h
	ok(b != null, "setup: a bot")
	if b == null:
		return
	var brain := Bot.new()
	b.teleport(m.player.pos + Vector3(Bot.FAR_M + 15.0, 0, 0))
	b.ai["tgt"] = null
	b.ai["goal_kind"] = "roam"
	var thinks := 0
	for i in Bot.FAR_EVERY * 4:
		var before := float(b.ai["dash_cd"])
		brain.tick(m, b, Match.DT)
		if float(b.ai["dash_cd"]) != before:
			thinks += 1
	ok(thinks == 4, "far away it decides every %d steps (%d decisions)" % [Bot.FAR_EVERY, thinks])
	b.teleport(m.player.pos + Vector3(5.0, 0, 0))
	thinks = 0
	for i in 6:
		var before := float(b.ai["dash_cd"])
		brain.tick(m, b, Match.DT)
		if float(b.ai["dash_cd"]) != before:
			thinks += 1
	ok(thinks == 6, "near the player it decides every step (%d of 6)" % thinks)
