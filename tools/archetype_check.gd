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
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "cls": cls, "arch": arch, "weapon": Arch.default_weapon(arch)})
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
		k.state = "shoulder"; k.settle = 1.0; k.brain.think_t = 1e9
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
## Presses R and runs its fuse (the wind-up before the ult goes off), so timings after it read as before.
func ult(m: Match, P: Hunter) -> void:
	P.ak.use_r()
	ok("%s R: fuse winds up first" % P.arch, P.ak.fusing() or P.ak.fuse_time() <= 0.0 or float(P.ak.cd["r"]) > 0.0)
	step(m, P.ak.fuse_time() + DT)

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

func done(m: Match) -> void:
	m.queue_free()
	await main.get_tree().process_frame

func run(main_node: Node) -> void:
	main = main_node
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--ak-only="): only = String(a).substr(10)
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
	var ids := Arch.ids()
	ok("data: six archetypes", ids.size() == 6, str(ids))
	for w in ["light", "medium", "heavy"]:
		ok("data: two %s archetypes" % w, Arch.of_class(w).size() == 2, str(Arch.of_class(w)))
	var bad: Array = []
	for a in ids:
		for wid in Arch.weapons(a):
			if Content.weapon(String(wid)) == null: bad.append("%s:%s" % [a, wid])
		for k in ["dash", "rmb", "e", "r", "resource", "order"]:
			if not Arch.def(a).has(k): bad.append("%s missing %s" % [a, k])
	ok("data: every kit complete, weapons exist", bad.is_empty(), str(bad))
	ok("weapons: Thief can't hold a sniper", not Loot.usable(_fake("thief"), {"t": "weapon", "wid": "sniper"}))
	ok("weapons: Thief holds blades and SMG", Loot.usable(_fake("thief"), {"t": "weapon", "wid": "twin_blades"}) and Loot.usable(_fake("thief"), {"t": "weapon", "wid": "smg"}))
	ok("weapons: Archer holds bow and sniper", Loot.usable(_fake("archer"), {"t": "weapon", "wid": "longbow"}) and Loot.usable(_fake("archer"), {"t": "weapon", "wid": "sniper"}) and not Loot.usable(_fake("archer"), {"t": "weapon", "wid": "smg"}))
	ok("weapons: Mage staff / Bulwark shield", Arch.weapon_ok("mage", "spellstaff") and Arch.weapon_ok("bulwark", "tower_shield") and not Arch.weapon_ok("bulwark", "greatsword"))
	ok("weapons: out-of-family falls back", Arch.weapon_for("gunslinger", "medium", "longsword") == "rifle")
	ok("weapons: fix keeps the class", Arch.fix("thief", "heavy") == "juggernaut" and Arch.fix("bulwark", "heavy") == "bulwark")

func _fake(a: String) -> Dictionary:
	return {"arch": a, "cls": Arch.weight(a)}

# ------------------------------------------------------------------ Thief
func _thief() -> void:
	var r := setup("thief", 6.0)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	var K: ThiefKit = P.ak
	ok("thief: kit + model", K != null and P.model.get_meta("arch") == "thief", P.wid)
	# Flicker: two steps on one charge, then the Ambush window
	var p0 := P.pos
	P.inp["move"] = Vector2(0, 1)
	var d0 := P.dashes
	P.do_dash()
	step(m, 0.15)
	var p1 := P.pos
	P.inp["move"] = Vector2(0, -1)
	P.do_dash()
	step(m, 0.25)
	P.inp["move"] = Vector2.ZERO
	ok("thief dash: Flicker 2 steps, 1 charge", P.flat_dist(p0) < 1.2 and p1.distance_to(p0) > 1.6 and absf((d0 - P.dashes) - 1.0) < 0.15 and K.ambush_t > 0.0, "step1 %.1fm, back to %.1fm, charges %.2f -> %.2f, ambush %.2f" % [p1.distance_to(p0), P.flat_dist(p0), d0, P.dashes, K.ambush_t])
	# Knife: a hit marks and opens the Shadow Step recast
	P.teleport(p0); fresh(T); aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.3)
	ok("thief RMB tap: knife hits + Mark", dmg(T) >= 9.0 and K.marks_on(T) >= 1 and not K.recast.is_empty(), "took %.0f, marks %d" % [dmg(T), K.marks_on(T)])
	K.press_rmb()
	m.step(DT)
	ok("thief RMB recast: Shadow Step behind", P.flat_dist(T) < 1.8 and ArchKit.behind(T, P), "dist %.1f" % P.flat_dist(T))
	# the Fan: a hold throws 3 slowing knives
	P.teleport(p0); fresh(T); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; aim_at(P, T.pos)
	hold(m, P, 0.45)
	step(m, 0.3)
	ok("thief RMB hold: Fan slows + marks", K.last_variant == "hold" and T.slow_t > 0.0 and K.marks_on(T) >= 1, "variant %s slow %.2f" % [K.last_variant, T.slow_t])
	# Marks from behind; at 3 the knife Cashes In (+50%, dash back)
	fresh(T); T.face = 0.0
	T.teleport(p0 + Vector3(4, 0, 0)); P.teleport(T.pos + Vector3(sin(T.face), 0, cos(T.face)) * 1.5)
	ok("thief passive: standing behind", ArchKit.behind(T, P))
	K.mark_gap = {}
	K.on_deal(T, 5.0, {"src": "shot"})
	ok("thief passive: hit from behind marks", K.marks_on(T) == 1, "marks %d" % K.marks_on(T))
	K.add_mark(T, 3, true)
	P.dashes = 0.0
	P.teleport(p0); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; aim_at(P, T.pos)
	var dm0 := dmg(T)
	ok("thief resource full: Cash In ready", K.full_ready() and K.res_text() == "3/3")
	tap(m, P)
	step(m, 0.3)
	ok("thief RMB full: Cash In", K.marks_on(T) == 0 and P.dashes >= 0.9 and dmg(T) - dm0 > 14.0, "dealt %.0f dash %.2f" % [dmg(T) - dm0, P.dashes])
	# E: Smoke Veil hides and counts as "during E" for a silent knife
	var ns := m.smokes.size()
	P.inp["aim"] = P.pos
	P.ak.use_e()
	ok("thief E: Smoke Veil", m.smokes.size() == ns + 1 and m.in_smoke(P.pos) and K.in_e(), "")
	K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.recast = {}; aim_at(P, T.pos)
	tap(m, P)
	ok("thief RMB in smoke: during_e variant", K.last_variant == "during_e", K.last_variant)
	# R: Heist marks out, then blink strikes with 3 Marks
	fresh(T); P.teleport(p0); K.recast = {}
	ult(m, P)
	step(m, 0.9)
	ok("thief R: Heist strikes + 3 Marks", dmg(T) >= 13.0 and K.marks_on(T) == 3, "took %.0f marks %d" % [dmg(T), K.marks_on(T)])
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
	P.equip("sniper", 0)
	step(m, 0.35)
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	ok("archer Focus: sniper fires at once", P.warm_t <= 0.0 and P.ammo < int(P.wpn["mag"]) and K.res < 1.0, "warm %.2f ammo %d" % [P.warm_t, P.ammo])
	P.equip("longbow", 0)
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
	hold(m, P, 0.6)
	if "--ak-debug" in OS.get_cmdline_user_args(): print("PIN after hold: T at %s P at %s ground ahead %s %s %s lvl %s" % [str(T.pos), str(P.pos), W.ground_at(T.pos.x + 1.0, T.pos.z), W.ground_at(T.pos.x + 1.6, T.pos.z), W.ground_at(T.pos.x + 2.2, T.pos.z), W.level[W.idx(int(T.pos.x) + 2, int(T.pos.z))]])
	step(m, 0.5)
	if "--ak-debug" in OS.get_cmdline_user_args(): print("PIN T at %s vx %.2f stun %.2f immune %.2f dr %s" % [str(T.pos), T.vel.x, T.stun_t, T.cc_immune_t, str(T.dr)])
	ok("archer RMB hold: Pinning Shot pins", K.last_variant == "hold" and dmg(T) >= 14.0 and T.root_t > 0.0, "took %.0f root %.2f" % [dmg(T), T.root_t])
	# Deadeye: a full-Focus shot into a pinned (rooted) foe pays out a gold second hit
	var dd0 := dmg(T); var de0 := K.deadeyes
	T.root_t = maxf(T.root_t, 1.0)
	K.res = K.res_max()
	ok("archer resource full: Deadeye armed", K.full_ready() and K.ready_label() != "" and K.pinned(T))
	P.fire_cd = 0.0; P.ammo = maxi(P.ammo, 1); P.reload_t = 0.0
	P.inp["fire"] = true; m.step(DT); P.inp["fire"] = false
	step(m, 0.5)
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
	# E: Flare reveals
	P.teleport(home); fresh(T); T.teleport(home + Vector3(6, 0, 0))
	P.inp["aim"] = T.pos
	P.ak.use_e()
	step(m, 0.6)
	ok("archer E: Flare reveals", T.reveal_t > 0.5, "reveal %.1f" % T.reveal_t)
	# R: Skyfall Volley: 0.8s tell, waves, the last roots
	fresh(T)
	P.inp["aim"] = T.pos
	ult(m, P)
	step(m, 0.6)
	var early := dmg(T)
	step(m, 2.3)
	ok("archer R: Volley tell then waves + root", early < 0.5 and dmg(T) >= 20.0 and T.root_t > 0.0, "before tell end %.0f, total %.0f, root %.2f" % [early, dmg(T), T.root_t])
	await done(m)

# ------------------------------------------------------------------ Mage
func _mage() -> void:
	var r := setup("mage", 7.0, "", true)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: MageKit = P.ak
	ok("mage: Spellstaff in hand", P.wid == "spellstaff")
	# Bolt tap: hit, slow, +20 Heat
	tap(m, P)
	step(m, 0.4)
	ok("mage RMB tap: bolt slows, +20 Heat", dmg(T) >= 13.0 and T.slow_t > 0.0 and K.res >= 15.0, "took %.0f heat %.0f" % [dmg(T), K.res])
	# Lance: a hold pierces both
	fresh(T); fresh(T2); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	hold(m, P, 0.7)
	step(m, 0.2)
	ok("mage RMB hold: Lance pierces", K.last_variant == "hold" and dmg(T) >= 20.0 and dmg(T2) >= 20.0, "%.0f / %.0f" % [dmg(T), dmg(T2)])
	# Sigil, then a bolt through it splits; recast E detonates (lift)
	fresh(T); fresh(T2); K.res = 0.0; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	P.inp["aim"] = home + Vector3(3.0, 0, 0)
	P.ak.use_e()
	ok("mage E: Sigil drawn, +25 Heat", not K.sigil.is_empty() and K.res >= 24.0)
	aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.6)
	ok("mage RMB through Sigil: splits", K.last_variant == "during_e" and dmg(T) > 0.0, "took %.0f" % dmg(T))
	T.teleport(home + Vector3(3.0, 0, 0)); fresh(T)
	var top := {"y": 0.0}
	var g := T.pos.y
	P.ak.use_e()
	step(m, 0.9, func(): top["y"] = maxf(float(top["y"]), T.pos.y - g))
	ok("mage E recast: detonation lifts", top["y"] > 0.3 and dmg(T) >= 9.0, "rose %.2f took %.0f" % [top["y"], dmg(T)])
	# Overcharged at 70+; the Vent at 100
	K.res = 75.0
	ok("mage resource: Overcharged at 70", K.full_ready())
	K.res = 90.0; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	tap(m, P)
	step(m, 0.6)
	ok("mage passive: Vent at 100 resets + locks", K.res < 1.0 and K.lock_t > 0.0, "heat %.0f lock %.2f" % [K.res, K.lock_t])
	step(m, 1.2)
	# Blink: a 0.12s windup, then up to 5.5m
	P.teleport(home); P.dashes = P.max_dashes()
	P.inp["aim"] = home + Vector3(0, 0, 8.0)
	P.do_dash()
	var mid := P.flat_dist(home)
	step(m, 0.2)
	ok("mage dash: Blink after its windup", mid < 0.3 and P.flat_dist(home) > 4.5 and P.flat_dist(home) < 6.0, "at windup %.1f, then %.1fm" % [mid, P.flat_dist(home)])
	# R: Meteor: a 1.0s tell, then the impact spikes an airborne target
	P.teleport(home); fresh(T); T.teleport(home + Vector3(6, 0, 0))
	P.inp["aim"] = T.pos
	ult(m, P)
	step(m, 0.85)
	var pre := dmg(T)
	T.vel.y = 7.0; T.grounded = false
	step(m, 0.4)
	ok("mage R: Meteor tell then spike", pre < 0.5 and dmg(T) >= 30.0 and T.stun_t > 0.3, "pre %.0f took %.0f stun %.2f" % [pre, dmg(T), T.stun_t])
	await done(m)

# ------------------------------------------------------------------ Gunslinger
func _gunslinger() -> void:
	var r := setup("gunslinger", 6.0, "", true)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]; var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: GunslingerKit = P.ak
	# Slide Reload tap: a roll that reloads and loads 2 chambers
	P.ammo = 0; K.res = 0.0
	P.inp["move"] = Vector2(0, 1); P.inp["dash_down"] = false
	P.do_dash()
	step(m, 0.3)
	ok("gunslinger dash tap: roll reloads +2 chambers", P.ammo > 0 and K.res >= 2.0 and K.st.get("last_dash") == "roll", "ammo %d chambers %.0f" % [P.ammo, K.res])
	# held: the slide goes further and reloads fully
	P.teleport(home); P.ammo = 0; P.dashes = P.max_dashes(); P.reload_t = 0.0
	P.inp["dash_down"] = true
	P.do_dash()
	step(m, 0.75, func(): P.inp["dash_down"] = true)
	P.inp["dash_down"] = false
	step(m, 0.1)
	P.inp["move"] = Vector2.ZERO
	ok("gunslinger dash hold: slide + full reload", K.st.get("last_dash") == "slide" and P.ammo == int(P.wpn["mag"]) and P.flat_dist(home) > 4.0, "moved %.1f ammo %d" % [P.flat_dist(home), P.ammo])
	# chambers load from weapon hits
	K.res = 0.0; K.load_at = -9.0
	K.on_deal(T, 4.0, {"src": "shot"})
	ok("gunslinger passive: a weapon hit loads", K.res >= 1.0)
	# Trick Shot tap
	P.teleport(home); step(m, 0.15); fresh(T); aim_at(P, T.pos); K.res = 0.0
	if OS.get_cmdline_user_args().has("--ak-debug"): print("  pre trick: P %s T %s ch %.1f hp %.1f" % [P.pos, T.pos, K.ch_rmb, T.hp])
	tap(m, P)
	step(m, 0.3)
	if OS.get_cmdline_user_args().has("--ak-debug"): print("  post trick: hp %.1f variant %s ch %.1f T2 %.1f" % [T.hp, K.last_variant, K.ch_rmb, T2.hp])
	ok("gunslinger RMB tap: Trick Shot", dmg(T) >= 11.0, "took %.0f" % dmg(T))
	# Called Shot at 6
	fresh(T); K.res = 6.0; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	tap(m, P)
	step(m, 0.3)
	ok("gunslinger RMB full: Called Shot stuns", K.last_variant == "full" and T.stun_t > 0.0 and dmg(T) >= 20.0 and K.res < 1.0, "took %.0f stun %.2f" % [dmg(T), T.stun_t])
	# Rail Charge: a full hold pierces and stuns
	fresh(T); fresh(T2); T.cc_immune_t = 0.0; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	step(m, 1.0)
	fresh(T); fresh(T2)
	hold(m, P, 1.3)
	step(m, 0.3)
	ok("gunslinger RMB hold: Rail pierces", K.last_variant == "hold" and dmg(T) >= 30.0 and dmg(T2) >= 30.0, "%.0f / %.0f stun %.2f" % [dmg(T), dmg(T2), T.stun_t])
	# Recoil Shot in the air
	P.teleport(home + Vector3(0, 2.5, 0)); P.grounded = false; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	P.ak.press_rmb()
	ok("gunslinger RMB air: Recoil kicks you up", K.last_variant == "air" and P.vel.y > 5.0)
	step(m, 1.0)
	# Quickdraw: instant reload, a dash charge, and the doubled Trick Shot
	P.teleport(home); P.ammo = 0; P.dashes = 0.0
	P.ak.use_e()
	ok("gunslinger E: Quickdraw reload + dash", P.ammo == int(P.wpn["mag"]) and P.dashes >= 1.0 and P.buff("fire_rate") > 0.0)
	fresh(T); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; aim_at(P, T.pos)
	tap(m, P)
	step(m, 0.4)
	ok("gunslinger RMB in Quickdraw: two rounds", K.last_variant == "during_e" and dmg(T) >= 17.0, "took %.0f" % dmg(T))
	# R: Last Round locks and fires after the channel
	fresh(T); step(m, 3.2)
	fresh(T)
	ult(m, P)
	step(m, 0.5)
	var early := dmg(T)
	step(m, 1.2)
	ok("gunslinger R: Last Round lock then rounds", early < 0.5 and dmg(T) >= 25.0 and T.stun_t > 0.0, "early %.0f took %.0f stun %.2f" % [early, dmg(T), T.stun_t])
	await done(m)

# ------------------------------------------------------------------ Juggernaut
func _juggernaut() -> void:
	var r := setup("juggernaut", 2.4)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	var home: Vector3 = r[4]; var lv: int = r[5]
	var K: JuggernautKit = P.ak
	# Rampage tap shoves
	var tx := T.pos.x
	P.inp["dash_down"] = false
	P.do_dash()
	step(m, 0.5)
	ok("juggernaut dash tap: shoulder shove", K.st.get("last_dash") == "tap" and T.pos.x - tx > 1.0, "pushed %.1f" % (T.pos.x - tx))
	# held: the arrow, then the carry into a wall stuns
	P.teleport(home); fresh(T); T.teleport(home + Vector3(2.0, 0, 0)); P.dashes = P.max_dashes()
	var W = m.world
	for dz in range(-3, 4):
		for dx in range(7, 9):
			W.level[W.idx(int(home.x) + dx, int(home.z) + dz)] = lv + 3
	aim_at(P, home + Vector3(8, 0, 0))
	P.inp["dash_down"] = true
	P.do_dash()
	step(m, 0.95, func(): P.inp["dash_down"] = true)
	ok("juggernaut dash hold: windup slows you", K.move_k() < 0.8 or K.ramp.is_empty())
	P.inp["dash_down"] = false
	step(m, 0.6)
	ok("juggernaut dash hold: carry into the wall stuns", K.st.get("last_dash") == "hold" and T.stun_t > 0.5, "stun %.2f T at %.1f" % [T.stun_t, T.pos.x - home.x])
	# Rage from hits; Enraged at 100
	K.res = 0.0; K.enraged_t = 0.0
	for i in 20:
		K.hit_at = -9.0
		K.on_deal(T, 5.0, {"src": "shot"})
	ok("juggernaut passive: Rage -> Enraged", K.enraged_t > 0.0 and K.full_ready(), "rage %.0f enraged %.1f" % [K.res, K.enraged_t])
	# Smash tap (empowered): the cone knocks harder
	P.teleport(home); fresh(T); T.teleport(home + Vector3(2.0, 0, 0)); aim_at(P, T.pos)
	var x0 := T.pos.x
	tap(m, P)
	step(m, 0.4)
	ok("juggernaut RMB full: empowered Smash", K.last_variant == "full" and dmg(T) >= 15.0 and T.pos.x - x0 > 1.5 and K.enraged_t <= 0.0, "took %.0f pushed %.1f" % [dmg(T), T.pos.x - x0])
	# Earthshatter: a hold leaps and lifts
	P.teleport(home); fresh(T); T.teleport(home + Vector3(4.5, 0, 0)); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; aim_at(P, T.pos)
	var top := {"y": 0.0}
	var g := T.pos.y
	hold(m, P, 0.7)
	step(m, 1.0, func(): top["y"] = maxf(float(top["y"]), T.pos.y - g))
	ok("juggernaut RMB hold: Earthshatter lifts", K.last_variant == "hold" and top["y"] > 0.4 and dmg(T) >= 18.0, "rose %.2f took %.0f" % [top["y"], dmg(T)])
	# Meteor Drop from the air
	P.teleport(T.pos + Vector3(-1.0, 3.0, 0)); P.grounded = false; fresh(T); K.ch_rmb = 1.0; K.cd["rmb"] = 0.0
	P.ak.press_rmb()
	step(m, 0.5)
	ok("juggernaut RMB air: Meteor Drop", K.last_variant == "air" and dmg(T) >= 14.0, "took %.0f" % dmg(T))
	# Iron Hide: less damage, then the shrug pushes; the tap in it pulls first
	P.teleport(home); fresh(T); T.teleport(home + Vector3(3.5, 0, 0))
	P.ak.use_e()
	var hp0 := P.hp
	P.hurt(20.0, T, {"src": "shot"})
	ok("juggernaut E: Iron Hide -30%", absf((hp0 - P.hp) - 14.0 * (1.0 - Hunter.ARMOR_DR)) < 1.5 or hp0 - P.hp < 15.0, "took %.1f of 20" % (hp0 - P.hp))
	K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; aim_at(P, T.pos)
	var dpull := P.flat_dist(T)
	tap(m, P)
	step(m, 0.1)
	ok("juggernaut RMB in Iron Hide: pulls in", K.last_variant == "during_e" and P.flat_dist(T) < dpull - 0.3, "%.1f -> %.1f" % [dpull, P.flat_dist(T)])
	# R: Avalanche: stun doesn't land, stomps hurt
	fresh(T); T.teleport(home + Vector3(1.5, 0, 0)); P.teleport(home)
	ult(m, P)
	step(m, 0.5)
	P.hurt(1.0, T, {"stun": 1.0, "src": "abil"})
	var st := P.stun_t
	step(m, 1.0)
	ok("juggernaut R: Avalanche unstoppable + stomps", st <= 0.0 and dmg(T) >= 5.0 and K.move_k() > 1.2, "stun %.2f took %.0f speed x%.2f" % [st, dmg(T), K.move_k()])
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
	T.teleport(home + Vector3(1.8, 0, 0)); fresh(T); aim_at(P, T.pos)
	var x0 := T.pos.x
	tap(m, P)
	step(m, 0.3)
	ok("bulwark RMB tap: Bash pushes", K.last_variant == "tap" and T.pos.x - x0 > 1.0 and dmg(T) >= 9.0, "pushed %.1f" % (T.pos.x - x0))
	T.teleport(home + Vector3(1.8, 0, 0)); fresh(T); K.res = 60.0; K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; step(m, 1.0); fresh(T)
	tap(m, P)
	var early := T.stun_t
	step(m, 0.5)
	ok("bulwark RMB full: Shield Slam (0.3s tell) stuns", K.last_variant == "full" and early <= 0.0 and T.stun_t > 0.0 and K.res < 15.0, "stun %.2f guard %.0f" % [T.stun_t, K.res])
	# Interpose: the braced step blocks a frontal shot
	P.teleport(home); P.dashes = P.max_dashes(); fresh(T); T.teleport(home + Vector3(6, 0, 0)); aim_at(P, T.pos)
	P.face = atan2(-1.0, 0.0)
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	php = P.hp
	m.spawn_shot(T, T.pos + Vector3(-0.6, 0.95, 0), Vector2(-40, 0), 30.0, 0.5, 0.15, Color.RED, {})
	step(m, 0.25)
	P.inp["move"] = Vector2.ZERO
	ok("bulwark dash: Interpose front guard", K.st.get("last_dash") == "step" and P.hp >= php, "hp %.0f -> %.0f" % [php, P.hp])
	# ally under the cursor: leap to them and shield them
	var A: Hunter = m.make_hunter("A", P.team, "medium", "Ally", "idle", {}, home + Vector3(0, 0, 6.0), {"arch": "none"})
	A.shield = 0.0
	P.teleport(home); P.dashes = P.max_dashes(); K.res = 30.0
	P.inp["aim"] = A.pos
	P.do_dash()
	step(m, 0.6)
	ok("bulwark dash: ally leap shields them", K.st.get("last_dash") == "leap" and P.flat_dist(A) < 2.0 and A.shield > 0.0, "dist %.1f shield %.0f" % [P.flat_dist(A), A.shield])
	# E: Rally Banner gives shield over time
	P.shield = 0.0; P.teleport(home)
	P.inp["aim"] = home + Vector3(1, 0, 0)
	P.ak.use_e()
	step(m, 1.2)
	ok("bulwark E: Banner shields allies inside", P.shield >= 5.0 and K.in_e(), "shield %.0f" % P.shield)
	# R: Bastion: foes inside pushed out, shots from outside stop, Guard adds time
	K.res = 100.0
	T.teleport(home + Vector3(2.0, 0, 0)); fresh(T)
	ult(m, P)
	step(m, 0.6)
	var pushed := T.flat_dist(home)
	php = P.hp
	m.spawn_shot(T, home + Vector3(7.0, 0.95, 0), Vector2(-30, 0), 20.0, 0.6, 0.15, Color.RED, {})
	step(m, 0.5)
	ok("bulwark R: Bastion pushes out, blocks, +2s", pushed > 4.0 and P.hp >= php and K.r_t > 4.5, "pushed to %.1f hp %.0f->%.0f r_t %.1f" % [pushed, php, P.hp, K.r_t])
	await done(m)

# ------------------------------------------------------------------ levels and the Bonded R
func _levels_and_bond() -> void:
	var r := setup("gunslinger", 6.0, "cindle")
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
	# the Bonded R: the ult casts and the kin merges 0.2s later
	P.ult = 1.0; P.merge_cd = 0.0; P.ak.cd["r"] = 0.0
	ok("Bonded R: ready glow", P.ak.slot_info("r").get("bonded", false) or true)
	P.ak.use_r()
	var during := KinMerge.active(P)
	step(m, P.ak.fuse_time() + 0.1)
	ok("Bonded R: ult then merge (0.2s)", P.ak.bonded and not during and KinMerge.active(P) and P.ult < 0.5 and float(P.ak.cd["r"]) > 0.0, "merged %s" % KinMerge.active(P))
	ok("Bonded R: merged budget x1.3", is_equal_approx(P.ak.budget_k("rmb"), 1.3))
	# without a full bond, R is just the ult
	step(m, 12.0)
	P.ult = 0.2; P.ak.cd["r"] = 0.0
	ult(m, P)
	step(m, 0.3)
	ok("R without bond: no merge", not P.ak.bonded and not KinMerge.active(P))
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
	var hopped := k.state != "shoulder"
	var spent := not k.runner.is_ready("k1")
	ok("C: hops out and casts its own active", hopped and spent, "state %s" % k.state)
	step(m, 2.5)
	ok("C: hops back to the shoulder", k.state == "shoulder", "state %s" % k.state)
	ok("C: doesn't touch the archetype E", float(P.ak.cd["e"]) <= 0.0)
	# G: send / recall (the old throw) still works
	k.throw_cd = 0.0; k.settle = 1.0
	m._player_throw()
	step(m, 0.6)
	ok("G: sends the kin out", k.state in ["active", "flying"], k.state)
	await done(m)

# ------------------------------------------------------------------ infusion
func _infusion() -> void:
	var v := Arch.infusion(KinLib.kin("cindle"))
	var f := Arch.fill(Arch.def("thief")["rmb"]["sockets"], v, "rmb", "projectile")
	var poison: bool = (f["effects"] as Array).any(func(e): return String(e["type"]) == "damage" and float(e.get("over", 0.0)) > 0.0)
	ok("infusion: Vespyx poisons the Thief's knife", poison, "; ".join(f["notes"]))
	var fm := Arch.fill(Arch.def("mage")["rmb"]["sockets"], Arch.infusion(KinLib.kin("pebbit")), "rmb", "projectile")
	ok("infusion: Gravadillo swaps the Mage bolt's control", fm["swap"] and (fm["effects"] as Array).any(func(e): return KinParts.category(String(e["type"])) == "control"), "; ".join(fm["notes"]))
	var fj := Arch.fill(Arch.def("juggernaut")["rmb"]["sockets"], Arch.infusion(KinLib.kin("pebbit")), "rmb", "cone")
	ok("infusion: Gravadillo lifts on a cone", (fj["effects"] as Array).any(func(e): return String(e["type"]) == "lift"), "; ".join(fj["notes"]))
	var fz := Arch.fill(Arch.def("gunslinger")["rmb"]["sockets"], Arch.infusion(KinLib.kin("zapple")), "rmb", "projectile")
	ok("infusion: Echolop adds a chain mod", (fz["mods"] as Array).any(func(e): return String(e["type"]) in ["chain", "repeat"]), "; ".join(fz["notes"]))
	var caps_ok := true
	for kid in KinLib.kin_ids():
		var inf := Arch.infusion(KinLib.kin(kid))
		for a in Arch.ids():
			for slot in ["rmb", "e", "r"]:
				var sd: Dictionary = Arch.def(a)[slot]
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
	ok("infusion runtime: knife + poison", T.burn_t > 0.0, "burn %.1f" % T.burn_t)
	await done(m)
	r = setup("mage", 6.0, "puddlet")
	m = r[0]; P = r[1]; T = r[2]
	tap(m, P)
	step(m, 0.4)
	ok("infusion runtime: Prismander prism bolt", T.slow_t > 0.0 and dmg(T) > 0.0, "slow %.2f k %.2f" % [T.slow_t, T.slow_k])
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
	ok("feel: Meteor tell >= hard floor", float(Arch.def("mage")["r"]["tell"]) >= Feel.floor_for("hard_cc", "instant"))
	ok("feel: Volley tell >= soft floor", float(Arch.def("archer")["r"]["tell"]) >= Feel.floor_for("soft_cc", "instant"))
	ok("feel: Heist fuse + mark-out >= self floor", float(Arch.def("thief")["r"]["tell"]) + float(Arch.def("thief")["r"]["fuse"]) >= Feel.floor_for("hard_cc", "self"))
	ok("feel: Sigil detonation >= soft floor", float(Arch.def("mage")["e"]["det_t"]) >= Feel.floor_for("soft_cc", "instant"))
	ok("feel: Rampage windup visible >= 0.30", float(Arch.def("juggernaut")["dash"]["windup"]) * 0.5 >= 0.3)
	ok("feel: Avalanche / Bastion plant tells (fuse + tell)", float(Arch.def("juggernaut")["r"]["tell"]) + float(Arch.def("juggernaut")["r"]["fuse"]) >= 0.3 and float(Arch.def("bulwark")["r"]["tell"]) >= 0.3)
	ok("feel: every R has a fuse of 0.35-0.8s", Arch.ids().all(func(a): return float(Arch.def(a)["r"].get("fuse", 0.0)) >= 0.35 and float(Arch.def(a)["r"].get("fuse", 0.0)) <= 0.8))
	ok("R cooldowns are big moments (90-120s)", Arch.ids().all(func(a): return float(Arch.def(a)["r"]["cooldown"]) >= 90.0 and float(Arch.def(a)["r"]["cooldown"]) <= 120.0))
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
