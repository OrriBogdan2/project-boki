extends RefCounted
## --incubator-check: the Incubator by the Nesting Nook. Rare Eggs brought home go into its cradles
## (5 to start, more bought up to 8) and warm side by side; the rest wait on the shelf. Each takes
## time (2 expeditions or ~8 minutes warm), never hatches by itself, an Ember kin at the brazier and
## Ember Coals each speed every egg up, hatching gives a rare kin with the IV floor, the breeding nest
## is untouched, and older saves move over. Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("INCUB %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _boss() -> String:
	for b in Data.MOBS:
		if Data.MOBS[b].has("egg") and Data.KIN.has(String(Data.MOBS[b]["egg"])): return b
	return ""

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var boss := _boss()
	var sp: String = String(Data.MOBS[boss]["egg"]) if boss != "" else String(Data.common_kin()[0])
	# ---------------------------------------------------------------- 1. cradles and the shelf
	Incubator.ensure()
	ok(Incubator.slots() == 5 and Incubator.eggs().is_empty() and Incubator.shelf().is_empty(), "a fresh save has an Incubator with 5 empty cradles")
	for i in 7: Econ._store(Loot.rare_egg(sp, boss))
	var slots_used := {}
	for e in Incubator.eggs(): slots_used[int(e["slot"])] = true
	ok(Incubator.eggs().size() == 5 and slots_used.size() == 5 and Incubator.shelf().size() == 2, "7 Rare Eggs brought home: 5 go into their own cradles, 2 wait on the shelf")
	ok(Save.d.get("egg", {}).is_empty(), "none go in the breeding nest")
	ok(Incubator.egg_name(Incubator.eggs()[0]).begins_with("Rare") and Incubator.boss_name(Incubator.eggs()[0]) != "a boss's lair", "each knows its kind and boss (%s, from %s)" % [Incubator.egg_name(Incubator.eggs()[0]), Incubator.boss_name(Incubator.eggs()[0])])
	var id_last := String(Incubator.shelf()[1]["id"])
	Incubator.next_up(id_last)
	ok(String(Incubator.shelf()[0]["id"]) == id_last, "'Next up' moves a shelf egg to the front")
	# ---------------------------------------------------------------- 2. buying cradles
	Save.d["gems"] = 2000
	var g0 := int(Save.d["gems"])
	var c6 := Incubator.slot_cost()
	ok(Incubator.expand() == "" and Incubator.slots() == 6 and int(Save.d["gems"]) == g0 - c6, "a 6th cradle for %d gems" % c6)
	ok(Incubator.eggs().size() == 6 and Incubator.shelf().size() == 1 and String(Incubator.in_slot(5).get("id", "")) == id_last, "the next shelf egg goes straight into it")
	Incubator.expand(); Incubator.expand()
	ok(Incubator.slots() == 8 and Incubator.slot_cost() == -1 and Incubator.expand() != "", "up to 8 cradles, then no more (%s)" % Incubator.expand())
	Save.d["gems"] = 0
	Save.d["incubator"]["slots"] = 7
	ok(Incubator.expand() != "" and Incubator.slots() == 7, "no gems, no cradle")
	Save.d["incubator"]["slots"] = 8
	# ---------------------------------------------------------------- 3. it takes time; warming in parallel
	ok(Incubator.eggs().all(func(e): return Incubator.progress(e) == 0.0) and not Incubator.any_ready(), "new eggs start cold")
	Incubator.tick(Incubator.HEAT_NEED * 0.5)
	ok(Incubator.eggs().all(func(e): return absf(Incubator.progress(e) - 0.5) < 0.01), "four minutes at home: every egg is half warm at once")
	ok(Incubator.status_text(Incubator.eggs()[0]).contains("min"), "each says what's left: \"%s\"" % Incubator.status_text(Incubator.eggs()[0]))
	Incubator.tick(Incubator.HEAT_NEED * 0.5)
	ok(Incubator.ready_eggs().size() == 7, "eight minutes: all ready")
	Incubator.tick(3600.0)
	ok(Incubator.eggs().size() == 7 and Incubator.ready_eggs().size() == 7, "ready eggs wait for you: nothing hatches by itself")
	# ---------------------------------------------------------------- 4. speed-ups
	var e0: Dictionary = Incubator.eggs()[0]
	var heat_after := func(warmed: bool, coal: bool) -> float:
		for e in Incubator.eggs(): e["heat"] = 0.0
		Save.d["incubator"]["coal"] = 600.0 if coal else 0.0
		Incubator.tick(60.0, warmed)
		return float(e0["heat"])
	var h_plain: float = heat_after.call(false, false)
	var h_kin: float = heat_after.call(true, false)
	var h_coal: float = heat_after.call(false, true)
	var h_both: float = heat_after.call(true, true)
	ok(absf(h_kin - 2.0 * h_plain) < 0.01, "an Ember kin at the brazier: twice as fast (%.0f s vs %.0f s a minute)" % [h_kin, h_plain])
	ok(absf(h_coal - 2.0 * h_plain) < 0.01, "Ember Coals burning: twice as fast (%.0f s)" % h_coal)
	ok(absf(h_both - 3.0 * h_plain) < 0.01, "both: three times as fast (%.0f s)" % h_both)
	Save.d["incubator"]["coal"] = 0.0
	Save.d["items"]["coals"] = 0
	ok(Incubator.stoke() != "", "no coals, nothing to stoke (%s)" % Incubator.stoke())
	Save.d["items"]["coals"] = 2
	ok(Incubator.stoke() == "" and int(Save.d["items"]["coals"]) == 1 and absf(Incubator.coal_left() - Incubator.COAL_SECS) < 0.01, "stoking one uses it and burns for %d minutes" % int(Incubator.COAL_SECS / 60.0))
	for e in Incubator.eggs(): e["heat"] = 0.0
	Incubator.tick(60.0)
	ok(absf(Incubator.coal_left() - (Incubator.COAL_SECS - 60.0)) < 0.01, "it burns down while eggs warm (%.0f s left)" % Incubator.coal_left())
	for e in Incubator.eggs(): e["heat"] = Incubator.HEAT_NEED
	Incubator.tick(60.0)
	ok(absf(Incubator.coal_left() - (Incubator.COAL_SECS - 60.0)) < 0.01, "and keeps when nothing's warming")
	Save.d["incubator"]["coal"] = 0.0
	# ---------------------------------------------------------------- 5. expeditions
	for e in Incubator.eggs(): e["heat"] = 0.0
	Save.d["matches"] = int(Save.d["matches"]) + 1      # (Game.apply_result counts each expedition like this)
	ok(Incubator.eggs().all(func(e): return absf(Incubator.progress(e) - 0.5) < 0.01), "one expedition: every egg half way")
	Save.d["matches"] = int(Save.d["matches"]) + 1
	ok(Incubator.ready_eggs().size() == Incubator.eggs().size(), "two expeditions: ready (whichever comes first)")
	# time away counts too
	for e in Incubator.eggs(): e["heat"] = 0.0; e["m0"] = int(Save.d["matches"])
	Save.d["incubator"]["t"] = Time.get_unix_time_from_system() - 120.0
	Incubator.catch_up()
	ok(absf(float(e0["heat"]) - 120.0) < 3.0, "two minutes away warm them two minutes (%.0f s)" % float(e0["heat"]))
	# ---------------------------------------------------------------- 6. hatching
	var rng := RandomNumberGenerator.new(); rng.seed = 8
	ok(Incubator.hatch(rng).is_empty() and Incubator.hatch(rng, String(e0["id"])).is_empty(), "nothing hatches before it's ready")
	e0["heat"] = Incubator.HEAT_NEED
	var slot0 := int(e0["slot"])
	var n0 := Incubator.eggs().size()
	var baby := Incubator.hatch(rng, String(e0["id"]))
	var hi_n := 0
	for k in Care.IV_KEYS:
		if Care.iv(baby, k) >= Care.IV_RARE_FLOOR: hi_n += 1
	ok(not baby.is_empty() and baby.get("rare", false) and String(baby["species"]) == sp, "the ready one hatches a rare %s; the others keep warming (%d still in cradles)" % [Data.KIN[sp]["name"], Incubator.eggs().size()])
	ok(hi_n >= Care.IV_RARE_HIGH, "with the Rare Egg IV floor: %d stats at 26+ (%s)" % [hi_n, str(Care.ivs(baby))])
	ok(Incubator.eggs().size() == n0 - 1 and Incubator.in_slot(slot0).is_empty() and Incubator.shelf().is_empty(), "its cradle is free (the shelf was empty)")
	Incubator.add(sp, boss)
	ok(not Incubator.in_slot(slot0).is_empty() and Incubator.progress(Incubator.in_slot(slot0)) == 0.0, "the next egg brought home goes into the free cradle, cold")
	# ---------------------------------------------------------------- 7. the breeding nest is untouched
	var a := Save.new_kin("cindle", "Ma"); var b := Save.new_kin("puddlet", "Pa")
	Save.d["roster"] = [a, b]
	Save.d["egg"] = {"a": a["uid"], "b": b["uid"], "sp": "cindle", "m": 1, "t": 0.0}
	var before: Dictionary = Save.d["egg"].duplicate()
	Incubator.ensure(); Incubator.settle(); Incubator.tick(30.0); Incubator.add(sp, boss)
	ok(Save.d["egg"] == before, "a pair's egg in the breeding nest is left alone")
	ok(not Care.settle_rare_egg() and Save.d["egg"] == before, "the old settle call never puts Rare Eggs in the nest")
	# ---------------------------------------------------------------- 8. older saves
	Save.d["incubator"] = {}; Save.d["rare_eggs"] = []
	Save.d["egg"] = {"sp": sp, "rare": true, "boss": boss, "m": 0, "t": 0.0}
	Incubator.ensure()
	ok(Save.d["egg"].is_empty() and Incubator.eggs().size() == 1 and String(Incubator.eggs()[0]["boss"]) == boss, "a Rare Egg sitting in the old nest moves into a cradle, and the nest is free")
	Save.d["incubator"] = {"sp": sp, "boss": boss, "id": "x1", "m0": 0, "heat": 100.0, "t": 0.0}
	Incubator.ensure()
	ok(Incubator.slots() == 5 and Incubator.eggs().size() == 1 and float(Incubator.eggs()[0]["heat"]) == 100.0, "an early one-egg incubator becomes cradle 1, warmth kept")
	var old := Save.fresh(); old.erase("incubator"); old.erase("rare_eggs")
	old["rare_eggs"] = [{"sp": sp, "boss": boss, "rare": true}]
	Save.d = old
	Incubator.ensure()
	ok(Save.d.has("incubator") and Incubator.eggs().size() == 1 and Incubator.shelf().is_empty(), "an old save's waiting Rare Egg goes into a cradle")
	# ---------------------------------------------------------------- 9. on the farm: an Ember kin warms it
	Save.d = Save.fresh()
	Econ.ensure()
	var ash := Save.new_kin("cindle", "Ash"); ash["level"] = 5; ash["trust"] = 60.0
	var drip := Save.new_kin("puddlet", "Drip"); drip["level"] = 5; drip["trust"] = 60.0; drip["starter"] = true
	Save.d["roster"] = [drip, ash]
	Save.d["active"] = drip["uid"]
	Save.d["tutorial"]["home"] = true; Save.d["tutorial"]["day1_done"] = true
	for r in Save.d["roster"]:
		Care.ensure(r)
		for n in Care.NEEDS: r["needs"][n] = 100.0
	for i in 3: Incubator.add(sp, boss)
	var H = load("res://scripts/home/home.gd").new()
	main.add_child(H)
	for _f in 4: await main.get_tree().process_frame
	H.day_t = 0.5
	ok(H.hinc != null and H.hinc.egg_nodes.size() == 3, "the Incubator stands by the Nook with 3 eggs placed in their cradles")
	var locked := 0
	for i in Incubator.MAX_SLOTS:
		if (H.hinc.node.get_node("C%d/Lock" % i) as Node3D).visible: locked += 1
	ok(locked == 3, "the 3 cradles not bought yet are shut behind a grate")
	H.hw.scan()
	var wj: Array = H.hw.jobs.filter(func(j): return String(j["kind"]) == "warm")
	ok(wj.size() == 1 and String(wj[0]["el"]) == "ember", "warming eggs make one Ember job: Warm the incubator")
	var ke: Dictionary = H._kin_entry(ash)
	var kd: Dictionary = H._kin_entry(drip)
	for k in [ke, kd]:      # both by the Nook, so the walk is short and the island the same
		k["pos"] = H.NEST_AT + Vector3(0, 0, 2.0); (k["node"] as Node3D).position = k["pos"]
	ok(String(H.hw.best_job(ke).get("kind", "-")) == "warm" and String(H.hw.best_job(kd).get("kind", "-")) != "warm", "the Ember kin (Ash) goes for it; the Tide kin doesn't")
	var got_warm := false
	for i in 900:
		for k in H.kins:
			for n in Care.NEEDS: k["rec"]["needs"][n] = 100.0
		H.day_t = 0.5
		H._move_kin(0.05)
		H.hw.tick(0.05)
		H.hinc.tick(0.05)
		if H.hinc.warmed(): got_warm = true; break
		if i % 100 == 0: await main.get_tree().process_frame
	ok(got_warm, "Ash walks over and sits by the brazier (%s)" % H.hw.job_text(ke))
	var ee: Dictionary = Incubator.eggs()[0]
	var t0 := float(ee["heat"])
	for i in 60: H.hinc.tick(0.05)
	var gain := float(ee["heat"]) - t0
	ok(absf(gain - 3.0 * 2.0) < 0.05, "while it's at it every egg warms twice as fast (%.2f s in 3 s)" % gain)
	for e in Incubator.eggs(): e["heat"] = Incubator.HEAT_NEED
	H.hw.scan()
	ok(not H.hw.jobs.any(func(j): return String(j["kind"]) == "warm"), "with every egg ready there's nothing to warm")
	_egg_sounds_home(H)
	ok(H.hinc.prompt().begins_with("Hatch"), "walking up says: %s" % H.hinc.prompt())
	H.queue_free()
	_egg_sounds()
	print("INCUBATOR CHECK DONE, failures: ", bad)
	main.get_tree().quit()

## In the garden: the Incubator's own tick plays each cradle's sounds as its warmth climbs, a ready egg puts up
## no message, and the Nook's nest egg chimes once it is ready.
func _egg_sounds_home(H) -> void:
	EggSfx.heard.clear()
	GardenSfx.heard.clear()
	H.hinc.ready_ids.clear()
	var lane := MsgLane.of(H.root_ui)
	lane.clear()
	var need := Incubator.secs_left({"heat": 0.0})      # seconds of warmth an egg needs
	var n := Incubator.eggs().size()
	for e in Incubator.eggs(): e["heat"] = need * 0.5 - 0.5
	Sfx.listener = H.INCUB_AT
	for i in 40: H.hinc.tick(0.05)
	var knocks := int(GardenSfx.heard.get("egg_knock", 0))
	ok(knocks == n, "warmed past half by the Incubator: each of %d eggs knocks once (%d)" % [n, knocks])
	for e in Incubator.eggs(): e["heat"] = need - 0.5
	Sfx.listener = H.INCUB_AT + Vector3(EggSfx.EARSHOT_M + 3.0, 0, 0)
	for i in 40: H.hinc.tick(0.05)
	var away := int(GardenSfx.heard.get("egg_ready", 0))
	Sfx.listener = H.INCUB_AT
	H.hinc.tick(0.05)
	var near := int(GardenSfx.heard.get("egg_ready", 0))
	var chimed := Incubator.ready_eggs().size() == n and away == 0 and near == n
	ok(chimed, "ready while you were far off: no chime, then one each when you come near (%d, %d)" % [away, near])
	ok(lane.count() == 0, "a ready egg puts up no message (%s)" % [lane.texts()])
	var roster: Array = Save.d["roster"]
	var laid := Time.get_unix_time_from_system()
	Save.d["egg"] = {"a": roster[0]["uid"], "b": roster[1]["uid"], "sp": "cindle", "m": 99, "t": laid + 600.0}
	H._refresh_nest()
	Sfx.listener = H.NEST_AT
	H._care_tick(0.05)
	var waiting := int(GardenSfx.heard.get("egg_ready", 0)) - near
	Save.d["egg"]["t"] = laid      # its time is up
	H._care_tick(0.05)
	H._care_tick(0.05)
	var chimes := int(GardenSfx.heard.get("egg_ready", 0)) - near
	ok(waiting == 0 and chimes == 1, "the Nook's nest egg: silent while it waits, one chime when ready (%d)" % chimes)

## The egg's sounds (EggSfx) follow the progress it stores: one knock past half, a small crack every few seconds
## from 90% while you are near, one chime when ready; at the egg, only within earshot, and a step missed while you
## were away plays when you come near.
func _egg_sounds() -> void:
	EggSfx.heard.clear()
	EggSfx.crack_in.clear()
	GardenSfx.heard.clear()
	var egg_at := Vector3(10, 0, 10)
	var near := egg_at + Vector3(2, 0, 1)
	var away := egg_at + Vector3(EggSfx.EARSHOT_M + 2.0, 0, 0)
	var plays := func(sname: String) -> int: return int(GardenSfx.heard.get(sname, 0))
	var sit := func(key: String, progress: float, secs: float) -> void:
		for i in roundi(secs / 0.1): EggSfx.hear(key, progress, egg_at, 0.1)
	Sfx.listener = near
	sit.call("a", 0.49, 1800.0)
	ok(GardenSfx.heard.is_empty(), "just under half warm for 30 minutes: silent (its progress decides, not a clock)")
	sit.call("a", 0.5, 5.0)
	ok(plays.call("egg_knock") == 1, "half warm: one gentle wobble and knock")
	sit.call("a", 0.8, 60.0)
	ok(plays.call("egg_knock") == 1 and plays.call("egg_crack") == 0, "then quiet up to 90%")
	sit.call("a", 0.9, 10.0)
	var cracks: int = plays.call("egg_crack")
	ok(cracks == 3, "from 90%%: a small crack every %.0f s while you are near (%d in 10 s)" % [EggSfx.CRACK_S, cracks])
	Sfx.listener = away
	sit.call("a", 0.95, 30.0)
	sit.call("a", 1.0, 5.0)
	var far_off: bool = plays.call("egg_crack") == 3 and plays.call("egg_ready") == 0
	ok(far_off, "past %.0f m: no cracks, and no chime as it turns ready" % EggSfx.EARSHOT_M)
	Sfx.listener = near
	sit.call("a", 1.0, 10.0)
	ok(plays.call("egg_ready") == 1 and plays.call("egg_crack") == 3, "come near: one ready chime, and the cracks stop")
	Sfx.listener = away
	sit.call("b", 0.6, 1.0)
	Sfx.listener = near
	sit.call("b", 0.6, 3.0)
	ok(plays.call("egg_knock") == 2, "half warm while you were away: its knock plays once you come near")
	sit.call("c", 0.95, 0.1)
	ok(plays.call("egg_knock") == 2 and plays.call("egg_crack") == 4, "past half and 90% while away: just the cracks")
	for p in [0.0, 1.0, 0.0, 1.0]: sit.call("nest", p, 1.0)
	ok(plays.call("egg_ready") == 3, "the nest egg chimes when ready, and the next egg laid there chimes again")
	var vol_at := func(metres: float) -> float:
		EggSfx.heard.erase("loud")
		Sfx.listener = egg_at + Vector3(metres, 0, 0)
		Sfx.last_played.erase("egg_ready")      # (Sfx merges a quick repeat and plays a burst of one sound quieter)
		Sfx.recent.erase("egg_ready")
		EggSfx.hear("loud", 1.0, egg_at, 0.1)
		var voice: AudioStreamPlayer = Sfx.players[(Sfx.next + Sfx.POOL - 1) % Sfx.POOL]
		return voice.volume_db if Sfx.last_played.has("egg_ready") else NAN
	var v_close: float = vol_at.call(1.0)
	var v_far: float = vol_at.call(8.0)
	ok(v_far < v_close - 3.0, "Sfx plays the chime at the egg: %.1f dB from 1 m, %.1f dB from 8 m" % [v_close, v_far])
