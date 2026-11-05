extends "res://tools/hero_pair_check.gd"
## Ostra's charged orb (item 60, for --ostra-combo-check; docs/heroes/ostra.md): the wait between shots charges
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
	var k := K.orb_k
	var shots0 := P.shot_n
	P.fire_cd = 0.0
	step(m, 0.05, func(): P.inp["fire"] = P.shot_n == shots0)
	P.inp["fire"] = false
	var mine: Array = m.shots.filter(func(s): return s["by"] == P)
	var sd: Dictionary = mine[-1]
	return {"s": sd, "k": k, "skin": _skin_of(m, sd)}

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
		var glass := ((skin["n"] as Node3D).get_node("Spin") as MeshInstance3D).material_override as ShaderMaterial
		var rim: Color = glass.get_shader_parameter("rim")
		rows.append({
			"wait": w, "k": f["k"], "dmg": sd["dmg"], "r": sd["r"], "speed": (sd["vel"] as Vector2).length(),
			"scale": (skin["n"] as Node3D).scale.x, "bright": rim.get_luminance()
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
		"charge: capped after the window",
		float(at[6.0]["dmg"]) == float(at[1.4]["dmg"]) and float(at[6.0]["scale"]) == float(at[1.4]["scale"])
	)
	var mids: Array = rows.filter(func(q): return float(q["wait"]) > 0.6 and float(q["wait"]) < 1.4)
	ok(
		"charge: smooth, not a switch (each step inside the window sits between plain and full)",
		mids.size() == 3 and float(mids[0]["dmg"]) > base and float(mids[2]["dmg"]) < float(at[1.4]["dmg"])
			and float(mids[0]["dmg"]) < float(mids[1]["dmg"]) and float(mids[1]["dmg"]) < float(mids[2]["dmg"])
	)
	ok(
		"charge: the drawn orb's scale tracks the hit size",
		rows.all(func(q): return absf(float(q["scale"]) - float(q["r"]) / float(rows[0]["r"])) < 0.001)
			and float(at[1.4]["scale"]) >= 1.5,
		"x%.2f" % float(at[1.4]["scale"])
	)
	await done(m)

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
		T.slow_t > 0.5 and absf(T.slow_k - float(K.lmb_def()["full_slow"])) < 0.001, "slow %.2f" % T.slow_t
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
	for w in [0.6, 1.0, 1.4]:
		fresh(T)
		var f := _fire_after(m, P, K, w)
		step(m, 0.6)
		var want := float(f["s"]["dmg"])
		ok(
			"walls: an orb at charge %.2f passes the rock and hits the dummy" % float(f["k"]),
			absf(dmg(T) - want) < 0.5, "took %.1f of %.1f" % [dmg(T), want]
		)
	P.teleport(Vector3(float(wx) - 0.45, P.pos.y, P.pos.z))
	aim_at(P, T.pos)
	fresh(T)
	_fire_after(m, P, K, 0.6)
	step(m, 0.6)
	ok("walls: fired pressed against the rock, a plain orb still passes", dmg(T) > 5.0, "took %.1f" % dmg(T))
	# the copy another game draws flies through walls too
	var shots0 := m.shots.size()
	m._net_ev(["s", P.pos.x, P.pos.y + 1.0, P.pos.z, 30.0, 0.0, 0.3, 0.28, "c070ff", 0.0, 2, 2], "peer")
	ok(
		"walls: a shot sent with kind 2 keeps pierce_terrain on the other side",
		m.shots.size() == shots0 + 1 and bool((m.shots[-1]["x"] as Dictionary).get("pierce_terrain", false))
	)
	await done(m)

func _glow_and_chime() -> void:
	var r := setup("ostra", 12.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: OstraKit = P.ak
	aim_at(P, r[2].pos)
	_fire_after(m, P, K, 0.0)
	var looks := KitLooks.of(m)
	ok("glow: none right after a shot", not looks.holding("os_charge"), "charge %.2f" % K.orb_k)
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
