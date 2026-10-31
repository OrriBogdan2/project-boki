extends RefCounted
## --pickup-check: a weapon you pick up arrives ready to fire. Ground loot, a deathbox, smart loot,
## the backpack's Equip and a bot's ground swap all give a full magazine with no reload going, even
## if you were mid-reload (the reload is simply dropped with the old gun). A gun put down and picked
## straight back up (under Loot.REPICK_T) keeps the bullets it had, so dropping and grabbing isn't a
## free reload; after that it's full again. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("PICKUP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _ready_gun(h: Hunter) -> bool:
	return h.ammo == int(h.wpn["mag"]) and h.reload_t <= 0.0

func _mid_reload(h: Hunter) -> void:
	h.ammo = 0
	h.idle_fire = 0.0
	h.start_reload()

func _run(m: Match, secs: float) -> void:
	for i in int(secs / Match.DT):
		m.step(Match.DT)

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var P: Hunter = m.player
	for o in m.hunters:
		if o != P: o.ctrl = "idle"; o.teleport(m.world.spawns[-1])
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P.ctrl = "idle"
	var wids: Array = Data.CLASSES[P.cls]["weapons"]
	var w1 := String(wids[1 % wids.size()]); var w0 := String(wids[0])
	P.pack_cap = 6; P.pack = []
	Loot.equip(P, Loot.weapon(w0, 2))
	# 1. mid-reload, pick a found gun off the ground: full, no reload, no reload pose
	_mid_reload(P)
	ok(P.reload_t > 0.0, "set up: reloading (%.2fs left)" % P.reload_t)
	var at := P.pos + Vector3(0.5, 0, 0)
	m.spawn_weapon(w1, 3, at, "", false, -1, Loot.weapon(w1, 3, "fire"))
	Pack.take_ground(m, P, m.wpicks[m.wpicks.size() - 1])
	ok(P.wid == w1 and _ready_gun(P), "ground pick-up mid-reload: %s with %d/%d, reload %.2f" % [P.wid, P.ammo, int(P.wpn["mag"]), P.reload_t])
	_run(m, 0.1)
	ok(float(P.anim_s.get("reload", -1.0)) < 0.0 and P.reload_t <= 0.0, "no reload pose after the swap (anim reload %s)" % str(P.anim_s.get("reload")))
	# the old one (mid-reload, empty) went in the pack marked as just put down
	var old_i := -1
	for i in P.pack.size():
		if String(P.pack[i].get("wid", "")) == w0: old_i = i
	ok(old_i >= 0 and int(P.pack[old_i].get("ammo_left", -1)) == 0, "the old gun went in the pack with the bullets it had (0)")
	# 2. straight back out of the pack (under 2s): it still has 0 and has to reload from the start
	_run(m, 0.5)
	Pack.use_from_pack(m, P, old_i)
	ok(P.wid == w0 and P.ammo == 0 and P.reload_t > float(P.wpn["reload"]) * 0.5, "re-equipped within 2s: still empty, reload from 0 (ammo %d, reload %.2f)" % [P.ammo, P.reload_t])
	# ... and the gun that went back in the pack with a full magazine: swapping back keeps its 3/4 mag
	var ni := -1
	for i in P.pack.size():
		if String(P.pack[i].get("wid", "")) == w1: ni = i
	ok(ni >= 0, "the found gun is in the pack now")
	# 3. after 2s in the pack it comes out full and ready
	_run(m, 2.3)
	Pack.use_from_pack(m, P, ni)
	ok(P.wid == w1 and _ready_gun(P), "out of the pack after 2s: full and ready (%d/%d)" % [P.ammo, int(P.wpn["mag"])])
	# a part-used mag: swap out and straight back keeps it
	P.ammo = maxi(1, int(P.wpn["mag"]) - 2)
	var part := P.ammo
	var oi := -1
	for i in P.pack.size():
		if String(P.pack[i].get("wid", "")) == w0: oi = i
	Pack.use_from_pack(m, P, oi)
	_run(m, 0.3)
	for i in P.pack.size():
		if String(P.pack[i].get("wid", "")) == w1: oi = i
	Pack.use_from_pack(m, P, oi)
	ok(P.wid == w1 and P.ammo == part and P.reload_t <= 0.0, "swapped away and straight back: keeps its %d bullets, no reload" % part)
	# 4. a deathbox weapon and smart loot, mid-reload: full, no reload
	var Q: Hunter = m.hunters.filter(func(x): return x != P)[0]
	var bx := {"owner": Q, "team": Q.team, "pos": P.pos, "gems": 0, "seeds": {}, "caught": [], "tonics": 0, "kits": 0, "soul_until": 0.0,
		"prog": {}, "node": null, "empty": false, "gear": [], "weapon": Loot.weapon(w0, 4, "frost"), "pack": []}
	_mid_reload(P)
	Life.take_item(m, P, bx, {"key": "weapon"})
	ok(P.wid == w0 and P.wrar == 4 and _ready_gun(P), "deathbox weapon mid-reload: full, no reload (%d/%d, %.2f)" % [P.ammo, int(P.wpn["mag"]), P.reload_t])
	ok(int((bx["weapon"] as Dictionary).get("ammo_left", -1)) >= 0, "the gun left in the box is marked with its bullets")
	var bx2 := bx.duplicate(true)
	bx2["weapon"] = Loot.weapon(w1, 4, "storm")
	Loot.equip(P, Loot.weapon(w0, 1))
	_mid_reload(P)
	Pack.smart_loot(m, P, bx2)
	ok(P.wid == w1 and P.wrar == 4 and _ready_gun(P), "smart loot's better gun mid-reload: full, no reload (%s %d, %d/%d)" % [P.wid, P.wrar, P.ammo, int(P.wpn["mag"])])
	# 5. a bot's swap on the ground: the old gun is left there; back within 2s keeps its bullets, later it's full
	var B: Hunter = Q
	B.teleport(P.pos + Vector3(3.0, 0, 0))
	Loot.equip(B, Loot.weapon(w0, 1))
	B.ammo = 2
	m.spawn_weapon(w1, 2, B.pos, "", false)
	m._take_weapon(B, m.wpicks[m.wpicks.size() - 1])
	ok(B.wid == w1 and _ready_gun(B), "bot ground swap: full and ready")
	var left: Dictionary = m.wpicks[m.wpicks.size() - 1]
	ok(String(left["wid"]) == w0 and int(left["ammo"]) == 2 and left.has("left_at"), "the bot's old gun lies there with its 2 bullets")
	_run(m, 0.5)
	m._take_weapon(B, left)
	ok(B.wid == w0 and B.ammo == 2, "grabbed straight back (0.5s): still 2 bullets (%d)" % B.ammo)
	var left2: Dictionary = m.wpicks[m.wpicks.size() - 1]
	_run(m, 2.3)
	_mid_reload(B)
	m._take_weapon(B, left2)
	ok(B.wid == w1 and _ready_gun(B), "picked up after 2s, mid-reload: full, reload dropped (%d/%d, %.2f)" % [B.ammo, int(B.wpn["mag"]), B.reload_t])
	# 6. what goes home carries no marks
	var marked := Pack.haul(P).any(func(it): return (it as Dictionary).has("left_at") or (it as Dictionary).has("ammo_left"))
	ok(not marked, "the haul home is clean of put-down marks")
	print("PICKUP CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
