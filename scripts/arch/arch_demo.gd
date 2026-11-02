class_name ArchDemo
extends RefCounted
## Screenshot tooling: --arch-demo=<archetype>:<what> puts the player as that archetype in a training
## match with two rival dummies ahead and fires one part of the kit a few rendered frames before the
## shot (--frames=N): dash, rmb (tap), hold, air, e, r, bonded, level (the level HUD with a level-up).

static func frame(m: Match) -> void:
	var spec := String(m.opts.get("arch_demo", "")).split(":")
	var what := spec[1] if spec.size() > 1 else "rmb"
	var P: Hunter = m.player
	if P == null or P.out:
		return
	var f := int(m.get_meta("demo_f", 0)) + 1
	m.set_meta("demo_f", f)
	var shot_at := 120
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--frames="): shot_at = int(String(a).substr(9))
	if f == 2:
		_setup(m, P, what)
	if f < 3:
		return
	var foes: Array = m.get_meta("demo_foes", [])
	var T: Hunter = foes[0] if not foes.is_empty() else null
	if T and is_instance_valid(T):
		T.hp = T.max_hp
		P.inp["aim"] = T.pos + Vector3(0, 0.9, 0); P.inp["aim_y"] = T.pos.y
		if what in ["e", "bonded", "r"] and P.arch in ["bulwark"]:
			P.inp["aim"] = P.pos + Vector3(1.5, 0.9, 0)
	P.hp = P.max_hp
	var lead: int = {"dash": 4, "rmb": 7, "hold": 6, "air": 5, "e": 14, "r": 18, "bonded": 20, "level": 8}.get(what, 8)
	if P.arch == "mage" and what == "r": lead = 26
	if P.arch == "archer" and what == "r": lead = 30
	if P.arch == "thief" and what == "r": lead = 22
	if P.arch == "gunslinger" and what == "r": lead = 14
	if what in ["r", "bonded"] and P.ak: lead += int(P.ak.fuse_time() * 60.0)     # the fuse winds up first
	var go := shot_at - lead
	var hold_t := float(P.ak.rmb_def().get("hold", 0.3)) + 0.25 if P.ak else 0.5
	if what == "hold" and f == go - 20:
		P.inp["sec_hold"] = true
		P.ak.press_rmb()
	if what == "hold" and f > go - 20 and f < go:
		P.inp["sec_hold"] = true
		if P.arch == "juggernaut" and f == go - 1: P.inp["sec_hold"] = false
		if P.arch in ["bulwark"]: P.inp["sec_hold"] = true
	if what == "hold" and f >= go and P.arch != "bulwark" and P.arch != "mage" and P.arch != "archer" and P.arch != "gunslinger":
		P.inp["sec_hold"] = false
	if what == "air" and f == go - 8:
		P.teleport(P.pos + Vector3(0, 3.0, 0)); P.grounded = false; P.vel = Vector3(1.5, 1.0, 0)
	if f == go + 2 and T and P.arch == "thief" and P.ak and what != "r":
		(P.ak as ThiefKit).add_mark(T, 3, true)      # so the Mark pips and the purse show in the shot
	if f != go:
		return
	match what:
		"dash":
			P.inp["move"] = Vector2(1, -0.4).normalized()
			if P.arch in ["juggernaut"]:
				P.inp["dash_down"] = true; P.ak.bot_hold["dash"] = 1.0
			P.do_dash()
		"rmb", "air":
			P.inp["sec_hold"] = false
			P.ak.press_rmb()
		"e":
			P.ak.use_e()
		"r":
			P.ult = 0.0
			P.ak.use_r()
		"bonded":
			P.ult = 1.0; P.merge_cd = 0.0
			P.ak.use_r()
		"level":
			P.gain_xp(float(Hunter.XP_TO[P.lvl]) - P.xp + 1.0)

static func _setup(m: Match, P: Hunter, what: String) -> void:
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for o in m.hunters:
		if o != P: o.teleport(m.world.spawns[-1]); o.ctrl = "idle"
	var at := P.pos
	var d := Vector3(1, 0, 0)
	for ang in [0.0, PI * 0.5, PI, PI * 1.5, PI * 0.25, PI * 0.75]:
		var dd := Vector3(cos(ang), 0, sin(ang))
		var ok := true
		for k in [2.0, 4.0, 6.0, 7.0]:
			var q: Vector3 = at + dd * float(k)
			if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z) or absf(m.world.ground_at(q.x, q.z) - at.y) > 0.5: ok = false
		if ok:
			d = dd; break
	var foes: Array = []
	var dist := 5.0 if P.arch not in ["juggernaut", "bulwark", "thief"] else 3.2
	if what in ["r", "bonded"]: dist = 4.5
	for i in 2:
		var q := at + d * (dist + i * 1.6) + Vector3(-d.z, 0, d.x) * (i * 1.2 - 0.6)
		if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z) or absf(m.world.ground_at(q.x, q.z) - at.y) > 0.5:
			q = m.world.free_spot_near(q, [P.pos], 1.2, 0.5, 6.0)
		q.y = m.world.ground_at(q.x, q.z)
		var T: Hunter = m.make_hunter("D%d" % i, 7, ["medium", "heavy"][i], ["Rook", "Vale"][i], "idle", {}, q, {"arch": ["gunslinger", "juggernaut"][i]})
		T.max_hp = 5000.0; T.hp = T.max_hp
		T.face = atan2(d.x, d.z)
		T.lvl = [4, 7][i]
		foes.append(T)
	m.set_meta("demo_foes", foes)
	if OS.get_cmdline_user_args().has("--demo-debug"): print("ARCHDEMO setup at %s dir %s foes %s" % [str(at), str(d), str(foes.map(func(x): return x.pos))])
	if P.kin == null:
		var rec := Save.new_kin("wisplet" if what == "bonded" else "puddlet"); rec["trust"] = 90.0
		var k: Kin = m.give_kin(P, rec)
		k.state = "shoulder"; k.settle = 1.0
	if m.hud: m.hud.guide_hidden = true
	P.unlock_all()
	P.lvl = 7; P.xp = float(Hunter.XP_TO[6]) + 120.0; P.slot_lv["ult"] = 1; P.skill_pts = 0
	if what == "level":
		P.lvl = 5; P.xp = float(Hunter.XP_TO[5]) - 8.0; P.slot_lv["ult"] = 0; P.skill_pts = 1
		P.slot_lv["sec"] = 2; P.slot_lv["kin"] = 1
	P.ult = 0.4
	if P.ak:
		P.ak.res = P.ak.res_max() * 0.6
	if P.arch == "thief" and P.ak:
		(P.ak as ThiefKit).add_mark(foes[0], 2, true)
