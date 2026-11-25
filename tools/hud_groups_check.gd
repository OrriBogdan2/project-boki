extends RefCounted
## --hud-groups-check: how many separately placed HUD blocks (groups, HudGroups) a new player scans at the four
## moments the 0.24.5 Ways Out touch: the first landing, the first fight, the Heart unlock, the quest-exit race.
##   1. the Ways Out strip is deferred (a newcomer) at the landing and the first fight, and revealed once a seat
##      is within seat_pips' lead_s (hud_reveal.json) of opening, is open, or you are out
##   2. at the Heart unlock and the exit race it is one group, and the Gate prompt is the one prompt, not a second
##   2b. a save's first expedition holds the clock/status strip back until the first Ways Out beat or kill
##   3. each moment's count equals the pinned one: 0.24.5 adds at most the one strip, only where it is needed.
##      The landing is at the owner's 5; the counters, glider ring and belt are folded in until they matter (rule 5).
##      The later moments add the toasts, the prompt and the strip. The check plays a fresh save (a new player), so
##      the "Your kit" card is not at the landing (rule 4)
##   4. a save before kit_card / own_numbers' match (HudReveal): no kit card (the training room keeps it), and your own
##      kills/knocks/gems row waits for the first kill, knock or gem or Tab; a veteran sees both as before
##   5. the glider ring only while you glide or the meter is not full; the belt only once a held item could be used
##      (then the save keeps it); the counters follow HudReveal ("counters", from the 4th expedition)
##   6. the gear strip and the perk row count only once drawn (HudReveal "gear" / "perks", then an item held)
##   7. the tutorial's HUD grows with its steps (HudReveal "tut_from"): minimap + vitals on the landing, the ability
##      row and weapon card from the shoot step, the Boki box from the G step, the belt from the loot step, no counters
##      (it draws none); never above TUT_MAX groups
## --hud-groups-check never touches the save. tools/hud_groups_shots.gd takes the pictures of the same moments.

const MOMENTS := ["landing", "fight", "heart", "race"]
const COUNTS := {"landing": 5, "fight": 7, "heart": 8, "race": 8}      # groups, strip included where it shows
const CLOCK := {"landing": 0, "fight": 0, "heart": 1, "race": 1}           # the clock strip: first beat or kill
const STRIP := {"landing": 0, "fight": 0, "heart": 1, "race": 1}           # of which the Ways Out strip

## The tutorial's groups from each step on: [first step id, count]; and the most it ever shows.
const TUT_COUNTS := [["land", 2], ["shoot", 4], ["gkey", 5], ["glove", 6]]
const TUT_MAX := 6

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
			m.interact = {"kind": "heart", "act": "leave", "prog": 0.0, "label": "F  Leave", "col": Heart.gate_col()}
		"race":
			sess = float(q["lair_open_s"]) + 5.0
			m.hud.kit_t0 = -100.0
			m.hud.toast("The Sealed Lair is open", Color.WHITE)
			m.interact = {"kind": "lair", "label": "F  Open the gate"}
	m.sess_t0 = sess - m.time

static func on_screen_has(hud, id: String) -> bool:
	return HudGroups.on_screen(hud).has(id)

func run(main: Node) -> void:
	var m: Match = await make_match(main)
	var hud := m.hud
	var q: Dictionary = Heart.rules()["quest"]
	var lead := float(HudReveal.groups()["seat_pips"]["lead_s"])
	var out := {}
	for id in MOMENTS:
		set_moment(m, id)
		var g: Array = HudGroups.on_screen(hud)
		out[id] = g
		print("HUDGROUPS   %s: %d groups (budget %d): %s" % [id, g.size(), HudGroups.rules()["budget"], ", ".join(g)])
		ok(g.size() == int(COUNTS[id]), "%s: %d groups" % [id, COUNTS[id]])
		ok(g.count("ways_out") == int(STRIP[id]), "%s: the Ways Out strip %s" % [id, "shows" if STRIP[id] else "waits"])
		ok(HudGroups.clock_shown(m) == bool(CLOCK[id]),
			"%s: the clock strip %s" % [id, "shows" if CLOCK[id] else "waits"])
		ok(g.count("prompt") <= 1, "%s: one prompt at most" % id)
	# 1. the reveal rule
	m.interact = {}
	m.heart._force(Heart.S.ASLEEP, "reset")      # the unlock moment left the spark ready
	m.sess_t0 = float(q["lair_open_s"]) - lead - 1.0 - m.time
	ok(not HudReveal.ways_out_shown(m), "every seat still more than %d s off: the strip waits" % int(lead))
	m.sess_t0 = float(q["lair_open_s"]) - lead + 1.0 - m.time
	ok(HudReveal.ways_out_shown(m), "the Lair opens within %d s: the strip comes" % int(lead))
	m.sess_t0 = 6.0 - m.time
	m.player.out = true
	ok(HudReveal.ways_out_shown(m), "out of the match: the strip (and the Ways out left line) is yours")
	m.player.out = false
	# 5. what folds in until it matters (the beats above made the save remember the clock)
	Save.d["hud_reveal"].erase("beat_clock")
	set_moment(m, "landing")
	var p0: Hunter = m.player
	ok(not on_screen_has(hud, "glider") and not on_screen_has(hud, "belt") and not on_screen_has(hud, "counters"),
		"landing: no glider ring, belt or counters")
	p0.gliding = true
	ok(on_screen_has(hud, "glider"), "gliding: the glider ring")
	p0.gliding = false
	p0.hp = p0.max_hp * 0.5
	ok(on_screen_has(hud, "belt") and BeltHud.shown(m, p0, true), "hurt with a tonic held: the belt")
	p0.hp = p0.max_hp
	ok(on_screen_has(hud, "belt"), "healed again: this save keeps the belt")
	Save.d["hud_reveal"].erase("belt")
	Save.d["matches"] = 3
	ok(on_screen_has(hud, "belt") and on_screen_has(hud, "counters"), "4th expedition: belt and counters back")
	Save.d["matches"] = 0
	# 4. what a new player's HUD holds back
	var p: Hunter = m.player
	set_moment(m, "landing")
	hud.kit_t0 = m.time      # just landed: a veteran's kit card would be up
	ok(not HudReveal.reached("kit_card"), "a fresh save is a new player")
	ok(not on_screen_has(hud, "kit"), "new player: no kit card at the landing")
	m.opts["training"] = true
	ok(on_screen_has(hud, "kit"), "new player: the training room keeps the kit card")
	m.opts["training"] = false
	ok(not HudReveal.own_numbers_shown(p, false), "new player: own kills/knocks/gems wait before the first one")
	ok(HudReveal.own_numbers_shown(p, true), "new player: own numbers show while Tab is held")
	for stat in ["kills", "knocks", "gems"]:
		p.set(stat, 1)
		ok(HudReveal.own_numbers_shown(p, false), "new player: own numbers show once %s is 1" % stat)
		p.set(stat, 0)
	Save.d["matches"] = int(HudReveal.groups()["kit_card"]["from_match"]) - 1
	ok(HudReveal.reached("kit_card") and HudReveal.reached("own_numbers"),
		"a save with %d expeditions is not new" % Save.d["matches"])
	ok(on_screen_has(hud, "kit") and HudReveal.own_numbers_shown(p, false),
		"veteran: kit card and own numbers as before")
	# 6. the gear strip and the perk row are counted only once drawn (HudReveal "gear" / "perks", then an item)
	ok(not on_screen_has(hud, "gear") and not on_screen_has(hud, "perks"),
		"veteran with no gear and no perk: neither strip")
	Save.d["matches"] = 0
	p.gear[2] = {"id": String(Gear.ALL.keys()[0]), "rar": 0}
	p.perks.append(String(Data.PERKS.keys()[0]))
	ok(not on_screen_has(hud, "gear") and not on_screen_has(hud, "perks"),
		"new player with gear and a perk: held back (HudReveal)")
	Save.d["matches"] = HudGroups.NEW_PLAYER_MATCHES
	ok(on_screen_has(hud, "gear") and on_screen_has(hud, "perks"),
		"veteran with gear and a perk: both strips")
	p.gear[2] = {}
	p.perks.clear()
	ok(not on_screen_has(hud, "gear") and not on_screen_has(hud, "perks"), "back to nothing held: neither strip")
	for i in 3:
		await main.get_tree().process_frame      # the real HUD draws the veteran's own-numbers row too
	Save.d["matches"] = 0
	# 2. the real HUD draws with the strip waiting and showing
	for id in MOMENTS:
		set_moment(m, id)
		for i in 3:
			await main.get_tree().process_frame
	ok(true, "the real HUD drew all four moments")
	m.queue_free()
	await _tutorial(main)
	print("HUDGROUPS DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)


## 5. a tutorial match, stepped through the course: the groups at every step.
func _tutorial(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var tm := Match.new()
	main.add_child(tm)
	tm.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	tm.set_process(false)
	var want := 0
	var most := 0
	for i in Tutorial.steps().size():
		var sid := String(Tutorial.steps()[i][0])
		tm.tut.step = i
		tm.interact = {}
		tm.hud.msgs.clear()
		var g: Array = HudGroups.on_screen(tm.hud)
		for t in TUT_COUNTS:
			if sid == t[0]:
				want = int(t[1])
		most = maxi(most, g.size())
		print("HUDGROUPS   tutorial %s: %d groups: %s" % [sid, g.size(), ", ".join(g)])
		ok(g.size() == want, "tutorial %s: %d groups" % [sid, want])
		ok(not g.has("counters"), "tutorial %s: no counters" % sid)
	ok(most <= TUT_MAX, "the tutorial never shows more than %d groups (%d)" % [TUT_MAX, most])
	tm.tut.step = Tutorial.step_index("land")
	for i in 3:
		await main.get_tree().process_frame      # the real HUD draws the first step
	tm.queue_free()
