extends RefCounted
## --friendly-fire-check: the source rule (docs/KIT_PARITY.md, "Friendly fire"): a Hunter's abilities never
## hurt their own team or the caster, and a world explosion (a powder keg) hurts everyone.
##   1. each of the 12 kits' LMB, RMB (tap and hold), E, R (the hunter ult, JSON slot x), X (the Boki Fuse)
##      and dash, with a foe, a teammate and the caster all inside the effect (once aimed at the foe,
##      once aimed at the caster's own feet): the teammate and the caster take 0 damage; the teammate
##      also no stun, root, slow or burn (a kit may plant its own caster)
##   2. each damaging glove, the same way
##   3. a powder keg hurts the caster, a teammate and a foe alike
## Prints FFCHECK PASS/FAIL and a DONE line.

var main: Node
var ac: RefCounted
var fails := 0
var n := 0
var taken := {}        # body -> damage it took in this case (CombatBus.hit_landed)
var foe_hit := 0       # cases where the foe took damage, so a case that cast nothing doesn't pass by silence
var dry: Array = []    # cases where the foe took none (the cast did not reach it): listed so the gap is visible
const DT := 1.0 / 60.0
const HP := 10000.0
const RECAST_S := 0.6   # s: a second press of E or R after this long, for the kits that pop or release on it
const HOLD_S := 3.0     # how long a cast is watched (fuses, charges and delayed blasts included)
const ALLY_SIDE := 0.7  # m: the teammate stands this far beside the foe
const SLOTS := ["lmb", "rmb_tap", "rmb_hold", "e", "fuse", "ult", "dash"]
const ARCHS := [
	"archer", "ashwick", "bulwark", "dolm", "dredge", "gunslinger",
	"juggernaut", "mage", "ostra", "rimewright", "tender", "thief",
]

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	if not cond:
		fails += 1
		print("FFCHECK %-58s FAIL  %s" % [label, info])

func run(main_node: Node) -> void:
	main = main_node
	Game.god = false     # mod mode turns god on: the keg row needs the caster mortal
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main_node
	for arch in ARCHS:
		for slot in SLOTS:
			for feet in [false, true]:
				await _cast(arch, slot, feet, "")
	for gid in _damaging_gloves():
		for feet in [false, true]:
			await _cast("gunslinger", "glove", feet, gid)
	await _keg()
	print("FFCHECK DONE %d checks, failures: %d, foe damaged in %d cases" % [n, fails, foe_hit])
	print("FFCHECK foe not damaged (cast did not reach it): %s" % ", ".join(dry))
	main.get_tree().quit(1 if fails > 0 else 0)

func _damaging_gloves() -> Array:
	var out: Array = []
	for gid in Gear.ALL:
		var effects := JSON.stringify(Gear.ALL[gid].get("effects", []))
		if Gear.is_glove(gid) and Gear.active(gid) and effects.contains("\"dmg\""):
			out.append(gid)
	return out

## A foe, a teammate (a step beside it) and the caster, then one cast. `feet`: aim at the caster's own feet
## with all three packed close, else at the foe a few metres out.
func _cast(arch: String, slot: String, feet: bool, glove: String) -> void:
	var r: Array = ac.setup(arch, 3.0, "cindle" if slot == "fuse" else "")
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var A := _ally(m, P, T.pos + Vector3(0, 0, ALLY_SIDE))
	if feet:
		T.teleport(home + Vector3(1.4, 0, 0))
		A.teleport(home + Vector3(1.0, 0, 1.0))
		ac.aim_at(P, home + Vector3(0.6, 0, 0))
	for i in 3: m.step(DT)
	taken = {A: 0.0, P: 0.0, T: 0.0}
	CombatBus.hit_landed.connect(_on_hit)
	var what := glove if glove != "" else arch
	var label := "%s %s %s" % [what, slot, "feet" if feet else "foe"]
	_press(m, P, slot, glove)
	ac.step(m, RECAST_S, func(): _keep(P, slot))
	if slot == "e":         # (a recast pops Brimseed, detonates a Sigil)
		P.ak.use_e()
	elif slot == "ult":
		P.ak.cast_ult()
	ac.step(m, HOLD_S - RECAST_S, func(): _keep(P, slot))
	_release(P)
	ac.step(m, 0.3)
	CombatBus.hit_landed.disconnect(_on_hit)
	for e in [A, P]:
		var who := "teammate" if e == A else "caster"
		ok("%s: %s takes no damage" % [label, who], float(taken[e]) <= 0.0, "%.1f taken" % float(taken[e]))
		var held: float = e.stun_t
		if e == A:
			held += e.root_t + e.slow_t      # (a kit may plant its own caster)
		ok("%s: %s takes no stun, root, slow or burn" % [label, who], held <= 0.0 and e.burn_t <= 0.0,
			"stun %.2f root %.2f slow %.2f burn %.2f" % [e.stun_t, e.root_t, e.slow_t, e.burn_t])
	if float(taken[T]) > 0.0:
		foe_hit += 1
	else:
		dry.append(label)
	m.queue_free()
	await main.get_tree().process_frame

func _tough(e: Hunter) -> void:
	e.max_hp = HP
	e.hp = HP
	e.armor = 0.0
	e.max_armor = 0.0

## A teammate of the caster, with a health pool no kit can empty.
func _ally(m: Match, P: Hunter, at: Vector3) -> Hunter:
	var A: Hunter = m.make_hunter("A", P.team, "medium", "Ally", "idle", {}, at, {"arch": "none"})
	_tough(A)
	return A

func _on_hit(_by: Node, target: Node, amount: float, tags: Array) -> void:
	if taken.has(target) and not tags.has("heat"):      # (an overheated glider burns whoever is gliding)
		taken[target] += amount

func _press(m: Match, P: Hunter, slot: String, glove: String) -> void:
	var K: ArchKit = P.ak
	for k in K.cd:
		K.cd[k] = 0.0
	P.ult = 1.0
	match slot:
		"lmb": P.inp["fire"] = true
		"rmb_tap", "rmb_hold":
			P.inp["sec_hold"] = slot == "rmb_hold"
			K.press_rmb()
		"e": K.use_e()
		"fuse": ac.merge_now(P)
		"ult": K.cast_ult()
		"dash": P.do_dash()
		"glove":
			P.gear[0] = {"id": glove, "rar": 1}
			P.gear_cd[0] = 0.0
			m.use_gear(P, 0)

func _keep(P: Hunter, slot: String) -> void:
	if slot == "lmb" or slot == "ult":      # (an X that arms the weapon: Starpiercer)
		P.inp["fire"] = true
	elif slot == "rmb_hold":
		P.inp["sec_hold"] = true

func _release(P: Hunter) -> void:
	P.inp["fire"] = false
	P.inp["sec_hold"] = false

## A world explosion has no team: the caster who lit it, a teammate and a foe all inside it are hurt.
func _keg() -> void:
	var r: Array = ac.setup("gunslinger", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var A := _ally(m, P, home + Vector3(0, 0, 1.0))
	for e in [P, T]:
		_tough(e)
	var ex: Dictionary = Breakables.spec("keg")["explosive"]
	var spot := home + Vector3(0.8, 0, 0.5)
	T.teleport(spot + Vector3(0.8, 0, 0))
	m._add_break("keg", spot)
	var before := [P.hp, A.hp, T.hp]
	m.brk.hit(m.breaks[-1], P)
	ac.step(m, float(ex["fuse"]) + 0.3)
	ok("keg: the caster who lit it is hurt", P.hp < before[0], "%.1f" % P.hp)
	ok("keg: a teammate is hurt", A.hp < before[1], "%.1f" % A.hp)
	ok("keg: a foe is hurt", T.hp < before[2], "%.1f" % T.hp)
	m.queue_free()
	await main.get_tree().process_frame
