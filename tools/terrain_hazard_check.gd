extends RefCounted
## --terrain-hazard-check: the Hollow Crown's terrain hazard areas (TerrainHazards,
## content/rules/terrain_hazards.json, docs/decisions/0060-terrain-hazards.md). One real match (seed 5);
## for each hazard kind the player stands in its first area twice, with a Boki that doesn't counter it
## (Vespyx, venom) and with one that does, and the check asserts:
##   lava        burns (hp drops, burn on)              / ember: no burn, no damage
##   deep_water  slowed, weaker hits, drowns after its breath / swimmer: hasted, full hits, no drowning
##   ice         low grip, a push slides far             / frost: full grip, it stops short
##   static      the next shock hurts and stuns          / storm: no damage, no stun
##   bramble     slowed and scratched                    / bloom: neither
## the ward rule (content/rules/terrain_hazards.json "ward"): the best single protection applies, no
## doubling. Every kind (the five grounds and the four biome traps) with none / its perk / its Boki / both,
## a carried second Boki, a downed Boki and a Fusion; the grounds also in play with both.
## plus the HUD's underfoot reading, the Boki's hint near one (risk or safe, naming it), and bots: they
## keep off a hazard their Boki can't handle (a path round the lava) and walk through one it can.
## Steps the real match at Match.DT; never touches the save. Prints "TERRAIN ..." lines and
## "TERRAIN CHECK DONE, N checks, failures: F".

const COUNTER := {"lava": "cindowary", "deep_water": "lilybara", "ice": "floenatee", "static": "kestrike",
	"bramble": "heatherhorn"}
const PLAIN := "cindle"          # venom: counters none of them
var main: Node
var m: Match
var tz: TerrainHazards
var P: Hunter
var n := 0
var fails := 0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("TERRAIN %-66s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	# a grown Boki (level 12, trust 95) talks in full lines, so its hint names the hazard
	await m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 5, "no_drop": true, "demo_kin": PLAIN,
		"demo_kin_lv": "12:95"})
	m.set_process(false)
	tz = TerrainHazards.of(m)
	ok("the Hollow Crown has its hazard areas", tz != null and tz.areas.size() >= 5, str(tz.areas.size() if tz else 0))
	if tz != null:
		for kind in COUNTER:
			var ai := _first(kind)
			ok("%s: an area on the map" % kind, ai >= 0)
			if ai < 0: continue
			for safe in [false, true]:
				_kin(COUNTER[kind] if safe else PLAIN)
				match kind:
					"lava": await _lava(ai, safe)
					"deep_water": await _deep_water(ai, safe)
					"ice": await _ice(ai, safe)
					"static": await _static(ai, safe)
					"bramble": await _bramble(ai, safe)
				var hud_safe: Variant = tz.underfoot(P).get("safe", null)
				ok("%s %s: the HUD reads it (safe = %s)" % [kind, _who(safe), safe], hud_safe == safe)
				_hint(kind, safe)
		await _stack()
		_bots()
	print("TERRAIN CHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

# ------------------------------------------------------------------ the ward rule
func _stack() -> void:
	var W: Dictionary = TerrainHazards.rules()["ward"]
	var trap_of := {}
	for trap in W["traps"]: trap_of[W["traps"][trap]] = trap
	var perk_of := {}
	for id in Data.PERKS:
		if Data.PERKS[id].has("ward"): perk_of[Data.PERKS[id]["ward"]] = id
	ok("one ward perk per trap kind, four in all", perk_of.size() == 4 and trap_of.size() == 4, str(perk_of.keys()))
	for kind in COUNTER:
		var perk: String = perk_of.get(trap_of.get(kind, ""), "")
		var has_perk := perk != ""
		var got := []
		for combo in ["none", "perk", "boki", "both"]:
			_kin(COUNTER[kind] if combo in ["boki", "both"] else PLAIN)
			P.perks = [perk] if has_perk and combo in ["perk", "both"] else []
			var expect: bool = (combo in ["perk", "both"] and has_perk) or combo in ["boki", "both"]
			got.append(TerrainHazards.shield(P, kind))
			ok("%s %s: protected = %s" % [kind, combo, expect], TerrainHazards.guards(P, kind) == expect)
			if has_perk and expect and combo != "boki":
				ok("%s %s: its trap kind is warded too" % [kind, combo], BiomeRun.warded(P, String(trap_of[kind])))
		var best_single: bool = got[3] == maxf(got[1], got[2]) and got[3] <= 1.0
		ok("%s: both counts once, the best single (shield %s)" % [kind, got], best_single)
		P.perks = [perk] if has_perk else []
		var ai := _first(kind)
		await _both(kind, ai)
	_kin(PLAIN)
	P.perks = []
	var rec: Dictionary = (P.kin as Kin).rec.duplicate()
	rec["species"] = COUNTER["ice"]
	var other := Kin.new()
	other.init_kin(m, "ward_check_k2", COUNTER["ice"], rec, P)
	m.add_child(other)
	other.bench()
	P.kin2 = other
	ok("a carried second Boki of the counter type adds nothing", not TerrainHazards.guards(P, "ice"))
	_kin(COUNTER["ice"])
	ok("with the counter out and a second one carried it counts once", TerrainHazards.shield(P, "ice") == 1.0)
	P.kin2 = null
	other.queue_free()
	_kin(COUNTER["ice"])
	var was: String = (P.kin as Kin).state
	(P.kin as Kin).state = "downed"
	ok("a downed counter Boki protects nothing", not TerrainHazards.guards(P, "ice"))
	(P.kin as Kin).state = "fused"
	ok("a Fusion keeps its counter", TerrainHazards.guards(P, "ice"))
	(P.kin as Kin).state = was
	P.perks = []

## Both a perk and the counter Boki on the ground itself behave exactly as one of them does (no twice-over).
func _both(kind: String, ai: int) -> void:
	if ai < 0: return
	_kin(COUNTER[kind])
	match kind:
		"lava": await _lava(ai, true)
		"deep_water": await _deep_water(ai, true)
		"ice": await _ice(ai, true)
		"static": await _static(ai, true)
		"bramble": await _bramble(ai, true)

# ------------------------------------------------------------------ setup
func _first(kind: String) -> int:
	for ai in tz.areas.size():
		if tz.areas[ai]["kind"] == kind: return ai
	return -1

func _who(safe: bool) -> String:
	return "with its counter" if safe else "without"

## The player's active Boki becomes this species (its type is what counters a hazard).
func _kin(species: String) -> void:
	P = m.player
	var k := P.kin as Kin
	k.species = species
	k.sp = Data.KIN[species]

## Stands the player still on the area's middle tile, fresh (full hp, no statuses, breath full).
func _stand(ai: int) -> void:
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var cells: Array = tz.areas[ai]["cells"]
	var c: Vector3 = tz.areas[ai]["centre"]
	var mid := Vector2(c.x - 0.5, c.z - 0.5)
	var best: Vector2i = cells[0]
	for q in cells:
		if Vector2(q).distance_to(mid) < Vector2(best).distance_to(mid):
			best = q
	P.teleport(Vector3(best.x + 0.5, float(tz.areas[ai]["y"]), best.y + 0.5))
	P.vel = Vector3.ZERO
	P.hp = P.max_hp
	for k in ["burn_t", "slow_t", "slow_k", "stun_t", "haste_t", "cc_immune_t"]: P.set(k, 0.0)
	P.dr.clear()
	tz.state.clear()

func _run(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT
	await main.get_tree().process_frame

# ------------------------------------------------------------------ one per hazard
func _lava(ai: int, safe: bool) -> void:
	_stand(ai)
	await _run(2.0)
	var lost := P.max_hp - P.hp
	if safe:
		ok("lava with an ember Boki: no burn, no damage", P.burn_t <= 0.0 and lost < 0.5, "lost %.1f" % lost)
	else:
		ok("lava without: it burns (hp drops 10+)", P.burn_t > 0.0 and lost >= 10.0, "lost %.1f" % lost)

func _deep_water(ai: int, safe: bool) -> void:
	_stand(ai)
	await _run(0.3)
	var spd := P.slow_mult() * (1.35 if P.haste_t > 0.0 else 1.0)
	var hits := TerrainHazards.hit_mult(m, P)
	await _run(float(TerrainHazards.kind_def("deep_water")["effect"]["breath_s"]) + 1.5)
	var lost := P.max_hp - P.hp
	if safe:
		ok("deep water with a swimmer: swims faster, full hits, never drowns",
			spd > 1.2 and is_equal_approx(hits, 1.0) and lost < 0.5,
			"speed x%.2f hits x%.2f lost %.1f" % [spd, hits, lost])
	else:
		ok("deep water without: slowed, weaker hits, drowns past its breath", spd < 0.7 and hits < 0.7 and lost >= 5.0,
			"speed x%.2f hits x%.2f lost %.1f" % [spd, hits, lost])

func _ice(ai: int, safe: bool) -> void:
	_stand(ai)
	await _run(0.1)
	var g := m.ground_grip(P.pos, P)
	var from := P.pos
	P.vel = Vector3(5.0, 0, 0)
	await _run(0.5)
	var slid := Vector2(P.pos.x - from.x, P.pos.z - from.z).length()
	if safe:
		ok("ice with a frost Boki: full footing, a push stops short", is_equal_approx(g, 1.0) and slid < 1.0,
			"grip %.2f slid %.2f m" % [g, slid])
	else:
		ok("ice without: low footing, a push slides on", g < 0.3 and slid > 1.2, "grip %.2f slid %.2f m" % [g, slid])

func _static(ai: int, safe: bool) -> void:
	_stand(ai)
	tz.areas[ai]["t"] = 0.6       # the next shock lands in a moment
	tz.areas[ai]["phase"] = "idle"
	var stunned := false
	var t := 0.0
	while t < 1.0:
		m.step(Match.DT)
		t += Match.DT
		stunned = stunned or P.stun_t > 0.0
	var lost := P.max_hp - P.hp
	if safe:
		ok("static with a storm Boki: the shock does nothing", lost < 0.5 and not stunned, "lost %.1f" % lost)
	else:
		ok("static without: the shock hurts and stuns", lost >= 5.0 and stunned,
			"lost %.1f stunned %s" % [lost, stunned])

func _bramble(ai: int, safe: bool) -> void:
	_stand(ai)
	await _run(2.0)
	var spd := P.slow_mult()
	var lost := P.max_hp - P.hp
	if safe:
		ok("bramble with a bloom Boki: not slowed, not scratched", is_equal_approx(spd, 1.0) and lost < 0.5,
			"speed x%.2f lost %.1f" % [spd, lost])
	else:
		ok("bramble without: slowed and scratched", spd < 0.7 and lost >= 3.0, "speed x%.2f lost %.1f" % [spd, lost])

# ------------------------------------------------------------------ the Boki's hint
## Just off the area's edge, the (grown) Boki names it and says whether it can handle it.
func _hint(kind: String, safe: bool) -> void:
	var ai := _first(kind)
	var cells: Array = tz.areas[ai]["cells"]
	var c: Vector3 = tz.areas[ai]["centre"]
	var at: Vector3 = Vector3(cells[0].x + 0.5, c.y, cells[0].y + 0.5)
	P.teleport(at + (at - c).normalized() * 2.5)
	tz.state.clear()
	tz.hinted.clear()
	m.bubbles.clear()
	tz._hint()
	var said: Dictionary = m.bubbles.back() if not m.bubbles.is_empty() else {}
	var want := "hazard_safe" if safe else "hazard_risk"
	var txt := String(said.get("text", ""))
	var filled := txt != "" and not "%" in txt
	var label := "%s %s: the Boki says %s, a grown line, hazard named" % [kind, _who(safe), want]
	ok(label, said.get("cat", "") == want and filled, txt)

# ------------------------------------------------------------------ bots
## A bot whose Boki can't handle lava walks round the field; one whose Boki can walks straight over it.
func _bots() -> void:
	var ai := _first("lava")
	var cells: Array = tz.areas[ai]["cells"]
	var mid: int = (tz.areas[ai]["centre"] as Vector3).z
	var x0 := 99999
	var x1 := -99999
	for q in cells:
		if q.y == mid:
			x0 = mini(x0, q.x)
			x1 = maxi(x1, q.x)
	var a := Vector2i(x0 - 3, mid)        # 3 tiles off the field's west edge, on its middle row
	var b := Vector2i(x1 + 3, mid)
	var bot: Hunter = null
	for h in m.hunters:
		if h != P and h.kin is Kin:
			bot = h
			break
	ok("a bot with a Boki to test with", bot != null)
	if bot == null: return
	bot.teleport(Vector3(a.x + 0.5, float(tz.areas[ai]["y"]), a.y + 0.5))
	for safe in [false, true]:
		var k := bot.kin as Kin
		k.species = COUNTER["lava"] if safe else PLAIN
		k.sp = Data.KIN[k.species]
		var path: Array = m.bot_brain._grid_path(m, a, b, bot)
		var through := 0
		var info := "%d steps, %d on lava"
		for p in path:
			if tz.cell[m.world.idx(int(p.x), int(p.y))] == ai + 1: through += 1
		if safe:
			ok("a bot with an ember Boki walks straight over the lava", not path.is_empty() and through > 0,
				info % [path.size(), through])
		else:
			ok("a bot without paths round the lava", not path.is_empty() and through == 0,
				info % [path.size(), through])
		var d := Vector2(b.x - a.x, 0).normalized()
		var guard := "ignores" if safe else "steers off"
		ok("its edge guard %s the lava ahead" % guard, m.bot_brain._safe(m, bot, d, 3.5) == safe)
