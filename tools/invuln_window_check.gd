extends "res://tools/hero_pair_check.gd"
## --invuln-window-check: every Hunter's invulnerable or shot-proof window (docs/KIT_PARITY.d/1128-invuln-windows.md).
## Per row: start the move, measure the window frame by frame (melee-proof = inv_t or Kael's guard; shot-proof adds
## phase_t), assert it against the row's `win`, then in two fresh matches hit the Hunter with one melee hit and one
## real shot: in the middle of the window both are refused, 0.1 s after it both land. A row with no window
## (`win` 0) asserts the hits land mid-move. Gil is ours and not here. Never touches the save.

const SIDE := 0.8  # m from the Hunter to the attacker at the moment of the hit
const SHOT_SPEED := 40.0  # m/s: the test shot reaches the body on its first step
const HIT := 10.0  # damage of each test hit
const AFTER := 0.1  # s past the window's end for the "outside" hits
const TOL := 0.04  # s: measured vs listed window
const MAX_T := 8.0  # s: the longest move measured
const RAMP := 0.12  # s: Albert's aegis rising before the Shield Charge (it takes 0.1 s)

## who, kit, move ("dash", "ult", "bash"), win = melee-proof s, shot = shot-proof s (both from the press).
const ROWS := [
	{"who": "Vex", "arch": "gunslinger", "move": "dash", "win": 0.117, "shot": 0.117},  # Slipstep roll (dash.invuln)
	{"who": "Kael", "arch": "juggernaut", "move": "dash", "win": 0.067, "shot": 0.067},  # Rampage
	{"who": "Kael", "arch": "juggernaut", "move": "ult", "win": 0.65, "shot": 0.65},
	{"who": "Lace", "arch": "archer", "move": "dash", "win": 0.283, "shot": 0.283},  # Spirit Walk roll
	{"who": "Cinder", "arch": "ashwick", "move": "dash", "win": 0.067, "shot": 0.067},  # Flue hop
	{"who": "Meeko", "arch": "tender", "move": "dash", "win": 0.133, "shot": 0.133},  # Foxtrot hop
	{"who": "Tenzo", "arch": "dolm", "move": "dash", "win": 0.083, "shot": 0.083},  # hop 1 only
	{"who": "Grimble", "arch": "dredge", "move": "dash", "win": 0.067, "shot": 0.067},  # Barge
	{"who": "Neve", "arch": "rimewright", "move": "dash", "win": 0.0, "shot": 0.0},  # Free Skate: none
	{"who": "Neve", "arch": "rimewright", "move": "ult", "win": 3.383, "shot": 3.383},  # Rimelock: hold + snap
	{"who": "Motley", "arch": "ostra", "move": "dash", "win": 0.0, "shot": 0.0},  # none
	{"who": "Albert", "arch": "bulwark", "move": "dash", "win": 0.117, "shot": 0.117},  # Tideturner
	{"who": "Albert", "arch": "bulwark", "move": "bash", "win": 0.35, "shot": 0.35},  # Shield Charge
	{"who": "Sparkle", "arch": "mage", "move": "dash", "win": 0.233, "shot": 0.483},  # Surge: phase runs 0.25 s on
	{"who": "Sparkle", "arch": "mage", "move": "ult", "win": 2.35, "shot": 2.35},  # Kitefall: crouch open, air proof
	{"who": "Sable", "arch": "thief", "move": "dash", "win": 0.517, "shot": 0.583},  # Vault
]


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for row in ROWS:
		await _row(row)
	print("INVULN WINDOW DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


func _row(row: Dictionary) -> void:
	var tag := "%s %s %s" % [row["who"], row["arch"], row["move"]]
	var w := await _measure(row)
	var melee_s: float = w[1] - w[0]
	var shot_s: float = w[3] - w[2]
	print("INVULN %s melee-proof %.3f-%.3f s, shot-proof %.3f-%.3f s" % [tag, w[0], w[1], w[2], w[3]])
	ok(tag + " melee-proof length", absf(melee_s - float(row["win"])) <= TOL, "%.3f vs %.3f" % [melee_s, row["win"]])
	ok(tag + " shot-proof length", absf(shot_s - float(row["shot"])) <= TOL, "%.3f vs %.3f" % [shot_s, row["shot"]])
	var mid_m: float = (w[0] + w[1]) * 0.5 if melee_s > 0.0 else 0.1
	var mid_s: float = (w[2] + w[3]) * 0.5 if shot_s > 0.0 else 0.1
	var hit := await _hit(row, mid_m, "melee")
	ok(tag + " melee inside", (hit > 0.0) == (melee_s <= 0.0), "took %.1f at %.3f s" % [hit, mid_m])
	hit = await _hit(row, mid_s, "shot")
	ok(tag + " shot inside", (hit > 0.0) == (shot_s <= 0.0), "took %.1f at %.3f s" % [hit, mid_s])
	var out_t: float = maxf(w[1], w[3]) + AFTER
	hit = await _hit(row, out_t, "melee")
	ok(tag + " melee outside", hit > 0.0, "took %.1f at %.3f s" % [hit, out_t])
	hit = await _hit(row, out_t, "shot")
	ok(tag + " shot outside", hit > 0.0, "took %.1f at %.3f s" % [hit, out_t])


## [melee from, melee to, shot from, shot to], s after _start: the first unbroken window of each (0, 0 = none).
func _measure(row: Dictionary) -> Array:
	var r := _start(row)
	var m: Match = r[0]
	var hn: Hunter = r[1]
	var w := [-1.0, -1.0, -1.0, -1.0]
	var t := 0.0
	while t < MAX_T and (w[1] < 0.0 or w[3] < 0.0):
		_win_edge(w, 0, t, _melee_proof(hn))
		_win_edge(w, 2, t, _melee_proof(hn) or hn.phase_t > 0.0)
		_step(m, hn)
		t += DT
	for i in [0, 2]:
		if w[i] < 0.0:
			w[i] = 0.0
			w[i + 1] = 0.0
		elif w[i + 1] < 0.0:
			w[i + 1] = MAX_T
	await done(m)
	return w


## Opens window `at` (0 or 2) on its first proof frame and closes it on the first frame after.
func _win_edge(w: Array, at: int, t: float, proof: bool) -> void:
	if proof and w[at] < 0.0:
		w[at] = t
	elif not proof and w[at] >= 0.0 and w[at + 1] < 0.0:
		w[at + 1] = t


func _melee_proof(hn: Hunter) -> bool:
	return hn.inv_t > 0.0 or (hn.ak is JuggernautKit and (hn.ak as JuggernautKit).riposte.guarding())


## Damage taken from one hit `at` s after the press, in a fresh match.
func _hit(row: Dictionary, at: float, kind: String) -> float:
	var r := _start(row)
	var m: Match = r[0]
	var hn: Hunter = r[1]
	var foe: Hunter = r[2]
	var t := 0.0
	while t < at - DT * 0.5:
		_step(m, hn)
		t += DT
	# from behind: Albert's aegis faces front and is not what this check is about
	var fwd := hn.aim_dir()
	foe.teleport(hn.pos - Vector3(fwd.x, 0, fwd.y) * SIDE)
	var hp0 := hn.hp
	if kind == "melee":
		hn.hurt(HIT, foe, {"src": "abil", "ab": "primary", "melee": true})
	else:
		var v := Vector2(hn.pos.x - foe.pos.x, hn.pos.z - foe.pos.z).normalized() * SHOT_SPEED
		m.spawn_shot(foe, foe.pos + Vector3(0, 1.0, 0), v, HIT, 0.1, 0.3, Color.WHITE, {"src": "shot"})
		m.step(DT)
		m.step(DT)
	var took := hp0 - hn.hp
	await done(m)
	return took


## A fresh match with the Hunter set up and the move pressed on its first step.
func _start(row: Dictionary) -> Array:
	var r := setup(String(row["arch"]), 12.0)
	var m: Match = r[0]
	var hn: Hunter = r[1]
	hn.max_hp = 10000.0
	hn.hp = hn.max_hp
	hn.armor = 0.0
	hn.max_armor = 0.0
	hn.shield = 0.0
	aim_at(hn, hn.pos + Vector3(0, 0, 6.0))
	match String(row["move"]):
		"ult":
			hn.ak.cd["x"] = 0.0
			hn.ak.cast_ult()
		"bash":
			hn.inp["sec_hold"] = true
			(hn.ak as BulwarkKit)._raise()
			step(m, RAMP, func(): hn.inp["sec_hold"] = true)
			_press_dash(m, hn)
		_:
			_press_dash(m, hn)
	return r


func _press_dash(m: Match, hn: Hunter) -> void:
	hn.inp["move"] = Vector2(0, 1)
	hn.inp["dash"] = true
	hn.inp["dash_down"] = true
	m.step(DT)
	hn.inp["dash"] = false
	hn.inp["dash_down"] = false


func _step(m: Match, hn: Hunter) -> void:
	if hn.ak is BulwarkKit:
		hn.inp["sec_hold"] = true
	m.step(DT)
