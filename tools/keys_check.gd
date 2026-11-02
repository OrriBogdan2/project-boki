extends RefCounted
## --keys-check: one locked chest type, keys, key carriers and the Shrubling (docs/decisions/0007).
##   1. the carriers: per region the number of key carriers equals the number of chests (a quiet
##      region with too few monsters is carried for by its neighbours), they change between seeds,
##      and every carrier shows a key glint
##   2. a chest will not open without a key, and opening one uses exactly one
##   3. keys drop in a deathbox, can be looted from it, and lie on the ground to be picked up
##   4. a carrier drops its key when it dies
##   5. the Shrubling: disguised until approached, flees (faster than a hunter on foot, slower than a
##      dash) and hides again, repeats, always carries a key, a root or a slow catches it, Grounded
##      stops its dive, it drops the key
##   6. bots go for a key, then open a chest

var main: Node
var fails := 0
var n := 0
const DT := 1.0 / 60.0

func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	print("KEYCHECK %-58s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT); t += DT

func build(seed_i: int, extra := {}) -> Match:
	var m := Match.new()
	main.add_child(m)
	var o := {"teams": 3, "squad": 1, "tier": 0, "seed": seed_i, "no_drop": true}
	o.merge(extra, true)
	await m.start(o)
	m.set_process(false)
	return m

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var only := ""      # --keys-part=carriers|chest|shrubling|bots runs one part while iterating
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--keys-part="): only = String(a).substr(12)
	if only in ["", "carriers"]: await _carriers()
	if only in ["", "chest"]: await _chest_and_keys()
	if only in ["", "shrubling"]: await _shrubling()
	if only in ["", "bots"]: await _bots()
	print("KEYCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

# ------------------------------------------------------------------ 1. carriers
func _carriers() -> void:
	var sets := []
	for sd in [3, 5, 9]:
		var m: Match = await build(sd)
		var K: KeyRun = m.keys
		var rep := K.report()
		var chests := 0; var carriers := 0; var elig := 0; var all_match := true
		for k in rep:
			var r: Dictionary = rep[k]
			chests += int(r["chests"]); carriers += int(r["carriers"])
			elig += int(r["monsters"]) + int(r["shrublings"])
			var want := mini(int(r["chests"]), int(r["monsters"]) + int(r["shrublings"]))
			if int(r["carriers"]) != want: all_match = false
			print("KEYCHECK   seed %d region %-4s chests %d monsters %d shrublings %d carriers %d (spilled in %d)" % [sd, k, r["chests"], r["monsters"], r["shrublings"], r["carriers"], r["spilled_in"]])
		ok("seed %d: carriers in each region equal its chests (or all its monsters)" % sd, all_match and chests > 0)
		var spilled := 0
		for k in rep: spilled += int(rep[k]["spilled_in"])
		ok("seed %d: the world holds one key per chest" % sd, K.carriers.size() == mini(chests, elig + 0) or K.carriers.size() == chests, "%d carriers, %d chests, %d spilled" % [K.carriers.size(), chests, spilled])
		var glints := K.carriers.filter(func(mb): return KeyCarry.glint_of(mb) != null).size()
		ok("seed %d: every carrier wears a key glint" % sd, glints == K.carriers.size(), "%d/%d" % [glints, K.carriers.size()])
		var ids := K.carriers.map(func(mb): return mb.nid)
		ids.sort()
		sets.append(ids)
		ok("seed %d: 1-3 Shrublings, all carriers" % sd, K.shrublings.size() >= 1 and K.shrublings.size() <= 3 and K.shrublings.all(func(s): return KeyCarry.carries(s)), "%d" % K.shrublings.size())
		var biomes_ok := true
		for s in K.shrublings:
			if not (KeyRun.rules()["shrubling"]["biomes"] as Array).has(m.world.biome_at(s.pos.x, s.pos.z)): biomes_ok = false
			if K.patches_near(s.pos, float(KeyRun.rules()["shrubling"]["sprint_r"])) < 3: biomes_ok = false
		ok("seed %d: Shrublings only in bloom/meadow/gloom/storm with 3+ patches near" % sd, biomes_ok)
		m.queue_free()
		await main.get_tree().process_frame
	ok("carriers change between seeds", sets[0] != sets[1] or sets[1] != sets[2])

# ------------------------------------------------------------------ 2, 3, 4. chest, box, ground, carrier death
func _chest_and_keys() -> void:
	var m: Match = await build(3, {"teams": 2})
	var P: Hunter = m.player
	var c: Dictionary = m.chests.filter(func(x): return not x.get("ride", false) and not x.get("free", false))[0]
	P.teleport(c["pos"] + Vector3(0.8, 0, 0))
	P.chest_keys = 0
	var pr := KeyChest.prompt(P, c)
	ok("no key: the prompt says locked", String(pr["kind"]) == "locked", String(pr["label"]))
	m._open_chest(P, c)
	ok("no key: the chest stays shut", not c["open"])
	P.chest_keys = 2
	pr = KeyChest.prompt(P, c)
	ok("with a key: the prompt offers to open it", String(pr["kind"]) == "chest" and String(pr["label"]).contains("1 key"), String(pr["label"]))
	var gems0 := m.pickups.size()
	m._open_chest(P, c)
	ok("opening uses exactly one key", c["open"] and P.chest_keys == 1, "keys %d" % P.chest_keys)
	m._open_chest(P, c)
	ok("an open chest costs nothing more", P.chest_keys == 1)
	ok("the chest pays out", m.pickups.size() > gems0)
	# a second chest, hold it through the interact loop
	var c2: Dictionary = m.chests.filter(func(x): return not x["open"] and not x.get("ride", false) and not x.get("free", false))[0]
	P.teleport(c2["pos"] + Vector3(0.8, 0, 0)); P.vel = Vector3.ZERO
	P.chest_keys = 0
	P.inp["interact"] = true
	step(m, 2.0)
	ok("holding interact at a locked chest does nothing", not c2["open"] and float(c2["prog"]) == 0.0)
	P.chest_keys = 1
	step(m, 1.6)
	P.inp["interact"] = false
	ok("holding interact with a key opens it for one key", c2["open"] and P.chest_keys == 0, "keys %d" % P.chest_keys)
	# deathbox
	P.chest_keys = 3
	var box := Life.drop_box(m, P, "test")
	ok("keys drop in the deathbox", int(box.get("chest_keys", 0)) == 3 and P.chest_keys == 0)
	var R: Hunter = m.hunters.filter(func(h): return h != P)[0]
	R.chest_keys = 0
	var items := Life.box_items(m, R, box)
	ok("the box lists the keys", items.any(func(it): return it["key"] == "chest_keys"))
	Life.smart_loot(m, R, box)
	ok("a rival can loot them", R.chest_keys == 3 and int(box["chest_keys"]) == 0, "keys %d" % R.chest_keys)
	# on the ground
	R.chest_keys = 0
	var np := m.pickups.size()
	m.drop("ckey", R.pos + Vector3(0.2, 0.6, 0), 1)
	ok("a dropped key lies on the ground", m.pickups.size() == np + 1 and String(m.pickups[-1]["kind"]) == "ckey")
	step(m, 1.5)
	ok("walking into it picks it up", R.chest_keys == 1, "keys %d" % R.chest_keys)
	# a carrier dies
	var K: KeyRun = m.keys
	var car: Mob = K.carriers.filter(func(mb): return not (mb is Shrubling) and not mb.dead)[0]
	var before := m.pickups.filter(func(p): return String(p["kind"]) == "ckey").size()
	car.hurt(99999.0, P, {"src": "shot"})
	var after := m.pickups.filter(func(p): return String(p["kind"]) == "ckey").size()
	ok("a carrier drops its key when it dies", after == before + 1 and not KeyCarry.carries(car), "%d -> %d" % [before, after])
	m.queue_free()
	await main.get_tree().process_frame

# ------------------------------------------------------------------ 5. the Shrubling
func _shrubling() -> void:
	var m: Match = await build(3, {"teams": 1, "god": true})
	var P: Hunter = m.player
	var K: KeyRun = m.keys
	var S: Shrubling = K.shrublings[0]
	var sr: Dictionary = KeyRun.rules()["shrubling"]
	for mb in m.mobs:
		if mb != S and not mb.dead: mb.hp = 0.0; mb.dead = true; mb.visible = false
	var home := S.pos
	ok("it always carries a key", KeyCarry.carries(S))
	ok("it starts as a bush: disguised, standing on grass", S.ss == "disguised" and m.world.in_bush(S.pos.x, S.pos.z))
	P.teleport(_ground_near(m, home + Vector3(14.0, 0, 0)))
	step(m, 4.0)
	ok("far away it stays disguised", S.ss == "disguised")
	P.teleport(_ground_near(m, home + Vector3(7.5, 0, 0)))
	step(m, 3.0)
	ok("at 7.5 m it still sits tight", S.ss == "disguised")
	P.teleport(_ground_near(m, home + Vector3(5.0, 0, 0)))
	step(m, 0.1)
	ok("inside 6 m it pops up (alert)", S.ss == "alert", S.ss)
	var peak := 0.0
	var t := 0.0
	var seen_flee := false
	while t < 2.5:
		step(m, 0.1); t += 0.1
		if S.ss == "flee":
			seen_flee = true
			peak = maxf(peak, Vector2(S.vel.x, S.vel.z).length())
		P.teleport(_ground_near(m, S.pos + Vector3(4.0, 0, 0)))      # the hunter keeps pace
	ok("then it flees", seen_flee and S.pos.distance_to(home) > 5.0, "moved %.1f m" % S.pos.distance_to(home))
	ok("faster than a hunter on foot", peak > P.base_speed + 0.2, "%.2f vs %.2f" % [peak, P.base_speed])
	ok("slower than a dash", peak < Hunter.DASH_SPEED * 0.5, "%.2f vs %.1f" % [peak, Hunter.DASH_SPEED])
	# the hunter gives up: it dives and is a bush again
	P.teleport(_ground_near(m, S.pos + Vector3(60.0, 0, 0)))
	step(m, 14.0)
	ok("out of sight it dives into grass and hides again", S.ss == "disguised" and m.world.in_bush(S.pos.x, S.pos.z), "%s at %s" % [S.ss, str(S.pos.snapped(Vector3.ONE))])
	step(m, 2.0)
	var hide2 := S.pos
	P.teleport(_ground_near(m, hide2 + Vector3(4.5, 0, 0)))
	step(m, 0.6)
	ok("approach it again and it runs again", S.ss in ["alert", "flee"], S.ss)
	# a root holds it, a slow drags it
	step(m, 0.6)
	S.root_t = 2.0
	var p0 := S.pos
	step(m, 1.0)
	ok("a root pins it", S.pos.distance_to(p0) < 0.3, "moved %.2f" % S.pos.distance_to(p0))
	step(m, 1.2)
	S.slow_t = 5.0; S.slow_k = 0.5
	step(m, 0.5)
	var slowed := Vector2(S.vel.x, S.vel.z).length()
	ok("a slow cuts its pace", slowed < peak * 0.7, "%.2f vs %.2f" % [slowed, peak])
	S.slow_t = 0.0
	# Grounded: it cannot dive
	P.teleport(_ground_near(m, S.pos + Vector3(30.0, 0, 0)))
	KitStatus.apply(S, "gnd", 6.0)
	step(m, 4.0)
	ok("Grounded: it can no longer dive", S.ss != "dive" and S.ss != "disguised", S.ss)
	# a hit while disguised gives it away; killing it drops the key
	S.hp = S.max_hp
	var np := m.pickups.filter(func(p): return String(p["kind"]) == "ckey").size()
	S.hurt(S.max_hp + 5.0, P, {"src": "shot"})
	step(m, 0.2)
	ok("it has low health and no attack", S.dead and float(Data.MOBS["shrubling"]["dmg"]) == 0.0 and S.max_hp <= 60.0, "hp %.0f" % S.max_hp)
	var nn := m.pickups.filter(func(p): return String(p["kind"]) == "ckey").size()
	ok("catching it pays the key", nn == np + 1, "%d -> %d" % [np, nn])
	ok("a hit uncovers a disguised one", await _hit_reveal())
	m.queue_free()
	await main.get_tree().process_frame

func _hit_reveal() -> bool:
	var m: Match = await build(3, {"teams": 1, "god": true})
	var S: Shrubling = m.keys.shrublings[0]
	step(m, 0.5)
	S.hurt(1.0, m.player, {"src": "shot"})
	step(m, 0.1)
	var good := S.ss == "alert" or S.ss == "flee"
	m.queue_free()
	return good

func _ground_near(m: Match, p: Vector3) -> Vector3:
	var q := m.world.free_spot_near(p, [], 0.5, 0.4, 6.0)
	return Vector3(q.x, m.world.ground_at(q.x, q.z), q.z)

# ------------------------------------------------------------------ 6. bots
func _bots() -> void:
	var m: Match = await build(7, {"teams": 1, "squad": 1, "autoplay": true})
	var B: Hunter = m.player      # (autoplay: the lone hunter is driven by the bot brain)
	var c: Dictionary = m.chests.filter(func(x): return not x.get("ride", false) and not x.get("free", false))[0]
	for mb in m.mobs:
		if not mb.dead and not (mb is Blight): mb.hp = 0.0; mb.dead = true; mb.visible = false
	m.keys.carriers.clear()
	B.chest_keys = 0
	B.teleport(_ground_near(m, c["pos"] + Vector3(-12.0, 0, 0)))
	var key_at := _ground_near(m, c["pos"] + Vector3(-17.0, 0, 3.0))
	m.drop("ckey", key_at + Vector3(0, 0.6, 0), 1)
	var open0 := m.chests.filter(func(x): return x["open"]).size()
	var got_key := false; var t := 0.0
	var opened := func(): return m.chests.filter(func(x): return x["open"]).size() > open0
	while t < 60.0 and not opened.call():
		step(m, 0.5); t += 0.5
		if B.chest_keys > 0: got_key = true
	ok("a bot picks up a dropped key", got_key or opened.call())
	ok("then opens a chest with it, and spends exactly that key", opened.call() and B.chest_keys == 0, "%.0fs" % t)
	# and a bot with no key does not stand at a locked chest
	var c2: Dictionary = m.chests.filter(func(x): return not x["open"] and not x.get("ride", false) and not x.get("free", false))[0]
	ok("a bot without a key has no chest goal", not BotKeys.chest_open_for(B, c2) or B.chest_keys > 0)
	m.queue_free()
