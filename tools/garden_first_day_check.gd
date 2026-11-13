extends RefCounted
## --garden-first-day-check: the first-day list in the Goals tracker (GardenFirstDay).
##   1. a fresh save has the list; a save from before it, and a replayed tutorial, have none
##   2. the tracker shows its five lines first, in order, ticked ones last; the card is hidden when done
##   3. ticks are once-only, an unknown id does nothing, the reward is paid once, then the list is gone
##   4. a bot plays a fresh base: feeds a Boki, plays at a toy, runs a race, naps in a pile and pairs two
##      Boki in the Nook, and the list finishes by itself
##   5. the screen stays quiet (GardenHudGroups): day 1 in the hub and two zones shows at most 5 HUD groups and one
##      arrival card; day 5 (a journal, today's wishes) shows one arrival card, the wishes riding on the away card
## Never touches the real save.

const HudGroups := preload("res://tools/garden_hud_groups.gd")

const STEP_S := 0.05      # s of farm time per step
const MAX_STEPS := 4800   # a toy is picked up within 60 s of farm time (toy_check)
const RACE_MAX_S := 120.0

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FIRSTDAY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _fresh_save() -> Dictionary:
	var d := Save.fresh()
	for i in 2:
		var k := Save.new_kin("zapple", ["Pip", "Fen"][i])
		k["level"] = 20
		Care.ensure(k)
		k["traits"]["temper"] = 0.3
		d["roster"].append(k)
	d["active"] = d["roster"][0]["uid"]
	return d

func _ids() -> Array:
	return (GardenFirstDay.rules()["rows"] as Array).map(func(r): return String(r["id"]))

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_list()
	await _bot()
	await _screens()
	print("FIRSTDAY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _screens() -> void:
	var gh := HudGroups.new()
	gh.main = main
	for day in [1, 5]:
		for zone in [""] + HudGroups.ZONES:
			var scr: Dictionary = await gh.screen(day, zone)
			var what := "day %d %s" % [day, zone if zone != "" else "hub"]
			var groups := int(scr["groups"].size())
			if day == 1:
				ok(groups <= HudGroups.DAY1_MAX, "%s: %d HUD groups (at most %d)" % [what, groups, HudGroups.DAY1_MAX])
			var cards: Array = scr["cards"]
			ok(cards.size() <= 1, "%s: %d arrival cards (%s)" % [what, cards.size(), ", ".join(cards)])

func _list() -> void:
	var ids := _ids()
	ok(ids.size() == 5 and ids == ["feed", "toy", "race", "nap", "pair"], "five lines: feed, toy, race, nap, pair")
	Save.d = Save.fresh()
	ok(GardenFirstDay.active() and GardenFirstDay.rows().size() == 5, "a fresh save has the list")
	var old := Save.fresh()
	old["tutorial"] = {"home": true, "day1_done": true}
	Save.d = old
	ok(not GardenFirstDay.active() and GardenFirstDay.rows().is_empty(), "a save from before it has none")
	GardenFirstDay.mark("feed")
	ok(not old["tutorial"].has("gfd"), "and a tick does not start it")
	Save.d = Save.fresh()
	var rows := GoalTracker.lines()
	var texts: Array = (GardenFirstDay.rules()["rows"] as Array).map(func(r): return String(r["text"]))
	ok(rows.size() == 5 and rows.map(func(r): return r["text"]) == texts,
			"the tracker leads with the five lines, in order")
	ok(rows.all(func(r): return r["source"] == "first_day" and int(r["need"]) == 1),
			"one line each, none of them a tutorial step")
	GardenFirstDay.mark("toy")
	rows = GoalTracker.lines()
	ok(int(rows[-1]["have"]) == 1 and rows[-1]["text"] == texts[1] and rows[0]["text"] == texts[0],
			"a ticked line drops to the end")
	GardenFirstDay.mark("toy")
	GardenFirstDay.mark("bogus")
	var gems0 := int(Save.d["gems"])
	ok(Save.d["tutorial"]["gfd"]["did"].size() == 1 and gems0 == int(Save.fresh()["gems"]),
			"a repeat or unknown id does nothing")
	for id in ids:
		ok(GardenFirstDay.active() or id == "pair", "still on until the last is ticked (%s)" % id)
		GardenFirstDay.mark(id)
	var reward := int(GardenFirstDay.rules()["reward_gems"])
	ok(int(Save.d["gems"]) == gems0 + reward and reward > 0,
			"the last tick pays the small reward once (+%d gems)" % reward)
	GardenFirstDay.mark("feed")
	ok(int(Save.d["gems"]) == gems0 + reward, "and nothing more later")
	ok(not GardenFirstDay.active() and GardenFirstDay.rows().is_empty(), "the list is gone when done")
	ok(not GoalTracker.lines().any(func(r): return r["source"] == "first_day"), "and so are its tracker lines")

## A bot on a real fresh base does the five things.
func _bot() -> void:
	Save.d = _fresh_save()
	Save.d["tutorial"]["day1_done"] = true      # the guided tutorial stays out of it
	Save.d["items"]["kibble"] = 3
	var rules: Dictionary = Content.rules("farm_build")
	rules["base_mode"] = true
	var lay := HomeLayout.ensure(Save.d)
	var at := HomeLayout.LANDING
	var toy := {"u": HomeLayout._next_uid(lay), "id": "toy_ball", "x": int(at.x) - 3, "z": int(at.z) - 6, "r": 0}
	(lay["deco"] as Array).append(toy)
	var home = await main._hb_home()
	for f in 60:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	home.ppos = Vector3(-500, 0, -500)
	ok(GardenFirstDay.rows().size() == 5, "bot: the fresh base starts with five open lines")
	var center: Vector3 = home.world.random_ground(0)
	for k in home.kins:
		k.erase("indoors")
		k["pos"] = home.world.free_spot_near(center, [], 0.8)
		(k["node"] as Node3D).position = k["pos"]
	var a: Dictionary = home.kins[0]
	var b: Dictionary = home.kins[1]
	a["rec"]["needs"]["food"] = 30.0      # hungry, and kibble is not a food it hates: it eats it
	a["rec"]["likes"]["hates"] = "none"
	home._care_feed(a["rec"], "kibble")
	ok(GardenFirstDay.did("feed"), "bot: feeding a Boki ticks 'feed'")
	for i in MAX_STEPS:
		for k in home.kins:
			for n in ["food", "energy", "clean"]:
				k["rec"]["needs"][n] = 80.0
			k["rec"]["needs"]["joy"] = 40.0
		home.day_t = 0.5
		home._move_kin(STEP_S)
		if GardenFirstDay.did("toy"):
			break
		if i % 200 == 0:
			await main.get_tree().process_frame
	ok(GardenFirstDay.did("toy"), "bot: a Boki playing at the toy ticks 'toy'")
	await _race(home)
	_nap(home, a, b)
	home._make_egg(a["rec"], b["rec"])
	ok(GardenFirstDay.did("pair"), "bot: pairing two Boki ticks 'pair'")
	ok(not GardenFirstDay.active() and GardenFirstDay.rows().is_empty(), "bot: all five done, the list is gone")
	ok(int(Save.d["gems"]) >= int(GardenFirstDay.rules()["reward_gems"]), "bot: the reward is in the purse")

func _race(home) -> void:
	var race: BaseRace = home.hrace
	ok(race != null, "bot: the base has the Dash")
	if race == null:
		return
	race.use()
	var t := 0.0
	while race.run != null and t < RACE_MAX_S:
		race.tick(0.1)
		t += 0.1
	ok(GardenFirstDay.did("race"), "bot: a finished race ticks 'race' (%.0f s)" % t)

## Two Boki asleep side by side: the pile.
func _nap(home, a: Dictionary, b: Dictionary) -> void:
	for k in [a, b]:
		k.erase("play")
		k["pos"] = a["pos"]
		(k["node"] as Node3D).position = k["pos"]
		k["nap_t"] = 30.0
		(k["life"] as Fsm).go(BaseLife.S.NAP, "test")
	home.day_t = 0.0
	for i in 20:
		home._move_kin(STEP_S)
	ok(GardenFirstDay.did("nap"), "bot: two Boki napping side by side tick 'nap'")
