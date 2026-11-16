extends RefCounted
## --shield-check: a shield never hides its Hunter. Every shield source (an ability's
## shield, an ally area, a Boki's Refraction and Mass Guard, the Bulwark's raised aegis, a Fuse release,
## the owner shield a Boki gives) is applied to a Hunter standing in front of a rival; after it settles
## every body mesh that was visible is still visible, the Hunter is still targetable and still seen by
## the rival, and the shield rim (ShieldLook) is on. A shield a hit breaks (and the aegis) cracks (ShieldBreak) in
## the owner's ability colour with no burst or ring, at Low too, and is gone after its time; one that runs out
## doesn't crack. With --shots-dir=<dir> (run under xvfb with a renderer) it also writes one crop per source and
## the break at match zoom. Never touches the save.

const DT := 1.0 / 60.0
const SETTLE_S := 0.6        # s each shield runs before it is measured

var bad := 0
var _dir := ""

func ok(cond: bool, what: String) -> void:
	print("SHIELDCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): _dir = String(a).substr(12)
	if _dir != "": DirAccess.make_dir_recursive_absolute(_dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "arch": "bulwark",
		"cls": Arch.weight("bulwark"), "weapon": Arch.signature("bulwark")})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var P: Hunter = m.player
	P.ctrl = "idle"
	P.unlock_all()
	var rival: Hunter = null
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
			rival = o
	rival.teleport(P.pos + Vector3(0, 0, 4.0))
	rival.face = 0.0
	rival.inp["aim"] = P.pos + Vector3(0, 0.9, 0)
	P.inp["aim"] = rival.pos + Vector3(0, 0.9, 0)      # aiming down the screen, toward the camera: the worst case
	P.face = PI
	await _settle(main, m, P, 0.3)
	var meshes := _body_meshes(P)
	ok(not meshes.is_empty(), "the Hunter has %d visible body meshes" % meshes.size())
	await _shot(main, m, P, "none")
	var sources := {
		"ability shield": func(): Effects.run([{"type": "shield", "amount": 40.0, "time": 5.0}], P, {}),
		"ally area": func(): Effects.run([{"type": "ally_area", "shield": 30.0, "radius": 3.0}], P, {"at": P.pos}),
		"Boki Refraction": func(): _boki(m, P, "puddlet", "k2"),
		"Boki Mass Guard": func(): _boki(m, P, "pebbit", "k2"),
		"Fuse release": func(): MergeRelease.afterglow(P),
		"Boki owner shield": func(): P.kin_shield = 16.0,
		"Bulwark aegis": func(): _aegis(P),
	}
	# the icon the vitals strip leads with; Mass Guard is a plate in front of you (a wall), no pool on you
	var icons := {"ability shield": ShieldSrc.ITEM, "ally area": ShieldSrc.HEAL, "Boki Refraction": ShieldSrc.BOKI,
		"Boki Mass Guard": "none", "Fuse release": ShieldSrc.FUSE, "Boki owner shield": ShieldSrc.BOKI,
		"Bulwark aegis": ShieldSrc.ITEM}
	for src in sources:
		P.shield = 0.0
		P.shield_t = 0.0
		P.kin_shield = 0.0
		(sources[src] as Callable).call()
		await _settle(main, m, P, SETTLE_S)
		var hidden: Array = []
		for mi in meshes:
			if is_instance_valid(mi) and not (mi as MeshInstance3D).is_visible_in_tree():
				hidden.append(String((mi as Node).name))
		ok(hidden.is_empty() and P.model.visible, "%s: the body stays visible (hidden: %s)" % [src, hidden])
		ok(P.targetable() and P.cloak_t <= 0.0, "%s: still targetable, never cloaked" % src)
		ok(m.can_see(rival.team, P), "%s: the rival still sees the Hunter" % src)
		ok(not ShieldLook.occludes(m, P), "%s: nothing opaque of the shield stands between camera and body" % src)
		if P.shield > 0.0:
			ok(ShieldLook.shown(P), "%s: the shield rim is on" % src)
		var pools := ShieldStrip.pools(P)
		var lead := String(pools[0][1]) if not pools.is_empty() else "none"
		ok(lead == icons[src], "%s: the vitals strip shows it, icon %s (wanted %s)" % [src, lead, icons[src]])
		await _shot(main, m, P, src)
		_clear(m, P)
	P.shield = 0.0
	P.kin_shield = 0.0
	await _settle(main, m, P, 0.2)
	ok(not ShieldLook.shown(P), "no shield: the rim is off")
	ok(ShieldStrip.pools(P).is_empty(), "no shield: no strip")
	await _breaks(main, m, P, rival)
	print("SHIELDCHECK done, %d failures" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The break look: a hit through a shield cracks it, running out doesn't, Low keeps it, the aegis cracks the same.
func _breaks(main: Node, m: Match, P: Hunter, rival: Hunter) -> void:
	var sb := ShieldBreak.of(m)
	var pieces := ShieldBreak.SEGS + ShieldBreak.BRANCH + ShieldBreak.SHARDS
	var col := Arch.color(P.arch)
	sb.set_process(false)        # stepped with the match below
	for low in [false, true]:
		m.fx.particles = 0.0 if low else Fx.PARTICLES
		Effects.run([{"type": "shield", "amount": 40.0, "time": 5.0}], P, {})
		await _settle(main, m, P, 0.2)
		var n0 := sb.played
		P.hurt(P.shield + 5.0, rival, {})
		var radial0 := m.fx.radial      # (the hit's own sparks are made by now: only the break is counted)
		ShieldLook.tick(P)
		var tag := " (Low)" if low else ""
		ok(m.fx.radial == radial0, "no burst or ring on the break%s" % tag)
		await _settle(main, m, P, 0.1)
		var what := "a hit breaks the shield: it cracks once, %d pieces%s" % [sb.live, tag]
		ok(sb.played == n0 + 1 and sb.live == pieces, what)
		ok(sb.last_col == col, "the crack is in the owner's ability colour%s" % tag)
		if not low:
			await _shot(main, m, P, "break", true)
		await _settle(main, m, P, ShieldBreak.SHARD_S)
		ok(sb.live == 0, "the crack and shards are gone after %.2f s%s" % [ShieldBreak.SHARD_S, tag])
	m.fx.particles = Fx.PARTICLES
	P.shield_t = 0.0
	Effects.run([{"type": "shield", "amount": 40.0, "time": 0.3}], P, {})
	var n1 := sb.played
	await _settle(main, m, P, 0.6)
	ok(not ShieldLook.shown(P) and sb.played == n1, "a shield that runs out doesn't crack")
	_aegis(P)
	await _settle(main, m, P, 0.6)
	var wall: Dictionary = (P.ak as BulwarkKit).wall
	ok(not wall.is_empty(), "the raised aegis is up")
	var n2 := sb.played
	m.verbs.walls.erase(wall)
	await _settle(main, m, P, 0.1)
	ok(sb.played == n2 + 1 and sb.last_col == Arch.color("bulwark"), "a broken aegis cracks the same way")
	_clear(m, P)
	var n3 := sb.played
	sb.net_in(["fx", "sbrk", P.pos.x, 1.0, P.pos.z, 0.45, 0.8, col.to_html()])
	ok(sb.played == n3 + 1 and sb.last_col.to_html() == col.to_html(), "a break from another game plays here")

func _settle(main: Node, m: Match, P: Hunter, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters: h.render(DT, 1.0)
		if m.verbs: m.verbs.render(1.0)
		m.cam.snap(P.pos)
		ShieldBreak.of(m).step(DT)
		await main.get_tree().process_frame
		t += DT

func _body_meshes(P: Hunter) -> Array:
	var out: Array = []
	for mi in P.model.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).is_visible_in_tree():
			out.append(mi)
	return out

func _boki(m: Match, P: Hunter, species: String, slot: String) -> void:
	if P.kin:
		var o: Kin = P.kin
		o.dead = true
		o.visible = false
		P.kin = null
	var rec := Save.new_kin(species)
	rec["trust"] = 95.0
	var k := m.give_kin(P, rec)
	k.brain.think_t = 1e9
	k.runner.reset()
	k.teleport(P.pos + Vector3(0.6, 0, 1.0))
	k.state = "active"
	k.fly = {}
	k.settle = 0.0
	k.grounded = true
	k.use_ability(slot, P.pos)

func _aegis(P: Hunter) -> void:
	P.inp["sec"] = true
	P.inp["sec_hold"] = true

func _clear(m: Match, P: Hunter) -> void:
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	for w in m.verbs.walls.duplicate():
		w["t"] = 0.0
	for mr in m.verbs.mirrors:
		mr["t"] = 0.0

func _shot(main: Node, m: Match, P: Hunter, label: String, whole := false) -> void:
	if _dir == "":
		return
	await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	if whole:
		img.save_png(_dir.path_join("shield_%s_match_zoom.png" % label))
	var vp := main.get_viewport()
	var c := vp.get_camera_3d().unproject_position(P.position + Vector3(0, 1.0, 0))
	c *= Vector2(img.get_size()) / vp.get_visible_rect().size
	var box := Rect2i(Vector2i(c) - Vector2i(240, 240), Vector2i(480, 480))
	var rg := box.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rg).save_png(_dir.path_join("shield_%s.png" % label.replace(" ", "_").to_lower()))
