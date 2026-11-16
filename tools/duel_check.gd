extends RefCounted
## --duel-check, moved out of main.gd (AGENTS.md section 2); registered in tools/check_registry.gd.

var main: Node

## Headless smoke test for the duel room: your autopilot against the sparring bot for a few
## minutes, changing the bot's class, behaviour, glove and difficulty along the way.
func run(main_node: Node) -> void:
	main = main_node
	var o := Match.duel_opts()
	o["autoplay"] = true
	var m := Match.new()
	main.add_child(m)
	m.start(o)
	m.set_process(false)
	var ok := true
	if m.duel == null or m.duel.bot == null:
		print("DUEL FAIL no bot"); main.get_tree().quit(); return
	print("DUEL START player=%s bot=%s dist=%.1f" % [m.player.pos.snapped(Vector3(0.1, 0.1, 0.1)), m.duel.bot.pos.snapped(Vector3(0.1, 0.1, 0.1)), m.player.flat_dist(m.duel.bot)])
	var plan := {20.0: ["mode", 1], 40.0: ["mode", 1], 60.0: ["mode", 1], 80.0: ["cls", 1], 100.0: ["glove", 1], 120.0: ["diff", 1], 140.0: ["weapon", 1]}
	var done := {}
	while m.time < 170.0:
		m.step(Match.DT)
		for t in plan:
			if m.time >= float(t) and not done.has(t):
				done[t] = true
				m.duel.cycle(String(plan[t][0]), int(plan[t][1]))
				print("DUEL t=%d %s -> %s / %s / %s / %s / %s" % [m.time, plan[t][0], m.duel.pick_text("cls"), m.duel.pick_text("weapon"), m.duel.pick_text("glove"), m.duel.pick_text("diff"), m.duel.pick_text("mode")])
		if m.duel.bot == null or not is_instance_valid(m.duel.bot):
			print("DUEL FAIL bot lost at ", m.time); ok = false; break
		if m.over:
			print("DUEL FAIL match ended at ", m.time); ok = false; break
	var st: Dictionary = m.duel.stats
	print("DUEL STATS ", st, " rounds=", m.duel.round_n, " bots=", m.hunters.size())
	if int(st["shots"]) <= 0 or float(st["dealt"]) <= 0.0:
		print("DUEL FAIL nothing landed"); ok = false
	print("DUEL CHECK ", "PASS" if ok else "FAIL")
	main.get_tree().quit()
