extends RefCounted
## --hud-groups-check: how many separately placed HUD blocks (groups, HudGroups) a new player scans at the four
## moments the 0.24.5 Ways Out touch: the first landing, the first fight, the Heart unlock, the quest-exit race.
##   1. the Ways Out strip is deferred (a newcomer) at the landing and the first fight, and revealed once a seat
##      is within ways_out_lead_s of opening, is open, or you are out
##   2. at the Heart unlock and the exit race it is one group, and the Gate prompt is the one prompt, not a second
##   3. each moment's count equals the pinned one: 0.24.5 adds at most the one strip, only where it is needed.
##      The blocks that were already there put every moment over the owner's 5 (docs/UI_FIRST15.md): that gap is
##      printed, and filed in docs/DEBT.md for the declutter jobs
## --hud-groups-check never touches the save. tools/hud_groups_shots.gd takes the pictures of the same moments.

const MOMENTS := ["landing", "fight", "heart", "race"]
const COUNTS := {"landing": 10, "fight": 11, "heart": 12, "race": 12}      # groups, strip included where it shows
const STRIP := {"landing": 0, "fight": 0, "heart": 1, "race": 1}           # of which the Ways Out strip

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HUDGROUPS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## A solo Hunter in a 4-squad match with the Heart, as the Ways Out checks make one.
static func make_match(main: Node) -> Match:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 1, "tier": 0, "seed": 77, "no_drop": true, "heart": true, "god": true,
		"length": 1e9})
	m.set_process(false)
	for h in m.hunters:
		h.ctrl = "idle"
	return m

## Puts the match at a moment: its clock, the Heart, the toasts and the prompt on screen.
static func set_moment(m: Match, id: String) -> void:
	var q: Dictionary = Heart.rules()["quest"]
	var H: Heart = m.heart
	var sess := 6.0
	m.interact = {}
	m.hud.msgs.clear()
	match id:
		"fight":
			sess = 60.0
			m.hud.kit_t0 = -100.0      # the button card is long gone
			m.hud.toast("Boki, sic!", Color.WHITE)
			m.interact = {"kind": "loot", "label": "F  Loot"}
		"heart":
			sess = Heart.r("wake_s") + Heart.r("charge_s") + 5.0
			m.hud.kit_t0 = -100.0
			H.charge = Heart.r("charge_s")
			H._force(Heart.S.READY, "charged")
			m.hud.toast("The Heartspark is ready", Color.WHITE)
			m.interact = {"kind": "heart", "act": "leave", "prog": 0.0, "label": "F  Leave", "col": Heart.GATE_COL}
		"race":
			sess = float(q["lair_open_s"]) + 5.0
			m.hud.kit_t0 = -100.0
			m.hud.toast("The Sealed Lair is open", Color.WHITE)
			m.interact = {"kind": "lair", "label": "F  Open the gate"}
	m.sess_t0 = sess - m.time

func run(main: Node) -> void:
	var m: Match = await make_match(main)
	var hud := m.hud
	var q: Dictionary = Heart.rules()["quest"]
	var lead: float = HudGroups.rules()["ways_out_lead_s"]
	var out := {}
	for id in MOMENTS:
		set_moment(m, id)
		var g: Array = HudGroups.on_screen(hud)
		out[id] = g
		print("HUDGROUPS   %s: %d groups (budget %d): %s" % [id, g.size(), HudGroups.rules()["budget"], ", ".join(g)])
		ok(g.size() == int(COUNTS[id]), "%s: %d groups" % [id, COUNTS[id]])
		ok(g.count("ways_out") == int(STRIP[id]), "%s: the Ways Out strip %s" % [id, "shows" if STRIP[id] else "waits"])
		ok(g.count("prompt") <= 1, "%s: one prompt at most" % id)
	# 1. the reveal rule
	m.interact = {}
	m.heart._force(Heart.S.ASLEEP, "reset")      # the unlock moment left the spark ready
	m.sess_t0 = float(q["lair_open_s"]) - lead - 1.0 - m.time
	ok(not HudGroups.ways_out_shown(m), "every seat still more than %d s off: the strip waits" % int(lead))
	m.sess_t0 = float(q["lair_open_s"]) - lead + 1.0 - m.time
	ok(HudGroups.ways_out_shown(m), "the Lair opens within %d s: the strip comes" % int(lead))
	m.sess_t0 = 6.0 - m.time
	m.player.out = true
	ok(HudGroups.ways_out_shown(m), "out of the match: the strip (and the Ways out left line) is yours")
	m.player.out = false
	# 2. the real HUD draws with the strip waiting and showing
	for id in MOMENTS:
		set_moment(m, id)
		for i in 3:
			await main.get_tree().process_frame
	ok(true, "the real HUD drew all four moments")
	m.queue_free()
	print("HUDGROUPS DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)
