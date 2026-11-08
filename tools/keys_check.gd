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

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("KEYCHECK %-58s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT

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
	var only := ""      # --keys-part=carriers|chest|shrubling|bots|bonus runs one part while iterating
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--keys-part="): only = String(a).substr(12)
	if only in ["", "carriers"]: await _carriers()
	if only in ["", "chest"]: await _chest_and_keys()
	if only in ["", "shrubling"]: await _shrubling()
	if only in ["", "bots"]: await _bots()
	if only in ["", "bonus"]: await _bonus()
	print("KEYCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

# ------------------------------------------------------------------ 1. carriers
func _carriers() -> void:
	var sets := []
	for sd in [3, 5, 9, 12, 21]:
		var m: Match = await build(sd)
		var K: KeyRun = m.keys
		var rep := K.report()
		var chests := 0
		var carriers := 0
		var elig := 0
		var all_match := true
		for k in rep:
			var r: Dictionary = rep[k]
			chests += int(r["chests"])
			carriers += int(r["carriers"])
			elig += int(r["monsters"]) + int(r["shrublings"])
			var want := mini(int(r["chests"]), int(r["monsters"]) + int(r["shrublings"]))
			if int(r["carriers"]) != want: all_match = false
			var row := [sd, k, r["chests"], r["monsters"], r["shrublings"], r["carriers"], r["spilled_in"]]
			var fmt := "KEYCHECK   seed %d region %-4s chests %d monsters %d shrublings %d carriers %d (spilled in %d)"
			print(fmt % row)
		ok("seed %d: carriers in each region equal its chests (or all its monsters)" % sd, all_match and chests > 0)
		var spilled := 0
		for k in rep: spilled += int(rep[k]["spilled_in"])
		ok(
				"seed %d: the world holds one key per chest" % sd,
				K.carriers.size() == mini(chests, elig + 0) or K.carriers.size() == chests,
				"%d carriers, %d chests, %d spilled" % [K.carriers.size(), chests, spilled])
		var glints := K.carriers.filter(func(mb): return KeyCarry.glint_of(mb) != null).size()
		ok(
				"seed %d: every carrier wears a key glint" % sd, glints == K.carriers.size(),
				"%d/%d" % [glints, K.carriers.size()])
		var ids := K.carriers.map(func(mb): return mb.nid)
		ids.sort()
		sets.append(ids)
		var n_shrub := K.shrublings.size()
		var all_carry := K.shrublings.all(func(s): return KeyCarry.carries(s))
		ok("seed %d: 1-3 Shrublings, all carriers" % sd, n_shrub >= 1 and n_shrub <= 3 and all_carry, "%d" % n_shrub)
		var biomes_ok := true
		for s in K.shrublings:
			if not (KeyRun.rules()["shrubling"]["biomes"] as Array).has(m.world.biome_at(
					s.pos.x, s.pos.z)): biomes_ok = false
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
	ok(
			"with a key: the prompt offers to open it",
			String(pr["kind"]) == "chest" and String(pr["label"]).contains("1 key"), String(pr["label"]))
	var gems0 := m.pickups.size()
	m._open_chest(P, c)
	ok("opening uses exactly one key", c["open"] and P.chest_keys == 1, "keys %d" % P.chest_keys)
	m._open_chest(P, c)
	ok("an open chest costs nothing more", P.chest_keys == 1)
	ok("the chest pays out", m.pickups.size() > gems0)
	# a second chest, hold it through the interact loop
	var c2: Dictionary = m.chests.filter(func(x): return not x["open"] and not x.get(
			"ride", false) and not x.get("free", false))[0]
	P.teleport(c2["pos"] + Vector3(0.8, 0, 0))
	P.vel = Vector3.ZERO
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
	BeltKeys.sync(R)
	R.ctrl = "idle"      # it waits by the key, not wandering off an edge
	R.inp["move"] = Vector2.ZERO
	var np := m.pickups.size()
	m.drop("ckey", R.pos + Vector3(0.2, 0.6, 0), 1, "", "", Vector3.ZERO)
	ok("a dropped key lies on the ground", m.pickups.size() == np + 1 and String(m.pickups[-1]["kind"]) == "ckey")
	step(m, 1.5)
	ok("walking into it picks it up", R.chest_keys == 1, "keys %d" % R.chest_keys)
	await _cap_and_belt(m, P, R)
	# a carrier dies
	var K: KeyRun = m.keys
	var car: Mob = K.carriers.filter(func(mb): return not (mb is Shrubling) and not mb.dead)[0]
	var before := m.pickups.filter(func(p): return String(p["kind"]) == "ckey").size()
	car.hurt(99999.0, P, {"src": "shot"})
	var after := m.pickups.filter(func(p): return String(p["kind"]) == "ckey").size()
	ok(
			"a carrier drops its key when it dies", after == before + 1 and not KeyCarry.carries(car),
			"%d -> %d" % [before, after])
	m.queue_free()
	await main.get_tree().process_frame

## The belt stack: at most 3 chest keys; past that a key stays on the ground and a box keeps the rest.
## KeyChest.count / take are what the utility belt shows and spends.
func _cap_and_belt(m: Match, P: Hunter, R: Hunter) -> void:
	var cap := KeyChest.cap()
	R.ctrl = "idle"      # held still, so its own bot brain does not spend a key mid-test
	R.inp["move"] = Vector2.ZERO
	R.chest_keys = cap
	for other in m.hunters:
		if other != R:
			other.teleport(R.pos + Vector3(30, 0, 30))     # (nobody else in grabbing range of the key)
	var spot := R.pos
	# only the key dropped here counts: a monster dying nearby in the wait drops its own loot (and key)
	var ours := func() -> Array:
		return m.pickups.filter(func(p):
			return String(p["kind"]) == "ckey" and Vector3(p["pos"]).distance_to(spot) < 2.0)
	m.drop("ckey", R.pos + Vector3(0.2, 0.6, 0), 1, "", "", Vector3.ZERO)      # (no random toss: it stays in reach)
	step(m, 1.5)
	var still_there: bool = ours.call().size() == 1
	var held := R.chest_keys
	ok("a full stack (%d) leaves the key on the ground" % cap, still_there and held == cap, "keys %d" % held)
	ok("belt adapter: count", KeyChest.count(R, "chest") == cap and KeyChest.count(R, "rift") == R.rift_keys)
	ok("belt adapter: take spends keys", KeyChest.take(R, "chest", 2) == 2 and R.chest_keys == cap - 2)
	ok("belt adapter: take never goes below zero", KeyChest.take(R, "chest", 9) == cap - 2 and R.chest_keys == 0)
	R.belt = UtilityBelt.empty()      # a free belt slot too: a key type takes one (BeltKeys)
	for pk in ours.call():
		R.teleport(pk["pos"] - Vector3(0, 0.3, 0))     # (the dropped key can roll out of reach while it waits)
	step(m, 1.5)
	ok("with room again it picks the key up", R.chest_keys == 1 and ours.call().is_empty(), "keys %d" % R.chest_keys)
	P.chest_keys = 0
	var box := Life.drop_box(m, P, "test")
	box["chest_keys"] = cap + 2
	R.chest_keys = 0
	Life.smart_loot(m, R, box)
	var kept := int(box["chest_keys"])
	ok("looting a box past the cap leaves the rest in it", R.chest_keys == cap and kept == 2, "kept %d" % kept)

# ------------------------------------------------------------------ 5. the Shrubling
## Gets S running: a light hit, then the hunter on its heels (3.5 m) for `secs`.
func _wake(m: Match, P: Hunter, S: Shrubling, secs: float) -> void:
	P.teleport(_ground_near(m, S.pos + Vector3(4.0, 0, 0)))
	S.hurt(0.5, P, {"src": "shot"})
	var t := 0.0
	while t < secs:
		step(m, 0.1)
		t += 0.1
		P.teleport(_ground_near(m, S.pos + Vector3(3.5, 0, 0)))

## Open ground (no grass) near `p` on the same island, or INF.
func _open_near(m: Match, p: Vector3) -> Vector3:
	var W := m.world
	for r in range(2, 12):
		for k in 16:
			var a := TAU * k / 16.0
			var x := p.x + cos(a) * r
			var z := p.z + sin(a) * r
			var ix := int(floor(x))
			var iz := int(floor(z))
			if not W.inb(ix, iz) or W.is_void(x, z) or W.is_block(x, z) or W.bush.has(W.idx(ix, iz)) \
					or W.island_of(x, z) != W.island_of(p.x, p.z):
				continue
			if absf(W.ground_at(x, z) - p.y) > 0.3: continue
			return Vector3(ix + 0.5, W.ground_at(ix + 0.5, iz + 0.5), iz + 0.5)
	return Vector3.INF

func _shrubling() -> void:
	var m: Match = await build(3, {"teams": 1, "god": true})
	var P: Hunter = m.player
	var K: KeyRun = m.keys
	var S: Shrubling = K.shrublings[0]
	var sr: Dictionary = KeyRun.rules()["shrubling"]
	for mb in m.mobs:
		if mb != S and not mb.dead:
			mb.hp = 0.0
			mb.dead = true
			mb.visible = false
	ok("it always carries a key", KeyCarry.carries(S))
	ok("it starts as a bush: disguised, standing on grass", S.ss == "disguised" and m.world.in_bush(S.pos.x, S.pos.z))
	# set it on bare ground, so any cover there is the Shrubling's own
	var bare := _open_near(m, S.pos)
	S.teleport(bare)
	step(m, 0.2)
	var home := S.pos
	var map_bush := m.world.bush.has(m.world.idx(int(floor(home.x)), int(floor(home.z))))
	ok("disguised, its tile is cover like any bush", m.world.in_bush(home.x, home.z) and not map_bush, str(home))
	# a hunter steps into it and hides there (no body to bump: it does not push them out); nothing happens
	P.teleport(home + Vector3(0.2, 0, 0.1))
	step(m, 3.0)
	var hiding := P.flat_dist(home) < 0.6 and m.world.in_bush(P.pos.x, P.pos.z)
	ok("a hunter can stand in it and hide there", hiding, "%.2f m from it" % P.flat_dist(home))
	ok("standing in it, or next to it, does not wake it", S.ss == "disguised" and S.pos.distance_to(home) < 0.3, S.ss)
	P.teleport(_ground_near(m, home + Vector3(1.4, 0, 0)))
	step(m, 4.0)
	ok("still a bush with a hunter beside it for 4 s", S.ss == "disguised", S.ss)
	# the tell: every 5 to 10 s, on its own seeded schedule
	var t0 := S.tells
	var times: Array = []
	var last := t0
	var t := 0.0
	while t < 32.0:
		step(m, 0.1)
		t += 0.1
		if S.tells != last:
			last = S.tells
			times.append(m.time)
	var gaps_ok := times.size() >= 3
	for i in range(1, times.size()):
		var g: float = times[i] - times[i - 1]
		if g < float(sr["tell_s"][0]) - 0.15 or g > float(sr["tell_s"][1]) + 0.15:
			gaps_ok = false
	ok("the tell fires every 5-10 s", gaps_ok and S.ss == "disguised", "%d tells in 32 s" % times.size())
	# the hider is in its tile when it is hit: it bolts and they are in the open
	P.teleport(home)
	step(m, 0.3)
	var hid: bool = m.world.in_bush(P.pos.x, P.pos.z)
	P.reveal_t = 0.0
	S.hurt(1.0, P, {"src": "shot"})
	step(m, Match.DT)
	ok("a hit wakes it", S.ss in ["alert", "flee"], S.ss)
	var exposed := hid and not m.world.in_bush(P.pos.x, P.pos.z) and P.reveal_t > 0.0
	ok("a hunter hiding in it is exposed when it bolts", exposed, "hid %s, reveal %.1f" % [hid, P.reveal_t])
	var peak := 0.0
	var seen_flee := false
	t = 0.0
	while t < 2.5:
		step(m, 0.1)
		t += 0.1
		if S.ss == "flee":
			seen_flee = true
			peak = maxf(peak, Vector2(S.vel.x, S.vel.z).length())
		P.teleport(_ground_near(m, S.pos + Vector3(4.0, 0, 0)))      # the hunter keeps pace
	ok("damage makes it flee", seen_flee, "moved %.1f m" % S.pos.distance_to(home))
	ok("faster than a hunter on foot", peak > P.base_speed + 0.2, "%.2f vs %.2f" % [peak, P.base_speed])
	ok("slower than a dash", peak < Hunter.DASH_SPEED * 0.5, "%.2f vs %.1f" % [peak, Hunter.DASH_SPEED])
	# the hunter gives up: it dives and is a bush again
	P.teleport(_ground_near(m, S.pos + Vector3(60.0, 0, 0)))
	step(m, 14.0)
	ok(
			"out of sight it dives into grass and hides again",
			S.ss == "disguised" and m.world.in_bush(S.pos.x, S.pos.z),
			"%s at %s" % [S.ss, str(S.pos.snapped(Vector3.ONE))])
	step(m, 2.0)
	var hide2 := S.pos
	P.teleport(_ground_near(m, hide2 + Vector3(2.0, 0, 0)))
	step(m, 2.0)
	ok("walking up to it again does not wake it", S.ss == "disguised", S.ss)
	S.root_t = 0.6
	step(m, 0.2)
	ok("a root counts as a hit: it wakes", S.ss in ["alert", "flee"], S.ss)
	step(m, 1.5)
	# a root holds it, a slow drags it (each time the hunter first gets it running)
	_wake(m, P, S, 1.0)
	S.root_t = 2.0
	var p0 := S.pos
	step(m, 1.0)
	ok("a root pins it", S.pos.distance_to(p0) < 0.3, "moved %.2f" % S.pos.distance_to(p0))
	step(m, 1.2)
	_wake(m, P, S, 0.6)
	S.slow_t = 5.0
	S.slow_k = 0.5
	step(m, 0.5)
	var slowed := Vector2(S.vel.x, S.vel.z).length()
	ok("a slow cuts its pace", slowed < peak * 0.7, "%.2f vs %.2f" % [slowed, peak])
	S.slow_t = 0.0
	# Grounded: it cannot dive
	_wake(m, P, S, 0.6)
	KitStatus.apply(S, "gnd", 6.0)
	P.teleport(_ground_near(m, S.pos + Vector3(30.0, 0, 0)))
	step(m, 4.0)
	ok("Grounded: it can no longer dive", S.ss == "flee", S.ss)
	# a grab (the shared yank every hook and pull uses) drags it to the hunter
	P.teleport(_ground_near(m, S.pos + Vector3(7.0, 0, 0)))
	var to := _ground_near(m, S.pos + Vector3(5.5, 0, 0))
	m.verbs.yank(S, to, 0.4)
	step(m, 0.45)
	ok(
			"a grab drags it in", Vector2(S.pos.x - to.x, S.pos.z - to.z).length() < 1.2,
			"%.2f m off" % Vector2(S.pos.x - to.x, S.pos.z - to.z).length())
	# a hit while disguised gives it away; killing it drops the key
	S.hp = S.max_hp
	var np := m.pickups.filter(func(p): return String(p["kind"]) == "ckey").size()
	S.hurt(S.max_hp + 5.0, P, {"src": "shot"})
	step(m, 0.2)
	ok(
			"it has low health and no attack",
			S.dead and float(Data.MOBS["shrubling"]["dmg"]) == 0.0 and S.max_hp <= 60.0, "hp %.0f" % S.max_hp)
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
		if not mb.dead and not (mb is Blight):
			mb.hp = 0.0
			mb.dead = true
			mb.visible = false
	m.keys.carriers.clear()
	B.chest_keys = 0
	B.teleport(_ground_near(m, c["pos"] + Vector3(-12.0, 0, 0)))
	var key_at := _ground_near(m, c["pos"] + Vector3(-17.0, 0, 3.0))
	KeyCarry.drop_keys(m, key_at + Vector3(0, 0.6, 0), 1)      # the way a bonus key drops
	var open0 := m.chests.filter(func(x): return x["open"]).size()
	var got_key := false
	var t := 0.0
	var opened := func(): return m.chests.filter(func(x): return x["open"]).size() > open0
	while t < 60.0 and not opened.call():
		step(m, 0.5)
		t += 0.5
		if B.chest_keys > 0: got_key = true
	ok("a bot picks up a dropped (bonus) key", got_key or opened.call())
	ok("then opens a chest with it, and spends exactly that key", opened.call() and B.chest_keys == 0, "%.0fs" % t)
	# and a bot with no key does not stand at a locked chest
	var c2: Dictionary = m.chests.filter(func(x): return not x["open"] and not x.get(
			"ride", false) and not x.get("free", false))[0]
	ok("a bot without a key has no chest goal", not BotKeys.chest_open_for(B, c2) or B.chest_keys > 0)
	m.queue_free()

# ------------------------------------------------------------------ 7. bonus keys
func _ckeys(m: Match) -> int:
	return m.pickups.filter(func(p): return String(p["kind"]) == "ckey").size()

func _bonus() -> void:
	await _surplus()
	await _sources()
	_never_sold()

## The surplus over six seeds: expected bonus keys against the locked chests, plus the real dice once.
func _surplus() -> void:
	var shares: Array = []
	var rolled := 0
	var chests_n := 0
	for sd in [3, 5, 9, 12, 21, 33]:
		var m: Match = await build(sd)
		var S := KeyBonus.surplus(m)
		shares.append(float(S["share"]))
		var row := [sd, S["expected"], S["chests"], float(S["share"]) * 100.0, str(S["by"])]
		print("KEYCHECK seed %d bonus keys: expected %.2f over %d chests (+%.0f%%)  sources %s" % row)
		for mb in m.mobs:
			rolled += KeyBonus.roll(m, KeyBonus.mob_source(mb))
		for b in m.breaks:
			rolled += KeyBonus.roll(m, String(b["kind"]))
		for c in m.chests:
			if c.has("ride"):
				rolled += KeyBonus.roll(m, "train_crate")
		chests_n += int(S["chests"])
		m.queue_free()
		await main.get_tree().process_frame
	var mean := 0.0
	for share in shares:
		mean += float(share)
	mean /= float(shares.size())
	print("KEYCHECK SURPLUS mean +%.1f%% over %d seeds (min +%.1f%%, max +%.1f%%)" % [
			mean * 100.0, shares.size(), float(shares.min()) * 100.0, float(shares.max()) * 100.0])
	ok("bonus keys: +20-30%% keys over chests on average (+%.1f%%)" % (mean * 100.0), mean >= 0.20 and mean <= 0.30)
	var real := float(rolled) / maxf(1.0, float(chests_n))
	ok("rolled for real: a surplus near that (+%.0f%%)" % (real * 100.0), real > 0.08 and real < 0.5)

## Every source fires (odds forced to 1 for the test), and a bonus key is an ordinary key on the ground.
func _sources() -> void:
	var m: Match = await build(5, {"teams": 1, "god": true})
	var R: Dictionary = KeyBonus.rules()
	var keep := R.duplicate(true)
	for k in ["monster", "pot", "crate", "barrel", "keg", "train_crate"]:
		R[k] = 1.0
	for k in ["boss", "elite"]:
		R[k] = {"odds": 1.0, "two": 1.0}
	for kind_s in ["monster", "elite", "boss"]:
		var mb := _mob_of(m, kind_s)
		var k0 := m.keys.bonus_given
		if mb is Boss:
			(mb as Boss).dormant = false
		for hit in 12:
			if mb == null or mb.dead:
				break
			mb.hurt(mb.max_hp * 10.0 + 500.0, m.player, {"src": "shot"})
			step(m, 0.3)
		var want := 1 if kind_s == "monster" else 2
		ok("a dead %s drops a bonus key" % kind_s, mb != null and m.keys.bonus_given == k0 + want,
				"%d -> %d" % [k0, m.keys.bonus_given])
	for kind_s in ["pot", "crate", "barrel", "keg"]:
		var brk := _break_of(m, kind_s)
		var k0 := _ckeys(m)
		if not brk.is_empty():
			m.brk.smash(brk, m.player)
			step(m, 0.2)
		ok("a broken %s drops one" % kind_s, not brk.is_empty() and _ckeys(m) >= k0 + 1, "%d -> %d" % [k0, _ckeys(m)])
	var shrub_none := m.keys.shrublings.all(func(s): return KeyBonus.mob_source(s) == "")
	ok("a Shrubling gives no bonus (it always carries one)", shrub_none)
	for k in keep:
		R[k] = keep[k]
	var p0 := m.player.chest_keys
	var kp: Dictionary = m.pickups.filter(func(p): return String(p["kind"]) == "ckey")[-1]
	m.player.teleport(Vector3(kp["pos"].x, m.world.ground_at(kp["pos"].x, kp["pos"].z), kp["pos"].z))
	step(m, 1.0)
	ok("a bonus key is picked up like any key", m.player.chest_keys > p0, "%d -> %d" % [p0, m.player.chest_keys])
	m.queue_free()
	await main.get_tree().process_frame
	await _train_crate()

## The sky train runs on Skyreach: opening one of its crates can pay a key too.
func _train_crate() -> void:
	var m: Match = await build(5, {"teams": 1, "god": true, "map": "skyreach"})
	var R: Dictionary = KeyBonus.rules()
	var keep := float(R["train_crate"])
	R["train_crate"] = 1.0
	var crates: Array = m.chests.filter(func(c): return c.has("ride") and not c["open"])
	var k1 := m.keys.bonus_given
	if not crates.is_empty():
		ChestLoot.drop(m, m.player, crates[0], false)
	R["train_crate"] = keep
	var crate_paid := not crates.is_empty() and m.keys.bonus_given == k1 + 1
	ok("a sky-train crate drops one", crate_paid, "%d crates" % crates.size())
	m.queue_free()
	await main.get_tree().process_frame

func _mob_of(m: Match, kind_s: String) -> Mob:
	for mb in m.mobs:
		if mb.dead or KeyBonus.mob_source(mb) != kind_s or m.world.is_void(mb.pos.x, mb.pos.z):
			continue
		return mb
	return null

func _break_of(m: Match, kind_s: String) -> Dictionary:
	for b in m.breaks:
		if b["kind"] == kind_s and not b["dead"]:
			return b
	return {}

## Never for sale: no content table besides the key rules themselves lists a chest key.
func _never_sold() -> void:
	var listed: Array = []
	for f in DirAccess.get_files_at("res://content/rules"):
		if not String(f).ends_with(".json") or f in ["keys.json", "chest_keys.json"]:
			continue
		var txt := FileAccess.get_file_as_string("res://content/rules/" + f)
		if txt.contains("\"ckey\"") or txt.contains("chest_key"):
			listed.append(f)
	ok("keys are never sold in shops", listed.is_empty(), ", ".join(listed))
