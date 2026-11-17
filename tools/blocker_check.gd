extends "res://tools/hero_pair_check.gd"
## --blocker-check: every crosser fired at every blocker, asserting the one rule in content/rules/blockers.json
## (Blockers, docs/ABILITIES.md "Blockers and crossers"). A flat strip: the shooter at home, a blocker on a line
## LINE m ahead and a target FAR m ahead behind it. Albert's raised shield and Kael's Riposte guard are bodies:
## for those the target is the blocker itself, LINE + 1 m ahead. Every blocker and crosser is the real one
## (its kit's own constructor or cast), except the shared shot, which is the projectile every weapon fires.
## Lines: PAIRCHECK <crosser> vs <blocker> PASS|FAIL  want <stop|pass>, got <stop|pass>; then BLOCKER DONE.

const LINE := 3.0            # m from the shooter to the blocker's line
const FAR := 6.0             # m from the shooter to the target behind a line blocker
const SHOT_SPEED := 30.0     # m/s of the shared test shot
const MOVED := 0.5           # m a pull or knock has to move the target to count as passing

var A: Hunter = null         # the owner of the placed blockers (the target's side)

func run(main_node: Node) -> void:
	main = main_node
	for c in Blockers.CROSSERS:
		await _crosser(String(c))
	print("BLOCKER DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _crosser(c: String) -> void:
	var r := setup(String(Blockers.CROSSERS[c]["arch"]), FAR)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	A = m.make_hunter("A", T.team, "medium", "Owner", "idle", {}, home + Vector3(0, 0, -6.0), {"arch": "none"})
	for b in Blockers.KINDS:
		var want := Blockers.stops(c, b)
		if want == Blockers.NA:
			continue
		var got := await _try(m, P, T, home, c, b)
		ok("%s vs %s" % [c, b], (got == "stop") == (want == Blockers.STOP), "want %s, got %s" % [want, got])
		_clear(m, P, T, home)
	await done(m)

## Puts the blocker up and fires the crosser; "stop" or "pass".
func _try(m: Match, P: Hunter, T: Hunter, home: Vector3, c: String, b: String) -> String:
	var X := T
	var line := home + Vector3(LINE, 0, 0)
	match b:
		"shield", "guard":
			X = _body(m, b, home + Vector3(LINE + 1.0, 0, 0), P)
			T.teleport(home + Vector3(0, 0, 6.0))
		"rock":
			HeroZones.rock(m, A, line, Vector2.RIGHT, "blk", 4.0, 60.0, 9999.0)
		"wall":
			var glove: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/gear/barrier.json"))
			var e: Dictionary = (glove["effects"] as Array)[0].duplicate()
			e["hp"] = 9999.0
			m.verbs.add_wall(A, line, Vector2.RIGHT, e, 1.0)
		"ice":
			_ice(m, home, line)
	step(m, 0.3, func(): _hold(X))
	return await _fire(m, P, X, home, c)

func _fire(m: Match, P: Hunter, X: Hunter, home: Vector3, c: String) -> String:
	var hp0 := X.hp
	var x0 := X.pos.x
	aim_at(P, X.pos)
	match c:
		"shot":
			m.spawn_shot(P, P.pos + Vector3(0, 1.0, 0), Vector2.RIGHT * SHOT_SPEED, 10.0, 0.5, 0.2, Color.WHITE)
		"hand":
			tap(m, P)
		"beam":
			P.ak.cast_e()
		"chain":
			P.ak.cast_e()
		"cloak":
			X.teleport(home + Vector3(LINE + 1.0, 0, 0))
			step(m, 0.05, func(): _hold(X))
			x0 = X.pos.x
			P.ak.cast_e()
		"trade":
			P.inp["dash_down"] = true
			P.ak.on_dash(false)
			step(m, 0.2, func():
				P.inp["dash_down"] = true
				_hold(X))
			P.inp["dash_down"] = false
		"fissure":
			P.ak._start_ult()
		"knock":
			if X == m.get_meta("blk_body", null):
				X.hurt(1.0, P, {"src": "abil", "ab": "lmb", "kb": Vector2.RIGHT * 14.0})
			else:
				X.teleport(home + Vector3(LINE - 1.2, 0, 0))
				x0 = X.pos.x
				X.hurt(1.0, P, {"src": "abil", "ab": "lmb", "kb": Vector2.RIGHT * 14.0})
				step(m, 1.0, func(): _hold(X))
				return "pass" if X.pos.x > home.x + LINE + 0.2 else "stop"
		"dash", "phase":
			P.teleport(home + Vector3(LINE - 1.4, 0, 0))
			P.inp["move"] = Vector2.RIGHT
			aim_at(P, home + Vector3(FAR + 4.0, 0, 0))
			P.do_dash()
			step(m, 1.5 if c == "phase" else 0.6, func(): P.inp["move"] = Vector2.RIGHT)
			P.inp["move"] = Vector2.ZERO
			return "pass" if P.pos.x > home.x + LINE + 0.3 else "stop"
	step(m, 2.2, func(): _hold(X))
	var moved := absf(X.pos.x - x0) > MOVED
	var hurt := X.hp < hp0 - 0.5
	if c == "trade":
		return "pass" if P.pos.x > home.x + LINE + 0.5 else "stop"
	if c in ["hand", "chain", "cloak"]:
		return "pass" if moved or (c == "chain" and P.ak.warchain.target == X) else "stop"
	return "pass" if hurt else "stop"

## Albert with the aegis raised at the shooter, or Kael in his Riposte guard.
func _body(m: Match, b: String, at: Vector3, P: Hunter) -> Hunter:
	var arch := "bulwark" if b == "shield" else "juggernaut"
	var B: Hunter = m.make_hunter("B", A.team, "heavy", "Blocker", "idle", {}, at, {"arch": arch})
	B.set_arch(arch)
	B.max_hp = 10000.0
	B.hp = B.max_hp
	B.armor = 0.0
	B.max_armor = 0.0
	aim_at(B, P.pos)
	m.step(DT)
	if b == "shield":
		(B.ak as BulwarkKit)._raise()
	else:
		(B.ak as JuggernautKit).riposte.start()
	m.set_meta("blk_body", B)
	return B

## Keeps a body blocker up for the whole try: the guard's clock held at its start, the shield's hp full.
func _hold(X: Hunter) -> void:
	if X.ak is JuggernautKit and (X.ak as JuggernautKit).riposte.guarding():
		(X.ak as JuggernautKit).riposte.st["t"] = 0.0
	elif X.ak is BulwarkKit and not (X.ak as BulwarkKit).wall.is_empty():
		(X.ak as BulwarkKit).wall["hp"] = 9999.0

## Neve's Rink Wall raised by her own kit, stopped where it rose and moved onto the line.
func _ice(m: Match, home: Vector3, line: Vector3) -> void:
	var at := home + Vector3(0, 0, -8.0)
	var N: Hunter = m.make_hunter("N", A.team, "light", "Neve", "idle", {}, at, {"arch": "rimewright"})
	N.set_arch("rimewright")
	var K: RimewrightKit = N.ak
	K._raise_wall(Vector2.RIGHT, 0.0)
	K.wall["sliding"] = false
	var w: Dictionary = K.wall["w"]
	var half := ((w["b"] as Vector2) - (w["a"] as Vector2)) * 0.5
	w["a"] = Vector2(line.x, line.z) - half
	w["b"] = Vector2(line.x, line.z) + half
	w["hp"] = 9999.0
	w["touch"] = {}
	m.set_meta("blk_ice", N)

func _clear(m: Match, P: Hunter, T: Hunter, home: Vector3) -> void:
	for s in m.shots.duplicate():
		m._shot_end(s, s["pos"], null)
	for w in m.verbs.walls.duplicate():
		m.verbs._break_wall(w)
	for key in ["blk_body", "blk_ice"]:
		var b = m.get_meta(key, null)
		if b is Hunter and is_instance_valid(b):
			m.hunters.erase(b)
			b.queue_free()
		m.set_meta(key, null)
	step(m, 1.5)
	for k in P.ak.cd.keys(): P.ak.cd[k] = 0.0
	P.dashes = P.max_dashes()
	P.teleport(home)
	P.vel = Vector3.ZERO
	T.teleport(home + Vector3(FAR, 0, 0))
	fresh(T)
	fresh(P)
	step(m, 0.3)
