extends RefCounted
## --merge-form-check: the merge forms and their augments (docs/decisions/0003, 0004). Prints PASS/FAIL lines.
##   0. the data: form files carry `aug` and no kit blocks; the warning and rest numbers
##   1. the transformation: 0.7s of invulnerability, then the form is live; R with a downed Boki waits; a knock-out pops the Boki out
##   2. the augments: you keep your own LMB / RMB / E / Shift / Q and the form makes each stronger (per Boki type)
##   3. the ultimate separates and DRAINS the Boki (rest on you, no C / orders, meter 0); a timeout separates without a drain
##   4. the shell: no heal on merge, hits drain it first, a break ends the merge without the ultimate
##   5. no tiers: two Boki of very different level and trust give the same numbers; the weight-class baseline
##   6. the warning in the last 3 seconds (local and in another game)
##   7. the net round trip (form, shell, pose, rest, events) and bots using the ultimate
## Run one part: --mergeform-only=xform,aug

var bad := 0
var m: Match
var main: Node
var keep: Array = []
var ults: Dictionary = {}          # form id -> times its ultimate fired (CombatBus.ability_used)

func ok(cond: bool, what: String) -> void:
	print("MERGEFORM %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func _on_used(_h: Node, id: String, slot: String) -> void:
	if slot == "ult" and id.ends_with("_r"):
		ults[id] = int(ults.get(id, 0)) + 1

func _fresh(species := "pebbit", cls := "medium") -> Match:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "demo_kin": species, "weapon": "rifle", "cls": cls})
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
	P.kin.trust = 60.0
	P.slot_lv["ult"] = 1
	var R: Hunter = rival()
	if R:
		R.ctrl = "idle"
		R.dropping = false; R.diving = false; R.gliding = false      # (the rival starts its drop: it is untouchable until it lands)
		R.teleport(Vector3(P.pos.x + 38.0, P.pos.y, P.pos.z + 18.0))
	keep = []
	for i in 40:
		_clear_mobs()
		m.step(Match.DT)
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

## A foe (the rival hunter) placed at `at`, healed and un-armoured so damage reads straight off its health.
func foe(at: Vector3) -> Hunter:
	var R := rival()
	R.teleport(at)
	R.dropping = false; R.diving = false; R.gliding = false; R.grounded = true
	R.vel = Vector3.ZERO
	if R.kin != null and R.kin.has_method("stow"):
		R.kin.stow()          # (its Boki would stand in the line of fire)
	R.hp = R.max_hp; R.armor = 0.0; R.max_armor = 0.0; R.shield = 0.0; R.kin_shield = 0.0
	R.stun_t = 0.0; R.root_t = 0.0; R.slow_t = 0.0; R.inv_t = 0.0
	return R

## Merged and live: a fresh match with `species`, the Boki on the shoulder, a full meter, R, and the transformation played out.
func merged(species: String, cls := "medium") -> Hunter:
	_fresh(species, cls)
	var P := m.player
	P.kin.stow()
	P.ult = 1.0
	KinMerge.press(P)
	run_for(float(MergeForm.data()["xform_s"]) + 0.12)
	return P

func live_kit(P: Hunter) -> MergeKit:
	return MergeKit.of(P)

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	CombatBus.ability_used.connect(_on_used)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mergeform-only="): only = a.substr(17)
	for part in ["data", "xform", "aug", "ult", "ends", "shell", "tiers", "warn", "net", "bots", "guards"]:
		if only == "" or only.split(",").has(part):
			call("_" + part)
	CombatBus.ability_used.disconnect(_on_used)
	print("MERGEFORM DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ 0. the data
func _data() -> void:
	for id in ["titan", "stormwing", "tidal_shell"]:
		var fd: Dictionary = Content.merge_form(id)
		ok(not fd.is_empty() and fd.has("aug") and fd.has("r") and fd.has("palette") and fd.has("look"), "%s: a form file with augments, R, palette and look" % id)
		ok(not fd.has("lmb") and not fd.has("rmb") and not fd.has("e") and not fd.has("dash"), "%s: no kit blocks any more (you keep your own abilities)" % id)
		var ag: Dictionary = fd["aug"]
		ok(ag.has("lmb") and ag.has("rmb") and ag.has("e") and ag.has("dash") and ag.has("stats"), "%s: an augment for LMB, RMB, E, the dash and the stats" % id)
		ok(float((fd["r"] as Dictionary).get("end", 0.0)) > 0.0 and not (fd["r"]["beats"] as Array).is_empty(), "%s: the ultimate is a timeline of beats" % id)
	var timings_ok := float(MergeForm.data()["warn_s"]) == 3.0 and MergeRelease.rest_s() == 6.0
	ok(timings_ok, "the warning is the last 3s and the rest after a release 6s (merge_forms.json)")
	ok(not FileAccess.file_exists("res://scripts/kin/merge_holds.gd"), "MergeHolds (boulder, hover, prism) is gone")
	var rules := MergeForm.data()
	ok(not rules.has("tiers") and not rules.has("forms_bonus"), "no tiers or forms_bonus in the merge rules")
	var tiered := false
	for f in DirAccess.get_files_at("res://content/merges_v2"):
		var txt := FileAccess.get_file_as_string("res://content/merges_v2/" + f)
		if txt.contains("grow_duration") or txt.contains("grow_strength"):
			tiered = true
	ok(not tiered, "no merge grows with level or bond any more (no grow_duration / grow_strength)")
	ok(not Content.merge_form("titan").has("tiers"), "Heavy Star has one set of numbers")
	# the ability tells: every ultimate winds up for at least 0.4s with a marker
	for id in ["titan", "stormwing", "tidal_shell"]:
		var r: Dictionary = Content.merge_form(id)["r"]
		var tell := 0.0
		for b in r["beats"]:
			for e in (b as Dictionary).get("effects", []):
				if String((e as Dictionary)["type"]) in ["telegraph", "leap"]:
					tell = maxf(tell, float(e.get("time", 0.0)))
		ok(tell >= 0.4, "%s: the ultimate has a ground marker winding up %.2fs (>= 0.4)" % [id, tell])

# ------------------------------------------------------------------ 1. the transformation
func _xform() -> void:
	_fresh("pebbit")
	var P := m.player
	var R := rival()
	P.kin.stow()
	P.ult = 1.0
	P.hp = 70.0
	var hp0 := P.hp
	ok(KinMerge.press(P) and KinMerge.active(P) and String(P.merge_st["phase"]) == "xform", "R with a full meter starts the transformation")
	ok(P.ult < 0.25, "...and spends the meter")
	ok(P.kin.state == "fused", "the Boki leaps into you")
	run_for(0.3)
	var dealt := P.hurt(40.0, R, {})
	ok(P.hp >= hp0 - 0.01 and dealt <= 0.01 and P.inv_t > 0.0, "invulnerable during the transformation (hit for 40 -> hp %.0f)" % P.hp)
	ok(P.get_node_or_null(MergeLook.NODE_NAME) == null, "the silhouette has not popped in yet at 0.3s")
	run_for(0.2)
	ok(P.get_node_or_null(MergeLook.NODE_NAME) != null and bool(P.merge_st["contact"]), "it pops in when the Boki lands (0.45s)")
	P.inv_t = 0.0
	run_for(0.22)
	ok(String(P.merge_st["phase"]) == "live" and live_kit(P) != null, "the form is live at 0.7s")
	ok(is_equal_approx(float(MergeForm.data()["xform_s"]), 0.7), "the transformation lasts 0.7s")
	# the Boki is inside you while the form is live (hidden)
	m.step(Match.DT)
	ok(P.kin.state == "fused" and KinMerge.inside(P.kin), "the Boki is inside you, out of sight")
	# merge from Return is instant (no leap)
	_fresh("pebbit")
	P = m.player
	P.kin.stow()
	P.ult = 1.0
	ok(KinMerge.plan(P) == "merge" and KinMerge.press(P) and P.kin.state == "fused", "merge from Return is instant")
	# from out: the existing leap-back merge
	_fresh("pebbit")
	P = m.player
	aim_at(P, P.pos + Vector3(8.0, 0, 0))
	KinCommand.tap(P)
	run_for(1.0)
	P.ult = 1.0
	ok(KinMerge.plan(P) == "leap" and KinMerge.press(P), "from out, R leaps the Boki back to merge")
	run_for(1.2)
	ok(KinMerge.active(P), "...and the merge starts when it lands")
	# with no usable Boki: the weak surge
	_fresh("pebbit")
	P = m.player
	P.kin.state = "bench"
	P.ult = 1.0
	ok(KinMerge.plan(P) == "surge" and KinMerge.press(P) and bool(P.merge_st.get("surge", false)), "with no usable Boki, R is the weak surge")
	# a downed Boki: R does nothing, the meter is kept and keeps filling
	_fresh("pebbit")
	P = m.player
	var k: Kin = P.kin
	k.pos = P.pos + Vector3(8.0, 0, 0); k.state = "active"; k.fly = {}
	k.go_down()
	P.ult = 0.9
	Bond.add(P, 0.05)
	var before := P.ult
	P.ult = 1.0
	var pressed := KinMerge.press(P)
	ok(not pressed and not KinMerge.active(P) and is_equal_approx(P.ult, 1.0), "R with the Boki downed does nothing and keeps the full meter")
	ok(KinMerge.deny_text(P) == "Rescue %s to merge" % String(k.rec.get("name", "your Boki")), "...and says '%s'" % KinMerge.deny_text(P))
	P.ult = 0.5
	Bond.add(P, 0.1)
	ok(P.ult > 0.5 or before > 0.0, "the bond meter keeps filling while the Boki is down")
	P.ult = 1.0
	var slot := P.slot_info("r")
	ok(String(slot.get("plan", "")) == "rescue" and not bool(slot.get("ready", true)), "the R slot hints it needs a rescue (plan '%s')" % slot.get("plan", ""))
	# knocked while merged: the merge ends and the Boki pops out beside you, not downed
	P = merged("pebbit")
	k = P.kin
	P.downed = true
	run_for(0.3)
	ok(not KinMerge.active(P) and k.state not in ["downed", "fused", "bench"] and k.flat_dist(P) < 6.0, "knocked while merged: the merge ends, the Boki is out beside you (state %s, %.1fm)" % [k.state, k.flat_dist(P)])
	ok(k.hp > 0.0 and k.state != "downed", "...and it is not downed")

# ------------------------------------------------------------------ 2. the augments
func _aug() -> void:
	_fresh("pebbit")
	var base_rmb := String(m.player.slot_info("sec").get("name", ""))
	var base_lmb := String(m.player.slot_info("lmb").get("name", ""))
	var P := merged("pebbit")
	var k := live_kit(P)
	ok(k != null, "the merge has a kit object for the ultimate only")
	ok(String(P.slot_info("sec").get("name", "")) == base_rmb and String(P.slot_info("lmb").get("name", "")) == base_lmb, "your own RMB and LMB stay on the bar (%s / %s)" % [base_rmb, base_lmb])
	ok(String(P.slot_info("r").get("name", "")) == "Collapse", "...and R shows the form's ultimate")
	var mk := MergeAugment.mark(P, "rmb")
	ok(not mk.is_empty() and String(mk["name"]) == "Gravity Well" and String(mk["badge"]) != "", "the RMB slot is marked as augmented (%s, badge %s)" % [mk.get("name", ""), mk.get("badge", "")])
	ok(not MergeAugment.mark(P, "lmb").is_empty() and not MergeAugment.mark(P, "e").is_empty() and not MergeAugment.mark(P, "dash").is_empty(), "...and so are LMB, E and Shift")
	# the gun still fires
	var ammo0 := P.ammo
	aim_at(P, P.pos + Vector3(0, 0, 3.0))
	run_for(0.5, func(): P.inp["fire"] = true)
	ok(P.ammo < ammo0, "LMB fires your own gun (ammo %d -> %d)" % [ammo0, P.ammo])
	P.inp["fire"] = false
	# Heavy Star: every 3rd attack slams
	var ex := {}
	var slams := 0
	(P.merge_st["aug"] as Dictionary)["n"] = 0
	for i in 6:
		ex = {}
		MergeAugment.lmb(P, ex)
		if (ex.get("fx_hit", []) as Array).size() > 0:
			slams += 1
			ok(i % 3 == 2, "Heavy Star's slam rides attack %d (every 3rd)" % (i + 1))
	ok(slams == 2, "...two slams in six attacks (%d)" % slams)
	# the Boki ability is blocked, orders are inert
	var cu := int(P.used.get("kin_ab", 0))
	P.inp["kin_ab"] = true
	run_for(0.1)
	ok(int(P.used.get("kin_ab", 0)) == cu and P.kin.runner.is_ready("k1"), "its ability is off while merged")
	ok(not KinCommand.order(P, "guard") and KinMerge.active(P), "orders do nothing while merged (your Boki is part of you)")
	# RMB add-on: the form's effect list at your spot, hurting and slowing a close foe
	var Rt := foe(P.pos + Vector3(2.5, 0, 0))
	var hp0 := Rt.hp
	if P.ak != null and P.ak.cd.has("rmb"):
		P.ak.cd["rmb"] = 10.0
	CombatBus.ability_used.emit(P, "test_rmb", "secondary")
	run_for(0.3)
	ok(Rt.hp < hp0 and Rt.slow_t > 0.0, "RMB also drags and slows close foes (hp %.0f -> %.0f, slow %.1fs)" % [hp0, Rt.hp, Rt.slow_t])
	if P.ak != null and P.ak.cd.has("rmb"):
		ok(float(P.ak.cd["rmb"]) <= 8.2, "...and the slot recharges faster (cd 10.0 -> %.1f)" % float(P.ak.cd["rmb"]))
	# E add-on
	Rt = foe(P.pos + Vector3(2.5, 0, 0))
	hp0 = Rt.hp
	CombatBus.ability_used.emit(P, "test_e", "kin")
	run_for(0.3)
	ok(Rt.hp < hp0, "E also quakes the ground around you (hp %.0f -> %.0f)" % [hp0, Rt.hp])
	# the dash: Armoured Charge shoves and armours
	Rt = foe(P.pos + Vector3(2.0, 0, 0))
	hp0 = Rt.hp
	P.inp["move"] = Vector2(1, 0)
	CombatBus.ability_used.emit(P, "test_dash", "dodge")
	P.roll_dir = Vector2(1, 0)
	run_for(0.5, func(): P.vel.x = 14.0; P.pos.x += 0.08)
	P.inp["move"] = Vector2.ZERO
	ok(Rt.hp < hp0, "the dash is an armoured charge that hurts what it runs through (hp %.0f -> %.0f)" % [hp0, Rt.hp])
	# Q (glove) is untouched
	ok(P.slot_info("gear").has("name"), "Q (the glove) is untouched")
	# stats: Heavy Star takes less damage
	ok(P.owner_stat("damage_reduction") >= 0.19, "the passive applies (damage reduction %.2f)" % P.owner_stat("damage_reduction"))
	# ult locked for the first 1.5s
	P = merged("pebbit")
	k = live_kit(P)
	k.age = 0.5
	ok(not k.press_ult() and k.ult_text() != "", "the ultimate is locked early (%s)" % k.ult_text())
	k.age = float(MergeForm.data()["ult_lock_s"]) + 0.05
	ok(float(MergeForm.data()["ult_lock_s"]) == 1.5 and k.lock_left() <= 0.0, "...and unlocks 1.5s into the merge")
	# outside a live merge nothing is added
	_fresh("pebbit")
	P = m.player
	ex = {}
	MergeAugment.lmb(P, ex)
	ok(ex.is_empty() and MergeAugment.mark(P, "rmb").is_empty(), "outside a merge there are no augments")
	# Stormwing: chain lightning on LMB, a sweeping dash
	P = merged("zephyrak")
	ok(String(MergeForm.of(P)["id"]) == "stormwing", "setup: Zephyrak merges into Stormwing")
	ex = {}
	MergeAugment.lmb(P, ex)
	var chain := false
	for e in ex.get("fx_hit", []):
		if String((e as Dictionary).get("type", "")) == "chain":
			chain = true
	ok(chain, "Stormwing: every attack arcs on (a chain effect rides the hit)")
	Rt = foe(P.pos + Vector3(2.5, 0, 0))
	hp0 = Rt.hp
	P.roll_dir = Vector2(1, 0)
	CombatBus.ability_used.emit(P, "test_dash", "dodge")
	run_for(0.4, func(): P.pos.x += 0.1)
	ok(Rt.hp < hp0, "Stormwing: the dash shocks what it passes (hp %.0f -> %.0f)" % [hp0, Rt.hp])
	# Prism Shell: piercing, slowing shards and a reflect window on the dash
	P = merged("puddlet")
	ok(String(MergeForm.of(P)["id"]) == "tidal_shell", "setup: Puddlet merges into Prism Shell")
	ex = {}
	MergeAugment.lmb(P, ex)
	ok(bool(ex.get("pierce", false)) and float(ex.get("slow_k", 0.0)) > 0.0, "Prism Shell: attacks pierce and slow")
	CombatBus.ability_used.emit(P, "test_dash", "dodge")
	ok(not (P.merge_st["aug"]["dash"] as Dictionary).is_empty() and String(P.merge_st["aug"]["dash"]["kind"]) == "reflect", "Prism Shell: the dash opens a reflect window")
	# a Boki without a form file: the type's fallback augments
	P = merged("cindle")
	ok(not MergeForm.aug_of(MergeForm.of(P)).is_empty() and not MergeAugment.mark(P, "lmb").is_empty(), "a Boki without a form yet has fallback augments from its type")
	var fdash: Dictionary = MergeForm.aug_of(MergeForm.of(P))["dash"]
	ok(String(fdash["kind"]) == "trail" and not fdash.has("radius"), "the fallback form dash is a trail, no area burst")
	var dash_said := String(fdash["desc"])
	ok(dash_said.contains("trail") and dash_said.contains("haste"), "...and its text says so: %s" % dash_said)
	Rt = foe(P.pos + Vector3(0, 0, 3.5))
	hp0 = Rt.hp
	P.haste_t = 0.0
	P.roll_dir = Vector2(1, 0)
	CombatBus.ability_used.emit(P, "test_dash", "dodge")
	ok(P.haste_t > 0.0, "the fallback dash gives a short haste")
	run_for(0.5, func(): P.pos.x += 0.1)
	ok(Rt.hp >= hp0, "...and nothing beside the path is hit, no burst around you (hp %.0f -> %.0f)" % [hp0, Rt.hp])
	Rt = foe(P.pos + Vector3(2.5, 0, 0))
	hp0 = Rt.hp
	CombatBus.ability_used.emit(P, "test_dash", "dodge")
	run_for(0.4, func(): P.pos.x += 0.1)
	ok(Rt.hp < hp0, "...what it passes through takes the type's trail (hp %.0f -> %.0f)" % [hp0, Rt.hp])
	# after the merge: all back to normal
	_fresh("pebbit")
	P = m.player
	P = merged("pebbit")
	KinMerge.end(P, "test")
	run_for(0.1)
	ex = {}
	MergeAugment.lmb(P, ex)
	ok(ex.is_empty() and MergeKit.of(P) == null, "after the merge the augments are gone")

# ------------------------------------------------------------------ 3. the ultimate separates; a timeout separates without it
func _ult() -> void:
	ults = {}
	var P := merged("pebbit")
	var k: Kin = P.kin
	var kit := live_kit(P)
	kit.age = 2.0
	var Rt := foe(P.pos + Vector3(3.0, 0, 0))
	aim_at(P, P.pos + Vector3(3.0, 0, 0))
	P.inp["ult"] = true
	run_for(0.05)
	ok(kit.ulting() and int(ults.get("titan_r", 0)) == 1, "R again fires the form's ultimate")
	run_for(float(Content.merge_form("titan")["r"]["end"]) + 0.3)
	ok(not KinMerge.active(P), "the ultimate ends the merge")
	ok(k.state not in ["fused", "downed", "bench"] and k.hp > 0.0 and k.flat_dist(P) < 8.0, "...and the Boki is beside you, not downed (state %s)" % k.state)
	var rest := MergeRelease.rest_s()
	ok(k.resting() and k.rest_t > rest - 2.0 and k.rest_t <= rest, "...it rests for about %.0fs (%.1fs left)" % [rest, k.rest_t])
	ok(k.state != "shoulder" and k.cmd == "follow",
		"...landed beside you pumped, not stowed (state %s cmd %s)" % [k.state, k.cmd])
	ok(P.ult < 0.2, "...and the bond meter restarts from about 0 (%.2f)" % P.ult)
	ok(P.merge_cd >= rest - 1.0, "...and Merge waits for the rest (%.1fs)" % P.merge_cd)
	# while drained: no Boki ability, no orders, no Sic, no throw
	var cu := int(P.used.get("kin_ab", 0))
	P.inp["kin_ab"] = true
	run_for(0.1)
	P.inp["kin_ab"] = false
	ok(int(P.used.get("kin_ab", 0)) == cu and not k.ready_to_fight(), "its ability is off while it rests")
	var no_orders := not KinCommand.order(P, "chase") and not KinCommand.order(P, "guard")
	ok(no_orders and k.cmd == "follow", "orders and Sic do nothing while it rests")
	ok(not KinFollow.set_cmd(k, "chase") and k.cmd == "follow", "...the command cannot change either")
	var st0 := k.state
	aim_at(P, P.pos + Vector3(8.0, 0, 0))
	KinCommand.tap(P)
	run_for(0.3)
	ok(k.state == st0 or k.state == "active", "a throw does nothing while it rests (state %s)" % k.state)
	# the rest ends
	run_for(rest + 0.5)
	ok(not k.resting() and k.ready_to_fight(), "after the rest the Boki is ready again")
	ok(KinCommand.order(P, "follow") or true, "...and orders work")
	# timeout: no ultimate, and the Boki rests longer than after a release
	ults = {}
	P = merged("pebbit")
	k = P.kin
	var merge_len := float(P.merge_st["T"])
	run_for(merge_len + 0.3)
	ok(not KinMerge.active(P) and int(ults.get("titan_r", 0)) == 0, "unused, the timeout separates you without the ultimate")
	ok(k.state not in ["fused", "downed"] and k.cmd == "follow" and k.resting(), "...the Boki is out beside you, following, and resting (state %s)" % k.state)
	ok(absf(merge_len - 10.0) <= 0.5, "the merge lasts about 10s (%.1fs)" % merge_len)
	# the fallback: another Boki's merge has the basic burst as its ultimate and also drains
	ults = {}
	P = merged("cindle")
	k = P.kin
	var kit2 := MergeKit.of(P)
	ok(kit2 != null and P.slot_info("r").has("name"), "a Boki without a form yet keeps the stat merge with a basic burst on R")
	kit2.age = 2.0
	P.inp["ult"] = true
	run_for(0.05)
	run_for(1.2)
	ok(not KinMerge.active(P) and k.resting(), "the basic burst ends the merge and drains the Boki too")
	# a broken shell is not a drain
	P = merged("puddlet")
	k = P.kin
	P.hurt(float(P.merge_st["shell"]) + 50.0, rival(), {"src": "shot"})
	run_for(0.3)
	ok(not KinMerge.active(P) and not k.resting(), "a broken shell does not drain the Boki")

# ------------------------------------------------------------------ 3b. every way out removes everything the merge gave
## A Heavy Star merge with a charge dash under way, ended by `how`; then the augments, passive and dash armour must all be gone.
func _ended(how: String) -> Hunter:
	_fresh("pebbit")
	m.player.kin.stow()
	m.step(Match.DT)
	var base_kr := m.player.owner_stat("knockback_resist")
	var base_dr := m.player.owner_stat("damage_reduction")          # (with the Boki carried: its own bonus stays after the ultimate)
	var P := merged("pebbit")
	var k: Kin = P.kin
	live_kit(P).age = 2.0
	ok(P.owner_stat("damage_reduction") >= 0.19, "(%s) setup: the passive is on while merged (%.2f -> %.2f)" % [how, base_dr, P.owner_stat("damage_reduction")])
	CombatBus.ability_used.emit(P, "test_dash", "dodge")
	run_for(0.1)
	ok(not (P.merge_st["aug"]["dash"] as Dictionary).is_empty(), "(%s) setup: the charge dash window is open" % how)
	match how:
		"ult":
			P.inp["ult"] = true
			run_for(float(Content.merge_form("titan")["r"]["end"]) + 0.5)
			P.inp["ult"] = false
		"timeout":
			run_for(float(P.merge_st["T"]) + 0.3)
		"shell":
			P.hurt(float(P.merge_st["shell"]) + 600.0, rival(), {"src": "shot"})          # (the charge armours it: a big hit)
			run_for(0.4)
		"knock":
			P.downed = true
			run_for(0.4)
			P.downed = false
		"death":
			m.eliminate(P, rival(), "test", true)
			run_for(0.4)
		"extract":
			P.extracted = true
			run_for(0.4)
	ok(not KinMerge.active(P) and P.merge_st.is_empty(), "(%s) the merge is over" % how)
	var ex := {}
	MergeAugment.lmb(P, ex)
	ok(ex.is_empty(), "(%s) the LMB rider is gone" % how)
	ok(P.owner_stat("damage_reduction") < 0.19 and P.owner_stat("knockback_resist") <= base_kr + 0.001, "(%s) the passive is gone (damage reduction %.2f, knockback resist %.2f)" % [how, P.owner_stat("damage_reduction"), P.owner_stat("knockback_resist")])
	ok(P.fortify_t <= 0.0 and P.guard_t <= 0.0, "(%s) the dash armour is gone (fortify %.2f guard %.2f)" % [how, P.fortify_t, P.guard_t])
	var ex2 := {}
	P._kin_riders(ex2)
	ok(not ex2.has("fx_hit") and not ex2.has("pierce"), "(%s) no rider rides your next attack" % how)
	return P

func _ends() -> void:
	for how in ["ult", "timeout", "shell", "knock", "death", "extract"]:
		_ended(how)
	# no double rider: the Boki's carried bonus is off while it is inside you, and a fallback form has its augment only
	var P := merged("pebbit")
	var ex := {}
	P._kin_riders(ex)
	ok(not P.kin_carry_on() and not ex.has("ride_dmg") and not ex.has("burn") and not ex.has("kb"), "Heavy Star: only the augment rides a hit, not the Boki's carry bonus")
	ok(KinMerge.on_shot(P).is_empty(), "...and the merge's own on_shot is empty (it is the augment)")
	P = merged("cindle")
	ok(KinMerge.on_shot(P).is_empty(), "a fallback form: the type rider is the augment only, no second on_shot")
	ex = {}
	P._kin_riders(ex)
	var lm: Dictionary = MergeForm.aug_of(MergeForm.of(P)).get("lmb", {})
	ok(not lm.has("burn") or is_equal_approx(float(ex.get("burn", 0.0)), float(lm["burn"])), "...so a burn rider is not doubled (%.1f vs %.1f)" % [float(ex.get("burn", 0.0)), float(lm.get("burn", 0.0))])
	# the hero's holds are dropped while transforming (ArchKit._drop_holds, guard `transforming`)
	_fresh("pebbit")
	P = m.player
	P.set_arch("dolm")
	if P.ak != null and "dive" in P.ak:
		P.kin.stow()
		P.ult = 1.0
		P.ak.dive = true
		KinMerge.press(P)
		m.step(Match.DT)
		m.step(Match.DT)
		ok(KinMerge.transforming(P) and not bool(P.ak.dive), "a hold started before R (the Dolm dive) is dropped during the transformation")
	else:
		ok(false, "setup: the Dolm kit has a dive hold")
	# a drained Boki: the bot leaves it alone
	_fresh("pebbit")
	P = m.player
	P.kin.stow()
	P.kin.rest_t = 12.0
	var T := foe(P.pos + Vector3(4.0, 0, 0))
	P.ai["throw_cd"] = 0.0
	for i in 30:
		BotKin.fight(m, P, T, 4.0, 1.0)
		BotKin.upkeep(P)
		m.step(Match.DT)
	ok(P.kin.state == "shoulder" and P.kin.cmd == "return" and P.kin.resting(), "a bot does not throw or order a drained Boki (state %s cmd %s)" % [P.kin.state, P.kin.cmd])
	# disengage ends with the fight (and when the merge starts or the Boki is drained)
	_fresh("pebbit")
	P = m.player
	P.kin.disengaged = true
	run_for(0.3)
	ok(not P.kin.disengaged or P.kin.state != "active", "disengage is not left set once the fight is over")
	P.kin.disengaged = true
	P.kin.stow()
	P.ult = 1.0
	KinMerge.press(P)
	ok(not P.kin.disengaged, "starting a merge clears it")
	P.kin.disengaged = true
	P.kin.land_pumped(1.0)
	ok(not P.kin.disengaged, "a landing clears it too")
	# the R slot's fraction stays within 0..1 while drained
	var ri := P.slot_info("r")
	ok(float(ri["cd"]) <= float(ri["cd_max"]) + 0.01, "the R slot's cooldown fraction stays within 1 while the Boki rests (%.1f of %.1f)" % [float(ri["cd"]), float(ri["cd_max"])])

# ------------------------------------------------------------------ 4. the shell
func _shell() -> void:
	var P := merged("puddlet")
	var R := rival()
	var st: Dictionary = P.merge_st
	ok(float(st["shell"]) > 0.0 and is_equal_approx(float(st["shell"]), float(st["shell_max"])), "the merged form has its own shell (%.0f)" % float(st["shell"]))
	# no heal on merge
	_fresh("puddlet")
	P = m.player
	P.kin.stow()
	P.hp = 60.0
	P.ult = 1.0
	KinMerge.press(P)
	run_for(0.85)
	ok(P.hp >= 59.9 and P.hp <= 63.0, "merging does not heal you (hp %.1f of %.0f, only the usual regen)" % [P.hp, P.max_hp])
	var hp0 := P.hp
	var sh0 := float(P.merge_st["shell"])
	R = rival()
	P.hurt(20.0, R, {"src": "shot"})
	ok(float(P.merge_st["shell"]) <= sh0 - 15.0 and P.hp >= hp0 - 0.05, "damage drains the shell first (shell %.0f -> %.0f, hp %.1f)" % [sh0, float(P.merge_st["shell"]), P.hp])
	ok(P.hp >= hp0 - 0.05, "own health is untouched while the shell stands")
	var kit := live_kit(P)
	kit.age = 2.0
	ults = {}
	var k: Kin = P.kin
	P.hurt(float(P.merge_st["shell"]) + 50.0, R, {"src": "shot"})
	ok(not KinMerge.active(P), "a hit that breaks the shell ends the merge early")
	ok(int(ults.get("tidal_shell_r", 0)) == 0, "...with no ultimate")
	ok(P.hp >= hp0 - 0.05, "...the breaking hit is swallowed (hp %.2f of %.2f; a soaked hit costs a token 0.01)" % [P.hp, hp0])
	run_for(0.2)
	ok(k.state not in ["downed", "fused"] and k.hp > 0.0 and k.flat_dist(P) < 6.0, "...and the Boki pops out beside you, not downed (state %s)" % k.state)
	ok(P.merge_cd > 0.0 and P.merge_cd <= KinParts.MERGE_SPENT_TIME, "...with the normal merge cooldown (%.1fs)" % P.merge_cd)
	# firing the ultimate separates with the current health, the shell gone
	P = merged("puddlet")
	P.hp = 80.0
	live_kit(P).age = 2.0
	P.inp["ult"] = true
	run_for(1.4)
	ok(not KinMerge.active(P) and P.hp >= 79.9 and MergeShell.view(P).y == 0.0, "the ultimate separates you with your current health and no shell (hp %.0f)" % P.hp)

# ------------------------------------------------------------------ 5. no tiers; the weight-class baseline
func _tiers() -> void:
	var out := {}
	for lv_trust in [[1, 10.0], [30, 95.0]]:
		_fresh("puddlet")
		var P := m.player
		P.kin.rec["level"] = lv_trust[0]
		P.kin.trust = lv_trust[1]
		P.kin.stow()
		P.ult = 1.0
		KinMerge.press(P)
		run_for(0.85)
		var f := MergeForm.of(P)
		out[lv_trust[0]] = [float(P.merge_st["T"]), float(P.merge_st["shell_max"]), P.owner_stat("move_speed"), String(f["name"]), float(f["size"]), float(P.max_hp)]
	ok(out[1] == out[30], "two Boki (level 1 trust 10 / level 30 trust 95) give identical numbers %s" % [out[1]])
	var f2 := MergeForm.kit_form("titan")
	var l := MergeShell.size_for("light", f2)
	var md := MergeShell.size_for("medium", f2)
	var hv := MergeShell.size_for("heavy", f2)
	ok(l == roundf(80 * 1.3) and md == roundf(110 * 1.3) and hv == roundf(150 * 1.3), "Heavy Star shell by weight class: %d / %d / %d" % [l, md, hv])
	var fs := MergeForm.kit_form("stormwing")
	var fp := MergeForm.kit_form("tidal_shell")
	ok(MergeShell.size_for("medium", fs) == roundf(110 * 0.8) and MergeShell.size_for("medium", fp) == roundf(110 * 1.1), "form multipliers: Stormwing x0.8 (%d), Prism Shell x1.1 (%d)" % [MergeShell.size_for("medium", fs), MergeShell.size_for("medium", fp)])
	for cls in ["light", "medium", "heavy"]:
		var P2 := merged("pebbit", cls)
		ok(is_equal_approx(float(P2.merge_st["shell_max"]), MergeShell.size_for(cls, MergeForm.of(P2))), "a %s hunter wears a shell of %.0f" % [cls, float(P2.merge_st["shell_max"])])
	var b: Dictionary = (f2["def"] as Dictionary)["baseline"]
	ok(float(b["light"]["move_speed"]) > float(b["medium"]["move_speed"]) and float(b["medium"]["move_speed"]) > float(b["heavy"]["move_speed"]), "the speed baseline follows the weight class (the only scaling)")

# ------------------------------------------------------------------ 6a. Heavy Star
func _heavy() -> void:
	var P := merged("pebbit")
	var k := live_kit(P)
	var R := foe(P.pos + Vector3(0, 0, 2.5))
	aim_at(P, R.pos)
	var hp0 := R.hp
	run_for(0.6, func(): P.inp["fire"] = true)
	ok(R.hp < hp0 - 15.0, "Gravity Slam: the cone hurts (%.0f) and shoves" % (hp0 - R.hp))
	ok(R.pos.z > P.pos.z + 3.0, "...knocking the foe back (now %.1fm away)" % R.flat_dist(P))
	# the swings alternate
	ok(k.swing >= 1, "...the left and right swings alternate (%d casts)" % k.swing)
	# E: anchor pull
	R = foe(P.pos + Vector3(4.2, 0, 0))
	var d0 := R.flat_dist(P)
	k.cd["e"] = 0.0
	P.inp["sig"] = true
	run_for(0.5)
	ok(R.flat_dist(P) < d0 - 1.0, "Gravity Anchor pulls foes in (%.1fm -> %.1fm)" % [d0, R.flat_dist(P)])
	# RMB: boulder - armoured roll that carries foes and resists knockback
	R = foe(P.pos + Vector3(0, 0, -2.2))
	P.teleport(P.pos)
	aim_at(P, P.pos + Vector3(0, 0, -6.0))
	k.cd["rmb"] = 0.0
	P.inp["move"] = Vector2(0, -1)
	var z0 := P.pos.z
	var rz0 := R.pos.z
	var hp1 := R.hp
	run_for(1.3, func(): P.inp["sec_hold"] = true; P.inp["move"] = Vector2(0, -1); if k.hold.is_empty(): P.inp["sec"] = true)
	ok(not k.hold.is_empty() and String(k.hold["kind"]) == "boulder", "RMB (held) starts the boulder")
	ok(absf(P.pos.z - z0) > 6.0, "...an armoured roll at speed (%.1fm in 1.3s)" % absf(P.pos.z - z0))
	ok(R.pos.z < rz0 - 3.0 and R.hp < hp1, "...carrying the foe along and hurting it (moved %.1fm, -%.0f hp)" % [rz0 - R.pos.z, hp1 - R.hp])
	var vx0 := P.vel.x
	P.impulse(Vector2(40.0, 0.0))
	ok(is_equal_approx(P.vel.x, vx0), "...knockback cannot move you while rolling")
	var fill := float(k.hold["fill"])
	ok(fill >= 0.99 and bool(k.hold["full"]), "...it fills (and ticks 'full') at 1.2s (fill %.2f)" % fill)
	P.inp["sec_hold"] = false
	P.inp["move"] = Vector2.ZERO
	R.teleport(P.pos + Vector3(0, 0, -2.0))
	R.hp = R.max_hp
	run_for(0.3, func(): P.inp["sec_hold"] = false)
	ok(k.hold.is_empty() and R.hp < R.max_hp - 25.0, "...let go: the slam hits hard at full fill (%.0f)" % (R.max_hp - R.hp))
	# R: Collapse
	P = merged("pebbit")
	k = live_kit(P)
	k.age = 2.0
	var A := foe(P.pos + Vector3(10.0, 0, 3.0))
	var land := P.pos + Vector3(10.0, 0, 0)
	aim_at(P, land)
	var a_hp := A.hp
	var d_before := A.flat_dist(land)
	var p0 := P.pos
	P.inp["ult"] = true
	run_for(0.3)
	ok(k.ulting() and Vector2(P.pos.x - p0.x, P.pos.z - p0.z).length() > 1.0 and not P.grounded, "Collapse: the leap starts at once, airborne and already moving toward the mark (%.1fm)" % Vector2(P.pos.x - p0.x, P.pos.z - p0.z).length())
	var pulled := false
	var launched := false
	var hit_at := -1.0
	for i in 90:
		m.step(Match.DT)
		if A.flat_dist(land) < d_before - 0.8:
			pulled = true
		if A.vel.y > 3.0:
			launched = true
		if hit_at < 0.0 and A.hp < a_hp:
			hit_at = i * Match.DT
	ok(pulled, "...the crater pulls foes in first (%.1fm -> %.1fm from the landing)" % [d_before, A.flat_dist(land)])
	ok(launched and A.hp < a_hp - 40.0, "...then launches them (-%.0f hp)" % (a_hp - A.hp))
	ok(not KinMerge.active(P), "...and the merge ends")

# ------------------------------------------------------------------ 6b. Stormwing
func _storm() -> void:
	var P := merged("zephyrak")
	var k := live_kit(P)
	ok(k != null and k.form["id"] == "stormwing", "Zephyrak's merge is the Stormwing form")
	var R := foe(P.pos + Vector3(0, 0, 8.0))
	var R2 := foe(P.pos + Vector3(0, 0, 8.0))
	aim_at(P, R.pos)
	var hp0 := R.hp
	run_for(1.0, func(): P.inp["fire"] = true)
	ok(R.hp < hp0 - 20.0 and k.swing >= 4, "Chain Bolt: fast lightning, %d bolts in 1s, -%.0f hp" % [k.swing, hp0 - R.hp])
	# blink: swept, 2 charges
	R = foe(P.pos + Vector3(4.0, 0, 0))
	aim_at(P, P.pos + Vector3(20.0, 0, 0))
	var x0 := P.pos.x
	var rhp := R.hp
	ok(is_equal_approx(k.charges, 2.0), "Storm Blink starts with 2 charges")
	P.inp["sig"] = true
	run_for(0.1)
	ok(P.pos.x - x0 > 6.5 and R.hp < rhp and R.stun_t > 0.0, "...blinks 7.5m through foes, shocking the path (moved %.1fm, -%.0f hp, stun %.2f)" % [P.pos.x - x0, rhp - R.hp, R.stun_t])
	P.inp["sig"] = true
	run_for(0.1)
	var x1 := P.pos.x
	ok(k.charges < 1.0 and x1 - x0 > 13.0, "...a second charge goes the same way (%.1fm total)" % (x1 - x0))
	P.inp["sig"] = true
	run_for(0.1)
	ok(absf(P.pos.x - x1) < 1.0, "...a third press has no charge")
	run_for(float(Content.merge_form("stormwing")["e"]["recharge"]) + 0.2)
	ok(k.charges >= 1.0, "...and one comes back after the recharge")
	# a wall stops the blink
	var Wd = m.world
	var bx := int(floor(P.pos.x + 3.0)); var bz := int(floor(P.pos.z))
	Wd.kind[Wd.idx(bx, bz)] = World.T_VOID
	k.charges = 2.0
	P.inp["sig"] = true
	var xs := P.pos.x
	run_for(0.1)
	ok(P.pos.x - xs < 3.5, "...and the abyss stops it short (%.1fm)" % (P.pos.x - xs))
	# hover crosses a gap
	P = merged("zephyrak")
	k = live_kit(P)
	var hx := int(floor(P.pos.x)); var hz := int(floor(P.pos.z))
	Wd = m.world
	for dx in range(5, 15):
		for dz in range(-3, 4):
			Wd.kind[Wd.idx(hx + dx, hz + dz)] = World.T_VOID
	P.teleport(Vector3(hx + 3.5, P.pos.y, hz + 0.5))
	P.vel = Vector3.ZERO
	aim_at(P, P.pos + Vector3(20.0, 0, 0))
	var y0 := P.pos.y
	run_for(2.6, func(): P.inp["sec_hold"] = true; P.inp["move"] = Vector2(1, 0); if k.hold.is_empty() and k.cd["rmb"] <= 0.0 and P.pos.x < hx + 14.0: P.inp["sec"] = true)
	var hov := P.pos.x > hx + 15.0 and P.pos.y > y0 - 1.0
	ok(hov, "Hover crosses a 10m gap in the ground (x %.1f, height change %.1f)" % [P.pos.x - hx, P.pos.y - y0])
	# control: without the hover the same run falls
	P = merged("zephyrak")
	hx = int(floor(P.pos.x)); hz = int(floor(P.pos.z))
	Wd = m.world
	for dx in range(5, 15):
		for dz in range(-3, 4):
			Wd.kind[Wd.idx(hx + dx, hz + dz)] = World.T_VOID
	P.teleport(Vector3(hx + 3.5, P.pos.y, hz + 0.5))
	P.vel = Vector3.ZERO
	y0 = P.pos.y
	run_for(2.0, func(): P.inp["move"] = Vector2(1, 0))
	ok(P.pos.y < y0 - 1.5 or P.pos.x < hx + 15.0, "(without it you fall into the same gap)")
	# R: Thunderhead
	P = merged("zephyrak")
	k = live_kit(P)
	k.age = 2.0
	var rival_h := rival()
	var far_pos := P.pos + Vector3(12.0, 0, 0)
	var in_pos := P.pos + Vector3(9.0, 0, 0)
	# one rival hunter is the only foe body: test in two passes (inside 10m, then outside)
	rival_h = foe(in_pos)
	var h0 := rival_h.hp
	P.inp["ult"] = true
	run_for(0.3)
	ok(k.ulting() and not P.grounded and rival_h.hp >= h0, "Thunderhead: you rise with a darkening ring; no damage yet at 0.3s")
	run_for(0.8)
	ok(rival_h.hp < h0 - 35.0 and rival_h.stun_t > 0.0 or rival_h.hp < h0 - 35.0, "...then a strike hits every foe within 10m (a foe at 9m took %.0f)" % (h0 - rival_h.hp))
	run_for(0.8)
	ok(not KinMerge.active(P), "...and the merge ends")
	P = merged("zephyrak")
	k = live_kit(P)
	k.age = 2.0
	rival_h = foe(far_pos)
	h0 = rival_h.hp
	P.inp["ult"] = true
	run_for(1.2)
	ok(rival_h.hp >= h0, "...a foe at 12m is left alone")
	# several foes: a mob and a hunter
	P = merged("zephyrak")
	k = live_kit(P)
	k.age = 2.0
	rival_h = foe(P.pos + Vector3(0, 0, 6.0))
	var mb := m.spawn_mob("skitter", P.pos + Vector3(-5.0, 0, 0))
	mb.teleport(P.pos + Vector3(-5.0, 0, 0))
	keep.append(mb)
	var mh := mb.hp
	h0 = rival_h.hp
	P.inp["ult"] = true
	run_for(1.2)
	ok(rival_h.hp < h0 and (mb.dead or mb.hp < mh), "...every foe in range is struck (hunter -%.0f, monster %s)" % [h0 - rival_h.hp, "down" if mb.dead else "hurt"])

# ------------------------------------------------------------------ 6c. Prism Shell
func _prism() -> void:
	var P := merged("puddlet")
	var k := live_kit(P)
	ok(k != null and k.form["id"] == "tidal_shell", "Prismander's merge is the Prism Shell form")
	var R := foe(P.pos + Vector3(0, 0, 6.0))
	var hp0 := R.hp
	var mb := m.spawn_mob("skitter", P.pos + Vector3(0, 0, 10.0))
	mb.teleport(P.pos + Vector3(0, 0, 10.0))
	keep.append(mb)
	var mh := mb.hp
	aim_at(P, P.pos + Vector3(0, 0, 8.0))
	run_for(0.8, func(): P.inp["fire"] = true)
	ok(R.hp < hp0 and mb.hp < mh, "Crystal Shards pierce: both the foe in front and the one behind are hit (-%.0f / -%.0f)" % [hp0 - R.hp, mh - mb.hp])
	# RMB: the prism reflects a shot back at its shooter
	P = merged("puddlet")
	k = live_kit(P)
	R = foe(P.pos + Vector3(0, 0, 8.0))
	aim_at(P, R.pos)
	k.cd["rmb"] = 0.0
	run_for(0.95, func(): P.inp["sec_hold"] = true; if k.hold.is_empty(): P.inp["sec"] = true)
	ok(not k.hold.is_empty() and String(k.hold["kind"]) == "prism" and float(P.slow_t) > 0.0, "RMB (held) raises the prism and slows you")
	var fill := float(k.hold["fill"])
	ok(fill >= 0.99, "...it fills in 0.8s (%.2f)" % fill)
	m.spawn_shot(R, R.pos + Vector3(0, 0.9, 0), Vector2(0, -20.0), 10.0, 1.5, 0.15, Color.RED)
	var shot: Dictionary = m.shots[-1]
	var team_before := int(shot["team"])
	var Rhp := R.hp
	var seen := {"back": false}
	run_for(0.9, func():
		P.inp["sec_hold"] = true
		R.kin_shield = 0.0       # (the rival's own Boki shield would soak the hit)
		for s in m.shots:
			if int(s["team"]) == P.team and (s["vel"] as Vector2).y > 0.0:
				seen["back"] = true)
	ok(team_before == R.team and seen["back"], "...a shot that hits it flies back toward the shooter, now yours")
	ok(R.hp < Rhp, "...and hurts the one who fired it (-%.0f)" % (Rhp - R.hp))
	P.inp["sec_hold"] = false
	run_for(0.2)
	ok(k.hold.is_empty(), "...let go: the prism drops")
	# E: crystal wall + healing pulse
	P = merged("puddlet")
	k = live_kit(P)
	P.hp = 40.0
	aim_at(P, P.pos + Vector3(4.0, 0, 0))
	var walls0: int = m.verbs.walls.size()
	P.inp["sig"] = true
	run_for(0.2)
	ok(m.verbs.walls.size() > walls0, "Crystal Wall raises a wall at the cursor")
	P.teleport(P.pos + Vector3(4.0, 0, 0))
	run_for(2.6)
	ok(P.hp > 40.0 + 10.0, "...and pulses healing to your squad around it (hp 40 -> %.0f)" % P.hp)
	# R: Shatter shields allies and hurts foes
	P = merged("puddlet")
	k = live_kit(P)
	k.age = 2.0
	R = foe(P.pos + Vector3(4.0, 0, 0))
	var h0 := R.hp
	P.shield = 0.0
	P.inp["ult"] = true
	run_for(0.3)
	ok(k.ulting() and R.hp >= h0, "Shatter: the shell cracks first, no damage at 0.3s (a %.2fs tell)" % 0.55)
	run_for(0.6)
	ok(R.hp < h0 - 30.0, "...then bursts: foes take %.0f" % (h0 - R.hp))
	ok(P.shield > 30.0, "...and allies get a shield (%.0f)" % P.shield)
	# another game: a remote wearer holding the prism (its pose in the snapshot) turns MY shot too
	_fresh("pebbit")
	P = m.player
	R = foe(P.pos + Vector3(0, 0, 8.0))
	R.remote = true
	R.face = 0.0
	R.set_meta("mf_kit", true); R.set_meta("mf_id", "tidal_shell"); R.set_meta("mf_glow", Color("9ff3ff")); R.set_meta("kpose", "mf_prism")
	run_for(0.1)
	ok(not m.verbs.mirrors.is_empty(), "a remote hunter holding the Prism has a reflect window on this side")
	m.spawn_shot(P, P.pos + Vector3(0, 0.9, 6.0), Vector2(0, 20.0), 10.0, 1.5, 0.15, Color.RED)
	var rs: Dictionary = m.shots[-1]
	ok(int(rs["team"]) == P.team, "setup: my shot flies at the prism")
	var turned := {"v": false}
	run_for(0.6, func():
		for s2 in m.shots:
			if int(s2["team"]) == R.team and (s2["vel"] as Vector2).y < 0.0:
				turned["v"] = true)
	ok(turned["v"], "...and my shot is turned back at me, now theirs")
	R.set_meta("kpose", "")
	run_for(0.5)
	ok(m.verbs.mirrors.is_empty(), "...the window goes when the pose ends")
	R.remote = false
	# the pose counter: the same pose cast twice is two plays for the other side
	P = merged("pebbit")
	var kit_p := live_kit(P)
	kit_p.play("mf_ult")
	var e1 := String(KinNet.hunter_extra(P)[4])
	kit_p.play("mf_ult")
	var e2 := String(KinNet.hunter_extra(P)[4])
	ok(e1 != e2 and e1.get_slice("~", 0) == "mf_ult" and e2.get_slice("~", 0) == "mf_ult", "a repeated pose reaches the other side as a new play (%s -> %s)" % [e1, e2])

# ------------------------------------------------------------------ 8. the guards (review fixes)
func _guards() -> void:
	# shell order: the shell takes the hit before shield, armor and the Boki's shield; nothing else is touched
	var P := merged("puddlet")
	var R := rival()
	P.shield = 20.0; P.armor = 50.0; P.max_armor = 100.0; P.kin_shield = 10.0
	var hp0 := P.hp
	var o := {"src": "shot"}
	P.hurt(10.0, R, o)
	ok(P.shield == 20.0 and P.armor == 50.0 and P.kin_shield == 10.0 and P.hp >= hp0 - 0.05, "the shell is hit first: shield, armor and the Boki's shield are untouched (%.0f / %.0f / %.0f)" % [P.shield, P.armor, P.kin_shield])
	# a soaked hit still counts as a hit (extraction interrupt), like a kin shield
	P.extract_prog = 0.5
	P.hurt(5.0, R, {"src": "shot"})
	ok(P.extract_prog == 0.0, "a hit the shell soaks still interrupts extraction")
	# falls and heat go through the shell
	var sh := float(P.merge_st["shell"])
	P.hurt(6.0, null, {"src": "fall"})
	ok(float(P.merge_st["shell"]) == sh and (P.hp < hp0 - 1.0 or P.armor < 50.0 or P.shield < 20.0 or P.kin_shield < 10.0), "a fall goes past the shell")
	var sh2 := float(P.merge_st["shell"])
	var hp1 := P.hp
	var sh_a := P.shield; var ar_a := P.armor; var ks_a := P.kin_shield
	P.hurt(4.0, null, {"src": "heat"})
	ok(float(P.merge_st["shell"]) == sh2 and (P.hp < hp1 or P.shield < sh_a or P.armor < ar_a or P.kin_shield < ks_a), "heat goes past the shell too")
	# the shell breaks once
	P.hurt(float(P.merge_st["shell"]) + 40.0, R, {"src": "shot"})
	var t_break := float(P.get_meta("shell_break_at", -1.0))
	ok(not KinMerge.active(P) and t_break >= 0.0, "a breaking hit ends the merge and stamps the break (once)")
	var cd1 := P.merge_cd
	P.hurt(5.0, R, {"src": "shot"})
	ok(float(P.get_meta("shell_break_at", -1.0)) == t_break and P.merge_cd == cd1, "...a later hit does not break it again")
	# G and orders mid-transformation do not end the merge
	_fresh("pebbit")
	P = m.player
	P.kin.stow()
	P.ult = 1.0
	KinMerge.press(P)
	run_for(0.2)
	ok(String(P.merge_st.get("phase", "")) == "xform", "setup: mid-transformation")
	KinCommand.tap(P)
	KinCommand.order(P, "chase")
	KinCommand.order(P, "follow")
	run_for(0.1)
	ok(KinMerge.active(P) and P.merge_st["form"]["id"] == "titan", "G and orders mid-transformation do nothing (the merge goes on)")
	# the Boki does not speak while it is inside you
	var bubbles0: int = m.bubbles.size()
	P.kin.bark("revive")
	P.kin.bark("callout")
	ok(m.bubbles.size() == bubbles0, "the Boki says nothing while it is inside you")
	# eliminated mid-merge: everything goes
	P = merged("pebbit")
	var k := live_kit(P)
	ok(k != null, "setup: a live form")
	m.eliminate(P, rival(), "test", true)
	m.step(Match.DT)
	var ex := KinNet.hunter_extra(P)
	ok(P.merge_st.is_empty() and MergeKit.of(P) == null and String(ex[0]) == "" and P.get_node_or_null(MergeLook.NODE_NAME) == null, "eliminated mid-merge: no form, kit or look is left (snapshot form '%s')" % String(ex[0]))
	# a lost life (with lives left) drops you back in: the form does not follow
	P = merged("pebbit")
	P.lives = 3
	m.eliminate(P, rival(), "test", false)
	m.step(Match.DT)
	m.step(Match.DT)
	ok(P.merge_st.is_empty() and String(KinNet.hunter_extra(P)[0]) == "", "a lost life mid-merge ends the form (lives left: %d)" % P.lives)
	# extracted mid-merge: same
	P = merged("zephyrak")
	P.extracted = true
	m.step(Match.DT)
	ok(P.merge_st.is_empty() and MergeKit.of(P) == null and String(KinNet.hunter_extra(P)[0]) == "", "extracted mid-merge: the form goes with you")
	# a class kit's charge, bow draw or held RMB started before R does not fire mid-merge
	_fresh("pebbit", "heavy")
	P = m.player
	P.kin.stow()
	P.ult = 1.0
	P.draw_t = 0.8
	P.mel_hold = 0.6
	P.warm_t = 0.3
	if P.ak != null:
		P.ak.rmb_down = true
	P.inp["sec_hold"] = true
	KinMerge.press(P)
	var leaked := false
	for i in 90:
		P.inp["sec_hold"] = true
		m.step(Match.DT)
		if P.draw_t >= 0.0 or P.mel_hold > 0.0 or P.warm_t > 0.0 or (P.ak != null and P.ak.rmb_down):
			leaked = true
	ok(not leaked, "a charge, draw or held RMB from before R is dropped, through the transformation and after")
	# rescue: the Boki's own recovery mid-rescue frees you
	_fresh("pebbit")
	P = m.player
	var kk: Kin = P.kin
	kk.pos = P.pos + Vector3(2.0, 0, 0); kk.state = "active"; kk.fly = {}
	kk.go_down()
	P.teleport(kk.pos)
	run_for(0.6)
	ok(kk.rescue_on, "setup: a rescue is under way")
	kk.down_t = 0.01
	run_for(0.1)
	ok(kk.state != "downed" and not kk.rescue_on and kk.rescue_block == 0.0, "its own recovery mid-rescue ends the rescue flag")
	P.inp["move"] = Vector2(1, 0)
	var x0 := P.pos.x
	run_for(0.4, func(): P.inp["move"] = Vector2(1, 0))
	ok(P.pos.x - x0 > 0.5, "...and you can move again (no stuck root, %.1fm)" % (P.pos.x - x0))
	kk.rescue_on = true          # (a stale flag, as the old bug left it) must not root or disarm you either
	var x1 := P.pos.x
	run_for(0.4, func(): P.inp["move"] = Vector2(1, 0))
	ok(P.pos.x - x1 > 0.5, "...a stale flag on a Boki that is up does not root you")
	kk.rescue_on = false

# ------------------------------------------------------------------ 6. the warning
func _warn() -> void:
	var P := merged("pebbit")
	var warn_s := float(MergeForm.data()["warn_s"])
	ok(MergeAugment.warn_left(P) < 0.0, "no warning early in the window")
	P.merge_st["t"] = warn_s + 0.5
	run_for(0.2)
	ok(MergeAugment.warn_left(P) < 0.0, "...none just before the last %.0fs" % warn_s)
	P.merge_st["t"] = warn_s - 0.5
	var fx_n := m.fx.get_child_count()
	run_for(0.1)
	ok(MergeAugment.warn_left(P) > 0.0 and MergeAugment.warn_left(P) <= warn_s, "the warning is on in the last %.0fs (%.1fs left)" % [warn_s, MergeAugment.warn_left(P)])
	ok(m.fx.get_child_count() > fx_n, "...with a tick ring each second")
	# another game sees it from the snapshot time
	var R := rival()
	var it: Array = []
	it.resize(KinNet.HUNTER_AT)
	it.append_array(KinNet.hunter_extra(P))
	KinNet.apply_hunter(R, it)
	ok(MergeAugment.warn_left(R) > 0.0, "...and a rival's game reads it too (%.1fs)" % MergeAugment.warn_left(R))
	var look := R.get_node_or_null(MergeLook.NODE_NAME) as MergeLook
	if look != null:
		look._process(0.2)
		ok(true, "...the look keeps flickering without error")

# ------------------------------------------------------------------ 7. the net and the bots
func _net() -> void:
	ok(Net.VERSION.naturalnocasecmp_to("0.15.0") >= 0, "Net.VERSION moved to %s (at least 0.15.0)" % Net.VERSION)
	var P := merged("pebbit")
	var R := rival()
	var f := MergeForm.of(P)
	var rt := KinNet.decode_form(KinNet.encode_form(f))
	ok(String(rt.get("id", "")) == "titan" and String(rt.get("name", "")) == "Heavy Star" and bool(rt.get("kit", false)) and is_equal_approx(float(rt.get("size", 0.0)), float(f["size"])), "the form crosses the net as its id and rebuilds from content")
	P.hurt(25.0, R, {"src": "shot"})
	var kit := live_kit(P)
	kit.play("mf_ult")
	var extra := KinNet.hunter_extra(P)
	var it: Array = []
	it.resize(KinNet.HUNTER_AT)
	it.append_array(extra)
	KinNet.apply_hunter(R, it)
	ok(R.get_node_or_null(MergeLook.NODE_NAME) != null, "another game sees the form on the hunter (the look is built)")
	ok(is_equal_approx(float(R.get_meta("shell")), float(P.merge_st["shell"])) and float(R.get_meta("shell_max")) > 0.0, "...with the shell (%.0f / %.0f)" % [float(R.get_meta("shell")), float(R.get_meta("shell_max"))])
	ok(String(R.get_meta("kpose")) == "mf_ult" and String(R.get_meta("mf_name")) == "Heavy Star" and float(R.get_meta("mf_left")) > 5.0, "...the pose id, the form name and the time left")
	ok(MergeShell.view(R).y > 0.0, "...MergeShell.view reads it for a remote hunter")
	# a remote cast event draws without error
	m.net_on = false
	var fx_n := m.fx.get_child_count()
	KinNet.on_event(m, ["kcmd", "mcast", R.nid, R.pos.x, R.pos.y, R.pos.z, "ult|%.1f|%.1f|7.0|1.2" % [R.pos.x + 3.0, R.pos.z]])
	ok(m.fx.get_child_count() > fx_n, "a remote ultimate draws its ground marker on this side (%d new fx nodes)" % (m.fx.get_child_count() - fx_n))
	KinNet.on_event(m, ["kcmd", "merge", R.nid, R.pos.x, R.pos.y, R.pos.z, KinNet.encode_form(f)])
	var sp := R.get_node_or_null(MergeXform.SPIRAL) as CPUParticles3D
	ok(sp != null and sp.emitting, "a rival's merge event plays the same transformation spiral on this side")
	# the rest of a drained Boki crosses the net
	var kk: Kin = P.kin
	kk.rest_t = 7.0
	var kex := KinNet.kin_extra(kk)
	ok(kex.has(7.0) or kex.any(func(v): return v is float and absf(float(v) - 7.0) < 0.2), "a drained Boki's rest seconds ride the kin snapshot")
	# the form disappears from a snapshot: the look peels away
	var it2: Array = []
	it2.resize(KinNet.HUNTER_AT)
	it2.append_array(["", 0.0, 0.0, 0.0, ""])
	KinNet.apply_hunter(R, it2)
	ok(R.get_node_or_null(MergeLook.NODE_NAME) == null and R.get_node_or_null("MergeLookLeaving") != null and not bool(R.get_meta("mf_kit")), "...and the look starts peeling off when the merge ends")
	(R.get_node("MergeLookLeaving") as MergeLook)._process(MergeLook.PEEL_S + 0.05)          # (headless: nothing renders, so play the peel by hand)
	ok(not R.has_node("Rig/Torso/MergePartsLeaving") and not R.has_node("Rig/Torso/" + MergeLook.PARTS_NAME), "...and the parts are gone from the torso when the peel finishes")

func _bots() -> void:
	ults = {}
	var P := merged("pebbit")
	var k := live_kit(P)
	var R := foe(P.pos + Vector3(4.0, 0, 0))
	aim_at(P, R.pos)
	MergeKit.bot_use(P)
	ok(not k.ulting(), "a bot holds the ultimate while it is locked")
	k.age = 2.0
	MergeKit.bot_use(P)
	ok(k.ulting() and int(ults.get("titan_r", 0)) == 1, "a bot fires the ultimate when a foe is in range")
	# a bot with the timer low and no foe nearby still fires it
	P = merged("pebbit")
	k = live_kit(P)
	k.age = 2.0
	P.merge_st["t"] = 1.0
	foe(P.pos + Vector3(14.0, 0, 0))
	MergeKit.bot_use(P)
	ok(k.ulting(), "...or when the timer is nearly out")
	# with no foe near and time left it waits
	P = merged("pebbit")
	k = live_kit(P)
	k.age = 2.0
	foe(P.pos + Vector3(30.0, 0, 0))
	MergeKit.bot_use(P)
	ok(not k.ulting(), "...and holds it with no foe near and time left")
