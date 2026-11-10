extends RefCounted
## --summon-credit-check: a summoned Boki's blows are its Hunter's (KnockCredit, CombatBus.takedown). Its last hit
## is the Hunter's knock and kill and the feed line names both ("Vex's Cindle knocked ..."); a hit that set up a
## teammate's knock is the Hunter's assist; a stolen summon credits the thief, never the Boki's own Hunter. The
## net events carry the credited Hunter and the Boki's id so every game writes the same line.

const DT := 1.0 / 60.0

var bad := 0
var m: Match
var seen: Array = []      # CombatBus.takedown payloads, newest last

func ok(cond: bool, what: String) -> void:
	print("SUMCREDIT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT

func _on_takedown(kind: String, victim: Node, hunter: Node, boki: Node, assists: Array) -> void:
	seen.append({"kind": kind, "victim": victim, "hunter": hunter, "boki": boki, "assists": assists})

func _stand(v: Hunter) -> void:
	Life.bring_back(m, v, v.pos, 1.0, false)
	v.inv_t = 0.0
	v.armor = 0.0
	v.shield = 0.0
	v.kin_shield = 0.0
	v.hp = v.max_hp
	KnockCredit.of(m).hits.clear()
	seen.clear()

func _feed() -> String:
	return String(m.feed.back()["text"])

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
		h.inp["move"] = Vector2.ZERO
	_frames(0.3)
	CombatBus.takedown.connect(_on_takedown)
	_summon_credit()
	_stolen_credit()
	CombatBus.takedown.disconnect(_on_takedown)
	m.queue_free()
	print("SUMMONCREDIT %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _summon_credit() -> void:
	var p: Hunter = m.player
	var mate: Hunter = m.hunters.filter(func(h: Hunter): return h.team == p.team and h != p)[0]
	var foes: Array = m.hunters.filter(func(h: Hunter): return h.team != p.team)
	var v: Hunter = foes[0]
	var bk: Kin = p.kin
	ok(KinSummon.press(p) and not bk.wisp and bk.owner_h == p,
		"setup: the Summon key bursts %s out" % bk.rec.get("name", "?"))
	var line := "%s's %s" % [p.pname, bk.rec.get("name", "Boki")]

	_stand(v)
	var k0 := p.knocks
	v.hp = 5.0
	v.hurt(20.0, bk, {"src": "kin"})
	ok(v.downed and p.knocks == k0 + 1, "last hit: the summoned Boki's knock is its Hunter's")
	ok(_feed() == "%s knocked %s" % [line, v.pname], "...and the feed names it: \"%s\"" % _feed())
	ok(seen.size() == 1 and seen[0]["kind"] == "knock" and seen[0]["hunter"] == p and seen[0]["boki"] == bk
		and seen[0]["victim"] == v, "...CombatBus.takedown: knock, Hunter and Boki")
	ok(KnockCredit.boki_nid(bk) == bk.nid and m.ents_by_id.get(bk.nid) == bk, "...the net event carries the Boki's id")

	seen.clear()
	var kills := p.kills
	m.eliminate(v, bk, "finished")
	ok(p.kills == kills + 1 and _feed() == "%s took out %s" % [line, v.pname],
		"last hit, kill: the Hunter's kill, \"%s\"" % _feed())
	ok(seen.size() == 1 and seen[0]["kind"] == "out" and seen[0]["hunter"] == p and seen[0]["boki"] == bk,
		"...CombatBus.takedown: out, Hunter and Boki")

	var v2: Hunter = foes[1]
	_stand(v2)
	var k1 := p.knocks
	var seen0: int = p.ak.knocks_seen
	var mk := mate.knocks
	v2.hurt(20.0, bk, {"src": "kin"})
	_frames(1.0)
	v2.hp = 5.0
	v2.hurt(20.0, mate, {"src": "shot"})
	ok(v2.downed and mate.knocks == mk + 1 and p.knocks == k1, "assist: a teammate's knock stays the teammate's")
	ok(p.ak.knocks_seen == seen0 + 1, "...the Boki's Hunter hears it as an assist")
	ok(seen.size() == 1 and seen[0]["hunter"] == mate and seen[0]["boki"] == null and seen[0]["assists"].has(p),
		"...CombatBus.takedown lists the Boki's Hunter as an assister")
	ok(_feed() == "%s knocked %s" % [mate.pname, v2.pname],
		"...and the feed names the finisher")

func _stolen_credit() -> void:
	var p: Hunter = m.player
	var f: Hunter = m.hunters.filter(func(h: Hunter): return h.team != p.team and h.kin != null)[0]
	var v: Hunter = m.hunters.filter(func(h: Hunter): return h.team != p.team and h != f)[0]
	var fk: Kin = f.kin
	_stand(f)
	_stand(v)
	m.knock(f, null, {})
	_frames(0.1)
	f.pos = fk.pos
	ok(KinSteal.grab(fk, p) and KinSteal.stolen(fk), "setup: %s grabs %s's loose wisp" % [p.pname, f.pname])
	p.kin.summon.end()      # (its own is sent back, resting, so the key bursts the stolen one)
	_frames(KinSummon.SHRINK_S + 0.1)
	p.kin.summon.cd = 40.0
	ok(KinSummon.press(p) and not fk.wisp, "...and summons it")
	seen.clear()
	var thief_k := p.knocks
	var home_k := f.knocks
	v.hp = 5.0
	v.hurt(20.0, fk, {"src": "kin"})
	ok(v.downed and p.knocks == thief_k + 1 and f.knocks == home_k,
		"stolen summon: the thief gets the knock, not its Boki's own Hunter")
	ok(_feed() == "%s's %s knocked %s" % [p.pname, fk.rec.get("name", "Boki"), v.pname],
		"...the feed shows the thief's: \"%s\"" % _feed())
	ok(seen.size() == 1 and seen[0]["hunter"] == p and seen[0]["boki"] == fk, "...CombatBus.takedown credits the thief")
	var kills := p.kills
	m.eliminate(v, fk, "finished")
	ok(p.kills == kills + 1 and f.kills == 0, "stolen summon, kill: the thief's kill")
