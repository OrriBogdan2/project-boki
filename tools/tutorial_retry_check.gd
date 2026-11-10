extends RefCounted
## --tutorial-retry-check: going down or falling into the abyss in a tutorial beat starts that beat again.
## A scripted run of the course (the driver, with a Boki). In every beat it reaches, the player is knocked down
## and, later in the same beat, dropped into the abyss; the Boki goes down in the Boki beats. After each:
## the step is the same and begins again (counters zero, fresh monsters), the player is up, healed and at the last
## stop, the Boki is up and out of its downed state, the save is untouched, the beat's retry line shows, and the
## beat does not count as done. Then the course still finishes.

const COMBAT := ["gkey", "shoot", "sig", "utility", "throw", "kin1", "fight"]
const GAPS := ["dash", "exdash", "glide"]
const BOKI_BEATS := ["gkey", "throw", "kin1"]

var bad := 0
var m: Match
var tu: Tutorial
var seen: Dictionary = {}

func ok(cond: bool, what: String) -> void:
	print("TUTRETRY %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	Save.no_write = true
	m = Match.new()
	mn.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	tu = m.tut
	tu.ack()
	var t := 0.0
	while t < 900.0 and not m.player.extracted:
		var sid := tu.id()
		if (sid in COMBAT or sid in GAPS) and tu.t > 0.4 and not seen.has(sid):
			seen[sid] = true
			_injure(sid, "down")
			_injure(sid, "fall")
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
	for sid in COMBAT:
		if m.player.ak == null and sid == "sig":
			continue
		ok(seen.has(sid), "the %s beat was reached, downed and dropped" % sid)
	ok(m.player.extracted, "the course still finishes after all of it")
	ok(m.player.kin != null and m.player.kin.state != "downed", "and the Boki is up")
	print("TUTRETRY DONE, failures: ", bad)
	mn.get_tree().quit(1 if bad > 0 else 0)

## Knock the player down (and the Boki in its beats), or drop the player off the island, in the beat now.
func _injure(sid: String, how: String) -> void:
	var p := m.player
	var step := tu.step
	var save_before := JSON.stringify(Save.d["tutorial"])
	var stop := tu.respawn()
	if how == "down":
		m.knock(p, null, {})
		if p.kin != null and sid in BOKI_BEATS:
			p.kin.go_down(true)
		var left := Tutorial.DOWN_T + 0.5
		while left > 0.0 and p.downed:
			m.step(Match.DT)
			left -= Match.DT
	else:
		p.teleport(Vector3(p.pos.x, p.pos.y - 60.0, p.pos.z))
		m.on_fell(p)
	var tag := "%s %s" % [sid, how]
	ok(tu.step == step and tu.id() == sid, "%s: the same beat" % tag)
	ok(not p.downed and p.hp >= p.max_hp - 0.01, "%s: up and healed" % tag)
	ok(p.pos.distance_to(stop) < 0.5 and not p.out, "%s: back at the last stop" % tag)
	var fresh: bool = tu.t < 0.5 and tu.got == 0 and tu.hits == 0 and tu.taps == 0 and not tu.flag
	ok(fresh, "%s: the beat starts again (t %.2f)" % [tag, tu.t])
	ok(JSON.stringify(Save.d["tutorial"]) == save_before, "%s: the save is untouched" % tag)
	var k := p.kin
	ok(k == null or (k.state != "downed" and k.hp > 0.0 and not k.dead), "%s: the Boki is up" % tag)
	var foes := m.mobs.filter(func(x): return not x.dead)
	if sid in COMBAT:
		ok(foes.all(func(x): return x.hp >= x.max_hp - 0.01), "%s: monsters are fresh (%d)" % [tag, foes.size()])
	var line := _retry_line()
	var shown := false
	m.player.inp["move"] = Vector2.ZERO
	for i in int(3.0 / Match.DT):
		m.step(Match.DT)
		if m.hud and m.hud.msgs.texts().any(func(x): return x.contains(line.substr(0, 12))):
			shown = true
			break
	ok(shown, "%s: the tip shows ('%s')" % [tag, line])

func _retry_line() -> String:
	var tips: Dictionary = Content.rules("tutorial")["retry"]
	return tu._fill(String(tips.get(tu.id(), tips["default"])))
