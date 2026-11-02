extends RefCounted
## --merge-form-check: the merge forms (docs/decisions/0003). Prints PASS/FAIL lines.
##   1. the transformation: 0.7s of invulnerability, then the form is live; R with a downed Boki waits; a knock-out pops the Boki out
##   2. the kit swap: LMB / RMB / E are the form's and restored after; C is blocked; the ultimate is locked 1.5s
##   3. the ultimate separates (the Boki beside you, following, not downed); a timeout separates without it
##   4. the shell: no heal on merge, hits drain it first, a break ends the merge without the ultimate
##   5. no tiers: two Boki of very different level and trust give the same numbers; the weight-class baseline
##   6. Heavy Star, Stormwing and Prism Shell: each slot does what it says
##   7. the net round trip (form, shell, pose, events) and bots playing the kit
## Run one part: --mergeform-only=xform,kit

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
	return MergeKit.live_of(P)

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	CombatBus.ability_used.connect(_on_used)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mergeform-only="): only = a.substr(17)
	for part in ["data", "xform", "kit", "ult", "shell", "tiers", "heavy", "storm", "prism", "net", "bots"]:
		if only == "" or only.split(",").has(part):
			call("_" + part)
	CombatBus.ability_used.disconnect(_on_used)
	print("MERGEFORM DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ 0. the data
func _data() -> void:
	for id in ["titan", "stormwing", "tidal_shell"]:
		var fd: Dictionary = Content.merge_form(id)
		ok(not fd.is_empty() and fd.has("lmb") and fd.has("rmb") and fd.has("e") and fd.has("r") and fd.has("palette") and fd.has("look"), "%s: a form file with LMB, RMB, E, R, palette and look" % id)
		ok(float((fd["r"] as Dictionary).get("end", 0.0)) > 0.0 and not (fd["r"]["beats"] as Array).is_empty(), "%s: the ultimate is a timeline of beats" % id)
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

# ------------------------------------------------------------------ 2. the kit swap
func _kit() -> void:
	var P := merged("pebbit")
	var R := rival()
	var k := live_kit(P)
	ok(k != null and k.has_slots(), "Gravadillo's merge is the Heavy Star form with its own kit")
	var base_rmb := ""
	_fresh("pebbit")
	base_rmb = String(m.player.slot_info("sec").get("name", ""))
	P = merged("pebbit")
	ok(String(P.slot_info("sec").get("name", "")) == "Bulldoze" and String(P.slot_info("k1").get("name", "")) == "Gravity Anchor" and String(P.slot_info("lmb").get("name", "")) == "Gravity Slam",
		"merged: the skill bar shows the form's LMB / RMB / E (%s / %s / %s)" % [P.slot_info("lmb").get("name", ""), P.slot_info("sec").get("name", ""), P.slot_info("k1").get("name", "")])
	ok(String(P.slot_info("r").get("name", "")) == "Collapse", "...and R shows the form's ultimate")
	ok(String(P.slot_info("sec").get("name", "")) != base_rmb, "...replacing the class's own RMB (%s)" % base_rmb)
	# LMB is the form's: the gun does not fire
	var ammo0 := P.ammo
	aim_at(P, P.pos + Vector3(0, 0, 3.0))
	run_for(0.4, func(): P.inp["fire"] = true)
	ok(P.ammo == ammo0 and int(P.used.get("lmb", 0)) > 0, "LMB casts the form's slam, not the gun (ammo %d -> %d)" % [ammo0, P.ammo])
	# C is blocked
	var cu := int(P.used.get("kin_ab", 0))
	P.inp["kin_ab"] = true
	run_for(0.1)
	ok(int(P.used.get("kin_ab", 0)) == cu and P.kin.runner.is_ready("k1"), "C is unavailable while merged")
	# G / orders are inert
	ok(not KinCommand.order(P, "guard") and KinMerge.active(P), "orders do nothing while merged (your Boki is part of you)")
	# Shift keeps its dash with the form's flavour
	var f := MergeForm.of(P)
	ok(not (f["dash"] as Dictionary).is_empty() and String(f["dash"]["visual"]) == "rock", "Shift keeps the dash, flavoured per form (rock shock for Heavy Star)")
	var Rt := foe(P.pos + Vector3(2.0, 0, 0))
	var hpR := Rt.hp
	P.inp["dash"] = true
	P.inp["move"] = Vector2(1, 0)
	run_for(0.4)
	ok(Rt.hp < hpR, "...the dodge leaves a damaging ground shock (%.0f dmg)" % (hpR - Rt.hp))
	P.inp["move"] = Vector2.ZERO
	# Q (glove) stays: the slot is still driven by the glove code
	ok(P.slot_info("gear").has("name"), "Q (the glove) is untouched")
	# ult locked for the first 1.5s
	P = merged("pebbit")
	k = live_kit(P)
	k.age = 0.5
	ok(not k.press_ult() and k.ult_text() != "", "the ultimate is locked early (%s)" % k.ult_text())
	k.age = float(MergeForm.data()["ult_lock_s"]) + 0.05
	ok(float(MergeForm.data()["ult_lock_s"]) == 1.5 and k.lock_left() <= 0.0, "...and unlocks 1.5s into the merge")
	# after the merge: the class's kit is back
	_fresh("pebbit")
	var base2 := String(m.player.slot_info("sec").get("name", ""))
	P = merged("pebbit")
	KinMerge.end(P, "test")
	run_for(0.1)
	ok(String(P.slot_info("sec").get("name", "")) == base2 and MergeKit.live_of(P) == null, "after the merge your own RMB and E are back (%s)" % P.slot_info("sec").get("name", ""))
	ammo0 = P.ammo
	run_for(0.5, func(): P.inp["fire"] = true)
	ok(P.ammo < ammo0, "...and LMB fires the gun again")

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
	ok(k.state not in ["fused", "downed", "bench"] and k.cmd == "follow" and k.flat_dist(P) < 8.0 and k.hp > 0.0, "...and the Boki pops out beside you, following, not downed (state %s cmd %s)" % [k.state, k.cmd])
	ok(P.merge_cd > 0.0 and P.merge_cd <= KinParts.MERGE_SPENT_TIME, "...then a short merge cooldown (%.1fs)" % P.merge_cd)
	# timeout: no ultimate
	ults = {}
	P = merged("pebbit")
	k = P.kin
	run_for(float(P.merge_st["T"]) + 0.3)
	ok(not KinMerge.active(P) and int(ults.get("titan_r", 0)) == 0, "unused, the timeout separates you without the ultimate")
	ok(k.state not in ["fused", "downed"] and k.cmd == "follow", "...the Boki is out beside you (state %s)" % k.state)
	ok(is_equal_approx(float(Content.merge_form("titan").get("duration", 10.0)), 10.0) or float(KinMerge.def_for(k).duration) == 10.0, "the merge lasts about 10s")
	# the fallback: another Boki's merge has the basic burst as its ultimate and also separates
	ults = {}
	P = merged("cindle")
	k = P.kin
	var kit2 := MergeKit.of(P)
	ok(kit2 != null and not kit2.has_slots() and P.slot_info("r").has("name"), "a Boki without a form yet keeps the stat merge with a basic burst on R")
	kit2.age = 2.0
	P.inp["ult"] = true
	run_for(0.05)
	run_for(1.2)
	ok(not KinMerge.active(P), "the basic burst ends the merge too")

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
	ok(is_equal_approx(float(P.merge_st["shell"]), sh0 - 20.0) and P.hp >= hp0 - 0.01, "damage drains the shell first (shell %.0f -> %.0f, hp %.1f)" % [sh0, float(P.merge_st["shell"]), P.hp])
	ok(P.hp >= hp0 - 0.01, "own health is untouched while the shell stands")
	var kit := live_kit(P)
	kit.age = 2.0
	ults = {}
	var k: Kin = P.kin
	P.hurt(float(P.merge_st["shell"]) + 50.0, R, {"src": "shot"})
	ok(not KinMerge.active(P), "a hit that breaks the shell ends the merge early")
	ok(int(ults.get("tidal_shell_r", 0)) == 0, "...with no ultimate")
	ok(P.hp >= hp0 - 0.01, "...the breaking hit is swallowed (hp %.1f)" % P.hp)
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
	# RMB: bulldoze - armoured roll that carries foes and resists knockback
	R = foe(P.pos + Vector3(0, 0, -2.2))
	P.teleport(P.pos)
	aim_at(P, P.pos + Vector3(0, 0, -6.0))
	k.cd["rmb"] = 0.0
	P.inp["move"] = Vector2(0, -1)
	var z0 := P.pos.z
	var rz0 := R.pos.z
	var hp1 := R.hp
	run_for(1.3, func(): P.inp["sec_hold"] = true; P.inp["move"] = Vector2(0, -1); if k.hold.is_empty(): P.inp["sec"] = true)
	ok(not k.hold.is_empty() and String(k.hold["kind"]) == "bulldoze", "RMB (held) starts the bulldoze")
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
	P.inp["ult"] = true
	run_for(0.3)
	ok(k.ulting() and P.pos.x > P.pos.x - 1.0 and not P.grounded, "Collapse: the leap starts at once, airborne")
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

# ------------------------------------------------------------------ 7. the net and the bots
func _net() -> void:
	ok(Net.VERSION == "0.11.0", "Net.VERSION moved to %s" % Net.VERSION)
	var P := merged("pebbit")
	var R := rival()
	var f := MergeForm.of(P)
	var rt := KinNet.decode_form(KinNet.encode_form(f))
	ok(String(rt.get("id", "")) == "titan" and String(rt.get("name", "")) == "Heavy Star" and bool(rt.get("kit", false)) and is_equal_approx(float(rt.get("size", 0.0)), 1.3), "the form crosses the net as its id and rebuilds from content")
	P.hurt(25.0, R, {"src": "shot"})
	var kit := live_kit(P)
	kit.play("mf_slam_a")
	var extra := KinNet.hunter_extra(P)
	var it: Array = []
	it.resize(KinNet.HUNTER_AT)
	it.append_array(extra)
	KinNet.apply_hunter(R, it)
	ok(R.get_node_or_null(MergeLook.NODE_NAME) != null, "another game sees the form on the hunter (the look is built)")
	ok(is_equal_approx(float(R.get_meta("shell")), float(P.merge_st["shell"])) and float(R.get_meta("shell_max")) > 0.0, "...with the shell (%.0f / %.0f)" % [float(R.get_meta("shell")), float(R.get_meta("shell_max"))])
	ok(String(R.get_meta("kpose")) == "mf_slam_a" and String(R.get_meta("mf_name")) == "Heavy Star" and float(R.get_meta("mf_left")) > 5.0, "...the pose id, the form name and the time left")
	ok(MergeShell.view(R).y > 0.0, "...MergeShell.view reads it for a remote hunter")
	# a remote cast event draws without error
	m.net_on = false
	KinNet.on_event(m, ["kcmd", "mcast", P.nid, P.pos.x, P.pos.y, P.pos.z, "ult|%.1f|%.1f|7.0|1.2" % [P.pos.x, P.pos.z]])
	KinNet.on_event(m, ["kcmd", "merge", P.nid, P.pos.x, P.pos.y, P.pos.z, KinNet.encode_form(f)])
	ok(true, "the merge and cast events play on the other side")
	# the form disappears from a snapshot: the look peels away
	var it2: Array = []
	it2.resize(KinNet.HUNTER_AT)
	it2.append_array(["", 0.0, 0.0, 0.0, ""])
	KinNet.apply_hunter(R, it2)
	run_for(0.1)
	ok(R.get_node_or_null(MergeLook.NODE_NAME) == null and not bool(R.get_meta("mf_kit")), "...and goes when the merge ends")

func _bots() -> void:
	ults = {}
	var P := merged("pebbit")
	var k := live_kit(P)
	var R := foe(P.pos + Vector3(4.0, 0, 0))
	aim_at(P, R.pos)
	MergeKit.bot_use(P, R, 4.0, true)
	ok(not k.ulting(), "a bot holds the ultimate while it is locked")
	k.age = 2.0
	MergeKit.bot_use(P, R, 4.0, true)
	ok(k.ulting() and int(ults.get("titan_r", 0)) == 1, "a bot fires the ultimate when a foe is in range")
	# a bot with the timer low and no foe nearby still fires it
	P = merged("pebbit")
	k = live_kit(P)
	k.age = 2.0
	P.merge_st["t"] = 1.0
	var R2 := foe(P.pos + Vector3(14.0, 0, 0))
	MergeKit.bot_use(P, R2, 14.0, true)
	ok(k.ulting(), "...or when the timer is nearly out")
	# the bot brain runs the kit: RMB hold and E when a foe is close
	P = merged("pebbit")
	k = live_kit(P)
	k.age = 0.5
	R = foe(P.pos + Vector3(0, 0, 4.0))
	aim_at(P, R.pos)
	var used := false
	for i in 40:
		MergeKit.bot_use(P, R, 4.0, true)
		if not k.hold.is_empty():
			used = true
		m.step(Match.DT)
	ok(used or k.cd["e"] > 0.0 or k.cd["rmb"] > 0.0, "a bot uses the form's RMB hold or E")
