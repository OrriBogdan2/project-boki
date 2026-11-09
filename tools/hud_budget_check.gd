extends RefCounted
## --hud-budget-check: a fresh profile plays its first expedition (bots, 6 min; the bot cannot die, its
## squad can) and the HUD groups on screen, and those waiting for a free slot, are logged every 10 s
## (docs/HUD_BUDGET.md has the table). Fails on:
##   1. more than HudBudget.MAX_GROUPS groups at any sample, or a start without exactly the four core groups
##   2. an id passed to Hud.budget.on() in scripts/ that the budget does not list
##   3. holding Tab not showing everything
## Never touches the save.

const RUN_S := 360.0          # s of the first expedition
const LOG_S := 10.0           # s between logged samples
const SAMPLE_S := 0.5         # s between budget updates (the HUD's panels redraw at 20 Hz)
const SRC_DIRS := ["res://scripts/ui", "res://scripts/match"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HUDBUDGET %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	var teams := int(ceil(Data.MATCH_PLAYERS / 3.0))
	m.start({"teams": teams, "squad": 3, "total": Data.MATCH_PLAYERS, "tier": 0, "seed": 7, "autoplay": true,
		"length": RUN_S + 30.0, "no_drop": true, "god": true})
	m.set_process(false)
	var b: HudBudget = m.hud.budget
	var most := 0
	var start_ok := true
	var next_sample := 0.0
	var next_log := 0.0
	var n_step := 0
	while m.time < RUN_S and not m.over:
		m.step(Match.DT)
		n_step += 1
		if n_step % 120 == 0: await main.get_tree().process_frame
		if m.time < next_sample: continue
		next_sample += SAMPLE_S
		b.update(m)
		most = maxi(most, b.shown.size())
		if m.time >= next_log:
			if next_log == 0.0: start_ok = b.shown == HudBudget.CORE
			next_log += LOG_S
			var p: Hunter = m.player
			var waiting: Array = b.wanted(m).filter(func(id): return not b.shown.has(id))
			var row := [int(m.time), b.shown.size(), ",".join(b.shown), ",".join(waiting), int(p.hp), int(p.max_hp)]
			print("HUDBUDGET t=%03d groups=%d shown=%s waiting=%s hp=%d/%d" % row)
	if m.over: print("HUDBUDGET the match ended at %d s (your squad was out)" % int(m.time))
	var cap := HudBudget.MAX_GROUPS
	ok(most <= cap, "never more than %d groups at once (most seen: %d, over %d s)" % [cap, most, int(m.time)])
	ok(start_ok, "the first sample is the four core groups: %s" % ",".join(HudBudget.CORE))
	_hurt_wants_belt(m, b)
	_ids_listed()
	Input.action_press("scores")
	var all_on: bool = HudBudget.CONTEXT.all(func(id): return b.on(id))
	ok(all_on and b.on("kit"), "holding Tab shows every group and the kit card")
	Input.action_release("scores")
	ok(not b.on("kit"), "the kit card is Tab only on an expedition")
	print("HUDBUDGET %s" % ("PASS" if bad == 0 else "FAIL (%d)" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)

## The bot's health seldom drops in a run, so the health-driven trigger gets a direct test: hurt, the belt wants a slot.
func _hurt_wants_belt(m: Match, b: HudBudget) -> void:
	m.player.hp = m.player.max_hp * 0.5
	b.update(m)
	ok(b.wanted(m).has("belt") and b.shown.size() <= HudBudget.MAX_GROUPS, "hurt to half health: the belt wants a slot")

## Every id the HUD asks the budget about must be one it knows (or an unlisted group stays hidden for good).
func _ids_listed() -> void:
	var known: Array = HudBudget.CORE + HudBudget.CONTEXT + ["kit"]
	var re := RegEx.create_from_string("budget\\.on\\(\"(\\w+)\"\\)")
	var used := {}
	for dir in SRC_DIRS:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				for hit in re.search_all(FileAccess.get_file_as_string("%s/%s" % [dir, f])):
					used[hit.get_string(1)] = true
	var unknown: Array = used.keys().filter(func(id): return not known.has(id))
	var what := "every budget.on() id is listed (%d, unknown: %s)" % [used.size(), unknown]
	ok(unknown.is_empty() and not used.is_empty(), what)
