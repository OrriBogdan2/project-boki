extends RefCounted
## --clarity-check: the one colour rule and the downed picture. In a 2v2: your ring is the "you" colour,
## your teammate's the ally colour and both rivals' the foe colour, and every Boki's ring matches its
## Hunter's. With your teammate knocked: their bleed-out drains, their Boki rides on them as a wisp with
## no icon (one down itself shows the knock) and only your squad's Boki get tethers. Never touches the save.
## Who and what on the body (docs/COMBAT_CLARITY.md): other Hunters' silhouettes carry their side's edge,
## other people's ability looks lean to their side (SideColor.fx), crowd control stays on the body it holds (stars,
## tendrils, frost and a pulsing tint, BodyTell) and a cast glints the caster. Less text: in a fight only your own
## Boki's lines are drawn, and a Boki's ability name floats over your own Boki only. What sits on the Hunters in a bot
## 3v3 of the slice Hunters (ClarityFight, 10 frames) stays within ClarityFight.BUDGET.

const ARCH_CHECK := preload("res://tools/archetype_check.gd")
const ClarityFight := preload("res://tools/clarity_fight.gd")
const DT := 1.0 / 60.0
const FIGHT_FRAMES := 10
const WAYPOINT_AHEAD := 4.0  # m beside the player the check's waypoint stands: on screen, in the middle of the field
const MIN_SIDE_GAP := 0.5  # RGB distance (0-1) between two sides' colours that reads as different at a glance

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("CLARITY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_sable_hit(main)
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "demo_kin": "cindle"})
	m.set_process(false)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var p: Hunter = m.player
	var ally: Hunter = null
	var foes: Array = []
	for h in m.hunters:
		h.ctrl = "idle"
		if h != p and h.team == p.team:
			ally = h
		elif h.team != p.team:
			foes.append(h)
	ok(ally != null and foes.size() == 3, "a 3v3: a teammate, three rivals")
	_run(m, 0.2)
	# ---------------------------------------------------------------- 1. the colour rule
	ok(SideColor.of(m, p) == SideColor.you() and SideColor.of(m, ally) == SideColor.ally(), "you and your ally")
	ok(foes.all(func(f): return SideColor.of(m, f) == SideColor.foe()), "every rival is the foe colour")
	ok(SideColor.of_team(p.team, (foes[0] as Hunter).team) != SideColor.of_team(p.team, p.team), "foe != ally")
	for h in m.hunters:
		var want := SideColor.of(m, h)
		var ring := h.model.get_node_or_null("TeamRing") as MeshInstance3D
		ok(_same(SideRings.shown(ring), want), "%s's ring is the %s colour" % [h.pname, _side(m, h)])
		if h.kin:
			ok(_same(SideRings.shown((h.kin as Kin).ring), want), "%s's Boki ring matches its Hunter" % h.pname)
			ok(SideColor.of(m, h.kin) == want, "%s's Boki takes its Hunter's colour" % h.pname)
		var edge := SideRings.edge_of(h)
		var edge_ok := edge.a == 0.0 if h == p else (_same(edge, want) and edge.a > 0.5)
		ok(edge_ok, "%s's body edge: %s (%s)" % [h.pname, "none on yours" if h == p else _side(m, h), edge])
	_boki_owner(m, p, ally, foes[0])
	_side_fx(m, p, ally, foes[0])
	_body_tell(m, foes[0])
	_boki_text(m, p, ally, foes[0])
	_melee_stack(m, p, ally, foes)
	_quiet_own(m, p, ally, foes[0])
	# ---------------------------------------------------------------- 2. the downed teammate
	ally.teleport(p.pos + Vector3(8.0, 0, 0))  # nobody in reach to pick them up: the bleed-out runs
	for f: Hunter in foes:
		f.teleport(p.pos + Vector3(-12.0, 0, 0))
	if ally.kin:
		(ally.kin as Kin).stow()
	m.knock(ally, foes[0], {})
	var f0 := DownedMarks.bleed_frac(ally)
	_run(m, 1.0)
	var f1 := DownedMarks.bleed_frac(ally)
	ok(f0 > 0.95 and f1 < f0, "the bleed-out drains (%.2f -> %.2f)" % [f0, f1])
	var k: Kin = ally.kin
	ok(k != null, "the downed teammate has a Boki")
	if k:
		ok(
			k.state != KinWispForm.STATE,
			"a Boki on the shoulder at the knock is no guardian: it stays put (%s)" % k.state
		)
		k.state = KinWispForm.STATE  # (a guardian's ride: summoned at the knock)
		ok(BokiMarks.status(k) == "", "its Boki rides on it as a wisp: no icon over it")
		k.state = "downed"
		ok(BokiMarks.status(k) == "knock", "a Boki down too shows the knock")
		k.state = KinWispForm.STATE
	# ---------------------------------------------------------------- 3. tethers only for your squad
	var tethered := _tethered(m)
	ok(p.kin == null or p.kin.state == "shoulder" or tethered.has(p.kin), "your own Boki out: tethered to you")
	ok(k == null or not tethered.has(k), "your downed teammate's Boki rides on them as a wisp: no tether")
	for f: Hunter in foes:
		ok(f.kin == null or not tethered.has(f.kin), "%s's Boki: no tether" % f.pname)
	# ---------------------------------------------------------------- 4. crowd control on the plate, with time left
	_cc_plate(m, foes[0], foes[1])
	m.queue_free()
	await main.get_tree().process_frame
	await _fight_budget(main)
	await _waypoint_words(main)
	print("CLARITY done, %d failures" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## Sable's crossbow hits read on the struck body: it flashes in her colour for the hit's 3 full frames, then the
## flash is white again for the next Hunter's hit.
func _sable_hit(main: Node) -> void:
	var a := ARCH_CHECK.new()
	a.main = main
	var r: Array = a.setup("thief", 6.0)
	var m: Match = r[0]
	var shooter: Hunter = r[1]
	var target: Hunter = r[2]
	var want := Arch.color("thief")
	shooter.fire_cd = 0.0
	var tinted := false
	var shown := Color.BLACK
	var t := 0.0
	while t < 1.2 and not tinted:
		shooter.inp["fire"] = true
		a.step(m, DT)
		target.render(DT, 1.0)
		tinted = target.flash_t > 0.0 and _same(target.flash_tint, want)
		if tinted and not target.mats.is_empty():
			shown = target.mats[0].get_shader_parameter("flash_color")
		t += DT
	shooter.inp["fire"] = false
	ok(tinted, "Sable's bolt hit: the struck body's flash is her colour")
	ok(_same(shown, want), "... and the shader draws it (%s)" % shown)
	a.step(m, 0.3)
	target.render(DT, 1.0)
	ok(_same(target.flash_tint, Color.WHITE), "the tint is white again once the flash ends")
	m.queue_free()


## A world waypoint in the middle of the field: its words ("Your ping  ·  5m") are drawn out of a fight and none are
## in one (a bare pin); both come back once the fight is over. Counted by the "waypoint_text" rects the HUD notes.
func _waypoint_words(main: Node) -> void:
	var words := func(m: Match) -> int:
		SafeArea.seen.clear()
		SafeArea.recording = true
		m.hud.c.queue_redraw()
		m.hud.panels.queue_redraw()
		await main.get_tree().process_frame
		SafeArea.recording = false
		return (SafeArea.seen.get("waypoint_text", []) as Array).size()
	var check := func(m: Match, _i: int) -> void:
		var p: Hunter = m.player
		p.hurt_at = -99.0
		for h: Hunter in m.hunters:
			h.combat_at = -99.0
		m.hud.reticle.dealt_at = -99.0
		var at := p.pos + Vector3(WAYPOINT_AHEAD, 0, 0)
		m.pings.append({"pos": at, "by": p, "team": p.team, "col": Color.WHITE, "t": 0.0, "life": 1e9})
		var calm: int = await words.call(m)
		ok(calm > 0, "no fight: the mid-field waypoint carries its words (%d)" % calm)
		p.combat_at = m.time
		var fight: int = await words.call(m)
		ok(fight == 0, "in a fight: waypoint text inside the field is gone (%d, was %d)" % [fight, calm])
		p.combat_at = -99.0
		ok(await words.call(m) > 0, "the fight is over: the waypoint words come back")
	var fm: Match = await ClarityFight.play(main, ClarityFight.FIGHTS[0], 1, check)
	fm.queue_free()


## The first ClarityFight fight: each BUDGET entry's element-Hunter pairs a frame, on average, within its budget.
func _fight_budget(main: Node) -> void:
	var pairs := {}
	var count := func(fm: Match, _i: int) -> void:
		for e in ClarityFight.tally(fm):
			var k := "%s %s" % [e[0], e[1]]
			for b: String in ClarityFight.BUDGET:
				if k.begins_with(b):
					pairs[b] = int(pairs.get(b, 0)) + int(e[2])
	var fm: Match = await ClarityFight.play(main, ClarityFight.FIGHTS[0], FIGHT_FRAMES, count)
	for b: String in ClarityFight.BUDGET:
		var per := float(pairs.get(b, 0)) / FIGHT_FRAMES
		var cap := float(ClarityFight.BUDGET[b])
		ok(per <= cap, "3v3 fight: '%s' on a Hunter %.1f a frame (budget %.1f)" % [b, per, cap])
	fm.queue_free()


## A stunned and a slowed dummy, then Ground and Daze (one of them a remote body, as the Net "kst" event
## leaves it): one icon per kind, each with its time left, shrinking, and nothing when nothing is active.
func _cc_plate(m: Match, a: Hunter, b: Hunter) -> void:
	ok(HudPlate.statuses(a).is_empty() and HudPlate.statuses(b).is_empty(), "nothing active: no CC row")
	a.stun_t = 2.0
	b.slow_t = 3.0
	var sa := _icon(a, "status_stunned")
	var sb := _icon(b, "status_slowed")
	var stun_ok: bool = sa.size() == 1 and absf(float(sa[0][3]) - 2.0) < 0.01 and sa[0][2] == "STUNNED"
	var slow_ok: bool = sb.size() == 1 and absf(float(sb[0][3]) - 3.0) < 0.01 and sb[0][2] == "SLOWED"
	ok(stun_ok, "stunned dummy: one STUNNED icon, 2.0 s left")
	ok(slow_ok, "slowed dummy: one SLOWED icon, 3.0 s left")
	_run(m, 1.0)
	var left := float(_icon(a, "status_stunned")[0][3])
	ok(left > 0.9 and left < 1.1, "the stun timer shrinks (%.2f s left after 1 s)" % left)
	a.root_t = 1.5
	KitStatus.apply(a, "gnd", 4.0, 0.0, false, "check")
	b.remote = true
	KitStatus.apply(b, "rat", 2.5, 0.0, false)
	b.remote = false
	var kinds: Array = HudPlate.statuses(a).map(func(x): return x[0])
	var in_order := kinds == ["status_stunned", "status_rooted", "status_grounded"]
	ok(in_order, "stun, root and Ground each get an icon, in order (%s)" % [kinds])
	var g := float(_icon(a, "status_grounded")[0][3])
	ok(g > 3.9 and g <= 4.0, "Ground shows its time left (%.2f s)" % g)
	var daze := _icon(b, "status_dazed")
	var daze_ok: bool = daze.size() == 1 and float(daze[0][3]) > 2.4 and HudPlate.statuses(b).size() == 2
	ok(daze_ok, "a remote body's Daze and Slow: two icons, Daze 2.5 s left")
	a.stun_t = 0.0
	a.root_t = 0.0
	a.set_meta("gnd_until", 0.0)
	ok(HudPlate.statuses(a).is_empty(), "all over: the row is gone")
	var mob: Ent = null
	for mb in m.mobs:
		if not mb.dead:
			mob = mb
	if mob == null:
		mob = m.spawn_mob("skitter", a.pos + Vector3(4, 0, 0))
	if mob:  # the monster plate draws the same row (hud._status_row)
		mob.stun_t = 1.2
		var ms := _icon(mob, "status_stunned")
		ok(ms.size() == 1 and absf(float(ms[0][3]) - 1.2) < 0.01, "a stunned monster: STUNNED icon, 1.2 s left")
		mob.stun_t = 0.0


## Whose Boki is it, walking or riding as a wisp: the ring and the wisp's rim are the owner's side colour, and your
## own, a teammate's and a rival's are three clearly different colours (--wisp-read-shots measures it on screen).
func _boki_owner(m: Match, p: Hunter, ally: Hunter, foe: Hunter) -> void:
	var rims: Array = []
	for h: Hunter in [p, ally, foe]:
		var k: Kin = h.kin
		if k == null:
			ok(false, "%s has a Boki to read" % h.pname)
			continue
		var was := k.state
		KinWisp.set_wisp(k, true)
		k.state = "shoulder"
		KinWisp.render(k)
		var rim: Color = (k.model.get_node("Body") as GeometryInstance3D).get_instance_shader_parameter("rim_col")
		rims.append(rim)
		ok(_same(rim, SideColor.of(m, h)), "%s's wisp rim is the %s colour" % [h.pname, _side(m, h)])
		KinWisp.set_wisp(k, false)
		k.state = was
		k.ring.visible = true
	for i in rims.size():
		var a: Color = rims[i]
		var b: Color = rims[(i + 1) % rims.size()]
		var gap := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
		ok(gap > MIN_SIDE_GAP, "own, ally and rival Boki read three ways (gap %.2f)" % gap)


## Other people's looks lean to their side: yours as made, a teammate's cooler, a rival's toward the hostile red.
func _side_fx(m: Match, p: Hunter, ally: Hunter, foe: Hunter) -> void:
	var c := Color("ffc832")
	ok(SideColor.fx(m, p, c) == c, "your own ability look keeps its colour")
	var a := SideColor.fx(m, ally, c)
	var f := SideColor.fx(m, foe, c)
	ok(a.b > c.b and a != c, "a teammate's look leans cool (%s)" % a)
	ok(f.r >= c.r and f.g < c.g, "a rival's look leans hostile (%s)" % f)
	var look := Oomph.shot_look(m, foe, c, 0.2)
	var halo := SideColor.fx(m, foe, (look[0] as Color).lightened(0.2))
	ok(_same(look[2], halo), "a rival's shot carries the hostile halo")


## A 3v3 melee, every Boki out, all of them piled on one spot: ownership rings are thin and sit under every cast, a
## rival's telegraph on top of yours on top of a teammate's, one full-strength fill under a body, and the rings
## fade while a telegraph covers them and come back after (docs/COMBAT_CLARITY.md, "Ground order").
func _melee_stack(m: Match, p: Hunter, ally: Hunter, foes: Array) -> void:
	var at := p.pos
	for h: Hunter in m.hunters:
		h.teleport(at + Vector3(0.4 * float(m.hunters.find(h) % 3), 0, 0.4 * float(int(m.hunters.find(h) / 3.0))))
		if h.kin:
			(h.kin as Kin).state = "active"
			(h.kin as Kin).teleport(h.pos + Vector3(0.3, 0, 0))
	_run(m, 0.1)
	m.fx.rings.clear()
	for n: Node3D in m.fx.teles.duplicate():
		m.fx.end_telegraph(n)
	var ground := func() -> void:
		for h: Hunter in m.hunters:
			SideRings.tick(h)
	ground.call()
	var rings: Array = []
	for h: Hunter in m.hunters:
		rings.append(h.model.get_node_or_null("TeamRing"))
		if h.kin:
			rings.append((h.kin as Kin).ring)
	var base := (rings[0] as MeshInstance3D).material_override as ShaderMaterial
	var full_a := SideRings.YOU_A
	ok(rings.size() == 12, "a 3v3 melee with every Boki out: 12 ownership rings (%d)" % rings.size())
	var thin := is_equal_approx(float(base.get_shader_parameter("thickness")), SideRings.THIN)
	ok(thin, "an ownership ring is the thinnest band")
	ok(rings.all(func(r): return _prio(r) == SideColor.ORDER_RING), "ownership rings draw under every cast")
	ok(is_equal_approx(SideRings.shown(rings[0]).a, full_a), "no telegraph: your ring is full strength")
	var mine := _tele(m, p, at)
	var theirs := _tele(m, foes[0], at)
	var mates := _tele(m, ally, at)
	m.fx.stack_telegraphs()
	var ordered := _prio(theirs) > _prio(mine) and _prio(mine) > _prio(mates) and _prio(mates) > SideColor.ORDER_RING
	ok(ordered, "draw order: rival over yours over a teammate's over the rings")
	var full := m.fx.teles.filter(func(n): return _alpha(n) > 0.8)
	ok(full == [theirs], "one full-strength fill under the pile: the rival's (%d)" % full.size())
	AbilityFx.land(m, foes[1], at, 2.0, Color.ORANGE)
	var landed: bool = not m.fx.rings.is_empty() and _prio(m.fx.rings[0]["node"]) == SideColor.ORDER_FOE
	ok(landed, "a rival's landing ring is on the rival tier")
	ground.call()
	ok(rings.all(func(r): return SideRings.shown(r).a < 0.3), "every ownership ring is faded under the telegraphs")
	_aim_order(m, p, foes[0])
	for n: Node3D in [mine, theirs, mates]:
		m.fx.end_telegraph(n)
	m.fx.rings.clear()
	ground.call()
	ok(is_equal_approx(SideRings.shown(rings[0]).a, full_a), "the ring is back at full strength with the ground clear")


func _tele(m: Match, by: Hunter, at: Vector3) -> Node3D:
	var col := Color(SideColor.fx(m, by, Color.CYAN), 0.9)
	return m.fx.telegraph_circle(at, 3.0, col, SideColor.order(m, by))


func _prio(n: Node3D) -> int:
	return (n.material_override as ShaderMaterial).render_priority


func _alpha(n: Node3D) -> float:
	return (n.material_override as ShaderMaterial).get_shader_parameter("color").a


## Yours and a teammate's telegraphs are a faint rim (no hatching, no lace crossing), a rival's the strong one: the
## same warning on the ground (Fx) and as an AimKit laced lane (docs/COMBAT_CLARITY.md, "Own telegraphs are quiet").
func _quiet_own(m: Match, p: Hunter, ally: Hunter, foe: Hunter) -> void:
	var quiet := func(by: Hunter) -> float:
		var n := _tele(m, by, p.pos)
		var q: float = (n.material_override as ShaderMaterial).get_shader_parameter("quiet")
		m.fx.end_telegraph(n)
		return q
	ok(quiet.call(p) == 1.0 and quiet.call(ally) == 1.0, "your and a teammate's ground telegraph is quiet")
	ok(quiet.call(foe) == 0.0, "a rival's ground telegraph is the strong one")
	var verts := func(by: Hunter, lace: bool) -> int:
		AimKit.lane(by, "lace", {"all": true, "len": 6.0, "width": 0.5, "fill": 0.8, "lace": lace, "chevrons": 2})
		var d := AimKit.layer(m)
		d.rebuild()
		var n: int = d.geo.v.size()
		AimKit.clear(by)
		return n
	var own: int = verts.call(p, true)
	var foe_laced: int = verts.call(foe, true)
	var foe_plain: int = verts.call(foe, false)
	ok(own < foe_laced, "AimKit: your laced lane is drawn plain (%d vertices, a rival's %d)" % [own, foe_laced])
	ok(own < foe_plain, "AimKit: your lane has no chevrons (%d vertices, a rival's plain %d)" % [own, foe_plain])


## AimKit draws a rival's telegraph in its own surface after yours.
func _aim_order(m: Match, p: Hunter, foe: Hunter) -> void:
	AimKit.circle(p, "own", {"all": true, "at": p.pos, "r": 3.0})
	AimKit.circle(foe, "rival", {"all": true, "at": p.pos, "r": 3.0})
	var d := AimKit.layer(m)
	d.rebuild()
	var n := d.mesh.get_surface_count()
	ok(n == 2, "AimKit: yours and a rival's draw as two surfaces (%d)" % n)
	ok(d.mat_foe.render_priority > d.mat.render_priority, "AimKit: the rival's surface draws after yours")
	ok(d.covers(p.pos), "AimKit: the pile counts as covered")
	AimKit.clear(p)
	AimKit.clear(foe)


## Crowd control on a body, on the body: its look (StatusLooks) shows while it lasts, the tint pulses its colour, all
## gone after;
## a cast glints the caster in their signature colour and fades.
func _body_tell(m: Match, f: Hunter) -> void:
	var looks := StatusLooks.of(m)
	Sfx.listener = f.pos  # (StatusLooks draws near the camera focus only)
	f.stun_t = 1.0
	_run(m, 0.1)
	ok(looks.showing(f, "stun"), "a stunned body spins the stars")
	ok(_same(BodyTell.tint_of(f), BodyTell.STUN_COL), "... and pulses the stun colour")
	f.stun_t = 0.0
	f.root_t = 1.0
	_run(m, 0.3)
	ok(looks.showing(f, "root"), "a rooted body shows the stakes at its feet")
	ok(_same(BodyTell.tint_of(f), BodyTell.ROOT_COL), "... and pulses the root colour")
	f.root_t = 0.0
	f.slow_t = 1.0
	f.stagger_t = 0.0
	_run(m, 0.05)
	ok(looks.showing(f, "slow"), "a slowed body shows the rings down its legs")
	f.slow_t = 0.0
	_run(m, 0.05)
	var none := not (looks.showing(f, "stun") or looks.showing(f, "root") or looks.showing(f, "slow"))
	ok(none and BodyTell.tint_of(f).a == 0.0, "nothing holding it: nothing on the body")
	var rings0: int = m.fx.radial
	f.cast_at = m.time
	_run(m, DT)
	ok(
		_same(BodyTell.tint_of(f), Arch.color(f.arch)) and BodyTell.tint_of(f).a > 0.5,
		"a cast glints the caster in their colour"
	)
	ok(m.fx.radial > rings0, "... and rings their feet")
	_run(m, BodyTell.GLINT_T)
	ok(BodyTell.tint_of(f).a == 0.0, "the glint fades")


## Boki text over a fight: every Boki's line is drawn out of a fight, only your own in one; an ability name floats
## over your own Boki, not a rival's.
func _boki_text(m: Match, p: Hunter, ally: Hunter, foe: Hunter) -> void:
	var mine: Kin = p.kin if p.kin else m.give_kin(p, Save.new_kin("puddlet"))
	ok(ally.kin != null and foe.kin != null, "your ally and the rival each have a Boki")
	if ally.kin == null or foe.kin == null:
		return
	p.combat_at = -99.0
	ally.combat_at = -99.0
	ok(BokiChatter.heard(m, foe.kin) and BokiChatter.heard(m, ally.kin), "no fight: every Boki's line is drawn")
	p.combat_at = m.time
	ok(BokiChatter.heard(m, mine), "in a fight: your own Boki's line is drawn")
	ok(not BokiChatter.heard(m, foe.kin) and not BokiChatter.heard(m, ally.kin), "... the others' are not")
	ok(not BokiChatter.calm(m), 'in a fight: no Boki callout pins ("Behind you!") over the field')
	p.combat_at = -99.0
	ok(BokiChatter.calm(m), "no fight: callout pins are drawn")
	ally.combat_at = m.time
	ok(not BokiChatter.calm(m) and not BokiChatter.heard(m, foe.kin), "squadmate fights: no pins or others' lines")
	ally.combat_at = -99.0
	for k: Kin in [mine, foe.kin]:
		k.unseen = false
		k.teleport(p.pos + Vector3(6.0 if k == mine else -6.0, 0, 0))
	var words := func(): return m.fx.nums.filter(func(n): return n.get("word", false) and float(n["t"]) == 0.0).size()
	var w0: int = words.call()
	m.on_kin_ability(foe.kin, (foe.kin as Kin).runner.def_of("k1"), false)
	ok(words.call() == w0, "a rival's Boki casting: no name over it")
	m.on_kin_ability(mine, mine.runner.def_of("k1"), false)
	ok(words.call() == w0 + 1, "your own Boki casting: its name floats")
	mine.stow()


func _icon(e: Ent, icon: String) -> Array:
	return HudPlate.statuses(e).filter(func(x): return x[0] == icon)


func _run(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters:
			h.render(DT, 1.0)
		t += DT


## The Boki BokiMarks would tether, by the same rule it draws with (every Boki stood away from its Hunter).
func _tethered(m: Match) -> Array:
	var out: Array = []
	for k in m.kins:
		var h: Hunter = k.owner_h
		if h == null:
			continue
		if k.state != KinWispForm.STATE:  # (a downed Hunter's Boki stays in its wisp form)
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
