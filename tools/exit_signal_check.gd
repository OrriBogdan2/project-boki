extends RefCounted
## --exit-signal-check: every exit reads from across the map (ExitSignal). The state mapping (idle,
## active, used, off) for each kind of exit; the beam and zone colours (kind colour when idle, the
## starter's team when active, the team standing on it when used); and, in a real match, that each exit
## has its sky beam and a ground zone as wide as the game's own radius, with no particle emitters
## added, and that a called dock goes idle -> active -> used -> closed on screen. Never touches the save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("EXITSIGNAL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _x(kind: String, state: String, extra := {}) -> Dictionary:
	var d := {"kind": kind, "state": state, "team": -1, "t": 0.0, "prog": 0.0}
	d.merge(extra, true)
	return d

func _emitters(n: Node) -> int:
	var k := 1 if (n is CPUParticles3D or n is GPUParticles3D) else 0
	for ch in n.get_children():
		k += _emitters(ch)
	return k

func _beam_color(x: Dictionary) -> Color:
	var beam := (x["node"] as Node3D).get_node("Signal/Beam") as MeshInstance3D
	return (beam.material_override as ShaderMaterial).get_shader_parameter("color")

func _mapping() -> void:
	var table := [
		[_x("dock", "idle"), -1, ExitSignal.IDLE], [_x("dock", "gone"), -1, ExitSignal.IDLE],
		[_x("dock", "closed"), -1, ExitSignal.OFF], [_x("dock", "closed"), 1, ExitSignal.OFF],
		[_x("dock", "called"), -1, ExitSignal.ACTIVE], [_x("dock", "boarding"), -1, ExitSignal.ACTIVE],
		[_x("dock", "boarding"), 1, ExitSignal.USED], [_x("dock", "idle"), 1, ExitSignal.IDLE],
		[_x("hatch", "sealed"), -1, ExitSignal.IDLE], [_x("hatch", "unlocking"), -1, ExitSignal.ACTIVE],
		[_x("hatch", "open"), -1, ExitSignal.ACTIVE], [_x("hatch", "open"), 0, ExitSignal.USED],
		[_x("outpost", "idle"), -1, ExitSignal.IDLE], [_x("outpost", "spent"), 0, ExitSignal.IDLE],
		[_x("outpost", "fizzling"), -1, ExitSignal.IDLE], [_x("outpost", "charging"), -1, ExitSignal.ACTIVE],
		[_x("outpost", "charging"), 2, ExitSignal.USED], [_x("outpost", "open"), -1, ExitSignal.ACTIVE],
		[_x("outpost", "open"), 0, ExitSignal.USED]]
	var wrong := table.filter(func(r): return ExitSignal.phase(r[0], r[1]) != r[2])
	ok(wrong.is_empty(),
			"the state mapping: %d of %d kind/state/occupant cases right" % [table.size() - wrong.size(), table.size()])
	ok(is_equal_approx(ExitSignal.left(_x("dock", "called", {"t": Exits.CALL_T * 0.25})), 0.25),
			"a called dock counts down from the call time")
	ok(is_equal_approx(ExitSignal.left(_x("outpost", "charging", {"prog": 0.7})), 0.3),
			"a charging uplink counts what is left to charge")
	ok(ExitSignal.left(_x("outpost", "open", {"t": 1e9})) == 1.0 and ExitSignal.left(_x("hatch", "open")) == 1.0,
			"no countdown: a tutorial lift and an open hatch stay full")

func _colors() -> void:
	var dock := _x("dock", "called", {"team": 1})
	var idle := ExitSignal.colors(_x("hatch", "sealed"), ExitSignal.IDLE, -1, 0.0)
	ok(Color(idle[0], 1.0) == ExitModels.HATCH and Color(idle[1], 1.0) == ExitModels.HATCH,
			"idle: the exit's own colour")
	var act := ExitSignal.colors(dock, ExitSignal.ACTIVE, -1, 1.0)
	ok(Color(act[0], 1.0) == ExitSignal.team_color(1), "active: the beam is the colour of the team that called it")
	var used := ExitSignal.colors(dock, ExitSignal.USED, 3, 0.0)
	ok(Color(used[0], 1.0) == ExitSignal.team_color(3) and Color(used[1], 1.0) == ExitSignal.team_color(3),
			"used: beam and zone in the colour of whoever stands on it")
	ok(idle[0].a < act[0].a and act[0].a < used[0].a and idle[1].a < act[1].a and act[1].a < used[1].a,
			"the beam and the zone get stronger idle < active < used")
	var held := _x("outpost", "charging", {"team": 0, "contested": true})
	var fight := ExitSignal.colors(held, ExitSignal.ACTIVE, -1, 1.0)
	ok(Color(fight[1], 1.0) == ExitSignal.CONTESTED, "a contested yard shows its zone in the contest colour")

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
	_mapping()
	_colors()
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
	var R: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	var far: Vector3 = m.exits.list[0]["pos"] + Vector3(80, 0, 80)
	var pins := {P: far, R: far + Vector3(5, 0, 5)}
	m.time = m.exits.list.reduce(func(a, x): return maxf(a, float(x.get("open_at", 0.0))), 0.0) + 1.0
	_step(m, 0.2, pins)
	var all_there := true
	var particles_in_signal := 0
	for x in m.exits.list:
		var n: Node3D = x["node"]
		all_there = all_there and n.get_node_or_null("Signal/Beam") != null and n.get_node_or_null("Zone") != null
		particles_in_signal += _emitters(n.get_node("Signal"))
	ok(all_there and not m.exits.list.is_empty(),
			"all %d exits have a sky beam and a ground zone" % m.exits.list.size())
	ok(particles_in_signal == 0, "the beam adds no particle emitters")
	var dock: Dictionary = m.exits.of_kind("dock")[0]
	var hatch: Dictionary = m.exits.of_kind("hatch")[0]
	var up: Dictionary = m.exits.of_kind("outpost")[0]
	var zd := func(x): return ((x["node"] as Node3D).get_node("Zone") as MeshInstance3D).mesh.size.x / 2.0
	var zones_ok := is_equal_approx(zd.call(hatch), Exits.HATCH_R) and is_equal_approx(zd.call(up), Exits.OUTPOST_R)
	zones_ok = zones_ok and is_equal_approx(zd.call(dock), Exits.DECK_R)
	ok(zones_ok, "each zone is as wide as the game's radius (deck %.1f, hatch %.1f, yard %.1f m)"
			% [zd.call(dock), zd.call(hatch), zd.call(up)])
	# ---------------------------------------------------------------- a dock through its states
	var sig := (dock["node"] as Node3D).get_node("Signal") as Node3D
	ok(dock["state"] == "idle" and sig.visible and is_equal_approx(sig.scale.y, ExitSignal.STUB_H / ExitSignal.SKY_H),
			"idle: a short stub marks the dock")
	m.exits._call(dock, P)
	_step(m, 0.3, pins)
	var beam_a := _beam_color(dock)
	ok(sig.scale.y >= 1.0 and is_equal_approx(sig.scale.x, ExitSignal.BEAM_R), "called: the full-height beam")
	ok(Color(beam_a, 1.0) == ExitSignal.team_color(P.team), "called: in the caller's team colour")
	pins[R] = dock["berth"]
	_step(m, 0.3, pins)
	dock["state"] = "boarding"
	dock["t"] = Exits.BOARD_T
	_step(m, 0.3, pins)
	var rival_col := Color(_beam_color(dock), 1.0) == ExitSignal.team_color(R.team)
	ok(is_equal_approx(sig.scale.x, ExitSignal.BEAM_R * 2.0) and rival_col,
			"a rival on the deck: thicker beam in the rival's colour")
	m.exits._close_dock(dock)
	_step(m, 0.1, pins)
	ok(not sig.visible and not ((dock["node"] as Node3D).get_node("Zone") as Node3D).visible,
			"a closed dock shows nothing")
	# ---------------------------------------------------------------- a hatch and an uplink
	var hn := hatch["node"] as Node3D
	ok(hatch["state"] == "sealed" and hn.get_node("Signal").scale.y < 1.0, "a sealed hatch: the stub")
	hatch["state"] = "unlocking"
	hatch["team"] = P.team
	hatch["t"] = 5.0
	_step(m, 0.1, pins)
	ok(hn.get_node("Signal").scale.y >= 1.0, "an unlocking hatch: the full beam")
	pins[P] = hatch["pos"]
	_step(m, 0.1, pins)
	var hatch_col := Color(_beam_color(hatch), 1.0) == ExitSignal.team_color(P.team)
	ok(hatch_col and hn.get_node("Signal").scale.x > ExitSignal.BEAM_R,
			"someone at the hatch: used")
	pins[P] = far
	m.exits._start(up, P)
	_step(m, 0.3, pins)
	var un := up["node"] as Node3D
	ok(un.get_node("Signal").scale.y >= 1.0 and is_equal_approx(un.get_node("Signal").scale.x, ExitSignal.BEAM_R),
			"a started uplink: the full beam, nobody in the yard")
	pins[P] = up["pos"] + Vector3(0.9, 0, 0.9)
	_step(m, 0.3, pins)
	ok(is_equal_approx(un.get_node("Signal").scale.x, ExitSignal.BEAM_R * 2.0), "the squad holds the yard: used")
	m.over = true
	m.queue_free()
	await main.get_tree().process_frame
	print("EXIT SIGNAL CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
