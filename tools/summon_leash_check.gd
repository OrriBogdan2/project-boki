extends RefCounted
## --summon-leash-check: the summoned Boki's lane and leash (DECISIONS 2026-11-09, WISP_DESIGN_OPEN Q3/Q7,
## decision 0039). One summoned Boki at a time per Hunter, a stolen one included: Summon while another is out
## is refused, while your own out is the early recall. The leash is the short fixed one from
## content/rules/boki_summon.json: chasing past it turns the Boki back, and it holds when you dash away,
## glide off a ledge or are knocked. Prints PASS/FAIL.

const DT := 1.0 / 60.0
const RUSH_S := 1.5      # s: its rush ability has landed and it is walking home again

var bad := 0
var m: Match
var p: Hunter
var k: Kin

func run(main: Node) -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true,
		"demo_kin": "cindle", "boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
	p = m.player
	k = p.kin
	_frames(0.3)
	_lane()
	_leash_rules()
	_chase()
	_dash()
	_glide()
	_knock()
	print("SUMMONLEASH %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("SUMMONLEASH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frames(secs: float) -> void:
	for _i in int(secs / DT):
		m.step(DT)

## A fresh summon: the Boki out whole beside you, the window full.
func _out() -> void:
	k.summon.cd = 0.0
	if k.summon.out():
		k.summon.left = 0.0
		k.summon.shrink = 0.0
		KinWisp.set_wisp(k, true)
	KinSummon.press(p)
	k.summon.left = 60.0      # (long enough to outlast the scene)
	_frames(0.2)

func _lane() -> void:
	var other: Kin = m.kins.filter(func(x: Kin): return x.owner_h != null and x.owner_h != p)[0]
	var home := other.owner_h
	other.owner_h = p          # (stands in for a stolen Boki riding with you: KinSteal does the same)
	other.summon.left = 5.0
	k.summon.cd = 0.0
	ok(KinSummon.lane_busy(p, k), "lane: a stolen Boki that is out takes your one lane")
	ok(not KinSummon.press(p) and k.wisp and not k.summon.out(), "...a second Summon is refused, yours stays a wisp")
	other.summon.left = 0.0
	other.owner_h = home
	ok(not KinSummon.lane_busy(p, k) and KinSummon.press(p) and not k.wisp, "...and the lane is free again after")
	ok(KinSummon.press(p) and k.summon.shrink > 0.0, "...Summon while your own is out is the early recall")
	_out()
	other.owner_h = p
	other.summon.left = 5.0
	ok(KinSummon.press(p) and k.summon.shrink > 0.0, "...recall still works while a stolen one is out too")
	other.summon.left = 0.0
	other.owner_h = home

func _leash_rules() -> void:
	var r := KinSummon.rules()
	var lr := float(r["leash"])
	ok(lr > 0.0 and lr < float(r["rebloom_dist"]) and String(r["_doc"]).contains("leash: m"),
		"leash: 10 m, under the re-bloom distance, with its unit and reason in the rules")
	var l := k.summon.leash(0.5)
	var sw := float(r["leash_swing"])
	ok(absf(l - lr) < 0.01 and k.summon.leash(1.0) <= lr + sw + 0.01 and k.summon.leash(0.0) >= lr - sw - 0.01,
		"...personality moves it by at most +-%.0f m" % float(r["leash_swing"]))

func _foe() -> Hunter:
	for h in m.hunters:
		if h.team != p.team:
			return h
	return null

func _chase() -> void:
	_out()
	k.cmd = "follow"
	var lsh := k.brain.leash()
	ok(lsh == k.summon.leash(k.brain.aggression), "chase: out, its leash is the summon one (%.1f m)" % lsh)
	var foe := _foe()
	var stay := Vector3(lsh + 2.0, 0, 0)      # a foe just past the leash, the Boki already near it
	k.teleport(p.pos + Vector3(lsh - 2.0, 0, 0))
	var far := 0.0
	var turned := false
	for _i in 360:
		foe.pos = p.pos + stay
		foe.prev = foe.pos
		m.step(DT)
		if _i > RUSH_S * 60:      # (its own rush ability flies first and is not the leash's business)
			far = maxf(far, k.flat_dist(p))
		turned = turned or k.state == "returning"
	ok(far > lsh - 1.5, "chase: it walks out to a foe at the edge of the leash (%.1f m of %.1f)" % [far, lsh])
	ok(turned, "chase: past the leash it turns back")
	ok(far < lsh + 4.0 and k.summon.out(), "...and never walks far past it (%.1f m of %.1f)" % [far, lsh])
	foe.pos = p.pos + Vector3(0, 0, 200)
	foe.prev = foe.pos

func _settled(what: String) -> void:
	_frames(3.0)
	var lsh := k.brain.leash()
	var d := k.flat_dist(p)
	ok(k.summon.out() and not k.wisp and d <= lsh + 1.0,
		"%s: back within the leash (%.1f of %.1f m), still out" % [what, d, lsh])

func _dash() -> void:
	_out()
	p.pos += Vector3(14, 0, 0)
	p.prev = p.pos
	_settled("dash")

func _glide() -> void:
	_out()
	for _i in 90:
		p.gliding = true
		p.grounded = false
		p.pos += Vector3(0.12, 0, 0)
		p.prev = p.pos
		m.step(DT)
	var d := k.flat_dist(p)
	ok(k.summon.out() and d < float(KinSummon.rules()["rebloom_dist"]), "glide: carried or beside you (%.1f m)" % d)
	p.gliding = false
	_settled("glide")

func _knock() -> void:
	_out()
	p.vel = Vector3(28, 6, 0)
	_frames(1.0)
	_settled("knock")
