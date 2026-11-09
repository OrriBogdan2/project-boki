extends RefCounted
## --perkorb-check: perks are found as orbs, never chosen from a prompt. No perk prompt exists;
## chests, shrines and bosses drop orbs (1 / 1-2 / a fan of 3) that lean the way the design says;
## taking one of a boss's fan fades the rest for you only (another hunter can still take them);
## orbs sync over Net; the old kit passives are in the pool; bots walk to orbs and take them. Prints PERKORB PASS/FAIL.

var main: Node
var fails := 0
var n := 0

func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	printerr("PERKORB %-62s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_prompt_gone()
	_pool()
	await _drops()
	await _fan()
	await _sync()
	await _bots()
	print("PERKORB DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _start(arch: String, seed_: int, teams := 1) -> Match:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": teams, "squad": 1, "tier": 0, "length": 1e9, "seed": seed_, "no_drop": true, "arch": arch, "cls": Arch.weight(arch)})
	m.set_process(false)
	return m

# ------------------------------------------------------------------ 1. no prompt
func _prompt_gone() -> void:
	var src := ""
	for f in ["res://scripts/match/match.gd", "res://scripts/ui/hud.gd", "res://scripts/match/hunter.gd", "res://scripts/match/lairs.gd"]:
		src += FileAccess.get_file_as_string(f)
	ok("no offer_perks, choose_perk or perk_offer in the code", not (src.contains("offer_perks") or src.contains("choose_perk") or src.contains("perk_offer") or src.contains("_perk_keys_down")))
	ok("no 'Pick a perk' toast", not src.contains("Pick a perk"))
	var m := Match.new()
	ok("Match has no perk prompt methods or state", not m.has_method("offer_perks") and not m.has_method("choose_perk") and m.get("perk_offer") == null)
	m.free()

# ------------------------------------------------------------------ 2. the pool
func _pool() -> void:
	var kinds: Dictionary = PerkOrbs.rules()["kinds"]
	var seen := {}
	var dup := false
	for k in kinds:
		for id in kinds[k]:
			if seen.has(id): dup = true
			seen[id] = k
	var missing: Array = Data.PERKS.keys().filter(func(k): return not seen.has(k))
	ok("every perk is in exactly one orb kind", not dup and missing.is_empty(), str(missing))
	var good := true
	for id in seen:
		if not Data.PERKS.has(id): good = false
	ok("every orb id is a real perk", good)
	for id in ["field_kit", "magpie", "satchel", "spyglass", "tinker_roll"]:
		ok("old kit passive %s is a perk in the pool" % id, Data.PERKS.has(id) and seen.get(id, "") == "kit")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var share := {}
	for src in ["shrine", "chest", "boss"]:
		var c := {"flat": 0, "weapon": 0, "kit": 0}
		for i in 600:
			c[PerkOrbs.kind_of(PerkOrbs.roll(rng, src))] += 1
		share[src] = c
	ok("shrines lean to flat stats", share["shrine"]["flat"] > share["shrine"]["weapon"], str(share["shrine"]))
	ok("chests lean to weapon perks", share["chest"]["weapon"] > share["chest"]["flat"], str(share["chest"]))
	ok("bosses lean to weapon perks even harder", share["boss"]["weapon"] > share["chest"]["weapon"] and share["boss"]["weapon"] > share["boss"]["flat"], str(share["boss"]))

# ------------------------------------------------------------------ 3. drops from chests, shrines, bosses
func _drops() -> void:
	var m := await _start("gunslinger", 11)
	var P: Hunter = m.player
	var before := PerkOrbs.list(m).size()
	ok("a fresh match has no orbs on the ground", before == 0)
	if m.chests.is_empty():
		ok("the map has a chest to open", false)
	else:
		var c: Dictionary = m.chests[0]
		P.teleport(c["pos"] + Vector3(1, 0, 0))
		P.chest_keys = 1      # chests are locked: opening one spends a key (decision 0007)
		m._open_chest(P, c)
		ok("opening a chest drops exactly one orb", PerkOrbs.list(m).size() == before + 1, str(PerkOrbs.list(m).size()))
		var o: Dictionary = PerkOrbs.list(m)[0]
		ok("the orb has a floating icon and a name in the perk's colour", o["node"].get_node("Bob/Icon") is Sprite3D and (o["node"].get_node("Bob/Name") as Label3D).text == Data.PERKS[o["perk"]]["name"] and (o["node"].get_node("Bob/Name") as Label3D).modulate.is_equal_approx(Data.PERKS[o["perk"]]["col"]))
		var y0: float = (o["node"].get_node("Bob") as Node3D).position.y
		m.time += 0.6
		PerkOrbs.update(m, 0.0)
		ok("the orb bobs", absf((o["node"].get_node("Bob") as Node3D).position.y - y0) > 0.001)
	var counts := {}
	for i in 12:
		var k0 := PerkOrbs.list(m).size()
		PerkOrbs.drop(m, "shrine", P.pos + Vector3(8, 0, 8))
		counts[PerkOrbs.list(m).size() - k0] = true
	ok("a shrine drops one or two orbs", counts.keys().all(func(k): return k == 1 or k == 2) and counts.size() == 2, str(counts.keys()))
	if not m.shrines.is_empty():
		var k1 := PerkOrbs.list(m).size()
		m._use_shrine(P, m.shrines[0])
		var d := PerkOrbs.list(m).size() - k1
		ok("using a shrine drops its orbs", d == 1 or d == 2, str(d))
	else:
		ok("using a shrine drops its orbs", false, "no shrine on this map")
	var k2 := PerkOrbs.list(m).size()
	var boss := PerkOrbs.drop(m, "boss", P.pos + Vector3(-8, 0, 8), 0, P)
	var ids: Array = boss.map(func(o): return String(o["perk"]))
	var fan: String = boss[0]["fan"]
	ok("a boss drops three orbs", boss.size() == 3 and PerkOrbs.list(m).size() == k2 + 3)
	ok("the boss's three orbs are all different perks", ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2], str(ids))
	ok("and they share one fan", fan != "" and boss.all(func(o): return o["fan"] == fan))
	var spread := (boss[0]["pos"] as Vector3).distance_to(boss[2]["pos"])
	ok("the fan is spread out, not stacked", spread > 1.5, "%.1f apart" % spread)
	# the Warden itself pays the fan through the real kill path
	var k3 := PerkOrbs.list(m).size()
	var w: Mob = m.spawn_mob("warden", P.pos + Vector3(10, 0, -6))
	if w != null:
		m.on_mob_dead(w, P, {})
		ok("killing the Warden drops a fan of three", PerkOrbs.list(m).size() == k3 + 3, str(PerkOrbs.list(m).size() - k3))
	else:
		ok("killing the Warden drops a fan of three", false, "no warden")
	# the old kit passives keep their kit numbers and work as perks
	for id in ["field_kit", "magpie", "satchel", "spyglass", "tinker_roll"]:
		var g = JSON.parse_string(FileAccess.get_file_as_string("res://content/gear/%s.json" % id)) if FileAccess.file_exists("res://content/gear/%s.json" % id) else null
		if g is Dictionary:
			var same := true
			for k in (g.get("stats", {}) as Dictionary):
				if not is_equal_approx(float(Data.PERKS[id]["stats"].get(k, 0.0)), float(g["stats"][k])): same = false
			ok("perk %s has the kit's numbers" % id, same, str(g.get("stats", {})))
	var cap0: int = P.pack_cap
	var gm0 := PerkOrbs.gem_mult(P)
	var s0: float = P.gear_stat("sight") + P.gear_stat("reload") + P.gear_stat("tonic")
	for id in ["field_kit", "magpie", "satchel", "spyglass", "tinker_roll"]:
		PerkOrbs.grant(P, id)
	ok("the satchel perk adds a backpack slot", P.pack_cap == cap0 + 1, "%d -> %d" % [cap0, P.pack_cap])
	ok("the magpie perk makes gems worth 25% more", is_equal_approx(PerkOrbs.gem_mult(P), gm0 + 0.25))
	ok("the spyglass, tinker's roll and field kit perks add their stats", is_equal_approx(P.gear_stat("sight") + P.gear_stat("reload") + P.gear_stat("tonic") - s0, 0.12 + 0.15 + 0.35))
	m.queue_free()

# ------------------------------------------------------------------ 4. fan: fade for you only
func _fan() -> void:
	var m := await _start("gunslinger", 12, 2)
	var P: Hunter = m.player
	var T: Hunter = null
	for h in m.hunters:
		if h != P: T = h
	var fanned := PerkOrbs.drop(m, "boss", P.pos + Vector3(0, 0, -6), 3, P)
	var a: Dictionary = fanned[0]
	var b: Dictionary = fanned[1]
	var c: Dictionary = fanned[2]
	ok("before taking, all three are open to you", [a, b, c].all(func(o): return PerkOrbs.can_take(m, P, o)))
	P.teleport(a["pos"])
	P.vel = Vector3.ZERO
	PerkOrbs.update(m, 0.016)
	ok("walking into an orb takes it", P.perks.has(a["perk"]) and not PerkOrbs.list(m).has(a), str(P.perks))
	ok("the orb is gone from the ground", not is_instance_valid(a["node"]) or a["node"].is_queued_for_deletion())
	PerkOrbs.update(m, 0.016)
	ok("the other two fade for you", b["faded"] and c["faded"] and not a.get("faded", false))
	ok("you can't take another from that fan", not PerkOrbs.can_take(m, P, b) and not PerkOrbs.can_take(m, P, c))
	P.teleport(b["pos"])
	P.vel = Vector3.ZERO
	var held := P.perks.size()
	PerkOrbs.update(m, 0.016)
	ok("standing in a faded orb does nothing", P.perks.size() == held and PerkOrbs.list(m).has(b))
	ok("a teammate can still take the other two", PerkOrbs.can_take(m, T, b) and PerkOrbs.can_take(m, T, c))
	PerkOrbs.take(m, T, b)
	ok("the teammate takes one: they have the perk", T.perks.has(b["perk"]))
	PerkOrbs.update(m, 0.016)
	ok("the last orb stays on the ground for others", PerkOrbs.list(m).has(c))
	ok("and it stays faded for you", c["faded"] and not PerkOrbs.can_take(m, P, c))
	ok("a teammate who took one can't take the last", not PerkOrbs.can_take(m, T, c))
	m.queue_free()

# ------------------------------------------------------------------ 5. sync
func _sync() -> void:
	var a := await _start("gunslinger", 13, 2)
	var b := await _start("gunslinger", 13, 2)
	Net.out_events.clear()
	a.net_on = true
	var fanned := PerkOrbs.drop(a, "boss", a.player.pos + Vector3(0, 0, -6), 3, a.player)
	var one := PerkOrbs.drop(a, "chest", a.player.pos + Vector3(5, 0, 0), 1, a.player)
	var evs: Array = Net.out_events.duplicate()
	ok("a drop sends one odrop event per orb", evs.size() == 4 and evs.all(func(e): return e[0] == "odrop"), str(evs.size()))
	for e in evs:
		b._net_ev(JSON.parse_string(JSON.stringify(e)), "peer")      # (through the wire's JSON, as Net sends it)
	var la := PerkOrbs.list(a)
	var lb := PerkOrbs.list(b)
	var same := la.size() == lb.size()
	for o in la:
		var twin := lb.filter(func(q): return q["id"] == o["id"] and q["perk"] == o["perk"] and q["fan"] == o["fan"] and (q["pos"] as Vector3).distance_to(o["pos"]) < 0.02)
		if twin.size() != 1: same = false
	ok("the other game spawns the same orbs (id, perk, fan, place)", same and lb.size() == 4, "%d vs %d" % [la.size(), lb.size()])
	ok("receiving orbs sends nothing back", Net.out_events.size() == 4)
	# a bot on A takes one of the fan: B loses that orb, and the fan stays for B's player
	var bot: Hunter = null
	for h in a.hunters:
		if h != a.player: bot = h
	Net.out_events.clear()
	PerkOrbs.take(a, bot, fanned[0])
	ok("taking an orb sends an otake event", Net.out_events.size() == 1 and Net.out_events[0][0] == "otake" and Net.out_events[0][1] == fanned[0]["id"])
	for e in Net.out_events.duplicate():
		b._net_ev(JSON.parse_string(JSON.stringify(e)), "peer")
	ok("the other game removes the taken orb", PerkOrbs.list(b).size() == 3 and PerkOrbs.list(b).all(func(q): return q["id"] != fanned[0]["id"]))
	var rest := PerkOrbs.list(b).filter(func(q): return q["fan"] == fanned[0]["fan"])
	ok("the rest of the fan stays for the player there", rest.size() == 2 and rest.all(func(q): return PerkOrbs.can_take(b, b.player, q)))
	ok("but the hunter who took one can't take another there", rest.all(func(q): return PerkOrbs.took_from_fan(b, bot.nid, q)))
	ok("Net is at 0.18.0 or later", Net.VERSION.naturalnocasecmp_to("0.18.0") >= 0, Net.VERSION)
	# a late joiner: the host sends every live orb again when the player count grows
	var host_was := Net.host
	var me_was := Net.me
	var peers_was := Net.peers.duplicate()
	Net.me = "host"
	Net.host = "host"
	Net.peers = {"host": {}}
	a.net_on = true
	PerkOrbs.update(a, 0.0)
	Net.out_events.clear()
	PerkOrbs.update(a, 0.0)
	ok("with no new player nothing is re-sent", Net.out_events.is_empty())
	Net.peers["late"] = {}
	PerkOrbs.update(a, 0.0)
	var joined: Array = Net.out_events.duplicate()
	var all_odrop: bool = joined.all(func(e): return e[0] == "odrop")
	ok("a new player makes the host re-send the live orbs", joined.size() == 3 and all_odrop, str(joined.size()))
	var c := await _start("gunslinger", 13, 2)
	for e in joined:
		c._net_ev(JSON.parse_string(JSON.stringify(e)), "host")
	var seen: Array = PerkOrbs.list(c).map(func(q): return q["id"])
	var live: Array = PerkOrbs.list(a).map(func(o): return o["id"])
	seen.sort()
	live.sort()
	ok("the late joiner sees the orbs already on the ground", seen.size() == 3 and seen == live)
	Net.out_events.clear()
	PerkOrbs.update(a, 0.0)
	ok("and it is only once", Net.out_events.is_empty())
	Net.host = host_was
	Net.peers = peers_was
	Net.me = me_was
	c.queue_free()
	a.net_on = false
	Net.out_events.clear()
	a.queue_free()
	b.queue_free()

# ------------------------------------------------------------------ 7. bots
func _bots() -> void:
	var m := await _start("gunslinger", 31, 2)
	var P: Hunter = m.player
	var bot: Hunter = null
	for h in m.hunters:
		if h != P: bot = h
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	# an orb a few steps from the bot, nothing else to do: it walks there and takes it
	var at := bot.pos + Vector3(9, 0, 0)
	at.y = m.world.ground_at(at.x, at.z)
	var orb := PerkOrbs.spawn(m, "toughskin", at, "", "", false)
	var g := PerkOrbs.bot_goal(m, bot, Vector3.INF)
	ok("a bot looks for the orb (bot_goal points at it)", g.distance_to(at) < 0.1)
	var t := 0.0
	var went := false
	while t < 14.0 and PerkOrbs.list(m).has(orb):
		m.step(Match.DT); t += Match.DT
		if String(bot.ai.get("goal_kind", "")) == "orb": went = true
	ok("the bot's goal was the orb", went)
	ok("the bot walked to the orb and took it", not PerkOrbs.list(m).has(orb) and bot.perks.has("toughskin"), "%.1fs" % t)
	# a fan: it takes the one it wants most, and only one
	bot.perks.clear()
	var fan_at := bot.pos + Vector3(0, 0, 5)
	var f1 := PerkOrbs.spawn(m, "magpie", fan_at + Vector3(-1.5, 0, 0), "", "fx", false)
	var f2 := PerkOrbs.spawn(m, "brand_fire", fan_at, "", "fx", false)
	var f3 := PerkOrbs.spawn(m, "satchel", fan_at + Vector3(1.5, 0, 0), "", "fx", false)
	ok("a bot ranks Ember Brand above Magpie Pouch and Satchel", PerkOrbs.want(bot, "brand_fire") > PerkOrbs.want(bot, "magpie") and PerkOrbs.want(bot, "brand_fire") > PerkOrbs.want(bot, "satchel"))
	t = 0.0
	while t < 16.0 and PerkOrbs.list(m).has(f2):
		m.step(Match.DT); t += Match.DT
	ok("the bot takes the best orb of the fan", bot.perks.has("brand_fire"), "%.1fs, %s" % [t, str(bot.perks)])
	for i in 60: m.step(Match.DT)
	ok("and only one of the three", bot.perks.count("magpie") + bot.perks.count("satchel") == 0 and PerkOrbs.list(m).has(f1) and PerkOrbs.list(m).has(f3))
	# a bot never wants an orb it has maxed
	bot.add_perk("secondwind")
	var maxed := PerkOrbs.spawn(m, "secondwind", bot.pos + Vector3(30, 0, 0), "", "", false)
	ok("a bot ignores an orb for a perk it has maxed", PerkOrbs.want(bot, "secondwind") == 0.0 and not PerkOrbs.can_take(m, bot, maxed))
	m.queue_free()
