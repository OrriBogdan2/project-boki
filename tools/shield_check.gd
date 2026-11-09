extends RefCounted
## --shield-check: a shield never hides its Hunter. Every shield source (an ability's
## shield, an ally area, a Boki's Refraction and Mass Guard, the Bulwark's raised aegis, a Fuse release,
## the owner shield a Boki gives) is applied to a Hunter standing in front of a rival; after it settles
## every body mesh that was visible is still visible, the Hunter is still targetable and still seen by
## the rival, and the shield rim (ShieldFx) is on. With --shots-dir=<dir> (run under xvfb with a
## renderer) it also writes one crop per source. Never touches the save.

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
		ok(not ShieldFx.occludes(m, P), "%s: nothing opaque of the shield stands between camera and body" % src)
		if P.shield > 0.0:
			ok(ShieldFx.shown(P), "%s: the shield rim is on" % src)
		await _shot(main, m, P, src)
		_clear(m, P)
	P.shield = 0.0
	P.kin_shield = 0.0
	await _settle(main, m, P, 0.2)
	ok(not ShieldFx.shown(P), "no shield: the rim is off")
	await _shell_language(main, m, P, rival)
	print("SHIELDCHECK done, %d failures" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The shell's own language: it thins as the shield runs down, an absorbed hit ripples it (one ripple for a burst),
## and the hit that breaks it cracks the body and sheds shards with no ring.
func _shell_language(main: Node, m: Match, P: Hunter, rival: Hunter) -> void:
	P.shield = 40.0
	P.shield_t = 30.0
	await _settle(main, m, P, 0.1)
	ok(P.get_meta(ShieldFx.STEP) == ShieldFx.STEPS, "a full shield draws the full rim")
	var flashes0: int = m.fx.flashes.size()
	P.hurt(5.0, rival, {})
	ok(m.fx.flashes.size() == flashes0 + 1 and P.shield < 40.0, "a hit the shield takes ripples the shell")
	P.hurt(5.0, rival, {})
	ok(m.fx.flashes.size() == flashes0 + 1, "a burst of hits is one ripple")
	P.shield = 8.0
	await _settle(main, m, P, 0.2)
	ok(P.get_meta(ShieldFx.STEP) == 1, "a shield nearly spent draws the thinnest rim (%s of %s)" % [P.shield, P.get_meta(ShieldFx.PEAK)])
	await _settle(main, m, P, 0.2)
	var rings0: int = m.fx.rings.size()
	P.flash_t = 0.0
	P.hurt(30.0, rival, {})
	await _settle(main, m, P, DT)
	ok(P.shield <= 0.0 and not ShieldFx.shown(P), "a hit that breaks the shield takes the rim off")
	ok(P.flash_t > Juice.SHELL_FLASH_T and m.fx.rings.size() == rings0, "the break cracks the body: flash held, no ring")

func _settle(main: Node, m: Match, P: Hunter, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters: h.render(DT, 1.0)
		if m.verbs: m.verbs.render(1.0)
		m.cam.snap(P.pos)
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

func _shot(main: Node, m: Match, P: Hunter, label: String) -> void:
	if _dir == "":
		return
	await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	var vp := main.get_viewport()
	var c := vp.get_camera_3d().unproject_position(P.position + Vector3(0, 1.0, 0))
	c *= Vector2(img.get_size()) / vp.get_visible_rect().size
	var box := Rect2i(Vector2i(c) - Vector2i(240, 240), Vector2i(480, 480))
	var rg := box.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rg).save_png(_dir.path_join("shield_%s.png" % label.replace(" ", "_").to_lower()))
