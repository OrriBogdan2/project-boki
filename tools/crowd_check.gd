extends RefCounted
## --crowd-check: what keeps a 40-hunter Hollow Crown (decision 0022) apart and cheap.
##   colours  every squad of a 40-solo match has its own team colour, no two closer than
##            Data.TEAM_COLOR_GAP in OKLab (the second twenty were deeper shades of the first, as
##            close as 0.028: two squads read as one)
##   napping  a camp with nobody within Mob.NAP_M sleeps, also with the sky ship or a high glider
##            straight over it (3D distance), and wakes at its next look once a Hunter walks up
##   models   a Warden's .glb scene is loaded once a session, not once per Hunter dressed in it (a
##            reload was ~70 ms, a 40-hunter build loaded it 40 times)

var fails := 0

func _ok(cond: bool, what: String) -> void:
	print("CROWD %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		fails += 1

static func oklab(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	var lm := 0.4122214708 * l.r + 0.5363325363 * l.g + 0.0514459929 * l.b
	var mm := 0.2119034982 * l.r + 0.6806995451 * l.g + 0.1073969566 * l.b
	var sm := 0.0883024619 * l.r + 0.2817188376 * l.g + 0.6299787005 * l.b
	lm = pow(lm, 1.0 / 3.0)
	mm = pow(mm, 1.0 / 3.0)
	sm = pow(sm, 1.0 / 3.0)
	return Vector3(0.2104542553 * lm + 0.7936177850 * mm - 0.0040720468 * sm,
		1.9779984951 * lm - 2.4285922050 * mm + 0.4505937099 * sm,
		0.0259040371 * lm + 0.7827717662 * mm - 0.8086757660 * sm)

func _colours() -> void:
	var cs: Array = Data.TEAM_COLORS
	_ok(cs.size() >= Data.MATCH_PLAYERS, "colours: %d for %d solos" % [cs.size(), Data.MATCH_PLAYERS])
	var worst := INF
	var pair := ""
	for i in cs.size():
		for j in range(i + 1, cs.size()):
			var d := oklab(cs[i]).distance_to(oklab(cs[j]))
			if d < worst:
				worst = d
				pair = "%d/%d" % [i, j]
	var gap := Data.TEAM_COLOR_GAP
	_ok(worst >= gap, "colours: closest pair %s at %.3f (gap %.2f)" % [pair, worst, gap])

func _napping(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 9, "no_drop": true})
	m.set_process(false)
	_ok(not m.mobs.is_empty(), "napping: the map has camps")
	if not m.mobs.is_empty():
		var mb: Mob = m.mobs[0]
		mb.st = "idle"
		mb.tgt = null
		mb.grounded = true
		var far := mb.pos + Vector3(Mob.NAP_M * 4.0, 0, 0)
		for e in m.hunters:
			e.pos = far
		for k in m.kins:
			k.pos = far
		mb._nap = 0.0
		_ok(mb._napping(0.01), "napping: alone, the camp sleeps")
		# the ship's deck height over it (SHIP_Y 70 m less ~10 m of ground)
		m.player.pos = mb.pos + Vector3(2.0, 60.0, 0.0)
		_ok(mb._napping(Mob.NAP_CHECK), "napping: the ship overhead does not wake it")
		m.player.pos = mb.pos + Vector3(4.0, 0.0, 0.0)
		_ok(not mb._napping(Mob.NAP_CHECK), "napping: a Hunter walking up wakes it at its next look")
	m.queue_free()
	await main.get_tree().process_frame

func _models() -> void:
	var arch := ""
	for a in Arch.ORDER:
		if WardenGlb.uses_model(a):
			arch = a
			break
	if arch == "":
		print("CROWD SKIP models: no Warden uses a .glb")
		return
	var built: Array = []
	for i in 2:
		var col: Color = Data.TEAM_COLORS[i]
		built.append(Models.hunter(Arch.weight(arch), col, Arch.signature(arch), "", PlayerLook.neutral(), arch))
	var sc: PackedScene = WardenGlb._scenes.get(WardenGlb.path(arch))
	_ok(sc != null and WardenGlb._scene(arch) == sc, "models: %s's scene loaded once for two Hunters" % arch)
	for n in built:
		(n as Node).free()

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_colours()
	_models()
	await _napping(main)
	print("CROWD DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)
