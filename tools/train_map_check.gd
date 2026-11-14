extends RefCounted
## --train-map-check: the sky train on the maps (TrainMap).
##   1. one halt icon per route stop, at the stop's place on the loop, with its name
##   2. the train's marker sits at the engine's arc position, and the cars follow it
##   3. the countdown at a halt runs down by the seconds that pass, reaches 0 as the train stands at that
##      halt, and reads "Next train: m:ss"
##   4. the minimap shows the loop by itself only while it is within range (MapDetail "train")
## Never touches the save.

const EPS := 0.05        # m: marker and arc position must agree this closely
const BEND := 0.5        # s: slack on countdown arithmetic

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("TMAP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## Jumps the match clock (and so the train) to time t.
func _set_time(m: Match, t: float) -> void:
	m.time = t
	m.skytrain.tick(0.0)

## The default map and Skyreach: each that has a train is checked (the 2x Hollow Crown's, or Skyreach's ring).
func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var with_train := 0
	for map_id in ["", "skyreach"]:
		var opts := {"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true}
		if map_id != "":
			opts["map"] = map_id
		var m := Match.new()
		main.add_child(m)
		await m.start(opts)
		m.set_process(false)
		if m.skytrain != null:
			with_train += 1
			print("TMAP map '%s': %d halts" % [map_id, m.world.train_route["stations"].size()])
			var tm := TrainMap.new()
			_halts(m, m.skytrain, tm)
			_marker(m, m.skytrain, tm)
			_countdown(m, m.skytrain, tm)
			_range(m, m.skytrain, tm)
		m.queue_free()
	ok(with_train > 0, "a map with a sky train was checked")
	print("TRAIN MAP CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _halts(m: Match, st: SkyTrain, tm: TrainMap) -> void:
	var route: Dictionary = m.world.train_route
	var halts: Array = tm.halts(st)
	var stops: int = route["stations"].size()
	ok(halts.size() == stops and stops > 0, "%d halt icons for %d route stops" % [halts.size(), stops])
	var placed := true
	var named := true
	for i in halts.size():
		var p := m.world.train_at(float(route["stations"][i]))
		placed = placed and (halts[i]["pos"] as Vector2).distance_to(Vector2(p.x, p.z)) < EPS
		named = named and String(halts[i]["name"]) != ""
		placed = placed and tm.nearest_halt(st, halts[i]["pos"]) == i
	ok(placed, "each halt icon sits on its stop of the loop")
	ok(named, "each halt icon has a name")

func _marker(m: Match, st: SkyTrain, tm: TrainMap) -> void:
	var worst := 0.0
	var worst_car := 0.0
	for i in 12:
		var t := st.period * i / 12.0 + 1.7
		_set_time(m, t)
		var p := m.world.train_at(st._schedule(t).x)
		worst = maxf(worst, tm.marker(st).distance_to(Vector2(p.x, p.z)))
		worst_car = maxf(worst_car, tm.marker(st).distance_to(st.car_positions()[0]))
	ok(worst < EPS, "the marker sits at the engine's arc position (worst %.3f m over 12 moments)" % worst)
	ok(worst_car < EPS, "the marker is the engine of the drawn cars (worst %.3f m)" % worst_car)
	_set_time(m, 0.0)
	var before := tm.marker(st)
	_set_time(m, st.dwell + 4.0)
	ok(tm.marker(st).distance_to(before) > 1.0, "the marker moves when the train does")

func _countdown(m: Match, st: SkyTrain, tm: TrainMap) -> void:
	var route: Dictionary = m.world.train_route
	var s_halt := float(route["stations"][2])
	_set_time(m, 0.5 * (st.dwell + float(st.legs[0]["t"])) + st.dwell * 0.5)
	var e0 := st.halt_eta(s_halt)
	ok(e0 > 0.0 and e0 < st.period, "a halt the train is away from counts down (%.1f s)" % e0)
	var t0 := float(m.time)
	_set_time(m, t0 + 3.0)
	var e1 := st.halt_eta(s_halt)
	ok(absf(e0 - 3.0 - e1) < BEND, "3 s on, the countdown is 3 s shorter (%.1f -> %.1f)" % [e0, e1])
	_set_time(m, t0 + e0 + 0.01)
	var stood := m.world.train_at(s_halt + (st.cars_n - 1) * SkyTrain.CAR_GAP * 0.5)
	ok(st.halt_eta(s_halt) == 0.0, "at the countdown's end the train stands at the halt")
	ok(tm.marker(st).distance_to(Vector2(stood.x, stood.z)) < EPS, "and its engine is where the schedule parks it")
	_set_time(m, t0 + e0 + st.dwell + 1.0)
	ok(st.halt_eta(s_halt) > st.period * 0.5, "after it leaves, the next one is a lap away")
	var reads := TrainMap.eta_text(24.0) == "Next train: 0:24" and TrainMap.eta_text(23.2) == "Next train: 0:24"
	ok(reads, "the text reads 'Next train: 0:24'")
	ok(TrainMap.eta_text(0.0) == "Train at the halt", "and says so when it is there")

func _range(m: Match, st: SkyTrain, tm: TrainMap) -> void:
	var P: Hunter = m.player
	var on: Vector2 = tm.halts(st)[0]["pos"]
	P.teleport(Vector3(on.x, 0.0, on.y))
	var close := tm.near(st, P)
	ok(close and MapDetail.shows("train", false, close), "on the loop the minimap shows it by itself")
	for _try in 40:
		P.teleport(m.world.random_ground())
		if not tm.near(st, P):
			break
	var away := tm.near(st, P)
	ok(not away and not MapDetail.shows("train", false, away), "out of range it waits for a hold (Tab or the map key)")
	ok(MapDetail.shows("train", true, away), "and a hold shows it anyway")
	ok(not tm.near(st, null), "no player, no loop")
