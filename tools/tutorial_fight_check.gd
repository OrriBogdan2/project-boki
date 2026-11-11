extends RefCounted
## --tutorial-fight-check: the tutorial fight beats suit each starter (Lace's charge bow, Kael's melee,
## Vex's gun). The test driver plays the course with each one; the fight beats (shoot..fight) must
## take FIGHT_MIN..FIGHT_MAX s without the hunter being brought down, and the first fight line
## names the starter's own move (draw, step in, shoot).

var bad := 0

const STARTERS := ["archer", "juggernaut", "gunslinger"]
const FIGHT_STEPS := ["shoot", "sig", "utility", "throw", "kin1", "fight"]
## What each starter's first fight line says.
const HINT_WORD := {"archer": "draw", "juggernaut": "step in", "gunslinger": "shoot"}
const FIGHT_MIN := 30.0       # s: the fight beats together, bot-driven, per starter
const FIGHT_MAX := 60.0
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
		"tutorial": true, "tut_test": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0,
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
	while t < 400.0 and not m.player.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		texts[tu.id()] = tu.text
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
	var in_range: bool = fight_t >= FIGHT_MIN and fight_t <= FIGHT_MAX
	ok(in_range, "%s: the fight beats take %.0f-%.0f s (%.1f)" % [id, FIGHT_MIN, FIGHT_MAX, fight_t])
	ok(downed == 0 and damage <= DAMAGE_MAX, "%s: never brought down, damage %.0f <= %.0f" % [id, damage, DAMAGE_MAX])
	m.queue_free()
