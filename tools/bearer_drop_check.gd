extends RefCounted
## --bearer-drop-check: Meeko's Bearer passive (docs/heroes/tender.md). The source rule: any damage or
## stun on her drops whoever she carries, with a 4 s pickup lock. Meeko carries a downed teammate and each
## of the other 11 Hunters hits her with every slot (LMB, RMB, E, R, dash); then a mob, a Boki summon, a
## hazard (the biome traps; the match's closing ring is an abyss timer and hurts nobody) and a burn DoT
## (Cinder's Ablaze). Whatever lands damage or a stun must have dropped the carry on that same frame.
## Prints BEARER PASS/FAIL.

const DT := 1.0 / 60.0
const WINDOW := 2.5      # seconds each slot gets to land something
const HOLD := 1.0        # seconds a held button stays down
const TAP := 0.03        # a tap: one frame
const LOCK_MIN := 3.8    # the 4 s lock, a few frames after the drop

var main: Node
var sc               # the support check's strip setup (tools/support_check.gd)
var fails := 0
var n := 0
var hit_slots := 0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("BEARER %-52s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	sc = load("res://tools/support_check.gd").new()
	sc.main = mn
	for arch in Arch.ids():
		if arch != "tender":
			await _hunter(arch)
	await _extras()
	ok("slots that landed damage or a stun were exercised", hit_slots >= 20, "%d slots landed" % hit_slots)
	print("BEARER DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Meeko (T) on the far team carrying a downed teammate (A), `arch` (P) three metres off.
func _setup(arch: String, kin := "") -> Array:
	var r: Array = sc.setup(arch, 2.5, kin)
	var T: Hunter = r[3]
	T.set_arch("tender")
	T.unlock_all()
	r[2].team = T.team
	return r

## A fresh carry: Meeko whole and unlocked, her teammate downed beside her and picked up.
func _carry(m: Match, r: Array) -> void:
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var T: Hunter = r[3]
	var K: TenderKit = T.ak
	T.max_hp = 10000.0
	T.hp = T.max_hp
	T.armor = 0.0
	T.max_armor = 0.0
	T.stun_t = 0.0
	T.root_t = 0.0
	T.burn_t = 0.0
	T.teleport(P.pos + Vector3(2.5, 0, 0))
	T.vel = Vector3.ZERO
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	P.fire_cd = 0.0
	P.reload_t = 0.0
	P.ammo = maxi(P.ammo, 1)
	P.stun_t = 0.0
	P.hp = P.max_hp
	if P.ak:
		for k in P.ak.cd:
			P.ak.cd[k] = 0.0
	K.lock_t = 0.0
	if not A.downed:
		sc.down(m, A)
	A.teleport(T.pos + Vector3(0.5, 0, 0))
	for i in 12:
		m.step(DT)
		if not K.carrying().is_empty():
			break
	sc.aim_at(P, T.pos)

## Steps up to WINDOW seconds with `press` held. Returns what Meeko took first: "" (nothing), "drop"
## (dropped on the frame it landed, lock set) or "bypass" (hurt or stunned and still carrying).
func _watch(m: Match, r: Array, press: Callable) -> String:
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var K: TenderKit = T.ak
	var hp0 := T.hp
	var spot := T.pos
	var t := 0.0
	while t < WINDOW:
		press.call(t)
		if T.flat_dist(spot) > 0.05 and T.stun_t <= 0.0:      # (Meeko drifts off the strip's edge: keep her in reach)
			T.teleport(spot)
		sc.aim_at(P, T.pos)
		m.step(DT)
		t += DT
		if T.hp < hp0 - 0.001 or T.stun_t > 0.0:
			if _dropped(K):
				return "drop"
			return "bypass"
	return ""

func _dropped(K: TenderKit) -> bool:
	return K.carrying().is_empty() and K.lock_t >= LOCK_MIN

func _slot(m: Match, r: Array, slot: String) -> String:
	var P: Hunter = r[1]
	_carry(m, r)
	var press: Callable
	match slot:
		"LMB": press = func(t): P.inp["fire"] = t < HOLD      # held, then let go (bows and swords fire on release)
		"RMB": press = func(t):
			P.inp["sec"] = t < TAP
			P.inp["sec_hold"] = t < HOLD
		"E": press = func(t): P.inp["sig"] = t < TAP or absf(t - 0.5) < TAP      # tap, tap again (thrown E's)
		"R": press = func(t): if t < TAP: HunterKeys.ult_pressed(P)
		_: press = func(t):
			P.inp["dash"] = t < TAP
			P.inp["move"] = Vector2(1, 0)
	var res := _watch(m, r, press)
	for k in ["fire", "sec", "sec_hold", "sig", "dash"]:
		P.inp[k] = false
	P.inp["move"] = Vector2.ZERO
	return res

func _hunter(arch: String) -> void:
	var r := _setup(arch)
	var m: Match = r[0]
	var seen := []
	for slot in ["LMB", "RMB", "E", "R", "dash"]:
		var res: String = await _slot(m, r, slot)
		await main.get_tree().process_frame
		if res != "":
			hit_slots += 1
		seen.append("%s:%s" % [slot, res if res != "" else "-"])
		ok("%s %s: damage or stun on Meeko drops the carry, 4 s lock" % [arch, slot], res != "bypass", res)
	print("BEARER %s  %s" % [arch, " ".join(seen)])
	m.queue_free()
	await main.get_tree().process_frame

## A mob, a Boki summon, a biome hazard and a DoT: sources that are not a Hunter's slot.
func _extras() -> void:
	var r := _setup("ashwick", "cindle")
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var K: TenderKit = T.ak
	_carry(m, r)
	var mb := m.spawn_mob("skitter", T.pos + Vector3(0.9, 0, 0))
	mb.team = P.team + 9
	var res := _watch(m, r, func(_t): pass)
	mb.queue_free()
	m.mobs.erase(mb)
	ok("a mob's attack drops the carry, 4 s lock", res == "drop", res)
	_carry(m, r)
	T.hurt(8.0, P.kin, {"src": "kin", "tags": ["kin", "melee"]})
	ok("a Boki's hit drops the carry, 4 s lock", _dropped(K), "lock %.1f" % K.lock_t)
	_carry(m, r)
	T.hurt(3.0, null, {"src": "hazard", "tags": ["mut", "hazard"]})
	ok("a hazard's hit (no attacker) drops the carry", _dropped(K), "lock %.1f" % K.lock_t)
	_carry(m, r)
	(P.ak as AshwickKit).stoke(T)
	ok("Ablaze: the burn is on her", T.burn_t > 0.0 and T.burn_dps > 0.0)
	res = _watch(m, r, func(_t): pass)
	ok("Ablaze: the burn's damage drops the carry, 4 s lock", res == "drop", res)
	m.queue_free()
	await main.get_tree().process_frame
