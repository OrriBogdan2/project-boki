extends RefCounted
## Ally dummies for the combo checks (the ally-effects parity pass). Friendly fire is off: `sweep` aims each
## slot of a hero at a teammate and lists the slots that hurt, stun, root or slow it. `spawn` is the teammate.

const AKCheck := preload("res://tools/archetype_check.gd")
const SLOTS := ["lmb", "rmb", "rmb_hold", "e", "x", "dash"]
const WATCH_S := 3.0      # seconds each slot is watched
const AIM_GAP_M := 5.0    # how far ahead the teammate stands (and is aimed at)

## A teammate of `p` at `at`: idle, 10000 hp, no armour.
static func spawn(m: Match, p: Hunter, at: Vector3) -> Hunter:
	var a: Hunter = m.make_hunter("Ally", p.team, "medium", "Ally", "idle", {}, at, {"arch": "none"})
	a.max_hp = 10000.0
	a.hp = a.max_hp
	a.armor = 0.0
	a.max_armor = 0.0
	return a

## Every slot of `arch`, one fresh match each, aimed at a teammate standing AIM_GAP_M ahead. Returns the
## offences as "slot: what", empty when the teammate is left alone.
static func sweep(main: Node, arch: String) -> Array:
	var ak := AKCheck.new()
	ak.main = main
	var bad: Array = []
	for slot in SLOTS:
		var r: Array = ak.setup(arch, 9.0)
		var m: Match = r[0]
		var p: Hunter = r[1]
		var a := spawn(m, p, r[4] + Vector3(AIM_GAP_M, 0, 0))
		for i in 5:
			m.step(AKCheck.DT)
		ak.aim_at(p, a.pos)
		_press(ak, m, p, slot)
		var cc := 0.0
		var t := 0.0
		while t < WATCH_S:
			_hold(p, slot, t)
			ak.step(m, AKCheck.DT)
			cc = maxf(cc, maxf(a.stun_t, maxf(a.root_t, a.slow_t)))
			t += AKCheck.DT
		if ak.dmg(a) > 0.0 or cc > 0.0:
			bad.append("%s %s: hurt %.1f, held %.2f s" % [arch, slot, ak.dmg(a), cc])
		await ak.done(m)
	return bad

static func _press(ak, m: Match, p: Hunter, slot: String) -> void:
	match slot:
		"lmb": p.inp["fire"] = true
		"rmb": ak.tap(m, p)
		"rmb_hold":
			p.inp["sec_hold"] = true
			p.ak.press_rmb()
		"e": p.ak.use_e()
		"x":
			p.ult = 1.0
			HunterKeys.ult_pressed(p)
		"dash": p.inp["dash"] = true

## The key stays down for a while (LMB 1 s, RMB hold 0.9 s) and the dash key for one step.
static func _hold(p: Hunter, slot: String, t: float) -> void:
	if slot == "lmb" and t > 1.0:
		p.inp["fire"] = false
	elif slot == "rmb_hold" and t > 0.9:
		p.inp["sec_hold"] = false
	elif slot == "dash" and t > 0.05:
		p.inp["dash"] = false
