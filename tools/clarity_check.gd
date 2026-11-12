extends RefCounted
## --clarity-check: the one colour rule and the downed picture. In a 2v2: your ring is the "you" colour,
## your teammate's the ally colour and both rivals' the foe colour, and every Boki's ring matches its
## Hunter's. With your teammate knocked: their bleed-out drains, their Boki's status icon says what it
## is doing (pulling them up, down too, defending) and only your squad's Boki get tethers. Never touches
## the save. Who and what on the body (docs/COMBAT_CLARITY.md): other Hunters' silhouettes carry their side's edge,
## other people's ability looks lean to their side (SideColor.fx), crowd control stays on the body it holds (stars,
## tendrils, frost and a pulsing tint, BodyTell) and a cast glints the caster. Less text: in a fight only your own
## Boki's lines are drawn, and a Boki's ability name floats over your own Boki only.

const ARCH_CHECK := preload("res://tools/archetype_check.gd")
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
	_sable_hit(main)
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
		var edge := SideRings.edge_of(h)
		var edge_ok := edge.a == 0.0 if h == P else (_same(edge, want) and edge.a > 0.5)
		ok(edge_ok, "%s's body edge: %s (%s)" % [h.pname, "none on yours" if h == P else _side(m, h), edge])
	_side_fx(m, P, ally, foes[0])
	_body_tell(m, foes[0])
	_boki_text(m, P, ally, foes[0])
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

## Sable's crossbow hits read on the struck body: it flashes in her violet for the hit's 3 full frames, then the
## flash is white again for the next Hunter's hit (the bolt's own starburst is content/vfx/thief.json, --hero-vfx-check).
func _sable_hit(main: Node) -> void:
	var a := ARCH_CHECK.new()
	a.main = main
	var r: Array = a.setup("thief", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var want := Arch.color("thief")
	P.fire_cd = 0.0
	var tinted := false
	var shown := Color.BLACK
	var t := 0.0
	while t < 1.2 and not tinted:
		P.inp["fire"] = true
		a.step(m, DT)
		T.render(DT, 1.0)
		tinted = T.flash_t > 0.0 and _same(T.flash_tint, want)
		if tinted and not T.mats.is_empty():
			shown = T.mats[0].get_shader_parameter("flash_color")
		t += DT
	P.inp["fire"] = false
	ok(tinted, "Sable's bolt hit: the struck body's flash is her violet")
	ok(_same(shown, want), "... and the shader draws it (%s)" % shown)
	a.step(m, 0.3)
	T.render(DT, 1.0)
	ok(_same(T.flash_tint, Color.WHITE), "the tint is white again once the flash ends")
	T.hurt(5.0, P, {})
	ok(_same(T.flash_tint, Color.WHITE) and T.flash_t > 0.0, "any other hit flashes white")
	m.queue_free()

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

## Other people's looks lean to their side: yours as made, a teammate's cooler, a rival's toward the hostile red.
func _side_fx(m: Match, P: Hunter, ally: Hunter, foe: Hunter) -> void:
	var c := Color("ffc832")
	ok(SideColor.fx(m, P, c) == c, "your own ability look keeps its colour")
	var a := SideColor.fx(m, ally, c)
	var f := SideColor.fx(m, foe, c)
	ok(a.b > c.b and a != c, "a teammate's look leans cool (%s)" % a)
	ok(f.r >= c.r and f.g < c.g, "a rival's look leans hostile (%s)" % f)
	var look := Oomph.shot_look(m, foe, c, 0.2)
	var halo := SideColor.fx(m, foe, (look[0] as Color).lightened(0.2))
	ok(_same(look[2], halo), "a rival's shot carries the hostile halo")

## Crowd control on a body, on the body: the props show while it lasts, the tint pulses its colour, all gone after;
## a cast glints the caster in their signature colour and fades.
func _body_tell(m: Match, f: Hunter) -> void:
	f.stun_t = 1.0
	_run(m, 0.1)
	var props := f.get_node_or_null("BodyTell") as Node3D
	ok(props != null and (props.get_node("Stun") as Node3D).visible, "a stunned body spins the stars")
	ok(_same(BodyTell.tint_of(f), BodyTell.STUN_COL), "... and pulses the stun colour")
	f.stun_t = 0.0
	f.root_t = 1.0
	_run(m, 0.3)
	var r := props.get_node("Root") as Node3D if props else null
	ok(r != null and r.visible and r.scale.y > 0.99, "a rooted body grows its tendrils")
	ok(_same(BodyTell.tint_of(f), BodyTell.ROOT_COL), "... and pulses the root colour")
	f.root_t = 0.0
	f.slow_t = 1.0
	f.stagger_t = 0.0
	_run(m, 0.05)
	ok(props != null and (props.get_node("Slow") as Node3D).visible, "a slowed body drips frost")
	f.slow_t = 0.0
	_run(m, 0.05)
	var none := props != null and not ((props.get_node("Stun") as Node3D).visible
			or (props.get_node("Root") as Node3D).visible or (props.get_node("Slow") as Node3D).visible)
	ok(none and BodyTell.tint_of(f).a == 0.0, "nothing holding it: nothing on the body")
	var rings0: int = m.fx.radial
	f.cast_at = m.time
	_run(m, DT)
	ok(_same(BodyTell.tint_of(f), Arch.color(f.arch)) and BodyTell.tint_of(f).a > 0.5,
		"a cast glints the caster in their colour")
	ok(m.fx.radial > rings0, "... and rings their feet")
	_run(m, BodyTell.GLINT_T)
	ok(BodyTell.tint_of(f).a == 0.0, "the glint fades")

## Boki text over a fight: every Boki's line is drawn out of a fight, only your own in one; an ability name floats
## over your own Boki, not a rival's.
func _boki_text(m: Match, P: Hunter, ally: Hunter, foe: Hunter) -> void:
	var mine: Kin = P.kin if P.kin else m.give_kin(P, Save.new_kin("puddlet"))
	ok(ally.kin != null and foe.kin != null, "your ally and the rival each have a Boki")
	if ally.kin == null or foe.kin == null:
		return
	m.music_dir.last_fight = -99.0
	ok(BokiChatter.heard(m, foe.kin) and BokiChatter.heard(m, ally.kin), "no fight: every Boki's line is drawn")
	m.music_dir.last_fight = m.time
	ok(BokiChatter.heard(m, mine), "in a fight: your own Boki's line is drawn")
	ok(not BokiChatter.heard(m, foe.kin) and not BokiChatter.heard(m, ally.kin), "... the others' are not")
	m.music_dir.last_fight = -99.0
	for k: Kin in [mine, foe.kin]:
		k.unseen = false
		k.teleport(P.pos + Vector3(6.0 if k == mine else -6.0, 0, 0))
	var words := func():
		return m.fx.nums.filter(func(n): return n.get("word", false) and float(n["t"]) == 0.0).size()
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
