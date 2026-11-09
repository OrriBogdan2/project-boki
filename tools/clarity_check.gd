extends RefCounted
## --clarity-check: the one colour rule and the downed picture. In a 2v2: your ring is the "you" colour,
## your teammate's the ally colour and both rivals' the foe colour, and every Boki's ring matches its
## Hunter's. With your teammate knocked: their bleed-out drains, their Boki's status icon says what it
## is doing (pulling them up, down too, defending) and only your squad's Boki get tethers. Never touches
## the save.

const DT := 1.0 / 60.0

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CLARITY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var P: Hunter = m.player
	var ally: Hunter = null
	var foes: Array = []
	for h in m.hunters:
		h.ctrl = "idle"
		if h != P and h.team == P.team: ally = h
		elif h.team != P.team: foes.append(h)
	ok(ally != null and foes.size() == 2, "a 2v2: one teammate, two rivals")
	_run(m, 0.2)
	# ---------------------------------------------------------------- 1. the colour rule
	ok(SideColor.of(m, P) == SideColor.YOU and SideColor.of(m, ally) == SideColor.ALLY, "you and your ally")
	ok(foes.all(func(f): return SideColor.of(m, f) == SideColor.FOE), "both rivals are the foe colour")
	ok(SideColor.of_team(P.team, (foes[0] as Hunter).team) != SideColor.of_team(P.team, P.team), "foe != ally")
	for h in m.hunters:
		var want := SideColor.of(m, h)
		var ring := h.model.get_node_or_null("TeamRing") as MeshInstance3D
		ok(_same(SideRings.shown(ring), want), "%s's ring is the %s colour" % [h.pname, _side(m, h)])
		if h.kin:
			ok(_same(SideRings.shown((h.kin as Kin).ring), want), "%s's Boki ring matches its Hunter" % h.pname)
			ok(SideColor.of(m, h.kin) == want, "%s's Boki takes its Hunter's colour" % h.pname)
	# ---------------------------------------------------------------- 2. the downed teammate
	ally.teleport(P.pos + Vector3(8.0, 0, 0))        # nobody in reach to pick them up: the bleed-out runs
	for f: Hunter in foes:
		f.teleport(P.pos + Vector3(-12.0, 0, 0))
	if ally.kin: (ally.kin as Kin).stow()
	m.knock(ally, foes[0], {})
	var f0 := DownedMarks.bleed_frac(ally)
	_run(m, 1.0)
	var f1 := DownedMarks.bleed_frac(ally)
	ok(f0 > 0.95 and f1 < f0, "the bleed-out drains (%.2f -> %.2f)" % [f0, f1])
	var k: Kin = ally.kin
	ok(k != null, "the downed teammate has a Boki")
	if k:
		k.state = "reviving"
		ok(BokiMarks.status(k) == "heart", "a Boki pulling its Hunter up shows the heart")
		k.state = "downed"
		ok(BokiMarks.status(k) == "knock", "a Boki down too shows the knock")
		k.state = "active"
		k.hp = k.max_hp
		k.target = foes[0]
		(foes[0] as Hunter).teleport(ally.pos + Vector3(1.0, 0, 0))
		ok(BokiMarks.status(k) == "fortify", "a Boki fighting someone over its Hunter shows the guard")
		k.target = null
		k.hp = k.max_hp * 0.05
		ok(BokiMarks.status(k) == "dash", "a badly hurt Boki hanging back shows the run")
	# ---------------------------------------------------------------- 3. tethers only for your squad
	var tethered := _tethered(m)
	ok(P.kin == null or P.kin.state == "shoulder" or tethered.has(P.kin), "your own Boki out: tethered to you")
	ok(k == null or tethered.has(k), "your downed teammate's Boki: tethered to them")
	for f: Hunter in foes:
		ok(f.kin == null or not tethered.has(f.kin), "%s's Boki: no tether" % f.pname)
	# ---------------------------------------------------------------- 4. crowd control on the plate, with time left
	_cc_plate(m, foes[0], foes[1])
	print("CLARITY done, %d failures" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A stunned and a slowed dummy, then Ground and Daze (one of them a remote body, as the Net "kst" event
## leaves it): one icon per kind, each with its time left, shrinking, and nothing when nothing is active.
func _cc_plate(m: Match, a: Hunter, b: Hunter) -> void:
	ok(HudPlate.statuses(a).is_empty() and HudPlate.statuses(b).is_empty(), "nothing active: no CC row")
	a.stun_t = 2.0
	b.slow_t = 3.0
	var sa := _icon(a, "concussion")
	var sb := _icon(b, "snare")
	var stun_ok: bool = sa.size() == 1 and absf(float(sa[0][3]) - 2.0) < 0.01 and sa[0][2] == "STUNNED"
	var slow_ok: bool = sb.size() == 1 and absf(float(sb[0][3]) - 3.0) < 0.01 and sb[0][2] == "SLOWED"
	ok(stun_ok, "stunned dummy: one STUNNED icon, 2.0 s left")
	ok(slow_ok, "slowed dummy: one SLOWED icon, 3.0 s left")
	_run(m, 1.0)
	var left := float(_icon(a, "concussion")[0][3])
	ok(left > 0.9 and left < 1.1, "the stun timer shrinks (%.2f s left after 1 s)" % left)
	a.root_t = 1.5
	KitStatus.apply(a, "gnd", 4.0, 0.0, false, "check")
	b.remote = true
	KitStatus.apply(b, "rat", 2.5, 0.0, false)
	b.remote = false
	var kinds: Array = HudPlate.statuses(a).map(func(x): return x[0])
	ok(kinds == ["concussion", "binding", "bolas"], "stun, root and Ground each get an icon, in order (%s)" % [kinds])
	var g := float(_icon(a, "bolas")[0][3])
	ok(g > 3.9 and g <= 4.0, "Ground shows its time left (%.2f s)" % g)
	var daze := _icon(b, "burst")
	var daze_ok: bool = daze.size() == 1 and float(daze[0][3]) > 2.4 and HudPlate.statuses(b).size() == 2
	ok(daze_ok, "a remote body's Daze and Slow: two icons, Daze 2.5 s left")
	a.stun_t = 0.0
	a.root_t = 0.0
	a.set_meta("gnd_until", 0.0)
	ok(HudPlate.statuses(a).is_empty(), "all over: the row is gone")
	var mob: Ent = null
	for mb in m.mobs:
		if not mb.dead: mob = mb
	if mob == null:
		mob = m.spawn_mob("skitter", a.pos + Vector3(4, 0, 0))
	if mob:   # the monster plate draws the same row (hud._status_row)
		mob.stun_t = 1.2
		var ms := _icon(mob, "concussion")
		ok(ms.size() == 1 and absf(float(ms[0][3]) - 1.2) < 0.01, "a stunned monster: STUNNED icon, 1.2 s left")
		mob.stun_t = 0.0

func _icon(e: Ent, icon: String) -> Array:
	return HudPlate.statuses(e).filter(func(x): return x[0] == icon)

func _run(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters: h.render(DT, 1.0)
		t += DT

## The Boki BokiMarks would tether, by the same rule it draws with (every Boki stood away from its Hunter).
func _tethered(m: Match) -> Array:
	var out: Array = []
	for k in m.kins:
		var h: Hunter = k.owner_h
		if h == null:
			continue
		k.state = "active"
		k.teleport(h.pos + Vector3(3.0, 0, 0))
		if BokiMarks.tethers(m, k):
			out.append(k)
	return out

func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.01

func _side(m: Match, h: Hunter) -> String:
	if h == m.player:
		return "you"
	return "ally" if h.team == m.player.team else "foe"
