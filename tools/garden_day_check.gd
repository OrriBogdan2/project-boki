extends RefCounted
## --garden-day-check: a 20-minute garden day, headless and time-scaled (0.25 s of farm time a step, no frames).
## Every zone (Bramblebank, Glasswater, Cinderstep, Hushwood, Kitewind) with six residents of its types, its
## toys, the snack patch and its game; then the hub with the partner who comes along (nobody lives there,
## GARDEN.md 10.1). Fails on: a Boki that visited fewer than MIN_STATES base-life states, stayed in one non-Nap
## state over STATE_MAX s, stood still STILL_MAX s off a nav point (its goal, a toy, its feeder or a place it is
## meant to rest), fell out of the zone, never played at a toy, or (unless nocturnal) missed a night's nap; a
## toy nobody used; the zone's game that does not finish a match; or a part over GARDEN.md 10.6's budget as far
## as a headless run can read it: nodes, emitting particle systems, and the script cost of a frame and of a
## 10 Hz base-life step (draws, objects and the GPU frame are --perf-bench --bench-zone=all). Bramblebank's day
## starts with a toy you place among the residents (GARDEN.md 4, BaseLife.new_toy): they gather and chatter, the
## most curious plays at it first and each keeps the day it arrived.
## `--day-zone=<id>` runs one zone (or "hub"). Never touches the real save.

const NavCheck := preload("res://tools/garden_nav_check.gd")
const DAY_SECS := 1200.0       # s of game time: a 20-minute garden day
const DT := 0.25               # s of farm time per step
const FRAME_EVERY := 400      # steps between frames
const FRAME := 1.0 / 60.0      # s: the frame the budget's script cost is timed at
const FRAMES := 300            # frames timed for the budget
const MIN_STATES := 4          # base-life states every Boki has to visit in the day
const STATE_MAX := 90.0        # s in one state other than Nap
const STILL_MAX := 20.0        # s without moving off a nav point
const PROGRESS := 0.12         # m moved in STILL_MAX s that counts as not still
const AT_POINT := 1.5          # m from its goal: it has arrived on a nav point
const FALL_Y := -2.0           # m: a Boki lower than this has fallen through the island
const SEED := 11
const DAY_START := 0.3         # the farm clock at the start (morning)
const ZONES := ["", "glasswater", "cinderstep", "hushwood", "ridge", "hub"]      # "" is the start zone, Bramblebank
const RESIDENTS := 6           # Boki living in the zone for the day
const MATCH_MAX := 180.0       # s a zone game's match may take before it counts as hung
const NEW_TOY := "toy_dig"     # the toy you place at the start of Bramblebank's day
const CURIOUS := 3             # the resident made the most curious (not the first in the list)
const TRY_MAX := 12.0          # s from placing the toy to the most curious playing at it

var bad := 0
var main: Node
var home
var nav := NavCheck.new()
var seen := {}         # uid -> {state name: true}
var still := {}        # uid -> {at: Vector3, s: seconds without moving}
var played := {}       # uid -> {toy uid: true} it played at
var napped := {}       # uid -> {night number: true} it napped in
var owed := {}         # uid -> nights that ended with the Boki not nocturnal (it should have napped)
var slept := {}        # uid -> of those, the nights it napped in
var toys_used := {}    # toy uid -> true
var nights := 0        # nights begun so far
var was_night := false
var table: Array = []  # one line a zone: the states, toys and game, for GARDEN.md
var said := {}         # one line per case

func ok(cond: bool, what: String) -> void:
	print("GARDENDAY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _fail(key: String, label: String, nm: String, what: String) -> void:
	if not said.has(key):
		said[key] = true
		print("GARDENDAY FAIL %s: %s %s" % [label, nm, what])
		bad += 1

## garden_zones.json's entry for a zone ("" is the start zone).
func _info(zone: String) -> Dictionary:
	return GardenZones.info(zone if zone != "" else GardenZones.start())

## The six residents lean toward the zone's types, so they thrive there (GardenZones.thrives): one type each,
## round-robin (Normal has no tint: plain food never leans, so it is left out).
func _lean(zone: String) -> void:
	var types: Array = _info(zone)["types"].filter(
			func(t): return Lean.rules()["types"][t].has("tint"))
	for i in Save.d["roster"].size():
		Save.d["roster"][i]["lean"] = {types[i % types.size()]: float(GardenZones.rules()["lean_key"])}

## One part of the garden for DAY_SECS: `zone` "" is Bramblebank, "hub" the hub.
func _day(zone: String) -> void:
	var label := "hub" if zone == "hub" else String(_info(zone)["name"])
	nav.zone = zone
	nav._save()
	if zone != "hub":
		_lean(zone)
	home = await nav._open_home()
	nav.home = home
	if zone != "hub":
		_stage(label, zone)
	seen.clear()
	still.clear()
	played.clear()
	napped.clear()
	owed.clear()
	slept.clear()
	toys_used.clear()
	nights = 0
	was_night = false
	home.day_t = DAY_START
	var wall := Time.get_ticks_msec()
	var t := 0.0
	if zone == "":
		_new_toy(label)
	while t < DAY_SECS:
		t += DT
		_advance(label, t)
		if int(t / DT) % FRAME_EVERY == 0:
			await main.get_tree().process_frame      # deferred frees and timers (the puffs) run
	var secs := float(Time.get_ticks_msec() - wall) / 1000.0
	print("GARDENDAY %s: %.0f s of game time in %.1f s of wall time" % [label, t, secs])
	var line := _states(label, zone)
	_budget(label, zone)
	if zone != "hub":
		line += " | " + _play_game(label, zone)
	table.append("| %s | %s" % [label, line])
	FarmUnlocks.rules()["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame

## One DT of the farm: its clock, the Boki, their care and the snack patch.
func _advance(label: String, t: float) -> void:
	home.day_t = fmod(home.day_t + DT / home.DAY_LEN, 1.0)
	home._move_kin(DT)
	home._care_tick(DT)
	home.hsp.tick(DT)
	_watch(label, t)

## You place a toy with every resident within a few metres, free and roaming; CURIOUS is the most curious.
## Checks they come to look, the gather lasts new_toy.gather s and is chatty, CURIOUS plays at it before anyone
## else, and each looker keeps the day in its memory.
func _new_toy(label: String) -> void:
	var spot: Vector3 = HomeLayout.LANDING + Vector3(0, 0, 7.0)
	var taken: Array = [spot]
	for i in home.kins.size():
		var k: Dictionary = home.kins[i]
		var p: Vector3 = home.world.free_spot_near(spot + Vector3(cos(i * 1.05), 0, sin(i * 1.05)) * 4.0, taken, 1.3)
		taken.append(p)
		k["pos"] = p
		(k["node"] as Node3D).position = p
		k["goal"] = Vector3.INF
		for key in ["busy", "indoors", "nap_t", "job", "chase", "fetch", "bath", "going_in", "called_t", "play"]:
			k.erase(key)
		k["hold_t"] = 0.0
		k["say_t"] = 0.0
		k["rec"]["needs"]["food"] = 100.0
		k["rec"]["needs"]["energy"] = 100.0
		k["rec"]["traits"]["curiosity"] = 0.95 if i == CURIOUS else 0.2 + 0.1 * i
		var m: Fsm = home.life.machine(k)
		if not m.is_in(BaseLife.S.ROAM):
			m.go(BaseLife.S.ROAM, "check")
	var curious: Dictionary = home.kins[CURIOUS]
	var was: Array = home.toys.toys().map(func(t): return int(t["u"]))
	var inv: Dictionary = home.hb.L()["inv"]
	inv[NEW_TOY] = int(inv.get(NEW_TOY, 0)) + 1
	ok(home.guide._place(NEW_TOY, spot), "%s: you place a %s among the residents" % [label, NEW_TOY])
	var new: Array = home.toys.toys().filter(func(t): return not was.has(int(t["u"])))
	var u: int = new[0]["u"] if not new.is_empty() else -1
	var lookers: Array = home.kins.filter(func(k): return (k["life"] as Fsm).is_in(BaseLife.S.REACT))
	ok(lookers.size() >= 3 and lookers.has(curious) and int(curious.get("life_toy", -1)) == u,
			"%s: %d of %d come to look; the most curious will try it" % [label, lookers.size(), home.kins.size()])
	var first := {}
	var try_t := -1.0
	var spoke := {}        # uid -> true: a looker that said a line
	var t := 0.0
	while t < TRY_MAX and try_t < 0.0:
		t += DT
		_advance(label, t)
		for k in lookers:
			if float(k.get("say_t", 0.0)) > 0.0:
				spoke[k["rec"]["uid"]] = true
		for k in home.kins:
			var play: Variant = k.get("play")
			if first.is_empty() and play is Dictionary and int(play["u"]) == u:
				first = k
		var cp: Variant = curious.get("play")
		if cp is Dictionary and int(cp["u"]) == u and cp["phase"] == "play":
			try_t = t
	var G: Array = home.life.R["new_toy"]["gather"]
	ok(is_same(first, curious), "%s: the most curious, %s, goes to it first (%s)"
			% [label, curious["rec"]["name"], first.get("rec", {}).get("name", "nobody")])
	ok(try_t >= float(G[0]) and try_t <= TRY_MAX, "%s: it plays at it %.1f s after a %.0f-%.0f s gather"
			% [label, try_t, G[0], G[1]])
	ok(spoke.size() >= 1, "%s: the lookers chatter (%d spoke)" % [label, spoke.size()])
	var stuck: Array = lookers.filter(func(k): return (k["life"] as Fsm).is_in(BaseLife.S.REACT))
	ok(stuck.is_empty() and home.panel_open == "", "%s: the gather is over and nothing opened on you" % label)
	for k in lookers:
		var mem: Array = k["rec"]["memory"].map(func(e): return String(e["text"]))
		var want := "first to try the dig patch" if is_same(k, curious) else "the day the dig patch arrived"
		ok(mem.any(func(x): return x.contains(want)), "%s: %s remembers '%s'" % [label, k["rec"]["name"], want])

## The zone's toys and the snack patch. A zone with a build brings its own (garden_zones.json deco); a zone
## without one gets the base demo's three toys and the patch round the landing.
func _stage(label: String, zone: String) -> void:
	if home.toys.toys().is_empty():
		var land := HomeLayout.LANDING
		for id in BaseDemo.TOYS:
			home.hg.demo_place(id, land + BaseDemo.TOYS[id])
		home.hg.demo_place(SnackPatch.ID, land + Vector3(5.0, 0, 5.0))
		home._sync_fixtures()
	var n: int = home.kins.size()
	ok(n == RESIDENTS and home.life != null, "%s: %d Boki live on a base_mode farm" % [label, n])
	var toys: int = home.toys.toys().size()
	ok(toys > 0 and not SnackPatch.entry(Save.d).is_empty(), "%s: %d toys and the snack patch stand" % [label, toys])

## A night ended: every Boki that is not nocturnal now should have napped in it.
func _end_night() -> void:
	for k in home.kins:
		var uid := String(k["rec"]["uid"])
		if not BaseLife.nocturnal(k["rec"]):
			owed[uid] = int(owed.get(uid, 0)) + 1
			slept[uid] = int(slept.get(uid, 0)) + int(napped.get(uid, {}).has(nights))

func _watch(label: String, t: float) -> void:
	var night: bool = home.life != null and home.life.night
	if night and not was_night:
		nights += 1
	if was_night and not night:
		_end_night()
	was_night = night
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
			if night and m.is_in(BaseLife.S.NAP):
				napped[uid] = napped.get(uid, {})
				napped[uid][nights] = true
			var endless: bool = m.is_in(BaseLife.S.NAP) or m.is_in(BaseLife.S.MENTOR)
			if m.since > STATE_MAX and m.since <= STATE_MAX + DT and not endless and not BaseLife._taken(k):
				_fail("state" + uid + m.state_name(), label, nm,
						"stuck in %s for over %.0f s (t=%.0f)" % [m.state_name(), STATE_MAX, t])
		var play: Variant = k.get("play")
		if play is Dictionary and play["phase"] == "play":
			played[uid] = played.get(uid, {})
			played[uid][play["u"]] = true
			toys_used[play["u"]] = true
		var out: bool = home.world.is_void(pos.x, pos.z) and not k.has("indoors")
		if is_nan(pos.x) or is_nan(pos.z) or pos.y < FALL_Y or out:
			_fail("fell" + uid, label, nm, "fell out of the zone at (%.1f, %.1f, %.1f), t=%.0f"
					% [pos.x, pos.y, pos.z, t])
		_watch_still(label, k, t)

## A Boki that has not moved for STILL_MAX s: fine on a nav point or at rest by design, a fail anywhere else.
func _watch_still(label: String, k: Dictionary, t: float) -> void:
	var uid := String(k["rec"]["uid"])
	var pos: Vector3 = k["pos"]
	var tr: Dictionary = still.get(uid, {"at": pos, "s": 0.0})
	var goal: Vector3 = k["goal"]
	var on_point: bool = goal == Vector3.INF or Vector2(goal.x - pos.x, goal.z - pos.z).length() <= AT_POINT
	if on_point or nav._resting(k) or Vector2(pos.x - tr["at"].x, pos.z - tr["at"].z).length() > PROGRESS:
		tr = {"at": pos, "s": 0.0}
	else:
		tr["s"] = float(tr["s"]) + DT
		if float(tr["s"]) >= STILL_MAX and float(tr["s"]) < STILL_MAX + DT:
			_fail("still" + uid + str(int(t)), label, k["rec"]["name"],
					"still %.0f s off a nav point at (%.1f, %.1f), goal (%.1f, %.1f), %s (t=%.0f)"
					% [STILL_MAX, pos.x, pos.z, goal.x, goal.z, nav._state(k), t])
	still[uid] = tr

## The day's tally for the zone: the states, toys and nights, checked. Returns the table row's rest.
func _states(label: String, zone: String) -> String:
	if zone == "hub":
		return "nobody lives here (the partner comes along) | | |"
	var all := {}
	var min_states := 99
	var night_naps := 0
	for k in home.kins:
		var rec: Dictionary = k["rec"]
		var uid := String(rec["uid"])
		var visited: Dictionary = seen.get(uid, {})
		all.merge(visited)
		min_states = mini(min_states, visited.size())
		ok(visited.size() >= MIN_STATES, "%s: %s (%s) visited %d states (%s)"
				% [label, rec["name"], rec["species"], visited.size(), ", ".join(visited.keys())])
		ok(played.has(uid), "%s: %s played at a toy (%d of %d toys)" % [label, rec["name"],
				played.get(uid, {}).size(), home.toys.toys().size()])
		if owed.has(uid):
			var n: int = slept.get(uid, 0)
			ok(n == owed[uid], "%s: %s napped in %d of %d nights" % [label, rec["name"], n, owed[uid]])
			night_naps += n
	ok(toys_used.size() == home.toys.toys().size(), "%s: every toy was played at (%d of %d)"
			% [label, toys_used.size(), home.toys.toys().size()])
	return "%d (%s) | %d | %d of %d | %d" % [all.size(), ", ".join(all.keys()), min_states, toys_used.size(),
			home.toys.toys().size(), night_naps]

## The budget as far as a headless run reads it (GARDEN.md 10.6, garden_zones.json budget / budget_hub).
func _budget(label: String, zone: String) -> void:
	var B: Dictionary = GardenZones.rules()["budget_hub" if zone == "hub" else "budget"]
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
	ok(nodes <= int(B["nodes"]), "%s: %d nodes (budget %d)" % [label, nodes, B["nodes"]])
	ok(emit <= int(B["emitters"]), "%s: %d emitting particle systems (budget %d)" % [label, emit, B["emitters"]])
	ok(frame_ms <= float(B["frame_ms"]), "%s: %.2f ms of script a frame (the whole frame's budget is %.1f ms)"
			% [label, frame_ms, B["frame_ms"]])
	ok(life_ms <= float(B["base_life_ms"]), "%s: %.3f ms a base-life step (budget %.1f ms)"
			% [label, life_ms, B["base_life_ms"]])

## The zone's game, played once with its residents: it starts, finishes within MATCH_MAX and frees both Boki.
## Returns the table row's last cell.
func _play_game(label: String, zone: String) -> String:
	var g
	var live: Callable
	match zone:
		"glasswater":
			g = home.hvolley
			live = func(): return g.run != null
		"cinderstep":
			g = home.hshove
			live = func(): return g.run != null
		"hushwood":
			g = home.hseek
			live = func(): return g.state != BaseSeek.S.IDLE
		_:
			g = home.hrace
			live = func(): return g.run != null
	for k in home.kins:
		k["busy"] = false
		k.erase("indoors")
		k["rec"]["needs"]["energy"] = 100.0
	g.use()
	if g is BaseSeek:
		home.ppos = HomeLayout.LANDING + Vector3(12.0, 0, 12.0)      # far from the pair, so the scent can be hidden
		g.use()
	var t := 0.0
	while t < MATCH_MAX and live.call():
		g.tick(DT)
		home._move_kin(DT)
		t += DT
	var busy: int = home.kins.filter(func(k): return k.get("busy", false)).size()
	ok(t > 0.0 and not live.call(), "%s: its game finished a match in %.0f s" % [label, t])
	ok(busy == 0, "%s: both Boki are free after the match (%d busy)" % [label, busy])
	return "%s %.0f s" % [_info(zone)["game"], t]

func run(m: Node) -> void:
	main = m
	nav.main = m
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--day-zone="):
			only = a.substr(11)
	for z in ZONES:
		if only == "" or only == z or (only == "bramblebank" and z == ""):
			FarmUnlocks.rules()["base_mode"] = true
			await _day(z)
	FarmUnlocks.rules()["base_mode"] = false
	print("GARDENDAY | zone | states | fewest | toys used | night naps | game |")
	for row in table:
		print("GARDENDAY %s" % row)
	print("GARDENDAY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
