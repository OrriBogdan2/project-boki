extends RefCounted
## --bot-dodge-check: bots step out of a foe's ground telegraph (BotDodge). A 1.6 s ring is put on a bot
## that otherwise stands still: on normal at least 70% are out when it fires, on easy under 40%; a
## friendly ring is ignored; a dash spends a real charge and a bot with none just walks.

var bad := 0
const DT := 1.0 / 60.0
const TELE_S := 1.6              # how long the ring shows before it would fire
const RING_R := 4.0              # m
const OFFSET_M := 1.5            # the bot starts this far off the ring's centre
const SETTLE_FRAMES := 30        # a bot dropped into place is pushed clear of anything it overlaps
const TRIALS := 40
const NORMAL_MIN := 0.7
const EASY_MAX := 0.4
const OPTS := {"duel": true, "training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242,
	"no_drop": true}

func ok(cond: bool, what: String) -> void:
	print("BOTDODGE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	await m.start(OPTS.duplicate())
	m.set_process(false)
	m.duel.mode = "fight"
	var rate := {}
	for dk in ["easy", "medium"]:
		rate[dk] = _escape_rate(m, String(dk), true)
		print("BOTDODGE %s: %.0f%% out of the %.1f s ring" % [dk, float(rate[dk]) * 100.0, TELE_S])
	ok(float(rate["medium"]) >= NORMAL_MIN, "normal bots leave at least %.0f%%" % (NORMAL_MIN * 100.0))
	ok(float(rate["easy"]) < EASY_MAX, "easy bots leave under %.0f%%" % (EASY_MAX * 100.0))
	var friendly := _escape_rate(m, "medium", false)
	print("BOTDODGE friendly: %.0f%%" % (friendly * 100.0))
	ok(friendly == 0.0, "a friendly ring is ignored")
	_dash_charges(m)
	m.queue_free()
	print("BOTDODGE done, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Share of trials where the bot is out of the ring when TELE_S is up. `foe`: the ring is a rival's.
func _escape_rate(m: Match, diff: String, foe: bool) -> float:
	var out := 0
	for i in TRIALS:
		var bot := _place_bot(m, diff, 100 + i)
		var centre := bot.pos + Vector3(OFFSET_M, 0, 0).rotated(Vector3.UP, TAU * i / TRIALS)
		_ring(m, bot, centre, foe)
		for _s in int(TELE_S / DT):
			m.step(DT)
		if Vector2(bot.pos.x - centre.x, bot.pos.z - centre.z).length() > RING_R:
			out += 1
	return float(out) / TRIALS

func _place_bot(m: Match, diff: String, sd: int) -> Hunter:
	seed(sd)
	m.rng.seed = sd
	m.duel.diff = diff
	m.duel.arch = "gunslinger"
	m.duel.spawn_bot()
	var bot := m.duel.bot
	bot.teleport(m.player.pos + Vector3(14, 0, 0))
	bot.ai["think"] = 1e9            # no fighting or wandering: only the dodge moves it
	bot.ai["tgt"] = null
	for _s in SETTLE_FRAMES:
		m.step(DT)
	return bot

func _ring(m: Match, bot: Hunter, centre: Vector3, foe: bool) -> void:
	m.player.team = 0 if foe else bot.team       # (the ring's owner is judged when the bot looks, so it stays)
	AimKit.circle(m.player, "tele", {"at": centre, "r": RING_R, "all": true, "dur": TELE_S})

func _dash_charges(m: Match) -> void:
	var bot := _place_bot(m, "medium", 7)
	bot.dashes = 2.0
	_ring(m, bot, bot.pos + Vector3(0.5, 0, 0), true)
	for _s in int(TELE_S / DT):
		m.step(DT)
	ok(bot.dashes < 2.0, "a normal bot dashes out, and the dash cost a real charge")
	var dry := _place_bot(m, "medium", 8)
	dry.dashes = 0.0
	var start := dry.pos
	_ring(m, dry, dry.pos + Vector3(0.5, 0, 0), true)
	for _s in int(TELE_S / DT):
		m.step(DT)
	ok(dry.dashes >= 0.0 and dry.dashes < 1.0, "no charge: no dash")
	ok(Vector2(dry.pos.x - start.x, dry.pos.z - start.z).length() > 0.5, "and it still walks out")
