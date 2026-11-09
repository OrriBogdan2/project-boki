extends RefCounted
## --garden-night-check (GARDEN.md section 4): with base_mode on, the farm's five Boki are asserted by time of day:
## by day the nocturnal ones carry no glow and not everyone naps; at dusk every day Boki walks to bed (two friends
## in a pile, a grumpy one off by itself) while the nocturnal Pip and Wisp stay up; at night the day Boki sleep on and
## the nocturnal ones roam and play with a soft light; walking up to a sleeper wakes it and it comes to look, then
## goes back to bed; at dawn everyone is up and the glow is gone. Never touches the real save.

const DT := 0.25             # s per farm step (the machines tick at 10 Hz inside it)
const DAY := 0.4             # day_t values: noon-ish, dusk, deep night, dawn (home.gd day_t: 0.25 morning, 0.75 dusk)
const DUSK := 0.74
const NIGHT := 0.9
const DAWN := 0.3
const PILE := 2.5            # m: friends bedded down this close count as a pile
const APART := 3.0           # m: the grumpy Boki lies at least this far from every other sleeper

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("GARDENNIGHT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _new_save() -> Array:
	var d := Save.fresh()
	var recs: Array = []
	for spec in [["cindle", "Ash"], ["basaltoad", "Crag"], ["burrlet", "Moss"], ["zapple", "Pip"], ["wisplet", "Wisp"]]:
		var rec := Save.new_kin(spec[0], spec[1])
		rec["traits"]["temper"] = 0.1
		recs.append(rec)
	recs[0]["starter"] = true
	d["roster"] = recs
	d["active"] = recs[0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true}     # no Welcome home card over the shots
	Save.d = d
	HomeLayout.ensure(d)
	return recs

func _by_name(home, who: String) -> Dictionary:
	for k in home.kins:
		if k["rec"]["name"] == who:
			return k
	return {}

func _run(home, secs: float) -> void:
	var t := 0.0
	while t < secs:
		home._move_kin(DT)
		t += DT

func _asleep(k: Dictionary) -> bool:
	return (k["life"] as Fsm).is_in(BaseLife.S.NAP) and float(k.get("nap_t", 0.0)) > 0.0

func _flat(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a["pos"].x - b["pos"].x, a["pos"].z - b["pos"].z).length()

## The check's farm: five Boki gathered in one spot, Ash and Crag friends, Moss grumpy.
## All the farm Boki within a few metres of one spot on the home island.
func _gather(home) -> void:
	var center: Vector3 = home.world.random_ground(0)
	for k in home.kins:
		k["pos"] = home.world.free_spot_near(center + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), [], 0.8)
		(k["node"] as Node3D).position = k["pos"]

func _setup() -> Node:
	Save.no_write = true
	seed(21)
	var rules: Dictionary = Content.rules("farm_build")
	rules["base_mode"] = true
	var recs := _new_save()
	BaseLife.add_bond(recs[0], recs[1], 0.8)       # Ash and Crag are friends
	Care.change(recs[2], "joy", -100.0)            # Moss is grumpy
	var home = await main._hb_home()
	home.ppos = Vector3(-500, 0, -500)       # you are away
	_gather(home)
	return home

## --garden-night-shots: the same farm at dusk (Boki walking to bed) and at night (a pile asleep, Pip and Wisp
## glowing), one wide and one close, into --shots-dir=<dir> (needs a real renderer, jobq --needs gpu).
func _shots(home) -> void:
	var dir := "shots"
	for a in OS.get_cmdline_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	# a slow GPU worker is still building the farm in slices here: wait for it and its five Boki, then place them
	var waited := 0.0
	while (home.building or home.kins.size() < 5) and waited < 120.0:
		await main.get_tree().create_timer(0.5).timeout
		waited += 0.5
	print("GARDENNIGHT farm ready after %.1f s (%d kins)" % [waited, home.kins.size()])
	if home.kins.is_empty():
		push_error("GARDENNIGHT no Boki on the farm, no shots")
		main.get_tree().quit(1)
		return
	_gather(home)
	home.ppos = home.kins[0]["pos"] + Vector3(0, 0, 5)     # on the farm, not out in the void (no wind toast)
	home.safe_at = home.ppos
	home.player.position = home.ppos
	await main.get_tree().create_timer(1.0).timeout
	if main.fade:
		main.fade.reveal(0.05)
	for phase in [["dusk", DUSK, 12.0], ["night", NIGHT, 25.0]]:
		home.day_t = phase[1]
		_run(home, phase[2])
		await main.get_tree().create_timer(2.0).timeout
		for view in [["wide", "Ash", 2.2], ["close", "Pip", 1.0]]:
			var at := _shot_at(home, view[1])
			home.ppos = at + Vector3(0, 0, 5)
			home.player.position = home.ppos
			home.cam.zoom_to = view[2]
			home.cam.zoom = view[2]
			home.cam.snap(at)
			home.set_process(false)
			home.prompt_box.visible = false
			home.ui.visible = false      # the world only: dusk light, the walk to bed, the glow
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			var img := main.get_viewport().get_texture().get_image()
			if img:      # null under --headless (no renderer): the run still walks every phase and quits
				img.save_png("%s/garden_%s_%s.png" % [dir, phase[0], view[0]])
			home.ui.visible = true
			home.set_process(true)
			print("GARDENNIGHT shot garden_%s_%s" % [phase[0], view[0]])
	home.queue_free()
	await main.get_tree().process_frame
	main.get_tree().quit(0)

## Where a shot looks: the named Boki, else any farm Boki, else the farm centre (the GPU run can respawn kins
## while the real renderer catches up, so look them up at shot time, never once before).
func _shot_at(home, who: String) -> Vector3:
	var k := _by_name(home, who)
	if k.is_empty() and not home.kins.is_empty():
		k = home.kins[0]
	print("GARDENNIGHT aim %s -> %s (%d kins)" % [who, k.get("rec", {}).get("name", "centre"), home.kins.size()])
	return k["pos"] if k.has("pos") else home.world.random_ground(0)

func run(m: Node, mode := "check") -> void:
	main = m
	var home = await _setup()
	if mode == "shots":
		await _shots(home)
		return
	var rules: Dictionary = Content.rules("farm_build")
	ok(home.life != null and home.kins.size() == 5, "base_mode on: the farm runs BaseLife with its five Boki")
	var ash := _by_name(home, "Ash")
	var crag := _by_name(home, "Crag")
	var moss := _by_name(home, "Moss")
	var pip := _by_name(home, "Pip")
	var wisp := _by_name(home, "Wisp")
	var day_boki := [ash, crag, moss]
	var night_boki := [pip, wisp]
	var kinds := [ash, crag, moss, pip, wisp]

	home.day_t = DAY
	var napped := 0
	for i in 40:
		_run(home, 1.0)
		napped += day_boki.filter(func(k): return _asleep(k)).size()
	ok(napped < 40 * 3 * 0.5, "by day the Boki are not all napping (%d of %d Boki-seconds)" % [napped, 40 * 3])
	ok(night_boki.all(func(k): return k.get("glow", null) == null), "by day the nocturnal Boki carry no glow")

	home.day_t = DUSK
	Care.change(moss["rec"], "joy", -100.0)
	_run(home, 30.0)
	ok(home.life.dusk and not home.life.night, "the base knows it is dusk, not yet night")
	ok(day_boki.all(func(k): return _asleep(k)), "at dusk Ash, Crag and Moss are all in bed")
	ok(night_boki.all(func(k): return not (k["life"] as Fsm).is_in(BaseLife.S.NAP)), "at dusk Pip and Wisp stay up")
	var pile := _flat(ash, crag)
	ok(pile < PILE, "the two friends bedded down in a pile (%.1f m apart)" % pile)
	var apart := minf(_flat(moss, ash), _flat(moss, crag))
	ok(apart >= APART, "grumpy Moss sleeps by itself (%.1f m from the nearest sleeper)" % apart)

	home.day_t = NIGHT
	var up := 0
	var slept := 0
	var play := 0
	var moved := 0.0
	var last := {}
	for i in 60:
		_run(home, 1.0)
		for k in night_boki:
			up += 0 if (k["life"] as Fsm).is_in(BaseLife.S.NAP) else 1
			var fsm: Fsm = k["life"]
			play += 1 if fsm.is_in(BaseLife.S.PLAY) or fsm.is_in(BaseLife.S.PLAY_WITH) else 0
			if last.has(k["rec"]["name"]):
				moved += _flat(k, {"pos": last[k["rec"]["name"]]})
			last[k["rec"]["name"]] = k["pos"]
		slept += day_boki.filter(func(k): return _asleep(k)).size()
	ok(home.life.night, "the base knows it is night")
	ok(slept >= 60 * 3 * 0.95, "at night the day Boki sleep on (%d of %d Boki-seconds)" % [slept, 60 * 3])
	ok(up >= 60 * 2 * 0.8, "at night Pip and Wisp roam, not nap (%d of 120 Boki-seconds up)" % up)
	ok(moved > 5.0, "the nocturnal Boki really move about at night (%.0f m)" % moved)
	ok(night_boki.all(func(k): return k.get("glow", null) != null and (k["glow"] as OmniLight3D).light_energy > 0.5),
		"at night Pip and Wisp glow softly")
	ok(day_boki.all(func(k): return k.get("glow", null) == null), "the day Boki do not glow")
	print("GARDENNIGHT played %d Boki-seconds at a toy or tag" % play)

	home.ppos = Vector3(ash["pos"].x + 1.5, 0, ash["pos"].z)       # you walk up to Ash's pile
	_run(home, 2.0)
	var ash_fsm: Fsm = ash["life"]
	ok(not _asleep(ash) and ash_fsm.is_in(BaseLife.S.REACT),
		"walking up to a sleeper wakes it and it comes to look (Ash is %s)" % ash_fsm.state_name())
	ok(_asleep(moss) or _flat(moss, {"pos": home.ppos}) < 3.0, "a sleeper you did not walk up to sleeps on")
	home.ppos = Vector3(-500, 0, -500)
	_run(home, 40.0)
	ok(ash_fsm.is_in(BaseLife.S.NAP), "it goes back to bed once you leave (Ash is %s)" % ash_fsm.state_name())

	home.day_t = DAWN
	_run(home, 15.0)
	ok(kinds.all(func(k): return not _asleep(k)), "at dawn everyone is up")
	ok(night_boki.all(func(k): return (k["glow"] as OmniLight3D).light_energy < 0.01), "at dawn the glow has faded out")
	print(home.life.readout())
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("GARDENNIGHT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
