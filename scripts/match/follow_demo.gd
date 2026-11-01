class_name FollowDemo
extends RefCounted
## Screenshots of follower Boki (--follow-demo=walk|ko|steal|watch). walk: you just tamed one and
## it trots after you; ko: it is down beside you; steal: a rival hunter left one behind and its
## steal window is running in front of you; watch: you went out and your own is on its own.
static func run(m: Match, _dt: float) -> void:
	var what := String(m.opts["follow_demo"])
	if not m.has_meta("fdemo"):
		m.set_meta("fdemo", true)
		Settings.v["tips"] = false          # (screenshots: no tutorial cards)
		var at := m.demo_clear_spot(4.0)
		var rec := Save.new_kin(String(m.opts.get("follow_kin", "puddlet")), "", m.kin_seed("fdemo"))
		if what == "steal":
			var R: Hunter = null
			for h in m.hunters:
				if h.team != m.player.team: R = h; break
			R.ctrl = "idle"
			R.teleport(m.world.free_spot_near(m.player.pos + Vector3(30, 0, 0), [], 1.0, 0.4, 20.0))
			rec["name"] = Data.KIN[rec["species"]]["name"]
			Follow.spawn(m, R, rec, at)
			R.lives = 1
			m.eliminate(R, null, "knocked out", true)
			Life.make_gone(m, R)
			m.player.face = atan2(-(at.x - m.player.pos.x), -(at.z - m.player.pos.z))
			return
		rec["name"] = "Drip"
		var f := Follow.spawn(m, m.player, rec, at)
		if what == "ko":
			f.hurt(9999.0, null, {})
		if what == "watch":
			m.player.lives = 1
			m.player.teleport(m.world.free_spot_near(m.player.pos + Vector3(30, 0, 0), [], 1.0, 0.4, 20.0))
			m.eliminate(m.player, null, "knocked out", true)
			Life.make_gone(m, m.player)
		return
	if what == "walk" and m.time > 0.6 and m.time < 2.4:
		m.player.inp["move"] = Vector2(0.8, 0.4).normalized()
	elif what == "walk":
		m.player.inp["move"] = Vector2.ZERO

