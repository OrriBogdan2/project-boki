class_name ExtractWidgetCheck
extends RefCounted
## The extraction widget's states (ExtractWidget), run at the end of --extract-check: hidden while no exit is
## open, the nearest open exit's way and distance, how long it stays open, the progress and what cancels it
## while boarding or charging, and the box staying inside the safe area at every screen size.

const SIZES := [Vector2(1920, 1080), Vector2(1280, 720), Vector2(1024, 768), Vector2(800, 600)]

static var _bad := 0

static func _ok(cond: bool, what: String) -> void:
	print("EXWIDGET %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		_bad += 1

static func _fresh(main: Node) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for h in m.hunters:
		h.ctrl = "idle"
		h.max_hp = 5000.0
		h.hp = 5000.0
		if h != m.player:
			_park(m, h)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	return m

## Somewhere away from the exits (a spawn point), so an idle hunter never joins in.
static func _park(m: Match, h: Hunter) -> void:
	h.teleport(m.world.spawns[-1])

static func _run(m: Match, sec: float, at: Vector3) -> void:
	for i in int(sec / Match.DT):
		m.player.teleport(at)
		for h in m.hunters:
			if h.has_meta("pin"):
				h.teleport(h.get_meta("pin"))
		for mob in m.mobs:
			mob.dead = true
			mob.visible = false
		m.step(Match.DT)

static func _done(m: Match) -> void:
	m.over = true
	m.queue_free()

## True when every widget state held.
static func run(main: Node) -> bool:
	_bad = 0
	var m := _fresh(main)
	var P: Hunter = m.player
	_ok(ExtractWidget.state(m, P).is_empty(), "hidden while no exit is open")
	var dock: Dictionary = m.exits.of_kind("dock")[0]
	m.time = float(dock["open_at"]) + 1.0
	_far_exit(m, P)
	_boarding(m, P, dock)
	_done(m)
	m = _fresh(main)
	_uplink(m, m.player, m.exits.of_kind("outpost")[0])
	_done(m)
	m = _fresh(main)
	_hatch(m, m.player, m.exits.of_kind("hatch")[0])
	_done(m)
	_safe_area()
	print("EXWIDGET ", "PASS" if _bad == 0 else "FAIL")
	return _bad == 0

static func _far_exit(m: Match, P: Hunter) -> void:
	P.teleport(m.exits.of_kind("dock")[0]["pos"] + Vector3(12, 0, 0))
	var s := ExtractWidget.state(m, P)
	var nearest := {}
	for x in m.exits.list:
		if m.exits.live(x) and (nearest.is_empty() or P.flat_dist(x["pos"]) < P.flat_dist(nearest["pos"])):
			nearest = x
	_ok(not s.is_empty() and is_same(s["x"], nearest), "shows the nearest open exit")
	var at: Vector3 = nearest.get("berth", nearest["pos"])
	var to := Vector2(at.x - P.pos.x, at.z - P.pos.z)
	var seen := Vector2(sin(float(s["bearing"])), -cos(float(s["bearing"])))
	_ok(seen.distance_to(to.normalized()) < 0.01, "the arrow points at it (north up, east right)")
	_ok(absf(float(s["dist"]) - to.length()) < 0.01, "the distance is the flat distance")
	_ok(String(s["left"]).begins_with("Open for") and s["step"] != "" and float(s["prog"]) < 0.0,
		"open: how long, a next step, no bar")

static func _boarding(m: Match, P: Hunter, d: Dictionary) -> void:
	P.teleport(d["pos"] + Vector3(0.3, 0, 0.3))
	m.exits.act(d, "call", P)
	var s := ExtractWidget.state(m, P)
	_ok(is_same(s["x"], d) and String(s["left"]).begins_with("Skiff arrives in"),
		"a called skiff shows when it arrives")
	d["t"] = 0.05
	_run(m, 0.3, P.pos)
	_ok(d["state"] == "boarding", "the skiff is in (boarding)")
	_run(m, 0.3, d["pos"] + Vector3(-5, 0, 0))
	s = ExtractWidget.state(m, P)
	_ok(String(s["cancel"]) == "" and String(s["step"]).contains("Get on"),
		"ashore: told to get on the deck, nothing to cancel")
	_run(m, 1.0, d["berth"])
	var p0 := float(ExtractWidget.state(m, P)["prog"])
	_run(m, 3.0, d["berth"])
	s = ExtractWidget.state(m, P)
	_ok(float(s["prog"]) > p0 and String(s["left"]).begins_with("Leaves in"),
		"aboard: the bar fills, the departure counts down")
	_ok(String(s["cancel"]).contains("Step off the deck"), "aboard: says stepping off cancels it")

static func _uplink(m: Match, P: Hunter, o: Dictionary) -> void:
	m.time = float(o["open_at"]) + 1.0
	var yard: Vector3 = o["pos"] + Vector3(0, 0, 2.5)     # in the yard, outside the lift
	P.teleport(yard)
	m.exits.act(o, "start", P)
	_run(m, 5.0, yard)
	var s := ExtractWidget.state(m, P)
	_ok(is_same(s["x"], o) and absf(float(s["prog"]) - float(o["prog"])) < 0.001 and float(s["prog"]) > 0.0,
		"uplink: the bar is the uplink's charge")
	_ok(String(s["left"]).begins_with("Lift in") and String(s["cancel"]).contains("drains"),
		"uplink: lift time and what cancels it")
	var rival: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	rival.teleport(o["pos"] + Vector3(-1.6, 0, 1.0))
	rival.set_meta("pin", rival.pos)
	_run(m, 0.3, yard)
	_ok(String(ExtractWidget.state(m, P)["left"]).begins_with("Stalled"), "uplink: a rival in the yard stalls it")
	rival.remove_meta("pin")
	_park(m, rival)
	_run(m, 2.0, o["pos"] + Vector3(30, 0, 0))
	s = ExtractWidget.state(m, P)
	_ok(String(s["left"]).begins_with("Runs dry") and String(s["step"]).contains("yard"),
		"uplink: empty yard drains, told to go back")
	o["prog"] = 1.0
	_run(m, 0.3, yard)
	s = ExtractWidget.state(m, P)
	_ok(String(s["left"]).begins_with("Lift closes in") and String(s["step"]).contains("light"),
		"lift open: closes in, step into the light")

static func _hatch(m: Match, P: Hunter, h: Dictionary) -> void:
	P.teleport(h["pos"] + Vector3(20, 0, 0))
	_ok(ExtractWidget.state(m, P).is_empty(), "a sealed hatch without a key stays hidden")
	P.rift_keys = 1
	var s := ExtractWidget.state(m, P)
	_ok(not s.is_empty() and is_same(s["x"], h) and String(s["left"]).begins_with("Sealed"),
		"a key makes the sealed hatch an open exit")
	P.teleport(h["pos"] + Vector3(0.7, 0, 0.5))
	m.exits.act(h, "open", P)
	_run(m, 3.0, P.pos)
	s = ExtractWidget.state(m, P)
	_ok(String(s["left"]).begins_with("Opens in") and float(s["prog"]) > 0.0, "unlocking: opens in, the bar fills")
	h["t"] = 0.05
	_run(m, 0.3, h["pos"] + Vector3(3, 0, 0))
	_ok(String(ExtractWidget.state(m, P)["left"]) == "%d of %d drops left" % [Exits.HATCH_USES, Exits.HATCH_USES],
		"open: the drops left")
	P.extracted = true
	_ok(ExtractWidget.state(m, P).is_empty(), "hidden once you are out")

static func _safe_area() -> void:
	for sz: Vector2 in SIZES:
		var safe := ExtractWidget.safe_rect(sz)
		var inside := true
		for rows in [2, 4]:
			inside = inside and safe.encloses(ExtractWidget.box_rect(sz, rows))
		_ok(inside, "the box stays inside the safe area at %dx%d" % [int(sz.x), int(sz.y)])
