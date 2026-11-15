extends RefCounted
## --tutorial-retry-check: falling into the abyss in a tutorial beat starts that beat again; a down in a fight
## keeps the tutorial's revive. A scripted run of the course (the driver, with a Boki). As each fight and gap beat
## starts the player is dropped into the abyss (in the Boki's beats the Boki is down at the time). After it: the
## same step begins again (counters zero, its camp back in full and unpaid), the player is up, healed and at the
## last stop, the Boki is up, the fall paid no XP, the save is untouched and the beat's tip shows with its keys
## drawn by Settings.key_cap. Each camp that pays a level falls after a kill and pays once: killed one by one,
## the camp brought back pays equal shares of what was left and the last kill lands on the camp's level (or, if
## kills before the fall had paid it already, nothing more). Then
## the fights with nothing left to pay are knocked down: up after Tutorial.DOWN_T with the beat going on. Then the
## course still finishes.

const FIGHTS := ["sec", "shoot", "gkey", "kin", "hook", "ult"]
const GAPS := ["dash", "exdash", "glide"]
const BOKI_BEATS := ["gkey", "ult"]
## The beats that finish a camp, and the camp whose level they pay (shoot finishes the sec step's camp).
const PAYS := {"shoot": "sec", "gkey": "gkey", "kin": "kin", "hook": "hook"}
## The fights knocked down: by then their camp has nothing left to pay, so a kill while down changes nothing.
const DOWNS := ["gkey", "kin", "hook", "ult"]
const XP_EPS := 0.05          # XP: rounding slack (the last kill of a camp adds 0.01 to tip the level)
const TIP_WAIT := 3.0         # s for the tip to show (it waits for the banner like every message)
const GLOVE_WAIT := 30.0      # s: the walk to the glove takes 7-14; past this the check hands it over

var bad := 0
var m: Match
var tu: Tutorial
var seen := {}
var paid_once := {}
var downed := {}

func ok(cond: bool, what: String) -> void:
	print("TUTRETRY %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	Save.no_write = true
	seed(11)       # (the same run each time)
	m = Match.new()
	mn.add_child(m)
	# a starter whose right click has a hold: without one the sec beat asks for no cast (need 0) and passes
	# by itself (docs/DEBT.md), so there would be no beat to start again
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle",
		"arch": "archer", "cls": Arch.weight("archer")})
	m.set_process(false)
	tu = m.tut
	tu.ack()
	var t := 0.0
	while t < 900.0 and not m.player.extracted:
		var sid := tu.id()
		if (sid in FIGHTS or sid in GAPS) and not seen.has(sid) and not m.player.downed:
			seen[sid] = true
			_beat(sid)
		if sid == "glove" and tu.t > GLOVE_WAIT and not tu.ground_item().is_empty():
			m.player.teleport(tu.ground_item()["pos"])      # (the driver's straight walk can stick by the lookout)
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
	var fell := _missing(FIGHTS + GAPS, seen)
	ok(fell.is_empty(), "every fight and gap beat fell (missed %s)" % str(fell))
	var unpaid := _missing(PAYS.keys(), paid_once)
	ok(unpaid.is_empty(), "every camp that pays a level fell after a kill and paid once (missed %s)" % str(unpaid))
	var up := _missing(DOWNS, downed)
	ok(up.is_empty(), "every fight in DOWNS was knocked down (missed %s)" % str(up))
	ok(m.player.extracted, "the course still finishes after all of it")
	print("TUTRETRY DONE, failures: ", bad)
	mn.get_tree().quit(1 if bad > 0 else 0)

func _missing(want: Array, got: Dictionary) -> Array:
	return want.filter(func(s): return not got.has(s))

## One beat, from its first frame: a camp that pays a level has a kill paid first, the fall, then that camp
## killed one by one, then a down in the fights whose camp has nothing left to pay.
func _beat(sid: String) -> void:
	var p := m.player
	p.inp["move"] = Vector2.ZERO      # (the driver's last step must not steer the player while the check has them)
	var to := int(Content.rules("tutorial")["camps"][PAYS[sid]]["to"]) if PAYS.has(sid) else 0
	var lvl0 := p.lvl
	var ups0 := p.level_ups
	if to > lvl0 and tu.camps.killed() == 0 and tu.camps.alive() >= 2:
		_kill(tu.camps.nearest())
	_fall(sid)
	if to > lvl0:
		paid_once[sid] = true
		_pays_once(sid, to, lvl0, ups0)
	if sid in DOWNS and tu.id() == sid:
		downed[sid] = true
		_down(sid)

## Drops the player off the island (the Boki down too in its beats): the beat starts again.
func _fall(sid: String) -> void:
	var p := m.player
	var step := tu.step
	var save_before := JSON.stringify(Save.d["tutorial"])
	var stop := tu.respawn()
	var xp := p.xp
	if p.kin != null and sid in BOKI_BEATS:
		p.kin.go_down()
	p.teleport(Vector3(p.pos.x, p.pos.y - 60.0, p.pos.z))
	m.on_fell(p)
	var tag := sid + " fall"
	ok(tu.step == step and tu.id() == sid, "%s: the same beat" % tag)
	ok(not p.downed and not p.out and p.hp >= p.max_hp - 0.01, "%s: up and healed" % tag)
	ok(p.pos.distance_to(stop) < 0.5, "%s: back at the last stop" % tag)
	var fresh: bool = tu.t < 0.5 and tu.got == 0 and tu.hits == 0 and tu.taps == 0 and not tu.flag
	ok(fresh, "%s: the beat starts again (t %.2f)" % [tag, tu.t])
	ok(absf(p.xp - xp) < 1e-6, "%s: the fall pays no XP (%.2f, was %.2f)" % [tag, p.xp, xp])
	ok(JSON.stringify(Save.d["tutorial"]) == save_before, "%s: the save is untouched" % tag)
	var k := p.kin
	ok(k == null or (k.state != "downed" and k.hp > 0.0 and not k.dead), "%s: the Boki is up" % tag)
	if sid in FIGHTS:
		var camp: Array = tu.camps.ledger
		var full := camp.all(func(e): return not e["paid"] and (e["mb"] as Mob).hp >= (e["mb"] as Mob).max_hp - 0.01)
		ok(not camp.is_empty() and full and tu.camps.alive() == camp.size(),
			"%s: the camp is back in full, none of it paid (%d)" % [tag, camp.size()])
	_tip_shows(tag)

## The beat's one line shows, every key in it drawn by Settings.key_cap (no token left).
func _tip_shows(tag: String) -> void:
	var line := tu.retry_tip()
	var shown := false
	for i in int(TIP_WAIT / Match.DT):
		m.step(Match.DT)
		if m.hud.msgs.texts().any(func(x): return x.begins_with(line)):
			shown = true
			break
	ok(shown and not line.contains("%"), "%s: the tip shows ('%s')" % [tag, line])

## After the fall the camp is back unpaid. Killed one by one, its kills pay equal shares of what was left to the
## camp's level (nothing is left when kills before the fall reached it), the level waits for the last one and
## lands on it, and the camp gave its levels once. The XP is held against the camp's own paid marks, so a
## kill by the Boki, paid in the same step or the next, is one more share.
func _pays_once(sid: String, to: int, lvl0: int, ups0: int) -> void:
	var p := m.player
	var camp: Array = tu.camps.ledger.duplicate()      # (its entries: their paid marks stay readable after a respawn)
	var paid0 := camp.filter(func(e): return e["paid"]).size()      # (the Boki may have had one while the tip showed)
	var xp0 := p.xp
	var left := maxf(0.0, float(Hunter.XP_TO[to - 1]) - xp0)
	var share := left / float(maxi(camp.size() - paid0, 1))
	var fair := true
	for i in camp.size() + 3:
		var alive := camp.filter(func(e): return not (e["mb"] as Mob).dead)
		if alive.is_empty() and camp.all(func(e): return e["paid"]):
			break
		_kill(null if alive.is_empty() else alive[0]["mb"])
		var paid := camp.filter(func(e): return e["paid"]).size()
		var want := share * (paid - paid0) + (0.01 if paid == camp.size() and left > 0.0 else 0.0)
		fair = fair and absf(p.xp - xp0 - want) < XP_EPS and (p.lvl < to or paid == camp.size() or left == 0.0)
	var all_paid := camp.all(func(e): return e["paid"])
	ok(all_paid and fair, "%s: each kill of the camp brought back pays its share (%.1f XP)" % [sid, share])
	var over := p.xp - float(Hunter.XP_TO[to - 1])
	var ups := p.level_ups - ups0
	ok(p.lvl == to and ups == to - lvl0 and over >= 0.0 and over < XP_EPS,
		"%s: the retried camp paid once (level %d, %d level-ups, %.2f XP over)" % [sid, p.lvl, ups, over])

## A down in a fight is no retry: up after Tutorial.DOWN_T, the same beat with its clock running on (a retry would
## start it from 0 at the last stop).
func _down(sid: String) -> void:
	var p := m.player
	var step := tu.step
	var t0 := tu.t
	m.knock(p, null, {})
	var t := 0.0
	while p.downed and t < Tutorial.DOWN_T + 1.0:
		m.step(Match.DT)
		t += Match.DT
	var tag := sid + " down"
	ok(not p.downed and absf(t - Tutorial.DOWN_T) < 0.1, "%s: up again after %.0f s (%.2f)" % [tag, Tutorial.DOWN_T, t])
	ok(tu.step == step and tu.t >= t0 + t - 0.1, "%s: the beat goes on, no restart" % tag)

## A camp monster killed the real way (by the player), then one step so the camp pays for it.
func _kill(mb: Mob) -> void:
	if mb != null:
		mb.hurt(mb.max_hp * 50.0, m.player)
	m.step(Match.DT)
