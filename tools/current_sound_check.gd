extends RefCounted
## --current-sound-check: wind roads and updrafts are heard (scripts/match/current_sound.gd).
##   1. every current on the map gets its looping bed when the listener is within BED_M, and no bed
##      past BED_KEEP_M (one player per nearby current only)
##   2. the riding layer plays while the player glides with in_current, its pitch rises with speed,
##      and it stops once in_current goes false or the glider is shut
##   3. the two sounds exist and loop

var main: Node
var fails := 0
var n := 0

func ok(cond: bool, what: String) -> void:
	n += 1
	print("CURRENTSOUND %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Game.goto("match", {"autoplay": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77,
		"no_drop": true, "map": "skyreach"})
	for i in 6:
		await main.get_tree().process_frame
	var m: Match = main.current
	m.set_process(false)
	var P: Hunter = m.player
	var w: World = m.world
	ok(not w.winds.is_empty() and not w.updrafts.is_empty(),
		"the map has wind roads (%d) and updrafts (%d)" % [w.winds.size(), w.updrafts.size()])
	for s in ["current_bed", "current_ride"]:
		ok(Sfx.has(s), "%s is loaded" % s)
	# far from everything: no bed anywhere
	Sfx.listener = Vector3(9000, 0, 9000)
	CurrentSound.tick(m)
	ok(CurrentSound.bed_keys(m).all(func(k): return not Sfx.loop_on(k)), "no current is heard from far away")
	# at each current in turn: its bed plays; leaving drops it again
	var missing := []
	var kept := []
	var keys := CurrentSound.bed_keys(m)
	for i in keys.size():
		var at: Vector3 = _point(w, i)
		Sfx.listener = at
		CurrentSound.tick(m)
		if not Sfx.loop_on(keys[i]):
			missing.append(keys[i])
		Sfx.listener = Vector3(at.x + 9000.0, at.y, at.z)
		CurrentSound.tick(m)
		if Sfx.loop_on(keys[i]):
			kept.append(keys[i])
	ok(missing.is_empty(), "all %d currents get a bed when you stand at them (missing %s)" % [keys.size(), missing])
	ok(kept.is_empty(), "a bed is dropped once you are far from it (kept %s)" % [kept])
	# the riding layer follows in_current
	Sfx.listener = Vector3(9000, 0, 9000)
	P.gliding = true
	P.dropping = false
	P.in_current = false
	CurrentSound.tick(m)
	ok(not Sfx.loop_on(CurrentSound.RIDE_KEY), "gliding in still air: no riding layer")
	P.in_current = true
	P.vel = Vector3(0, 0, 4)
	CurrentSound.tick(m)
	ok(Sfx.loop_on(CurrentSound.RIDE_KEY), "gliding in a current: the riding layer plays")
	var slow := _ride_pitch()
	P.vel = Vector3(0, 0, 14)
	CurrentSound.tick(m)
	var fast := _ride_pitch()
	ok(fast > slow + 0.2, "it rises in pitch with speed (%.2f at 4 m/s, %.2f at 14 m/s)" % [slow, fast])
	P.in_current = false
	await main.get_tree().create_timer(float(Sfx.HOLD_MS) / 1000.0 + 0.3).timeout
	ok(not Sfx.loop_on(CurrentSound.RIDE_KEY), "leaving the current stops the riding layer")
	P.in_current = true
	CurrentSound.tick(m)
	P.gliding = false
	await main.get_tree().create_timer(float(Sfx.HOLD_MS) / 1000.0 + 0.3).timeout
	CurrentSound.tick(m)
	ok(not Sfx.loop_on(CurrentSound.RIDE_KEY), "a shut glider (stale in_current) has no riding layer")
	print("CURRENTSOUND DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _ride_pitch() -> float:
	return ((Sfx.loops[CurrentSound.RIDE_KEY] as Dictionary)["p"] as AudioStreamPlayer).pitch_scale

## A spot on current i: the middle of a wind road, or the foot of an updraft.
func _point(w: World, i: int) -> Vector3:
	if i < w.winds.size():
		return (w.winds[i]["a"] as Vector3).lerp(w.winds[i]["b"], 0.5)
	return w.updrafts[i - w.winds.size()]["pos"]
