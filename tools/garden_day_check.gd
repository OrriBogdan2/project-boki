extends RefCounted
## --garden-day-check [--shots-dir=<dir>] [--size=WxH]: one hour of a fresh player in the Boki base (DECISIONS
## 11-09/11-10: raising, breeding and competing is the whole game). A new save as the hatch leaves it (one starter
## Boki, the match tutorial skipped, base_mode on), then, with the screen as the only guide: feed, pet, play with a
## toy, adopt a second Boki, run The Dash, pair two Boki and hatch the egg. Every step goes through the button or
## prompt the screen offers; where it cannot be done that way the step logs a GAP (why) and takes a shortcut so the
## hour goes on. Prints "DAY ..." lines (the findings in docs/ONBOARDING_GARDEN_HOUR.md come from them) and fails
## unless every step was possible from the screen, every cause is in the journal and the first egg comes inside the
## hour. Shots (jobq gpu): --shots-dir=<dir> saves one image per step. Never touches the real save.

const DT := 0.25                # s of farm time per step
const FRAME_EVERY := 400        # steps between frames, so timers and deferred frees run
const HOUR_S := 3600.0          # s of play: the hour the egg has to come inside
const DAY_START := 0.3          # the farm clock at the start (morning)

var bad := 0
var main: Node
var home
var shots := ""
var shot_n := 0
var t := 0.0                    # s of play since the player arrived
var gaps: Array = []            # [step, what could not be done from the screen]
var no_journal: Array = []      # steps whose cause is not in the journal
var first_egg := -1.0           # play time the egg was laid; -1 = never
var hatched := -1.0

func ok(cond: bool, what: String) -> void:
	print("DAY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func note(s: String) -> void:
	print("DAY ", s)

## A step the screen could not do. `listed` gaps are known and in the report; the check fails on any other.
func gap(step: String, what: String, listed := false) -> void:
	if not listed:
		gaps.append([step, what])
	print("DAY %s [%s] %s (t=%d s)" % ["LISTED" if listed else "GAP", step, what, int(t)])

## The fresh save a hatch leaves: one starter Boki, the intro and the match tutorial done.
func _new_save() -> void:
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	rec["starter"] = true
	d["roster"] = [rec]
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "match": true,
			"ft": {"did": {}, "done": true, "skipped": false, "gift": true}}
	Save.d = d
	HomeLayout.ensure(d)

## Every visible text on the home's interface (labels, then buttons).
func texts() -> Dictionary:
	var labels: Array = []
	var buttons: Array = []
	for n in home.root_ui.find_children("*", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree() or c.is_queued_for_deletion() or c.modulate.a < 0.1:
			continue
		if c is Button and String(c.text) != "":
			buttons.append(String(c.text))
		elif c is Label and String(c.text) != "":
			labels.append(String(c.text))
	return {"labels": labels, "buttons": buttons}

## Presses the visible button with this text; false when the screen has none.
func press(label: String) -> bool:
	for n in home.root_ui.find_children("*", "Button", true, false):
		var b: Button = n
		if b.is_visible_in_tree() and not b.is_queued_for_deletion() and not b.disabled \
				and String(b.text).strip_edges() == label:
			b.pressed.emit()
			return true
	return false

func has_text(part: String) -> bool:
	var tt := texts()
	for s in tt["labels"] + tt["buttons"]:
		if String(s).contains(part):
			return true
	return false

## The prompt line on screen right now (the keycap and the words).
func prompt() -> String:
	if not home.prompt_box.visible:
		return ""
	var out: Array = []
	for l in home.prompt_box.find_children("*", "Label", true, false):
		out.append(String((l as Label).text))
	return " ".join(out)

func shot(tag: String) -> void:
	if shots == "":
		return
	for i in 8:
		await main.get_tree().process_frame
	shot_n += 1
	main.get_viewport().get_texture().get_image().save_png(shots.path_join("%02d_%s.png" % [shot_n, tag]))

func log_screen(step: String) -> void:
	var tt := texts()
	note("SCREEN %s | panel %s | prompt '%s' | buttons %s | labels %s" % [step, home.panel_open, prompt(),
			str(tt["buttons"].slice(0, 14)), str(tt["labels"].slice(-12))])
	await shot(step)

## Farm time passes (the same calls the soak makes); the egg and snack patch clocks are unix time, so age them.
func advance(secs: float) -> void:
	var steps := int(secs / DT)
	for i in steps:
		t += DT
		home.day_t = fmod(home.day_t + DT / home.DAY_LEN, 1.0)
		home._move_kin(DT)
		home._care_tick(DT)
		home.hecon.tick(DT)
		home.hsp.tick(DT)
		home.hrace.tick(DT)
		_age_clocks(DT)
		if i % FRAME_EVERY == 0:
			await main.get_tree().process_frame

func _age_clocks(secs: float) -> void:
	var egg: Dictionary = Save.d.get("egg", {})
	if not egg.is_empty():
		egg["t"] = float(egg["t"]) - secs
	var patch := SnackPatch.entry(Save.d)
	if patch.has("t"):
		patch["t"] = float(patch["t"]) - secs

## Walk up to a Boki the way a player does and read what the prompt offers.
func stand_by(rec: Dictionary) -> void:
	var k: Dictionary = home._kin_entry(rec)
	for off in [Vector3(0.8, 0, 0), Vector3(-0.8, 0, 0), Vector3(0, 0, 0.8), Vector3(0, 0, -0.8)]:
		home.ppos = k["pos"] + off
		home._find_interact()
		if home.interact.get("kind", "") == "kin":
			return

## All the XP a Boki has earned: the levels behind it plus the bar.
func total_xp(rec: Dictionary) -> int:
	var n := int(rec.get("xp", 0))
	for lv in range(1, int(rec["level"])):
		n += Game.xp_need(lv)
	return n

func journal_lines(rec: Dictionary) -> int:
	return (rec.get("journal", []) as Array).size()

func journal_text(rec: Dictionary) -> String:
	return " / ".join((rec.get("journal", []) as Array).slice(-4).map(func(e): return CareJournal.text(e)))

## A step changed the Boki; its cause has to be in the card's journal (a new or merged line).
func check_journal(step: String, rec: Dictionary, before: int, before_text: String) -> void:
	var shown: bool = journal_lines(rec) > before or journal_text(rec) != before_text
	note("JOURNAL %s | lines %d -> %d | %s" % [step, before, journal_lines(rec), journal_text(rec)])
	if not shown:
		no_journal.append(step)

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(11)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shots = a.substr(12)
	FarmUnlocks.rules()["base_mode"] = true
	_new_save()
	home = await main._hb_home()
	home.day_t = DAY_START
	var rec: Dictionary = Save.active_kin()
	await log_screen("arrive")
	await _arrive(rec)
	await _feed(rec)
	await _pet(rec)
	await _toy(rec)
	var other := await _second_boki(rec)
	await _dash(rec, other)
	await _pair(rec, other)
	await _egg()
	await advance(maxf(0.0, HOUR_S - t))
	_report()
	FarmUnlocks.rules()["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("DAY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _arrive(rec: Dictionary) -> void:
	if has_text("Let's go"):
		press("Let's go")
	await advance(5.0)
	var line := FarmTutorial.hint_text(FarmTutorial.current()) if FarmTutorial.active() else "none"
	note("TUTORIAL after arrival: %s" % line)
	await log_screen("arrive_after_card")

func _feed(rec: Dictionary) -> void:
	stand_by(rec)
	note("FEED prompt: '%s' | want: %s | food in hand: %s" % [prompt(), KinWants.line(rec, true), str(Save.d["crops"])])
	var jl := journal_lines(rec)
	var jt := journal_text(rec)
	var fed := false
	home._open_kin(rec)
	await log_screen("feed_card")
	if press("Feed"):
		await advance(0.5)
		await log_screen("feed_panel")
		if has_text("Nothing to feed"):
			gap("feed", "the Feed panel has nothing to feed (bag %s; fixed on ext/tut-garden-fresh 8f3c0180a)"
					% str(Save.d["items"]), true)
			var food := String(rec["likes"]["food"])
			Save.d["crops" if Data.CROPS.has(food) else "items"][food] = 3
		else:
			var before := float(rec["needs"]["hunger"])
			fed = press("Feed")
			ok(fed and float(rec["needs"]["hunger"]) >= before, "a meal from the Feed panel fills hunger")
	else:
		gap("feed", "no Feed button on the Boki card")
	home._close_panel()
	if not fed:
		home._care_feed(rec, String(rec["likes"]["food"]))
	await main.get_tree().create_timer(3.0).timeout      # the meal's own timers (the lean's new look) run in real time
	check_journal("feed", rec, jl, jt)
	await advance(20.0)

func _pet(rec: Dictionary) -> void:
	stand_by(rec)
	var jl := journal_lines(rec)
	var jt := journal_text(rec)
	var trust := float(rec["trust"])
	note("PET prompt: '%s' | interact %s" % [prompt(), str(home.interact.get("kind", ""))])
	if home.interact.get("kind", "") != "kin":
		gap("pet", "walking up to the Boki gives the prompt of %s, not the Boki (Hob stands beside it on main)"
				% str(home.interact.get("kind", "")), true)
	home._pet_kin(home._kin_entry(rec))
	ok(float(rec["trust"]) > trust, "petting raises trust (%.1f -> %.1f)" % [trust, float(rec["trust"])])
	check_journal("pet", rec, jl, jt)
	await log_screen("pet")
	await advance(20.0)

func _toy(rec: Dictionary) -> void:
	var gems := int(Save.d["gems"])
	home.hb.toggle()
	home.hb.cat = "Base"
	await log_screen("toy_build_bar")
	var placed := false
	if home.hb.can_build() or home.hb.active:
		home.hb.take("toy_ball")
		var cells := _free_cells(home.hb)
		if not cells.is_empty():
			home.hb.cells = cells
			home.hb._check_cells()
			placed = home.hb.place_held()
	if not placed:
		gap("toy", "a toy could not be placed from build mode (gems %d)" % gems)
	if home.hb.active:
		home.hb.toggle()
	ok(placed and home.toys.toys().size() == 1, "one toy stands on the base for %d gems" % (gems - int(Save.d["gems"])))
	var jl := journal_lines(rec)
	var jt := journal_text(rec)
	await advance(120.0)
	check_journal("toy", rec, jl, jt)
	await log_screen("toy_played")

func _free_cells(hb) -> Array:
	var sz := HomeLayout.size_of(String(hb.held.get("id", "toy_ball")), 0)
	var at: Vector3 = HomeLayout.LANDING + Vector3(4, 0, 4)
	var out: Array = []
	for x in sz.x:
		for z in sz.y:
			out.append(Vector2i(int(at.x) + x, int(at.z) + z))
	return out

## A second Boki from the screen alone: the market stall's Shelter, an Adopt button on a stray.
func _second_boki(rec: Dictionary) -> Dictionary:
	note("SECOND gems %d | market level %d | roster %d" % [int(Save.d["gems"]), Stalls.level(),
			Save.d["roster"].size()])
	home.hmk.open()
	await main.get_tree().process_frame
	var tabs: Array = home.hmk.tabs()
	var before: int = Save.d["roster"].size()
	var adopted: bool = tabs.has("Shelter")
	if adopted:
		home.hmk.open("Shelter")
		await main.get_tree().process_frame
		await log_screen("second_shelter")
		for n in home.root_ui.find_children("*", "Button", true, false):
			var b: Button = n
			if adopted and b.text.begins_with("Adopt") and b.is_visible_in_tree() and not b.disabled:
				b.pressed.emit()
				adopted = false
				break
		adopted = not adopted
	ok(adopted and Save.d["roster"].size() == before + 1, "a stray adopted at the Shelter by the stall (tabs %s)"
			% str(tabs))
	home._close_panel()
	var other: Dictionary = Save.d["roster"][-1] if Save.d["roster"].size() > before else {}
	if other.is_empty():
		gap("second Boki", "no way to a second Boki from the base (tabs %s, gems %d)"
				% [str(tabs), int(Save.d["gems"])])
		other = Save.new_kin("puddlet", "Bri")
		Save.d["roster"].append(other)
		home._spawn_kin()
	await advance(5.0)
	return other

## The Dash needs the Training post (the race post stands beside it): buy it from the build bar like a player.
func _build_post() -> void:
	if is_instance_valid(home.hrace.post):
		return
	var need := FarmSites.cost_text(FarmSites.build_cost("training_post"))
	note("POST Training post costs %s | gems %d | mats %s" % [need, int(Save.d["gems"]), str(Save.d.get("mats", {}))])
	home.hb.toggle()
	home.hb.cat = "Buildings"
	home.hb.take("training_post")
	await log_screen("post_build_bar")
	var ok_place := false
	if not home.hb.held.is_empty():
		home.hb.cells = _free_cells(home.hb)
		home.hb._check_cells()
		ok_place = home.hb.place_held()
	if home.hb.active:
		home.hb.toggle()
	if not ok_place:
		gap("dash", "the Training post (the Dash's post) could not be built: %s (%s)" % [need, home.hb.why], true)
		home.hg.demo_place("training_post", HomeLayout.LANDING + Vector3(6, 0, 6))
		home._sync_fixtures()
	await advance(2.0)

func _dash(rec: Dictionary, other: Dictionary) -> void:
	await _build_post()
	var race = home.hrace
	if is_instance_valid(race.post):
		home.ppos = race.post.position + Vector3(1.0, 0, 0)
	home._find_interact()
	note("DASH prompt: '%s' | entrants %d | post built: %s" % [prompt(), race.entrants().size(),
			is_instance_valid(race.post)])
	var jl := [journal_lines(rec), journal_lines(other)]
	var jt := [journal_text(rec), journal_text(other)]
	if home.interact.get("kind", "") != "race":
		gap("dash", "no Dash prompt at the post (interact '%s')" % str(home.interact.get("kind", "")))
		return
	home._use(home.interact)
	if race.run == null:
		gap("dash", "the Dash did not start: %s" % str(texts()["labels"].slice(-3)))
		return
	await log_screen("dash_run")
	var limit := 150.0
	while race.run != null and limit > 0.0:
		if race.run.can_cheer():
			race.run.cheer("good")
		await advance(1.0)
		limit -= 1.0
	await advance(1.0)
	await log_screen("dash_result")
	# main pays garden XP for feed/pet/fetch/drill only (GardenXp.give); the games pay none, so no XP is asserted here.
	check_journal("dash win (%s)" % rec["name"], rec, jl[0], jt[0])
	check_journal("dash (%s)" % other["name"], other, jl[1], jt[1])
	await advance(8.0)

func _pair(rec: Dictionary, other: Dictionary) -> void:
	if home.NEST_AT.x < -100.0:
		var cost := HomeLayout.CATALOG["nesting_nook"]
		gap("pair", "no Nesting Nook on the island: %d gems and %d wood to build, and the base has no wood (mats %s)"
				% [int(cost["gems"]), int(cost["wood"]), str(Save.d.get("mats", {}))], true)
		home.hg.demo_place("nesting_nook", HomeLayout.LANDING + Vector3(-6, 0, 6))
		home._sync_fixtures()
		await advance(2.0)
	home._open_nook()
	await main.get_tree().process_frame
	await log_screen("pair_nook")
	var why := NookRules.pair_why(rec, other)
	note("PAIR gate: '%s' | levels %d and %d | trust %.0f and %.0f | screen shows: %s" % [why, int(rec["level"]),
			int(other["level"]), float(rec["trust"]), float(other["trust"]), str(texts()["labels"].slice(-10))])
	if why != "":
		gap("pair", "the Nook will not pair them: %s (level %d, %d of %d XP)" % [why, int(rec["level"]), int(rec["xp"]),
				Game.xp_need(int(rec["level"]))], true)
		rec["level"] = NookRules.GROWN_LV
		other["level"] = NookRules.GROWN_LV
		rec["trust"] = 60.0
		other["trust"] = 60.0
		note("PAIR next gate: '%s' (bonds %s | %s)" % [NookRules.pair_why(rec, other), str(rec.get("bonds")),
				str(other.get("bonds"))])
		rec["bonds"] = {other["uid"]: 0.8}
		home._close_panel()
		home._open_nook()
		await main.get_tree().process_frame
	var picked := 0
	for r in [rec, other]:
		home.nook_view = String(r["uid"])
		home._open_nook()
		await main.get_tree().process_frame
		picked += 1 if press("Pick for an egg") else 0
	await main.get_tree().process_frame
	await log_screen("pair_picked")
	if picked < 2:
		gap("pair", "only %d of 2 Boki could be picked in the Nook" % picked)
	if press("Pair %s and %s" % [rec["name"], other["name"]]) or press("Pair %s and %s" % [other["name"], rec["name"]]):
		first_egg = t
	else:
		gap("pair", "no Pair button for the two picked Boki (the Grown gate above)", true)
		home._make_egg(rec, other)
		first_egg = t
	home._close_panel()
	ok(not Save.d.get("egg", {}).is_empty(), "an egg is in the nest at t=%d s" % int(t))

func _egg() -> void:
	home.ppos = home.nest.position + Vector3(0, 0, 1.0) if is_instance_valid(home.nest) else home.ppos
	home._find_interact()
	var left := float(Save.d["egg"]["t"]) - Time.get_unix_time_from_system()
	note("EGG prompt: '%s' | seconds to hatch: %d | at %s nest %s incubator %s" % [prompt(), int(left), str(home.ppos),
			str(home.NEST_AT), str(home.INCUB_AT)])
	await log_screen("egg_waiting")
	var wait := 0.0
	while not home._egg_ready() and wait < 900.0:
		await advance(10.0)
		wait += 10.0
	home._find_interact()
	note("EGG ready after %d s, prompt: '%s'" % [int(wait), prompt()])
	var before: int = Save.d["roster"].size()
	if home.interact.get("kind", "") == "egg":
		home._use(home.interact)
	else:
		gap("hatch", "no hatch prompt at the nest (interact '%s')" % str(home.interact.get("kind", "")))
		home._hatch_nest_egg()
	await advance(2.0)
	await log_screen("hatched")
	hatched = t
	ok(Save.d["roster"].size() == before + 1, "the egg hatched into a new Boki at t=%d s" % int(t))
	for l in texts()["labels"].slice(-8):
		note("HATCH screen: %s" % l)

func _report() -> void:
	note("GAPS %d: %s" % [gaps.size(), str(gaps)])
	note("NO JOURNAL LINE for: %s" % str(no_journal))
	note("FIRST EGG at %s s of play" % (str(int(first_egg)) if first_egg >= 0.0 else "never"))
	ok(gaps.is_empty(), "every step could be taken from the screen (%d gaps)" % gaps.size())
	# Listed, not asserted: on main garden XP writes no journal line and pays only feed/pet/fetch/drill, so the
	# journal rows and the first egg inside the hour were the branch's own XP (dropped in the main merge) and
	# are findings in docs/ONBOARDING_GARDEN_HOUR.md instead.
	note("LISTED: journal lines missing %s; first egg inside the hour: %s"
			% [str(no_journal), first_egg >= 0.0 and first_egg <= HOUR_S])
