extends RefCounted
## --reload-swap-check: swapping or dropping a gun mid-reload cancels the reload at once, and a gun
## put down is full the next time anyone picks it up, unless it's picked back up within Loot.REPICK_T
## (2 s): then it keeps the bullets it had, so dropping and re-grabbing is never a free reload.
## Covers the backpack's Equip, the backpack's Drop, a ground swap, a bot's ground swap, a bot that
## keeps fighting after its swap, and the online copy of a put-down gun (Net 0.5.1 "wdrop" carries
## how long ago it left someone's hands). Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("RELOAD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run(m: Match, secs: float) -> void:
	for i in int(round(secs / Match.DT)):
		m.step(Match.DT)

func _mid_reload(h: Hunter) -> void:
	h.ammo = 0
	h.idle_fire = 0.0
	h.reload_t = 0.0
	h.start_reload()

func _full(h: Hunter) -> bool:
	return h.ammo == int(h.wpn["mag"]) and h.reload_t <= 0.0

func _pack_i(h: Hunter, wid: String) -> int:
	for i in h.pack.size():
		if String(h.pack[i].get("wid", "")) == wid: return i
	return -1

func _last(m: Match) -> Dictionary:
	return m.wpicks[m.wpicks.size() - 1]

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 33, "no_drop": true})
	m.set_process(false)
	var P: Hunter = m.player
	for o in m.hunters:
		if o != P: o.ctrl = "idle"; o.teleport(m.world.spawns[-1])
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P.ctrl = "idle"
	P.set_arch("")      # (the classic class kit: two guns of its own to swap between)
	var wids: Array = (Data.CLASSES[P.cls]["weapons"] as Array).filter(func(w): return not Data.weapon_stats(String(w), 1).get("melee", false))
	var wa := String(wids[0]); var wb := String(wids[1 % wids.size()])
	P.pack_cap = 6; P.pack = []
	Loot.equip(P, Loot.weapon(wa, 2))
	P.pack.append(Loot.weapon(wb, 2))
	# ---------------------------------------------------------------- 1. swap mid-reload: cancelled at once
	_mid_reload(P)
	_run(m, 0.2)
	var left_before := P.reload_t
	ok(left_before > 0.0 and P.ammo == 0, "set up: %s empty and reloading (%.2fs left)" % [wa, left_before])
	Pack.use_from_pack(m, P, _pack_i(P, wb))
	ok(P.wid == wb and P.reload_t <= 0.0 and _full(P), "Equip from the pack mid-reload: the reload stops that frame, %s comes out ready (%d/%d)" % [wb, P.ammo, int(P.wpn["mag"])])
	_run(m, Match.DT)
	ok(float(P.anim_s.get("reload", -1.0)) < 0.0, "no reload pose a frame later (anim %s)" % str(P.anim_s.get("reload")))
	var gone := _pack_i(P, wa)
	ok(gone >= 0 and int(P.pack[gone].get("ammo_left", -1)) == 0, "the half-reloaded %s went into the pack still empty: the reload went nowhere" % wa)
	# it never finishes reloading in the pack, however long you wait inside 2 s
	_run(m, maxf(0.1, left_before - 0.1))
	Pack.use_from_pack(m, P, _pack_i(P, wa))
	ok(P.wid == wa and P.ammo == 0 and P.reload_t > float(P.wpn["reload"]) * 0.5, "swapped back inside 2 s: still empty and reloads from the start (%.2fs), no free reload" % P.reload_t)
	# ---------------------------------------------------------------- 2. the 2 s rule: before vs after
	P.reload_t = 0.0; P.ammo = 3
	Pack.use_from_pack(m, P, _pack_i(P, wb))
	_run(m, Loot.REPICK_T - 0.4)
	Pack.use_from_pack(m, P, _pack_i(P, wa))
	ok(P.wid == wa and P.ammo == 3 and P.reload_t <= 0.0, "a part-used %s back %.1fs later: keeps its 3 bullets" % [wa, Loot.REPICK_T - 0.4])
	Pack.use_from_pack(m, P, _pack_i(P, wb))
	_run(m, Loot.REPICK_T + 0.3)
	Pack.use_from_pack(m, P, _pack_i(P, wa))
	ok(P.wid == wa and _full(P), "back %.1fs later: full (%d/%d)" % [Loot.REPICK_T + 0.3, P.ammo, int(P.wpn["mag"])])
	# ---------------------------------------------------------------- 3. dropping mid-reload (the backpack's Drop)
	_mid_reload(P)
	Pack.use_from_pack(m, P, _pack_i(P, wb))      # (wa is in the pack now, empty)
	Pack.drop_from_pack(m, P, _pack_i(P, wa))
	var dropped := _last(m)
	ok(String(dropped["wid"]) == wa and dropped.has("left_at") and int(Pack.ground_item(dropped).get("ammo_left", -1)) == 0, "Drop from the pack: the empty %s lies on the ground, marked as just put down" % wa)
	_run(m, 0.5)
	P.teleport(dropped["pos"])
	Pack.take_ground(m, P, dropped)
	var back_i := _pack_i(P, wa)
	if P.wid != wa and back_i >= 0: Pack.use_from_pack(m, P, back_i)
	ok(P.wid == wa and P.ammo == 0, "grabbed straight back (0.5 s): still empty (%d)" % P.ammo)
	# a gun left on the ground longer comes back full
	Pack.use_from_pack(m, P, _pack_i(P, wb))
	Pack.drop_from_pack(m, P, _pack_i(P, wa))
	var dropped2 := _last(m)
	_run(m, Loot.REPICK_T + 0.5)
	P.teleport(dropped2["pos"])
	Pack.take_ground(m, P, dropped2)
	back_i = _pack_i(P, wa)
	if P.wid != wa and back_i >= 0: Pack.use_from_pack(m, P, back_i)
	ok(P.wid == wa and _full(P), "picked up after %.1fs on the ground: full (%d/%d)" % [Loot.REPICK_T + 0.5, P.ammo, int(P.wpn["mag"])])
	# ---------------------------------------------------------------- 4. a ground swap mid-reload (no backpack: the old gun goes down)
	var B: Hunter = m.hunters.filter(func(x): return x != P)[0]
	B.set_arch("")
	B.teleport(P.pos + Vector3(3.0, 0, 0))
	var bw: Array = (Data.CLASSES[B.cls]["weapons"] as Array).filter(func(w): return not Data.weapon_stats(String(w), 1).get("melee", false))
	var ba := String(bw[0]); var bb := String(bw[1 % bw.size()])
	Loot.equip(B, Loot.weapon(ba, 1))
	_mid_reload(B)
	m.spawn_weapon(bb, 3, B.pos, "", false)
	m._take_weapon(B, _last(m))
	ok(B.wid == bb and _full(B), "a bot swaps on the ground mid-reload: the reload stops, the new gun is full")
	var bl := _last(m)
	ok(String(bl["wid"]) == ba and int(bl["ammo"]) == 0 and bl.has("left_at"), "its old %s lies there empty, marked as just put down" % ba)
	_run(m, 1.0)
	m._take_weapon(B, bl)
	ok(B.wid == ba and B.ammo == 0 and B.reload_t > 0.0, "back on it within 2 s: still empty, so it reloads (%.2fs) rather than getting a full mag" % B.reload_t)
	# ---------------------------------------------------------------- 5. bots still fight after a swap
	B.reload_t = 0.0; B.ammo = int(B.wpn["mag"])
	var T := P
	T.ctrl = "idle"
	B.teleport(T.pos + Vector3(4.0, 0, 0))
	B.ctrl = "bot"
	B.ai.clear()
	var fired := false
	for i in int(6.0 / Match.DT):
		T.hp = T.max_hp; T.armor = T.max_armor
		var a0 := B.ammo
		m.step(Match.DT)
		if B.ammo < a0: fired = true
		if B.reload_t > 0.0 and B.ammo <= 0: break
	var reloaded := false
	for i in int(6.0 / Match.DT):
		T.hp = T.max_hp; T.armor = T.max_armor
		m.step(Match.DT)
		if B.ammo > 0 and B.reload_t <= 0.0: reloaded = true; break
	ok(fired and reloaded, "the bot fights on with the gun it swapped to: fires (%s), runs dry and reloads on its own (%s)" % [fired, reloaded])
	B.ctrl = "idle"
	# ---------------------------------------------------------------- 6. online: the put-down age travels with the gun (Net 0.5.1)
	ok(Net.VERSION != "0.5.0", "the network version moved on for the wider wdrop event (%s)" % Net.VERSION)
	var evs: Array = []
	m.net_on = true
	var sent: Array = Net.out_events.duplicate()
	Loot.equip(P, Loot.weapon(wa, 1))
	P.ammo = 2
	m.spawn_weapon(wb, 2, P.pos + Vector3(0.5, 0, 0), "", false)
	m._take_weapon(P, _last(m))
	for e in Net.out_events:
		if not sent.has(e) and typeof(e) == TYPE_ARRAY and String(e[0]) == "wdrop": evs.append(e)
	m.net_on = false
	var ev: Array = evs[-1] if not evs.is_empty() else []
	ok(ev.size() > 10 and float(ev[10]) >= 0.0 and float(ev[10]) < 0.1 and int(ev[7]) == 2, "the put-down gun's wdrop says it just left someone's hands, with its 2 bullets (%s)" % str(ev.slice(7)))
	# a peer's copy of it, 1 s old: grabbed straight away it keeps 2 bullets
	if ev.size() > 10:
		var fake: Array = ev.duplicate()
		fake[1] = "peer_w1"; fake[10] = 1.0
		m._net_ev(fake, "peer")
		var pw := _last(m)
		ok(String(pw["id"]) == "peer_w1" and pw.has("left_at") and absf(m.time - float(pw["left_at"]) - 1.0) < 0.05, "a peer sees it as put down 1 s ago")
		var Q: Hunter = B
		Loot.equip(Q, Loot.weapon(bb, 1))
		m._take_weapon(Q, pw)
		ok(Q.wid == String(fake[2]) and Q.ammo == 2, "picked up there inside 2 s: still 2 bullets (%d)" % Q.ammo)
		var fresh: Array = ev.duplicate()
		fresh[1] = "peer_w2"; fresh[10] = -1.0
		m._net_ev(fresh, "peer")
		var fw := _last(m)
		ok(not fw.has("left_at"), "fresh loot from a peer carries no put-down mark")
	Net.out_events.clear()
	print("RELOAD SWAP CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
