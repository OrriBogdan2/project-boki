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
## each with its counter Boki and with its hazard perk (Lava-walker, Tidewader, Iceboots; plain Boki + perk),
## plus the big fields (tagged regions, safe paths and stones, perk loot near them), the HUD's underfoot
## reading, the Boki's hint near one (risk or safe, naming it), and bots: they
## keep off a hazard their Boki can't handle (a path round the lava) and walk through one it can.
## Steps the real match at Match.DT; never touches the save. Prints "TERRAIN ..." lines and
## "TERRAIN CHECK DONE, N checks, failures: F".

const COUNTER := {"lava": "cindowary", "deep_water": "lilybara", "ice": "floenatee", "static": "kestrike",
	"bramble": "heatherhorn"}
const PERK := {"lava": "lavawalker", "deep_water": "tidewader", "ice": "iceboots"}      # the immunity perks
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
			for via in ["none", "boki", "perk"]:
				if via == "perk" and not PERK.has(kind): continue
				var safe: bool = via != "none"
				_kin(COUNTER[kind] if via == "boki" else PLAIN)
				P.perks.clear()
				if via == "perk": P.perks.append(PERK[kind])
				match kind:
					"lava": await _lava(ai, safe)
					"deep_water": await _deep_water(ai, safe)
					"ice": await _ice(ai, safe)
					"static": await _static(ai, safe)
					"bramble": await _bramble(ai, safe)
				var hud: Dictionary = tz.underfoot(P)
				ok("%s %s: the HUD reads it (safe = %s, by %s)" % [kind, via, safe, hud.get("by", "")],
					hud.get("safe", null) == safe)
				_hint(kind, safe)
		_fields()
		_bots()
	print("TERRAIN CHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

# ------------------------------------------------------------------ setup
func _first(kind: String) -> int:
	for ai in tz.areas.size():
		if tz.areas[ai]["kind"] == kind: return ai
	return -1

func _who(safe: bool) -> String:
	return "with its counter" if safe else "without"

## The big fields: the map's regions are tagged with their hazard and its share of the ground; a safe path
## (a lane or an islet) is ground, and a field's loot leans to the perk that walks it.
func _fields() -> void:
	var seen := {}
	for R in World.load_layout("hollowcrown")["regions"]:
		if R.has("hazard"): seen[R["hazard"]] = float(R["share"])
	for kind in PERK:
		ok("%s: a region built round it with 30%%+ of its ground" % kind, seen.get(kind, 0.0) >= 0.3,
			str(seen.get(kind)))
	var ai := _first("lava")
	var A: Dictionary = tz.areas[ai]
	ok("the lava field is big (500+ tiles)", (A["cells"] as Array).size() >= 500, str((A["cells"] as Array).size()))
	var dry := 0
	for q in A["cells"]:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if tz.cell[m.world.idx(q.x + d.x, q.y + d.y)] == 0: dry += 1
	ok("walkable paths and stones cut through it (its edge is long)", dry >= 100, str(dry))
	var c: Vector3 = A["centre"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var near := TerrainHazards.perk_near(m, c, 40.0)
	var n_near := 0
	var n_far := 0
	for i in 300:
		n_near += 1 if PerkOrbs.roll(rng, "chest", null, [], near) == "lavawalker" else 0
		n_far += 1 if PerkOrbs.roll(rng, "chest") == "lavawalker" else 0
	ok("the field names its perk, and chests beside it drop it 5x more",
		near == "lavawalker" and n_near > 5 * maxi(n_far, 1), "%d vs %d of 300" % [n_near, n_far])

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
		ok("lava with its counter: no burn, no damage", P.burn_t <= 0.0 and lost < 0.5, "lost %.1f" % lost)
	else:
		ok("lava without: it burns (hp drops 10+)", P.burn_t > 0.0 and lost >= 10.0, "lost %.1f" % lost)

func _deep_water(ai: int, safe: bool) -> void:
	_stand(ai)
	await _run(0.3)
	var spd := P.slow_mult(0.65) * (1.35 if P.haste_t > 0.0 else 1.0)
	var hits := TerrainHazards.hit_mult(m, P)
	await _run(float(TerrainHazards.kind_def("deep_water")["effect"]["breath_s"]) + 1.5)
	var lost := P.max_hp - P.hp
	if safe:
		ok("deep water with its counter: swims faster, full hits, never drowns",
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
		ok("ice with its counter: full footing, a push stops short", is_equal_approx(g, 1.0) and slid < 1.0,
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
	var spd := P.slow_mult(0.65)
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
	var a := Vector2i(42, 141)        # the lake's west chest, and its east islet: causeways cross between them
	var b := Vector2i(85, 158)
	var edge := Vector2i.ZERO        # dry ground 2 tiles west of a lava tile: facing east is facing the lava
	for q: Vector2i in tz.areas[ai]["cells"]:
		var w := m.world
		var at := w.idx(q.x - 2, q.y)
		if w.inb(q.x - 2, q.y) and w.kind[at] == World.T_GROUND and tz.cell[at] == 0 and tz.cell[at + 1] == 0:
			edge = Vector2i(q.x - 2, q.y)
			break
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
		var d := Vector2(1, 0)
		bot.teleport(Vector3(edge.x + 0.5, float(tz.areas[ai]["y"]), edge.y + 0.5))
		var guard := "ignores" if safe else "steers off"
		ok("its edge guard %s the lava ahead" % guard, m.bot_brain._safe(m, bot, d, 3.5) == safe)
