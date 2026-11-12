extends RefCounted
## --hp-regen-check: Hunter out-of-combat regen at source values (content/rules/boki_system.json "regen").
## The source gives no Hunter health regen of its own, so each of the 12 Hunters with no Boki points
## stays hurt; Boki owner_regen heals hp/s (Blight cuts it, none while downed) and shows as the health
## bar filling; the owner_shield refill waits out the combat window (InCombat) after a hit (a Hunter's, a
## monster's or Blight's) or a hit dealt, then fills owner_shield_pct_s a second; armour never
## refills. Never touches the save.

const ARCHS := ["bulwark", "dredge", "thief", "mage", "dolm", "ostra", "ashwick", "juggernaut", "archer",
	"tender", "gunslinger", "rimewright"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HPREGEN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## Steps the match with no monsters about (lairs and the Blight keep spawning them), so the only
## damage is what a case deals on purpose.
func _run_for(m: Match, secs: float) -> void:
	for i in int(round(secs / Match.DT)):
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(Match.DT)

func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false})
	m.set_process(false)
	var P: Hunter = m.player
	var foe: Hunter = null
	for o in m.hunters:
		o.ctrl = "idle"
		if o != P and o.team != P.team and foe == null: foe = o
	for o in m.hunters:
		if o != P: o.teleport(m.world.random_ground())
	var rr := KinRegen.rules()
	var wait := InCombat.window()
	# (a) source parity: no Hunter heals on its own, however long it stays out of a fight (its Boki
	# benched, so nothing it does is a heal on hit: dmg_done must not move)
	var k: Kin = P.kin
	k.bench()
	for a in ARCHS:
		P.set_arch(a)
		P.kin_bonus = {}
		P.hp = P.max_hp
		P.hurt(P.max_hp * 0.4, foe)
		var miss0 := P.max_hp - P.hp       # (missing health: a level-up adds to max and current alike)
		var dealt := P.dmg_done
		_run_for(m, 12.0)
		var miss1 := P.max_hp - P.hp
		ok(P.dmg_done == dealt, "(a) %s: stays out of a fight (dealt %.1f)" % [a, P.dmg_done - dealt])
		var why := "(a) %s: no regen of its own 12s after a hit (missing %.1f -> %.1f)" % [a, miss0, miss1]
		ok(miss0 > 1.0 and absf(miss1 - miss0) < 0.01, why)
	k.unbench()
	k.state = "active"
	k.cmd = "follow"
	k.settle = 1.0
	k.target = null
	# (b) a Boki's owner_regen: that many hp/s at once, the bar fills at that pace; Blight cuts it
	P.kin_bonus = {"owner_regen": 4.0}
	P.hp = P.max_hp * 0.5
	var b0 := P.hp
	_run_for(m, 2.0)
	ok(absf((P.hp - b0) / 2.0 - 4.0) < 0.3, "(b) owner_regen 4: %.2f hp/s (want 4)" % ((P.hp - b0) / 2.0))
	var fills := "(b) the health bar's fill rises with it (%.3f -> %.3f)" % [b0 / P.max_hp, P.hp / P.max_hp]
	ok(P.hp / P.max_hp > b0 / P.max_hp, fills)
	P.blight_t = 10.0
	var b1 := P.hp
	_run_for(m, 2.0)
	var want := 4.0 * (1.0 - P.blight_k)
	ok(absf((P.hp - b1) / 2.0 - want) < 0.3, "(b) under Blight: %.2f hp/s (want %.2f)" % [(P.hp - b1) / 2.0, want])
	P.blight_t = 0.0
	# (c) the owner_shield: waits out the combat window after any hit, then fills at the data rate
	P.kin_bonus = {"owner_shield": 40.0}
	P.kin_shield = 0.0
	P.hp = P.max_hp
	P.hurt(5.0, foe)
	P.kin_shield = 0.0
	_run_for(m, wait - 0.5)
	ok(P.kin_shield < 0.01, "(c) no shield refill in the first %.1fs after a hit (%.2f)" % [wait - 0.5, P.kin_shield])
	_run_for(m, 1.0)
	var s0 := P.kin_shield
	_run_for(m, 0.5)
	var rate := (P.kin_shield - s0) / 0.5 / 40.0
	var pct := float(rr["owner_shield_pct_s"])
	ok(absf(rate - pct) < 0.03, "(c) after %.1fs it fills %.2f of its size/s (want %.2f)" % [wait, rate, pct])
	P.kin_shield = 0.0
	foe.hurt(5.0, P)
	_run_for(m, wait - 0.5)
	ok(P.kin_shield < 0.01, "(c) dealing damage restarts the wait too (%.2f after %.1fs)" % [P.kin_shield, wait - 0.5])
	var src_cases := [["a monster's hit", null, {"src": "mob"}], ["Blight damage", null, {"src": "blight"}]]
	for sc in src_cases:
		_run_for(m, 4.0)
		P.kin_shield = 0.0
		P.hurt(5.0, sc[1], sc[2])
		_run_for(m, wait - 0.5)
		ok(P.kin_shield < 0.01, "(c) %s restarts the wait (%.2f after %.1fs)" % [sc[0], P.kin_shield, wait - 0.5])
	# (d) downed: a Hunter gets nothing, even with owner_regen
	P.kin_bonus = {"owner_regen": 4.0}
	P.downed = true
	P.hp = P.max_hp * 0.3
	var dn := P.hp
	_run_for(m, 0.5)
	P.downed = false
	ok(P.hp <= dn + 0.01, "(d) downed: no owner_regen (%.2f -> %.2f)" % [dn, P.hp])
	# (e) armour never refills on its own
	P.kin_bonus = {}
	ok(P.max_armor > 0.5 or P.armor <= 0.0, "(e) has an armour bar to test (max %.1f)" % P.max_armor)
	if P.max_armor > 0.5:
		P.armor = P.max_armor * 0.5
		var a0 := P.armor
		_run_for(m, 15.0)
		ok(absf(P.armor - a0) < 0.01, "(e) armour stays at %.1f after 15s out of a fight (%.1f)" % [a0, P.armor])
	print("HPREGEN DONE, failures: ", bad)
	main.get_tree().quit()
