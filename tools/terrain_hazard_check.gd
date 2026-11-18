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
## and the body's move there (HazardMoves): every hunter in deep water swims, one without footing on ice says so,
## a warded one doesn't,
## and the sounds: HazardSfx (a contact cue per kind, heard only in range, one gasp before drowning, the warded cue
## once per kind, the beds placed at the nearest ground and capped) and HazardMoveSfx (a splash going in and out of
## deep water, a stroke per swim arm stroke, a catch when ice footing returns, a rival's quieter),
## plus the HUD's underfoot reading, the Boki's hint near one (risk or safe, naming it), and bots: they
## keep off a hazard their Boki can't handle (a path round the lava) and walk through one it can.
## and the maps: HazardMap shows each area (minimap on a hold or once one is near, full map always) in its kind's
## colours from the rules, and paints without error round and square; the full map's key (MapKey) lists
## the kinds. Steps the real match at Match.DT; never touches the save. Prints "TERRAIN ..." lines and
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
		await _sounds()
		await _move_sounds()
		_bots()
		_map()
	print("TERRAIN CHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

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
	var spd := P.slow_mult(0.65) * (1.35 if P.haste_t > 0.0 else 1.0)
	var hits := TerrainHazards.hit_mult(m, P)
	ok("deep water %s: the hunter swims" % _who(safe), HazardMoves.of(P) == HazardMoves.SWIM, str(HazardMoves.of(P)))
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
	var want := HazardMoves.NONE if safe else HazardMoves.FOOTING
	ok("ice %s: %s" % [_who(safe), "sure footing" if safe else "no footing (short stride, arms out)"],
		HazardMoves.of(P) == want, str(HazardMoves.of(P)))
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

# ------------------------------------------------------------------ the minimap and the full map
var painted := 0

func _map() -> void:
	ok("the minimap lists the hazards as a detail kind", "hazard" in MapDetail.DETAIL)
	ok("every area keeps its outline and box for the maps",
		tz.areas.all(func(a): return (a["poly"] as PackedVector2Array).size() >= 3 and (a["box"] as Rect2).has_area()))
	var tint := tz.areas.all(func(a):
		var look: Dictionary = a["def"]["look"]
		return HazardMap.edge(a["kind"]).is_equal_approx(Color(Color(String(look["edge"])), HazardMap.EDGE_A)) \
			and HazardMap.fill(a["kind"]).a == HazardMap.FILL_A)
	ok("area colours come from the rules' look", tint)
	var kinds := {}
	for a in tz.areas:
		kinds[HazardMap.fill(a["kind"])] = true
	ok("each hazard kind has its own tint", kinds.size() == COUNTER.size(), str(kinds.size()))
	P = m.player
	var keyed := MapKey.kinds(m, TrainMap.new())
	ok("the full map's key has a row per hazard kind",
		tz.areas.all(func(a): return ("hz:" + String(a["kind"])) in keyed), ", ".join(keyed))
	var guarded := tz.areas.any(func(a): return tz.guards(P, String(a["kind"])))
	ok("and the shield row only when your Boki counters one", ("safe" in keyed) == guarded)
	var home := P.pos
	_stand(0)
	ok("the minimap shows hazards once one is close", HazardMap.matters(m))
	var far := false
	for x in range(0, m.world.w, 8):
		P.pos = Vector3(x, home.y, m.world.h * 0.5)
		far = far or not HazardMap.matters(m)
	ok("and not when none is within %d m" % int(HazardMap.NEAR_M), far)
	P.pos = home
	var c := Control.new()
	main.add_child(c)
	c.draw.connect(func():
		var to_screen := func(p3: Vector3) -> Vector2: return Vector2(p3.x, p3.z) * 2.0
		var inner := Rect2(Vector2.ZERO, Vector2(m.world.w, m.world.h) * 2.0)
		HazardMap.draw(c, m, to_screen, inner, Vector3.ZERO, HazardMap.FULL_SHIELD)
		var disc := Vector3(inner.size.x * 0.5, inner.size.y * 0.5, 300.0)
		HazardMap.draw(c, m, to_screen, inner, disc, HazardMap.MM_SHIELD)
		painted += 1)
	c.queue_redraw()
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok("the areas paint on a square and a round map", painted > 0, str(painted))
	c.queue_free()

# ------------------------------------------------------------------ sounds (HazardSfx)
## Stands the player fresh on the area and starts listening there.
func _listen(ai: int) -> void:
	_stand(ai)
	Sfx.last_played.clear()
	Sfx.recent.clear()
	Sfx.listener = P.pos

func _sounds() -> void:
	var R := HazardSfx.play_rules()
	_kin(PLAIN)
	for kind in COUNTER:
		if not R["kinds"][kind].has("contact"):
			continue
		var cue := String(R["kinds"][kind]["contact"])
		_listen(_first(kind))
		if kind == "static":
			tz.areas[_first(kind)]["t"] = 0.6
			tz.areas[_first(kind)]["phase"] = "idle"
		await _run(1.0 if kind == "static" else 0.1)
		ok("%s without: its contact cue plays (%s)" % [kind, cue], Sfx.last_played.has(cue),
			str(Sfx.last_played.keys()))
	_listen(_first("lava"))
	Sfx.listener = P.pos + Vector3(60, 0, 0)
	await _run(0.1)
	ok("the lava burn tick is positional: 60 m off it is out of earshot", not Sfx.last_played.has("hazard_lava_burn"))
	_listen(_first("deep_water"))
	var gasps := 0
	var gasp_t := -1.0
	var hurt_t := -1.0
	var t := 0.0
	while t < float(TerrainHazards.kind_def("deep_water")["effect"]["breath_s"]) + 1.5:
		m.step(Match.DT)
		t += Match.DT
		if Sfx.last_played.has("hazard_breath"):
			Sfx.last_played.erase("hazard_breath")
			gasps += 1
			gasp_t = t
		if hurt_t < 0.0 and P.hp < P.max_hp: hurt_t = t
	ok("deep water without: one gasp before it starts to drown", gasps == 1 and gasp_t < hurt_t,
		"%d gasps at %.1f s, drowning at %.1f s" % [gasps, gasp_t, hurt_t])
	tz.audio.warded.clear()
	_kin(COUNTER["lava"])
	_listen(_first("lava"))
	await _run(0.2)
	var first := Sfx.last_played.has("hazard_warded") and not Sfx.last_played.has("shield")
	_listen(_first("lava"))
	await _run(0.2)
	ok("warded: a soft cue the first time the Boki keeps the lava off, not again", first
		and not Sfx.last_played.has("hazard_warded"), str(Sfx.last_played.keys()))
	_kin(PLAIN)
	_beds()

## The beds: the lava's sounds from its nearest ground, louder 2 m off its edge than 10 m off; none far
## from every area; never more than beds_max at once, standing anywhere.
func _beds() -> void:
	var au := tz.audio
	var ai := _first("lava")
	var edge := Vector3.ZERO
	var out := Vector3.ZERO
	for q: Vector2i in tz.areas[ai]["cells"]:
		var dry := 0
		for k in range(1, 11):
			var west := Vector2i(q.x - k, q.y)
			if not m.world.inb(west.x, west.y) or tz.cell[m.world.idx(west.x, west.y)] != 0: break
			dry += 1
		var at := Vector3(q.x + 0.5, float(tz.areas[ai]["y"]), q.y + 0.5)
		if dry < 10:
			continue
		au.scan(at + Vector3(-10, 0, 0))
		if au.beds.has(ai) and (au.beds[ai] as Vector3).distance_to(at) < 1.5:
			edge = at
			out = Vector3(-1, 0, 0)
			break
	ok("a lava edge with nothing of it nearer than 10 m off its west side", out != Vector3.ZERO)
	var vols := []
	for d in [10.0, 2.0]:
		Sfx.listener = edge + out * d
		au.scan(Sfx.listener)
		au.scan_t = 1.0
		au.tick(0.0)
		var L: Dictionary = Sfx.loops.get("hazard_bed%d" % ai, {})
		var at: Vector3 = au.beds.get(ai, Vector3.INF)
		var off := Vector2(at.x - Sfx.listener.x, at.z - Sfx.listener.z).length()
		var placed: bool = tz.area_at(at) == ai and off <= d + 1.0
		vols.append((L["p"] as AudioStreamPlayer).volume_db if placed and not L.is_empty() else -99.0)
	ok("the lava bed sounds from its nearest ground, louder 2 m off than 10 m", vols[0] > -99.0 and vols[1] > vols[0],
		"%.1f dB -> %.1f dB" % vols)
	var most := 0
	var quiet := false
	for x in range(4, m.world.w - 4, 6):
		for z in range(4, m.world.h - 4, 6):
			au.scan(Vector3(x + 0.5, 0, z + 0.5))
			most = maxi(most, au.beds.size())
			quiet = quiet or au.beds.is_empty()
	ok("the beds: silent far from every area, at most %d at once anywhere" % int(HazardSfx.play_rules()["beds_max"]),
		quiet and most >= 1 and most <= int(HazardSfx.play_rules()["beds_max"]), "most %d" % most)
	au.beds.clear()

# ------------------------------------------------------------------ the moves' sounds (HazardMoveSfx)
## Runs the real frames for secs and returns what the player's pose found: the strokes counted, every sound played.
func _hear(secs: float) -> Dictionary:
	Sfx.last_played.clear()
	Sfx.recent.clear()
	var strokes := 0
	var bits := 0
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		P.render(Match.DT, 1.0)
		await main.get_tree().process_frame
		var c := P.anim.hz_cues
		strokes += 1 if c & HazardMoveSfx.STROKE else 0
		bits |= c
		t += Match.DT
	return {"strokes": strokes, "bits": bits, "heard": Sfx.last_played.keys()}

## The volume of the sound Sfx played last (its pool voice).
func _last_db() -> float:
	return Sfx.players[(Sfx.next - 1 + Sfx.POOL) % Sfx.POOL].volume_db

func _move_sounds() -> void:
	_kin(PLAIN)
	_listen(_first("deep_water"))
	var r := await _hear(2.5)
	ok("deep water: a splash going in and a stroke splash per arm stroke (%d in 2.5 s)" % r["strokes"],
		r["bits"] & HazardMoveSfx.ENTER != 0 and r["strokes"] >= 2 and "splash" in r["heard"] and "swim" in r["heard"],
		str(r["heard"]))
	_listen(_first("ice"))
	r = await _hear(0.5)
	ok("leaving the water: a splash coming out", r["bits"] & HazardMoveSfx.EXIT != 0 and "splash" in r["heard"],
		str(r["heard"]))
	ok("ice, no footing: the skid scrape", "hazard_ice_skid" in r["heard"], str(r["heard"]))
	_kin(COUNTER["ice"])
	r = await _hear(0.5)
	ok("a frost Boki puts the footing back: a catch", r["bits"] & HazardMoveSfx.CATCH != 0
		and "hazard_catch" in r["heard"], str(r["heard"]))
	_kin(PLAIN)
	var rival: Hunter = null
	for h in m.hunters:
		if h != P:
			rival = h
			break
	ok("a rival to compare with", rival != null)
	if rival == null:
		return
	rival.render(Match.DT, 1.0)       # (builds its pose: the match's own render is off)
	var db := {}
	for who: Hunter in [P, rival]:
		Sfx.listener = who.pos
		Sfx.last_played.clear()
		Sfx.recent.clear()
		who.anim.hz_cues = HazardMoveSfx.CATCH
		HazardMoveSfx.play(who)
		db[who] = _last_db()
	ok("a rival's catch is %.0f dB quieter than yours" % -HazardMoveSfx.OTHERS_DB,
		is_equal_approx(float(db[P]) - float(db[rival]), -HazardMoveSfx.OTHERS_DB), str(db.values()))
	Sfx.listener = rival.pos + Vector3(60, 0, 0)
	Sfx.last_played.clear()
	HazardMoveSfx.play(rival)
	ok("out of earshot (60 m): no sound", Sfx.last_played.is_empty(), str(Sfx.last_played.keys()))
	rival.anim.hz_cues = 0
	P.anim.hz_cues = 0
