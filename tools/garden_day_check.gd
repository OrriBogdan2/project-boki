extends RefCounted
## --garden-day-check: a 20-minute garden day, headless and time-scaled (0.25 s of farm time a step, no frames).
## Bramblebank with six Boki, the three toys and the snack patch; then the hub with the partner who comes along
## (nobody lives there, GARDEN.md 10.1). Fails on: a Boki that visited fewer than MIN_STATES base-life states,
## stayed in one non-Nap state over STATE_MAX s, stood still STILL_MAX s off a nav point (its goal, a toy, its
## feeder or a place it is meant to rest), fell out of the zone, or a part over GARDEN.md 10.6's budget as far
## as a headless run can read it: nodes, emitting particle systems, and the script cost of a frame and of a
## 10 Hz base-life step (draws, objects and the GPU frame are --perf-bench --bench-zone=all). Never touches the
## real save.

const NavCheck := preload("res://tools/garden_nav_check.gd")
const DAY_SECS := 1200.0  # s of game time: a 20-minute garden day
const DT := 0.25  # s of farm time per step
const FRAME_EVERY := 400  # steps between frames
const FRAME := 1.0 / 60.0  # s: the frame the budget's script cost is timed at
const FRAMES := 300  # frames timed for the budget
const MIN_STATES := 4  # base-life states every Boki has to visit in the day
const STATE_MAX := 90.0  # s in one state other than Nap
const STILL_MAX := 20.0  # s without moving off a nav point
const PROGRESS := 0.12  # m moved in STILL_MAX s that counts as not still
const AT_POINT := 1.5  # m from its goal: it has arrived on a nav point
const FALL_Y := -2.0  # m: a Boki lower than this has fallen through the island
const SEED := 11
const DAY_START := 0.3  # the farm clock at the start (morning)

var bad := 0
var main: Node
var home
var nav := NavCheck.new()
var seen := {}  # uid -> {state name: true}
var still := {}  # uid -> {at: Vector3, s: seconds without moving}
var said := {}  # one line per case


func ok(cond: bool, what: String) -> void:
	print("GARDENDAY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _fail(key: String, label: String, nm: String, what: String) -> void:
	if not said.has(key):
		said[key] = true
		print("GARDENDAY FAIL %s: %s %s" % [label, nm, what])
		bad += 1


## One part of the garden for DAY_SECS: `zone` "" is Bramblebank, "hub" the hub.
func _day(zone: String) -> void:
	var label := "hub" if zone == "hub" else "Bramblebank"
	nav.zone = zone
	nav._save()
	home = await nav._open_home()
	nav.home = home
	if zone == "":
		_stage()
	seen.clear()
	still.clear()
	home.day_t = DAY_START
	var wall := Time.get_ticks_msec()
	var t := 0.0
	while t < DAY_SECS:
		home.day_t = fmod(home.day_t + DT / home.DAY_LEN, 1.0)
		home._move_kin(DT)
		home._care_tick(DT)
		home.hsp.tick(DT)
		t += DT
		_watch(label, t)
		if int(t / DT) % FRAME_EVERY == 0:
			await main.get_tree().process_frame  # deferred frees and timers (the puffs) run
	var secs := float(Time.get_ticks_msec() - wall) / 1000.0
	print("GARDENDAY %s: %.0f s of game time in %.1f s of wall time" % [label, t, secs])
	_states(label, zone)
	_budget(label, zone)
	FarmUnlocks.rules()["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame


## The three toys and the snack patch round the landing (the base demo's spots).
func _stage() -> void:
	var land := HomeLayout.LANDING
	for id in BaseDemo.TOYS:
		home.hg.demo_place(id, land + BaseDemo.TOYS[id])
	home.hg.demo_place(SnackPatch.ID, land + Vector3(5.0, 0, 5.0))
	home._sync_fixtures()
	ok(home.kins.size() == 6 and home.life != null, "Bramblebank: %d Boki live on a base_mode farm" % home.kins.size())
	var stand: bool = home.toys.toys().size() == 3 and not SnackPatch.entry(Save.d).is_empty()
	ok(stand, "Bramblebank: three toys and the snack patch stand")


func _watch(label: String, t: float) -> void:
	for k in home.kins:
		var rec: Dictionary = k["rec"]
		var uid := String(rec["uid"])
		var nm := String(rec["name"])
		var pos: Vector3 = k["pos"]
		if k.has("life"):
			var m := k["life"] as Fsm
			if not seen.has(uid):
				seen[uid] = {}
			seen[uid][m.state_name()] = true
			var endless: bool = m.is_in(BaseLife.S.NAP) or m.is_in(BaseLife.S.MENTOR)
			if m.since > STATE_MAX and m.since <= STATE_MAX + DT and not endless and not BaseLife._taken(k):
				_fail(
					"state" + uid + m.state_name(),
					label,
					nm,
					"stuck in %s for over %.0f s (t=%.0f)" % [m.state_name(), STATE_MAX, t]
				)
		var out: bool = home.world.is_void(pos.x, pos.z) and not k.has("indoors")
		if is_nan(pos.x) or is_nan(pos.z) or pos.y < FALL_Y or out:
			_fail(
				"fell" + uid, label, nm, "fell out of the zone at (%.1f, %.1f, %.1f), t=%.0f" % [pos.x, pos.y, pos.z, t]
			)
		_watch_still(label, k, t)


## A Boki that has not moved for STILL_MAX s: fine on a nav point or at rest by design, a fail anywhere else.
func _watch_still(label: String, k: Dictionary, t: float) -> void:
	var uid := String(k["rec"]["uid"])
	var pos: Vector3 = k["pos"]
	var track: Dictionary = still.get(uid, {"at": pos, "s": 0.0})
	var goal: Vector3 = k["goal"]
	var on_point: bool = goal == Vector3.INF or Vector2(goal.x - pos.x, goal.z - pos.z).length() <= AT_POINT
	if on_point or nav._resting(k) or Vector2(pos.x - track["at"].x, pos.z - track["at"].z).length() > PROGRESS:
		track = {"at": pos, "s": 0.0}
	else:
		track["s"] = float(track["s"]) + DT
		if float(track["s"]) >= STILL_MAX and float(track["s"]) < STILL_MAX + DT:
			_fail(
				"still" + uid + str(int(t)),
				label,
				k["rec"]["name"],
				(
					"still %.0f s off a nav point at (%.1f, %.1f), goal (%.1f, %.1f), %s (t=%.0f)"
					% [STILL_MAX, pos.x, pos.z, goal.x, goal.z, nav._state(k), t]
				)
			)
	still[uid] = track


func _states(label: String, zone: String) -> void:
	if zone == "hub":
		return  # nobody lives in the hub: no base life there
	for k in home.kins:
		var visited: Dictionary = seen.get(String(k["rec"]["uid"]), {})
		var names := ", ".join(visited.keys())
		ok(
			visited.size() >= MIN_STATES,
			"%s: %s visited %d states (%s)" % [label, k["rec"]["name"], visited.size(), names]
		)


## The budget as far as a headless run reads it (GARDEN.md 10.6, garden_zones.json budget / budget_hub).
func _budget(label: String, zone: String) -> void:
	var budget: Dictionary = GardenZones.rules()["budget_hub" if zone == "hub" else "budget"]
	var nodes: int = home.find_children("*", "", true, false).size()
	var emit := 0
	for cls in ["GPUParticles3D", "CPUParticles3D"]:
		var all: Array = home.find_children("*", cls, true, false)
		emit += all.filter(func(n): return n.emitting and not n.one_shot and n.is_visible_in_tree()).size()
	var t0 := Time.get_ticks_usec()
	for i in FRAMES:
		home._move_kin(FRAME)
		home._care_tick(FRAME)
	var frame_ms := (Time.get_ticks_usec() - t0) / 1000.0 / FRAMES
	var life_ms := 0.0
	if home.life != null:
		t0 = Time.get_ticks_usec()
		for i in FRAMES:
			home.life.step(0.1)
		life_ms = (Time.get_ticks_usec() - t0) / 1000.0 / FRAMES
	ok(nodes <= int(budget["nodes"]), "%s: %d nodes (budget %d)" % [label, nodes, budget["nodes"]])
	ok(
		emit <= int(budget["emitters"]),
		"%s: %d emitting particle systems (budget %d)" % [label, emit, budget["emitters"]]
	)
	ok(
		frame_ms <= float(budget["frame_ms"]),
		"%s: %.2f ms of script a frame (the whole frame's budget is %.1f ms)" % [label, frame_ms, budget["frame_ms"]]
	)
	ok(
		life_ms <= float(budget["base_life_ms"]),
		"%s: %.3f ms a base-life step (budget %.1f ms)" % [label, life_ms, budget["base_life_ms"]]
	)


func run(m: Node) -> void:
	main = m
	nav.main = m
	Save.no_write = true
	seed(SEED)
	FarmUnlocks.rules()["base_mode"] = true
	await _day("")
	FarmUnlocks.rules()["base_mode"] = true
	await _day("hub")
	FarmUnlocks.rules()["base_mode"] = false
	print("GARDENDAY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
