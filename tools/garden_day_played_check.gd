extends RefCounted
## --garden-day-played-check [--shots-dir=<dir>] (docs/GARDEN_DAY_PLAYED.md): one garden day on the --base-demo
## seed, driven through the real farm screens (Game.goto, the feed menu, the Dash, Stump Shove, the Nesting Nook,
## the Waystone and the zone cards, the away card). Each beat prints "GDAY ok/FAIL/NOTE": FAIL is a break, NOTE
## is a dead end or a confusing screen worth listing. With --shots-dir (needs a renderer) it saves a frame per beat.
## Never touches the real save.

const WAIT_S := 30.0  # s to wait for a home to finish building
const GAME_S := 90.0  # s (real time) one Dash or shove may take before the beat gives up
const MAX_RACES := 24  # Dash races tried for the Crown
const TIME_SCALE := 4.0  # game seconds per real second while a race or a walk runs
const AWAY_S := 28800.0  # s: the simulated gap (8 hours)
const FOE_RATIO := 1.1  # the rivals' Speed, over Pip's (a cup round needs 1.1)
const STALL_S := 60.0  # game s a walk, nap or menu may take before it is a stall
const FOOD_S := 120.0  # game s a hungry Boki may take to reach food (a play or a nap may finish first)
const PLAIN_KEYS := ["rec", "node", "pos", "goal", "emote", "life", "pers", "say"]  # a kin entry's usual keys
const HUNGRY_FOOD := 10.0  # the food need the bowl beat starts them at
const ATE_GAIN := 15.0  # a snack gives at least this (Emberberry: about +25)
const PAIR_LEVEL := 8  # Grown: the level a Boki needs to pair

var bad := 0
var main: Node
var dir := ""
var shot_n := 0
var only: PackedStringArray = []  # --beats=food,nap: run just these beats (all when empty)


func _want(beat: String) -> bool:
	return only.is_empty() or beat in only


func ok(cond: bool, what: String) -> void:
	print("GDAY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func note(what: String) -> void:
	print("GDAY NOTE %s" % what)


## Seconds of wall time: a renderer runs slow frames, so the waits count real time.
func _now() -> float:
	return CheckClock.own_msec() / 1000.0


func _grab(label: String) -> void:
	if dir == "":
		return
	main.fade.reveal(0.01)  # the boot logo and the ink wipe stay up until asked
	await _wait(1.5)
	await main.get_tree().process_frame
	shot_n += 1
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("%02d_%s.png" % [shot_n, label]))
	print("GDAY shot %02d_%s" % [shot_n, label])


func _wait(secs: float) -> void:
	var t0 := _now()
	var t := 0.0
	while t < secs:
		await main.get_tree().process_frame
		t = _now() - t0


## The home a goto started, once it is built and revealed; null on a timeout.
func _arrived(was: Node):
	var t0 := _now()
	var t := 0.0
	while t < WAIT_S:
		await main.get_tree().process_frame
		t = _now() - t0
		var cur = Game.main.current
		if (
			cur != was
			and is_instance_valid(cur)
			and cur.get("hway") != null
			and cur.get("player") != null
			and cur.get("building") != true
			and cur.get("root_ui") != null
			and not Game.main.fade.covered
		):
			return cur
	return null


func _snap(rec: Dictionary) -> String:
	return JSON.stringify([rec["stats"], rec.get("lean"), rec["needs"], rec["level"]])


func _rec(nm: String) -> Dictionary:
	return (Save.d["roster"] as Array).filter(func(r): return String(r["name"]) == nm)[0]


func _labels(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + " | "
	elif n is Button:
		out += (n as Button).text + " | "
	for c in n.get_children():
		out += _labels(c)
	return out


func _rest_all() -> void:
	for r in Save.d["roster"]:
		r["needs"]["energy"] = 100.0
		r["needs"]["food"] = 95.0


func _press(game) -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	game.input(ev)


func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--beats="):
			only = String(a).substr(8).split(",")
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
			DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	seed(5)
	var d := BaseDemo.save()
	d["zones"]["cinderstep"] = {"open": true}  # the second zone the day plays in
	var real := Save.path_for(Save.slot)
	var before := FileAccess.get_md5(real)
	Game.goto("home", {"zone": "bramblebank"})
	var bb = await _arrived(Game.main.current)
	ok(bb != null and bb.life != null, "the demo base opens in Bramblebank with base life")
	if bb != null and bb.life != null:
		if _want("morning"):
			await _morning(bb)
		if _want("loot"):
			await _loot_react(bb)
		if _want("dash"):
			await _dash_and_cup(bb)
		if _want("fetch"):
			await _fetch(bb)
		if _want("food"):
			await _food(bb)
		if _want("nap"):
			await _nap(bb)
		if _want("nook"):
			await _nook(bb)
		if _want("zone"):
			await _zone_move(bb)
		var cs = await _second_game(bb)
		if cs != null:
			if _want("away"):
				await _away(cs)
			var was = Game.main.current
			Game.goto("home", {"zone": "bramblebank"})
			var back = await _arrived(was)
			ok(back != null, "back in Bramblebank for the hatch")
			if back != null:
				await _hatch(back)
	ok(FileAccess.get_md5(real) == before, "the real save file is untouched")
	Engine.time_scale = 1.0
	print("GDAY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## Row: you come home from an expedition with a garden item kind you never had. The nearest free Boki walks up, reacts
## and says a line, its journal keeps one line, no pop-up opens, and the same kind is not news a second time.
func _loot_react(bb) -> void:
	FarmChatter._look_t = 0.0
	FarmChatter.tick(bb, 0.01)  # the farm learns who is home and what is in the bag
	ComeLook._looks.clear()
	var panel: String = bb.panel_open
	Save.d["items"]["hushpearl"] = int(Save.d["items"].get("hushpearl", 0)) + 1
	Save.d["extracts"] = int(Save.d.get("extracts", 0)) + 1
	FarmChatter._look_t = 0.0
	FarmChatter.tick(bb, 0.01)
	var looks: Array = ComeLook._looks.duplicate()
	ok(
		looks.size() == 1 and looks[0]["kind"] == "item",
		"react: one Boki walks up to the new Hushpearl (%d)" % looks.size()
	)
	if looks.is_empty():
		return
	var k: Dictionary = looks[0]["k"]
	var t0 := _now()
	while ComeLook._looks.has(looks[0]) and _now() - t0 < 25.0:
		await main.get_tree().process_frame
	var lines: Array = (k["rec"].get("journal", []) as Array).map(func(e): return CareJournal.text(e))
	var said := lines.any(func(t): return String(t).ends_with("the new Hushpearl"))
	ok(said, "react: %s's journal: %s" % [k["rec"]["name"], lines[-1]])
	ok(bb.panel_open == panel, "react: no pop-up opened")
	ok(Save.d["tutorial"].get(ComeLook.ITEM_KEY + "hushpearl", false), "react: the kind is marked, once per save")
	await _grab("loot_react")


## Arrival, the feed menu's preview, feeding an item.
func _morning(bb) -> void:
	await _grab("arrival")
	var card := String(bb.panel_open)
	if card != "":
		note("on arrival a '%s' panel is open over the base: %s" % [card, _labels(bb.root_ui).left(90)])
	bb._close_panel()
	BaseDemo.new().stage(bb)
	var pip := _rec("Pip")
	Save.add_item("zipseed", 1)
	Save.add_item("bramble_honey", 1)
	Save.add_item("heirloom_thread", 1)
	await _wait(1.0)
	var snap := _snap(pip)
	bb._open_feed(pip)
	var text := _labels(bb.root_ui)
	ok(bb.panel_open == "Feed Pip" and "Zipseed" in text, "the feed menu lists the Zipseed")
	var pv := GardenItems.preview(pip, "zipseed")
	ok(pv["ok"] and String(pv["text"]) in text, "the row shows the exact preview line: %s" % pv["text"])
	ok(_snap(pip) == snap, "looking at the preview changes nothing")
	if "Heirloom" not in text:
		note("the Nest item (Heirloom Thread) has no row in the feed menu and nothing here says it works in the Nook")
	await _grab("feed_menu")
	var stat := String(GardenItems.item("zipseed")["effect"]["stat"])
	var was: int = int(pip["stats"][stat])
	bb._care_feed(pip, "zipseed")
	await _wait(0.5)
	var now: int = int(pip["stats"][stat])
	var gain := int(GardenItems.item("zipseed")["effect"]["n"])
	ok(now == mini(was + gain, Care.stat_cap(pip)), "feeding adds the preview (%s %d to %d)" % [stat, was, now])
	ok(int(Save.d["items"].get("zipseed", 0)) == 0, "the Zipseed left the bag")
	ok(pip["journal"].any(func(e): return "Zipseed" in String(CareJournal.text(e))), "the journal has the line")
	await _grab("fed")
	bb._close_panel()


## The Dash until the backed Boki takes the Crown (three wins in a row against stronger rivals).
func _dash_and_cup(bb) -> void:
	var pip := _rec("Pip")
	# the cup compares the game's own stat (Speed for the Dash): Pip is fast, the rivals are FOE_RATIO times as fast
	pip["stats"] = {"power": 10, "guard": 10, "speed": 70, "focus": 10}
	for nm in ["Moss", "Ash", "Rocky"]:
		pip["bonds"].erase(_rec(nm)["uid"])  # friends run together (a pull): the cup run is against strangers
		_rec(nm)["bonds"].erase(pip["uid"])
	var foe_speed := ceili(float(pip["stats"]["speed"]) * FOE_RATIO)
	for nm in ["Moss", "Ash", "Rocky"]:
		_rec(nm)["stats"] = {"power": 8, "guard": 8, "speed": foe_speed, "focus": 8}
	Engine.time_scale = TIME_SCALE
	var races := 0
	var wins := 0
	var seen_card := ""
	var progressed := false  # a Dash win over a rival 1.1x as fast moved the cup on
	while races < MAX_RACES and GardenPrizes.ribbon_count(pip, "dash") == 0:
		races += 1
		_rest_all()
		await _wait(0.4)
		var gems: int = int(Save.d["gems"])
		bb.hrace.use()
		if bb.hrace.run == null:
			ok(false, "the Dash starts from the post (race %d)" % races)
			break
		var t0 := _now()
		var t := 0.0
		while bb.hrace.run != null and t < GAME_S:
			await main.get_tree().process_frame
			t = _now() - t0
			if bb.hrace.run != null and bb.hrace.run.cheered < 3 and t > 1.0 + 3.0 * bb.hrace.run.cheered:
				_press(bb.hrace)
		if bb.hrace.run != null:
			ok(false, "race %d finished within %.0f s" % [races, GAME_S])
			break
		var lap := "the practice lap, no card" if races == 1 else "paid"
		print("GDAY TIME dash race %d: %.1f s (%s)" % [races, t * TIME_SCALE, lap])
		if seen_card == "" and races > 1:  # race 1 is the first-race practice lap: it never pays and shows no card
			seen_card = _labels(bb.hrace.card) if is_instance_valid(bb.hrace.card) else ""
			Engine.time_scale = 1.0
			await _grab("dash_card")
			Engine.time_scale = TIME_SCALE
		if int(Save.d["gems"]) - gems >= 6:
			wins += 1
		progressed = progressed or GardenPrizes.stage(pip, "dash") > 0
		bb.hrace.card_t = 0.0
	Engine.time_scale = 1.0
	ok(seen_card != "", "a result card follows the first paying race: %s" % seen_card.left(120))
	var crowned: bool = GardenPrizes.ribbon_count(pip, "dash") > 0
	var stage := GardenPrizes.stage(pip, "dash")
	# rivals 1.1x as fast are beaten about one race in four: the Crown (3 in a row) is a streak, so the beat
	# asks for the cup to have moved on (Speed is what it compares); the Crown itself is in --garden-prizes-check
	ok(
		crowned or progressed,
		"the Dash cup moves on Speed (%d of %d races won, crowned %s, stage %d)" % [wins, races, crowned, stage]
	)
	if not crowned:
		note("no Crown in %d races (Pip fast, rivals %.2fx the Speed): Pip won %d" % [races, FOE_RATIO, wins])
	await _grab("after_dash")


## Game seconds (the process delta, so the time scale counts) until `cond` holds; -1 when `cap` runs out first.
func _until(cond: Callable, cap: float) -> float:
	var t := 0.0
	while t < cap:
		if cond.call():
			return t
		await main.get_tree().process_frame
		t += main.get_process_delta_time()
	return -1.0


## Prints the seconds a beat took; a beat that never ended is a stall (FAIL).
func _took(what: String, secs: float, cap: float) -> void:
	if secs < 0.0:
		ok(false, "STALL %s: not done after %.0f s" % [what, cap])
	else:
		ok(true, "%s (%.1f s)" % [what, secs])
		print("GDAY TIME %s: %.1f s" % [what, secs])


## Hungry Boki walk to a bowl and eat; a menu left open or a Boki that never gets there is a stall.
func _food(bb) -> void:
	bb.day_t = 0.3  # the Dash and the Fetch Cup ran the clock on to night, when sleepers sleep till dawn
	_rest_all()
	Save.d["crops"]["emberberry"] = 5
	var c: Vector3 = bb.world.random_ground(0)
	var bowl := {"id": FeedBowl.ID, "u": 990100, "x": int(c.x), "z": int(c.z), "r": 0}
	Save.d["layout"]["deco"].append(bowl)
	bb.hb._sync_deco()
	c = FeedBowl.at(bowl)
	var hungry := ["Moss", "Ash", "Rocky"]
	var n := 0
	for k in bb.kins:
		for key in ["indoors", "leap", "exiting", "going_in", "called_t", "busy", "eat", "nap_go", "job"]:
			k.erase(key)
		if String(k["rec"]["name"]) in hungry:
			k["rec"]["needs"]["food"] = HUNGRY_FOOD
			k["nap_t"] = 0.0
			k["t"] = 0.0
			k["pos"] = bb.world.free_spot_near(c + Vector3(3.0 + n, 0, 2.0), [], 0.6)
			(k["node"] as Node3D).position = k["pos"]
			n += 1
	for nm in ["Moss", "Ash"]:  # hungry and tired: they are asleep when the snacks land
		bb.life._nap(bb._kin_entry(_rec(nm)), "tired")
	await _wait(1.0)
	bb.ppos = Vector3(-500, 0, -500)  # you are away: nobody follows you instead of eating
	var far := {}  # a Boki past the bowl's reach when the snacks land (it napped at a far spot): open, see the doc
	for k in bb.kins:
		var away := Vector2(c.x - k["pos"].x, c.z - k["pos"].z).length()
		if String(k["rec"]["name"]) in hungry and away > FeedBowl.reach(HUNGRY_FOOD):
			far[String(k["rec"]["name"])] = away
			var who := String(k["rec"]["name"])
			note("%s napped %.0f m from the bowl: past its reach, so it does not answer" % [who, away])
	for _i in 3:
		FeedBowl.drop(bb, bowl)
	ok(FeedBowl.snacks(bowl).size() == 3, "three snacks are in the bowl")
	Engine.time_scale = TIME_SCALE
	var fed := {}  # name -> game s when its food rose by a snack
	var trace := {}  # name -> the machine's state every 10 s
	var t := 0.0
	var last_t := -10.0
	while t < FOOD_S and fed.size() < hungry.size():
		await main.get_tree().process_frame
		t += main.get_process_delta_time()
		if t - last_t >= 10.0:
			last_t = t
			for nm in hungry:
				var kk: Dictionary = bb._kin_entry(_rec(nm))
				var st: String = bb.life.machine(kk).state_name().left(4)
				trace[nm] = String(trace.get(nm, "")) + " " + st + ("*" if bb.life.night else "")
		for nm in hungry:
			if not fed.has(nm) and Care.need(_rec(nm), "food") >= HUNGRY_FOOD + ATE_GAIN:
				fed[nm] = t
	for nm in hungry:
		var secs: float = float(fed.get(nm, -1.0))
		if far.has(nm):
			continue
		if secs < 0.0 and String(_rec(nm).get("likes", {}).get("hates", "")) == "emberberry":
			note("%s hates Emberberry, the only snack here: it stays hungry (by design, open)" % nm)
			continue
		_took("%s walks to the bowl and eats" % nm, secs, FOOD_S)
		var limit := STALL_S
		ok(secs >= 0.0 and secs <= limit, "%s reaches the bowl within %.0f s, asleep or not" % [nm, limit])
		if secs < 0.0 or secs > STALL_S * 0.5:
			var k: Dictionary = bb._kin_entry(_rec(nm))
			note(
				(
					"%s: keys %s t %.1f, likes %s, states per 10 s [%s ] (* night), now %s, life_eat %s, "
					+ "food %.0f, %.1f m from the bowl, busy %s, indoors %s"
				)
				% [
					nm,
					str(k.keys().filter(func(x): return x not in PLAIN_KEYS)),
					float(k.get("t", 0.0)),
					str(_rec(nm).get("likes", {})),
					trace.get(nm, ""),
					bb.life.machine(k).state_name(),
					str(k.get("life_eat", {})),
					Care.need(_rec(nm), "food"),
					Vector2(c.x - k["pos"].x, c.z - k["pos"].z).length(),
					k.get("busy", false),
					k.has("indoors")
				]
			)
	var done: float = await _until(func(): return bb.kins.all(func(k): return FeedBowl.phase(k) == ""), STALL_S)
	_took("everyone is done at the bowl", done, STALL_S)
	Engine.time_scale = 1.0
	bb.ppos = bb.player.position
	await _grab("food")


## A tired Boki is told to nap: it goes to bed (or lies down) and is rested and up again.
func _nap(bb) -> void:
	bb.day_t = 0.42
	var rec := _rec("Rocky")
	rec["needs"]["energy"] = 12.0
	var k: Dictionary = bb._kin_entry(rec)
	for key in ["busy", "indoors", "job"]:
		k.erase(key)
	bb._care_nap(rec)
	Engine.time_scale = TIME_SCALE
	var lying := func() -> bool: return float(k.get("nap_t", 0.0)) > 0.0 or bb.life.machine(k).state_name() == "NAP"
	var down: float = await _until(lying, STALL_S)
	_took("Rocky lies down for the nap (bed %s)" % k.has("bed"), down, STALL_S)
	var rested := func() -> bool: return Care.need(rec, "energy") > 50.0 and float(k.get("nap_t", 0.0)) <= 0.0
	var up: float = await _until(rested, 120.0)
	_took("Rocky wakes rested (energy %.0f)" % Care.need(rec, "energy"), up, 120.0)
	Engine.time_scale = 1.0


## Fetch Cup: a 60 s round at the toss mat, the head-start press, the result card, the card going away.
func _fetch(bb) -> void:
	if bb.hfetch != null and bb.hfetch.mat == null:  # the mat lies by the Training post: the demo has none yet
		bb.hg.demo_place("training_post", HomeLayout.LANDING + Vector3(6, 0, 6))
		bb._sync_fixtures()
		bb.hfetch.place()
	if bb.hfetch == null or bb.hfetch.mat == null:
		note("this base has no Fetch Cup mat")
		return
	_rest_all()
	await _wait(0.4)
	var gems: int = int(Save.d["gems"])
	bb.hfetch.use()
	ok(bb.hfetch.run != null, "Fetch Cup starts at the mat")
	if bb.hfetch.run == null:
		return
	Engine.time_scale = TIME_SCALE
	_press(bb.hfetch)  # the head-start call
	var secs: float = await _until(func(): return bb.hfetch.run == null, GAME_S)
	_took("the Fetch Cup round ends", secs, GAME_S)
	if bb.hfetch.run != null:
		bb.hfetch.input(_menu_key())  # a stalled round is left with the menu key
	var shown := is_instance_valid(bb.hfetch.card)
	var line := _labels(bb.hfetch.card).left(100) if shown else ""
	ok(shown, "a Fetch Cup result card shows: %s" % line)
	Engine.time_scale = 1.0
	await _grab("fetch_card")
	Engine.time_scale = TIME_SCALE
	var gone: float = await _until(func(): return not is_instance_valid(bb.hfetch.card), STALL_S)
	_took("the Fetch Cup card closes by itself", gone, STALL_S)
	Engine.time_scale = 1.0
	note("Fetch Cup paid %d gems" % (int(Save.d["gems"]) - gems))


func _menu_key() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = "menu"
	ev.pressed = true
	return ev


## The Nook egg is ready: the hatch plays, the Boki meets you, you name it, the screen is clear again.
func _hatch(bb) -> void:
	Save.d["egg"]["t"] = 0.0
	ok(bb._egg_ready(), "the nest egg is ready")
	var n: int = (Save.d["roster"] as Array).size()
	Engine.time_scale = TIME_SCALE
	bb._hatch_nest_egg()
	var reveal = null
	var secs: float = await _until(
		func():
			for c in bb.get_children():
				if c is KinReveal and c.ready_to_name:
					reveal = c
					return true
			return false,
		STALL_S
	)
	_took("the egg hatches and the Boki's card is up", secs, STALL_S)
	ok((Save.d["roster"] as Array).size() == n + 1, "the roster has the hatchling")
	if reveal == null:
		bb.panel_open = ""
		return
	Engine.time_scale = 1.0
	await _grab("hatch_card")
	Engine.time_scale = TIME_SCALE
	reveal._go()
	var naming := func() -> bool: return bb.panel_open != "reveal" and bb.panel_host.get_child_count() > 0
	var named: float = await _until(naming, STALL_S)
	_took("the naming card opens", named, STALL_S)
	var step: Node = _find_step(bb.panel_host)
	ok(step != null, "the naming step is on screen")
	if step != null:
		step.keep()
	var clear: float = await _until(func(): return bb.panel_open == "" and not bb.building_now, STALL_S)
	_took("the screen is clear after naming", clear, STALL_S)
	Engine.time_scale = 1.0


func _find_step(n: Node) -> Node:
	if n is NameStep:
		return n
	for c in n.get_children():
		var r := _find_step(c)
		if r != null:
			return r
	return null


## Two Boki in the Nook: the gate a fresh Boki hits, then the pair.
func _nook(bb) -> void:
	var a := _rec("Pip")
	var b := _rec("Moss")
	var why: String = NookRules.pair_why(a, b)
	note("the demo's friends are level %d: the Nook says '%s'" % [int(a["level"]), why])
	ok(why != "", "a level-%d pair is refused with a reason" % int(a["level"]))
	bb._open_nook()
	await _grab("nook_gated")
	var tag := "lv %d needed" % NookRules.GROWN_LV
	ok(tag in _labels(bb.root_ui).to_lower(), "the Nook tile says the real level it needs")
	bb._close_panel()
	for r in [a, b]:
		r["level"] = PAIR_LEVEL
		r["needs"]["energy"] = 100.0
		r["trust"] = 90.0
	BaseLife.add_bond(a, b, 0.9)
	why = NookRules.pair_why(a, b)
	ok(why == "", "at level %d and close, the pair is allowed (%s)" % [PAIR_LEVEL, why])
	bb.nook_tab = "Pairs"
	bb.nook_pick = [a["uid"], b["uid"]]
	bb._open_nook()
	await _grab("nook_pair")
	ok("Pair Pip and Moss" in _labels(bb.root_ui), "the button names the pair")
	bb._close_panel()
	bb._make_egg(a, b)
	ok(not Save.d["egg"].is_empty(), "an egg is in the nest")
	await _wait(0.5)
	await _grab("egg_in_nest")


## Moss walks to the pad and goes to live in Cinderstep.
func _zone_move(bb) -> void:
	var moss := _rec("Moss")
	var k: Dictionary = bb._kin_entry(moss)
	ok(not k.is_empty(), "Moss is out on the farm")
	if k.is_empty():
		return
	ZoneCards.move_to(bb, k)
	ok(bb.panel_open == "Move Moss to..." and "Cinderstep" in _labels(bb.root_ui), "Move to... lists Cinderstep")
	await _grab("move_cards")
	bb._close_panel()
	ok(bb.hway.send(k, "cinderstep") == "", "Moss is sent to Cinderstep")
	Engine.time_scale = TIME_SCALE
	var t0 := _now()
	var t := 0.0
	while bb.kins.has(k) and t < GAME_S:
		await main.get_tree().process_frame
		t = _now() - t0
	Engine.time_scale = 1.0
	ok(not bb.kins.has(k) and GardenZones.zone_of(moss) == "cinderstep", "it walks to the pad and goes (%.1f s)" % t)
	await _grab("moss_leaving")


## Hop to Cinderstep with the partner; Pip and Moss play Stump Shove there. Returns the Cinderstep home.
func _second_game(bb):
	ok(bb.hway.hop(GardenZones.HUB), "the return pad takes you to the hub")
	var hub = await _arrived(bb)
	ok(hub != null and hub.zone == GardenZones.HUB, "the hub loads")
	if hub == null:
		return null
	await _grab("hub")
	hub._close_panel()
	await _grab("hub_clear")
	ok(hub.hway.hop("cinderstep"), "the Waystone hop to Cinderstep starts")
	var cs = await _arrived(hub)
	ok(cs != null and cs.zone == "cinderstep", "Cinderstep loads")
	if cs == null:
		return null
	var names: Array = cs.kins.map(func(k): return String(k["rec"]["name"]))
	names.sort()
	ok(names == ["Moss", "Pip"], "Cinderstep has Pip (with you) and Moss (lives there): %s" % str(names))
	await _grab("cinderstep")
	cs._close_panel()
	await _grab("cinderstep_clear")
	_rest_all()
	# an evolution that was waiting plays on arrival (Pip busy, then its card): close it and wait for two free Boki
	var free: float = await _until(
		func():
			if not cs.building_now and cs.panel_open != "":
				cs._close_panel()
			return not cs.building_now and cs.hrace.entrants().size() >= 2,
		STALL_S
	)
	_took("two rested Boki are free at the stump", free, STALL_S)
	var gems: int = int(Save.d["gems"])
	if cs.hshove == null or cs.hshove.stump == null:
		note("Cinderstep has no Stump Shove stump on this build")
		return cs
	var who: Array = cs.hrace.entrants()
	cs.hshove.use()
	ok(
		cs.hshove.run != null,
		"Stump Shove starts at the stump (rested Boki out: %s)" % str(who.map(func(k): return k["rec"]["name"]))
	)
	if cs.hshove.run == null:
		for k in cs.kins:
			note(
				(
					"Cinderstep %s: busy %s, indoors %s, energy %.0f, state %s"
					% [
						k["rec"]["name"],
						k.get("busy", false),
						k.has("indoors"),
						Care.need(k["rec"], "energy"),
						cs.life.machine(k).state_name()
					]
				)
			)
	var bouts := 0
	while cs.hshove.run != null and bouts < 2:  # the first bout is a practice one (a press ends it, no gems)
		bouts += 1
		var practice: bool = cs.hshove.practice
		if bouts == 1:
			await _grab("shove")
		Engine.time_scale = TIME_SCALE
		var t := 0.0
		while cs.hshove.run != null and t < GAME_S:
			await main.get_tree().process_frame
			t += main.get_process_delta_time()
			if cs.hshove.run != null and cs.hshove.run.can_shove():
				_press(cs.hshove)
		Engine.time_scale = 1.0
		var kind := "practice " if practice else ""
		_took("the %sshove ends" % kind, -1.0 if cs.hshove.run != null else t, GAME_S)
		if practice:
			_rest_all()
			await _until(func(): return cs.hrace.entrants().size() >= 2, STALL_S)
			cs.hshove.use()
	await _grab("shove_card")
	ok(int(Save.d["gems"]) > gems, "gems paid (%d to %d)" % [gems, int(Save.d["gems"])])
	var gone: float = await _until(func(): return not is_instance_valid(cs.hshove.card), STALL_S)
	_took("the shove card closes by itself", gone, STALL_S)
	cs._close_panel()
	return cs


## Back after eight hours: the card, the gifts, nobody lost.
func _away(cs) -> void:
	for r in Save.d["roster"]:
		r["needs_t"] = float(r.get("needs_t", 0.0)) - AWAY_S
		for e in r.get("journal", []):
			e["t"] = float(e["t"]) - AWAY_S
	Save.d["away_seen"] = float(Save.d.get("away_seen", Time.get_unix_time_from_system())) - AWAY_S
	var marks: Dictionary = Save.d.get("away_zone", {})
	for id in marks:
		marks[id] = float(marks[id]) - AWAY_S  # each zone's own last-arrival mark goes back too
	var n: int = (Save.d["roster"] as Array).size()
	Game.goto("home", {"zone": "bramblebank"})
	var bb = await _arrived(cs)
	ok(bb != null, "back in Bramblebank after the gap")
	if bb == null:
		return
	await _wait(1.5)
	var text := "\n".join(BaseCard.away)  # the lines behind the HUD line
	var line := BaseCard.away_line(BaseCard.away)
	ok(line != "" and bb.panel_open != "While you were away", "the return is one HUD line, no panel (%s)" % line)
	await _grab("away_card")
	print("GDAY card: ", text.substr(maxi(0, text.find("While you were away")), 900))
	ok("Moss trained" not in text, "Moss lives in Cinderstep: it does not train at Bramblebank's toys while away")
	ok("starv" not in text.to_lower() and "lost" not in text.to_lower(), "the card never says lost or starved")
	# row H: two zones open, the lines sit under zone names, and the shared mark does not starve the other zone
	var head := text.find("Bramblebank")
	ok(
		head >= 0 and "Moss saved you" not in text,
		"the Bramblebank card has its own zone name and no gift from Moss, who lives in Cinderstep"
	)
	ok(
		head < 0 or text.find("saved you a snack") < 0 or text.find("saved you a snack") > head,
		"the gifts sit under the zone name"
	)
	var bb_trained := "trained" in text.substr(maxi(0, head))
	ok((Save.d["roster"] as Array).size() == n, "nobody left the roster during the gap")
	var worst := 100.0
	for r in Save.d["roster"]:
		worst = minf(worst, Care.need(r, "food"))
	note("lowest food after the gap: %d" % int(worst))
	bb._close_panel()
	await _wait(1.0)
	await _grab("back_home")
	await _away_cinderstep(bb, bb_trained)


## Row H: the first arrival in Cinderstep after the gap trains Moss at its toys (the Bramblebank arrival did
## not use up Cinderstep's own away mark), under the Cinderstep name.
func _away_cinderstep(bb, bb_trained: bool) -> void:
	Game.goto("home", {"zone": "cinderstep"})
	var cs = await _arrived(bb)
	ok(cs != null and cs.zone == "cinderstep", "back in Cinderstep after the gap")
	if cs == null:
		return
	await _wait(1.5)
	var text := "\n".join(BaseCard.away)
	var line := BaseCard.away_line(BaseCard.away)
	ok(line != "", "Cinderstep has its own return line (%s)" % line)
	print("GDAY cinderstep card: ", text.substr(maxi(0, text.find("While you were away")), 900))
	var head := text.find("Cinderstep")
	var trained := text.find("Moss trained")
	ok(
		trained >= 0 and head >= 0 and head < trained,
		"Moss trains at Cinderstep's toys on that zone's first arrival, under its name"
	)
	note("Bramblebank card trained anyone: %s" % str(bb_trained))
	cs._close_panel()
