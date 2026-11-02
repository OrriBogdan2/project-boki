class_name HudRefDemo
extends RefCounted
## --hudref-demo=<plates|fight> (screenshots only): sets up the overhead plates and bottom HUD in
## known states so before/after pictures line up. Match calls tick() every step while the option is on.
##   plates: five rivals in a row in front of you, one per plate state (full; just hit, showing the
##           chip; armoured with a shield; low and slowed; downed), your abilities unlocked with one
##           cooling down. Everyone else stands still.
##   fight:  every hunter bunched up around you; after 4s they fight, so many plates overlap.

const HIT_AT := 2.2       # s of match time: the hit that leaves a chip lands this long before a 2.5s shot

static func tick(m) -> void:
	var mode := String(m.opts.get("hudref_demo", ""))
	if mode == "" or m.player == null or m.time < 0.05:
		return
	var P: Hunter = m.player
	if not m.has_meta("hudref_set"):
		m.set_meta("hudref_set", true)
		Settings.set_v("kin_chatter", "quiet", false)
		for mb in m.mobs: mb.dead = true; mb.visible = false
		P.lvl = 7; P.skill_pts = 0
		for s in P.slot_lv: P.slot_lv[s] = 1
		if mode == "plates": _plates(m, P)
		else: _fight(m, P)
	# (the pointer rests on open ground just under you: the camera doesn't lead and no hover card shows)
	var vp: Viewport = m.get_viewport()
	if vp: vp.warp_mouse(vp.get_visible_rect().size * 0.5 + Vector2(0, 120))
	for h in m.hunters:
		if h == P: continue
		if mode == "plates" or m.time < 4.0:
			h.ctrl = "idle"
			for k in h.inp: if h.inp[k] is bool: h.inp[k] = false
			h.inp["move"] = Vector2.ZERO
		else:
			h.ctrl = "bot"
	for k in m.kins:
		var kn: Kin = k
		if kn.owner_h == null and not kn.dead:
			kn.dead = true; kn.visible = false           # no wild Boki wandering into the picture
		elif kn.owner_h and kn.state != "shoulder":
			kn.stow()                                      # everyone's Boki rides their shoulder, out of the fight
	if mode == "plates":
		var hit: Hunter = m.get_meta("hudref_hit", null)
		if hit and m.time >= HIT_AT and not m.has_meta("hudref_hit_done"):
			m.set_meta("hudref_hit_done", true)
			hit.hurt(46.0, P)
		var st: Hunter = m.get_meta("hudref_stun", null)
		if st: st.slow_t = maxf(st.slow_t, 1.0)

static func _stand(m, h: Hunter, at: Vector3) -> void:
	var g: Vector3 = m.world.free_spot_near(at, [], 0.6, 0.5, 3.0)
	h.teleport(Vector3(g.x, m.world.ground_at(g.x, g.z), g.z))
	h.ctrl = "idle"; h.vel = Vector3.ZERO
	h.downed = false; h.hp = h.max_hp; h.armor = h.max_armor * 0.6; h.shield = 0.0

static func _plates(m, P: Hunter) -> void:
	var foes: Array = m.hunters.filter(func(x): return x != P)
	var base: Vector3 = P.pos
	for i in foes.size():
		var h: Hunter = foes[i]
		_stand(m, h, base + (Vector3((float(i) - 2.0) * 3.2, 0, -3.8) if i < 5 else Vector3((float(i) - 6.5) * 3.2, 0, 5.0)))
		h.lvl = 3 + i
	P.hp = P.max_hp * 0.62
	P.armor = P.max_armor * 0.5
	if P.ak and P.ak.cd.has("e"): P.ak.cd["e"] = 6.4
	if foes.size() < 5:
		return
	(foes[0] as Hunter).armor = 0.0                                      # full health, no armour
	m.set_meta("hudref_hit", foes[1])                                    # hit just before the picture
	(foes[2] as Hunter).armor = (foes[2] as Hunter).max_armor            # armoured, with a shield
	(foes[2] as Hunter).shield = 40.0; (foes[2] as Hunter).shield_t = 30.0
	(foes[3] as Hunter).hp = (foes[3] as Hunter).max_hp * 0.22           # low, and slowed
	(foes[3] as Hunter).armor = 0.0
	m.set_meta("hudref_stun", foes[3])
	m.knock(foes[4], P, {})                                              # downed

static func _fight(m, P: Hunter) -> void:
	var base: Vector3 = P.pos
	var i := 0
	for h in m.hunters:
		if h == P: continue
		var a := float(i) * 1.9
		_stand(m, h, base + Vector3(cos(a), 0, sin(a)) * (2.6 + 0.7 * float(i % 3)))
		h.lvl = 2 + i % 6
		if i % 3 == 1: h.hp = h.max_hp * 0.55
		if i % 4 == 2: h.armor = 0.0
		i += 1
	P.hp = P.max_hp * 0.3
