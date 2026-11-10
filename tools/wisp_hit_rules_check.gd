extends RefCounted
## --wisp-hit-rules-check: wisps are not in the way (DECISIONS 2026-11-09). A rival's Boki orbiting as a wisp
## and a downed rival Hunter (a Wisp) must not block, absorb or trigger a shot or an area: no damage, no
## status, no push, no pull, no hit event, and what stands behind them is hit exactly as with nothing there.
## For all 12 Hunters, LMB, RMB (tap) and E are fired at a rival's Boki wisp and over a downed rival, close and
## far, and compared with the same cast at an empty lane. The exceptions the source allows still work: Abyssal
## Hand scoops a Hunter Wisp, Mending Ground's burst starts an allied Wisp coming back, a revive stands the
## hunter up, and an execute still ends a downed rival. (Hail Wall's drain and Lightning Strike's launch of
## Wisps are not built: docs/heroes/archer.md and mage.md.) Prints WISPHIT PASS/FAIL.

const DT := 1.0 / 60.0
const NEAR := 2.5      # m to the rival: inside a melee kit's reach
const FAR := 6.0       # m to the rival: a gun's range
const SLOTS := ["lmb", "rmb", "e"]
const BOKI := "cindle"
const BLOCK_TOL := 0.9     # what share of the empty-lane damage the one behind must still take
const SLACK := 0.5         # hp: tick timing between two runs

var main: Node
var ac: RefCounted
var bad := 0
var hits: Array = []      # hit events whose target was a wisp (the Hunter Wisp or the Boki's)

func run(main_node: Node) -> void:
	main = main_node
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	CombatBus.hit_landed.connect(_on_hit)
	for arch in Arch.ids():
		await _hero(arch)
	await _loose_wisp()
	await _exceptions()
	CombatBus.hit_landed.disconnect(_on_hit)
	print("WISPHIT %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("WISPHIT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _on_hit(_by: Node, target: Node, _amount: float, _tags: Array) -> void:
	if (target is Hunter and (target as Hunter).downed) or (target is Kin and (target as Kin).wisp):
		hits.append(target)

## One Hunter: every slot, close and far, against an empty lane, a downed rival, and a rival's Boki wisp.
func _hero(arch: String) -> void:
	for d in [NEAR, FAR]:
		for slot in SLOTS:
			var tag := "[%s] %s at %.1f m" % [arch, slot, d]
			var base: Dictionary = await _cast(arch, d, slot, "empty")
			var down: Dictionary = await _cast(arch, d, slot, "downed")
			ok(not down["touched"], tag + ": a downed rival takes nothing (%s)" % down["why"])
			ok(float(down["behind"]) >= BLOCK_TOL * float(base["behind"]) - SLACK, tag + ": over a Wisp the one behind takes %.0f of %.0f" % [down["behind"], base["behind"]])
			var boki: Dictionary = await _cast(arch, d, slot, "boki")
			ok(not boki["touched"], tag + ": a rival's Boki wisp takes nothing (%s)" % boki["why"])
			ok(float(boki["behind"]) >= BLOCK_TOL * float(base["behind"]) - SLACK, tag + ": through a Boki wisp the one behind takes %.0f of %.0f" % [boki["behind"], base["behind"]])

## Fires `slot` in a fresh match (a kit's charges and cooldowns carry over) from the Hunter at `t` placed `d` m
## ahead with `t2` 2 m behind it. `mode`: "empty" (t off the lane), "downed" (t a Wisp in the lane) or "boki"
## (t, no target itself, in the lane, its Boki wisp at shoulder height over it).
## Returns {behind: what t2 took, touched: anything reached the wisp, why: what}.
func _cast(arch: String, d: float, slot: String, mode: String) -> Dictionary:
	var s: Array = ac.setup(arch, d, "", true)
	var m: Match = s[0]
	var p: Hunter = s[1]
	var t: Hunter = s[2]
	var t2: Hunter = s[3]
	var home: Vector3 = s[4]
	var k: Kin = null
	if mode == "boki":
		m.opts["boki_wisps"] = true
		k = m.give_kin(t, Save.new_kin(BOKI))
		t.riding = true      # (its owner is no target, so only the wisp is in the lane)
		ac.step(m, 0.3)
		ok(k.wisp and not k.hittable() and not (k in m.foes_of(p.team)), "[%s] the rival's Boki rides as a wisp, off every target list" % arch)
	elif mode == "downed":
		m.knock(t, p, {})
		t.down_hp = 1e6
	else:
		t.teleport(home + Vector3(d, 0, 9.0))
	ac.step(m, 0.3)
	var at := t.pos
	var aim := t2.pos + Vector3(0, 0.6, 0)      # (the lane through the wisp: a Boki wisp floats at shoulder height)
	ac.aim_at(p, aim)
	var k_hp := k.hp if k else 0.0
	hits.clear()
	match slot:
		"lmb":
			ac.step(m, 0.7, func(): p.inp["fire"] = true; ac.aim_at(p, aim))
			p.inp["fire"] = false
		"rmb":
			p.ak.cd["rmb"] = 0.0
			ac.tap(m, p)
			ac.step(m, 0.8)
		"e":
			p.ak.cd["e"] = 0.0
			p.ak.use_e()
			ac.step(m, 1.5)
	var why: Array = []
	if mode == "downed":
		var marked := not (t.get_meta("marks", {}) as Dictionary).is_empty()
		for pair in [["hp", t.hp != 0.0], ["stun", t.stun_t > 0.0], ["root", t.root_t > 0.0], ["slow", t.slow_t > 0.0],
				["burn", t.burn_t > 0.0], ["moved", t.pos.distance_to(at) > 0.05 and not (arch == "dredge" and slot == "rmb")], ["marked", marked]]:
			if pair[1]:
				why.append(pair[0])
	elif mode == "boki" and k.hp != k_hp:
		why.append("hp")
	if not hits.is_empty():
		why.append("hit event")
	var out := {"behind": ac.dmg(t2), "touched": not why.is_empty(), "why": ", ".join(why)}
	await ac.done(m)
	return out

## A downed rival's Boki wisps break loose and float: still no target.
func _loose_wisp() -> void:
	var s: Array = ac.setup("gunslinger", FAR, "", false)
	var m: Match = s[0]
	var p: Hunter = s[1]
	var t: Hunter = s[2]
	m.opts["boki_wisps"] = true
	var k: Kin = m.give_kin(t, Save.new_kin(BOKI))
	ac.step(m, 0.3)
	m.knock(t, p, {})
	KinSteal.break_loose(k, t.pos)
	ac.step(m, 0.3)
	ok(KinSteal.loose(k) and not k.hittable() and not (k in m.foes_of(p.team)), "a loose Boki wisp is no target either")
	await ac.done(m)

## What the source lets touch Wisps still works.
func _exceptions() -> void:
	var s: Array = ac.setup("dredge", 6.0, "", true)
	var m: Match = s[0]
	var p: Hunter = s[1]
	var t: Hunter = s[2]
	t.teleport(s[4] + Vector3(5.0, 0, 0))
	m.knock(t, p, {})
	t.down_hp = 1e6
	ac.step(m, 0.2)
	ac.aim_at(p, t.pos)
	ac.tap(m, p)
	ac.step(m, 1.0)
	ok(t.downed and (p.ak.scoop.has(t) or bool(p.ak.pull.get("wisp", false))), "Abyssal Hand scoops a Hunter Wisp (the source lets it)")
	m.eliminate(t, p, "executed", true)
	ok(t.out, "an execute still ends a downed rival")
	await ac.done(m)
	s = ac.setup("bulwark", 3.0, "", false)
	m = s[0]
	p = s[1]
	var mate: Hunter = m.make_hunter("M", p.team, "medium", "Mate", "idle", {}, s[4] + Vector3(1.0, 0, 0), {"arch": "none"})
	m.knock(mate, null, {})
	mate.down_hp = 1e6
	var r0 := mate.revive
	p.ak.use_e()
	ac.step(m, 4.0)
	ok(mate.revive > r0 or not mate.downed, "Mending Ground's burst starts an allied Wisp coming back")
	m.revive_hunter(mate, p)
	ok(not mate.downed, "a revive stands the hunter up")
	await ac.done(m)
