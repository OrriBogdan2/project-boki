extends RefCounted
## --archetype-check: every archetype kit (docs/ARCHETYPES.md) in a flat training arena against
## idle dummies: each dash, passive and resource, the RMB variants, E, R (locked until level 6,
## Bonded R merges the kin), the controls, the weapon locks, kin infusion examples, the kin's own
## ability on C, and the feel spec's telegraph floors and hitstop tiers. Prints AKCHECK PASS/FAIL.

var main: Node
var fails := 0
var n := 0
const DT := 1.0 / 60.0

func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	print("AKCHECK %-34s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

## A flat training strip, the player as `arch`, an idle dummy `dist` ahead (and a second one).
func setup(arch: String, dist: float, kin_sp := "", second := false) -> Array:
	var cls := Arch.weight(arch)
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "cls": cls, "arch": arch, "weapon": Arch.signature(arch)})
	m.set_process(false)
	var P: Hunter = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var W = m.world
	var hx := int(floor(P.pos.x)); var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-6, 7):
		for dx in range(-8, int(dist) + 12):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			W.stairs.erase(i); W.walls.erase(i); W.props.erase(i); W.bush.erase(i)
	var home := Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)
	P.teleport(home); P.vel = Vector3.ZERO
	P.set_arch(arch)
	P.unlock_all()
	P.lvl = 6; P.slot_lv["ult"] = 1
	P.dashes = P.max_dashes()
	if P.kin:
		var o: Kin = P.kin
		o.dead = true; m.kins.erase(o); o.queue_free(); P.kin = null
	if kin_sp != "":
		var rec := Save.new_kin(kin_sp); rec["trust"] = 95.0
		var k: Kin = m.give_kin(P, rec)
		k.stow(); k.brain.think_t = 1e9
	P.ult = 0.0
	var T: Hunter = m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(dist, 0, 0), {"arch": "none"})
	T.max_hp = 10000.0; T.hp = T.max_hp; T.armor = 0.0; T.max_armor = 0.0
	var T2: Hunter = null
	if second:
		T2 = m.make_hunter("T2", 5, "medium", "Target2", "idle", {}, home + Vector3(dist + 2.0, 0, 0), {"arch": "none"})
		T2.max_hp = 10000.0; T2.hp = T2.max_hp; T2.armor = 0.0; T2.max_armor = 0.0
	for i in 5: m.step(DT)
	aim_at(P, T.pos)
	return [m, P, T, T2, home, lv]

func aim_at(P: Hunter, p: Vector3) -> void:
	P.inp["aim"] = p + Vector3(0, 0.9, 0); P.inp["aim_y"] = p.y

func step(m: Match, secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		if each.is_valid(): each.call()
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT); t += DT

func fresh(T: Hunter) -> void:
	T.hp = T.max_hp; T.stun_t = 0.0; T.root_t = 0.0; T.slow_t = 0.0; T.burn_t = 0.0; T.vel = Vector3.ZERO; T.reveal_t = 0.0; T.cc_immune_t = 0.0
	T.dr = {}; T.dr_stun = false; T.knock_t = 0.0
	T.set_meta("marks", {})

func dmg(T: Hunter) -> float:
	return T.max_hp - T.hp

## Taps RMB (press, released next frame).
func tap(m: Match, P: Hunter) -> void:
	P.inp["sec_hold"] = false
	P.ak.press_rmb()
	m.step(DT)

## Holds RMB for `t` seconds, then lets go.
func hold(m: Match, P: Hunter, t: float) -> void:
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, t, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	m.step(DT)

## Starts a Boki merge on `h` the way R does (the full merge when it has a Boki to merge with, else the surge).
func merge_now(h: Hunter) -> bool:
	h.ult = 1.0
	if not KinMerge.cast(h):
		KinMerge.surge(h)
	return KinMerge.active(h)

func done(m: Match) -> void:
	m.queue_free()
	await main.get_tree().process_frame

func run(main_node: Node) -> void:
	main = main_node
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--ak-only="): only = String(a).substr(10)
	for who in ["mage", "gunslinger"]:
		if "--%s-combo-check" % who in OS.get_cmdline_user_args():
			var hc = load("res://tools/hero_combo_check.gd").new()      # Vireo's and Venator's cross-ability interactions
			await hc.run(main_node, who)
			return
	if "--kit-combo-check" in OS.get_cmdline_user_args():
		await _combos()
		print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
		main.get_tree().quit(1 if fails > 0 else 0)
		return
	if only != "":
		# one archetype's section only (debugging)
		await call("_" + only)
		print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
		main.get_tree().quit()
		return
	_controls()
	_data()
	await _thief()
	await _archer()
	await _mage()
	await _gunslinger()
	await _juggernaut()
	await _bulwark()
	await _combos()
	await _levels_and_bond()
	await _kin_ability()
	await _infusion()
	_feel()
	print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

# ------------------------------------------------------------------ controls and data
func _has_key(action: String, key: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and ((e as InputEventKey).keycode == key or (e as InputEventKey).physical_keycode == key): return true
	return false

func _has_mouse(action: String, b: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == b: return true
	return false

func _controls() -> void:
	ok("keys: E archetype utility", _has_key("signature", KEY_E))
	ok("keys: R archetype ultimate", _has_key("ultimate", KEY_R))
	ok("keys: C kin ability", _has_key("kin_ability", KEY_C))
	ok("keys: G send/recall + MMB alt", _has_key("throw", KEY_G) and _has_mouse("throw", MOUSE_BUTTON_MIDDLE))
	ok("keys: Q glove, Shift dash, RMB", _has_key("gear1", KEY_Q) and _has_key("dash", KEY_SHIFT) and _has_mouse("secondary", MOUSE_BUTTON_RIGHT))
	ok("keys: binding version bumped", Settings.KEYS_V >= 3, "keys_v %d" % Settings.KEYS_V)
	ok("keys: rebindable list names them", Settings.ACTIONS.any(func(a): return a[0] == "kin_ability"))

func _data() -> void:
	# rank previews: always the NEXT rank first (rank 2 at rank 1), then rank 3's special; every
	# ability of every archetype has a concrete rank 2
	var rk_ok := true
	for a in Arch.ids():
		for sl in ["sec", "dash", "kin", "ult"]:
			if sl == "ult" and not Arch.def(a).has("r"): continue      # Vireo and Venator have no R (Boki Merge owns it)
			var r2 := String(Arch.def(a).get("rank2", {}).get(sl, ""))
			if not (r2.contains("->") and r2.length() > 20): rk_ok = false
	ok("ranks: every ability has a concrete rank 2", rk_ok)
	var n1 := Arch.next_ranks("archer", "sec", 1); var n2 := Arch.next_ranks("archer", "sec", 2); var n3 := Arch.next_ranks("archer", "sec", 3)
	ok("ranks: next rank first (2 at 1, 3 at 2, none at max)", n1.size() == 2 and n1[0][0] == "Rank 2" and n1[1][0] == "Rank 3" and n2.size() == 1 and n2[0][0] == "Rank 3" and n3.is_empty(), str(n1))
	var ids := Arch.ids()
	ok("data: at least the six archetypes", ids.size() >= 6, str(ids))
	for w in ["light", "medium", "heavy"]:
		ok("data: %s has archetypes" % w, Arch.of_class(w).size() >= 1, str(Arch.of_class(w)))
	var bad: Array = []
	for a in ids:
		for wid in Arch.weapons(a):
			if Content.weapon(String(wid)) == null: bad.append("%s:%s" % [a, wid])
		for k in ["dash", "rmb", "e", "resource", "order"]:
			if not Arch.def(a).has(k): bad.append("%s missing %s" % [a, k])
	ok("data: every kit complete, weapons exist", bad.is_empty(), str(bad))
	ok("weapons: one signature weapon each", ids.all(func(x): return Arch.weapons(x).size() == 1 and Arch.signature(x) != "" and Arch.weapon_ok(x, Arch.signature(x))), str(ids.map(func(x): return Arch.signature(x))))
	ok("weapons: Thief blades / Archer bow / Vireo coil / Bulwark shield", Arch.signature("thief") == "twin_blades" and Arch.signature("archer") == "longbow" and Arch.signature("mage") == "coilcaster" and Arch.signature("bulwark") == "tower_shield")
	ok("weapons: another archetype's weapon is not yours", not Arch.weapon_ok("bulwark", "greatsword") and not Arch.weapon_ok("thief", "smg"))
	ok("weapons: asking for another weapon gives the signature", Arch.weapon_for("gunslinger", "medium", "longsword") == "quill_rifle")
	var sup_ok := true
	for a in ["tender", "rimewright"]:
		var sd2 := Arch.def(a)
		for k in ["card", "passive", "dash", "rmb", "e", "rank2", "rank3", "rank_next", "tells"]:
			if not sd2.has(k): sup_ok = false
		if sd2.has("r") or (sd2["card"] as Dictionary).has("r"): sup_ok = false          # no R for the support pair
		if (sd2["rmb"] as Dictionary).get("variants", {}).is_empty() or String(sd2["e"].get("desc", "")).length() < 40: sup_ok = false
	ok("data: support heroes complete, no R", sup_ok)
	ok("data: Thief and Juggernaut have no R (it is the Boki Merge); Jackpot and the crash are data", Arch.def("thief").has("jackpot") and Arch.def("juggernaut")["rmb"].has("crash") and not Arch.def("thief").has("r") and not Arch.def("juggernaut").has("r") and not Arch.def("thief")["card"].has("r") and not Arch.def("juggernaut")["card"].has("r"))
	ok("weapons: fix keeps the class", Arch.fix("thief", "heavy") == "juggernaut" and Arch.fix("bulwark", "heavy") == "bulwark")

# ------------------------------------------------------------------ Thief (kits2: a port of SUPERVIVE's Shiv)
func _thief() -> void:
	var r := setup("thief", 4.0, "", true)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: ThiefKit = P.ak
	ok("thief: kit + model", K != null and P.model.get_meta("arch") == "thief", P.wid)
	# Marks (Malice): every weapon hit stacks one on the target; +8% per Mark on your weapon hits, up to 5
	K.mark_gap = {}
	K.on_deal(T, 5.0, {"src": "shot"})
	K.mark_gap = {}
	K.on_deal(T, 5.0, {"src": "shot"})
	ok("thief passive: every weapon hit stacks a Mark", K.marks_on(T) == 2, "marks %d" % K.marks_on(T))
	ok("thief passive: +8% per Mark on weapon hits only", absf(K.outgoing(T, 10.0, {"src": "shot"}) - 11.6) < 0.01 and absf(K.outgoing(T, 10.0, {"src": "abil", "ab": "utility"}) - 10.0) < 0.01, "%.2f" % K.outgoing(T, 10.0, {"src": "shot"}))
	K.mark_gap = {}
	K.on_deal(T, 5.0, {"src": "abil", "ab": "utility"})
	ok("thief passive: ability hits don't stack", K.marks_on(T) == 2)
	K.jp_cd = 99.0          # (the fifth Mark's Jackpot has its own test below)
	K.add_mark(T, 9, true)
	ok("thief passive: five Marks at most", K.marks_on(T) == 5 and K.res_text() == "5/5", K.res_text())
	# Vault (Quickflip): a flip, a burst of speed, the next hit Primed; landing it resets Vault
	fresh(T); P.teleport(home); P.dashes = P.max_dashes()
	var d0 := P.dashes
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	step(m, 0.3)
	P.inp["move"] = Vector2.ZERO
	ok("thief dash: Vault flips, speeds, Primes", P.flat_dist(home) > 2.5 and K.primed_t > 0.0 and K.move_k() > 1.2 and P.dashes < d0 - 0.5, "moved %.1f primed %.2f speed x%.2f dashes %.2f" % [P.flat_dist(home), K.primed_t, K.move_k(), P.dashes])
	ok("thief HUD: PRIMED label + dash dot", K.ready_label().begins_with("PRIMED") and P.slot_info("dash").get("full", false) and not P.slot_info("sec").get("full", false), K.ready_label())
	var hp0 := dmg(T)
	K.on_deal(T, 5.0, {"src": "shot"})
	ok("thief Primed hit: +damage, 2 Marks, Shred, speed ends, Vault back", dmg(T) - hp0 >= 9.0 and K.marks_on(T) == 2 and T.vuln_t > 0.0 and K.move_k() <= 1.0 and P.dashes >= P.max_dashes() - 0.01 and K.primed_t <= 0.0 and K.primed_hits == 1,
		"dealt %.0f marks %d vuln %.1f speed x%.2f dashes %.2f" % [dmg(T) - hp0, K.marks_on(T), T.vuln_t, K.move_k(), P.dashes])
	# RMB: the Bola grounds its first foe and flies on; a second foe along its path and both are stunned
	fresh(T); fresh(T2); T2.teleport(T.pos + Vector3(3.0, 0, 0)); P.teleport(home); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.5)
	ok("thief RMB: Bola flies on and tangles two (Grounded + stun)", K.bola_pairs == 1 and KitStatus.grounded(T) and KitStatus.grounded(T2) and T.stun_t > 0.0 and T2.stun_t > 0.0 and dmg(T) >= 16.0,
		"pairs %d grounded %s/%s stun %.2f/%.2f dmg %.0f" % [K.bola_pairs, KitStatus.grounded(T), KitStatus.grounded(T2), T.stun_t, T2.stun_t, dmg(T)])
	T.stun_t = 0.0
	var tx := T.pos
	T.dashes = 1.0
	T.do_dash()
	T.do_jump()
	m.step(DT)
	ok("thief Bola: Grounded can't dash or jump", T.dashes >= 0.99 and T.roll_t <= 0.0 and T.vel.y < 1.0, "dashes %.2f vy %.1f" % [T.dashes, T.vel.y])
	step(m, 2.2)
	fresh(T); fresh(T2); T.teleport(tx); T2.teleport(tx + Vector3(0, 0, 2.2)); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.5)
	ok("thief RMB: a foe beside the path isn't caught", KitStatus.grounded(T) and T.stun_t <= 0.0 and T2.stun_t <= 0.0 and K.bola_pairs == 1)
	step(m, 2.2)
	# E: the Shadow Knife sticks in a foe (slow 50%); recast steps to it; or you step when it runs out
	fresh(T); fresh(T2); T2.teleport(home + Vector3(0, 0, 9.0)); T.teleport(tx); P.teleport(home); aim_at(P, T.pos)
	P.ak.use_e()
	step(m, 0.3)
	ok("thief E: the knife sticks in them (slow 50%, damage)", not K.knife.is_empty() and K.knife.get("target") == T and T.slow_t > 0.0 and T.slow_k >= 0.49 and dmg(T) >= 7.0, "slow %.2f k %.2f dmg %.0f" % [T.slow_t, T.slow_k, dmg(T)])
	P.ak.use_e()
	m.step(DT)
	ok("thief E recast: step to it", P.flat_dist(T) < 1.8 and K.knife.is_empty(), "dist %.1f" % P.flat_dist(T))
	K.cd["e"] = 0.0; P.teleport(home); fresh(T); aim_at(P, T.pos)
	P.ak.use_e()
	step(m, 0.3 + 5.1)
	ok("thief E: waiting steps you anyway (5s)", P.flat_dist(T) < 1.8 and K.knife.is_empty(), "dist %.1f" % P.flat_dist(T))
	# Jackpot (a Mark trigger, no key): the fifth Mark releases a burst of knives at that foe, every knife
	# refreshes the Marks, and one Vault is free; it rests so a long fight can't chain it
	fresh(T); fresh(T2); P.teleport(home); T.teleport(home + Vector3(3.5, 0, 0)); T2.teleport(home + Vector3(7.0, 0, 0.5))
	K.jp_cd = 0.0; K.quick = 0; K.quick_t = 0.0; K.mark_gap = {}; K.primed_t = 0.0
	K.add_mark(T, 4, true)
	T.get_meta("marks")[P.nid][1] = 0.75
	var jk0 := K.jackpot_hits; var jb0 := K.jackpots
	var ds := P.dashes
	K.add_mark(T, 1, true)
	ok("thief Jackpot: the fifth Mark releases it (a free Vault, then it rests)", K.jackpots == jb0 + 1 and K.quick == 1 and K.jp_cd > 5.0, "jackpots %d quick %d rest %.1f" % [K.jackpots - jb0, K.quick, K.jp_cd])
	step(m, 0.9)
	ok("thief Jackpot: 4 knives land on that foe only, Marks refreshed", K.jackpot_hits - jk0 == 4 and dmg(T) >= 17.0 and dmg(T2) <= 0.01 and K.marks_on(T) == 5 and float(T.get_meta("marks")[P.nid][1]) > 3.0,
		"knives %d took %.0f other %.0f marks %d left %.2f" % [K.jackpot_hits - jk0, dmg(T), dmg(T2), K.marks_on(T), float(T.get_meta("marks")[P.nid][1])])
	P.do_dash()
	step(m, 0.15)
	ok("thief Jackpot: the free Vault costs no charge and Primes", K.quick == 0 and P.dashes >= ds - 0.01 and K.primed_t > 0.0, "quick %d dashes %.2f -> %.2f" % [K.quick, ds, P.dashes])
	K.set_marks(T, 0)
	K.add_mark(T, 5, true)
	step(m, 0.6)
	ok("thief Jackpot: resting, a second fifth Mark does nothing", K.jackpots == jb0 + 1 and K.jackpot_hits - jk0 == 4)
	# Net 0.15.0: the kit's full-body move (id and age) rides the hunter snapshot, so remote players see the pose
	K.play("thf_vault_f")
	step(m, 0.2)
	var nm := ArchKit.net_move(P)
	K.anim_id = ""
	var pk: Array = []
	pk.resize(ArchKit.NET_MOVE_AT)
	pk.append_array(nm)
	ArchKit.apply_net_move(P, pk)
	ok("net: the kit move id and age ride the hunter snapshot", String(nm[0]) == "thf_vault_f" and K.anim_id == "thf_vault_f" and absf((m.time - K.anim_at) - float(nm[1])) < 0.01 and Net.VERSION.naturalnocasecmp_to("0.16.0") >= 0, "%s %s" % [str(nm), Net.VERSION])
	# a knock (Resolve) heals you a fifth of your health in all: 15% from the passive, 5% from the takedown reset
	P.hp = P.max_hp * 0.5
	var php := P.hp
	T.hp = 4.0
	T.hurt(10.0, P, {"src": "shot"})
	step(m, 0.1)
	ok("thief passive: a knock heals (20% in all)", T.downed and K.knocks_seen >= 1 and P.hp >= php + P.max_hp * 0.19, "hp %.0f -> %.0f" % [php, P.hp])
	await done(m)

# ------------------------------------------------------------------ Archer
func _archer() -> void:
	var r := setup("archer", 7.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	var home: Vector3 = r[4]; var lv: int = r[5]
	var K: ArcherKit = P.ak
	# Focus builds standing still and makes the next shot instant (+20% range)
	K.res = 0.0
	P.inp["move"] = Vector2.ZERO
	step(m, 1.6)
	ok("archer passive: Focus fills standing still", K.res >= 99.0, "%.0f" % K.res)
	ok("archer resource tell: full", K.tell == "full")
	P.equip("sniper")
	step(m, 0.35)
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	ok("archer Focus: sniper fires at once", P.warm_t <= 0.0 and P.ammo < int(P.wpn["mag"]) and K.res < 1.0, "warm %.2f ammo %d" % [P.warm_t, P.ammo])
	P.equip("longbow")
	step(m, 0.3)
	# the Longbow draws: a full draw hits for 60
	fresh(T); K.res = 0.0
	step(m, 0.05, func(): P.inp["fire"] = true)
	step(m, 1.0, func(): P.inp["fire"] = true; K.res = 0.0)
	P.inp["fire"] = false
	step(m, 0.5)
	ok("archer weapon: Longbow full draw", dmg(T) >= 50.0, "took %.0f" % dmg(T))
	# Snare tap: a foe hit is rooted; a miss plants a Tripwire
	fresh(T); K.ch_rmb = 2.0
	tap(m, P)
	step(m, 0.3)
	ok("archer RMB tap: snare roots", T.root_t > 0.0 and dmg(T) >= 7.0, "root %.2f" % T.root_t)
	var nt: int = m.verbs.traps.size()
	P.inp["aim"] = P.pos + Vector3(0, 0, 5.0)
	tap(m, P)
	step(m, 0.5)
	ok("archer RMB tap: Tripwire on the ground", m.verbs.traps.size() > nt and K.trips.size() >= 1, "%d traps" % m.verbs.traps.size())
	# Pinning Shot: pushed into a wall within 3m, pinned
	fresh(T); K.ch_rmb = 2.0; K.cd["rmb"] = 0.0
	if "--ak-debug" in OS.get_cmdline_user_args(): print("PIN build: T at %s P at %s vel %s" % [str(T.pos), str(P.pos), str(T.vel)])
	var W: World = m.world
	# (packed arrays are copied on write: edit a copy and put it back, so the wall really stands)
	var wk: PackedByteArray = W.kind; var wl: PackedByteArray = W.level
	for dz in range(-3, 4):
		for dx in range(0, 3):
			var i: int = W.idx(int(T.pos.x) + dx, int(T.pos.z) + dz)
			wk[i] = World.T_GROUND
			wl[i] = lv if dx < 2 else lv + 3
	W.kind = wk; W.level = wl
	aim_at(P, T.pos)
	K.res = 0.0       # (a full Focus outranks the hold variant)
	hold(m, P, 1.15)
	if "--ak-debug" in OS.get_cmdline_user_args(): print("PIN after hold: T at %s P at %s ground ahead %s %s %s lvl %s" % [str(T.pos), str(P.pos), W.ground_at(T.pos.x + 1.0, T.pos.z), W.ground_at(T.pos.x + 1.6, T.pos.z), W.ground_at(T.pos.x + 2.2, T.pos.z), W.level[W.idx(int(T.pos.x) + 2, int(T.pos.z))]])
	step(m, 0.5)
	if "--ak-debug" in OS.get_cmdline_user_args(): print("PIN T at %s vx %.2f stun %.2f immune %.2f dr %s" % [str(T.pos), T.vel.x, T.stun_t, T.cc_immune_t, str(T.dr)])
	ok("archer RMB hold: Heavy Shot pins to the wall", K.last_variant == "hold" and dmg(T) >= 14.0 and T.stun_t > 0.0, "took %.0f stun %.2f" % [dmg(T), T.stun_t])
	# a full charge: the hold reached full (the shared charge feedback ticked)
	ok("archer RMB hold: charge reached full", K.charge_fulls >= 1 and K.charge_last >= 0.99, "fulls %d last %.2f" % [K.charge_fulls, K.charge_last])
	# Deadeye: a full-Focus shot into a pinned (rooted) foe pays out a gold second hit
	var dd0 := dmg(T); var de0 := K.deadeyes
	T.root_t = maxf(T.root_t, 1.0)
	K.res = K.res_max()
	ok("archer resource full: Deadeye armed", K.full_ready() and K.ready_label() != "" and K.pinned(T))
	P.fire_cd = 0.0; P.ammo = maxi(P.ammo, 1); P.reload_t = 0.0
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	step(m, 0.5)
	if "--ak-debug" in OS.get_cmdline_user_args(): print("DEADEYE dd0 %.1f now %.1f" % [dd0, dmg(T)])
	ok("archer Deadeye: Focus shot into a pinned foe", K.deadeyes == de0 + 1 and dmg(T) - dd0 >= 70.0, "deadeyes %d dealt %.0f" % [K.deadeyes - de0, dmg(T) - dd0])
	# ... and not into a free one
	fresh(T); K.res = K.res_max(); de0 = K.deadeyes
	step(m, 0.9)      # (past the pin's grace)
	K.res = K.res_max()
	P.fire_cd = 0.0; P.ammo = maxi(P.ammo, 1); P.reload_t = 0.0
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	step(m, 0.5)
	ok("archer Deadeye: none without a pin", K.deadeyes == de0 and dmg(T) >= 50.0, "dealt %.0f" % dmg(T))
	# Grapple Arrow: bites the ledge and climbs on top
	P.teleport(home); P.vel = Vector3.ZERO; P.dashes = P.max_dashes()
	for dz in range(-3, 4):
		for dx in range(3, 6):
			W.level[W.idx(int(home.x) + dx, int(home.z) + dz)] = lv + 2
	P.inp["aim"] = home + Vector3(5.0, 0, 0)
	P.do_dash()
	step(m, 0.7)
	ok("archer dash: Grapple zips onto a ledge", P.pos.y > home.y + 1.2 and K.st.get("last_grapple") == "zip", "y %.1f -> %.1f" % [home.y, P.pos.y])
	P.teleport(home); P.dashes = P.max_dashes()
	P.inp["aim"] = home + Vector3(0, 0, 6.0)
	P.do_dash()
	step(m, 0.4)
	ok("archer dash: no bite hops back", K.st.get("last_grapple") == "hop" and P.pos.z < home.z - 1.5, "z %.1f" % (P.pos.z - home.z))
	# Plunge from the air
	P.teleport(home + Vector3(0, 3.0, 0)); P.grounded = false; P.vel = Vector3(0, -2, 0); K.ch_rmb = 2.0; K.cd["rmb"] = 0.0
	K.res = 0.0     # (Focus filled while standing on the ledge after the zip: a full Focus shot outranks the air variant)
	P.ak.press_rmb()
	ok("archer RMB air: Plunge lifts you", K.last_variant == "air" and P.vel.y > 5.0, "vy %.1f" % P.vel.y)
	step(m, 1.2)
	# the bow's perfect window: let go right at full draw for +25%
	P.teleport(home); P.vel = Vector3.ZERO; fresh(T); T.teleport(home + Vector3(-6.5, 0, 0)); aim_at(P, T.pos)    # (clear of the test walls east)
	P.equip("longbow"); step(m, 0.4)
	var pf0 := K.perfects
	step(m, 0.95, func(): P.inp["fire"] = true; K.res = 0.0; aim_at(P, T.pos))
	P.inp["fire"] = false
	step(m, 0.5)
	ok("archer bow: perfect release +25%", K.perfects == pf0 + 1 and dmg(T) >= 74.0, "perfects %d took %.0f" % [K.perfects - pf0, dmg(T)])
	# E: Hail Wall: a line of falling arrows; damage over time, slow, blight
	P.teleport(home); fresh(T); T.teleport(home + Vector3(6, 0, 0))
	P.inp["aim"] = T.pos
	P.ak.use_e()
	ok("archer E: Hail Wall cast", K.in_e())
	step(m, 2.0, func(): K.res = 0.0)
	ok("archer E: Hail Wall hurts, slows, blights", dmg(T) >= 10.0 and T.slow_t > 0.0 and T.blight_t > 0.0, "took %.0f slow %.2f blight %.2f" % [dmg(T), T.slow_t, T.blight_t])
	step(m, 3.0)
	ok("archer E: Hail Wall ends", not K.in_e())
	await done(m)

# ------------------------------------------------------------------ Mage
func _mage() -> void:
	var r := setup("mage", 5.0, "", true)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: MageKit = P.ak
	ok("vireo: Coilcaster in hand, light weight", P.wid == "coilcaster" and Arch.weight("mage") == "light" and not Arch.def("mage").has("r"))
	# Sparks: weapon hits load one each, four make a Live foe
	K.on_deal(T, 4.0, {"src": "shot"})
	ok("vireo passive: a weapon hit loads a Spark", K.spark_n(T) == 1)
	K.add_spark(T, 3)
	ok("vireo passive: four Sparks = Live", K.live(T) and K.full_ready() and K.res_text() == "4/4")
	# Wirerun held through a Live foe: Blowout, dash back at once
	P.teleport(home); aim_at(P, T.pos); P.dashes = P.max_dashes(); fresh(T)
	P.inp["dash_down"] = true
	P.do_dash()
	ok("vireo dash: press starts the lane, the charge spent on the press", not K.wire.is_empty() and P.dashes < 1.0)
	step(m, 0.5, func(): P.inp["dash_down"] = true; aim_at(P, T.pos))
	P.inp["dash_down"] = false
	step(m, 0.5)
	ok("vireo Wirerun through Live: Blowout + dash back", K.blowouts == 1 and not K.live(T) and P.dashes >= 1.0 and dmg(T) >= 17.0, "blowouts %d took %.0f dashes %.1f" % [K.blowouts, dmg(T), P.dashes])
	# a knock heals 15%
	P.hp = 20.0
	var kt := P.hp
	T2.hp = 1.0
	K.on_deal(T2, 5.0, {"src": "shot"}); T2.hp = 0.0
	K.on_deal(T2, 5.0, {"src": "shot"})
	ok("vireo passive: a knock heals", P.hp > kt + 10.0, "hp %.0f" % P.hp)
	T2.hp = T2.max_hp
	# Coilshot hold: damage, a throw, a mote that gives the dash back
	P.teleport(home); fresh(T); fresh(T2); T2.teleport(home + Vector3(12, 0, 0)); step(m, 0.2); aim_at(P, T.pos); P.dashes = 0.0
	hold(m, P, 1.0)
	step(m, 0.9)
	ok("vireo RMB hold: Coilshot hits + Sparks", K.last_variant == "hold" and dmg(T) >= 12.0 and K.spark_n(T) >= 1, "took %.0f" % dmg(T))
	ok("vireo RMB: a hit drops a charge orb", K.motes.size() >= 1, str(K.motes.size()))
	ok("vireo RMB: the orb does not give Wirerun back (only a full-Static foe does)", P.dashes < 1.0)
	# Skycall: lightning flings and grounds
	P.teleport(home); fresh(T); T.teleport(home + Vector3(5, 0, 0)); step(m, 0.2); aim_at(P, T.pos); K.cd["e"] = 0.0
	var x0 := T.pos.x
	P.ak.use_e()
	step(m, 1.2)
	ok("vireo E: Skycall damages, flings, Sparks", dmg(T) >= 12.0 and T.pos.x > x0 + 1.0 and K.spark_n(T) >= 1, "took %.0f moved %.1f" % [dmg(T), T.pos.x - x0])
	ok("vireo E: Grounded (no dashing)", KitStatus.grounded(T))
	var d0 := T.dashes
	T.do_dash()
	ok("vireo E: a Grounded foe can't dash", is_equal_approx(T.dashes, d0))
	await done(m)

func _gunslinger() -> void:
	var r := setup("gunslinger", 5.0, "", true)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: GunslingerKit = P.ak
	var medium := Arch.weight("gunslinger") == "medium"
	ok("venator: Quill Rifle in hand, medium, no R", P.wid == "quill_rifle" and medium and not Arch.def("gunslinger").has("r"))
	# Fever: abilities stack lifesteal (4 x 5%)
	P.hp = 60.0
	K.on_deal(T, 10.0, {"src": "abil", "ab": "utility"})
	K.on_deal(T, 10.0, {"src": "abil", "ab": "k1"})
	ok("venator passive: abilities build Fever", K.res >= 2.0)
	var hp0 := P.hp
	K.on_deal(T, 100.0, {"src": "shot"})
	ok("venator passive: Fever heals off damage", P.hp > hp0 + 8.0, "healed %.1f" % (P.hp - hp0))
	K.res = 0.0
	# Burr Charge: thrown past the foe, it blasts a cone back from the ground at the lane's end, Dazing
	fresh(T); T2.teleport(home + Vector3(12, 0, 0)); P.teleport(home); T.teleport(home + Vector3(7, 0, 0)); step(m, 0.2); aim_at(P, T.pos); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	tap(m, P)
	step(m, 1.6)
	var dazed := KitStatus.rattled(T) and K.rattles >= 1
	ok("venator RMB: the cone blast hits and Dazes", dmg(T) >= 12.0 and dazed, "took %.0f" % dmg(T))
	ok("venator RMB: the blast fed Fever", K.res >= 1.0, "fever %.0f" % K.res)
	var base := K.outgoing(T, 10.0, {"src": "shot"})
	ok("venator Dazed: rifle +90%", is_equal_approx(base, 19.0), "%.1f" % base)
	# Longneedle: charge, then a piercing beam
	fresh(T); KitStatus.clear_rattled(T); K.cd["e"] = 0.0; aim_at(P, T.pos)
	P.ak.use_e()
	ok("venator E: Longneedle winds up slowed", not K.needle.is_empty() and K.move_k() < 1.0)
	step(m, 0.5)
	var early := dmg(T)
	step(m, 0.6)
	ok("venator E: needle fires after the charge, shaves its cooldown", early < 0.5 and dmg(T) >= 30.0 and float(K.cd["e"]) < 12.0 * 0.75, "early %.0f took %.0f cd %.1f" % [early, dmg(T), float(K.cd["e"])])
	# Slipstep: tap skids, hold slides, early release refunds
	P.teleport(home); P.dashes = P.max_dashes(); P.inp["move"] = Vector2(0, 1)
	P.do_dash(); step(m, 0.4)
	ok("venator dash tap: Slipstep skid", K.last_dash_kind == "step" and P.flat_dist(home) > 1.8, "moved %.1f" % P.flat_dist(home))
	P.inp["move"] = Vector2.ZERO
	await done(m)

# ------------------------------------------------------------------ Juggernaut (kits2: a port of SUPERVIVE's Brall)
func _juggernaut() -> void:
	var r := setup("juggernaut", 2.4)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	var home: Vector3 = r[4]; var lv: int = r[5]
	var K: JuggernautKit = P.ak
	ok("juggernaut: greatsword, 2 Rampage charges", P.wid == "greatsword" and P.max_dashes() >= 2.0, "%s %.0f" % [P.wid, P.max_dashes()])
	# Rage (Blazing Spirit): damage fills it; nothing below full; Enraged gives damage, dash and ability haste
	K.res = 0.0; K.enraged_t = 0.0
	K.on_deal(T, 40.0, {"src": "shot"})
	ok("juggernaut passive: damage fills Rage", K.res > 25.0 and K.res < 31.0, "rage %.1f" % K.res)
	ok("juggernaut passive: no bonus below full", absf(K.outgoing(T, 100.0, {}) - 100.0) < 0.1)
	K.gain_rage(100.0)
	ok("juggernaut passive: full = Enraged (+15%)", K.enraged_t > 0.0 and absf(K.outgoing(T, 100.0, {}) - 115.0) < 0.1 and K.ready_label() == "ENRAGED", "%.1f" % K.outgoing(T, 100.0, {}))
	K.cd["e"] = 10.0; P.dashes = 0.0
	step(m, 1.0)
	ok("juggernaut Enraged: ability + dash haste", float(K.cd["e"]) < 8.85 and P.dashes > 1.0 / P.dash_regen() * 1.08, "e cd %.2f dashes %.3f" % [float(K.cd["e"]), P.dashes])
	K.enraged_t = 0.0; K.res = 0.0; K.cd["e"] = 0.0
	# LMB: quick slashes, double at the tip; hold for a Searing Wave
	P.teleport(home); fresh(T); T.teleport(home + Vector3(1.3, 0, 0)); aim_at(P, T.pos); P.fire_cd = 0.0
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	step(m, 0.3)
	var near := dmg(T)
	fresh(T); T.teleport(home + Vector3(2.95, 0, 0)); aim_at(P, T.pos); P.fire_cd = 0.0
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	step(m, 0.3)
	ok("juggernaut LMB tap: a slash, double at the tip", near >= 7.0 and dmg(T) >= near * 1.8 and K.waves == 0, "near %.0f tip %.0f" % [near, dmg(T)])
	fresh(T); T.teleport(home + Vector3(7.0, 0, 0)); aim_at(P, T.pos); P.fire_cd = 0.0; K.res = 0.0
	step(m, 0.5, func(): P.inp["fire"] = true)
	var midk := K.wave_k()
	step(m, 0.6, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 0.6)
	ok("juggernaut LMB hold: Searing Wave (ranged, fills Rage fast)", K.waves == 1 and midk > 0.2 and dmg(T) >= 20.0 and T.slow_t > 0.0 and K.res > 45.0, "mid %.2f took %.0f rage %.0f" % [midk, dmg(T), K.res])
	K.res = 0.0
	# RMB tap: the Finishing Slam winds up (aim it), then hits; +50% under 35%; its sweet spot is the payoff
	P.teleport(home); fresh(T); T.teleport(home + Vector3(2.6, 0, 0)); aim_at(P, T.pos); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	tap(m, P)
	var early := dmg(T)
	var winding := not K.slam_w.is_empty()
	step(m, 0.6)
	ok("juggernaut RMB tap: Finishing Slam winds up, then lands", winding and early <= 0.0 and dmg(T) >= 24.0 and K.last_variant == "tap", "took %.0f" % dmg(T))
	ok("juggernaut RMB: the sweet spot is the payoff (rank 1: no crash yet)", K.sweet_spots == 1 and K.crashes == 0, "spots %d crashes %d" % [K.sweet_spots, K.crashes])
	P.teleport(home); fresh(T); T.teleport(home + Vector3(1.2, 0, 0)); aim_at(P, T.pos); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	T.hp = T.max_hp * 0.3
	var hp0 := T.hp
	tap(m, P)
	step(m, 0.6)
	ok("juggernaut RMB tap: +50% under 35%, no sweet spot up close", hp0 - T.hp >= 36.0 and K.sweet_spots == 1, "dealt %.0f spots %d" % [hp0 - T.hp, K.sweet_spots])
	ok("juggernaut RMB: short cooldown (3s)", float(K.cd["rmb"]) <= 3.0 and float(K.cd["rmb"]) > 1.5, "%.2f" % float(K.cd["rmb"]))
	# hold: the charged Lunge into the first foe; a miss doubles the cooldown
	P.teleport(home); fresh(T); T.teleport(home + Vector3(5.0, 0, 0)); aim_at(P, T.pos); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	hold(m, P, 0.95)
	step(m, 0.5)
	ok("juggernaut RMB hold: charged Lunge hits", K.last_variant == "hold" and dmg(T) >= 18.0 and P.flat_dist(home) > 2.0, "took %.0f moved %.1f" % [dmg(T), P.flat_dist(home)])
	step(m, 3.2)
	P.teleport(home); fresh(T); T.teleport(home + Vector3(0, 0, 6.0)); aim_at(P, home + Vector3(6.0, 0, 0)); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	hold(m, P, 0.95)
	step(m, 0.5)
	ok("juggernaut RMB hold: a miss doubles the cooldown", float(K.cd["rmb"]) > 4.0, "cd %.1f" % float(K.cd["rmb"]))
	# air: the downward slam slows, the centre takes more and is stunned
	K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	P.teleport(T.pos + Vector3(-0.6, 3.0, 0)); P.grounded = false; fresh(T)
	P.ak.press_rmb()
	step(m, 0.5)
	ok("juggernaut RMB air: Meteor Drop slows, centre stunned", K.last_variant == "air" and dmg(T) >= 24.0 and T.slow_t > 0.0 and T.stun_t > 0.0, "took %.0f slow %.2f stun %.2f" % [dmg(T), T.slow_t, T.stun_t])
	# Rampage (Flame Step): a dash attack, aimed like any dash (Settings); the tip hits double; rank 3 adds a charge
	step(m, 1.0)
	P.teleport(home); fresh(T); T.teleport(home + Vector3(4.3, 0, 0)); aim_at(P, T.pos); P.dashes = 2.0
	P.inp["move"] = Vector2(1, 0)        # (Rampage follows the dash setting: WASD by default, here toward the target)
	P.do_dash()
	step(m, 0.5)
	P.inp["move"] = Vector2.ZERO
	ok("juggernaut dash: Rampage the way you face, tip hits", K.tips >= 1 and dmg(T) >= 14.0 and P.dashes < 1.5, "tips %d took %.0f dashes %.2f" % [K.tips, dmg(T), P.dashes])
	P.slot_lv["dash"] = 3
	ok("juggernaut dash rank 3: a third charge", P.max_dashes() >= 3.0, "%.0f" % P.max_dashes())
	P.slot_lv["dash"] = 1
	# E: the Warchain hooks a foe (blight); its cooldown waits for the pull; a Smash in the pull spins
	P.teleport(home); fresh(T); T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos); K.cd["e"] = 0.0
	P.ak.use_e()
	step(m, 0.3)
	ok("juggernaut E: Warchain hooks + blights, cooldown waits", not K.chain.is_empty() and K.chain.get("target") == T and T.blight_t > 0.0 and dmg(T) >= 7.0 and float(K.cd["e"]) <= 0.0, "blight %.1f cd %.1f" % [T.blight_t, float(K.cd["e"])])
	P.ak.use_e()
	step(m, 0.08)
	ok("juggernaut E recast: the pull starts the cooldown", K.reels == 1 and float(K.cd["e"]) > 5.0 and K.in_e(), "cd %.1f" % float(K.cd["e"]))
	step(m, 0.12)
	K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.2)
	ok("juggernaut RMB during the pull: Cinder Spin (blight)", K.spins == 1 and K.last_variant == "during_e" and dmg(T) >= 20.0, "spins %d variant %s took %.0f" % [K.spins, K.last_variant, dmg(T)])
	# rooted: no chain; a stun breaks a chain
	step(m, 0.5)
	K.cd["e"] = 0.0; P.root_t = 1.0
	P.ak.use_e()
	ok("juggernaut E: can't throw it rooted", K.chain.is_empty() and not K.chain_flying)
	P.root_t = 0.0
	P.teleport(home); fresh(T); T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
	P.ak.use_e()
	step(m, 0.3)
	P.stun_t = 0.3
	step(m, 0.05)
	ok("juggernaut E: a stun breaks the chain", K.chain.is_empty() and float(K.cd["e"]) > 5.0)
	step(m, 0.4)
	# ... or bites a wall and pulls you to it
	var W = m.world
	for dz in range(-3, 4):
		for dx in range(7, 9):
			W.level[W.idx(int(home.x) + dx, int(home.z) + dz)] = lv + 3
	P.teleport(home); T.teleport(home + Vector3(0, 0, 5.0)); K.cd["e"] = 0.0; aim_at(P, home + Vector3(8.0, 0, 0))
	P.ak.use_e()
	step(m, 0.35)
	var anchored: bool = not K.chain.is_empty() and K.chain.get("target") == null
	P.ak.use_e()
	step(m, 0.45)
	ok("juggernaut E: chain a wall, pull yourself to it", anchored and P.flat_dist(home) > 4.0, "anchored %s moved %.1f" % [anchored, P.flat_dist(home)])
	# Smash rank 3 (the old Doomfall): the sweet spot also crashes (3m) and heals 60% of what it deals; it
	# rests, and a knock on a foe it hit makes it ready again
	P.slot_lv["sec"] = 3
	step(m, 3.0)
	P.teleport(home); fresh(T); T.teleport(home + Vector3(2.6, 0, 0)); aim_at(P, T.pos); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.crash_cd = 0.0
	P.hp = P.max_hp * 0.5
	var php := P.hp
	tap(m, P)
	step(m, 0.8)
	ok("juggernaut Smash rank 3: the sweet spot also crashes, and it rests", K.crashes == 1 and K.sweet_spots == 2 and dmg(T) >= 44.0 and K.crash_cd > 5.0, "crashes %d took %.0f rest %.1f" % [K.crashes, dmg(T), K.crash_cd])
	ok("juggernaut Smash rank 3: the crash heals 60% of its damage", P.hp > php + 12.0, "hp %.0f -> %.0f" % [php, P.hp])
	P.hp = P.max_hp * 0.5
	T.hp = 4.0
	T.hurt(10.0, P, {"src": "shot"})
	step(m, 0.1)
	ok("juggernaut Smash rank 3: a knock on a foe it hit resets the crash", T.downed and K.crash_resets == 1 and K.crash_cd <= 0.0, "rest %.1f resets %d" % [K.crash_cd, K.crash_resets])
	ok("juggernaut passive: a knock heals 20% of their health", K.knock_healed >= 70.0, "healed %.0f" % K.knock_healed)
	await done(m)

# ------------------------------------------------------------------ Bulwark
func _bulwark() -> void:
	var r := setup("bulwark", 5.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	ok("bulwark: Tower Shield & Mace", P.wid == "tower_shield")
	# hold: raise the shield; blocked shots become Guard
	K.res = 0.0
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	var php := P.hp
	m.spawn_shot(T, T.pos + Vector3(-0.6, 0.95, 0), Vector2(-30, 0), 30.0, 0.5, 0.15, Color.RED, {})
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	ok("bulwark RMB hold: shield blocks + Guard, no swing", not K.wall.is_empty() and P.hp >= php and K.res >= 10.0 and not P.can_fire(), "guard %.0f hp %.0f" % [K.res, P.hp])
	P.inp["sec_hold"] = false
	step(m, 0.1)
	ok("bulwark RMB release: lowered", K.wall.is_empty())
	# tap: Bash; at 50 Guard, Shield Slam stuns
	T.teleport(home + Vector3(1.8, 0, 0)); fresh(T); aim_at(P, T.pos); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	var x0 := T.pos.x
	tap(m, P)
	step(m, 0.3)
	ok("bulwark RMB tap: Bash pushes", K.last_variant == "tap" and T.pos.x - x0 > 1.0 and dmg(T) >= 9.0, "pushed %.1f" % (T.pos.x - x0))
	T.teleport(home + Vector3(1.8, 0, 0)); fresh(T); K.res = 60.0; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; step(m, 1.0); fresh(T)
	ok("bulwark resource full: Shield Slam armed", K.full_ready() and K.ready_label() != "")
	tap(m, P)
	var early := T.stun_t
	step(m, 0.5)
	ok("bulwark RMB full: Shield Slam (0.3s tell) stuns", K.last_variant == "full" and early <= 0.0 and T.stun_t > 0.0 and K.res < 15.0, "stun %.2f guard %.0f" % [T.stun_t, K.res])
	# hold to block, let go: the Bash comes out of the block
	T.teleport(home + Vector3(1.8, 0, 0)); fresh(T); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.res = 0.0; step(m, 0.8); fresh(T)
	x0 = T.pos.x
	hold(m, P, 0.5)
	step(m, 0.3)
	ok("bulwark RMB release after block: Bash", K.wall.is_empty() and K.last_variant == "hold" and T.pos.x - x0 > 1.0, "pushed %.1f" % (T.pos.x - x0))
	# Crushed: a Bash into a wall stuns and heals
	var W: World = m.world
	var lv: int = r[5]
	var wk: PackedByteArray = W.kind; var wl: PackedByteArray = W.level
	for dz in range(-3, 4):
		for dx in range(0, 3):
			var i: int = W.idx(int(home.x) + 3 + dx, int(home.z) + dz)
			wk[i] = World.T_GROUND
			wl[i] = lv if dx < 1 else lv + 3
	W.kind = wk; W.level = wl
	T.teleport(home + Vector3(2.2, 0, 0)); fresh(T); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.crushed_at = {}
	P.teleport(home); aim_at(P, T.pos); P.hp = P.max_hp - 40.0
	var c0 := K.crushes; var hp0 := P.hp
	step(m, 0.2)
	tap(m, P)
	step(m, 0.3)
	ok("bulwark payoff: Bash into a wall Crushes (stun + heal)", K.crushes == c0 + 1 and T.stun_t > 0.0 and P.hp > hp0, "crushes %d stun %.2f hp %.0f -> %.0f" % [K.crushes - c0, T.stun_t, hp0, P.hp])
	for dz in range(-3, 4):
		for dx in range(0, 3):
			wl[W.idx(int(home.x) + 3 + dx, int(home.z) + dz)] = lv
	W.level = wl
	# LMB tap: the mace flies through, lies there, comes back on a second tap
	T.teleport(home + Vector3(4.0, 0, 0)); fresh(T); P.teleport(home); aim_at(P, T.pos); P.fire_cd = 0.0
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false; m.step(DT)
	ok("bulwark LMB tap: mace thrown", not K.mace.is_empty())
	step(m, 0.6)
	var thrown := dmg(T)
	ok("bulwark LMB: mace hits and lies", thrown >= 14.0 and String(K.mace.get("st", "")) == "ground", "took %.0f state %s" % [thrown, String(K.mace.get("st", ""))])
	P.fire_cd = 0.0
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	step(m, 0.8)
	ok("bulwark LMB tap again: recalled, hits on the way", K.mace.is_empty() and dmg(T) > thrown, "took %.0f" % dmg(T))
	# LMB hold: a full Crushing Blow
	T.teleport(home + Vector3(2.0, 0, 0)); fresh(T); P.teleport(home); aim_at(P, T.pos); P.fire_cd = 0.0
	step(m, 1.3, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	P.inp["fire"] = false
	step(m, 0.3)
	ok("bulwark LMB hold: full Crushing Blow", dmg(T) >= 30.0 and T.stun_t > 0.0, "took %.0f stun %.2f" % [dmg(T), T.stun_t])
	# dash: Whirl; with the shield up, a Shield Charge
	P.teleport(home); P.dashes = P.max_dashes(); fresh(T); T.teleport(home + Vector3(6, 0, 0)); aim_at(P, T.pos)
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	step(m, 0.3)
	ok("bulwark dash: Whirl", K.st.get("last_dash") == "whirl" and P.flat_dist(home) > 2.5, "moved %.1f" % P.flat_dist(home))
	P.teleport(home); P.dashes = P.max_dashes(); K.lock_t = 0.0; K.shield_hp = K.shield_max()
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.do_dash()
	var inv := P.inv_t
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false; P.inp["move"] = Vector2.ZERO
	step(m, 0.1)
	ok("bulwark dash with the shield up: Shield Charge", K.st.get("last_dash") == "charge" and inv > 0.15 and P.flat_dist(home) > 3.0, "inv %.2f moved %.1f" % [inv, P.flat_dist(home)])
	# E: Mending Ground bursts after 1s and heals
	P.teleport(home); P.hp = P.max_hp - 50.0; hp0 = P.hp
	P.inp["aim"] = home + Vector3(1, 0, 0)
	P.ak.use_e()
	step(m, 0.5)
	var mid := P.hp
	step(m, 0.8)
	ok("bulwark E: Mending Ground heals after its delay", mid <= hp0 + 1.0 and P.hp >= hp0 + 20.0, "hp %.0f -> %.0f -> %.0f" % [hp0, mid, P.hp])
	await done(m)

# ------------------------------------------------------------------ levels and the Bonded R
func _levels_and_bond() -> void:
	var r := setup("thief", 6.0, "cindle")      # (a kit with an R: Vireo and Venator have none)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	# a fresh run: R locked until level 6
	P.lvl = 1; P.xp = 0.0; P.skill_pts = 1
	for s in Hunter.SLOTS: P.slot_lv[s] = 0
	ok("R: locked at level 1", not P.can_level("ult"))
	P.ak.use_r()
	ok("R: can't cast while locked", float(P.ak.cd["r"]) <= 0.0 and P.ak.r_t <= 0.0)
	P.gain_xp(float(Hunter.XP_TO[5]) + 1.0)
	ok("R: level 6 opens it", P.lvl >= 6 and P.can_level("ult"), "lvl %d" % P.lvl)
	P.level_slot("ult")
	ok("R: first unlock fills the bond", P.ult >= 1.0 and int(P.slot_lv["ult"]) == 1)
	P.gain_xp(float(Hunter.XP_TO[8]) - P.xp + 1.0)
	P.skill_pts = maxi(P.skill_pts, 1)
	ok("R: rank 2 at level 9", P.lvl >= 9 and P.can_level("ult"), "lvl %d" % P.lvl)
	P.skill_pts = 0
	# no class ultimate (the Thief and Juggernaut lost theirs): pressing R through the kit does nothing, the Merge owns the key
	P.ult = 1.0; P.merge_cd = 0.0; P.ak.cd["r"] = 0.0
	P.ak.use_r()
	step(m, 0.5)
	ok("R: no class ultimate, the kit's press does nothing", float(P.ak.cd["r"]) <= 0.0 and not P.ak.fusing() and not P.ak.bonded and not KinMerge.active(P))
	await done(m)

# ------------------------------------------------------------------ cross-ability combinations (--kit-combo-check)
## Every interaction between the Thief's and the Juggernaut's abilities, scripted one by one, asserting
## the variant that should fire (docs/ARCHETYPES.md "E + RMB combinations").
func _combos() -> void:
	# ---- Juggernaut
	var r := setup("juggernaut", 6.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	var home: Vector3 = r[4]; var lv: int = r[5]
	var K: JuggernautKit = P.ak
	var hook := func():
		P.teleport(home); fresh(T); T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
		K.cd["e"] = 0.0; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.haul = {}
		P.ak.use_e()
		step(m, 0.3)
	# E, E, then RMB tap in the pull: Cinder Spin
	hook.call()
	P.ak.use_e()
	step(m, 0.06)
	tap(m, P)
	step(m, 0.3)
	ok("combo jug: E > E > RMB tap = Cinder Spin", K.spins == 1 and K.last_variant == "during_e" and T.blight_t > 0.0, "spins %d variant %s" % [K.spins, K.last_variant])
	# E, then RMB held and let go while attached: Chain Lunge along it
	step(m, 1.0)
	hook.call()
	var hp0 := dmg(T)
	hold(m, P, 0.95)
	step(m, 0.4)
	ok("combo jug: E > hold RMB = Chain Lunge", K.chain_lunges == 1 and K.chain.is_empty() and dmg(T) - hp0 >= 18.0 and T.stun_t > 0.0 and P.flat_dist(T) < 3.4, "lunges %d dist %.1f took %.0f" % [K.chain_lunges, P.flat_dist(T), dmg(T) - hp0])
	# E, hold RMB, then E while still holding: pulled in, Haul Slam on arrival
	step(m, 1.0)
	hook.call()
	hp0 = dmg(T)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.5, func(): P.inp["sec_hold"] = true)
	P.ak.use_e()
	P.inp["sec_hold"] = false
	step(m, 0.45)
	ok("combo jug: E > hold RMB > E = Haul Slam on arrival", K.haul_slams == 1 and dmg(T) - hp0 >= 16.0 and T.stun_t > 0.0 and K.chain_lunges == 1, "slams %d took %.0f stun %.2f" % [K.haul_slams, dmg(T) - hp0, T.stun_t])
	# E, E, then RMB held through the pull: Haul Slam where you land
	step(m, 1.0)
	hook.call()
	P.ak.use_e()
	step(m, 0.04)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	step(m, 0.3)
	ok("combo jug: E > E > hold RMB = Haul Slam", K.haul_slams == 2, "slams %d" % K.haul_slams)
	# E attached, RMB tapped (not pulling): a normal Finishing Slam
	step(m, 1.0)
	hook.call()
	tap(m, P)
	ok("combo jug: E > RMB tap = Finishing Slam", not K.slam_w.is_empty() and K.last_variant == "tap")
	step(m, 0.8)
	# Finishing Slam's sweet spot below rank 3 is the payoff only; at rank 3 it also crashes
	P.teleport(home); fresh(T); T.teleport(home + Vector3(2.6, 0, 0)); aim_at(P, T.pos); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.crash_cd = 0.0
	var cs := K.crashes
	tap(m, P)
	step(m, 0.7)
	ok("combo jug: RMB sweet spot (rank 1) = payoff, no crash", K.sweet_spots >= 1 and K.crashes == cs)
	P.slot_lv["sec"] = 3
	step(m, 3.0)
	P.teleport(home); fresh(T); T.teleport(home + Vector3(2.6, 0, 0)); aim_at(P, T.pos); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.crash_cd = 0.0
	P.hp = P.max_hp * 0.5
	var php := P.hp
	tap(m, P)
	step(m, 0.7)
	ok("combo jug: RMB sweet spot (rank 3) = crash + heal", K.crashes == cs + 1 and P.hp > php + 12.0 and K.crash_cd > 5.0, "hp %.0f -> %.0f rest %.1f" % [php, P.hp, K.crash_cd])
	# the crash, then a knock within 2s: the crash is ready again, a heal, a dash charge back
	P.dashes = 0.0
	var rs := K.crash_resets
	T.hp = 4.0
	T.hurt(10.0, P, {"src": "shot"})
	step(m, 0.05)
	ok("combo jug: crash > knock = crash reset + heal + a dash", K.crash_resets == rs + 1 and K.crash_cd <= 0.0 and K.knock_healed > 0.0 and P.dashes >= 0.99, "dashes %.2f" % P.dashes)
	await done(m)
	r = setup("juggernaut", 6.0)
	m = r[0]; P = r[1]; T = r[2]; home = r[4]; lv = r[5]
	K = P.ak
	# a Lunge that strikes nothing doubles the Smash cooldown
	aim_at(P, home + Vector3(0, 0, 6.0)); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	hold(m, P, 0.95)
	step(m, 0.5)
	ok("combo jug: RMB hold miss = cooldown x2", float(K.cd["rmb"]) > 4.0, "%.1f" % float(K.cd["rmb"]))
	# a dash or a lunge winds down: no glider straight out of it
	P.dashes = 2.0; aim_at(P, home + Vector3(6.0, 0, 0))
	P.do_dash()
	step(m, 0.05)
	ok("combo jug: Rampage winds down (no instant glide)", P.glide_cd > 0.2, "%.2f" % P.glide_cd)
	# rooted: no chain; a stun breaks it; Enraged speeds every cooldown
	step(m, 1.0)
	K.cd["e"] = 0.0; P.root_t = 1.0
	P.ak.use_e()
	ok("combo jug: rooted = no Warchain", K.chain.is_empty() and not K.chain_flying)
	P.root_t = 0.0
	KitStatus.apply(P, "gnd", 1.0)
	P.ak.use_e()
	ok("combo jug: Grounded = no Warchain", K.chain.is_empty() and not K.chain_flying)
	step(m, 1.1)
	P.teleport(home); fresh(T); T.teleport(home + Vector3(6.0, 0, 0)); aim_at(P, T.pos)
	P.ak.use_e()
	step(m, 0.3)
	P.stun_t = 0.3
	step(m, 0.05)
	ok("combo jug: stun breaks the Warchain", K.chain.is_empty() and float(K.cd["e"]) > 5.0)
	step(m, 0.4)
	K.gain_rage(100.0); K.cd["rmb"] = 3.0
	step(m, 1.0)
	ok("combo jug: Enraged hastes the Smash", float(K.cd["rmb"]) < 1.85, "%.2f" % float(K.cd["rmb"]))
	await done(m)
	# ---- Thief
	r = setup("thief", 4.0, "", true)
	m = r[0]; P = r[1]; T = r[2]
	var T2: Hunter = r[3]
	home = r[4]
	var TK: ThiefKit = P.ak
	# Vault > hit: Primed, Vault reset, speed ends
	P.dashes = P.max_dashes()
	P.do_dash()
	step(m, 0.2)
	TK.on_deal(T, 5.0, {"src": "shot"})
	ok("combo thief: Vault > hit = Primed + Vault reset", TK.primed_hits == 1 and P.dashes >= P.max_dashes() - 0.01 and TK.haste_t <= 0.0)
	# Knife into a foe at rank 3 > Vault reset
	P.slot_lv["dash"] = 3; P.slot_lv["kin"] = 3
	P.teleport(home); fresh(T); T2.teleport(home + Vector3(0, 0, 9.0)); aim_at(P, T.pos); P.dashes = 0.0; TK.cd["e"] = 0.0
	P.ak.use_e()
	step(m, 0.35)
	ok("combo thief: Knife in a foe (rank 3) = Vault reset + refund", P.dashes >= 0.99 and float(TK.cd["e"]) < 10.0, "dashes %.2f e cd %.1f" % [P.dashes, float(TK.cd["e"])])
	P.ak.use_e()
	step(m, 0.05)
	ok("combo thief: Knife > E = step to them", P.flat_dist(T) < 1.8)
	# Bola into two at rank 3: their Marks pool
	P.slot_lv["sec"] = 3
	P.teleport(home); fresh(T); fresh(T2); T.teleport(home + Vector3(4.0, 0, 0)); T2.teleport(home + Vector3(7.0, 0, 0)); aim_at(P, T.pos)
	TK.add_mark(T2, 3, true)
	TK.ch_rmb = 1.0; TK.cd["rmb"] = 0.0
	tap(m, P)
	step(m, 0.5)
	ok("combo thief: Bola on two (rank 3) = pooled Marks", TK.bola_pairs >= 1 and TK.marks_on(T) >= 4 and TK.marks_on(T) == TK.marks_on(T2), "T %d T2 %d" % [TK.marks_on(T), TK.marks_on(T2)])
	ok("combo thief: Bola > Grounded = no dash", KitStatus.grounded(T) and (func(): var d0 := T.dashes; T.stun_t = 0.0; T.do_dash(); return T.dashes == d0).call())
	step(m, 2.0)
	# a Primed hit lands 2 Marks: on 3 Marks that is the fifth, so the Primed hit itself sets Jackpot off
	P.teleport(home); fresh(T); fresh(T2); T.teleport(home + Vector3(3.5, 0, 0)); T2.teleport(home + Vector3(7.0, 0, 0.5)); TK.jp_cd = 0.0; TK.quick = 0
	TK.add_mark(T, 3, true)
	var jbp := TK.jackpots
	TK.primed_t = 3.0
	TK.on_deal(T, 5.0, {"src": "shot"})
	step(m, 0.7)
	ok("combo thief: Primed hit on 3 Marks = the fifth Mark = Jackpot", TK.jackpots == jbp + 1 and TK.marks_on(T) == 5 and TK.jackpot_hits >= 4)
	step(m, 1.0)
	# Jackpot (the fifth Mark): the burst refreshes Marks, the free Vault Primes, the Primed hit resets Vault
	P.teleport(home); fresh(T); fresh(T2); T.teleport(home + Vector3(3.5, 0, 0)); T2.teleport(home + Vector3(7.0, 0, 0.5)); TK.jp_cd = 0.0; TK.quick = 0
	TK.add_mark(T, 4, true)
	T.get_meta("marks")[P.nid][1] = 0.75
	var jb := TK.jackpots
	TK.add_mark(T, 1, true)
	step(m, 0.7)
	ok("combo thief: 5th Mark = Jackpot burst, Marks refreshed", TK.jackpots == jb + 1 and TK.jackpot_hits >= 4 and float(T.get_meta("marks")[P.nid][1]) > 3.0)
	var ds := P.dashes
	TK.primed_t = 0.0
	P.do_dash()
	step(m, 0.15)
	ok("combo thief: Jackpot > Vault = free Vault that Primes", TK.quick == 0 and P.dashes >= ds - 0.01 and TK.primed_t > 0.0)
	var ph := TK.primed_hits
	TK.on_deal(T, 5.0, {"src": "shot"})
	ok("combo thief: Jackpot > free Vault > hit = Vault reset", TK.primed_hits == ph + 1 and TK.primed_t <= 0.0 and P.dashes >= P.max_dashes() - 0.01)
	await done(m)
	await _merge_holds()

## A Boki merge starting mid-hold: nothing the hunter was holding or winding up fires, and none of it is left
## behind for when the merge ends (KinMerge.cast clears the generic weapon holds, the kits clear their own).
func _merge_holds() -> void:
	# ---- Juggernaut: the Searing Wave charge (LMB held)
	var r := setup("juggernaut", 6.0, "cindle")
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	var K: JuggernautKit = P.ak
	P.ult = 1.0; P.merge_cd = 0.0
	step(m, 0.7, func(): P.inp["fire"] = true)
	ok("merge hold jug: the Searing Wave is charging", K.lmb_t > 0.3 and P.mel_hold > 0.0, "lmb_t %.2f" % K.lmb_t)
	var w0 := K.waves
	ok("merge hold jug: the merge starts", KinMerge.cast(P) and KinMerge.active(P))
	step(m, 0.6, func(): P.inp["fire"] = false)
	ok("merge hold jug: the charged wave does not fire", K.waves == w0 and dmg(T) <= 0.0, "waves %d took %.0f" % [K.waves - w0, dmg(T)])
	ok("merge hold jug: no charge left behind", K.lmb_t < 0.0 and K.lmb_buf <= 0.0 and P.mel_hold <= 0.0, "lmb_t %.2f" % K.lmb_t)
	await done(m)
	# the Finishing Slam winding up
	# (a control first: what the merge's own transformation does to a foe this close, with no slam)
	r = setup("juggernaut", 2.6, "cindle")
	m = r[0]; P = r[1]; T = r[2]
	P.ult = 1.0; P.merge_cd = 0.0
	KinMerge.cast(P)
	step(m, 1.0)
	var ctl := dmg(T)
	await done(m)
	r = setup("juggernaut", 2.6, "cindle")
	m = r[0]; P = r[1]; T = r[2]
	K = P.ak
	P.ult = 1.0; P.merge_cd = 0.0
	aim_at(P, T.pos)
	tap(m, P)
	ok("merge hold jug: the Finishing Slam is winding up", not K.slam_w.is_empty())
	KinMerge.cast(P)
	step(m, 1.0)
	ok("merge hold jug: the wound-up slam does not land", K.slam_w.is_empty() and K.sweet_spots == 0 and dmg(T) <= ctl + 0.5, "took %.0f (merge alone %.0f)" % [dmg(T), ctl])
	await done(m)
	# the Smash held (the Lunge charge), and a Haul Slam armed for the end of a pull
	r = setup("juggernaut", 6.0, "cindle")
	m = r[0]; P = r[1]; T = r[2]
	K = P.ak
	P.ult = 1.0; P.merge_cd = 0.0
	aim_at(P, T.pos)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.6, func(): P.inp["sec_hold"] = true)
	ok("merge hold jug: the Lunge is charging", K.rmb_down and K.rmb_t > 0.3)
	K.haul = {"k": 1.0}
	var chg := K.ch_rmb
	KinMerge.cast(P)
	P.inp["sec_hold"] = false
	step(m, 0.6)
	ok("merge hold jug: the charged Lunge does not go and no Smash charge is spent", K.lunge.is_empty() and not K.rmb_down and K.ch_rmb >= chg, "charges %.1f of %.1f" % [K.ch_rmb, chg])
	ok("merge hold jug: an armed Haul Slam is dropped", K.haul.is_empty() and K.haul_slams == 0)
	await done(m)
	# ---- Thief: no hold of its own; the Jackpot burst already in the air stops when a merge starts
	r = setup("thief", 4.0, "cindle")
	m = r[0]; P = r[1]; T = r[2]
	var TK: ThiefKit = P.ak
	P.ult = 1.0; P.merge_cd = 0.0
	TK.jp_cd = 0.0
	TK.add_mark(T, 5, true)
	step(m, 0.08)
	KinMerge.cast(P)
	var jh := TK.jackpot_hits
	step(m, 0.8)
	ok("merge hold thief: Jackpot's burst in the air does not finish", TK.jackpots == 1 and TK.jackpot_hits == jh and KinMerge.active(P), "knives after %d" % (TK.jackpot_hits - jh))
	await done(m)

# ------------------------------------------------------------------ the kin's own ability on C
func _kin_ability() -> void:
	var r := setup("thief", 6.0, "puddlet")
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	var k: Kin = P.kin
	ok("C: kin starts on the shoulder", k.state == "shoulder")
	aim_at(P, P.pos + Vector3(3.0, 0, 0))
	P.inp["kin_ab"] = true
	m.step(DT)
	var spent := not k.runner.is_ready("k1")
	ok("C: casts its own active, through you (the Boki stays on the shoulder)", k.state == "shoulder" and spent, "state %s" % k.state)
	step(m, 0.5)
	ok("C: doesn't touch the archetype E", float(P.ak.cd["e"]) <= 0.0)
	# G: send / recall (the old throw) still works
	k.throw_cd = 0.0; k.settle = 1.0
	KinCommand.tap(P)
	step(m, 0.6)
	ok("G: sends the kin out", k.state in ["active", "flying"], k.state)
	await done(m)

# ------------------------------------------------------------------ infusion
func _infusion() -> void:
	var v := Arch.infusion(KinLib.kin("cindle"))
	var f := Arch.fill(Arch.def("thief")["rmb"]["sockets"], v, "rmb", "projectile")
	var poison: bool = (f["effects"] as Array).any(func(e): return String(e["type"]) == "damage" and float(e.get("over", 0.0)) > 0.0)
	ok("infusion: Vespyx poisons the Thief's Bola", poison, "; ".join(f["notes"]))
	var fm := Arch.fill(Arch.def("mage")["rmb"]["sockets"], Arch.infusion(KinLib.kin("pebbit")), "rmb", "projectile")
	ok("infusion: Gravadillo adds a control to Vireo's Coilshot", (fm["effects"] as Array).any(func(e): return KinParts.category(String(e["type"])) == "control"), "; ".join(fm["notes"]))
	var fj := Arch.fill(Arch.def("juggernaut")["rmb"]["sockets"], Arch.infusion(KinLib.kin("pebbit")), "rmb", "cone")
	ok("infusion: Gravadillo lifts on a cone", (fj["effects"] as Array).any(func(e): return String(e["type"]) == "lift"), "; ".join(fj["notes"]))
	var fz := Arch.fill(Arch.def("gunslinger")["rmb"]["sockets"], Arch.infusion(KinLib.kin("zapple")), "rmb", "projectile")
	ok("infusion: Echolop adds a chain mod", (fz["mods"] as Array).any(func(e): return String(e["type"]) in ["chain", "repeat"]), "; ".join(fz["notes"]))
	var caps_ok := true
	for kid in KinLib.kin_ids():
		var inf := Arch.infusion(KinLib.kin(kid))
		for a in Arch.ids():
			for slot in ["rmb", "e", "r"]:
				var sd: Dictionary = Arch.def(a).get(slot, {})
				if sd.is_empty(): continue          # (the Archer and Bulwark have no class R)
				var ff := Arch.fill(sd.get("sockets", {}), inf, slot, String(sd.get("delivery", "burst")))
				for e in ff["effects"]:
					var cap: Dictionary = Arch.CAPS[String(sd["sockets"].get("ctrl_cap", "soft"))]
					if String(e["type"]) == "stun" and float(e["duration"]) > float(cap["stun"]) + 0.001: caps_ok = false
					if String(e["type"]) == "root" and float(e["duration"]) > float(cap["root"]) + 0.001: caps_ok = false
	ok("infusion: every kin x archetype within caps", caps_ok, "%d kin" % KinLib.kin_ids().size())
	# at run time: the Vespyx knife poisons
	var r := setup("thief", 6.0, "cindle")
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	tap(m, P)
	step(m, 0.3)
	ok("infusion runtime: Bola + poison", T.burn_t > 0.0, "burn %.1f" % T.burn_t)
	await done(m)
	r = setup("mage", 5.0, "puddlet")
	m = r[0]; P = r[1]; T = r[2]
	hold(m, P, 0.5)
	step(m, 0.6)
	ok("infusion runtime: a Boki's type rides Vireo's Coilshot", dmg(T) > 0.0 and (T.slow_t > 0.0 or T.burn_t > 0.0 or T.stun_t > 0.0 or T.root_t > 0.0), "slow %.2f burn %.2f stun %.2f" % [T.slow_t, T.burn_t, T.stun_t])
	await done(m)

# ------------------------------------------------------------------ feel
func _feel() -> void:
	ok("feel: hard CC floor 0.40s at range", is_equal_approx(Feel.floor_for("hard_cc", "instant"), 0.4))
	ok("feel: soft CC floor 0.30s", is_equal_approx(Feel.floor_for("soft_cc", "instant"), 0.3))
	ok("feel: trap click 0.15s", is_equal_approx(Feel.floor_for("hard_cc", "trap"), 0.15))
	var rep := GrammarReport.new()
	var st := StageSpec.parse({"delivery": {"type": "burst", "origin": "aim", "radius": 2.5}, "effects": [{"type": "stun", "duration": 0.8}]}, "", rep)
	ok("feel: an instant hard-CC burst gets +0.40s", is_equal_approx(Feel.missing_windup(st), 0.4), "%.2f" % Feel.missing_windup(st))
	var st2 := StageSpec.parse({"delivery": {"type": "burst", "origin": "aim", "radius": 2.5}, "effects": [{"type": "stun", "duration": 0.8}], "modifiers": [{"type": "delay", "time": 0.6}]}, "", GrammarReport.new())
	ok("feel: an author delay covers it", Feel.missing_windup(st2) <= 0.0)
	var st3 := StageSpec.parse({"delivery": {"type": "leap", "range": 7, "time": 0.5}}, "", GrammarReport.new())
	ok("feel: leap flight counts", Feel.missing_windup(st3) <= 0.0)
	# archetype tells meet the floors
	ok("feel: Skycall and Longneedle show a lane or ring before they land", float(Arch.def("mage")["e"]["delay"]) >= 0.5 and float(Arch.def("gunslinger")["e"]["charge"]) >= 0.5)
	ok("feel: Arrow Rain tell >= soft floor", float(Arch.def("archer")["e"]["tell"]) >= Feel.floor_for("soft_cc", "instant"))
	ok("feel: the Bola and Warchain are projectiles (dodgeable)", String(Arch.def("thief")["rmb"]["delivery"]) == "projectile" and float(Arch.def("thief")["rmb"]["bola"]["speed"]) <= 34.0 and String(Arch.def("juggernaut")["e"]["delivery"]) == "projectile")
	ok("feel: Wirerun shows its lane while it grows", float(Arch.def("mage")["dash"]["hold"]) >= 0.3)
	ok("feel: the Smash's crash comes after a 0.5s wind-up", float(Arch.def("juggernaut")["rmb"]["windup"]) >= 0.3)
	ok("feel: every R has a fuse of 0.35-0.8s", Arch.ids().filter(func(a): return Arch.def(a).has("r")).all(func(a): return float(Arch.def(a)["r"].get("fuse", 0.0)) >= 0.35 and float(Arch.def(a)["r"].get("fuse", 0.0)) <= 0.8))
	ok("R cooldowns are big moments (90-120s)", Arch.ids().filter(func(a): return Arch.def(a).has("r")).all(func(a): return float(Arch.def(a)["r"]["cooldown"]) >= 90.0 and float(Arch.def(a)["r"]["cooldown"]) <= 120.0))
	# hitstop tiers
	var dummy := Hunter.new(); dummy.max_hp = 145.0
	ok("feel: chip hit T1", Feel.tier(dummy, 4.0, {"src": "shot"}) == 1)
	ok("feel: solid hit T2", Feel.tier(dummy, 14.0, {"src": "shot"}) == 2)
	ok("feel: CC landing T3", Feel.tier(dummy, 2.0, {"stun": 0.4}) == 3)
	ok("feel: wall slam / payoff T4", Feel.tier(dummy, 10.0, {"src": "wall"}) == 4 and Feel.tier(dummy, 5.0, {"payoff": true}) == 4)
	ok("feel: bonded start T5", Feel.tier(dummy, 0.0, {"bonded": true}) == 5)
	ok("feel: ticks never freeze", Feel.tier(dummy, 30.0, {"src": "burn"}) == 0)
	ok("feel: category colours", Feel.cat_color("control") == Color("c46bff") and Feel.cat_color("damage") == Color("ff7a3d") and Feel.cat_color("utility") == Color("5fd8ff"))
	ok("feel: severity from parts", Feel.severity([{"type": "root", "duration": 1.2}]) == "hard_cc" and Feel.severity([{"type": "slow", "duration": 1.0}]) == "soft_cc" and Feel.severity([{"type": "damage", "amount": 30}]) == "heavy_dmg")
	dummy.free()
