extends RefCounted
## --keys-check: one locked chest type, keys, key carriers and the Shrubling (docs/decisions/0007).
##   1. the carriers: per region the number of key carriers equals the number of chests (a quiet
##      region with too few monsters is carried for by its neighbours), they change between seeds,
##      and every carrier shows a key glint
##   2. a chest will not open without a key, and opening one uses exactly one; its lid creaks by the chest's tier
##   3. keys drop in a deathbox, can be looted from it, and lie on the ground to be picked up
##   4. a carrier drops its key when it dies
##   5. the Shrubling: disguised until approached, flees (faster than a hunter on foot, slower than a
##      dash) and hides again, repeats, always carries a key, a root or a slow catches it, Grounded
##      stops its dive, it drops the key
##   6. bots go for a key, then open a chest; a carrier they gave up on is left alone for a while
##   7. fewer chests: a match places chest.keep of the map's chests (the most crowded go first, no dice)
##      and of the item caches; the vaults stay; the tutorial has exactly one, the chest step's
##   8. the Esc menu's Controls card: every cap is Settings.key_cap (a rebind shows at once), no key
##      is written in its script, and every Hunter's five slots have an icon and a name
##   9. --keys-part=rebind: every drawn key follows a rebind (tools/rebind_keys_check.gd)

var main: Node
var fails := 0
var n := 0
const DT := 1.0 / 60.0


func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("KEYCHECK %-58s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


const SPILL_S := 0.9  # s: a kill dissolves first, then its drops spill (MobDissolve)


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
	m.start(o)
	m.set_process(false)
	return m


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var only := ""  # --keys-part=carriers|chest|shrubling|bots|bonus|fewer|rebind runs one part while iterating
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--keys-part="):
			only = String(a).substr(12)
	if only in ["", "carriers"]:
		await _carriers()
	if only in ["", "chest"]:
		await _chest_and_keys()
	if only in ["", "shrubling"]:
		await _shrubling()
	if only in ["", "bots"]:
		_bots()
	if only in ["", "bonus"]:
		await _bonus()
	if only in ["", "fewer"]:
		await _fewer()
	if only in ["", "card"]:
		_controls_card()
	if only in ["", "rebind"]:
		await load("res://tools/rebind_keys_check.gd").new().run(self, main)
	print("KEYCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()


# ------------------------------------------------------------------ 1. carriers
func _carriers() -> void:
	var sets := []
	for sd in [3, 5, 9, 12, 21]:
		var m: Match = build(sd)
		var k_v: KeyRun = m.keys
		var rep := k_v.report()
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
			if int(r["carriers"]) != want:
				all_match = false
			var row := [sd, k, r["chests"], r["monsters"], r["shrublings"], r["carriers"], r["spilled_in"]]
			var fmt := "KEYCHECK   seed %d region %-4s chests %d monsters %d shrublings %d carriers %d (spilled in %d)"
			print(fmt % row)
		ok("seed %d: carriers in each region equal its chests (or all its monsters)" % sd, all_match and chests > 0)
		var spilled := 0
		for k in rep:
			spilled += int(rep[k]["spilled_in"])
		ok(
			"seed %d: the world holds one key per chest" % sd,
			k_v.carriers.size() == mini(chests, elig + 0) or k_v.carriers.size() == chests,
			"%d carriers, %d chests, %d spilled" % [k_v.carriers.size(), chests, spilled]
		)
		var glints := k_v.carriers.filter(func(mb): return KeyCarry.glint_of(mb) != null).size()
		ok(
			"seed %d: every carrier wears a key glint" % sd,
			glints == k_v.carriers.size(),
			"%d/%d" % [glints, k_v.carriers.size()]
		)
		var ids := k_v.carriers.map(func(mb): return mb.nid)
		ids.sort()
		sets.append(ids)
		var n_shrub := k_v.shrublings.size()
		var all_carry := k_v.shrublings.all(func(s): return KeyCarry.carries(s))
		ok("seed %d: 1-3 Shrublings, all carriers" % sd, n_shrub >= 1 and n_shrub <= 3 and all_carry, "%d" % n_shrub)
		var biomes_ok := true
		for s in k_v.shrublings:
			if not (KeyRun.rules()["shrubling"]["biomes"] as Array).has(m.world.biome_at(s.pos.x, s.pos.z)):
				biomes_ok = false
			if k_v.patches_near(s.pos, float(KeyRun.rules()["shrubling"]["sprint_r"])) < 3:
				biomes_ok = false
		ok("seed %d: Shrublings only in bloom/meadow/gloom/storm with 3+ patches near" % sd, biomes_ok)
		m.queue_free()
		await main.get_tree().process_frame
	ok("carriers change between seeds", sets[0] != sets[1] or sets[1] != sets[2])


# ------------------------------------------------------------------ 7. fewer chests
func _fewer() -> void:
	var at := [Vector3(0, 0, 0), Vector3(40, 0, 0), Vector3(41, 0, 0), Vector3(0, 0, 40), Vector3(40, 0, 40)]
	var spots := at.map(func(p): return {"pos": p})
	var kept := KeyChest.thin(spots)
	var crowded_gone := not kept.any(func(c): return c["pos"] == at[2])
	ok(
		"thinning keeps chest.keep of the spots, the crowded one first out",
		kept.size() == KeyChest.kept(5) and crowded_gone
	)
	ok("thinning is the same every time (no dice)", KeyChest.thin(spots) == kept)
	for map_id in ["hollowcrown", "skyreach"]:
		var m: Match = build(5, {"map": map_id})
		var spots_n: int = m.world.chest_spots.size()
		var vaults: int = m.spawn_plan.active_of("vault").size()
		var caches: int = m.spawn_plan.active_of("cache").size()
		var train := m.chests.filter(func(c): return c.has("ride")).size()
		var map_n := m.chests.size() - vaults - caches - train
		var info := (
			"%s: map %d of %d spots, vaults %d, caches %d, train %d, total %d"
			% [map_id, map_n, spots_n, vaults, caches, train, m.chests.size()]
		)
		var pick := func(cat: String) -> int: return int(m.spawn_plan.cats[cat]["pick"][0])
		ok(
			"%s: chest.keep of the map's chests and caches, every vault" % map_id,
			(
				map_n == KeyChest.kept(spots_n)
				and caches == KeyChest.kept(pick.call("cache"))
				and vaults == pick.call("vault")
			),
			info
		)
		m.queue_free()
		await main.get_tree().process_frame
	var tr: Match = build(5, {"training": true, "teams": 1})
	var tr_spots: int = tr.world.chest_spots.size()
	ok(
		"training: chest.keep of its generated map's chests",
		tr.chests.size() == KeyChest.kept(tr_spots),
		"%d of %d spots" % [tr.chests.size(), tr_spots]
	)
	tr.queue_free()
	var tu: Match = build(5, {"tutorial": true, "teams": 1})
	# (ext/tutorial-abilities dropped the chest step, so the tutorial island has no chest at all)
	ok(
		"tutorial: no chests (the tutorial has no chest step)",
		tu.chests.is_empty(),
		"%d chests, the map has %d spots" % [tu.chests.size(), tu.world.chest_spots.size()]
	)
	tu.queue_free()
	await main.get_tree().process_frame


# ------------------------------------------------------------------ 2, 3, 4. chest, box, ground, carrier death
func _chest_and_keys() -> void:
	var m: Match = build(3, {"teams": 2})
	var p_v: Hunter = m.player
	var c: Dictionary = m.chests.filter(func(x): return not x.get("ride", false) and not x.get("free", false))[0]
	p_v.teleport(c["pos"] + Vector3(0.8, 0, 0))
	p_v.chest_keys = 0
	var pr := KeyChest.prompt(p_v, c)
	ok("no key: the prompt says locked", String(pr["kind"]) == "locked", String(pr["label"]))
	m._open_chest(p_v, c)
	ok("no key: the chest stays shut", not c["open"])
	p_v.chest_keys = 2
	pr = KeyChest.prompt(p_v, c)
	ok(
		"with a key: the prompt offers to open it",
		String(pr["kind"]) == "chest" and String(pr["label"]).contains("1 key"),
		String(pr["label"])
	)
	var gems0 := m.pickups.size()
	Sfx.listener = c["pos"]
	Sfx.last_played.clear()
	m._open_chest(p_v, c)
	ok("opening uses exactly one key", c["open"] and p_v.chest_keys == 1, "keys %d" % p_v.chest_keys)
	var lid := ChestLoot.creak(ChestLoot.rarity_bonus(m, c["pos"]))
	ok(
		"the lid creaks by the chest's tier, not the pickup sound",
		Sfx.last_played.has(lid) and not Sfx.last_played.has("pickup"),
		lid
	)
	m._open_chest(p_v, c)
	ok("an open chest costs nothing more", p_v.chest_keys == 1)
	ok("the chest pays out", m.pickups.size() > gems0)
	# a second chest, hold it through the interact loop
	var c2: Dictionary = m.chests.filter(func(x): return not x["open"] and not x.get("ride", false) and not x.get("free", false))[0]
	p_v.teleport(c2["pos"] + Vector3(0.8, 0, 0))
	p_v.vel = Vector3.ZERO
	p_v.chest_keys = 0
	p_v.inp["interact"] = true
	step(m, 2.0)
	ok("holding interact at a locked chest does nothing", not c2["open"] and float(c2["prog"]) == 0.0)
	p_v.chest_keys = 1
	p_v.inp["interact"] = false
	step(m, DT)
	pr = KeyChest.prompt(p_v, c2)
	var press := not String(pr["label"]).begins_with("Hold")
	ok("with a key: the prompt is a press, not a hold", press, String(pr["label"]))
	p_v.inp["interact"] = true
	step(m, DT)
	p_v.inp["interact"] = false
	ok(
		"one press of interact with a key opens it for one key, no hold",
		c2["open"] and p_v.chest_keys == 0 and p_v.holding() != "chest",
		"keys %d" % p_v.chest_keys
	)
	var free_c := {"free": true, "open": false}
	ok("a free chest is still held open", String(KeyChest.prompt(p_v, free_c)["label"]).begins_with("Hold"))
	# deathbox
	p_v.chest_keys = 3
	var box := Life.drop_box(m, p_v, "test")
	ok("keys drop in the deathbox", int(box.get("chest_keys", 0)) == 3 and p_v.chest_keys == 0)
	var r: Hunter = m.hunters.filter(func(h): return h != p_v)[0]
	r.chest_keys = 0
	var items := Life.box_items(m, r, box)
	ok("the box lists the keys", items.any(func(it): return it["key"] == "chest_keys"))
	Life.smart_loot(m, r, box)
	ok("a rival can loot them", r.chest_keys == 3 and int(box["chest_keys"]) == 0, "keys %d" % r.chest_keys)
	# on the ground
	r.chest_keys = 0
	BeltKeys.sync(r)
	r.ctrl = "idle"  # it waits by the key, not wandering off an edge
	r.inp["move"] = Vector2.ZERO
	var np := m.pickups.size()
	m.drop("ckey", r.pos + Vector3(0.2, 0.6, 0), 1, "", "", Vector3.ZERO)
	ok("a dropped key lies on the ground", m.pickups.size() == np + 1 and String(m.pickups[-1]["kind"]) == "ckey")
	step(m, 1.5)
	ok("walking into it picks it up", r.chest_keys == 1, "keys %d" % r.chest_keys)
	_cap_and_belt(m, p_v, r)
	# a carrier dies
	var k: KeyRun = m.keys
	var car: Mob = k.carriers.filter(func(mb): return not (mb is Shrubling) and not mb.dead)[0]
	var before := m.pickups.filter(func(p): return String(p["kind"]) == "ckey").size()
	var bonus0 := k.bonus_given  # (the death may also roll a bonus key: KeyBonus)
	car.hurt(99999.0, p_v, {"src": "shot"})
	step(m, SPILL_S)
	var after := m.pickups.filter(func(p): return String(p["kind"]) == "ckey").size()
	var bonus := k.bonus_given - bonus0
	ok(
		"a carrier drops its key when it dies",
		after == before + 1 + bonus and not KeyCarry.carries(car),
		"%d -> %d (+%d bonus)" % [before, after, bonus]
	)
	m.queue_free()
	await main.get_tree().process_frame


## The belt stack: at most 3 chest keys; past that a key stays on the ground and a box keeps the rest.
## KeyChest.count / take are what the utility belt shows and spends.
func _cap_and_belt(m: Match, p_v: Hunter, r: Hunter) -> void:
	var cap := KeyChest.cap()
	r.ctrl = "idle"  # held still, so its own bot brain does not spend a key mid-test
	r.inp["move"] = Vector2.ZERO
	r.chest_keys = cap
	for other in m.hunters:
		if other != r:
			other.teleport(r.pos + Vector3(30, 0, 30))  # (nobody else in grabbing range of the key)
	var spot := r.pos
	# only the key dropped here counts: a monster dying nearby in the wait drops its own loot (and key)
	var ours := func() -> Array:
		return m.pickups.filter(
			func(p): return String(p["kind"]) == "ckey" and Vector3(p["pos"]).distance_to(spot) < 2.0
		)
	m.drop("ckey", r.pos + Vector3(0.2, 0.6, 0), 1, "", "", Vector3.ZERO)  # (no random toss: it stays in reach)
	step(m, 1.5)
	var still_there: bool = ours.call().size() == 1
	var held := r.chest_keys
	ok("a full stack (%d) leaves the key on the ground" % cap, still_there and held == cap, "keys %d" % held)
	ok("belt adapter: count", KeyChest.count(r, "chest") == cap)
	ok("belt adapter: take spends keys", KeyChest.take(r, "chest", 2) == 2 and r.chest_keys == cap - 2)
	ok("belt adapter: take never goes below zero", KeyChest.take(r, "chest", 9) == cap - 2 and r.chest_keys == 0)
	r.belt = UtilityBelt.empty()  # a free belt slot too: a key type takes one (BeltKeys)
	for pk in ours.call():
		r.teleport(pk["pos"] - Vector3(0, 0.3, 0))  # (the dropped key can roll out of reach while it waits)
	step(m, 1.5)
	ok("with room again it picks the key up", r.chest_keys == 1 and ours.call().is_empty(), "keys %d" % r.chest_keys)
	p_v.chest_keys = 0
	var box := Life.drop_box(m, p_v, "test")
	box["chest_keys"] = cap + 2
	r.chest_keys = 0
	Life.smart_loot(m, r, box)
	var kept := int(box["chest_keys"])
	ok("looting a box past the cap leaves the rest in it", r.chest_keys == cap and kept == 2, "kept %d" % kept)


# ------------------------------------------------------------------ 5. the Shrubling
## Gets S running: a light hit, then the hunter on its heels (3.5 m) for `secs`.
func _wake(m: Match, p_v: Hunter, s: Shrubling, secs: float) -> void:
	p_v.teleport(_ground_near(m, s.pos + Vector3(4.0, 0, 0)))
	s.hurt(0.5, p_v, {"src": "shot"})
	var t := 0.0
	while t < secs:
		step(m, 0.1)
		t += 0.1
		p_v.teleport(_ground_near(m, s.pos + Vector3(3.5, 0, 0)))


## Open ground (no grass) near `p` on the same island, or INF.
func _open_near(m: Match, p: Vector3) -> Vector3:
	var w := m.world
	for r in range(2, 12):
		for k in 16:
			var a := TAU * k / 16.0
			var x := p.x + cos(a) * r
			var z := p.z + sin(a) * r
			var ix := int(floor(x))
			var iz := int(floor(z))
			if (
				not w.inb(ix, iz)
				or w.is_void(x, z)
				or w.is_block(x, z)
				or w.bush.has(w.idx(ix, iz))
				or w.island_of(x, z) != w.island_of(p.x, p.z)
			):
				continue
			if absf(w.ground_at(x, z) - p.y) > 0.3:
				continue
			return Vector3(ix + 0.5, w.ground_at(ix + 0.5, iz + 0.5), iz + 0.5)
	return Vector3.INF


func _shrubling() -> void:
	var m: Match = build(3, {"teams": 1, "god": true})
	var p_v: Hunter = m.player
	var k: KeyRun = m.keys
	var s: Shrubling = k.shrublings[0]
	var sr: Dictionary = KeyRun.rules()["shrubling"]
	for mb in m.mobs:
		if mb != s and not mb.dead:
			mb.hp = 0.0
			mb.dead = true
			mb.visible = false
	ok("it always carries a key", KeyCarry.carries(s))
	ok("it starts as a bush: disguised, standing on grass", s.ss == "disguised" and m.world.in_bush(s.pos.x, s.pos.z))
	# set it on bare ground, so any cover there is the Shrubling's own
	var bare := _open_near(m, s.pos)
	s.teleport(bare)
	step(m, 0.2)
	var home := s.pos
	var map_bush := m.world.bush.has(m.world.idx(int(floor(home.x)), int(floor(home.z))))
	ok("disguised, its tile is cover like any bush", m.world.in_bush(home.x, home.z) and not map_bush, str(home))
	# a hunter steps into it and hides there (no body to bump: it does not push them out); nothing happens
	p_v.teleport(home + Vector3(0.2, 0, 0.1))
	step(m, 3.0)
	var hiding := p_v.flat_dist(home) < 0.6 and m.world.in_bush(p_v.pos.x, p_v.pos.z)
	ok("a hunter can stand in it and hide there", hiding, "%.2f m from it" % p_v.flat_dist(home))
	ok("standing in it, or next to it, does not wake it", s.ss == "disguised" and s.pos.distance_to(home) < 0.3, s.ss)
	p_v.teleport(_ground_near(m, home + Vector3(1.4, 0, 0)))
	step(m, 4.0)
	ok("still a bush with a hunter beside it for 4 s", s.ss == "disguised", s.ss)
	# the tell: every 5 to 10 s, on its own seeded schedule
	var t0 := s.tells
	var times: Array = []
	var last := t0
	var t := 0.0
	while t < 32.0:
		step(m, 0.1)
		t += 0.1
		if s.tells != last:
			last = s.tells
			times.append(m.time)
	var gaps_ok := times.size() >= 3
	for i in range(1, times.size()):
		var g: float = times[i] - times[i - 1]
		if g < float(sr["tell_s"][0]) - 0.15 or g > float(sr["tell_s"][1]) + 0.15:
			gaps_ok = false
	ok("the tell fires every 5-10 s", gaps_ok and s.ss == "disguised", "%d tells in 32 s" % times.size())
	# the hider is in its tile when it is hit: it bolts and they are in the open
	p_v.teleport(home)
	step(m, 0.3)
	var hid: bool = m.world.in_bush(p_v.pos.x, p_v.pos.z)
	p_v.reveal_t = 0.0
	s.hurt(1.0, p_v, {"src": "shot"})
	step(m, Match.DT)
	ok("a hit wakes it", s.ss in ["alert", "flee"], s.ss)
	var exposed := hid and not m.world.in_bush(p_v.pos.x, p_v.pos.z) and p_v.reveal_t > 0.0
	ok("a hunter hiding in it is exposed when it bolts", exposed, "hid %s, reveal %.1f" % [hid, p_v.reveal_t])
	var peak := 0.0
	var seen_flee := false
	t = 0.0
	while t < 2.5:
		step(m, 0.1)
		t += 0.1
		if s.ss == "flee":
			seen_flee = true
			peak = maxf(peak, Vector2(s.vel.x, s.vel.z).length())
		p_v.teleport(_ground_near(m, s.pos + Vector3(4.0, 0, 0)))  # the hunter keeps pace
	ok("damage makes it flee", seen_flee, "moved %.1f m" % s.pos.distance_to(home))
	ok("faster than a hunter on foot", peak > p_v.base_speed + 0.2, "%.2f vs %.2f" % [peak, p_v.base_speed])
	ok("slower than a dash", peak < Hunter.DASH_SPEED * 0.5, "%.2f vs %.1f" % [peak, Hunter.DASH_SPEED])
	# the hunter gives up: it dives and is a bush again
	p_v.teleport(_ground_near(m, s.pos + Vector3(60.0, 0, 0)))
	step(m, 14.0)
	ok(
		"out of sight it dives into grass and hides again",
		s.ss == "disguised" and m.world.in_bush(s.pos.x, s.pos.z),
		"%s at %s" % [s.ss, str(s.pos.snapped(Vector3.ONE))]
	)
	step(m, 2.0)
	var hide2 := s.pos
	p_v.teleport(_ground_near(m, hide2 + Vector3(2.0, 0, 0)))
	step(m, 2.0)
	ok("walking up to it again does not wake it", s.ss == "disguised", s.ss)
	s.root_t = 0.6
	step(m, 0.2)
	ok("a root counts as a hit: it wakes", s.ss in ["alert", "flee"], s.ss)
	step(m, 1.5)
	# a root holds it, a slow drags it (each time the hunter first gets it running)
	_wake(m, p_v, s, 1.0)
	s.root_t = 2.0
	var p0 := s.pos
	step(m, 1.0)
	ok("a root pins it", s.pos.distance_to(p0) < 0.3, "moved %.2f" % s.pos.distance_to(p0))
	step(m, 1.2)
	_wake(m, p_v, s, 0.6)
	s.slow_t = 5.0
	s.slow_k = 0.5
	step(m, 0.5)
	var slowed := Vector2(s.vel.x, s.vel.z).length()
	ok("a slow cuts its pace", slowed < peak * 0.7, "%.2f vs %.2f" % [slowed, peak])
	s.slow_t = 0.0
	# Grounded: it cannot dive
	_wake(m, p_v, s, 0.6)
	KitStatus.apply(s, "gnd", 6.0)
	p_v.teleport(_ground_near(m, s.pos + Vector3(30.0, 0, 0)))
	step(m, 4.0)
	ok("Grounded: it can no longer dive", s.ss == "flee", s.ss)
	# a grab (the shared yank every hook and pull uses) drags it to the hunter
	p_v.teleport(_ground_near(m, s.pos + Vector3(7.0, 0, 0)))
	var to := _ground_near(m, s.pos + Vector3(5.5, 0, 0))
	m.verbs.yank(s, to, 0.4)
	step(m, 0.45)
	ok(
		"a grab drags it in",
		Vector2(s.pos.x - to.x, s.pos.z - to.z).length() < 1.2,
		"%.2f m off" % Vector2(s.pos.x - to.x, s.pos.z - to.z).length()
	)
	# a hit while disguised gives it away; killing it drops the key
	s.hp = s.max_hp
	var np := m.pickups.filter(func(p): return String(p["kind"]) == "ckey").size()
	s.hurt(s.max_hp + 5.0, p_v, {"src": "shot"})
	step(m, 0.3)  # (its key spills as the small body dissolves, before the player is near enough to take it)
	ok(
		"it has low health and no attack",
		s.dead and float(Data.MOBS["shrubling"]["dmg"]) == 0.0 and s.max_hp <= 60.0,
		"hp %.0f" % s.max_hp
	)
	var nn := m.pickups.filter(func(p): return String(p["kind"]) == "ckey").size()
	ok("catching it pays the key", nn == np + 1, "%d -> %d" % [np, nn])
	ok("a hit uncovers a disguised one", _hit_reveal())
	m.queue_free()
	await main.get_tree().process_frame


func _hit_reveal() -> bool:
	var m: Match = build(3, {"teams": 1, "god": true})
	var s: Shrubling = m.keys.shrublings[0]
	step(m, 0.5)
	s.hurt(1.0, m.player, {"src": "shot"})
	step(m, 0.1)
	var good := s.ss == "alert" or s.ss == "flee"
	m.queue_free()
	return good


func _ground_near(m: Match, p: Vector3) -> Vector3:
	var q := m.world.free_spot_near(p, [], 0.5, 0.4, 6.0)
	return Vector3(q.x, m.world.ground_at(q.x, q.z), q.z)


# ------------------------------------------------------------------ 6. bots
func _bots() -> void:
	var m: Match = build(7, {"teams": 1, "squad": 1, "autoplay": true})
	var b: Hunter = m.player  # (autoplay: the lone hunter is driven by the bot brain)
	var c: Dictionary = m.chests.filter(func(x): return not x.get("ride", false) and not x.get("free", false))[0]
	for mb in m.mobs:
		if not mb.dead and not (mb is Blight):
			mb.hp = 0.0
			mb.dead = true
			mb.visible = false
	m.keys.carriers.clear()
	b.chest_keys = 0
	b.teleport(_ground_near(m, c["pos"] + Vector3(-12.0, 0, 0)))
	var key_at := _ground_near(m, c["pos"] + Vector3(-17.0, 0, 3.0))
	KeyCarry.drop_keys(m, key_at + Vector3(0, 0.6, 0), 1)  # the way a bonus key drops
	var open0 := m.chests.filter(func(x): return x["open"]).size()
	var got_key := false
	var t := 0.0
	var opened := func(): return m.chests.filter(func(x): return x["open"]).size() > open0
	while t < 60.0 and not opened.call():
		step(m, 0.5)
		t += 0.5
		if b.chest_keys > 0:
			got_key = true
	ok("a bot picks up a dropped (bonus) key", got_key or opened.call())
	ok("then opens a chest with it, and spends exactly that key", opened.call() and b.chest_keys == 0, "%.0fs" % t)
	# and a bot with no key does not stand at a locked chest
	var c2: Dictionary = m.chests.filter(func(x): return not x["open"] and not x.get("ride", false) and not x.get("free", false))[0]
	ok("a bot without a key has no chest goal", not BotKeys.chest_open_for(b, c2) or b.chest_keys > 0)
	_given_up(m, b)
	m.queue_free()


## A carrier the bot has given up on is left alone: the fight dropped it (no clear shot), or the walk
## did (no way there). The no-path clock follows a carrier that walks about instead of restarting.
func _given_up(m: Match, b: Hunter) -> void:
	b.chest_keys = 0
	m.pickups = m.pickups.filter(func(p): return String(p["kind"]) != "ckey")
	var mb: Mob = m.mobs.filter(func(x): return not (x is Blight))[0]
	mb.dead = false
	mb.hp = 50.0
	KeyCarry.mark(mb)
	mb.pos = _ground_near(m, b.pos + Vector3(6.0, 0, 0))
	var g := BotKeys.goal(m, b, Vector3.INF)
	ok(
		"a bot without a key goes for a carrier 6 m off",
		not g.is_empty() and String(g[1]) == "keyhunt" and g[0] == mb.pos
	)
	b.ai["ignore"] = {"e": mb, "until": m.time + 4.0}
	ok("not one its fight gave up on (no clear shot)", BotKeys.goal(m, b, Vector3.INF).is_empty())
	b.ai.erase("ignore")
	b.ai["goal"] = BotKeys.goal(m, b, Vector3.INF)[0]
	b.ai["goal_kind"] = "keyhunt"
	b.ai.erase("nopath")
	var brain := Bot.new()
	for i in 12:  # 2 s of no path while the carrier ambles 0.1 m a step
		mb.pos.x += 0.1
		b.ai["goal"] = mb.pos
		brain._no_path(m, b)
		m.time += 0.17
	ok("no way to a walking carrier: given up within 2 s", BotKeys.goal(m, b, Vector3.INF).is_empty())
	m.time += Bot.GIVE_UP_S
	ok("and taken up again once the give-up runs out", not BotKeys.goal(m, b, Vector3.INF).is_empty())


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
		var m: Match = build(sd)
		var s := KeyBonus.surplus(m)
		shares.append(float(s["share"]))
		var row := [sd, s["expected"], s["chests"], float(s["share"]) * 100.0, str(s["by"])]
		print("KEYCHECK seed %d bonus keys: expected %.2f over %d chests (+%.0f%%)  sources %s" % row)
		for mb in m.mobs:
			rolled += KeyBonus.roll(m, KeyBonus.mob_source(mb))
		for b in m.breaks:
			rolled += KeyBonus.roll(m, String(b["kind"]))
		for c in m.chests:
			if c.has("ride"):
				rolled += KeyBonus.roll(m, "train_crate")
		chests_n += int(s["chests"])
		m.queue_free()
		await main.get_tree().process_frame
	var mean := 0.0
	for share in shares:
		mean += float(share)
	mean /= float(shares.size())
	print(
		(
			"KEYCHECK SURPLUS mean +%.1f%% over %d seeds (min +%.1f%%, max +%.1f%%)"
			% [mean * 100.0, shares.size(), float(shares.min()) * 100.0, float(shares.max()) * 100.0]
		)
	)
	ok("bonus keys: +20-30%% keys over chests on average (+%.1f%%)" % (mean * 100.0), mean >= 0.20 and mean <= 0.30)
	var real := float(rolled) / maxf(1.0, float(chests_n))
	ok("rolled for real: a surplus near that (+%.0f%%)" % (real * 100.0), real > 0.08 and real < 0.5)


## Every source fires (odds forced to 1 for the test), and a bonus key is an ordinary key on the ground.
func _sources() -> void:
	var m: Match = build(5, {"teams": 1, "god": true})
	var r: Dictionary = KeyBonus.rules()
	var keep := r.duplicate(true)
	for k in ["monster", "pot", "crate", "barrel", "keg", "train_crate"]:
		r[k] = 1.0
	for k in ["boss", "elite"]:
		r[k] = {"odds": 1.0, "two": 1.0}
	for kind_s in ["monster", "elite", "boss"]:
		var mb := _mob_of(m, kind_s)
		var k0 := m.keys.bonus_given
		if mb is Boss:
			(mb as Boss).wake("check")
		for hit in 12:
			if mb == null or mb.dead:
				break
			mb.hurt(mb.max_hp * 10.0 + 500.0, m.player, {"src": "shot"})
			step(m, SPILL_S)
		var want := 1 if kind_s == "monster" else 2
		ok(
			"a dead %s drops a bonus key" % kind_s,
			mb != null and m.keys.bonus_given == k0 + want,
			"%d -> %d" % [k0, m.keys.bonus_given]
		)
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
		r[k] = keep[k]
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
	var m: Match = build(5, {"teams": 1, "god": true, "map": "skyreach"})
	var r: Dictionary = KeyBonus.rules()
	var keep := float(r["train_crate"])
	r["train_crate"] = 1.0
	var crates: Array = m.chests.filter(func(c): return c.has("ride") and not c["open"])
	var k1 := m.keys.bonus_given
	if not crates.is_empty():
		ChestLoot.drop(m, m.player, crates[0], false)
	r["train_crate"] = keep
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
		if txt.contains('"ckey"') or txt.contains("chest_key"):
			listed.append(f)
	ok("keys are never sold in shops", listed.is_empty(), ", ".join(listed))


# ------------------------------------------------------------------ 7. the Controls card
## The key caps of a built card: [[actions, cap texts], ...] per row.
func _card_caps(id: String) -> Array:
	var v := VBoxContainer.new()
	ControlsCard.fill(v, id)
	var out: Array = []
	var stack: Array = [v]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_meta("actions"):
			var caps: Array = []
			for l in node.find_children("*", "Label", true, false):
				if (l.get_parent() as Node).get_parent() == node.get_child(1):
					caps.append((l as Label).text)
			out.append([node.get_meta("actions"), caps])
		stack.append_array(node.get_children())
	v.free()
	return out


func _caps_match(rows: Array) -> bool:
	for r in rows:
		var want: Array = (r[0] as Array).map(func(a): return Settings.key_cap(String(a)))
		if r[1] != want:
			return false
	return true


func _controls_card() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/controls_card.gd")
	var lit := RegEx.create_from_string('"(?:[A-Z0-9]|Space|Shift|Ctrl|[LRM]MB|Tab|Esc)"')
	ok("the card script writes no key cap itself", lit.search(src) == null)
	var all_slots := true
	var all_caps := true
	for id in Arch.ids():
		var rows := _card_caps(id)
		all_caps = all_caps and rows.size() == 11 and _caps_match(rows)
		for r in ControlsCard.hunter_rows(id):
			all_slots = all_slots and String(r[0]) != "" and String(r[2]) != ""
	ok("every Hunter: five slots with an icon and a name", all_slots)
	ok("every Hunter: all 11 rows show Settings.key_cap", all_caps)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_J
	Settings.rebind("signature", ev)
	ev = InputEventKey.new()
	ev.physical_keycode = KEY_N
	Settings.rebind("jump", ev)
	var after := _card_caps("archer")
	var flat: Array = after.map(func(r): return r[1]).reduce(func(a, b): return a + b, [])
	var shown := _caps_match(after) and flat.has("J") and flat.has("N") and not flat.has("E")
	ok("a rebind shows at once", shown, str(flat))
	Settings.reset_all()
