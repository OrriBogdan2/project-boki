extends RefCounted
## --tutorial-fight-check: the tutorial fight beats suit each starter (Lace's charge bow, Kael's melee,
## Vex's gun). The test driver plays the course with each one; the fight beats (sec..ult) must
## take FIGHT_MIN..FIGHT_MAX s without the hunter being brought down, and the first fight line
## names the starter's own move (draw, step in, shoot). The run levels: it lands at level 1 with every
## ability locked, the first pick can only be the right click, every ability ends up unlocked and used
## (right click, attack, dash, wall kick, Boki, E, glove, ultimate), and only the camps paid XP.

var bad := 0

const STARTERS := ["archer", "juggernaut", "gunslinger"]
const FIGHT_STEPS := ["sec", "shoot", "gkey", "kin", "hook", "ult"]
const USED := ["sec", "fire", "dash", "kick", "boki", "kin", "glove", "ult"]
## What each starter's first fight line says.
const HINT_WORD := {"archer": "draw", "juggernaut": "step in", "gunslinger": "shoot"}
const FIGHT_MIN := 12.0       # s: the fight beats together, bot-driven, per starter (Lace and Vex take 16-20 s)
const FIGHT_MAX := 70.0       # (six camps since 0.24.4: the bot's melee juggernaut walks to each, 52-61 s)
const DAMAGE_MAX := 60.0      # hp taken over the fight beats (of 100)

func ok(cond: bool, what: String) -> void:
	print("TUTFIGHT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	for id in STARTERS:
		await _play(main, id)
	print("TUTFIGHT DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _play(main: Node, id: String) -> void:
	seed(11)       # (the same run each time)
	var m := Match.new()
	main.add_child(m)
	m.start({
		"tutorial": true, "tut_test": true, "seed": 11, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0,
		"demo_kin": "cindle", "arch": id, "cls": Arch.weight(id),
	})
	m.set_process(false)
	var tu: Tutorial = m.tut
	var t := 0.0
	var fight_t := 0.0
	var damage := 0.0
	var downed := 0
	var hp := m.player.hp
	var texts := {}
	var locked: bool = m.player.slot_lv.values().all(func(v): return int(v) == 0)
	ok(locked and m.player.lvl == 1 and m.player.skill_pts == 1, id + ": lands at level 1, one point, all locked")
	var forced := false
	while t < 400.0 and not m.player.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		texts[tu.id()] = tu.text
		if tu.id() == "pick_sec" and not forced:
			forced = true
			var p := m.player
			var only: bool = p.can_level("sec") and not p.can_level("dash") and not p.can_level("kin")
			ok(only and not p.can_level("ult"), id + ": the first pick can only be the right click")
			p.gain_xp(500.0)
			ok(p.lvl == 1, id + ": XP from anything but the camps is ignored")
		if tu.id() in FIGHT_STEPS:
			fight_t += Match.DT
			damage += maxf(0.0, hp - m.player.hp)
			downed += 1 if m.player.out else 0
		hp = m.player.hp
	var tag := "%s: fight beats %.1f s, damage %.0f hp, finished %s" % [id, fight_t, damage, str(m.player.extracted)]
	print("TUTFIGHT ", tag)
	var hint := String(texts.get("shoot", "")).to_lower()
	var names_move: bool = hint.contains(HINT_WORD[id]) and hint.length() <= 34
	ok(names_move, "%s: the first fight line names its move ('%s')" % [id, hint])
	ok(m.player.extracted, id + ": the course finishes")
	var all_on: bool = m.player.slot_lv.values().all(func(v): return int(v) > 0)
	ok(all_on, "%s: every ability unlocked %s" % [id, str(m.player.slot_lv)])
	var missing := USED.filter(func(k): return not tu.seen.get(k, false))
	ok(missing.is_empty(), "%s: every ability used (missing %s)" % [id, str(missing)])
	var in_range: bool = fight_t >= FIGHT_MIN and fight_t <= FIGHT_MAX
	ok(in_range, "%s: the fight beats take %.0f-%.0f s (%.1f)" % [id, FIGHT_MIN, FIGHT_MAX, fight_t])
	ok(downed == 0 and damage <= DAMAGE_MAX, "%s: never brought down, damage %.0f <= %.0f" % [id, damage, DAMAGE_MAX])
	m.queue_free()
