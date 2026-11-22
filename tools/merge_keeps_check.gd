extends RefCounted
## --merge-keeps-check: merging with your Boki only ADDS (docs/decisions/0100). For every Hunter: merge, then press
## LMB, RMB, E, the hunter ultimate (R), Shift, the Boki key (C), jump, glide and crouch. Each must go off as it does
## unmerged, while the merge's own bonuses (shell, look, cooldown haste, LMB rider) stay on and the merge keeps
## running. Prints MERGEKEEPS PASS/FAIL lines.
## Run one hero: --merge-keeps-check=archer,mage

const DT := 1.0 / 60.0
const FRAMES := 45  # a press and what follows it (a held LMB, a recast window, a dash)
const FOE_DIST := 4.0  # m, the rival in front of the Hunter
const FOE_HP := 1.0e6  # the rival soaks every kit's damage
const MERGE_SECS := 600.0  # the window is held open: only the abilities are under test
const RIDER_TRIES := 12  # attacks tried for the LMB rider (the slowest is every 6th)
const SLOTS := ["lmb", "rmb", "e", "r", "dash", "boki", "jump", "glide", "crouch"]

var bad := 0
var main: Node
var m: Match
var origin := Vector3.ZERO  # where the Hunter stands (the rival is knocked about, so it is not the anchor)


func ok(cond: bool, what: String) -> void:
	print("MERGEKEEPS %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(host: Node) -> void:
	main = host
	Save.no_write = true
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--merge-keeps-check="):
			only = String(a).get_slice("=", 1)
	for id in Arch.ORDER:
		if only == "" or only.split(",").has(id):
			_hunter(String(id))
	print("MERGEKEEPS DONE, failures: ", bad)
	host.get_tree().quit(1 if bad > 0 else 0)


## A fresh match with `id`, a flat arena, the rival parked in front, the Boki on the shoulder and a full meter.
func _fresh(id: String) -> Hunter:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start(
		{
			"training": true,
			"teams": 2,
			"squad": 1,
			"tier": 0,
			"length": 1e9,
			"seed": 4242,
			"no_drop": true,
			"demo_kin": "pebbit",
			"cls": Arch.weight(id),
			"arch": id,
			"weapon": Arch.signature(id)
		}
	)
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var hero: Hunter = m.player
	var world = m.world
	var hx := int(floor(hero.pos.x))
	var hz := int(floor(hero.pos.z))
	var hi: int = world.idx(hx, hz)
	var lv: int = int(world.level[hi]) if world.kind[hi] != World.T_VOID else 0
	for dz in range(-20, 21):
		for dx in range(-30, 41):
			if not world.inb(hx + dx, hz + dz):
				continue
			var i: int = world.idx(hx + dx, hz + dz)
			world.kind[i] = World.T_GROUND
			world.level[i] = lv
			world.island[i] = world.island[hi]
			world.stairs.erase(i)
			world.walls.erase(i)
			world.props.erase(i)
			world.bush.erase(i)
	origin = Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)
	hero.teleport(origin)
	hero.unlock_all()
	hero.lvl = 6
	hero.slot_lv["ult"] = 1
	hero.kin.trust = 60.0
	hero.kin.stow()
	hero.ult = 1.0
	for i in 40:
		m.step(DT)
	return hero


func _rival() -> Hunter:
	for h in m.hunters:
		if h.team != m.player.team:
			return h
	return null


## The rival parked in front of the Hunter: it never dies and never fights back.
func _foe(hero: Hunter) -> Hunter:
	var rival := _rival()
	rival.ctrl = "idle"
	rival.dropping = false
	rival.diving = false
	rival.gliding = false
	rival.teleport(hero.pos + Vector3(FOE_DIST, 0, 0))
	rival.max_hp = FOE_HP
	rival.hp = FOE_HP
	rival.max_armor = 0.0
	rival.armor = 0.0
	if rival.kin != null:
		rival.kin.stow()
	return rival


func _merge(hero: Hunter) -> bool:
	if not KinMerge.press(hero):
		return false
	for i in int((float(MergeForm.data()["xform_s"]) + 0.15) / DT):
		m.step(DT)
	hero.merge_st["t"] = MERGE_SECS
	hero.merge_st["T"] = MERGE_SECS
	return KinMerge.active(hero) and String(hero.merge_st.get("phase", "")) == "live"


func _hunter(id: String) -> void:
	var hero := _fresh(id)
	var rival := _foe(hero)
	var base := {}
	for s in SLOTS:
		base[s] = _press(hero, rival, s)
		_reset(hero)
	hero = _fresh(id)  # (a second match: a seed or a stance left by the first run must not leak in)
	rival = _foe(hero)
	ok(_merge(hero), "%s: merges (the form is live)" % id)
	for s in SLOTS:
		var went := _press(hero, rival, s)
		var seen := went if went != "" else "nothing"
		ok(went != "" or base[s] == "", "%s merged: %s goes off like unmerged (%s)" % [id, s, seen])
		_reset(hero)
	_bonuses(id, hero)


## One slot pressed the way Match._gather_input sets it. Returns what was seen ("" when nothing went off).
func _press(hero: Hunter, rival: Hunter, slot: String) -> String:
	var seen := ""
	var shots := hero.shot_n
	var used0 := int(hero.used.get("kin_ab", 0))
	for i in FRAMES:
		hero.inp["aim"] = rival.pos + Vector3(0, 0.9, 0)
		hero.inp["aim_y"] = rival.pos.y
		hero.dashes = hero.max_dashes()
		hero.inp["fire"] = slot == "lmb" and i < 6
		hero.inp["sec_hold"] = slot == "rmb" and i < 2
		hero.inp["dash_down"] = slot == "dash" and i < 2
		hero.inp["crouch"] = slot == "crouch"
		hero.inp["glide"] = slot == "glide" and i > 8
		hero.inp["glide_btn"] = hero.inp["glide"]
		if i == 0:
			_tap(hero, slot)
		elif slot == "glide" and i == 4:
			hero.inp["jump"] = true
		m.step(DT)
		rival.hp = FOE_HP
		seen = seen if seen != "" else _went(hero, slot, shots, used0)
	hero.inp["crouch"] = false
	hero.inp["glide"] = false
	hero.inp["glide_btn"] = false
	return seen


func _tap(hero: Hunter, slot: String) -> void:
	if hero.ak:
		for key in hero.ak.cd:
			hero.ak.cd[key] = 0.0
	match slot:
		"rmb":
			hero.inp["sec"] = true
		"e":
			hero.inp["sig"] = true
		"r":
			HunterKeys.ult_pressed(hero)  # (rival goes straight to the kit, not through inp)
		"dash":
			hero.inp["dash"] = true
		"boki":
			hero.inp["kin_ab"] = true
		"jump", "glide":
			hero.inp["jump"] = true


## What this frame shows of `slot` going off ("" when nothing yet).
func _went(hero: Hunter, slot: String, shots: int, used0: int) -> String:
	match slot:
		"lmb":
			return "shot or swing" if hero.shot_n > shots or hero.swing_t > 0.0 else ""
		"rmb":
			return "slot flashed" if _flash("sec") or hero.ak.rmb_down or hero.ak.ch_rmb < 1.0 else ""
		"e":
			return (
				"cooldown %.1fs" % float(hero.ak.cd["e"]) if float(hero.ak.cd["e"]) > 0.0 or hero.ak.e_t > 0.0 else ""
			)
		"r":
			return (
				"cooldown %.1fs" % float(hero.ak.cd["x"])
				if float(hero.ak.cd["x"]) > 0.0 or hero.ak.ult_running()
				else ""
			)
		"dash":
			return "rolling" if hero.roll_t > 0.0 or hero.dashes < hero.max_dashes() - 0.5 else ""
		"boki":
			var cd: float = hero.kin.runner.cd_left("k1")
			return "cooldown %.1fs" % cd if int(hero.used.get("kin_ab", 0)) > used0 and cd > 0.0 else ""
		"jump":
			return "airborne" if not hero.grounded and hero.vel.y > 0.0 else ""
		"glide":
			return "gliding" if hero.gliding else ""
		"crouch":
			return "crouched" if hero.crouch else ""
	return ""


func _flash(id: String) -> bool:
	return m.hud != null and m.hud.slot_fx.has(id) and String(m.hud.slot_fx[id]["kind"]) == "cast"


## Back to a clean standing start for the next slot; the merge stays on.
func _reset(hero: Hunter) -> void:
	hero.inp["move"] = Vector2.ZERO
	for i in 90:
		m.step(DT)
	hero.stun_t = 0.0
	hero.inv_t = 0.0
	hero.hp = hero.max_hp
	if hero.ak:
		hero.ak.drop_holds()
		for key in hero.ak.cd:
			hero.ak.cd[key] = 0.0
	hero.teleport(origin)
	hero.vel = Vector3.ZERO
	_foe(hero)


## The merge's own gifts are still on after all of that, and the merge is still running.
func _bonuses(id: String, hero: Hunter) -> void:
	var form := MergeForm.of(hero)
	ok(KinMerge.active(hero), "%s: still merged after every ability" % id)
	var shell := float(hero.merge_st.get("shell", 0.0))
	ok(shell > 0.0, "%s: the shell is up (%.0f)" % [id, shell])
	ok(hero.get_node_or_null(MergeLook.NODE_NAME) != null, "%s: the merged look is on" % id)
	ok(
		hero.owner_stat("cooldown") > 0.0 or float(form.get("haste", 0.0)) <= 0.0,
		"%s: the form's cooldown haste applies (%.2f)" % [id, hero.owner_stat("cooldown")]
	)
	var extra := {}
	for i in RIDER_TRIES:
		hero._kin_riders(extra)  # (an "every Nth attack" rider only shows on its Nth)
	var rider: Dictionary = MergeForm.aug_of(form).get("lmb", {})
	ok(rider.is_empty() or not extra.is_empty(), "%s: the LMB rider rides your attacks (%s)" % [id, str(extra.keys())])
