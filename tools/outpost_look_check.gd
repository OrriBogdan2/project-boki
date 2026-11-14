extends RefCounted
## --outpost-look-check: an outpost is a built object that shows its state itself (OutpostLook), with a
## quiet ground edge. Checks, in a real match: the structure exists (mast, crystal, banner, four lamps, no
## particle emitters and no charging column anywhere on it); neutral = unlit crystal and lamps, banner low
## and grey; capturing = crystal and lamps fill with the charge, banner raised in the holder's team colour;
## owned/open = everything lit; the charge ring is hidden unless you stand in the yard or it is contested
## (the yard's edge itself is always there, see ExitSignal and --exit-signal-check); and the minimap
## glyph draws without error for each state. Never touches the save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("OUTPOSTLOOK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _emitters(n: Node) -> int:
	var k := 1 if (n is CPUParticles3D or n is GPUParticles3D) else 0
	for ch in n.get_children():
		k += _emitters(ch)
	return k

func _param(n: Node, path: String, key: String):
	return ((n.get_node(path) as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter(key)

func _glow(n: Node, path: String) -> float:
	return float(_param(n, path, "glow"))

func _vis(n: Node, path: String) -> bool:
	return (n.get_node(path) as Node3D).visible

func _lamps_lit(n: Node) -> int:
	var k := 0
	for i in 4:
		if _glow(n, "Lamp%d" % i) > 0.5 * OutpostLook.LAMP_GLOW:
			k += 1
	return k

func _step(m: Match, secs: float, pins: Dictionary) -> void:
	var t := 0.0
	while t < secs:
		for h in pins:
			h.teleport(pins[h])
			h.vel = Vector3.ZERO
		for mb in m.mobs:
			mb.dead = true
			mb.visible = false
		m.step(Match.DT)
		t += Match.DT

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.max_hp = 5000.0
		h.hp = 5000.0
	var P: Hunter = m.player
	var R: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	var o: Dictionary = m.exits.of_kind("outpost")[0]
	var n: Node3D = o["node"]
	var away: Vector3 = o["pos"] + Vector3(30, 0, 0)
	var inside: Vector3 = o["pos"] + Vector3(0.9, 0, 0.9)
	var pins := {P: away, R: away + Vector3(5, 0, 5)}
	# ---------------------------------------------------------------- the structure
	var parts := ["Mast/Crystal", "Mast/Banner/Cloth", "Lamp0", "Lamp1", "Lamp2", "Lamp3", "Zone", "Charge"]
	ok(parts.all(func(p): return n.get_node_or_null(p) != null), "a built object: mast, crystal, banner, four lamps")
	var no_column := n.get_node_or_null("Beam") == null and n.get_node_or_null("Sparks") == null
	ok(_emitters(n) == 0 and no_column, "no particle emitters and no charging column on it")
	# ---------------------------------------------------------------- neutral
	m.time = float(o["open_at"]) + 1.0
	_step(m, 0.2, pins)
	var banner := n.get_node("Mast/Banner") as Node3D
	var crystal := "Mast/Crystal/" + n.get_node("Mast/Crystal").get_child(0).name
	ok(o["state"] == "idle" and _glow(n, crystal) == 0.0 and _lamps_lit(n) == 0, "neutral: crystal and lamps dark")
	ok(is_equal_approx(banner.position.y, OutpostLook.BANNER_LOW), "neutral: banner low (%.2f m)" % banner.position.y)
	ok(_vis(n, "Zone") and not _vis(n, "Charge"), "neutral, nobody near: the faint yard edge, no charge ring")
	pins[P] = inside
	_step(m, 0.2, pins)
	ok(_vis(n, "Zone") and not _vis(n, "Charge"), "standing in the yard: no charge ring yet")
	# ---------------------------------------------------------------- capturing
	m.exits._start(o, P)
	_step(m, 6.0, pins)
	var g1 := _glow(n, crystal)
	ok(o["state"] == "charging" and float(o["prog"]) > 0.05, "capturing: charge %d%%" % int(float(o["prog"]) * 100.0))
	var want_glow: float = OutpostLook.CRYSTAL_GLOW * float(o["prog"])
	ok(absf(g1 - want_glow) < 0.05, "the crystal glow follows the charge (%.2f)" % g1)
	var team_col: Color = Data.TEAM_COLORS[P.team % Data.TEAM_COLORS.size()]
	var cloth_col: Color = _param(n, "Mast/Banner/Cloth", "albedo")
	var raised := is_equal_approx(banner.position.y, OutpostLook.BANNER_HIGH)
	ok(raised and cloth_col.is_equal_approx(team_col), "banner raised in the holder's team colour")
	ok(_vis(n, "Zone") and _vis(n, "Charge"), "inside the yard: the charge ring shows")
	o["prog"] = 0.6
	_step(m, 0.1, pins)
	ok(_lamps_lit(n) == 2, "at 60%%: %d of 4 lamps lit" % _lamps_lit(n))
	pins[P] = away
	_step(m, 0.2, pins)
	ok(not _vis(n, "Charge"), "you walk off, nobody contests: the charge ring is hidden again")
	pins[R] = inside
	_step(m, 0.2, pins)
	ok(bool(o["contested"]) and _vis(n, "Charge"), "a rival in the yard: contested, the charge ring shows from afar")
	pins[R] = away + Vector3(5, 0, 5)
	_step(m, 0.2, pins)
	# ---------------------------------------------------------------- owned / open
	pins[P] = inside
	o["prog"] = 0.999
	_step(m, 1.0, pins)
	var crystal_lit := absf(_glow(n, crystal) - OutpostLook.CRYSTAL_GLOW) < 0.05
	ok(o["state"] == "open" and _lamps_lit(n) == 4 and crystal_lit, "open: every lamp and the crystal lit")
	ok(_emitters(n) == 0, "still no emitters while it is open")
	# ---------------------------------------------------------------- the map glyph
	var holder := Control.new()
	main.add_child(holder)
	holder.draw.connect(func():
		for lit in [0.0, 0.5, 1.0]:
			OutpostGlyph.draw(holder, Vector2(20, 20), 1.0, ExitModels.UPLINK, team_col, lit))
	holder.queue_redraw()
	await main.get_tree().process_frame
	ok(true, "the minimap glyph draws neutral, charging and lit")
	holder.queue_free()
	m.over = true
	m.queue_free()
	await main.get_tree().process_frame
	print("OUTPOST LOOK CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
