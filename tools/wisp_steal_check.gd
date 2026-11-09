extends RefCounted
## --wisp-steal-check: stolen Boki wisps (KinSteal, decision 0041), with Boki wisps on. A downed hunter's wisp
## breaks loose and floats; holding interact beside it grabs it (the prompt shows the key cap); the thief gets its
## carry passive at half strength (clamped) and the owner loses it; one stolen summon at half the window; at most
## two stolen wisps ("Hands full"); a thief going down scatters them; the owner takes theirs back once revived; an
## ungrabbed wisp goes home and stays; match end sends every stolen wisp home with a soul echo in the Field Book;
## the kin snapshot carries the carrier. Prints PASS/FAIL.

const DT := 1.0 / 60.0

var bad := 0
var m: Match
var main: Node

func run(main_node: Node) -> void:
	main = main_node
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
		h.inp["move"] = Vector2.ZERO
	_frames(0.3)
	_steal()
	m.queue_free()
	print("WISPSTEAL %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("WSTEAL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT

## Hold interact beside a wisp for a while (the player stays put; nothing else moves).
func _hold(h: Hunter, k: Kin, secs: float) -> void:
	h.teleport(Vector3(k.pos.x + 0.5, h.pos.y, k.pos.z))
	h.inp["interact"] = true
	_frames(secs)
	h.inp["interact"] = false

func _steal() -> void:
	var p: Hunter = m.player
	var foes: Array = m.hunters.filter(func(h: Hunter): return h.team != p.team and h.kin != null)
	var mate: Hunter = m.hunters.filter(func(h: Hunter): return h.team == p.team and h != p and h.kin != null)[0]
	foes.sort_custom(func(a: Hunter, b: Hunter): return a.kin.ks.carry_passives.size() > b.kin.ks.carry_passives.size())
	var f: Hunter = foes[0]
	var f2: Hunter = foes[1]
	var fk: Kin = f.kin
	ok(fk.wisp and fk.home_h == f and not fk.ks.carry_passives.is_empty(),
		"a rival's Boki rides as a wisp with a carry passive (%s)" % fk.species)
	var stat := String(fk.ks.carry_passives[0]["stat"])
	var amount := 0.0
	for ps in fk.ks.carry_passives:
		if ps["stat"] == stat:
			amount += float(ps["amount"])
	var mine := p.owner_stat(stat)
	var fell := f.pos
	m.knock(f, p, {})
	_frames(0.1)
	ok(KinSteal.loose(fk) and fk.owner_h == f and not fk.carried() and absf(fk.flat_dist(fell) - KinSteal.POP_M) < 0.1,
		"loose: the downed hunter's wisp breaks loose and pops off them")
	ok(fk.visible and absf(fk.pos.y - fell.y - KinWisp.SHOULDER_Y) < 0.05, "...floating at shoulder height")
	_hold(p, fk, 0.2)
	var label := String(m.interact.get("label", ""))
	ok(label.contains(Settings.key_cap("interact")) and String(m.interact.get("kind", "")) == "wisp",
		"grab: the prompt names the interact key (%s)" % label)
	ok(KinSteal.loose(fk), "...a short hold is not a grab")
	_hold(p, fk, 0.7)
	ok(KinSteal.stolen(fk) and fk.owner_h == p and fk.team == p.team and not KinSteal.loose(fk) and fk.wisp,
		"grab: held 0.6 s, the wisp rides with the thief")
	ok(int(Care.dex_entry(fk.species).get("echo", 0)) >= 1 and bool(Care.dex_entry(fk.species).get("seen", false)),
		"...a soul echo: the species is in the Field Book")
	_frames(0.1)
	var cap := float(KinParts.OWNER_STATS[stat][2])
	var want := minf(cap, mine + amount * 0.5)
	ok(absf(p.owner_stat(stat) - want) < 0.001,
		"passive: the thief gets %s at half strength, clamped (%.3f -> %.3f, want %.3f)"
		% [stat, mine, p.owner_stat(stat), want])
	m.revive_hunter(f, null)
	_frames(0.1)
	ok(not f.kin_carry_on() and f.owner_stat(stat) == 0.0, "...and its revived owner has none")
	ok(not KinSummon.press(f) and fk.wisp, "...nor its summon")
	p.kin.summon.cd = 40.0
	ok(KinSummon.press(p) and not fk.wisp and p.kin.wisp, "summon: own Boki resting, Summon bursts the stolen one")
	var win := maxf(5.0, ceilf(fk.summon.dur * 0.5))
	ok(absf(fk.summon.left - win) < 0.05 and fk.owner_h == p,
		"...for half its window, at least 5 s (%.1f s)" % fk.summon.left)
	_frames(win + KinSummon.SHRINK_S + 0.1)
	ok(fk.wisp and KinSteal.stolen(fk) and fk.stolen_summoned, "...then back to a wisp with the thief")
	ok(not KinSummon.press(p), "...one summon only")
	var f2k: Kin = f2.kin
	m.knock(f2, p, {})
	_frames(0.1)
	_hold(p, f2k, 0.7)
	ok(KinSteal.stolen(f2k) and KinSteal.count(p) == 2, "cap: a second stolen wisp")
	var mk: Kin = mate.kin
	m.knock(mate, null, {})
	_frames(0.1)
	_hold(p, mk, 0.8)
	ok(KinSteal.loose(mk) and KinSteal.count(p) == 2 and String(m.interact.get("label", "")).begins_with("Hands full"),
		"cap: a third is refused, 'Hands full'")
	var at := p.pos
	m.knock(p, null, {})
	_frames(0.1)
	var popped := absf(fk.flat_dist(at) - KinSteal.POP_M) < 0.1
	ok(KinSteal.loose(fk) and KinSteal.loose(f2k) and fk.owner_h == f and f2k.owner_h == f2 and popped,
		"scatter: the thief goes down, both wisps are loose again where they fell")
	f.teleport(Vector3(fk.pos.x + 0.5, f.pos.y, fk.pos.z))
	f.inp["interact"] = true
	_frames(0.7)
	f.inp["interact"] = false
	ok(not KinSteal.taken(fk) and fk.owner_h == f and fk.carried() and f.kin_carry_on(),
		"take back: the revived owner grabs their own wisp and its passive is theirs again")
	_frames(float(KinSteal.rules()["loose_s"]))
	ok(not KinSteal.taken(f2k) and f2k.owner_h == f2 and f2k.wisp,
		"home: ungrabbed, the wisp goes back to its downed owner")
	_frames(0.5)
	ok(not KinSteal.loose(f2k), "...and stays there")
	m.revive_hunter(p, null)
	_frames(0.1)
	m.knock(f, p, {})
	_frames(0.1)
	ok(KinSteal.grab(fk, p) and KinSteal.stolen(fk), "match end: a wisp stolen again")
	var row: Array = []
	row.resize(KinNet.KIN_AT)
	row.append_array(KinNet.kin_extra(fk))
	KinSteal.match_end(m)
	ok(not KinSteal.taken(fk) and fk.owner_h == f and fk.team == f.team,
		"match end: every stolen wisp goes home to its owner")
	KinNet.apply_kin(fk, row)
	ok(fk.owner_h == p and KinSteal.stolen(fk), "net: the kin snapshot carries the carrier")
	row[KinNet.KIN_AT + 10] = ""
	KinNet.apply_kin(fk, row)
	ok(fk.owner_h == f, "...and an empty carrier sends it home")
