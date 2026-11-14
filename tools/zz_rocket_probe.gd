extends RefCounted
## Throwaway probe (not committed): the rival rocket's flight after drop_rocket_check moves it mid-map.
func run(main: Node) -> void:
	await main.get_tree().process_frame
	for trial in 3:
		var m := Match.new()
		main.add_child(m)
		m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1500.0, "seed": 4242})
		m.set_process(false)
		m.skydrop.planning = false
		var foe := 1 - m.player.team
		var t := 0.0
		while t < 40.0 and not m.skydrop.rockets.has(foe):
			m.step(Match.DT)
			t += Match.DT
		var r: DropRocket = m.skydrop.rockets[foe]
		var w: World = m.world
		var l: Hunter = m.skydrop.leader(foe)
		print("PROBE launch t=%.1f pos=%s land=%s lvoid=%s mid_void=%s" % [t, r.pos, l.ai.get("land"), w.is_void(float(l.ai.get("land", Vector3.ZERO).x), float(l.ai.get("land", Vector3.ZERO).z)), w.is_void(w.w * 0.5, w.h * 0.5)])
		if not w.is_void(w.w * 0.5, w.h * 0.5):
			r.pos = Vector3(w.w * 0.5, w.ground_at(w.w * 0.5, w.h * 0.5) + 40.0, w.h * 0.5)
			r.vel = Vector3(0.0, r.vel.y, 0.0)
		Sfx.last_played.clear()
		t = 0.0
		var hit := ""
		while t < 40.0 and not r.done:
			m.step(Match.DT)
			Sfx.listener = r.pos + Vector3(45, 0, 0)
			t += Match.DT
			if hit == "" and w.is_void(r.pos.x, r.pos.z):
				hit = "over void at %.1f pos %s" % [t, r.pos]
		print("PROBE flight done=%s t=%.1f pos=%s void=%s %s land_played=%s riders=%d" % [r.done, t, r.pos, w.is_void(r.pos.x, r.pos.z), hit, Sfx.last_played.has("rocket_land"), r.riders.size()])
		m.queue_free()
		await main.get_tree().process_frame
	main.get_tree().quit()
