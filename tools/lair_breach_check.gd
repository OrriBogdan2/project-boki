extends RefCounted
## --lair-breach-check: breaking a lair's gate down (LairBreach). Every shipped lair's way in is its Gate
## Seal (no dial lectern). Damage cracks it in stages: each drops its blocks, opens its crack, calls guards
## and counts down on the label. Walking away keeps the cracks (it knits back only after
## LairBreach.MEND_IDLE s, and never past its last crack). A lit rune knocks a share off it instead of
## opening the gate. Breaking it opens the gate. Then bots break seals down on their own, timed: one bot
## alone (real commitment, far longer than the dial's 6.5 s pressed perfectly) and a squad of three (much
## faster). Never touches the save.

const SOLO_MIN := 45.0  # s: a lone bot must take at least this long (a perfect dial took 6.5 s)
const SOLO_MAX := 240.0  # s: ... and still get in (it fights the guards each crack calls, too)
const SQUAD_K := 0.6  # a squad of three takes at most this share of the lone bot's time

var bad := 0
var m: Match
var keep: Array = []


func ok(cond: bool, what: String) -> void:
	print("BREACH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _run(sec: float) -> void:
	var t := 0.0
	while t < sec:
		for h in keep:
			h.hp = h.max_hp
			if h.downed:
				m.revive_hunter(h, h)
			if h.kin and h.kin.state == "downed":  # (a bot's rescue run would stall the timing)
				KinDowned.come_round(h.kin, true)
		m.step(Match.DT)
		t += Match.DT


func _spot(h: Hunter, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	h.vel = Vector3.ZERO


func _gate_is(l: Dictionary, tile: int) -> bool:
	return (l["gate_tiles"] as Array).all(func(q): return m.world.kind[m.world.idx(q.x, q.y)] == tile)


func _clear_guards(l: Dictionary) -> void:
	for g in l["guards"]:
		if is_instance_valid(g) and not g.dead:
			g.dead = true
			g.visible = false


## Bots in `crew` go and break `L`'s seal from a few metres off; returns seconds from the first hit
## to the gate opening (-1 if it didn't open within `limit`).
func _bots_break(l: Dictionary, crew: Array, limit: float) -> float:
	var out := Vector3(l["out"].x, 0, l["out"].y)
	var side := Vector3(-out.z, 0, out.x)
	for i in crew.size():
		var h: Hunter = crew[i]
		h.ctrl = "bot"
		h.lvl = maxi(h.lvl, 8)
		h.ai["boss_hunt"] = true
		_spot(h, LairBreach.stand(l) + out * 5.0 + side * (i - 1) * 1.5)
	keep = crew
	var seal: Mob = m.lairs.breach.seal_of(l)
	var t0 := -1.0
	var t := 0.0
	while t < limit and l["state"] == "sealed":
		_run(0.25)
		t += 0.25
		if t0 < 0.0 and seal.hp < seal.max_hp:
			t0 = m.time
	print(
		(
			"BREACH  %s: %.0f%% broken after %.0f s, crew goals %s"
			% [l["name"], LairBreach.done_k(seal) * 100.0, t, str(crew.map(func(h): return h.ai.get("goal_kind", "")))]
		)
	)
	for h in crew:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.inp["fire"] = false
	return m.time - t0 if l["state"] == "open" and t0 >= 0.0 else -1.0


func run(main: Node) -> void:
	main.set_meta("lair_breach_check", self)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true, "blight": false})
	m.set_process(false)
	var p: Hunter = m.player
	for h in m.hunters:
		h.ctrl = "idle" if h != p else "local"
		h.inp["move"] = Vector2.ZERO
	var by_boss := {}
	for l in m.lairs.list:
		m.lairs.activate(l)
		by_boss[l["boss"]] = l
	# ---------------------------------------------------------------- 1. every shipped lair: a seal, no dial
	var maps_ok := true
	for path in ["res://content/maps/skyreach.json", "res://content/maps/hollowcrown.json"]:
		var lay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for d_v in lay.get("lairs", []):
			if not (d_v["entry"] as Array).has("breach") or (d_v["entry"] as Array).has("dial"):
				maps_ok = false
	var gw := World.new()
	gw.generate(5, 128, 16)
	for d_v in gw.lair_defs:
		if not (d_v["entry"] as Array).has("breach"):
			maps_ok = false
	gw.free()
	ok(maps_ok, "Skyreach, Hollowcrown and generated maps all break their gates down (no dial)")
	var seals: Array = m.lairs.list.map(func(l): return m.lairs.breach.seal_of(l))
	var no_dial: bool = m.lairs.list.all(func(l): return l["nodes"]["dial"] == null)
	ok(
		seals.all(func(s): return s != null and s.mkind == "gate") and no_dial,
		(
			"each of the %d lairs has its Gate Seal at the gate (%s health at tier 0) and no dial lectern"
			% [seals.size(), str(seals.map(func(s): return int(s.max_hp)))]
		)
	)
	# -------------------------------------------------- 2. a crack: blocks fall, guards come, the label counts
	var f: Dictionary = by_boss["colossus"]
	var seal: Mob = m.lairs.breach.seal_of(f)
	_clear_guards(f)
	keep = [p]
	_spot(p, LairBreach.stand(f))
	_run(0.2)
	var pr: Dictionary = m.lairs.interact_for(p)
	ok(String(pr.get("what", "")) == "breach", 'at the seal the prompt says so: "%s"' % String(pr.get("label", "")))
	var g0: int = m.lairs._guards_alive(f)
	seal.hurt(seal.max_hp * 0.3, p, {"src": "shot"})
	_run(0.1)
	var slab: Node3D = seal.model.get_node("Slab")
	var lbl: Label3D = f["nodes"]["label"]
	var cracked: bool = slab.get_node("Crack1").visible and not slab.get_node("Crack2").visible
	ok(
		int(f["seal_stage"]) == 1 and cracked and not slab.get_node("B30").visible,
		"30%% down: the first crack opens and its block falls (stage %d)" % int(f["seal_stage"])
	)
	var g1: int = m.lairs._guards_alive(f)
	ok(g1 >= g0 + LairBreach.STAGE_GUARDS, "the crack calls guards (%d -> %d)" % [g0, g1])
	ok(lbl.text.contains("30%"), 'the label counts it: "%s"' % lbl.text.replace("\n", " / "))
	ok(f["state"] == "sealed" and _gate_is(f, World.T_BLOCK), "the gate stays shut")
	# -------------------------------------------------- 3. walk away: nothing resets; the mend stops at the crack
	_clear_guards(f)
	_spot(p, f["c"] + Vector3(f["out"].x, 0, f["out"].y) * 30.0)
	var hp0 := seal.hp
	_run(LairBreach.MEND_IDLE - 2.0)
	ok(
		is_equal_approx(seal.hp, hp0),
		"away %d s: the seal hasn't healed (%.0f of %.0f)" % [int(LairBreach.MEND_IDLE - 2.0), seal.hp, seal.max_hp]
	)
	_run(40.0)
	var cap := seal.max_hp * (1.0 - 1.0 / LairBreach.STAGES)
	ok(
		seal.hp > hp0 and seal.hp <= cap and int(f["seal_stage"]) == 1 and slab.get_node("Crack1").visible,
		(
			"left alone it knits back only to its last crack (%.0f%% broken, floor %.0f%%)"
			% [LairBreach.done_k(seal) * 100.0, 100.0 / LairBreach.STAGES]
		)
	)
	# -------------------------------------------------- 4. lit runes knock shares off instead of opening the gate
	var e: Dictionary = by_boss["serpent"]
	var es: Mob = m.lairs.breach.seal_of(e)
	_clear_guards(e)
	for rn in e["runes"]:
		m.lairs._light_rune(e, rn, p)
	_run(0.1)
	ok(
		e["state"] == "sealed" and absf(LairBreach.done_k(es) - LairBreach.SHARE * e["runes"].size()) < 0.02,
		(
			"all %d runes lit: the Eyrie's seal %.0f%% down, the gate still shut"
			% [e["runes"].size(), LairBreach.done_k(es) * 100.0]
		)
	)
	_clear_guards(e)
	es.hp = es.max_hp
	# ---------------------------------------------------------------- 5. the last crack breaks it and the gate opens
	_spot(p, LairBreach.stand(f))
	seal.hurt(seal.hp + 1.0, p, {"src": "shot"})
	_run(0.2)
	ok(
		f["state"] == "open" and seal.dead and _gate_is(f, World.T_GROUND),
		"broken: the gate is %s and walkable" % f["state"]
	)
	_clear_guards(f)
	# -------------------------------------------------- 6. bots break seals down; a squad much faster than one
	var mates: Array = m.hunters.filter(func(x): return x.team == p.team and x != p)
	var rivals: Array = m.hunters.filter(func(x): return x.team != p.team)
	_spot(p, f["c"])  # (out of the way: inside the open lair)
	var solo := _bots_break(by_boss["brood"], [mates[0]], 300.0)
	var squad := _bots_break(e, rivals.slice(0, 3), 160.0)
	print("BREACH times: one bot %.1f s, three bots %.1f s (tier 0; seal %d health)" % [solo, squad, int(es.max_hp)])
	ok(
		solo >= SOLO_MIN and solo <= SOLO_MAX,
		"one bot alone breaks the Thornhive's seal in %.0f s (%d-%d)" % [solo, int(SOLO_MIN), int(SOLO_MAX)]
	)
	ok(
		squad > 0.0 and squad <= solo * SQUAD_K,
		"three bots break the Eyrie's in %.0f s (at most %.0f%% of one bot's)" % [squad, SQUAD_K * 100.0]
	)
	m.over = true
	print("BREACH ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	main.get_tree().quit()
