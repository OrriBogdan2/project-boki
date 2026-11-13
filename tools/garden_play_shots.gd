extends RefCounted
## --garden-play-shots --hatch-auto=0 --shots-dir=<dir>: a garden-only player's first 30 minutes on a fresh save, played through the
## real screens (docs/GARDEN_PLAY_0246.md): hatch, name, skip the combat tutorial, pet, feed, two garden games, breed,
## hatch the egg, visit a second zone. Game time runs at TIME_SCALE; a shot every SHOT_EVERY_S of it, and one `PLAY`
## line per step with what the player would see. Needs a renderer for the shots (jobq --needs gpu).
## Never writes the save.

const TIME_SCALE := 6.0       # game seconds per real second
const SHOT_EVERY_S := 300.0   # game s between shots (5 min)
const TOTAL_S := 1800.0       # game s of play (30 min)

var main: Node
var dir := "shots"
var clock := 0.0              # game s since the home opened
var next_shot := 0.0
var shot_n := 0

func say(what: String) -> void:
	print("PLAY %4.0fs %s" % [clock, what])

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): dir = a.substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Content.rules("farm_build")["base_mode"] = true      # the garden mode (farm_build.json ships it off)
	Engine.time_scale = TIME_SCALE
	main.show_screen("hatch", {})
	await _wait(func(): return main.current != null and main.current.get("stage") == "reveal", 40.0)
	var hatch = main.current
	var reveal: KinReveal = hatch.get_children().filter(func(c): return c is KinReveal)[0]
	await _wait(func(): return reveal.ready_to_name, 20.0)
	reveal._go()
	await _wait(func(): return hatch.stage == "name", 5.0)
	say("hatched: stage %s, species %s" % [hatch.stage, hatch.egg_defs[hatch.chosen]["species"]])
	hatch._finish(hatch.egg_defs[hatch.chosen]["species"], "Biscuit", "Tester", false)
	if hatch.stage == "mask":      # a new save must pick its first Relic before it reaches the garden
		var relic: String = ClassUnlock.starters()[0]
		say("forced Relic pick before home: %s of %s" % [relic, str(ClassUnlock.starters())])
		ClassUnlock.choose_starters([relic])
		Save.d["arch"] = relic      # (the put-on-the-Relic moment is a cinematic: skipped, it is not the garden)
		Save.d["cls"] = Arch.weight(relic)
		Save.d["weapon"] = Arch.signature(relic)
		hatch._head_out(false)
	await _wait(func(): return main.current != null and main.current.get("kins") != null, 120.0)
	var home = main.current
	await _wait(func(): return not home.building and is_instance_valid(home.root_ui), 60.0)
	main.fade.reveal(0.01)
	clock = 0.0
	await _play(home)
	say("end")
	Engine.time_scale = 1.0
	main.get_tree().quit()

## Real-time wait (TIME_SCALE does not stretch it) until `cond` holds or `limit_s` of it passes.
func _wait(cond: Callable, limit_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > limit_s * TIME_SCALE:
			return false
		await main.get_tree().process_frame
	return true

## Lets `secs` of game time pass, shooting on the 5-minute marks.
func _idle(secs: float) -> void:
	var end := clock + secs
	while clock < end:
		await main.get_tree().process_frame
		clock += main.get_process_delta_time() * TIME_SCALE
		if clock >= next_shot:
			await _shot()

func _shot() -> void:
	next_shot += SHOT_EVERY_S
	shot_n += 1
	if DisplayServer.get_name() == "headless":
		say("shot %d (headless: none)" % shot_n)
		return
	await RenderingServer.frame_post_draw
	var f := dir.path_join("play_%02dmin.png" % int(round(clock / 60.0)))
	main.get_viewport().get_texture().get_image().save_png(f)
	say("shot %s" % f)

func _play(home) -> void:
	var rec: Dictionary = Save.active_kin()
	say("home: %d Boki out, items %s, gems %d, zones %s"
			% [home.kins.size(), str(Save.d["items"]), Save.d["gems"], str(Save.d["zones"].keys())])
	var goals: Array = GoalTracker.lines().map(func(r): return "%s %d/%d" % [r["text"], r["have"], r["need"]])
	say("tutorial %s; goals %s" % [str(Save.d["tutorial"]), str(goals)])
	var step := FarmTutorial.current()
	say("farm tutorial: active %s, step '%s', hint '%s'" % [FarmTutorial.active(), step, FarmTutorial.hint_text(step)])
	await _idle(10.0)
	var k: Dictionary = home.kins[0]
	var joy := Care.need(rec, "joy")
	home._pet_kin(k)
	say("pet: joy %.0f -> %.0f, trust %.0f" % [joy, Care.need(rec, "joy"), float(rec.get("trust", 0))])
	var food := "kibble"
	say("food in bag %s (the tutorial hands it out at its feed step: gift %s)"
			% [str(Save.d["items"]), str(FarmTutorial.state()["gift"])])
	say("feed: needs %s, has kibble %s" % [str(rec["needs"]), str(Save.d["items"].get(food, 0))])
	rec["needs"]["food"] = 30.0
	home._care_feed(rec, food)
	say("fed: food now %.0f, first-day %s" % [Care.need(rec, "food"), str(GardenFirstDay.did("feed"))])
	await _idle(SHOT_EVERY_S - clock + 1.0)
	await _games(home)
	await _idle(SHOT_EVERY_S * 2.0 - clock + 1.0)
	await _breed(home)
	await _idle(SHOT_EVERY_S * 3.0 - clock + 1.0)
	await _zone(home)
	await _idle(TOTAL_S - clock + 1.0)

## The garden games, each started as the post's own prompt would be; a refused start is a gap in the loop.
func _games(home) -> void:
	for id in ["race", "shove", "seek", "volley"]:
		var g = {"race": home.hrace, "shove": home.hshove, "seek": home.hseek, "volley": home.hvolley}[id]
		say("game %s: '%s', Boki able to enter %d" % [id, g.label(), home.hrace.entrants().size()])
		g.use()
		var started: bool = g.get("run") != null
		say("game %s: %s" % [id, "started" if started else "REFUSED (needs a second Boki)"])
		if started and id == "race":
			var t := 0.0
			while g.get("run") != null and t < 120.0:
				g.tick(0.1)
				t += 0.1
			say("race finished in %.0f s, first-day %s" % [t, str(Save.d["tutorial"]["gfd"]["did"].keys())])
		elif started:
			g.tick(0.1)
			await _idle(5.0)

## Breeding: what the Nook says to a one-Boki player, then a stand-in partner at the Grown level, an egg and its hatch.
func _breed(home) -> void:
	var rec: Dictionary = Save.active_kin()
	say("breed: level %d (Grown %d), can_pair '%s', roster %d"
			% [int(rec["level"]), NookRules.GROWN_LV, NookRules.can_pair(rec), Save.d["roster"].size()])
	var mate := Save.new_kin("puddlet", "Drip")
	mate["level"] = NookRules.GROWN_LV
	mate["trust"] = 60.0
	Care.ensure(mate)
	rec["level"] = NookRules.GROWN_LV
	say("breed: stand-in mate added (a one-Boki save has no second Boki), why '%s'" % NookRules.pair_why(rec, mate))
	(Save.d["roster"] as Array).append(mate)
	home._make_egg(rec, mate)
	say("breed: egg %s, first-day pair %s" % [str(Save.d.get("egg", {}).keys()), str(GardenFirstDay.did("pair"))])
	Save.d["egg"]["t"] = 0.0
	home._hatch_nest_egg()
	await _idle(20.0)
	say("breed: roster now %d, egg left %s" % [Save.d["roster"].size(), str(Save.d.get("egg", {}))])

## A second zone: what opens it, then the first closed one woken and visited.
func _zone(home) -> void:
	var ids: Array = GardenZones.ids().filter(func(z): return z != GardenZones.start())
	say("zone: open %s; keys for %s: %s" % [str(Save.d["zones"].keys()), ids[0], str(GardenZones.keys_for(ids[0]))])
	GardenZones.wake(ids[0])
	Game.goto("home", {"zone": ids[0]})
	var ok := await _wait(func(): return _arrived(home), 120.0)
	say("zone: %s arrived %s" % [ids[0], str(ok)])
	main.fade.reveal(0.01)

func _arrived(old) -> bool:
	var cur = main.current
	return cur != null and cur != old and cur.get("kins") != null and not cur.building
