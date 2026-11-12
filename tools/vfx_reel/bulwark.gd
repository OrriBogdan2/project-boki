extends "res://tools/hero_vfx_reel.gd"
## Albert's reel (tools/hero_vfx_reel.gd, docs/decisions/0061-breaker-swing-lunge.md), every slot at the match
## camera's zoom: the hammer thrown and called back, the charged swing, the swing's lunge standing and running (its
## distance over him with the full performance overlay on), the raised shield, the aegis boop on the dummy, its Shield
## Charge into a Shield Slam, a foe driven into a rock, the 360 Smash (dash), Mending Ground (e), the Faultline hop and
## slam (r), and the thrown hammer reeled home by its rope.

const HOLD := 1.5              # s the swing is held: past full charge and its perfect window

func parts() -> Array:
	return ["throw", "charge", "swing", "shield", "boop", "bash", "wall", "dash", "e", "r", "rope"]

## Each part starts with the hammer in his hand and the shield down (the last part may have left it out).
func _hand() -> void:
	P.ak.set("mace", {})
	P.ak.set("lock_t", 0.0)
	P.ak.fx.hammer_hide()
	P.ak.fx.in_hand(true)
	P.ak.cancel_hold()

func _part_throw() -> void:
	await _reset(8.0)
	_hand()
	var tap := func(t: float):
		P.inp["fire"] = _at(t, 0.2) or _at(t, 1.5)
		_aim(home + Vector3(6.0, 0, 0))
	await _go(2.4, tap, _sheet("throw", "LMB tap: the throw, the plant under its ray, LMB again: the recall",
		[0.3, 0.38, 0.46, 0.6, 1.0, 1.55, 1.7, 1.85, 2.1]), 2.5)
	await _go(GAP)

func _part_charge() -> void:
	await _reset(2.4)
	_hand()
	var swing := func(t: float):
		P.inp["fire"] = t > 0.2 and t < 1.7
		_aim(T.pos)
	await _go(2.4, swing, _sheet("charge", "LMB held: whirl, glint, full flare, then the release: crescent and impact",
		[0.5, 0.9, 1.2, 1.35, 1.72, 1.76, 1.82, 1.95, 2.2]), 1.5)
	await _go(GAP)

func _part_shield() -> void:
	await _reset(6.0)
	_hand()
	var guard := func(t: float):
		P.inp["sec_hold"] = t > 0.15
		if _at(t, 0.2):
			P.ak.set("lock_t", 0.0)
			P.ak.press_rmb()
		_aim(T.pos)
		if _at(t, 1.2):
			var from := T.pos + Vector3(-0.6, 1.0, 0)
			m.spawn_shot(T, from, Vector2(-40, 0), 12.0, 0.3, 0.15, Color("ff6a4a"), {"kb": 0.0})
	await _go(2.2, guard, _sheet("shield", "RMB held: the shield rises, a shot blocked at 1.2 s",
		[0.25, 0.32, 0.45, 0.7, 1.25, 1.3, 1.4, 1.7, 2.1]), 2.0)
	await _go(GAP)

func _part_bash() -> void:
	await _reset(5.0)
	_hand()
	P.ak.res = 50.0          # (a full Guard: the charge ends in a Shield Slam)
	var charge := func(t: float):
		P.inp["sec_hold"] = t > 0.15
		if _at(t, 0.2):
			P.ak.set("lock_t", 0.0)
			P.ak.press_rmb()
		if _at(t, 0.5):
			P.inp["move"] = Vector2(1, 0)
			P.do_dash()
		if t > 0.55:
			P.inp["move"] = Vector2.ZERO
		_aim(T.pos)
	await _go(1.9, charge, _sheet("bash", "Shift behind the shield: the Shield Charge into a Shield Slam",
		[0.45, 0.52, 0.6, 0.7, 0.8, 0.9, 1.0, 1.15, 1.5]), 2.0)
	await _go(GAP)

func _part_wall() -> void:
	var rock := _rock()
	await _reset(7.0)
	_hand()
	P.teleport(rock - Vector3(3.3, 0, 0))
	T.teleport(rock - Vector3(1.2, 0, 0))
	var swing := func(t: float):
		T.vel = Vector3.ZERO
		if t < 1.45:
			T.teleport(rock - Vector3(1.2, 0, 0))
		P.inp["fire"] = t > 0.2 and t < 1.5
		_aim(rock - Vector3(1.2, 0, 0))
	await _go(2.6, swing, _sheet("wall", "A full swing drives a foe into a rock: Crushed, stunned",
		[1.5, 1.58, 1.66, 1.75, 1.9, 2.1, 2.4], func(): return rock - Vector3(2.0, 0, 0)), 1.0)
	await _go(GAP)

## The nearest rock tile with free ground west of it (the Crushed shots of tools/pin_bjorn_shots.gd).
func _rock() -> Vector3:
	var W = m.world
	var best := Vector3.INF
	for z in range(4, W.h - 4):
		for x in range(6, W.w - 4):
			if W.kind[W.idx(x, z)] != World.T_BLOCK or W.kind[W.idx(x + 1, z)] == World.T_VOID:
				continue
			var open := true
			for dx in range(1, 5):
				open = open and W.kind[W.idx(x - dx, z)] == World.T_GROUND
			var q := Vector3(x + 0.5, W.ground_at(x + 0.5, z + 0.5), z + 0.5)
			if open and (best == Vector3.INF or q.distance_to(home) < best.distance_to(home)):
				best = q
	return best

func _part_swing() -> void:
	Settings.v["show_fps"] = 2                 # (the full overlay: each swing's distance shows over him)
	await _reset(9.0)
	_hand()
	var stand := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 0.1 + HOLD
		_aim(T.pos)
	await _go(2.6, stand, _sheet("swing", "LMB held and let go standing: the lunge", [1.5, 1.62, 1.75, 1.9, 2.2]), 1.5)
	await _reset(12.0)
	_hand()
	P.teleport(home + Vector3(-4.0, 0, 0))
	var run := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 0.1 + HOLD
		P.inp["move"] = Vector2(1, 0) if t < 2.0 else Vector2.ZERO
		_aim(T.pos)
	await _go(2.8, run, _sheet("swing", "LMB held and let go running: further", [1.5, 1.62, 1.75, 1.9, 2.2]), 1.5)
	await _go(GAP)

func _part_boop() -> void:
	await _reset(2.3)
	_hand()
	var boop := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 1.8
		P.inp["fire"] = (t > 0.7 and t < 0.75) or (t > 1.3 and t < 1.35)
		if _at(t, 1.2):
			T.teleport(home + Vector3(2.3, 0, 0))
		_aim(home + Vector3(6.0, 0, 0))
	await _go(2.2, boop, _sheet("boop", "RMB up, LMB: the boop", [0.7, 0.75, 0.8, 0.9, 1.0, 1.35, 1.45]), 1.5)
	await _go(GAP)

func _part_r() -> void:
	await _reset(9.0, 2.6)
	_hand()
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(home + Vector3(12.0, 0, 0))
	await _go(2.6, cast, _sheet("r", "R, Faultline: the hop, the slam, the lane",
		[0.15, 0.25, 0.32, 0.4, 0.5, 0.56, 0.7, 1.0, 1.6]), 2.0)
	await _go(GAP)

func _part_rope() -> void:
	await _reset(30.0)
	_hand()
	var walk := func(t: float):
		P.inp["fire"] = t > 0.1 and t < 0.15
		P.inp["move"] = Vector2(-1, 0) if t > 0.8 and t < 3.4 else Vector2.ZERO
		_aim(home + Vector3(8.0, 0, 0))
	await _go(4.2, walk, _sheet("rope", "LMB throw, walk away: the rope reels it home",
		[0.3, 0.8, 1.6, 2.4, 2.8, 3.0, 3.2, 3.6, 4.0]), 3.0)
	await _go(GAP)
