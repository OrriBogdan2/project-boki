extends "res://tools/hero_pair_check.gd"
## Motley's charged orb (item 60, for --ostra-combo-check; docs/heroes/ostra.md): the wait between shots charges
## the next orb smoothly, its damage, speed, size and brightness follow the charge and cap at the window, a full
## orb slows, every orb passes walls and terrain at any charge, and the glow and chime show the build-up.

const WAITS := [0.0, 0.3, 0.6, 0.8, 1.0, 1.2, 1.4, 2.0, 6.0]      # s since the last shot

## Every orb assertion; returns when done (the caller prints the totals).
func orbs(main_node: Node) -> void:
	main = main_node
	await _charge_curve()
	await _held_fire()
	await _full_slows()
	await _through_walls()
	await _glow_and_chime()
	await _weapon_kept()

## Fires one orb `wait` seconds after the last and returns its shot, with the kit's charge at the shot.
func _fire_after(m: Match, P: Hunter, K: OstraKit, wait: float) -> Dictionary:
	K.last_shot_t = m.time - wait
	K._set_charge(K.wait_charge())
	var k := K.charge
	var sfx := String(P.wpn["sfx"])      # the release sound the shot will play
	var shots0 := P.shot_n
	P.fire_cd = 0.0
	step(m, 0.05, func(): P.inp["fire"] = P.shot_n == shots0)
	P.inp["fire"] = false
	var mine: Array = m.shots.filter(func(s): return s["by"] == P)
	var sd: Dictionary = mine[-1] if not mine.is_empty() else {}      # (point blank it has already hit)
	return {"s": sd, "k": k, "sfx": sfx, "skin": _skin_of(m, sd) if not sd.is_empty() else {}}

func _skin_of(m: Match, sd: Dictionary) -> Dictionary:
	for e in KitLooks.of(m).live:
		if int((e["s"] as Dictionary)["sid"]) == int(sd["sid"]):
			return e
	return {}

## Takes a list and a value picker: true when it never falls.
func _rises(rows: Array, key: String) -> bool:
	for i in range(1, rows.size()):
		if float(rows[i][key]) < float(rows[i - 1][key]) - 0.0001:
			return false
	return true

func _charge_curve() -> void:
	var r := setup("ostra", 12.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: OstraKit = P.ak
	aim_at(P, r[2].pos)
	var base := float(K.base_wpn.get("dmg", P.wpn["dmg"]))
	var rows: Array = []
	for w in WAITS:
		var f := _fire_after(m, P, K, w)
		var sd: Dictionary = f["s"]
		var skin: Dictionary = f["skin"]
		var sn := skin["n"] as Node3D
		var glass := (sn.get_node("Orb/Glass") as MeshInstance3D).material_override as ShaderMaterial
		var rim: Color = glass.get_shader_parameter("rim")
		rows.append({
			"wait": w, "k": f["k"], "dmg": sd["dmg"], "r": sd["r"], "speed": (sd["vel"] as Vector2).length(),
			"scale": sn.scale.x, "bright": rim.get_luminance(), "orb": (sn.get_node("Orb") as Node3D).visible,
			"shard": (sn.get_node("Shard") as Node3D).visible, "sfx": f["sfx"]
		})
		step(m, 0.05)
	var at: Dictionary = {}
	for row in rows: at[row["wait"]] = row
	var table := rows.map(func(q): return "%.1fs k%.2f %.2fdmg x%.2f" % [q["wait"], q["k"], q["dmg"], q["scale"]])
	print("  orb table: ", table)
	for key in ["k", "dmg", "r", "speed", "scale", "bright"]:
		ok("charge: %s never falls with the wait" % key, _rises(rows, key))
	ok("charge: a quick shot is the plain orb (263)", absf(float(rows[0]["dmg"]) - base) < 0.01)
	ok(
		"charge: full at the 1.4s window, 353/263 of the plain orb",
		absf(float(at[1.4]["k"]) - 1.0) < 0.001 and absf(float(at[1.4]["dmg"]) / base - 353.0 / 263.0) < 0.01,
		"%.2f" % float(at[1.4]["dmg"])
	)
	ok(
		"charge: the drawn orb's scale tracks the hit size",
		rows.all(func(q): return absf(float(q["scale"]) - float(q["r"]) / float(rows[0]["r"])) < 0.001),
		"x%.2f" % float(at[1.4]["scale"])
	)
	ok(
		"item 117: a full orb is at least 1.6x a quick one, drawn and hit",
		float(at[1.4]["scale"]) / float(rows[0]["scale"]) >= 1.6 and float(at[1.4]["r"]) / float(rows[0]["r"]) >= 1.6,
		"x%.2f" % (float(at[1.4]["r"]) / float(rows[0]["r"]))
	)
	var two_looks := rows.all(_two_looks_ok)
	ok(
		"owner 11-08: a quick shot is the violet shard, a charged one (k >= 0.5) the void orb, each with its sound",
		two_looks and bool(rows[0]["shard"]) and bool(at[1.4]["orb"])
	)
	var full_x := float(at[1.4]["scale"]) / float(rows[0]["scale"])
	ok("owner 11-08: the full void orb is drawn at least 1.8x a quick shot", full_x >= 1.8, "x%.2f" % full_x)
	await done(m)

## Owner 11-08: below ORB_HELD_K a row is the shard with os_orb, from it the void orb with os_orb_hot.
func _two_looks_ok(q: Dictionary) -> bool:
	var held_orb := float(q["k"]) >= KitLooks.ORB_HELD_K
	var sound := "os_orb_hot" if held_orb else "os_orb"
	return bool(q["orb"]) == held_orb and bool(q["shard"]) != held_orb and String(q["sfx"]) == sound

## Held, the fire rate never builds a charge: the stream stays plain orbs, so its damage is unchanged.
func _held_fire() -> void:
	var r := setup("ostra", 12.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: OstraKit = P.ak
	aim_at(P, r[2].pos)
	step(m, 0.05)
	var plain := float(K.base_wpn["dmg"])
	var seen := {}
	var dmgs: Array = []
	K.last_shot_t = m.time
	step(m, 3.0, func():
		P.inp["fire"] = true
		for s in m.shots:
			if s["by"] == P and not seen.has(s["sid"]):
				seen[s["sid"]] = true
				dmgs.append(float(s["dmg"])))
	P.inp["fire"] = false
	ok(
		"held fire: every orb in the stream is plain",
		dmgs.size() >= 4 and dmgs.all(func(d): return absf(d - plain) < 0.01), str(dmgs)
	)
	await done(m)

func _full_slows() -> void:
	var r := setup("ostra", 8.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: OstraKit = P.ak
	var hit_at := T.pos
	aim_at(P, hit_at)
	_fire_after(m, P, K, 1.3)
	step(m, 0.6)
	ok("slow: a nearly full orb hits but doesn't slow", dmg(T) > 11.0 and T.slow_t <= 0.0, "%.1f" % dmg(T))
	fresh(T)
	_fire_after(m, P, K, 1.4)
	step(m, 0.6)
	ok(
		"slow: a full orb slows (10% for 1.5s, the data's values)",
		T.slow_t > 0.5 and absf(T.slow_k - float(K.lmb_def()["prime_slow"])) < 0.001, "slow %.2f" % T.slow_t
	)
	step(m, 2.0)
	fresh(T)
	aim_at(P, hit_at + Vector3(0, 0, 5.0))
	_fire_after(m, P, K, 1.4)
	aim_at(P, hit_at)
	_fire_after(m, P, K, 0.6)
	step(m, 0.6)
	ok(
		"slow: a plain orb right after a full one that missed doesn't slow",
		dmg(T) > 5.0 and T.slow_t <= 0.0, "took %.1f slow %.2f" % [dmg(T), T.slow_t]
	)
	await done(m)
	r = setup("ostra", 1.2)
	m = r[0]
	P = r[1]
	T = r[2]
	K = P.ak
	aim_at(P, T.pos)
	_fire_after(m, P, K, 1.4)
	step(m, 0.3)
	ok("slow: a full orb fired point blank still slows", dmg(T) > 11.0 and T.slow_t > 0.5, "slow %.2f" % T.slow_t)
	await done(m)

## A rock row between him and the dummy: every charge passes it, also fired with him pressed against it.
func _through_walls() -> void:
	var r := setup("ostra", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: OstraKit = P.ak
	var W = m.world
	var wx := int(floor(home.x)) + 3
	for dz in range(-2, 3):
		W.kind[W.idx(wx, int(floor(home.z)) + dz)] = World.T_BLOCK
	aim_at(P, T.pos)
	P.teleport(Vector3(float(wx) - 0.45, P.pos.y, P.pos.z))
	aim_at(P, T.pos)
	fresh(T)
	_fire_after(m, P, K, 0.6)
	step(m, 0.6)
	ok("walls: fired pressed against the rock, a plain orb still passes", dmg(T) > 5.0, "took %.1f" % dmg(T))
	await _net_copy(m, P, T, K)
	await done(m)

## What other games get: the "s" event carries the full size and the pierce kind, and the copy it makes crosses
## the same rock (through the wire's JSON, as Net sends it).
func _net_copy(m: Match, P: Hunter, T: Hunter, K: OstraKit) -> void:
	P.teleport(P.pos + Vector3(-3.0, 0, 0))
	aim_at(P, T.pos)
	Net.out_events.clear()
	m.net_on = true
	_fire_after(m, P, K, 1.4)
	m.net_on = false
	var sent: Array = Net.out_events.filter(func(e): return e[0] == "s")
	Net.out_events.clear()
	ok("net: the orb goes out as one \"s\" event", sent.size() == 1, "%d" % sent.size())
	if sent.is_empty():
		return
	var ev: Array = JSON.parse_string(JSON.stringify(sent[0]))
	var full_r := float(K.base_wpn["size"]) * K.orb_size_k(1.0)
	ok("net: the event sends the pierce kind", int(ev[11]) == 2, "kind %s" % str(ev[11]))
	ok("net: the event sends the charged size", absf(float(ev[7]) - full_r) < 0.01, "%.2f" % float(ev[7]))
	var shots0 := m.shots.size()
	m._net_ev(ev, "peer")
	ok(
		"net: the copy keeps pierce_terrain",
		m.shots.size() == shots0 + 1 and bool(m.shots[-1]["x"].get("pierce_terrain", false))
	)
	var copy: Dictionary = m.shots[-1]
	var wall_x := P.pos.x + 3.0      # (he was moved 3m back from a spot right at the rock)
	step(m, 0.25)
	var past := float(copy["pos"].x)
	ok("net: the copy flies past the rock", past > wall_x + 1.0, "x %.1f, rock %.1f" % [past, wall_x])

func _glow_and_chime() -> void:
	var r := setup("ostra", 12.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: OstraKit = P.ak
	aim_at(P, r[2].pos)
	_fire_after(m, P, K, 0.0)
	var looks := KitLooks.of(m)
	ok("glow: none right after a shot", not looks.holding("os_charge"), "charge %.2f" % K.charge)
	var chimes := K.full_chimes
	var sizes: Array = []
	K.last_shot_t = m.time
	for t in 8:
		step(m, 0.2)
		if looks.holding("os_charge"):
			sizes.append((looks.held["os_charge"]["n"] as Node3D).scale.x)
	ok(
		"glow: at his hand, it grows with the charge", sizes.size() >= 4 and sizes[-1] > sizes[0] * 2.0, str(sizes)
	)
	ok(
		"glow: it sits on his hand",
		(looks.held["os_charge"]["n"] as Node3D).global_position.distance_to(P.ak.hand_pos(true)) < 0.05
	)
	ok("chime: once on reaching full", K.full_chimes == chimes + 1, "%d" % (K.full_chimes - chimes))
	step(m, 1.0)
	ok("chime: not again while it waits", K.full_chimes == chimes + 1)
	await done(m)

## The charge lives on a copy of the weapon: an upgrade re-bases it, and the kit hands back what it was given.
func _weapon_kept() -> void:
	var r := setup("ostra", 12.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: OstraKit = P.ak
	step(m, 0.1)
	var plain := float(K.base_wpn["dmg"])
	var up := Data.weapon_stats("tether_lantern")
	up["dmg"] = plain * 2.0
	P.wpn = up
	K.last_shot_t = m.time
	step(m, 0.1)
	ok("weapon: an upgrade becomes the new plain orb", absf(float(P.wpn["dmg"]) - plain * 2.0) < 0.01)
	K.last_shot_t = m.time - 2.0
	step(m, 0.1)
	ok("weapon: ...and the charge builds on it", float(P.wpn["dmg"]) > plain * 2.5, "%.1f" % float(P.wpn["dmg"]))
	K.teardown()
	ok("weapon: teardown leaves the weapon as loaded", absf(float(P.wpn["dmg"]) - plain * 2.0) < 0.01)
	await done(m)
