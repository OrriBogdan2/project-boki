extends RefCounted
## --base-check: basing to a teammate (B): a clean channel arrives weakened; a hit interrupts.

func run(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "no_drop": true, "seed": 77, "autoplay": true, "big": false})
	m.set_process(false)
	var p: Hunter = m.player
	p.ctrl = "local"
	var mate := m.base_target(p)
	if mate == null:
		print("BCHECK FAIL no teammate"); main.get_tree().quit(); return
	mate.ctrl = "idle"   # the check measures the recall landing beside the mate, not where a wandering mate strolls off to during the 3 s channel
	for i in 30: m.step(Match.DT)
	p.inp["move"] = Vector2.ZERO
	p.start_base(mate)
	var t := 0.0
	while t < 3.3:
		p.inp["move"] = Vector2.ZERO
		m.step(Match.DT); t += Match.DT
	var near := p.flat_dist(mate) < 2.5
	print("BCHECK clean: arrived=%s weak=%.1f cd=%.0f dmg_mult=%.2f" % [near, p.weak_t, p.base_cd, m.dmg_mult(p)])
	p.base_cd = 0.0
	p.start_base(mate)
	for i in 30: m.step(Match.DT)
	p.hurt(5.0, null, {"src": "test"})
	print("BCHECK interrupt: channel=%.2f cancelled=%s" % [p.base_t, p.base_t <= 0.0])
	print("BCHECK ", "PASS" if near and p.base_t <= 0.0 else "FAIL")
	main.get_tree().quit()
