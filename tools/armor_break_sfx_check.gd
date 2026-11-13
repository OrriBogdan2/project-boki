extends RefCounted
## --armor-break-sfx-check: the armour-break cues (Juice.armor_break, reached from Hunter.hurt).
##  1. A hit that empties armour plays the crack once, and the attacker's tick once.
##  2. The victim's crack is louder than the same break heard from across the match.
##  3. A hit on empty armour plays neither, however many land.
##  4. A refill re-arms it: the next break plays both again.
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ABSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## Which of the two cues played since the last call (Sfx stamps each start), then forgets them.
func _cues() -> Array:
	var got := []
	for n in ["armor_break", "click"]:
		got.append(int(Sfx.last_played.get(n, -1000)) > 0)
		Sfx.last_played.erase(n)
		Sfx.recent.erase(n)
	return got

func _break(P: Hunter, Q: Hunter) -> void:
	Q.armor = 1.0
	Q.hurt(400.0, P, {"src": "abil"})

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 41, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.lives = 1
	var P: Hunter = m.player
	var Q: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	for h in [P, Q]:
		h.max_hp = 100000.0
		h.hp = h.max_hp
		h.max_armor = 50.0
	Q.teleport(P.pos + Vector3(6, 0, 0))
	Sfx.listener = P.pos          # the match is not processing, so nothing moved the listener
	_cues()
	_break(P, Q)
	var c := _cues()
	ok(c[0] and c[1], "a break plays the crack and the attacker's tick")
	for i in 3:
		Q.hurt(30.0, P, {"src": "abil"})
	c = _cues()
	ok(not c[0] and not c[1], "hits on empty armour play neither")
	Q.armor = 30.0
	_break(P, Q)
	c = _cues()
	ok(c[0] and c[1], "after a refill the next break plays both again")
	Q.armor = 1.0
	Q.hurt(400.0, m.hunters.filter(func(x): return x.team == Q.team and x != Q)[0], {"src": "abil"})
	c = _cues()
	ok(c[0] and not c[1], "a break by a teammate gives the crack but not the tick to you")
	P.armor = 1.0
	P.hurt(400.0, Q, {"src": "abil"})
	c = _cues()
	ok(c[0] and not c[1], "your own armour breaking plays the crack, with no attacker tick")
	ok(Juice.ARMOR_BREAK_DB_VICTIM > Juice.ARMOR_BREAK_DB, "the victim's crack is louder than a bystander's")
	print("ABSFX DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
