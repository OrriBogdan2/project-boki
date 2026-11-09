extends RefCounted
## --bot-ramp-check: backfill bots go easy on a new player (BotRamp). Match 1 uses the Easy profile,
## match 4 the tier's normal one, the ramp is monotone in between, gentle bots hold their ult for the
## first two minutes, humans are never touched, online the least experienced human sets it, a save
## without the count reads as brand new, and a forced difficulty is left alone.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BOTRAMP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_profiles()
	_online_and_save()
	_matches()
	print("BOTRAMP DONE, failures: %d" % bad)
	main.get_tree().quit()

func _profiles() -> void:
	var normal: Dictionary = Data.BOT_DIFF["hard"]
	var easy: Dictionary = Data.BOT_DIFF["easy"]
	var c1 := BotRamp.cfg(normal, 0)
	var same := true
	for k in BotRamp.KNOBS:
		same = same and is_equal_approx(float(c1[k]), float(easy[k]))
	ok(same, "match 1 (0 finished) uses every Easy knob")
	var slower := is_equal_approx(float(c1["react"]), 0.75) and float(c1["skill"]) < float(normal["skill"])
	ok(slower, "match 1: slower reactions, worse aim than normal")
	ok(c1["no_ult_s"] == 120.0, "match 1: no ult for the first 120 s")
	var c4 := BotRamp.cfg(normal, 3)
	ok(c4 == normal and not c4.has("no_ult_s"), "match 4 is the normal profile, ult free")
	var prev := c1
	var mono := true
	for n in [1, 2, 3]:
		var c := BotRamp.cfg(normal, n)
		mono = mono and float(c["skill"]) > float(prev["skill"]) and float(c["abil"]) > float(prev["abil"])
		mono = mono and float(c["react"]) < float(prev["react"])
		prev = c
	ok(mono, "skill, abilities up and reaction time down at every step to normal")
	var held2 := BotRamp.cfg(normal, 2).has("no_ult_s")
	ok(held2 and not BotRamp.cfg(normal, 3).has("no_ult_s"), "the ult hold lasts through match 3")
	ok(BotRamp.cfg(normal, 99) == normal, "a veteran gets the normal profile")
	ok(Data.BOT_DIFF["hard"] == normal and not normal.has("no_ult_s"), "the shared profile table is not edited")

func _online_and_save() -> void:
	Save.d = Save.fresh()
	ok(BotRamp.matches_for({}) == 0, "a fresh save counts 0 matches")
	Save.d.erase("ramp_n")
	Save.d.erase("matches")
	ok(BotRamp.matches_for({}) == 0, "a save with no count reads as brand new")
	BotRamp.count({"tutorial": true})
	ok(BotRamp.played() == 0, "the tutorial match does not use up a gentle match")
	BotRamp.count({"extracted": false})
	ok(BotRamp.played() == 1, "a finished real Extraction counts, won or lost")
	var old := {"v": 5, "matches": 7}
	BotRamp.migrate(old)
	ok(int(old["ramp_n"]) == 7, "an old save's matches carry over, so a veteran stays a veteran")
	var cur := {"matches": 9, "ramp_n": 2}
	BotRamp.migrate(cur)
	ok(int(cur["ramp_n"]) == 2, "a save that has the count keeps it")
	Save.d["ramp_n"] = 40
	var net := {"net": {"roster": [{"matches": 40}, {"matches": 1}, {"matches": 12}]}}
	ok(BotRamp.matches_for(net) == 1, "online: the host's view of the newest human sets the ramp")
	net = {"net": {"roster": [{"matches": 40}, {"matches": 12}, {"name": "old client"}]}}
	var normal_n := BotRamp.matches_for(net) == BotRamp.RAMP_MATCHES
	ok(normal_n, "online: veterans, and a roster entry without a count, get normal bots")

func _start(matches: int, o := {}) -> Match:
	Save.d = Save.fresh()
	Save.d["ramp_n"] = matches
	var m := Match.new()
	main.add_child(m)
	var opts := {"teams": 3, "squad": 3, "tier": 1, "length": 1e9, "seed": 11, "no_drop": true, "autoplay": true}
	opts.merge(o, true)
	m.start(opts)
	m.set_process(false)
	return m

func _matches() -> void:
	var m1 := _start(0)
	var bots1: Array = m1.hunters.filter(func(h): return h.ctrl == "bot" and h != m1.player)
	var easy: Dictionary = Data.BOT_DIFF["easy"]
	var easy_react := func(h): return is_equal_approx(float(h.ai["diff"]["react"]), float(easy["react"]))
	ok(bots1.size() > 0 and bots1.all(easy_react), "match 1: every bot in a real match has Easy reactions (Dusk Isles)")
	ok(bots1.all(func(h): return float(h.ai["skill"]) < 0.4), "match 1: bots aim like Easy (skill under 0.4)")
	ok(m1.player.ai == null or not m1.player.ai.has("no_ult_s"), "match 1: the player is not a bot and is untouched")
	m1.time = 10.0
	var b: Hunter = bots1[0]
	b.inp["ult"] = true
	m1.bot_brain.tick(m1, b, 0.016)
	ok(b.inp["ult"] == false, "match 1: a bot's ult is held at 10 s")
	m1.queue_free()
	var m4 := _start(3)
	var bots4: Array = m4.hunters.filter(func(h): return h.ctrl == "bot" and h != m4.player)
	var normal: Dictionary = Data.BOT_DIFF["medium"]
	var normal_bot := func(h): return h.ai["diff"] == normal
	ok(bots4.size() > 0 and bots4.all(normal_bot), "match 4: every bot has the tier's normal profile, no ult hold")
	m4.queue_free()
	var mf := _start(0, {"bot_diff": "expert"})
	ok(mf.bot_cfg == Data.BOT_DIFF["expert"], "a forced difficulty is not ramped")
	mf.queue_free()
