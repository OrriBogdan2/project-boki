extends RefCounted
## --boki-system-check: the Boki command system and the Merge (docs/decisions/0001). Prints PASS/FAIL lines.
##   1. G: a tap is told from a hold by the release (a hold opens the wheel); a thrown Boki's landing staggers what it lands on
##   2. Call back: the leap to your side hits what is on its path; only within the recall range
##   3. the Guard and Follow orders (the G wheel's picks; the wheel itself is in --boki-follow-check)
##   4. C: the Boki's own ability from where it stands (out), or through you (on the shoulder)
##   5. a downed Boki: stays where it fell, no C / merge while down, the owner rescues it by touch,
##      else it comes round alone after 15-20s at low health; a fall into the abyss only has the timer
##   6. nobody steals or hurts a downed Boki while its owner is in the map
##   7. the Merge: gated by the bond meter, changes your look (form) by Boki type (no tiers), leaps
##      back from out and merges mid-air, and without a Boki it is only a weak surge
##   8. the net version moved for the new snapshot shape

var bad := 0
var m: Match
var main: Node
var tags_seen: Dictionary = {}
var keep: Array = []       # the mobs a case spawned itself; any others the world makes are cleared each step

func ok(cond: bool, what: String) -> void:
	print("BOKISYS %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func _on_hit(_a: Node, _t: Node, _amt: float, tags: Array) -> void:
	for t in tags:
		tags_seen[String(t)] = int(tags_seen.get(String(t), 0)) + 1

func _fresh(species := "cindle") -> Match:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "demo_kin": species, "weapon": "rifle", "cls": "medium"})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var W = m.world
	var hx := int(floor(P.pos.x)); var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-20, 21):
		for dx in range(-30, 41):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			W.stairs.erase(i); W.walls.erase(i); W.props.erase(i); W.bush.erase(i)
	P.teleport(Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5))
	P.vel = Vector3.ZERO
	for t in ["bravery", "loyalty", "temper", "curiosity"]:
		P.kin.traits[t] = 0.5
	P.kin.trust = 60.0
	P.slot_lv["ult"] = 1
	var R: Hunter = rival()
	if R:
		R.ctrl = "idle"
		R.teleport(Vector3(P.pos.x + 38.0, P.pos.y, P.pos.z + 18.0))
	keep = []
	for i in 40:
		_clear_mobs()
		m.step(Match.DT)
	tags_seen = {}
	return m

func _clear_mobs() -> void:
	for mb in m.mobs.duplicate():
		if not keep.has(mb):
			m.mobs.erase(mb)
			mb.queue_free()

func rival() -> Hunter:
	for h in m.hunters:
		if h.team != m.player.team:
			return h
	return null

func run_for(secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		if each.is_valid(): each.call()
		_clear_mobs()
		m.step(Match.DT); t += Match.DT

func aim_at(P: Hunter, p: Vector3) -> void:
	P.inp["aim"] = p + Vector3(0, 0.9, 0); P.inp["aim_y"] = p.y

func mob_at(kind: String, at: Vector3) -> Mob:
	var mb := m.spawn_mob(kind, at)
	mb.teleport(at)
	keep.append(mb)
	return mb

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	CombatBus.hit_landed.connect(_on_hit)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bokisys-only="): only = a.substr(15)
	for part in ["poll", "throw", "recall", "modes", "cast_c", "downed", "no_steal", "merge", "leap", "surge", "net"]:
		if only == "" or only.split(",").has(part):
			call("_" + part)
	CombatBus.hit_landed.disconnect(_on_hit)
	print("BOKISYS DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ 1. G: tap and hold
func _poll() -> void:
	_fresh()
	var P := m.player
	if not InputMap.has_action("throw"):
		ok(false, "the throw action exists")
		return
	Input.action_press("throw")
	var r := KinCommand.poll(P, 0.1, false)
	Input.action_release("throw")
	r = KinCommand.poll(P, 0.016, false)
	ok(r == "tap", "a short press is a tap, judged on release (got '%s')" % r)
	Input.action_press("throw")
	var got := ""
	for i in 12:
		var x := KinCommand.poll(P, 0.05, false)
		if x != "": got = x
	var opened := KinWheel.is_open(P)
	Input.action_release("throw")
	var after := KinCommand.poll(P, 0.016, false)
	ok(got == "" and opened and after == "" and not KinWheel.is_open(P), "a long press opens the wheel, and its release is not also a tap (tap '%s', open %s, then '%s')" % [got, opened, after])

# ------------------------------------------------------------------ 1. throw: the landing staggers
func _throw() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	k.stow()
	var land := P.pos + Vector3(6.0, 0, 0)
	# a foe just to the side of the landing spot, out of the flight path itself
	var mb := mob_at("skitter", land + Vector3(0, 0, 1.3))
	var stunned := false
	var landed_d := -1.0          # how far from you it was the moment it landed (it then walks back to your side under Follow)
	aim_at(P, land)
	KinCommand.tap(P)
	ok(k.state == "flying", "G tap throws the Boki from the shoulder (state %s)" % k.state)
	for i in 70:
		_clear_mobs()
		m.step(Match.DT)
		if is_instance_valid(mb) and mb.stun_t > 0.0: stunned = true
		if landed_d < 0.0 and k.state == "active": landed_d = k.flat_dist(P)
	ok(int(tags_seen.get("land", 0)) >= 1, "the landing hits what it lands near (land hits %d)" % int(tags_seen.get("land", 0)))
	ok(stunned, "...and briefly stuns it")
	ok(k.state == "active" and landed_d > 4.0, "the Boki lands out where it was sent (%.1fm), and is out in the world (%s)" % [landed_d, k.state])

# ------------------------------------------------------------------ 2. recall: hits along the path
func _recall() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	# far beyond the recall range: the tap does not call it
	k.pos = P.pos + Vector3(40.0, 0, 0); k.state = "active"; k.fly = {}; k.hold_at = Vector3.INF
	KinCommand.tap(P)
	ok(k.state == "active", "recall only works within its range (40m: %s)" % k.state)
	k.pos = P.pos + Vector3(10.0, 0, 0); k.state = "active"; k.fly = {}; k.hold_at = Vector3.INF
	var mb := mob_at("skitter", P.pos + Vector3(5.0, 0, 0.2))
	var hp0 := mb.hp
	KinCommand.tap(P)
	ok(k.state == "flying_home", "G tap with the Boki away calls it back (state %s)" % k.state)
	var landed_d := [-1.0]
	run_for(1.2, func():
		if float(landed_d[0]) < 0.0 and k.state == "active": landed_d[0] = k.flat_dist(P))
	ok(k.state == "active" and float(landed_d[0]) >= 0.0 and float(landed_d[0]) < 3.5, "it leaps back to your side, not onto the shoulder (state %s, %.1fm at landing)" % [k.state, float(landed_d[0])])
	ok(int(tags_seen.get("recall", 0)) >= 1 and (not is_instance_valid(mb) or mb.hp < hp0), "the leap home hit what was on its path (recall hits %d)" % int(tags_seen.get("recall", 0)))

# ------------------------------------------------------------------ 3. Guard and Follow
func _modes() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	k.stow()
	aim_at(P, P.pos + Vector3(7.0, 0, 0))
	KinCommand.tap(P)
	run_for(1.0)
	ok(k.cmd == "follow" and k.hold_at == Vector3.INF, "a Boki sent out from the shoulder is out beside you (follow), not guarding")
	ok(KinCommand.order(P, "guard") and k.cmd == "guard" and k.hold_at != Vector3.INF, "the Guard order holds where it stands")
	var spot := k.pos
	P.teleport(P.pos + Vector3(0, 0, 12.0))
	run_for(2.0)
	ok(k.state == "active" and k.flat_dist(P) > 7.0 and Vector2(k.pos.x - spot.x, k.pos.z - spot.z).length() < 3.0, "guard: it stays by its spot while you move off (%.1fm from it, %.1fm from you, %s)" % [Vector2(k.pos.x - spot.x, k.pos.z - spot.z).length(), k.flat_dist(P), k.state])
	ok(KinCommand.order(P, "follow") and k.cmd == "follow" and k.hold_at == Vector3.INF, "the Follow order releases the spot")
	run_for(3.0)
	ok(k.flat_dist(P) < 5.5, "follow: it comes back to your side (%.1fm away, %s)" % [k.flat_dist(P), k.state])

# ------------------------------------------------------------------ 4. C
func _cast_c() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	k.stow()
	ok(k.state == "shoulder" and k.runner.is_ready("k1"), "setup: Boki on the shoulder, ability ready")
	aim_at(P, P.pos + Vector3(5.0, 0, 0))
	var went := KinCommand.cast_c(P)
	m.step(Match.DT)
	ok(went and not k.runner.is_ready("k1") and k.state == "shoulder", "C on the shoulder: cast through you, it stays put (state %s)" % k.state)
	_fresh()
	P = m.player
	k = P.kin
	aim_at(P, P.pos + Vector3(8.0, 0, 0))
	KinCommand.tap(P)
	run_for(1.0)
	var at := k.pos
	var out := KinCommand.cast_c(P)
	m.step(Match.DT)
	ok(out and not k.runner.is_ready("k1") and k.state != "shoulder" and k.pos.distance_to(at) < 3.0, "C with the Boki out: cast from where it stands, it does not come back (state %s, moved %.1fm)" % [k.state, k.pos.distance_to(at)])

# ------------------------------------------------------------------ 5. downed
func _downed() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	var spot := P.pos + Vector3(9.0, 0, 0)
	k.pos = spot; k.state = "active"; k.fly = {}
	k.go_down()
	ok(k.state == "downed" and k.down_total >= 14.9 and k.down_total <= 20.1, "a Boki that goes down is down for 15-20s (%.1fs)" % k.down_total)
	run_for(1.5)
	ok(k.state == "downed" and Vector2(k.pos.x - spot.x, k.pos.z - spot.z).length() < 1.0, "it stays where it fell")
	ok(not KinCommand.cast_c(P), "no C while down")
	ok(not KinMerge.can_cast(P) and not KinMerge.boki_with_you(P), "no Merge with it while down")
	ok(BokiHud.squad_downed(m).has(k), "it is marked for your squad (HUD / minimap / full map)")
	# rescue by touch
	P.teleport(Vector3(spot.x, spot.y, spot.z))
	run_for(0.25)
	ok(k.state == "downed" and k.rescue_t > 0.0 and k.rescue_on, "running into it starts the rescue (%.2fs, no key)" % k.rescue_t)
	ok(float(KinDowned.rules()["rescue_s"]) == 3.5, "the rescue takes 3.5s (data: rescue_s)")
	run_for(1.5)
	ok(k.state == "downed" and k.rescue_t > 1.0, "...it is not a scoop: 1.7s in it is still going (%.2fs)" % k.rescue_t)
	run_for(2.2)
	ok(k.state != "downed" and k.hp >= k.max_hp * 0.55, "...and at 3.5s it is back with a good chunk of health (%s, %.0f%%)" % [k.state, 100.0 * k.hp / k.max_hp])
	# the rescue is interrupted by crowd control and by a dash, not by plain damage; progress drains back instead of resetting
	k.pos = P.pos + Vector3(9.0, 0, 0); k.state = "active"; k.fly = {}
	k.go_down()
	P.teleport(Vector3(k.pos.x, k.pos.y, k.pos.z))
	run_for(1.5)
	ok(k.rescue_on and k.rescue_t > 1.0, "a second rescue is under way (%.2fs)" % k.rescue_t)
	ok(KinDowned.rescue_pose(P) == "rs_cradle", "...the rescuer cradles it (pose %s)" % KinDowned.rescue_pose(P))
	P.inp["move"] = Vector2(1, 0); P.inp["fire"] = true; P.inp["sig"] = true
	var x0 := P.pos.x
	run_for(0.3, func(): P.inp["move"] = Vector2(1, 0); P.inp["fire"] = true)
	ok(absf(P.pos.x - x0) < 0.1 and not P.used.has("fire"), "...you are rooted and can't attack while you do it")
	P.hurt(5.0, null, {"src": "test"})
	run_for(0.1)
	ok(k.rescue_on, "...plain damage does not break it")
	P.stun_t = 0.8
	run_for(0.1)
	ok(not k.rescue_on and k.rescue_t > 0.5, "...a stun does, and the progress is kept (%.2fs)" % k.rescue_t)
	var held := k.rescue_t
	run_for(0.5, func(): P.stun_t = 0.8)
	ok(k.rescue_t < held and k.rescue_t > 0.0, "...it drains back over ~2s rather than resetting (%.2f -> %.2f)" % [held, k.rescue_t])
	P.stun_t = 0.0
	run_for(0.3)
	ok(k.rescue_on, "...running into it again picks it up where it was")
	P.inp["dash"] = true
	run_for(0.1, func(): P.inp["dash"] = true)
	P.inp["dash"] = false
	ok(not k.rescue_on and k.rescue_block > 0.0, "a dash cancels it too (and it will not restart for a moment)")
	k.state = "active"; k.fly = {}
	k.go_down()

	# self-recovery
	k.pos = P.pos + Vector3(9.0, 0, 0); k.state = "active"; k.fly = {}
	k.go_down()
	var t_total := k.down_total
	run_for(t_total - 1.0)
	ok(k.state == "downed", "alone, it is still down just before its time")
	run_for(2.0)
	ok(k.state != "downed" and k.hp > 0.0 and k.hp <= k.max_hp * 0.3, "it comes round on its own at low health (%s, %.0f%%)" % [k.state, 100.0 * k.hp / k.max_hp])
	# a fall into the abyss: only the timer
	k.pos = P.pos + Vector3(9.0, 0, 0); k.state = "active"; k.fly = {}
	k.go_down(true)
	ok(k.state == "downed" and k.down_void and not KinDowned.rescuable(k), "a Boki that fell into the abyss can only wait out the timer")

# ------------------------------------------------------------------ 6. nobody takes it
func _no_steal() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	var R := rival()
	var spot := P.pos + Vector3(10.0, 0, 6.0)
	k.pos = spot; k.state = "active"; k.fly = {}
	k.go_down()
	R.teleport(Vector3(spot.x + 0.3, spot.y, spot.z))
	R.inp["interact"] = true
	var owner := k.owner_h
	run_for(4.0, func(): R.inp["interact"] = true)
	ok(k.state == "downed" and k.owner_h == owner and k.owner_h == P, "a rival standing on it, holding interact, takes nothing")
	var dealt := k.hurt(50.0, R, {})
	ok(dealt == 0.0 and k.hp <= 0.0, "...and cannot hurt it")
	ok(not BokiHud.squad_downed(m).is_empty() and R.team != k.team, "(it is still yours)")

# ------------------------------------------------------------------ 7. the Merge
func _merge() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	k.stow()
	P.ult = 0.5
	ok(KinMerge.plan(P) == "" and not KinMerge.press(P), "R does nothing on a half bond meter")
	P.ult = 1.0
	ok(KinMerge.plan(P) == "merge", "a full bond meter with the Boki returned to you merges at once")
	var pressed := KinMerge.press(P)
	ok(pressed and KinMerge.active(P) and P.ult < 0.25, "R merges and spends the meter (bond %.2f)" % P.ult)
	var form: Dictionary = P.merge_st.get("form", {})
	ok(not form.is_empty() and String(form.get("name", "")) != "", "the merge has a form: a look and a name, no tiers (%s)" % String(form.get("name", "?")))
	var looks := {}
	for sp in ["cindle", "puddlet", "mossel"]:
		if not Data.KIN.has(sp):
			continue
		_fresh(sp)
		var Q := m.player
		Q.kin.stow()
		Q.ult = 1.0
		if KinMerge.press(Q):
			var f: Dictionary = Q.merge_st.get("form", {})
			looks[sp] = "%s/%s" % [f.get("style", "?"), f.get("word", "?")]
	ok(looks.size() >= 2 and looks.values().size() > 0 and (looks.values() as Array).any(func(v): return v != looks.values()[0]), "different Boki types merge into different looks %s" % [looks])
	# the ability changes: every ability is faster for the merge's length, whatever the class
	_fresh()
	m.player.kin.stow()
	var base_cdr: float = _cdr(m.player)
	m.player.ult = 1.0
	KinMerge.press(m.player)
	ok(_cdr(m.player) > base_cdr, "merged: your abilities cool down faster (cooldown stat %.2f -> %.2f)" % [base_cdr, _cdr(m.player)])
	var torso: Node3D = m.player.model.get_node_or_null("Rig/Torso") if m.player.model else null
	run_for(float(MergeForm.data()["xform_s"]) + 0.1)       # (the silhouette pops in when the Boki lands in you, 0.45s into the transformation)
	if torso:
		ok(torso.get_node_or_null(MergeLook.PARTS_NAME) != null, "merged: the form's silhouette parts ride the torso")
	run_for(float(m.player.merge_st.get("T", 10.0)) + float(MergeForm.data()["xform_s"]) + 1.0)
	if torso:
		ok(torso.get_node_or_null(MergeLook.PARTS_NAME) == null or torso.get_node(MergeLook.PARTS_NAME).is_queued_for_deletion(), "the merge's parts are removed when it ends (no leftovers stacking up)")
	ok(not KinMerge.active(m.player) and m.player.kin.state == "shoulder", "the merge ends and the Boki is back on the shoulder (state %s)" % m.player.kin.state)
	ok(m.player.merge_cd > 0.0, "the slot rests a moment after it (%.1fs)" % m.player.merge_cd)

func _cdr(h: Hunter) -> float:
	return h.gear_stat("cdr")

# ------------------------------------------------------------------ 7. merge from out
func _leap() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	aim_at(P, P.pos + Vector3(9.0, 0, 0))
	KinCommand.tap(P)
	run_for(1.0)
	var mb := mob_at("skitter", (P.pos + k.pos) * 0.5 + Vector3(0, 0, 0.2))
	P.ult = 1.0
	ok(k.state == "active" and KinMerge.plan(P) == "leap", "a full meter with the Boki out says leap (plan '%s')" % KinMerge.plan(P))
	ok(KinMerge.press(P) and k.state == "flying_home", "R sends it leaping back to you")
	var merged_in_air := false
	for i in 90:
		m.step(Match.DT)
		if KinMerge.active(P):
			merged_in_air = true
			break
	ok(merged_in_air, "the merge starts when it lands on you")
	ok(int(tags_seen.get("recall", 0)) >= 1, "...and it hit what was in its way")
	# too far to leap
	_fresh()
	P = m.player
	P.kin.pos = P.pos + Vector3(50.0, 0, 0); P.kin.state = "active"; P.kin.fly = {}
	P.ult = 1.0
	ok(KinMerge.plan(P) == "far" and not KinMerge.press(P), "a Boki too far away must be called back first")

# ------------------------------------------------------------------ 7. a downed Boki: R waits. No Boki at all: a weak surge
func _surge() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	k.pos = P.pos + Vector3(8.0, 0, 0); k.state = "active"; k.fly = {}
	k.go_down()
	P.ult = 1.0
	ok(KinMerge.plan(P) == "rescue", "with the Boki down, R does nothing but say so (plan '%s')" % KinMerge.plan(P))
	ok(not KinMerge.press(P) and not KinMerge.active(P) and P.ult >= 1.0, "...the full meter is kept (%.2f)" % P.ult)
	ok(KinMerge.deny_text(P).begins_with("Rescue "), "...and says what to do ('%s')" % KinMerge.deny_text(P))
	run_for(2.0)
	ok(P.ult >= 1.0 and k.state == "downed", "the meter stays full while it is down")
	# no Boki with you at all (benched): the weak surge
	_fresh()
	P = m.player
	k = P.kin
	k.state = "bench"
	P.ult = 1.0
	ok(KinMerge.plan(P) == "surge", "with no Boki at all, R is a surge (plan '%s')" % KinMerge.plan(P))
	ok(KinMerge.press(P) and KinMerge.active(P) and bool(P.merge_st.get("surge", false)), "R fires the basic surge")
	ok(float(P.merge_st["T"]) <= 4.0, "...which is short and weak (%.1fs)" % float(P.merge_st["T"]))

# ------------------------------------------------------------------ 8. net
func _net() -> void:
	ok(Net.VERSION == "0.11.0", "the net version moved for the new snapshot shape (%s)" % Net.VERSION)
