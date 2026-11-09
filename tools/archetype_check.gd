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
	for dz in range(-10, 11):      # (targets are parked 9m to either side)
		for dx in range(-8, int(dist) + 12):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			W.stairs.erase(i); W.walls.erase(i); W.props.erase(i); W.bush.erase(i)
	for b in m.breaks: b["dead"] = true      # crates and kegs off the strip too: shots here are about the kit
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
			var hc = load("res://tools/hero_combo_check.gd").new()      # Sparkle's and Vex's cross-ability interactions
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
	ok("keys: X merge, R hunter ultimate, no reload",
		_has_key("ultimate", KEY_X) and _has_key("hunter_ult", KEY_R) and not InputMap.has_action("reload"))
	ok("keys: G send/recall, MMB pings", _has_key("throw", KEY_G) and _has_mouse("ping", MOUSE_BUTTON_MIDDLE))
	ok("keys: Q glove, Shift dash, RMB", _has_key("gear1", KEY_Q) and _has_key("dash", KEY_SHIFT) and _has_mouse("secondary", MOUSE_BUTTON_RIGHT))
	ok("keys: binding version bumped", Settings.KEYS_V >= 3, "keys_v %d" % Settings.KEYS_V)
	ok("keys: rebindable list names them", Settings.ACTIONS.any(func(a): return a[0] == "hunter_ult"))

func _data() -> void:
	# rank previews: always the NEXT rank first (rank 2 at rank 1), then rank 3's special; every
	# ability of every archetype has a concrete rank 2
	var rk_ok := true
	for a in Arch.ids():
		for sl in ["sec", "dash", "kin", "ult"]:
			if sl == "ult" and not Arch.def(a).has("r"): continue      # Sparkle and Vex have no R (Boki Merge owns it)
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
	ok("weapons: Sable bolts / Lace bow / Sparkle coil / Mossy hammer and aegis", Arch.signature("thief") == "arc_bolts" and Arch.signature("archer") == "longbow" and Arch.signature("mage") == "coilcaster" and Arch.signature("bulwark") == "tower_shield")
	ok("weapons: another archetype's weapon is not yours", not Arch.weapon_ok("bulwark", "greatsword") and not Arch.weapon_ok("thief", "smg"))
	ok("weapons: asking for another weapon gives the signature", Arch.weapon_for("gunslinger", "medium", "longsword") == "quill_rifle")
	# no ammo but the source's one gun (Ghost's 30-round rifle): no magazine, no reload timer, no count on the HUD
	var ammo_bad: Array = []
	for a2 in ids:
		var ws := Data.weapon_stats(Arch.signature(a2))
		var wants: bool = a2 == "gunslinger"
		if bool(ws.get("ammo", true)) != wants or ws.has("reload"):
			ammo_bad.append("%s:%s" % [a2, Arch.signature(a2)])
	ok("weapons: no hero weapon has ammo or a reload but Vex's drum (no reload anywhere)", ammo_bad.is_empty(), str(ammo_bad))
	var sup_ok := true
	for a in ["tender", "rimewright"]:
		var sd2 := Arch.def(a)
		for k in ["card", "passive", "dash", "rmb", "e", "rank2", "rank3", "rank_next", "tells"]:
			if not sd2.has(k): sup_ok = false
		if sd2.has("r") or (sd2["card"] as Dictionary).has("r"): sup_ok = false          # no R for the support pair
		if (sd2["rmb"] as Dictionary).get("variants", {}).is_empty() or String(sd2["e"].get("desc", "")).length() < 40: sup_ok = false
	ok("data: support heroes complete, no R", sup_ok)
	var dj_ults := _has_ult("thief") and _has_ult("juggernaut")
	ok("data: Sable and Kael have their own ultimate (X, level 6); no Jackpot fold, no crash fold",
			dj_ults and not Arch.def("thief").has("jackpot") and not Arch.def("juggernaut")["rmb"].has("crash"))
	ok("weapons: fix keeps the class", Arch.fix("thief", "heavy") == "juggernaut" and Arch.fix("bulwark", "heavy") == "bulwark")

# ------------------------------------------------------------------ Sable (thief): tools/dancer_jug_check.gd
func _thief() -> void:
	await _dj().thief(self)

## An ultimate's data: no generic fuse, a 15-40s cooldown, opening at level 6.
func _ult_shaped(rd: Dictionary) -> bool:
	var cd := float(rd["cooldown"])
	return float(rd.get("fuse", 0.0)) <= 0.0 and cd >= 15.0 and cd <= 80.0 and int(rd.get("unlock", 6)) == 6

## The hero has its own ultimate on X: "r" data opening at level 6, and a card line for it.
func _has_ult(arch: String) -> bool:
	var d := Arch.def(arch)
	return int(d.get("x", {}).get("unlock", 0)) == 6 and d["card"].has("x") and not d["card"].has("r")

func _dj() -> RefCounted:
	return load("res://tools/dancer_jug_check.gd").new()

# ------------------------------------------------------------------ Archer
func _archer() -> void:
	var r := setup("archer", 7.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	var home: Vector3 = r[4]; var lv: int = r[5]
	var K: ArcherKit = P.ak
	# no Focus meter (KIT_PARITY 5, cut by the owner): standing still builds nothing
	P.inp["move"] = Vector2.ZERO
	step(m, 1.6)
	ok("archer passive: no Focus meter (Hawk Sense only)",
		not K.has_meter() and K.res == 0.0 and K.tell == "", "res %.0f tell %s" % [K.res, K.tell])
	# Hawk Sense stays: a rival under half health within 22m is seen by her team (numbers: --archer-combo-check)
	fresh(T); T.hp = T.max_hp * 0.4
	step(m, 0.5)
	ok("archer Hawk Sense: a hurt rival is sensed", ArcherKit.sensed_by(m, P.team, T))
	fresh(T)
	P.equip("sniper")
	step(m, 0.35)
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	ok("archer: a sniper still winds up (no Focus to skip it)",
		P.warm_t > 0.0 and P.shot_range_k == 1.0, "warm %.2f range_k %.1f" % [P.warm_t, P.shot_range_k])
	P.equip("longbow")
	step(m, 0.3)
	# the Longbow draws: a full draw hits for 60
	fresh(T)
	step(m, 0.05, func(): P.inp["fire"] = true)
	step(m, 1.2, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 0.5)
	ok("archer weapon: Longbow full draw", dmg(T) >= 50.0, "took %.0f" % dmg(T))
	# the Heavy Shot is hold only: a tap looses nothing and spends no charge
	fresh(T); K.ch_rmb = 1.0
	tap(m, P)
	step(m, 0.3)
	ok("archer RMB tap: nothing fires and the charge stays", dmg(T) <= 0.0 and T.root_t <= 0.0 and K.ch_rmb >= 1.0, "took %.0f charges %.1f" % [dmg(T), K.ch_rmb])
	# Pinning Shot: pushed into a wall within 3m, pinned
	fresh(T); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
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
	hold(m, P, 1.15)
	if "--ak-debug" in OS.get_cmdline_user_args(): print("PIN after hold: T at %s P at %s ground ahead %s %s %s lvl %s" % [str(T.pos), str(P.pos), W.ground_at(T.pos.x + 1.0, T.pos.z), W.ground_at(T.pos.x + 1.6, T.pos.z), W.ground_at(T.pos.x + 2.2, T.pos.z), W.level[W.idx(int(T.pos.x) + 2, int(T.pos.z))]])
	step(m, 0.5)
	if "--ak-debug" in OS.get_cmdline_user_args(): print("PIN T at %s vx %.2f stun %.2f immune %.2f dr %s" % [str(T.pos), T.vel.x, T.stun_t, T.cc_immune_t, str(T.dr)])
	ok("archer RMB hold: Heavy Shot pins to the wall", K.last_variant == "hold" and dmg(T) >= 14.0 and T.stun_t > 0.0, "took %.0f stun %.2f" % [dmg(T), T.stun_t])
	# a full charge: the hold reached full (the shared charge feedback ticked)
	ok("archer RMB hold: charge reached full", K.charge_fulls >= 1 and K.charge_last >= 0.99, "fulls %d last %.2f" % [K.charge_fulls, K.charge_last])
	# a tapped arrow into a pinned foe is one ordinary arrow (it was 30+ with the Deadeye)
	var dd0 := dmg(T)
	T.root_t = maxf(T.root_t, 1.0)
	P.fire_cd = 0.0; P.ammo = maxi(P.ammo, 1); P.reload_t = 0.0
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	step(m, 0.5)
	ok("archer: an arrow into a pinned foe is a plain tap (no Deadeye)",
		dmg(T) - dd0 > 0.0 and dmg(T) - dd0 < 30.0 and K.ready_label() == "", "dealt %.0f" % (dmg(T) - dd0))
	# Spirit Walk: a dodge roll, then walking through a rock column (terrain still blocks)
	P.teleport(home); P.vel = Vector3.ZERO; P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	ok("archer dash: Spirit Walk", K.st.get("last_dash") == "spirit" and K.spirit.active() and P.spirit_t > 2.0, "dash %s ghost %.2f" % [str(K.st.get("last_dash")), P.spirit_t])
	step(m, 0.3)
	ok("archer dash: the roll moves you", P.pos.z > home.z + 1.5, "z %.1f" % (P.pos.z - home.z))
	step(m, 3.0)
	P.inp["move"] = Vector2.ZERO
	ok("archer dash: Spirit Walk ends after 2.8s", not K.spirit.active() and P.spirit_t <= 0.0)
	# in the air the press still starts a draw: the Heavy Shot has no air variant
	P.teleport(home + Vector3(0, 3.0, 0)); P.grounded = false; P.vel = Vector3(0, -2, 0); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	P.ak.press_rmb()
	ok("archer RMB air: the press starts a draw, no Plunge", K.rmb_down and not bool(K.rmb_ctx["air"]) and P.vel.y < 5.0, "vy %.1f" % P.vel.y)
	K.rmb_down = false
	step(m, 1.2)
	# the bow's perfect window: let go right as Supercharged comes up: no extra damage, the next draw is faster
	P.teleport(home); P.vel = Vector3.ZERO; fresh(T); T.teleport(home + Vector3(-6.5, 0, 0)); aim_at(P, T.pos)    # (clear of the test walls east)
	P.equip("longbow"); step(m, 0.4)
	var pf0 := K.perfects
	step(m, 1.2, func(): P.inp["fire"] = true; aim_at(P, T.pos))
	P.inp["fire"] = false
	step(m, 0.5)
	ok("archer bow: perfect release, Supercharged damage, a quick next draw", K.perfects == pf0 + 1 and dmg(T) >= 55.0 and dmg(T) <= 66.0 and K.draw.quick, "perfects %d took %.0f quick %s" % [K.perfects - pf0, dmg(T), K.draw.quick])
	# E: Hail Wall: a line of falling arrows; damage over time, slow, blight
	P.teleport(home); fresh(T); T.teleport(home + Vector3(6, 0, 0))
	aim_at(P, T.pos)
	P.ak.use_e()
	ok("archer E: Hail Wall cast", K.in_e())
	step(m, 2.0)
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
	# no knock heal (audit: the data's passive is Static only)
	P.hp = 20.0
	var kt := P.hp
	T2.hp = 1.0
	K.on_deal(T2, 5.0, {"src": "shot"}); T2.hp = 0.0
	K.on_deal(T2, 5.0, {"src": "shot"})
	ok("vireo passive: a knock heals nothing (data)", P.hp <= kt + 0.01, "hp %.0f" % P.hp)
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
	step(m, 2.2)
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
	# Fever: an ability that lands lights one flat 6% lifesteal
	P.hp = 60.0
	K.on_deal(T, 10.0, {"src": "abil", "ab": "utility"})
	K.on_deal(T, 10.0, {"src": "abil", "ab": "k1"})
	ok("venator passive: abilities light Fever (one level, never stacked)", K.res == 1.0)
	var hp0 := P.hp
	K.on_deal(T, 100.0, {"src": "shot"})
	ok("venator passive: Fever heals 6% off damage", absf(P.hp - hp0 - 6.0) < 0.5, "healed %.1f" % (P.hp - hp0))
	K.res = 0.0
	# Burr Charge: thrown at a foe, it goes off on them (damage + Dazed, no cone); walls and the ground give the cone
	fresh(T); T2.teleport(home + Vector3(12, 0, 0)); P.teleport(home); T.teleport(home + Vector3(7, 0, 0)); step(m, 0.2); aim_at(P, T.pos); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	tap(m, P)
	step(m, 1.6)
	var dazed := KitStatus.rattled(T) and K.direct_hits >= 1
	ok("venator RMB: a direct hit hurts and Dazes", dmg(T) >= 12.0 and dazed, "took %.0f" % dmg(T))
	ok("venator RMB: the hit fed Fever", K.res >= 1.0, "fever %.0f" % K.res)
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
	P.do_dash(); step(m, 0.6)      # the tap skid runs ~0.5s
	ok("venator dash tap: Slipstep skid", K.last_dash_kind == "step" and P.flat_dist(home) > 1.8, "moved %.1f" % P.flat_dist(home))
	P.inp["move"] = Vector2.ZERO
	await done(m)

# ------------------------------------------------------------------ Juggernaut: tools/dancer_jug_check.gd
func _juggernaut() -> void:
	await _dj().juggernaut(self)

# ------------------------------------------------------------------ Bulwark
func _bulwark() -> void:
	var r := setup("bulwark", 5.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	ok("bulwark: War Hammer & Aegis", P.wid == "tower_shield")
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
	# tap: no Bash (it is Shift behind the shield); at 50 Guard the Shield Charge ends in a Shield Slam
	T.teleport(home + Vector3(1.8, 0, 0)); fresh(T); aim_at(P, T.pos); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	var x0 := T.pos.x
	tap(m, P)
	step(m, 0.3)
	ok("bulwark RMB tap: no Bash any more", K.last_variant == "tap" and absf(T.pos.x - x0) < 0.2 and dmg(T) <= 0.0 and K.ch_rmb >= 1.0, "pushed %.1f" % (T.pos.x - x0))
	T.teleport(home + Vector3(1.8, 0, 0)); fresh(T); K.res = 60.0; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; step(m, 1.0); fresh(T)
	ok("bulwark resource full: Shield Slam armed", K.full_ready() and K.ready_label() != "")
	# hold to block, let go: the aegis just comes down (the foe at its face got only the aegis's 2 m push, no Bash)
	x0 = T.pos.x
	hold(m, P, 0.5)
	step(m, 0.3)
	ok("bulwark RMB release after block: only lowers", K.wall.is_empty() and K.last_variant == "hold" and dmg(T) <= 0.0 and absf(T.pos.x - x0 - 2.0) < 0.3, "pushed %.1f" % (T.pos.x - x0))
	K.res = 0.0
	# Crushed: a Shield Charge into a wall stuns (no heal)
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
	K.lock_t = 0.0; P.dashes = P.max_dashes()
	step(m, 0.2)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.do_dash()
	step(m, 0.35, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	step(m, 0.2)
	ok("bulwark payoff: Shield Charge into a wall Crushes (stun, no heal)", K.crushes == c0 + 1 and T.stun_t > 0.0 and P.hp <= hp0 + 1.0, "crushes %d stun %.2f hp %.0f -> %.0f" % [K.crushes - c0, T.stun_t, hp0, P.hp])
	for dz in range(-3, 4):
		for dx in range(0, 3):
			wl[W.idx(int(home.x) + 3 + dx, int(home.z) + dz)] = lv
	W.level = wl
	# LMB tap: the hammer flies to the cursor (through the foe in front), stays planted, comes back on a second tap
	T.teleport(home + Vector3(4.0, 0, 0)); fresh(T); P.teleport(home); aim_at(P, T.pos + Vector3(1.0, 0, 0)); P.fire_cd = 0.0
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false; m.step(DT)
	ok("bulwark LMB tap: hammer thrown", not K.mace.is_empty())
	step(m, 0.6)
	var thrown := dmg(T)
	ok("bulwark LMB: hammer hits and stays planted", thrown >= 10.0 and String(K.mace.get("st", "")) == "ground", "took %.0f state %s" % [thrown, String(K.mace.get("st", ""))])
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
	P.teleport(home); P.dashes = P.max_dashes(); K.lock_t = 0.0; K.shield_hp = K.shield_max(); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.do_dash()
	var inv := P.inv_t
	step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false; P.inp["move"] = Vector2.ZERO
	step(m, 0.1)
	ok("bulwark dash with the shield up: Shield Charge", K.st.get("last_dash") == "charge" and inv > 0.15 and P.flat_dist(home) > 3.0, "inv %.2f moved %.1f" % [inv, P.flat_dist(home)])
	# E: Mending Ground: the column comes down for 1s, then the zone heals over time and ends in a burst
	P.teleport(home); P.hp = P.max_hp - 100.0; hp0 = P.hp
	P.inp["aim"] = home + Vector3(1, 0, 0)
	P.ak.use_e()
	step(m, 0.5)
	var mid := P.hp
	step(m, 4.8)
	ok("bulwark E: Mending Ground heals after its delay, over its zone", mid <= hp0 + 1.0 and P.hp >= hp0 + 30.0, "hp %.0f -> %.0f -> %.0f" % [hp0, mid, P.hp])
	await done(m)

# ------------------------------------------------------------------ levels and the Bonded R
func _levels_and_bond() -> void:
	var r := setup("thief", 6.0, "cindle")      # (a kit with an R: Sparkle and Vex have none)
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
	# X is the hero's own ultimate: it casts at level 6 and, even with the bond full, never merges (R does)
	P.ult = 1.0
	P.merge_cd = 0.0
	P.ak.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	step(m, 0.5)
	ok("X: the hero ultimate casts and never merges (R is the Merge)",
			float(P.ak.cd["x"]) > 10.0 and not P.ak.bonded and not KinMerge.active(P))
	await done(m)

# ------------------------------------------------------------------ cross-ability combinations (--kit-combo-check)
## Sable's and Juggernaut's interactions and their merge-hold rules live in tools/dancer_jug_check.gd.
func _combos() -> void:
	await _dj().combos(self)

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
	ok("infusion: Gravadillo adds a control to Sparkle's Coilshot", (fm["effects"] as Array).any(func(e): return KinParts.category(String(e["type"])) == "control"), "; ".join(fm["notes"]))
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
	step(m, 0.8)          # (the Bola's 0.4s wind-up with the lane, then its flight)
	ok("infusion runtime: Bola + poison", T.burn_t > 0.0, "burn %.1f" % T.burn_t)
	await done(m)
	r = setup("mage", 5.0, "puddlet")
	m = r[0]; P = r[1]; T = r[2]
	hold(m, P, 0.5)
	step(m, 0.6)
	ok("infusion runtime: a Boki's type rides Sparkle's Coilshot", dmg(T) > 0.0 and (T.slow_t > 0.0 or T.burn_t > 0.0 or T.stun_t > 0.0 or T.root_t > 0.0), "slow %.2f burn %.2f stun %.2f" % [T.slow_t, T.burn_t, T.stun_t])
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
	ok("feel: the Finishing Slam lands after a 0.5s wind-up", float(Arch.def("juggernaut")["rmb"]["windup"]) >= 0.3)
	# the hero ultimates on X run their own wind-ups (a growing ring, a guard), on the source's cooldown ratios
	var ults: Array = Arch.ids().filter(func(a): return Arch.def(a).has("x"))
	ok("feel: every X ultimate has its own wind-up (no generic fuse) and a 15-80s cooldown (the game data runs to 80s)",
			ults.all(func(a): return _ult_shaped(Arch.def(a)["x"])))
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
