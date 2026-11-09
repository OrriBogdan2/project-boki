extends RefCounted
## --new-player-bots-check: the rookie bot tier for a new player's first expeditions (DECISIONS 2026-11-08,
## Data.BOT_DIFF["rookie"]). Who gets it (offline, first ROOKIE_MATCHES finished expeditions, never an online
## lobby), what it does (early charge release, no recast of an E that is up, no third-partying), and the gap
## it makes: a rookie bot and an easy bot fight the same still target, and the rookie takes much longer to knock.

var bad := 0
const DT := 1.0 / 60.0
const CAP_S := 120.0             # a bot that has not knocked the target by now counts as this long
const MIN_GAP := 1.5             # the rookies' total time to knock must be at least this times the easy bots'
const START_M := 3.0             # the bot starts this close: inside the rookie tier's reach for a fight
const PLAYER_HP := 150.0
const LOSE_M := 10.0             # a bot this far off has left the fight
const ARCHS := ["gunslinger", "archer", "thief", "mage", "juggernaut"]
const OPTS := {"duel": true, "training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 5151,
	"no_drop": true}

func ok(cond: bool, what: String) -> void:
	print("NEWBOTS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_who()
	var m := Match.new()
	main.add_child(m)
	await m.start(OPTS.duplicate())
	m.set_process(false)
	m.duel.mode = "fight"
	_plain_and_calm(m)
	var t := {"rookie": 0.0, "easy": 0.0}
	for dk in t:
		for i in ARCHS.size() * 2:
			t[dk] += _time_to_knock(m, String(dk), String(ARCHS[i % ARCHS.size()]), 77 + i)
	print("NEWBOTS time to knock (s) over %d bots: rookie %.1f, easy %.1f" % [ARCHS.size() * 2, t["rookie"], t["easy"]])
	ok(float(t["easy"]) < CAP_S * ARCHS.size() * 2, "easy bots knock the target")
	ok(float(t["rookie"]) >= float(t["easy"]) * MIN_GAP, "rookie bots take at least %.1fx as long" % MIN_GAP)
	m.queue_free()
	print("NEWBOTS done, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _who() -> void:
	for n in [0, 1, 2]:
		Save.d["matches"] = n
		ok(Data.rookie_run({}), "%d finished expeditions: rookie bots" % n)
		ok(not Data.rookie_run({"net": {"host": "x"}}), "%d finished, online lobby: the server's setting" % n)
	Save.d["matches"] = Data.ROOKIE_MATCHES
	ok(not Data.rookie_run({}), "after %d finished expeditions: the normal tier" % Data.ROOKIE_MATCHES)
	ok(Data.auto_bot_diff(0, 0, false, true) == "rookie", "a rookie run gets the rookie tier")
	ok(Data.auto_bot_diff(0, 0, true, true) == "easy", "the tutorial stays easy")
	ok(not Data.BOT_ORDER.has("rookie"), "rookie is never in the Settings list")
	var r: Dictionary = Data.BOT_DIFF["rookie"]
	var e: Dictionary = Data.BOT_DIFF["easy"]
	ok(float(r["react"]) > float(e["react"]), "slower reaction than easy")
	ok(float(r["skill"]) < float(e["skill"]), "worse aim than easy")
	ok(float(r["aim_k"]) > 1.0 and float(r["abil_slow"]) > 1.0, "larger aim error, slower abilities")
	ok(float(r["calm_s"]) >= 120.0 and bool(r["plain"]), "two quiet minutes, plain kit use")

func _plain_and_calm(m: Match) -> void:
	var bot := m.duel.bot
	var holds := {"rmb": 0.0, "dash": 0.0}
	bot.ak.bot_hold["rmb"] = 1.0
	m.bot_brain._plain_kit(bot, holds)
	ok(is_equal_approx(float(bot.ak.bot_hold["rmb"]), Bot.EARLY_RELEASE), "a new charge is let go early")
	m.bot_brain._plain_kit(bot, {"rmb": 0.55, "dash": 0.0})
	ok(is_equal_approx(float(bot.ak.bot_hold["rmb"]), Bot.EARLY_RELEASE), "a hold already running is not cut")
	var kit := {"arch": "gunslinger", "weapon": Arch.signature("gunslinger")}
	var at := m.player.pos + Vector3(5, 0, 0)
	var third := m.make_hunter(m.next_id("b"), 2, "", "Third", "bot", {}, at, kit)
	third.ai = m.bot_brain.new_mind(m.rng, 0.5, Data.BOT_DIFF["rookie"])
	third.ai["tgt"] = m.player
	ok(m.bot_brain._in_others_fight(m, bot, m.player), "a rival fighting someone else is busy")
	third.team = bot.team
	ok(not m.bot_brain._in_others_fight(m, bot, m.player), "a rival fighting our own team is not")
	m.hunters.erase(third)
	third.queue_free()

## Seconds until the target (the player, standing still) is knocked by a bot of this tier and Hunter.
func _time_to_knock(m: Match, diff: String, arch: String, sd: int) -> float:
	seed(sd)
	m.rng.seed = sd
	var d := m.duel
	d.diff = diff
	d.arch = arch
	m.player.max_hp = PLAYER_HP      # (it grows between rounds: every bot meets the same target)
	m.player.max_armor = 0.0
	d.spawn_bot()
	d.bot.teleport(m.player.pos + Vector3(START_M, 0, 0))
	var t0 := m.time
	while m.time - t0 < CAP_S and not m.player.downed:
		m.step(DT)
		if d.bot.flat_dist(m.player) > LOSE_M:
			d.bot.teleport(m.player.pos + Vector3(START_M, 0, 0))      # it wandered off: it comes back to the fight
	return minf(m.time - t0, CAP_S)
