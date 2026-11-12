extends RefCounted
## --summon-death-check: a killed summon (KinSummon.killed, decision 0044), with Boki wisps on. Damage alone never
## ends the window; its death turns the Boki back into a wisp where it fell. A rival hunter's kill: the longer
## cooldown, the wisp flies home at home_speed, its owner is revealed for reveal_s and pinged on the killer squad's
## minimap. A monster's kill: plain cooldown, no reveal. The owner downed: a rival's kill leaves a loose wisp
## where it fell, a monster's sends it home. Online: the "wkill" event pings only the killer's squad and the kin
## snapshot shows the wisp. Owner knocked: the summon fights on (main's KinWispForm skips it). Prints PASS/FAIL.

const DT := 1.0 / 60.0

var bad := 0
var m: Match
var main: Node

func run(main_node: Node) -> void:
	main = main_node
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 79, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
		h.inp["move"] = Vector2.ZERO
	_frames(0.3)
	_death()
	m.queue_free()
	print("SUMMONDEATH %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("SDEATH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT

## The foe's Boki, summoned and ready to be hurt (its owner stands and stays put).
func _summoned(f: Hunter) -> Kin:
	var k: Kin = f.kin
	k.summon.cd = 0.0
	k.summon.burst(k.summon.dur)
	_frames(0.05)
	return k

func _wisp_pings() -> int:
	return m.sound_pings.filter(func(sp: Dictionary) -> bool: return sp["kind"] == "wisp").size()

func _death() -> void:
	var p: Hunter = m.player
	var f: Hunter = m.hunters.filter(func(h: Hunter): return h.team != p.team and h.kin != null)[0]
	var base := KinSummon.times(f.kin.ks).y
	var mult := float(KinSummon.rules()["killed_cd_mult"])
	var k := _summoned(f)
	ok(k.summon.out() and not k.wisp, "setup: a foe's Boki is summoned")
	k.hurt(k.max_hp * 0.6, p)
	ok(k.summon.out() and not k.wisp and not f.downed, "damage alone does not end the summon")
	var pings := _wisp_pings()
	k.teleport(f.pos + Vector3(12, 0, 0))          # (killed away from its owner, so there is a flight)
	k.hurt(k.max_hp * 5.0, p)
	ok(k.wisp and k.state == "shoulder" and not KinSteal.loose(k) and k.owner_h == f,
		"killed by a rival: back to a wisp, with its owner")
	ok(absf(k.summon.cd - base * mult) < 0.01, "...the longer cooldown (%.1f s)" % k.summon.cd)
	ok(f.reveal_t >= float(KinSummon.rules()["reveal_s"]) - 0.01, "...its owner is revealed for reveal_s")
	ok(_wisp_pings() == pings + 1, "...and the killer's minimap gets a ping")
	var from := k.summon.fly_from
	var want := Vector2(from.x - f.pos.x, from.z - f.pos.z).length() / float(KinSummon.rules()["home_speed"])
	ok(k.summon.fly > 0.0 and want > 0.2 and absf(k.summon.fly_len - want) < 0.05,
		"...it flies home at home_speed (%.2f s)" % k.summon.fly_len)
	k.render(DT, 1.0)
	ok(k.global_position.distance_to(k.summon.fly_from) < 1.0, "...the streak starts where it fell")
	_frames(k.summon.fly_len + 0.1)
	ok(k.summon.fly == 0.0 and k.state == "shoulder", "...and ends on its owner's shoulder")

	f.reveal_t = 0.0
	pings = _wisp_pings()
	k = _summoned(f)
	k.summon.cd = 0.0
	k.hurt(k.max_hp * 5.0, null)
	ok(k.wisp and absf(k.summon.cd - base) < 0.01, "killed by a monster: the plain cooldown (%.1f s)" % k.summon.cd)
	ok(f.reveal_t <= 0.0 and _wisp_pings() == pings, "...no reveal and no ping")

	k = _summoned(f)
	f.downed = true
	k.hurt(k.max_hp * 5.0, p)
	ok(k.wisp and KinSteal.loose(k), "owner downed, killed by a rival: a loose wisp")
	ok(absf(k.summon.cd - base * mult) < 0.01, "...and the longer cooldown")
	KinSteal.go_home(k)
	k = _summoned(f)
	f.downed = true
	k.hurt(k.max_hp * 5.0, null)
	_frames(0.2)
	ok(k.wisp and not KinSteal.loose(k) and k.owner_h == f, "owner downed, a monster's kill: home, not loose")
	f.downed = false

	var team := p.team
	pings = _wisp_pings()
	KinNet.on_event(m, ["kcmd", "wkill", f.nid, 0.0, 0.0, 0.0, str(team + 1)])
	ok(_wisp_pings() == pings, "online: the event pings nobody else's squad")
	KinNet.on_event(m, ["kcmd", "wkill", f.nid, 0.0, 0.0, 0.0, str(team)])
	ok(_wisp_pings() == pings + 1, "online: the killer's squad gets the ping")
	k = _summoned(f)
	k.hurt(k.max_hp * 5.0, p)
	var other: Kin = m.kins.filter(func(x: Kin): return x.owner_h != null and x != k)[0]
	other.summon.left = 5.0
	KinWisp.set_wisp(other, false)
	var row: Array = []
	row.resize(KinNet.KIN_AT)
	KinNet.apply_kin(other, row + KinNet.kin_extra(k))
	ok(other.wisp and other.summon.left == 0.0 and absf(other.summon.cd - k.summon.cd) < 0.11,
		"online: the snapshot shows the killed summon as a resting wisp")
	var g: Hunter = m.hunters.filter(func(h: Hunter): return h.team != p.team and h.kin != null and not h.out)[0]
	k = _summoned(g)
	m.knock(g, p, {})
	g.down_hp = 1e6
	_frames(0.2)
	ok(g.downed and k.summon.out() and k.state != KinWispForm.STATE, "owner knocked: the summon fights on (no KinWispForm)")
