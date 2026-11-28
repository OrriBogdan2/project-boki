extends "res://tools/garden_first15_check.gd"
## --garden-only-pass-check: 2 hours of garden time for a player who never starts an expedition (the
## first-15 bot, run eight times as long, and playing like a garden-only player: it picks the patch, feeds
## the snack that leans toward the zone it works on, runs the Dash for gems, buys Old Pell's Wayseed when his
## stock holds one and the gems cover it, wakes a zone once both keys are in hand, and pairs two Grown Boki
## at the Nook). Prints the minute each zone opened and each dead end the bot met. Farm days are
## `Home.DAY_LEN` long: Pell's stock follows them (MarketSave.skew_days) and the patch timer is aged by hand.
## Every second it reads what the player is shown: the tutorial line, the
## Goals rows (the whole list, not only the home ones), a Boki's speech. A line that tells the player to go
## on an expedition, or a Goals row only a match can fill, is a nag: each one is logged once with when it
## first showed. A nag fails the check unless it is listed in docs/GARDEN.md (open questions) as a gate that
## still needs a design call: ALLOWED_NAGS below.

const NAG := "\\b(expeditions?|extract\\w*|matches|raids?|skiff|Hunters?|lairs?)\\b"
## Match-only Goals sources: a row from one is a nag, whatever it says.
const MATCH_SOURCES := ["unlock", "mastery"]
## Nags that wait for a design call (docs/GARDEN.md, open questions) or are a choice, not a push.
## Each is a part of the "where: line" text.
const ALLOWED_NAGS := ["Goals row (unlock)", "Goals row (mastery)", "head out, or press Stay"]

const FEED_BELOW := 80.0  # food need under which the player feeds a snack
const RACE_EVERY_S := 150.0  # s of garden time between two Dash runs for gems
const PATCH_AT := Vector3(5, 0, 5)  # where the player puts the snack patch down, from the landing

var nag_rx := RegEx.create_from_string("(?i)" + NAG)
var goals_seen := {}  # Goals row text -> source, every row the card showed
var nags := {}  # line -> [first second it showed, where]
var opened := {}  # zone id -> minute it opened
var dead_ends := {}  # why the bot could not go on -> [first minute, how many looks]
var last_act := 0.0
var last_act_clock_10 := 0.0
var last_race := -RACE_EVERY_S
var grown_min := -1.0  # minute the first Boki reached Grown
var egg_min := -1.0  # minute the first egg was laid
var wayseeds_bought := 0


func run(m: Node) -> void:
	sim_s = 7200.0
	await super.run(m)


func guidance() -> Array:
	_note(home.guide.hint_text(), "tutorial line")
	for r in GoalTracker.lines():
		goals_seen[String(r["text"])] = r["source"]
		_note(String(r["text"]), "Goals row (%s)" % r["source"], r["source"] in MATCH_SOURCES)
	for k in home.kins:
		if k.has("say") and is_instance_valid(k["say"]) and k["say"].visible:
			_note((k["say"] as Label3D).text, "speech")
	return super.guidance()


func _note(text: String, where: String, always := false) -> void:
	if text != "" and not nags.has(text) and (always or nag_rx.search(text) != null):
		nags[text] = [clock, where]
		print("GO2H nag at %4.0f s (%s): %s" % [clock, where, text])


func _allowed(line: String) -> bool:
	var full: String = nags[line][1] + ": " + line
	return ALLOWED_NAGS.any(func(a): return full.contains(a))


func _verdicts() -> void:
	super._verdicts()
	for g in goals_seen:
		print("GO2H goal shown: %s (%s)" % [g, goals_seen[g]])
	var loose := nags.keys().filter(func(l): return not _allowed(l))
	var what := "no line sends a garden-only player on an expedition (%d: %s)"
	ok(loose.is_empty(), what % [loose.size(), "; ".join(loose)])
	MarketSave.skew_days = 0
	for z in GardenZones.ids():
		print("GO2H zone %s: %s" % [z, "opened at min %.1f" % opened[z] if opened.has(z) else "never opened"])
	for why in dead_ends:
		print("GO2H dead end x%d from min %.1f: %s" % [dead_ends[why][1], dead_ends[why][0], why])
	print("GO2H Wayseeds bought %d, grown at min %.1f, egg at min %.1f" % [wayseeds_bought, grown_min, egg_min])
	ok(KinBox.farm().size() >= 2, "the bot adopted a second Boki: every game that pays gems needs two")
	var open_n := GardenZones.ids().filter(func(z): return GardenZones.is_open(z)).size()
	ok(open_n >= 2, "a garden-only player opens a second zone in %.0f hours (%d open)" % [sim_s / 3600.0, open_n])
	print(
		(
			"GO2H gate: Black Market placed %s, zones open %d of %d, matches %d"
			% [HomeLayout.placed("ransom", Save.d), open_n, GardenZones.ids().size(), int(Save.d["matches"])]
		)
	)


## What a garden-only player does every few seconds, on top of the first-15 tutorial and Goals steps.
func _act() -> void:
	super._act()
	var dt := clock - last_act
	last_act = clock
	MarketSave.skew_days = int(clock / home.DAY_LEN)
	_tend_patch(dt)
	_adopt()
	_feed()
	_run_for_gems()
	_shop()
	_open_zones()
	_pair(dt)
	if int(clock / 600.0) > int(last_act_clock_10 / 600.0):
		var rec: Dictionary = KinBox.farm()[0]
		var line := "GO2H min %3.0f: %d gems, level %d, %d zones open, pantry %d, %d of %d Boki can run the Dash"
		var n := [clock / 60.0, int(Save.d["gems"]), int(rec["level"]), opened.size(), _pantry_count()]
		print(line % (n + [home.hrace.entrants().size(), home.kins.size()]))
		print("GO2H   %s" % str(home.kins.map(_state)))
	last_act_clock_10 = clock


func _state(k: Dictionary) -> String:
	var rec: Dictionary = k["rec"]
	var flags := ""
	if k.get("busy", false):
		flags += "busy "
	if k.has("indoors"):
		flags += "indoors "
	return "%s e%.0f f%.0f %s" % [rec["name"], Care.need(rec, "energy"), Care.need(rec, "food"), flags]


func _pantry_count() -> int:
	var n := 0
	for f in Lean.rules()["foods"]:
		n += Econ.pantry(f)
	return n


func _dead_end(why: String) -> void:
	if not dead_ends.has(why):
		dead_ends[why] = [clock / 60.0, 0]
		print("GO2H dead end at min %5.1f: %s" % [clock / 60.0, why])
	dead_ends[why][1] += 1


## Puts the patch down, ages its timer by the garden time that passed (the real clock cannot be sped up) and
## walks over it when ripe.
func _tend_patch(dt: float) -> void:
	var e := SnackPatch.entry(Save.d)
	if e.is_empty():
		if int(HomeLayout.of(Save.d)["inv"].get(SnackPatch.ID, 0)) > 0:
			home.hg.demo_place(SnackPatch.ID, HomeLayout.LANDING + PATCH_AT)
			home._sync_fixtures()
		return
	if not e.has("t"):
		return
	e["t"] = float(e["t"]) - dt
	if SnackPatch.ripe(e, Time.get_unix_time_from_system()):
		home.ppos = HomeLayout.deco_center(e)
		home.hsp.tick(1.0)


## The locked zone to work on: the one whose Wayseed is in the bag, else the one Pell holds, else the first.
func _target() -> String:
	var locked: Array = GardenZones.ids().filter(func(z): return not GardenZones.is_open(z))
	for z in locked:
		if GardenZones.keys_for(z)["seed"]:
			return z
	for e in BlackMarket.stock():
		if BlackMarket.is_seed(String(e["key"])):
			return BlackMarket.id_of(String(e["key"]))
	return "" if locked.is_empty() else String(locked[0])


## The pantry snack to give: one that leans toward the zone it works on, else its favourite, else any it eats.
func _snack_for(rec: Dictionary, zone: String) -> String:
	var foods: Dictionary = Lean.rules()["foods"]
	var types: Array = GardenZones.info(zone).get("types", [])
	var any := ""
	for f in foods:
		if Econ.pantry(f) <= 0 or f == rec["likes"]["hates"]:
			continue
		if types.has(String(foods[f])):
			return f
		any = f if any == "" or f == rec["likes"]["food"] else any
	return any


func _feed() -> void:
	var zone := _target()
	for rec in KinBox.farm():
		if Care.need(rec, "food") >= FEED_BELOW:
			continue
		var f := _snack_for(rec, zone)
		if f == "":
			_dead_end("hungry and the pantry has no snack (the patch ripens every %d s)" % SnackPatch.grow_secs())
		else:
			home._care_feed(rec, f)


## A second Boki from the Shelter: a stray costs stray_fee, and every game that pays gems needs two rested Boki.
func _adopt() -> void:
	if KinBox.farm().size() >= 2 or not Shelter.open():
		return
	var strays: Array = Shelter.cards().filter(func(c): return String(c.get("from", "")) == "")
	if strays.is_empty() or int(Save.d["gems"]) < int(strays[0]["price"]):
		return
	if Shelter.adopt(String(strays[0]["id"]))["ok"]:
		home._spawn_kin()
		print("GO2H adopted a stray at min %5.1f for %d gems" % [clock / 60.0, int(strays[0]["price"])])


## The Dash between two rested Boki, cheering at the three marks: the one game here with a way in for the bot.
func _run_for_gems() -> void:
	if clock - last_race < RACE_EVERY_S or home.hrace.run != null:
		return
	if home.hrace.entrants().size() < 2:
		_dead_end("the Dash needs two rested Boki out on the base (no gems from any game with one)")
		return
	last_race = clock
	home.hrace.use()
	var t := 0.0
	while home.hrace.run != null and t < RACE_MAX_S:
		home.hrace.tick(0.1)
		t += 0.1
		if home.hrace.run != null and home.hrace.run.cheered < 3 and t > 1.0 + 3.0 * home.hrace.run.cheered:
			home.hrace.input(_key("interact"))


## Old Pell: the Wayseed is bought when the stall stands, his stock holds one and the gems cover it.
func _shop() -> void:
	if not HomeLayout.placed("ransom", Save.d):
		_dead_end("Old Pell's Black Market is not on the base")
		return
	var held := false
	for e in BlackMarket.stock():
		if not BlackMarket.is_seed(String(e["key"])):
			continue
		held = true
		var gems := int(Save.d["gems"])
		if gems < int(e["price"]):
			_dead_end("short of gems for the Wayseed (%d each)" % int(e["price"]))
		elif BlackMarket.buy(String(e["id"]))["ok"]:
			wayseeds_bought += 1
			print("GO2H bought %s at min %5.1f, %d gems left" % [e["key"], clock / 60.0, int(Save.d["gems"])])
	var locked: Array = GardenZones.ids().filter(func(z): return not GardenZones.is_open(z))
	if not held and not locked.is_empty() and not GardenZones.keys_for(String(locked[0]))["seed"]:
		_dead_end("Pell's stock holds no Wayseed (one every %d days)" % BlackMarket.seed_terms()[0])


## Wakes every locked zone whose two keys are in hand; notes the zone that waits for a leaning Boki.
func _open_zones() -> void:
	for z in GardenZones.ids():
		if GardenZones.is_open(z):
			if not opened.has(z):
				opened[z] = clock / 60.0
				print("GO2H zone %s open at min %5.1f" % [z, opened[z]])
			continue
		var keys := GardenZones.keys_for(z)
		if keys["seed"] and keys["lean"]:
			GardenZones.attune(z)
		elif keys["seed"]:
			var near := GardenZones.closest(z)
			var pts := float(near["lean"]) if not near.is_empty() else 0.0
			var why := "%s has its Wayseed, no Boki leans enough (best %.0f of %.0f)"
			_dead_end(why % [z, pts, float(GardenZones.rules()["lean_key"])])


## Pairs two Boki at the Nook once the gates are met; the egg ages by hand and hatches.
func _pair(dt: float) -> void:
	var recs := KinBox.farm()
	if grown_min < 0.0 and recs.any(func(r): return int(r["level"]) >= NookRules.GROWN_LV):
		grown_min = clock / 60.0
		print("GO2H first Grown Boki at min %5.1f" % grown_min)
	var egg: Dictionary = Save.d.get("egg", {})
	if not egg.is_empty():
		egg["t"] = float(egg["t"]) - dt
		if home._egg_ready():
			home._hatch_nest_egg()
		return
	if grown_min < 0.0:
		return
	if recs.size() < 2:
		_dead_end("a Grown Boki and no second one to pair with")
	elif not HomeLayout.placed("nesting_nook", Save.d):
		_dead_end("two Boki and the Nesting Nook is not built")
	else:
		var why := NookRules.pair_why(recs[0], recs[1])
		if why == "":
			home._make_egg(recs[0], recs[1])
			egg_min = clock / 60.0
			print("GO2H egg laid at min %5.1f" % egg_min)
		else:
			_dead_end("pair: " + why)
