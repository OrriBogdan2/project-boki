extends RefCounted
## --mob-damage-check: how long a Hunter lasts when they stand in a camp and never fight back. A
## Medium Hunter (classic kit, no Boki, full starting armour) at level 1 and level 5 stands still,
## first alone with each of the 7 monsters, then in each fixed camp mix Match spawns, then in each
## lair with its boss awake. Every row prints the seconds to fall, the damage per hit landed (after
## armour) and the damage per second, which is the table in docs/EXPEDITION_SPEC.md section 13.
## Health is put back after each hit and the loss is added up instead, so the Hunter never actually
## goes down and every row starts the same. Monsters are the base kind (tier 0, no region, rarity or
## mutation). Never touches the save.

const CAP := 90.0          # s: a row that hasn't felled the Hunter by then reads "> 90"
const RING := 2.5          # m from the Hunter that each monster of a camp starts at
const OPEN := 10.0         # m of flat open ground the Hunter stands in the middle of
const DRIFT := 3.0         # m a knock may carry them before they step back to where they stood
## Rows: [label, monster kinds]. Solo rows first, then the camp mixes in Match's camp spawner
## (light, normal, heavy), then the lair bosses (one kind, run in its lair).
const SOLO := ["skitter", "spitter", "brute", "warden", "bomber", "sentinel", "glimmer"]
const CAMPS := [
	["light: 2 skitter", ["skitter", "skitter"]],
	["light: spitter + skitter", ["spitter", "skitter"]],
	["light: bomber + skitter", ["bomber", "skitter"]],
	["normal: brute + skitter + bomber", ["brute", "skitter", "bomber"]],
	["normal: skitter + bomber + spitter", ["skitter", "bomber", "spitter"]],
	["normal: sentinel + 2 skitter", ["sentinel", "skitter", "skitter"]],
	["heavy: brute + spitter + skitter + sentinel", ["brute", "spitter", "skitter", "sentinel"]],
]

var bad := 0
var m: Match
var P: Hunter
var field := Vector3.INF      # where the camp rows are stood

func ok(cond: bool, what: String) -> void:
	print("MOBDMG %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## The health a level-1 and a level-5 Hunter of this class has (LevelGrowth, +6% a level).
func _hps() -> Array:
	var base := float(P.cdat["hp"])
	return [base, base * (1.0 + LevelGrowth.hp_pct(5))]

## Stands the Hunter (level 1, full armour) still among `mine` until the damage taken reaches the
## level-5 health or CAP. Health doesn't change what monsters do, so one run gives both levels:
## {t: [s to fall at level 1, at level 5], hits, dmg, dur}. A hit's damage is after armour.
func _stand(mine: Array) -> Dictionary:
	P.lvl = 1
	P.hp = P.max_hp
	P.armor = P.max_armor
	var hps := _hps()
	var home := P.pos
	var full := P.hp
	var fall := [CAP, CAP]
	var lost := 0.0
	var hits := 0
	var t := 0.0
	while t < CAP and lost < float(hps[1]):
		m.step(Match.DT)
		t += Match.DT
		if P.hp < full - 0.001:
			lost += full - P.hp
			hits += 1
			P.hp = full
			for i in 2:
				if lost >= float(hps[i]) and fall[i] >= CAP: fall[i] = t
		# knocked out of the camp: they step straight back in, as a Hunter holding it would
		if P.grounded and P.flat_dist(home) > DRIFT:
			P.teleport(home)
			P.vel = Vector3.ZERO
		for mb in mine:
			if not mb.dead: mb.camp = home       # (they never walk home: the Hunter stays in their camp)
	return {"t": fall, "hits": hits, "dmg": lost, "dur": t}

## Takes monsters off the field at once (no kill: no drops, no XP).
func _clear_now(mobs: Array) -> void:
	for mb in mobs:
		if is_instance_valid(mb) and not mb.dead:
			mb.dead = true
			mb.visible = false

func _clear(mine: Array) -> void:
	_clear_now(mine)
	for i in 90:      # (shots and blasts already on their way land on nobody's tally)
		m.step(Match.DT)
		P.hp = P.max_hp

## Open ground with no drop or wall within OPEN m, so no knock throws the Hunter into the abyss.
func _open_spot() -> Vector3:
	var w := m.world
	for c in w.camp_spots.map(func(x): return x["pos"]) + range(400).map(func(_i): return w.random_ground()):
		var clear := true
		for i in 24:
			for rr in [OPEN * 0.5, OPEN]:
				var q: Vector3 = c + Vector3(cos(TAU * i / 24.0), 0, sin(TAU * i / 24.0)) * rr
				var step := absf(w.ground_at(q.x, q.z) - w.ground_at(c.x, c.z))
				if w.is_void(q.x, q.z) or w.is_block(q.x, q.z) or step > 0.5:
					clear = false
		if clear:
			return Vector3(c.x, w.ground_at(c.x, c.z), c.z)
	return Vector3.INF

func _camp(kinds: Array) -> Array:
	var at := field
	P.teleport(at)
	P.vel = Vector3.ZERO
	var mine: Array = []
	for i in kinds.size():
		var a := TAU * float(i) / float(kinds.size())
		var mb := m.spawn_mob(String(kinds[i]), at + Vector3(cos(a), 0, sin(a)) * RING)
		mb.camp = at
		mine.append(mb)
	return mine

func _boss(L: Dictionary) -> Array:
	var b: Boss = L["boss_mob"]
	_clear_now(L["guards"])
	if L["state"] == "sealed": m.lairs.open(L, P, "dial")
	var at: Vector3 = L["c"] + Vector3(L["out"].x, 0, L["out"].y) * 3.0
	P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	P.vel = Vector3.ZERO
	m.lairs.wake(L, P)
	b.awake_t = 0.0
	b.enraged = false
	return [b]

func _boss_rest(L: Dictionary) -> void:
	_clear_now(L["adds"])
	var b: Boss = L["boss_mob"]
	b._clear_attack()
	b.hazards.clear()
	b.flying.clear()
	b.waves.clear()
	b.awake_t = 0.0
	b.enraged = false
	for i in 90:
		m.step(Match.DT)
		P.hp = P.max_hp

func _secs(t: float) -> String:
	return "> %d" % int(CAP) if t >= CAP - 0.01 else "%.1f" % t

func _row(label: String, start: Callable, rest: Callable) -> Dictionary:
	var mine: Array = start.call()
	var r := _stand(mine)
	rest.call(mine)
	var hps := _hps()
	var per_hit := float(r["dmg"]) / maxf(1.0, float(r["hits"]))
	var per_s := float(r["dmg"]) / float(r["dur"])
	print("MOBDMG row %s | level 1 (%.0f hp) %s s | level 5 (%.0f hp) %s s | %.1f per hit | %.1f per s"
		% [label, hps[0], _secs(r["t"][0]), hps[1], _secs(r["t"][1]), per_hit, per_s])
	return r

func run(main: Node) -> void:
	main.set_meta("mob_damage_check", self)
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true, "blight": false})
	m.set_process(false)
	_clear_now(m.mobs.filter(func(mb): return not (mb is Boss)))
	for k in m.kins.duplicate():
		m.kins.erase(k)
		k.queue_free()
	P = m.player
	P.kin = null
	P.reclass("medium", "")
	P.set_arch("")
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h != P: h.teleport(m.world.random_ground())
	field = _open_spot()
	ok(field != Vector3.INF and m.lairs != null, "a map with %.0f m of open ground and lairs" % OPEN)
	var rows := {}
	for k in SOLO:
		rows[k] = _row(k, _camp.bind([k]), _clear)
	for c in CAMPS:
		rows[c[0]] = _row(c[0], _camp.bind(c[1]), _clear)
	for L in m.lairs.list: m.lairs.activate(L)
	for bk in Data.BOSSES:
		var L: Dictionary = {}
		for x in m.lairs.list: if String(x["boss"]) == bk: L = x
		if L.is_empty():
			ok(false, "a lair with the %s" % bk)
			continue
		rows[bk] = _row(bk, _boss.bind(L), func(_mine): _boss_rest(L))

	# what has to hold whatever the numbers are
	ok(float(rows["glimmer"]["dmg"]) == 0.0, "the Glimmerkin never hurts anyone")
	var bomb: Dictionary = rows["bomber"]
	ok(int(bomb["hits"]) <= 2 and float(bomb["dmg"]) > 0.0, "a lone Puffbomb blows up once and is gone")
	for k in rows:
		if k in ["glimmer", "bomber"]: continue
		var t1 := float(rows[k]["t"][0])
		var n := int(rows[k]["hits"])
		ok(t1 < CAP and n >= 3, "%s fells a level-1 Hunter who stands in it within %d s, over 3+ hits (%.1f s, %d hits)"
			% [k, int(CAP), t1, n])
	m.queue_free()
	print("MOBDMG DONE, failures: %d" % bad)
	main.get_tree().quit()
