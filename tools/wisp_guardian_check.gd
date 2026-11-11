extends RefCounted
## --wisp-guardian-check: the guardian summon (KinGuardian, decision 0040). Wisps off: nothing happens. Wisps
## on and the summon ready: the knock bursts the Boki out beside the Hunter Wisp for its species' window
## clamped to 8-15 s, on a 6 m leash, fighting a stomper, taking +25 % damage, with no Summon key and the
## bond meter untouched. Beaten, or at the end of the window, it is a wisp on the cooldown and the hunter is
## no longer protected (the steal hook). On cooldown, nothing bursts. Revived inside the window it finishes
## it as a plain summon. The snapshot carries the flag. Prints PASS/FAIL.

const DT := 1.0 / 60.0

var bad := 0
var m: Match
var main: Node

func run(main_node: Node) -> void:
	main = main_node
	_off()
	_start(true)
	_burst()
	_clamp()
	_beaten()
	_window_end()
	_cooling()
	_revived()
	_snapshot()
	m.queue_free()
	print("GUARDCHECK %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("GUARD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _start(wisps: bool) -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 79, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": wisps})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
		h.inp["move"] = Vector2.ZERO
	_frames(0.3)

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
	for h in m.hunters:
		h.render(DT, 1.0)

func _foe() -> Hunter:
	return m.hunters.filter(func(x): return x.team != m.player.team)[0]

## Knock the player down (kept from bleeding out) with the foe far away, unless a place is given.
func _down(foe_at := Vector3.INF) -> void:
	var p: Hunter = m.player
	var foe := _foe()
	if foe_at != Vector3.INF:
		foe.pos = foe_at
		foe.prev = foe.pos
	m.knock(p, foe, {})
	p.down_hp = 1e6

func _off() -> void:
	_start(false)
	_down()
	var k: Kin = m.player.kin
	ok(not k.wisp and not k.summon.guardian and not KinGuardian.protecting(m.player),
		"off: wisps off, the knock summons nothing")

func _burst() -> void:
	var p: Hunter = m.player
	var k: Kin = p.kin
	var s := k.summon
	var ult0 := p.ult
	var near: Vector3 = p.pos + Vector3(2.0, 0, 0)
	var foe := _foe()
	var foe_hp := foe.hp
	_down(near)
	ok(p.downed and not k.wisp and s.guardian and k.state == "active" and KinGuardian.protecting(p),
		"knock with the summon ready: the Boki bursts out as the guardian")
	ok(absf(s.left - 8.0) < 0.01, "...for its species' window, clamped to 8-15 s (%.1f s)" % s.left)
	ok(k.flat_dist(p) < 4.0, "...beside the Hunter Wisp (%.1f m)" % k.flat_dist(p))
	ok(not KinSummon.press(p), "...no Summon key while downed")
	ok(absf(k.brain.leash() - 6.0) < 0.01, "...on a 6 m leash (%.1f)" % k.brain.leash())
	k.hp = k.max_hp
	k.hurt(10.0, null)
	ok(absf(k.max_hp - k.hp - 12.5) < 0.2, "...takes +25 %% damage (%.1f for 10)" % (k.max_hp - k.hp))
	k.hp = k.max_hp
	k.render(DT, 1.0)
	var rings := m.fx.radial
	m.time += 1.0
	k.render(DT, 1.0)
	ok(m.fx.radial > rings, "...a white guardian ring pulses on the ground")
	_frames(3.0)
	ok(foe.hp < foe_hp or k.target == foe, "...it fights the stomper at the Hunter Wisp")
	ok(p.ult >= ult0, "...the bond meter is not spent")
	ok(s.cd == 0.0 and s.left > 4.0, "...the cooldown starts when the window ends, not before")

func _clamp() -> void:
	for pair in [[5.0, 8.0], [10.0, 10.0], [20.0, 15.0]]:
		_start(true)
		var s: KinSummon = m.player.kin.summon
		s.dur = pair[0]
		_down()
		ok(absf(s.left - pair[1]) < 0.01, "window: a %.0f s summon guards for %.0f s" % [pair[0], pair[1]])

func _beaten() -> void:
	_start(true)
	var p: Hunter = m.player
	var k: Kin = p.kin
	_down()
	k.hurt(k.max_hp * 5.0, null)
	var unprotected := not k.summon.guardian and not KinGuardian.protecting(p)
	ok(k.wisp and p.downed and unprotected and absf(k.summon.cd - 75.0) < 0.01,
		"beaten: back to a wisp (75 s cooldown), the Hunter is no longer protected")

func _window_end() -> void:
	_start(true)
	var p: Hunter = m.player
	var k: Kin = p.kin
	_down()
	k.summon.left = 0.1
	_frames(0.2)
	ok(not k.summon.guardian and not KinGuardian.protecting(p), "window end: flag clears, Hunter unprotected")
	_frames(KinSummon.SHRINK_S + 0.1)
	ok(k.wisp and absf(k.summon.cd - 60.0) < 0.5, "...it shrinks back, the full cooldown runs (%.1f s)" % k.summon.cd)

func _cooling() -> void:
	_start(true)
	var p: Hunter = m.player
	var k: Kin = p.kin
	k.summon.cd = 30.0
	_down()
	ok(k.wisp and not k.summon.guardian and k.summon.cd > 29.0, "on cooldown: nothing bursts, the wisp stays a wisp")

func _revived() -> void:
	_start(true)
	var p: Hunter = m.player
	var k: Kin = p.kin
	_down()
	m.revive_hunter(p, null)
	_frames(0.1)
	ok(not p.downed and not k.summon.guardian and k.summon.left > 0.0 and not k.wisp,
		"revived: it finishes the window beside you as a plain summon")

func _snapshot() -> void:
	_start(true)
	var p: Hunter = m.player
	var k: Kin = p.kin
	_down()
	var other: Kin = m.kins.filter(func(x: Kin): return x.owner_h != null and x != k)[0]
	var row: Array = []
	row.resize(KinNet.KIN_AT)
	KinNet.apply_kin(other, row + KinNet.kin_extra(k))
	ok(other.summon.guardian and not other.wisp, "online: the snapshot shows the guardian and its form")
