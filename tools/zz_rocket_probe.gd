extends RefCounted
## Throwaway probe (not committed): when do the rival squad's bots launch in drop_rocket_check's setup?
func run(main: Node) -> void:
	await main.get_tree().process_frame
	for trial in 6:
		var m := Match.new()
		main.add_child(m)
		m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1500.0, "seed": 4242})
		m.set_process(false)
		m.skydrop.planning = false
		var foe := 1 - m.player.team
		var ja := []
		for h in m.hunters:
			if h.team == foe:
				ja.append("%s lead=%s ja=%.1f" % [h.pname, m.skydrop.is_lead(h), float(h.ai.get("jump_at", -1.0))])
		var t := 0.0
		while t < 40.0 and not m.skydrop.rockets.has(foe):
			m.step(Match.DT)
			t += Match.DT
		print("PROBE trial %d foe launch t=%.1f ride=%.1f %s" % [trial, t, float(m.ship.get("ride", -1)), ja])
		m.queue_free()
		await main.get_tree().process_frame
	main.get_tree().quit()
