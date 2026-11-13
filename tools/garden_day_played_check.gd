extends RefCounted
## --garden-day-played-check [--shots-dir=<dir>] (docs/GARDEN_DAY_PLAYED.md): one garden day on the --base-demo
## seed, driven through the real farm screens (Game.goto, the feed menu, the Dash, Stump Shove, the Nesting Nook,
## the Waystone and the zone cards, the away card). Each beat prints "GDAY ok/FAIL/NOTE": FAIL is a break, NOTE
## is a dead end or a confusing screen worth listing. With --shots-dir (needs a renderer) it saves a frame per beat.
## Never touches the real save.

const WAIT_S := 30.0         # s to wait for a home to finish building
const GAME_S := 90.0         # s (real time) one Dash or shove may take before the beat gives up
const MAX_RACES := 12        # Dash races tried for the Crown
const TIME_SCALE := 4.0      # game seconds per real second while a race or a walk runs
const AWAY_S := 28800.0      # s: the simulated gap (8 hours)
const FOE_RATIO := 1.15      # the rivals' trained stats, over the partner's (a cup round needs 1.1)
const PAIR_LEVEL := 8        # Grown: the level a Boki needs to pair

var bad := 0
var main: Node
var dir := ""
var shot_n := 0

func ok(cond: bool, what: String) -> void:
	print("GDAY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func note(what: String) -> void:
	print("GDAY NOTE %s" % what)

## Seconds of wall time: a renderer runs slow frames, so the waits count real time.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _grab(label: String) -> void:
	if dir == "":
		return
	main.fade.reveal(0.01)      # the boot logo and the ink wipe stay up until asked
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
		if cur != was and is_instance_valid(cur) and cur.get("hway") != null and cur.get("player") != null \
				and cur.get("building") != true and cur.get("root_ui") != null and not Game.main.fade.covered:
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
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
			DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	seed(5)
	var d := BaseDemo.save()
	d["zones"]["cinderstep"] = {"open": true}      # the second zone the day plays in
	var real := Save.path_for(Save.slot)
	var before := FileAccess.get_md5(real)
	Game.goto("home", {"zone": "bramblebank"})
	var bb = await _arrived(Game.main.current)
	ok(bb != null and bb.life != null, "the demo base opens in Bramblebank with base life")
	if bb != null and bb.life != null:
		await _morning(bb)
		await _dash_and_cup(bb)
		await _nook(bb)
		await _zone_move(bb)
		var cs = await _second_game(bb)
		if cs != null:
			await _away(cs)
	ok(FileAccess.get_md5(real) == before, "the real save file is untouched")
	Engine.time_scale = 1.0
	print("GDAY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

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
	# the cup compares stat totals, the race runs on Speed: Pip is fast, the rivals have the bigger total
	pip["stats"] = {"power": 10, "guard": 10, "speed": 70, "focus": 10}
	for nm in ["Moss", "Ash", "Rocky"]:
		pip["bonds"].erase(_rec(nm)["uid"])      # friends run together (a pull): the cup run is against strangers
		_rec(nm)["bonds"].erase(pip["uid"])
	var foe_each := ceili(float(GardenPrizes.strength(pip)) * FOE_RATIO - 8.0) / 3
	for nm in ["Moss", "Ash", "Rocky"]:
		_rec(nm)["stats"] = {"power": foe_each, "guard": foe_each, "speed": 8, "focus": foe_each}
	Engine.time_scale = TIME_SCALE
	var races := 0
	var wins := 0
	var seen_card := ""
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
		if races == 1:
			seen_card = _labels(bb.hrace.card) if is_instance_valid(bb.hrace.card) else ""
			Engine.time_scale = 1.0
			await _grab("dash_card")
			Engine.time_scale = TIME_SCALE
		if int(Save.d["gems"]) - gems >= 6:
			wins += 1
		bb.hrace.card_t = 0.0
	Engine.time_scale = 1.0
	ok(seen_card != "", "a result card follows the first race: %s" % seen_card.left(120))
	var crowned: bool = GardenPrizes.ribbon_count(pip, "dash") > 0
	var stage := GardenPrizes.stage(pip, "dash")
	ok(crowned, "the Dash Crown is won (%d of %d races won, cup stage %d)" % [wins, races, stage])
	if not crowned:
		note("no Crown in %d races (Pip fast, rivals %.2fx the total): Pip won %d" % [races, FOE_RATIO, wins])
	await _grab("after_dash")

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
	await _wait(0.5)
	var gems: int = int(Save.d["gems"])
	if cs.hshove == null or cs.hshove.stump == null:
		note("Cinderstep has no Stump Shove stump on this build")
		return cs
	cs.hshove.use()
	ok(cs.hshove.run != null, "Stump Shove starts at the stump")
	if cs.hshove.run != null:
		await _grab("shove")
		Engine.time_scale = TIME_SCALE
		var t0 := _now()
		var t := 0.0
		while cs.hshove.run != null and t < GAME_S:
			await main.get_tree().process_frame
			t = _now() - t0
			if cs.hshove.run != null and cs.hshove.run.can_shove():
				_press(cs.hshove)
		Engine.time_scale = 1.0
		ok(cs.hshove.run == null, "the shove ends (%.1f s)" % t)
		await _grab("shove_card")
		ok(int(Save.d["gems"]) > gems, "gems paid (%d to %d)" % [gems, int(Save.d["gems"])])
		cs._close_panel()
	return cs

## Back after eight hours: the card, the gifts, nobody lost.
func _away(cs) -> void:
	for r in Save.d["roster"]:
		r["needs_t"] = float(r.get("needs_t", 0.0)) - AWAY_S
		for e in r.get("journal", []):
			e["t"] = float(e["t"]) - AWAY_S
	Save.d["away_seen"] = float(Save.d.get("away_seen", Time.get_unix_time_from_system())) - AWAY_S
	var n: int = (Save.d["roster"] as Array).size()
	Game.goto("home", {"zone": "bramblebank"})
	var bb = await _arrived(cs)
	ok(bb != null, "back in Bramblebank after the gap")
	if bb == null:
		return
	await _wait(1.5)
	var text := _labels(bb.root_ui)
	ok(bb.panel_open == "While you were away", "the away card opens (%s)" % bb.panel_open)
	await _grab("away_card")
	print("GDAY card: ", text.substr(maxi(0, text.find("While you were away")), 900))
	ok("Moss trained" not in text, "Moss lives in Cinderstep: it does not train at Bramblebank's toys while away")
	ok("starv" not in text.to_lower() and "lost" not in text.to_lower(), "the card never says lost or starved")
	ok((Save.d["roster"] as Array).size() == n, "nobody left the roster during the gap")
	var worst := 100.0
	for r in Save.d["roster"]:
		worst = minf(worst, Care.need(r, "food"))
	note("lowest food after the gap: %d" % int(worst))
	bb._close_panel()
	await _wait(1.0)
	await _grab("back_home")
