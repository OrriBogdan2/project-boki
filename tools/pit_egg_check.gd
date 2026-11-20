extends RefCounted
## --pit-egg-check: a beaten boss gives exactly ONE Rare Egg, to ONE hunter picked at random from
## everyone inside the pit at the kill (any team); nobody else gets one.
##   1. three hunters from two teams in the pit, one outside: over 50 seeds there is always exactly one
##      egg across all packs and the floor, each of the three wins at least once, the outsider never
##   2. a full pack: the egg lies at the winner's feet, theirs alone until EGG_HOLD_T runs out
##   3. nobody inside: the egg lies on the floor for anyone, as before
## Prints "PITEGG ok|FAIL ..." lines and "PITEGG DONE, failures: N". Never touches the save.

const SEEDS := 50

var bad := 0
var m: Match
var L: Dictionary

func ok(cond: bool, what: String) -> void:
	print("PITEGG %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 5, "no_drop": true, "map": "hollowcrown"})
	m.set_process(false)
	for mob in m.mobs.duplicate():
		if not (mob is Boss):
			mob.queue_free()
			m.mobs.erase(mob)
	L = m.lairs.list[0]
	for h in m.hunters:
		h.ctrl = "idle"
	m.hunters[3].ctrl = "bot"
	_spread_wins()
	_full_pack()
	_nobody_inside()
	m.queue_free()
	print("PITEGG DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _eggs_in_packs(h: Hunter) -> int:
	return h.pack.filter(func(it): return Loot.is_rare_egg(it)).size()

func _eggs_on_floor() -> int:
	return m.wpicks.filter(func(wp): return wp.has("egg")).size()

## Resets the lair and the floor, puts the first `inside_n` hunters in the pit (the rest well outside)
## and kills the boss under match seed `seed_v`. `cap` is every pack's size.
func _kill(seed_v: int, inside_n: int, cap := 4) -> void:
	for wp in m.wpicks.duplicate():
		Pack._off_ground(m, wp)
	L["egg_wp"] = null
	for i in m.hunters.size():
		var h: Hunter = m.hunters[i]
		h.pack = []
		h.pack_cap = cap
		var dx := i * 1.5 - 2.0 if i < inside_n else float(L["half"]) + 12.0
		var spot: Vector3 = L["c"] + Vector3(dx, 0, 0)
		h.pos = Vector3(spot.x, m.world.ground_at(spot.x, spot.z), spot.z)
	m.rng.seed = seed_v
	m.lairs.on_mob_dead(m.lairs.boss_of(L), m.hunters[0])

func _spread_wins() -> void:
	var wins := [0, 0, 0, 0]
	var one_egg := true
	for s in SEEDS:
		_kill(s + 1, 3)
		var total := _eggs_on_floor()
		for i in 4:
			total += _eggs_in_packs(m.hunters[i])
			wins[i] += _eggs_in_packs(m.hunters[i])
		one_egg = one_egg and total == 1
	ok(one_egg, "%d kills with 3 in the pit: exactly one egg every time" % SEEDS)
	ok(wins[0] > 0 and wins[1] > 0 and wins[2] > 0, "each hunter in the pit wins at least once (%s)" % str(wins))
	ok(wins[3] == 0, "the hunter outside the pit never wins")
	ok(m.hunters[0].team != m.hunters[2].team, "the three in the pit are from two teams")
	_kill(1, 3)
	var told: bool = m.feed_all.any(func(t): return " got the " in String(t) and String(t).ends_with(" Egg"))
	ok(told, "the feed says who got which Egg")
	var bot_won := false
	for s in SEEDS:
		_kill(s + 1, 4)
		bot_won = bot_won or _eggs_in_packs(m.hunters[3]) == 1
	ok(bot_won, "a bot wins too: the egg is in its pack, where bot.gd's egg_home reads it")

func _full_pack() -> void:
	_kill(7, 3, 0)
	var wp2: Variant = L.get("egg_wp")
	ok(wp2 != null and _eggs_on_floor() == 1, "full pack: the egg lies at the winner's feet")
	if wp2 == null:
		return
	var w: Hunter = wp2["only"]
	var other: Hunter = m.hunters[0] if m.hunters[0] != w else m.hunters[1]
	ok(m.lairs.held_from(wp2, other) and not m.lairs.held_from(wp2, w), "it is reserved for the winner")
	m.time += Lairs.EGG_HOLD_T + 0.1
	ok(not m.lairs.held_from(wp2, other), "after the hold runs out anyone can take it")

func _nobody_inside() -> void:
	_kill(3, 0)
	var held := 0
	for h in m.hunters:
		held += _eggs_in_packs(h)
	var wp: Variant = L.get("egg_wp")
	var free: bool = held == 0 and _eggs_on_floor() == 1 and wp != null and wp.get("only") == null
	ok(free, "nobody inside: one egg on the floor, free for all")
	var apart := 99.0
	for p in m.wpicks:
		if not p.has("egg"):
			apart = minf(apart, Vector2(p["pos"].x - wp["pos"].x, p["pos"].z - wp["pos"].z).length())
	var well_placed: bool = apart >= 2.0 and m.lairs.inside(L, wp["pos"])
	ok(well_placed, "the floor egg lies inside the lair, %.1fm from the loot pile" % apart)
