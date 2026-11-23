extends RefCounted
## --weapon-check: every weapon against a standing target at a couple of ranges, tapping and
## (for swords) charging, and prints the damage per second it actually lands.


func run(main: Node) -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weapon-check="):
			only = a.substr(15)
	for ad in Arch.ids():
		var wid := Arch.signature(String(ad))
		if only != "" and wid != only:
			continue
		var cls := Arch.weight(String(ad))
		var wd: Dictionary = Data.weapon_stats(wid)
		var modes: Array = ["tap", "charge"] if wd.has("charge_time") else ["hold"]
		for mode in modes:
			for dist in (
				[1.6]
				if wd.get("melee", false)
				else ([1.5, 3.0] if wd.has("pellets") else [3.0, float(wd["range"]) * 0.8])
			):
				var m := Match.new()
				main.add_child(m)
				m.start(
					{
						"training": true,
						"teams": 1,
						"squad": 1,
						"tier": 0,
						"length": 1e9,
						"seed": 4242,
						"no_drop": true,
						"weapon": wid,
						"cls": cls,
						"arch": ad
					}
				)
				m.set_process(false)
				var p: Hunter = m.player
				var t_v: Hunter = null
				var home := Vector3.ZERO
				# find flat open ground for both
				for tries in 400:
					# the training island first; long sightlines may need the open ground elsewhere
					var at: Vector3 = (
						m.world.random_ground(m.world.island_of(p.pos.x, p.pos.z))
						if tries < 200
						else m.world.random_ground()
					)
					var to := at + Vector3(dist, 0, 0)
					var ok := true
					for k in 9:
						var q := at.lerp(to, k / 8.0)
						if m.world.is_block(q.x, q.z) or absf(m.world.ground_at(q.x, q.z) - at.y) > 0.01:
							ok = false
					if ok:
						home = at
						p.teleport(at)
						t_v = m.make_hunter("T", 5, "medium", "Target", "idle", {}, to)
						break
				if t_v == null:
					print("WCHECK %s: no spot" % wid)
					m.queue_free()
					continue
				t_v.max_hp = 100000.0
				t_v.hp = t_v.max_hp
				t_v.armor = 0.0
				t_v.max_armor = 0.0
				for mb in m.mobs:
					mb.queue_free()
				m.mobs.clear()
				var t := 0.0
				var dur := 6.0
				while t < dur:
					t_v.teleport(p.pos + Vector3(dist, 0, 0))
					t_v.vel = Vector3.ZERO
					p.inp["aim"] = t_v.pos + Vector3(0, 0.9, 0)
					p.inp["aim_y"] = t_v.pos.y
					if mode == "tap":
						p.inp["fire"] = int(t / 0.05) % 2 == 0
					elif mode == "charge":
						# hold until the charge is full, then let go for a moment
						if p.inp["fire"] and p.atk.charge_k() >= 1.0:
							p.inp["fire"] = false
							p.set_meta("rel", 0.5)
						elif not p.inp["fire"]:
							p.set_meta("rel", float(p.get_meta("rel", 0.0)) - Match.DT)
							if float(p.get_meta("rel", 0.0)) <= 0.0:
								p.inp["fire"] = true
								p.teleport(home)
								p.vel = Vector3.ZERO  # lunges carry you off the test strip
					else:
						p.inp["fire"] = true
					m.mobs.clear()
					m.step(Match.DT)
					t += Match.DT
				var dealt := t_v.max_hp - t_v.hp
				print(
					(
						"WCHECK %-12s %-6s dist %4.1f  dps %6.1f  (%d in %ds)"
						% [wid, mode, dist, dealt / dur, int(dealt), int(dur)]
					)
				)
				m.queue_free()
				await main.get_tree().process_frame
	main.get_tree().quit()
