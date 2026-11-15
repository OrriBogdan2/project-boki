extends RefCounted
## --summon-check: the Boki summon out of the wisp (KinSummon, decision 0039). The Summon key
## (C) bursts the wisp into the full Boki, again sends it back early, the role x size table and the leash
## come from content/rules/boki_summon.json, a knock-down turns it back into a wisp with the longer
## cooldown, the leash holds on a chase, a dash, a glide and a knock, and the kin snapshot carries the
## summon seconds to another game. Prints PASS/FAIL.

const DT := 1.0 / 60.0
const RUSH_S := 1.5      # s: its rush ability has landed and it is walking home again

var bad := 0
var m: Match
var p: Hunter
var k: Kin
var east := Vector3.RIGHT      # the way the scenes walk: solid ground out to 20 m (the map has abyss on some sides)


func run(main: Node) -> void:
	m = Match.new()
	main.add_child(m)
	m.start(
		{
			"teams": 2,
			"squad": 2,
			"tier": 0,
			"length": 1e9,
			"seed": 78,
			"no_drop": true,
			"demo_kin": "cindle",
			"boki_wisps": true
		}
	)
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
	p = m.player
	k = p.kin
	_frames(0.3)
	east = _solid_dir()
	_table()
	_press()
	_knocked()
	_net()
	_leash_rules()
	_chase()
	_dash()
	_glide()
	_knock()
	print("SUMMON %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)


func ok(cond: bool, what: String) -> void:
	print("SUMMON %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _frames(secs: float) -> void:
	for _i in int(secs / DT):
		m.step(DT)


## The first of 8 directions from the Hunter with no abyss within 20 m.
func _solid_dir() -> Vector3:
	for i in 8:
		var d := Vector3.RIGHT.rotated(Vector3.UP, i * TAU / 8.0)
		var clear := true
		for r in range(2, 22, 2):
			var q := p.pos + d * float(r)
			clear = clear and not m.world.is_void(q.x, q.z)
		if clear:
			return d
	return Vector3.RIGHT


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


func _table() -> void:
	var band: Array = KinSummon.rules()["uptime_band"]
	var worst := true
	for id in Data.KIN:
		var t := KinSummon.times(KinLib.kin(String(id)))
		var up := t.x / (t.x + t.y)
		worst = worst and up >= float(band[0]) and up <= float(band[1])
	ok(worst, "table: every species' window / (window + cooldown) is inside the uptime band")


func _press() -> void:
	ok(k.wisp and k.summon.cd == 0.0, "press: the Boki rides as a wisp, ready")
	ok(KinSummon.press(p) and not k.wisp and k.summon.left > 0.0, "press: Summon bursts it out whole")
	ok(KinSummon.press(p) and k.summon.shrink > 0.0, "press: Summon again is the early recall")
	_frames(KinSummon.SHRINK_S + 0.2)
	ok(k.wisp and k.summon.cd >= k.summon.cd_base - 1.0, "press: back as a wisp with the full cooldown")
	ok(not KinSummon.press(p) and k.wisp, "press: refused while it rests")
	var cap := Settings.key_cap("summon")
	ok(cap != "", "press: the Summon key has a cap for the prompts (%s)" % cap)


func _knocked() -> void:
	_out()
	k.go_down()
	ok(k.wisp and not k.summon.out(), "knocked: a knock-down turns it straight back into a wisp")
	var want: float = k.summon.cd_base * float(KinSummon.rules()["knocked_cd_mult"])
	ok(absf(k.summon.cd - want) < 0.5, "...with the longer cooldown (%.0f s)" % k.summon.cd)


## The kin snapshot carries the wisp flag and the summon seconds, and another game applies them.
func _net() -> void:
	_out()
	k.summon.left = 7.5
	k.summon.cd = 0.0
	var snap := KinNet.kin_extra(k)
	var it: Array = []
	it.resize(KinNet.KIN_AT)
	it.append_array(snap)
	k.summon.left = 0.0
	KinNet.apply_kin(k, it)
	ok(absf(k.summon.left - 7.5) < 0.2 and not k.wisp, "net: window seconds and the out form round-trip")
	k.summon.left = 0.0
	k.summon.shrink = 0.0
	KinWisp.set_wisp(k, true)
	k.summon.cd = 33.0
	snap = KinNet.kin_extra(k)
	it.resize(KinNet.KIN_AT)
	it.append_array(snap)
	k.summon.cd = 0.0
	KinWisp.set_wisp(k, false)
	KinNet.apply_kin(k, it)
	ok(k.wisp and absf(k.summon.cd - 33.0) < 0.2, "net: the wisp flag and the cooldown round-trip")


func _leash_rules() -> void:
	var r := KinSummon.rules()
	var lr := float(r["leash"])
	ok(lr > 0.0 and lr < float(r["rebloom_dist"]), "leash: 10 m, under the re-bloom distance")
	var sw := float(r["leash_swing"])
	ok(
		absf(k.summon.leash(0.5) - lr) < 0.01 and absf(k.summon.leash(1.0) - lr) <= sw + 0.01,
		"...personality moves it by at most +-%.0f m" % sw
	)


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
	var stay := east * (lsh + 2.0)      # a foe just past the leash, the Boki already near it
	k.teleport(p.pos + east * (lsh - 2.0))
	var far := 0.0
	var turned := false
	for i in 360:
		foe.pos = p.pos + stay
		foe.prev = foe.pos
		m.step(DT)
		if i == int(RUSH_S * 60) + 20:      # (the rush flew it home: back to the edge, the walk is measured)
			k.teleport(p.pos + east * (lsh - 2.0))
		if i > RUSH_S * 60 + 20:
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
	ok(
		k.summon.out() and not k.wisp and d <= lsh + 1.0,
		"%s: back within the leash (%.1f of %.1f m), still out" % [what, d, lsh]
	)


func _dash() -> void:
	_out()
	p.pos += east * 14.0
	p.prev = p.pos
	_settled("dash")


func _glide() -> void:
	_out()
	for _i in 90:
		p.gliding = true
		p.grounded = false
		p.pos += east * 0.12
		p.prev = p.pos
		m.step(DT)
	var d := k.flat_dist(p)
	ok(k.summon.out() and d < float(KinSummon.rules()["rebloom_dist"]), "glide: carried or beside you (%.1f m)" % d)
	p.gliding = false
	_settled("glide")


func _knock() -> void:
	_out()
	p.vel = east * 28.0 + Vector3(0, 6, 0)
	_frames(1.0)
	_settled("knock")
