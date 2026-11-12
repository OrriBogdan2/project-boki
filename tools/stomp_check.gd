extends RefCounted
## --stomp-check: the stomp (docs/decisions/0061-stomp-lock.md, Owner 2026-11-11).
##  1. Holding interact on an enemy wisp for Stomp.COMMIT commits you; letting go, moving, dashing or
##     firing does nothing after that, and neither stomper nor wisp moves, shoves and knocks included.
##  2. The stomper takes damage as usual while locked, and it doesn't break the stomp.
##  3. A stun on the stomper cancels it at once; the wisp lives and can drift again.
##  4. Left alone, the stomp kills the wisp at Stomp.TIME, not before.
##  5. Online: the stomper's game sends "go" and how it ended; a "go" from another game pins this
##     game's wisp, "broken" lets it go, "done" eliminates it here.
##  6. Styles: every Hunter has its own default (owned, all different); the unlockable can't be worn
##     until bought with gems, then the local player stomps with it and bots keep their own; a save
##     with no stomp keys reads as "wearing your own".
##  7. Per-Hunter looks (DECISIONS 2026-11-11): every style strikes on the same frames (Stomp.SLAM in
##     each beat), so sounds and hits stay in sync; Albert's hammer and Kael's sword are swung two-handed
##     overhead and down, Vex's heel comes down with the rifle aimed at the wisp, Motley keeps his feet
##     still and slams with his hands; in a match the stomper's weapon really is up, then down.
## Never touches the save.

var bad := 0
var m: Match
var foe: Hunter
var W: Hunter

func ok(cond: bool, what: String) -> void:
	print("STOMPCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run(sec: float) -> void:
	var t := 0.0
	while t < sec:
		m.step(Match.DT)
		t += Match.DT

func _spot(h: Hunter, at: Vector3) -> void:
	h.teleport(at)
	h.vel = Vector3.ZERO

## Solid ground well away from `at`.
func _far_from(at: Vector3) -> Vector3:
	var g := m.world.random_ground()
	while g.distance_to(at) < 20.0:
		g = m.world.random_ground()
	return g

## A fresh wisp at `at` with no Boki to pull it up, the stomper beside it, everyone else far away.
func _setup(at: Vector3) -> void:
	for h in m.hunters:
		if h != foe and h != W and not h.out:
			_spot(h, _far_from(at))
	if W.downed:
		m.revive_hunter(W, null)
	for kk in [W.kin, W.kin2]:
		if kk: (kk as Kin).dead = true
	foe.hp = foe.max_hp
	foe.armor = 0.0
	foe.shield = 0.0
	foe.stun_t = 0.0
	foe.launched_at = -9.0
	_spot(W, at)
	_spot(foe, at + Vector3(0.6, 0, 0))
	m.knock(W, foe, {})

## Hold interact until the stomp commits; the seconds it took.
func _commit() -> float:
	var t0 := m.time
	while foe.stomp.is_empty() and m.time - t0 < 2.0:
		foe.inp["interact"] = true
		_run(Match.DT)
	foe.inp["interact"] = false
	return m.time - t0

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 31, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.lives = 1
	foe = m.hunters.filter(func(x): return x.team != m.player.team)[0]
	W = m.hunters.filter(func(x): return x.team == m.player.team and x != m.player)[0]
	var home := m.world.random_ground()
	_check_lock(home)
	_check_stun(home + Vector3(6, 0, 0))
	_check_swing(home + Vector3(0, 0, -6))
	_check_finish(home + Vector3(-6, 0, 0))
	_check_net(home + Vector3(0, 0, 6))
	_check_styles()
	_check_looks()
	print("STOMP CHECK DONE, failures: ", bad)
	main.get_tree().quit()

func _check_lock(at: Vector3) -> void:
	_setup(at)
	var took := _commit()
	ok(not foe.stomp.is_empty() and took <= Stomp.COMMIT + 0.1, "a %.2fs hold commits the stomp" % took)
	var f0 := foe.pos
	var w0 := W.pos
	for i in 40:
		foe.inp["move"] = Vector2(1, 0)
		foe.inp["dash"] = true
		foe.inp["fire"] = true
		W.inp["move"] = Vector2(-1, 0)
		if i == 10: foe.impulse(Vector2(6, 0))       # a hit's shove
		if i == 20: W.impulse(Vector2(0, 12))        # a knock on the wisp
		_run(Match.DT)
	ok(not foe.stomp.is_empty(), "letting go, moving, dashing and firing don't end it")
	ok(foe.pos.distance_to(f0) < 0.05, "the stomper stays on the spot (moved %.3f m)" % foe.pos.distance_to(f0))
	ok(W.pos.distance_to(w0) < 0.05, "the wisp stays on the spot (moved %.3f m)" % W.pos.distance_to(w0))
	ok(foe.roll_t <= 0.0, "no dodge mid-stomp")
	var hp0 := foe.hp
	foe.hurt(20.0, m.player, {})
	_run(Match.DT)
	ok(foe.hp < hp0 - 10.0 and not foe.stomp.is_empty(),
		"damage lands on the stomper (%.0f -> %.0f) and the stomp holds" % [hp0, foe.hp])
	Stomp.end(m, foe, "gone")

func _check_stun(at: Vector3) -> void:
	_setup(at)
	_commit()
	_run(1.0)
	foe.hurt(5.0, m.player, {"stun": 0.6})
	_run(Match.DT)
	ok(foe.stomp.is_empty(), "a stun cancels the stomp")
	ok(W.downed and not W.out and not W.has_meta("stomped_by"), "the wisp survives the cancelled stomp and is let go")
	_spot(foe, at + Vector3(30, 0, 0))
	var w0 := W.pos
	for i in 30:
		W.inp["move"] = Vector2(1, 0)
		_run(Match.DT)
	ok(W.downed and not W.out and W.pos.distance_to(w0) > 0.2, "...and drifts again (%.2f m)" % W.pos.distance_to(w0))

func _check_finish(at: Vector3) -> void:
	_setup(at)
	_commit()
	var t0 := m.time
	while not W.out and m.time - t0 < Stomp.TIME + 1.0:
		_run(Match.DT)
	var took := m.time - t0
	ok(W.out and String(W.get_meta("died_why", "")) == "executed", "left alone the stomp executes the wisp")
	ok(absf(took - Stomp.TIME) <= 0.05, "at %.2fs (Stomp.TIME %.1fs)" % [took, Stomp.TIME])
	ok(foe.stomp.is_empty(), "and the stomper is free again")

func _check_net(at: Vector3) -> void:
	# the last wisp was executed (a knock now would wipe its team): the player stomps a rival instead
	W = m.hunters.filter(func(x): return x.team != m.player.team and x != foe)[0]
	foe = m.player
	_setup(at)
	# this game's stomper tells the others
	m.net_on = true
	Net.out_events.clear()
	Stomp.start(m, foe, W)
	Stomp.end(m, foe, "broken")
	var sent: Array = Net.out_events.filter(func(e): return e[0] == "stomp")
	m.net_on = false
	ok(sent.size() == 2 and sent[0][3] == "go" and sent[0][4] == StompLook.style_id(foe) and sent[1][3] == "broken",
		"a stomp sends \"go\" with its style and how it ended (%s)" % [sent])
	Net.out_events.clear()
	# another game's stomper on this game's wisp
	foe.remote = true
	Stomp.net_in(m, ["stomp", foe.nid, W.nid, "go", "thunder_stomp"])
	var w0 := W.pos
	for i in 20:
		W.inp["move"] = Vector2(1, 0)
		_run(Match.DT)
	var pinned: bool = W.has_meta("stomped_by") and W.get_meta("stomped_by") == foe and W.pos.distance_to(w0) < 0.05
	ok(pinned and foe.stomp["style"] == "thunder_stomp",
		"a \"go\" from another game pins this game's wisp, in the sender's style")
	Stomp.net_in(m, ["stomp", foe.nid, W.nid, "broken"])
	ok(foe.stomp.is_empty() and W.downed and not W.out and not W.has_meta("stomped_by"),
		"a \"broken\" lets it go alive")
	Stomp.net_in(m, ["stomp", foe.nid, W.nid, "go", ""])
	_run(0.5)
	Stomp.net_in(m, ["stomp", foe.nid, W.nid, "done"])
	ok(W.out and String(W.get_meta("died_why", "")) == "executed", "a \"done\" executes this game's wisp")
	foe.remote = false

func _check_styles() -> void:
	var seen := {}
	for f in DirAccess.get_files_at("res://content/archetypes"):
		var arch := String(f).get_basename()
		var sid := StompLook.default_for(arch)
		var st := StompLook.style(sid)
		var key := JSON.stringify(st.duplicate().merged({"name": "", "hunter": ""}, true))
		ok(sid != "" and StompLook.owned(sid) and not seen.has(key), "%s stomps its own way: %s" % [arch, sid])
		seen[key] = true
	ok(StompLook.equipped() == "" and StompLook.style_id(m.player) == StompLook.default_for(m.player.arch),
		"a save with no stomp keys wears the Hunter's own")
	ok(not StompLook.owned("thunder_stomp") and not StompLook.equip("thunder_stomp"), "the unlockable isn't yours yet")
	Save.d["gems"] = 100
	ok(not StompLook.buy("thunder_stomp"), "it can't be bought without the gems")
	Save.d["gems"] = 1000
	ok(StompLook.buy("thunder_stomp") and int(Save.d["gems"]) == 700 and StompLook.equip("thunder_stomp"),
		"bought for 300 gems and worn")
	m.player.ctrl = "local"
	ok(StompLook.style_id(m.player) == "thunder_stomp" and StompLook.style_id(W) == StompLook.default_for(W.arch),
		"the player stomps in it; a bot keeps its own")
	var a := StompLook.legs(StompLook.style("thunder_stomp"), 0.4)
	var b := StompLook.legs(StompLook.style(StompLook.default_for("archer")), 0.4)
	ok(a.distance_to(b) > 0.2, "styles pose differently mid-lift")

func _check_looks() -> void:
	var off := []
	for id in StompLook.rules()["styles"]:
		var st := StompLook.style(id)
		for b in Stomp.BEATS:
			if StompLook.strike(st, b + Stomp.SLAM) > 0.01 or StompLook.strike(st, b + Stomp.SLAM * 0.5) < 0.5:
				off.append("%s beat %d" % [id, b])
	ok(off.is_empty(), "every style strikes on Stomp.SLAM of each beat and is up between %s" % str(off))
	for arch in ["bulwark", "juggernaut"]:
		var st := StompLook.style(StompLook.default_for(arch))
		var top: Variant = StompLook.weapon(st, Stomp.SLAM * 0.65)
		var hit: Variant = StompLook.weapon(st, Stomp.SLAM)
		var legs := StompLook.legs(st, Stomp.SLAM * 0.5)
		var swung := top != null and StompLook.two_hands(st) and _point(top) > 0.3 and _point(hit) < -0.7
		ok(swung and legs.x == legs.z, "%s swings the weapon in both hands, up (%.2f) and down (%.2f), feet planted"
			% [arch, _point(top), _point(hit)])
	var vex := StompLook.style(StompLook.default_for("gunslinger"))
	var vl := StompLook.legs(vex, Stomp.SLAM * 0.5)
	ok(StompLook.weapon(vex, 0.0) != null and _point(StompLook.weapon(vex, Stomp.SLAM)) < -0.7 and vl.z > 1.0
		and not StompLook.two_handed(vex), "Vex: a boot heel high (hip %.2f), the rifle kept and aimed down" % vl.z)
	var mot := StompLook.style(StompLook.default_for("ostra"))
	var ml := StompLook.legs(mot, Stomp.SLAM * 0.5)
	var rise := StompLook.body(mot, Stomp.SLAM * 0.5).z
	var palm := StompLook.hand(mot, Stomp.SLAM, Vector3.ZERO, -1.0)
	ok(ml.x == ml.z and ml.x < 0.3 and rise > 0.3 and palm.y < -0.4 and mot["arms"] == "cast",
		"Motley floats: no foot lifts, he rises %.2f m and his palms push down on the slam" % rise)

## How far a weapon transform's forward (-Z) points up (1) or down (-1); 0 for none.
func _point(tf: Variant) -> float:
	return -(tf as Transform3D).basis.z.y if tf != null else 0.0

## A live stomp in Albert's style: HunterAnim really raises the weapon and brings it down on the slam.
func _check_swing(at: Vector3) -> void:
	_setup(at)
	_commit()
	if foe.stomp.is_empty():
		ok(false, "a stomp commits for the live swing")
		return
	foe.stomp["style"] = StompLook.default_for("bulwark")
	var gun_at := func() -> float:
		var g := foe.anim.gun if foe.anim else null
		return -g.transform.basis.z.normalized().y if g else 0.0
	while float(foe.stomp.get("t", 9.0)) < (1.0 + Stomp.SLAM * 0.65) * Stomp.TIME / Stomp.BEATS:
		_run(Match.DT)
		foe.render(Match.DT, 1.0)
	var top: float = gun_at.call()
	while float(foe.stomp.get("t", 9.0)) < (1.0 + Stomp.SLAM) * Stomp.TIME / Stomp.BEATS:
		_run(Match.DT)
		foe.render(Match.DT, 1.0)
	var hit: float = gun_at.call()
	ok(foe.anim != null and top > 0.3 and hit < -0.5,
		"in a match the stomper's weapon is up at the top (%.2f) and down on the slam (%.2f)" % [top, hit])
	Stomp.end(m, foe, "gone")
