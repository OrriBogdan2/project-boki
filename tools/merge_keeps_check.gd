extends RefCounted
## --merge-keeps-check: merging with your Boki only ADDS (docs/decisions/0004, 0099-merge-keeps-abilities). For every
## Hunter: merge, then press LMB, RMB, E, the hunter ultimate (R), Shift, the Boki key (C), jump, glide and crouch, and
## each one must go off exactly as it does unmerged, while the merge's own bonuses (shell, look, cooldown haste,
## the LMB rider) are still on and the merge is still running. Prints MERGEKEEPS PASS/FAIL lines.
## Run one hero: --merge-keeps-check=archer,mage

const DT := 1.0 / 60.0
const FRAMES := 45               # a press and what follows it (a held LMB, a recast window, a dash)
const FOE_DIST := 4.0            # m, the rival in front of the Hunter
const FOE_HP := 1.0e6            # the rival soaks every kit's damage
const MERGE_SECS := 600.0        # the window is held open: only the abilities are under test
const RIDER_TRIES := 12           # attacks tried for the LMB rider (the slowest is every 6th)
const SLOTS := ["lmb", "rmb", "e", "r", "dash", "boki", "jump", "glide", "crouch"]

var bad := 0
var main: Node
var m: Match

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
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"demo_kin": "pebbit", "cls": Arch.weight(id), "arch": id, "weapon": Arch.signature(id)})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var W = m.world
	var hx := int(floor(P.pos.x))
	var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-20, 21):
		for dx in range(-30, 41):
			if not W.inb(hx + dx, hz + dz):
				continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			W.stairs.erase(i)
			W.walls.erase(i)
			W.props.erase(i)
			W.bush.erase(i)
	P.teleport(Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5))
	P.unlock_all()
	P.lvl = 6
	P.slot_lv["ult"] = 1
	P.kin.trust = 60.0
	P.kin.stow()
	P.ult = 1.0
	for i in 40:
		m.step(DT)
	return P

func _rival() -> Hunter:
	for h in m.hunters:
		if h.team != m.player.team:
			return h
	return null

## The rival parked in front of the Hunter: it never dies and never fights back.
func _foe(P: Hunter) -> Hunter:
	var R := _rival()
	R.ctrl = "idle"
	R.dropping = false
	R.diving = false
	R.gliding = false
	R.teleport(P.pos + Vector3(FOE_DIST, 0, 0))
	R.max_hp = FOE_HP
	R.hp = FOE_HP
	R.max_armor = 0.0
	R.armor = 0.0
	if R.kin != null:
		R.kin.stow()
	return R

func _merge(P: Hunter) -> bool:
	if not KinMerge.press(P):
		return false
	for i in int((float(MergeForm.data()["xform_s"]) + 0.15) / DT):
		m.step(DT)
	P.merge_st["t"] = MERGE_SECS
	P.merge_st["T"] = MERGE_SECS
	return KinMerge.active(P) and String(P.merge_st.get("phase", "")) == "live"

func _hunter(id: String) -> void:
	var P := _fresh(id)
	ok(_merge(P), "%s: merges (the form is live)" % id)
	var R := _foe(P)
	for s in SLOTS:
		var went := _press(P, R, s)
		ok(went != "", "%s merged: %s goes off (%s)" % [id, s, went if went != "" else "nothing happened"])
		_reset(P, R)
	_bonuses(id, P)

## One slot pressed the way Match._gather_input sets it. Returns what was seen ("" when nothing went off).
func _press(P: Hunter, R: Hunter, slot: String) -> String:
	var seen := ""
	var shots := P.shot_n
	var used0 := int(P.used.get("kin_ab", 0))
	for i in FRAMES:
		P.inp["aim"] = R.pos + Vector3(0, 0.9, 0)
		P.inp["aim_y"] = R.pos.y
		P.dashes = P.max_dashes()
		P.inp["fire"] = slot == "lmb" and i < 6
		P.inp["sec_hold"] = slot == "rmb" and i < 2
		P.inp["dash_down"] = slot == "dash" and i < 2
		P.inp["crouch"] = slot == "crouch"
		P.inp["glide"] = slot == "glide" and i > 8
		P.inp["glide_btn"] = P.inp["glide"]
		if i == 0:
			_tap(P, slot)
		elif slot == "glide" and i == 4:
			P.inp["jump"] = true
		m.step(DT)
		R.hp = FOE_HP
		seen = seen if seen != "" else _went(P, slot, shots, used0)
	P.inp["crouch"] = false
	P.inp["glide"] = false
	P.inp["glide_btn"] = false
	return seen

func _tap(P: Hunter, slot: String) -> void:
	if P.ak:
		for key in P.ak.cd:
			P.ak.cd[key] = 0.0
	match slot:
		"rmb":
			P.inp["sec"] = true
		"e":
			P.inp["sig"] = true
		"r":
			HunterKeys.ult_pressed(P)      # (R goes straight to the kit, not through inp)
		"dash":
			P.inp["dash"] = true
		"boki":
			P.inp["kin_ab"] = true
		"jump", "glide":
			P.inp["jump"] = true

## What this frame shows of `slot` going off ("" when nothing yet).
func _went(P: Hunter, slot: String, shots: int, used0: int) -> String:
	match slot:
		"lmb":
			return "shot or swing" if P.shot_n > shots or P.swing_t > 0.0 else ""
		"rmb":
			return "slot flashed" if _flash(P, "sec") or P.ak.rmb_down or P.ak.ch_rmb < 1.0 else ""
		"e":
			return "cooldown %.1fs" % float(P.ak.cd["e"]) if float(P.ak.cd["e"]) > 0.0 or P.ak.e_t > 0.0 else ""
		"r":
			return "cooldown %.1fs" % float(P.ak.cd["x"]) if float(P.ak.cd["x"]) > 0.0 or P.ak.ult_running() else ""
		"dash":
			return "rolling" if P.roll_t > 0.0 or P.dashes < P.max_dashes() - 0.5 else ""
		"boki":
			var cd: float = P.kin.runner.cd_left("k1")
			return "cooldown %.1fs" % cd if int(P.used.get("kin_ab", 0)) > used0 and cd > 0.0 else ""
		"jump":
			return "airborne" if not P.grounded and P.vel.y > 0.0 else ""
		"glide":
			return "gliding" if P.gliding else ""
		"crouch":
			return "crouched" if P.crouch else ""
	return ""

func _flash(P: Hunter, id: String) -> bool:
	return m.hud != null and m.hud.slot_fx.has(id) and String(m.hud.slot_fx[id]["kind"]) == "cast"

## Back to a clean standing start for the next slot; the merge stays on.
func _reset(P: Hunter, R: Hunter) -> void:
	P.inp["move"] = Vector2.ZERO
	for i in 90:
		m.step(DT)
	P.stun_t = 0.0
	P.inv_t = 0.0
	P.hp = P.max_hp
	if P.ak:
		P.ak.drop_holds()
		for key in P.ak.cd:
			P.ak.cd[key] = 0.0
	P.teleport(Vector3(R.pos.x - FOE_DIST, P.pos.y, R.pos.z))
	_foe(P)

## The merge's own gifts are still on after all of that, and the merge is still running.
func _bonuses(id: String, P: Hunter) -> void:
	var form := MergeForm.of(P)
	ok(KinMerge.active(P), "%s: still merged after every ability" % id)
	ok(float(P.merge_st.get("shell", 0.0)) > 0.0, "%s: the shell is up (%.0f)" % [id, float(P.merge_st.get("shell", 0.0))])
	ok(P.get_node_or_null(MergeLook.NODE_NAME) != null, "%s: the merged look is on" % id)
	ok(P.owner_stat("cooldown") > 0.0 or float(form.get("haste", 0.0)) <= 0.0,
		"%s: the form's cooldown haste applies (%.2f)" % [id, P.owner_stat("cooldown")])
	var extra := {}
	for i in RIDER_TRIES:
		P._kin_riders(extra)          # (an "every Nth attack" rider only shows on its Nth)
	var rider: Dictionary = MergeForm.aug_of(form).get("lmb", {})
	ok(rider.is_empty() or not extra.is_empty(), "%s: the LMB rider rides your attacks (%s)" % [id, str(extra.keys())])
