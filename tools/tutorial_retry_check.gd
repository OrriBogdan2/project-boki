extends RefCounted
## --tutorial-retry-check: going down or falling into the abyss in a tutorial beat starts that beat again.
## The driver plays the course twice with a Boki: once clean, once with retries. In the retry pass every camp
## beat, gap beat and the glove's has the player knocked down and, later in the same beat, dropped into the
## abyss (the Boki goes down too in its beat); in a camp beat one monster falls first, so the camp has paid
## some XP. After each: the same beat begins again (counters zero, a fresh camp on a new XP ledger), the
## player is up, healed and at the last stop, the Boki is up, one glove lies on the ground, the cleared
## monsters paid no XP, the save is untouched and the beat's retry line shows. Every beat but sec then ends
## on the XP it ends on in the clean pass, and the course still finishes.

const CAMPS := ["sec", "shoot", "gkey", "kin", "hook", "ult"]
const OTHERS := ["dash", "exdash", "glide", "glove"]
const BOKI_BEAT := "gkey"      # the beat a downed Boki used to pass
const RUN_MAX := 400.0         # s of driven play: the whole course, retries and all
const STARTER := "archer"      # its right click has a hold, so its sec beat waits for a tap and a hold
const XP_EPS := 0.001          # XP: two amounts this close are the same
const TIP_WAIT := 3.0          # s for the retry line to come up (the step's banner holds the lane first)
const KEYS := ["fire", "glide", "interact", "crouch", "sec", "sec_hold", "sig", "jump", "dash", "throw", "gear1", "ult"]

var bad := 0
var m: Match
var tu: Tutorial
var ended_xp := {}             # step id -> the player's XP when that beat ended
var tut_save := {}             # the save's tutorial part before the first pass

func ok(cond: bool, what: String) -> void:
	print("TUTRETRY %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	Save.no_write = true
	tut_save = Save.d["tutorial"].duplicate(true)
	var clean := _play(mn, false)
	var retried := _play(mn, true)
	for sid in clean:
		if sid == "sec":
			continue      # (its cast ends it with any part of its camp down; shoot ends that camp)
		var xp := float(retried.get(sid, -1.0))
		var same := absf(xp - float(clean[sid])) < XP_EPS
		ok(same, "%s: ends on the clean pass's XP (%.2f, clean %.2f)" % [sid, xp, float(clean[sid])])
	print("TUTRETRY DONE, failures: ", bad)
	mn.get_tree().quit(1 if bad > 0 else 0)

## One run of the course, with or without the retries. Returns the XP each beat ended on. Not a tut_test
## match: that one drives itself in every step, and here the player stands still while a retry plays out.
func _play(mn: Node, retries: bool) -> Dictionary:
	seed(11)       # (the same course both times)
	Save.d["tutorial"] = tut_save.duplicate(true)      # (and from the same save: no beat to carry on from)
	ended_xp = {}
	m = Match.new()
	mn.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle",
			"arch": STARTER, "cls": Arch.weight(STARTER)})
	m.set_process(false)
	tu = m.tut
	tu.ack()
	var tried := {}
	var t := 0.0
	while t < RUN_MAX and not m.player.extracted:
		var sid := tu.id()
		if retries and (sid in CAMPS or sid in OTHERS) and tu.t > 0.4 and not tried.has(sid):
			tried[sid] = true
			for how in ["down", "fall"]:
				_one_falls(sid)
				_injure(sid, how)
		TutorialDrive.drive(m)
		_step()
		t += Match.DT
	if retries:
		for sid in CAMPS + OTHERS:
			ok(tried.has(sid), "the %s beat was reached, downed and dropped" % sid)
		ok(m.player.kin != null and m.player.kin.state != "downed", "the Boki is up at the end")
	var tag := "retry pass" if retries else "clean pass"
	ok(m.player.extracted, "%s: the course finishes (%.0f s)" % [tag, t])
	m.queue_free()
	return ended_xp

## One frame. When a beat ends, the XP it ended on is noted.
func _step() -> void:
	var before := tu.step
	m.step(Match.DT)
	if tu.step != before and before >= 0 and before < Tutorial.steps().size():
		ended_xp[String(Tutorial.steps()[before][0])] = m.player.xp

## In a camp beat with two or more standing, one falls to the player, so the camp has paid some XP.
func _one_falls(sid: String) -> void:
	if sid not in CAMPS or tu.camps.alive() < 2:
		return
	var xp := m.player.xp
	var mb := tu.camps.nearest()
	mb.hurt(mb.max_hp * 10.0, m.player)
	_step()
	var paid := m.player.xp > xp or int(tu.camps.ledger[0]["to"]) <= m.player.lvl
	ok(mb.dead and paid, "%s: one of the camp fell and paid (XP %.2f -> %.2f)" % [sid, xp, m.player.xp])

## Knocks the player down (and the Boki in its beat), or drops the player off the island; then checks that
## the beat started again.
func _injure(sid: String, how: String) -> void:
	var p := m.player
	var step := tu.step
	var flag_before := tu.flag
	var save_before := JSON.stringify(Save.d["tutorial"])
	var back_at := tu.respawn()
	var xp_before := p.xp
	for key in KEYS:
		p.inp[key] = false      # (hands off: what the driver last held does nothing while this plays out)
	p.inp["move"] = Vector2.ZERO
	if how == "down":
		m.knock(p, null, {})
		if p.kin != null and sid == BOKI_BEAT:
			p.kin.go_down(true)
		var left := Tutorial.DOWN_T + 0.5
		while left > 0.0 and p.downed:
			xp_before = p.xp      # (the Boki's kills while you are down still pay; the retry's frame pays none)
			_step()
			left -= Match.DT
	else:
		p.teleport(Vector3(p.pos.x, p.pos.y - 60.0, p.pos.z))
		m.on_fell(p)
	var tag := "%s %s" % [sid, how]
	ok(tu.step == step and tu.id() == sid, "%s: the same beat" % tag)
	ok(not p.downed and p.hp >= p.max_hp - 0.01, "%s: up and healed" % tag)
	ok(p.pos.distance_to(back_at) < 0.5 and not p.out, "%s: back at the last stop" % tag)
	var flag_kept := tu.flag == flag_before if sid == "ult" else not tu.flag      # (the fuse is once a run)
	var fresh: bool = tu.t < 0.5 and tu.got == 0 and tu.hits == 0 and tu.taps == 0 and flag_kept
	ok(fresh, "%s: the beat starts again (t %.2f)" % [tag, tu.t])
	ok(JSON.stringify(Save.d["tutorial"]) == save_before, "%s: the save is untouched" % tag)
	ok(absf(p.xp - xp_before) < XP_EPS, "%s: the cleared monsters paid no XP (%.2f -> %.2f)" % [tag, xp_before, p.xp])
	var k: Kin = p.kin
	var boki_up: bool = k == null or (k.state != "downed" and not k.dead and k.hp >= k.max_hp - 0.01)
	ok(boki_up, "%s: the Boki is up and healed" % tag)
	if sid in CAMPS:
		_camp_fresh(tag)
	if sid == "glove":
		var gloves := m.wpicks.filter(func(w): return w.get("tut", false)).size()
		ok(gloves == 1, "%s: one glove on the ground (%d)" % [tag, gloves])
	_tip_shows(sid, tag)

## The camp the beat brought back: all of it standing at full health, none of it paid, nothing else out.
func _camp_fresh(tag: String) -> void:
	var ledger: Array = tu.camps.ledger
	var fresh := not ledger.is_empty()
	for e: Dictionary in ledger:
		var mb: Mob = e["mb"]
		fresh = fresh and not e["paid"] and not mb.dead and mb.hp >= mb.max_hp - 0.01
	var others := m.mobs.filter(func(x): return not x.dead).size() - tu.camps.alive()
	ok(fresh and others == 0, "%s: a fresh camp of %d on a new ledger, no one else (%d)" % [tag, ledger.size(), others])

## The beat's retry line comes up (its words up to the first token, which the player's keys fill in).
func _tip_shows(sid: String, tag: String) -> void:
	var tips: Dictionary = Content.rules("tutorial")["retry"]
	var line := String(tips.get(sid, tips["default"]))
	if line.contains("%"):
		line = line.substr(0, line.find("%"))
	var shown := false
	for i in int(TIP_WAIT / Match.DT):
		_step()
		if m.hud and m.hud.msgs.texts().any(func(x): return x.begins_with(line)):
			shown = true
			break
	ok(shown, "%s: the retry line shows ('%s')" % [tag, line])
