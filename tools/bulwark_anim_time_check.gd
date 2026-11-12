extends RefCounted
## Albert's clip timing against his kit (briefs/DECISIONS.md 2026-11-07, parity first): each move's strike beat
## (the hammer head's fastest frame; the shield bone's for the aegis) is measured through WardenClips and set
## against the kit's own hit moment, measured in a match. Runs inside --bulwark-combo-check
## (tools/archer_bulwark_combo_check.gd). docs/heroes/bulwark.md "Animation timing" holds the table this keeps true.

const AKCheck := preload("res://tools/archetype_check.gd")
const DT := 1.0 / 60.0
const TOL := 0.04              # s: a 30 fps key either side of the kit's hit
const MOVES := ["bul_throw", "bul_recall", "bul_smash", "bul_guard", "bul_whirl", "bul_lumber", "bul_mend",
		"bul_ult_slam"]
var A: AKCheck
var beats := {}                # kmove -> {len, cock, peak, settle, vmax, bar}
var leads := {}                # kmove -> its "lead" (s skipped at the start)
var fades := {}                # kmove -> s it blends in over

func run(a) -> void:
	A = a
	clips()
	await kit()

# ------------------------------------------------------------------ the clips, offline
## Sweeps each kmove clip at 60 Hz through an AnimationPlayer on the clips' library (no blend) and tracks the
## hammer head (the blade tip on the hand bone), or the shield bone for the aegis, the way tools/clip_check.gd reads it.
func clips() -> void:
	var id := "bulwark"
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	A.main.add_child(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var cl: WardenClips = sync.get("clips")
	var tip := sync.get("blade_tip") as Node3D
	var hb := int(sync.get("blade_bone"))
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var shield := sk.find_bone("x_shield")
	cl.tree.active = false
	var glb := cl.tree.get_parent()
	var ap := AnimationPlayer.new()
	glb.add_child(ap)
	ap.root_node = ap.get_path_to(glb)
	ap.add_animation_library("", cl.lib)
	var moves: Dictionary = cl.d.get("kmoves", {})
	for km in MOVES:
		var mv: Dictionary = moves[km]
		var clip := String(mv["clip"])
		var length := cl.lib.get_animation(clip).length
		var pts: Array[Vector3] = []
		var t := 0.0
		ap.play(clip)
		while t < length:
			ap.seek(t, true)
			sk.force_update_all_bone_transforms()
			var p := sk.get_bone_global_pose(shield).origin if km == "bul_guard" \
					else sk.get_bone_global_pose(hb) * tip.position
			pts.append(m.to_local(sk.global_transform * p))
			t += DT
		var v: Array[float] = []
		for i in range(1, pts.size()):
			v.append(pts[i].distance_to(pts[i - 1]) / DT)
		beats[km] = _beats(v, length)
		leads[km] = float(mv.get("lead", 0.0))
		fades[km] = float(mv.get("fade", WardenClips.FADE))
		var b: Dictionary = beats[km]
		print("BEAT %-13s len %.2f cock %.2f peak %.2f settle %.2f vmax %4.1f lead %s  |%s|" % [km, length,
				b["cock"], b["peak"], b["settle"], b["vmax"], str(mv.get("lead", "-")), b["bar"]])
	m.free()

## From the tracked point's speed per frame: cock (the last quiet frame before the fastest), peak, settle (quiet
## for 0.1 s).
func _beats(v: Array[float], length: float) -> Dictionary:
	var vmax := 0.0
	var ip := 0
	for i in v.size():
		if v[i] > vmax:
			vmax = v[i]
			ip = i
	var ic := ip
	while ic > 0 and v[ic - 1] < v[ic]:
		ic -= 1
	var quiet := maxf(0.15 * vmax, 0.5)
	var settle := v.size()
	var still := 0
	for i in range(ip, v.size()):
		still = still + 1 if v[i] < quiet else 0
		if still >= 6:
			settle = i - 5
			break
	var bar := ""
	for i in range(0, v.size(), 3):
		bar += str(mini(9, int(9.0 * sqrt(v[i] / maxf(vmax, 0.001)))))
	return {"len": length, "cock": ic * DT, "peak": (ip + 1) * DT, "settle": settle * DT, "vmax": vmax, "bar": bar}

# ------------------------------------------------------------------ the kit, in a match
## Steps until `ev` holds (or `limit` s): returns [age of the kit's clip when it did, its anim_id, s since the press].
func _until(m: Match, K: BulwarkKit, ev: Callable, limit: float, each := Callable()) -> Array:
	var t := 0.0
	while t < limit:
		if each.is_valid():
			each.call()
		m.step(DT)
		t += DT
		if ev.call():
			return [m.time - K.anim_at, K.anim_id, t]
	return [-1.0, K.anim_id, t]

func _ev(what: String, r: Array) -> void:
	print("EVENT %-18s at %.3f into %s (%.2f s after the press)" % [what, r[0], r[1], r[2]])

## The clip's beat (`at`: "peak" or "settle", less the lead) sits on the kit's moment, within TOL.
func _on_beat(km: String, at: String, r: Array) -> void:
	var b: Dictionary = beats.get(km, {})
	var clip_at := float(b.get(at, -1.0)) - float(leads.get(km, 0.0))
	A.ok("bjorn anim: %s %s on the kit's moment" % [km, at], r[1] == km and absf(clip_at - float(r[0])) <= TOL,
			"clip %.2f - lead %.2f = %.2f vs kit %.3f into %s" % [b.get(at, -1.0), leads.get(km, 0.0), clip_at,
			r[0], r[1]])

func _fresh(m: Match, P: Hunter, K: BulwarkKit, home: Vector3, T: Hunter) -> void:
	P.inp["fire"] = false
	P.inp["sec_hold"] = false
	A.step(m, 1.2)
	if not K.mace.is_empty():
		K._catch(true)
	K.anim_id = ""
	for s in ["e", "rmb", "x"]:
		K.cd[s] = 0.0
	P.dashes = P.max_dashes()
	P.fire_cd = 0.0
	P.teleport(home)
	P.vel = Vector3.ZERO
	T.teleport(home + Vector3(2.2, 0, 0))
	T.hp = T.max_hp
	m.step(DT)
	A.aim_at(P, T.pos)

func kit() -> void:
	var r := A.setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: BulwarkKit = P.ak
	# LMB tap: the hammer leaves the hand; thrown ~6 m (the footage's 5-7 h) and called back
	_fresh(m, P, K, home, T)
	A.aim_at(P, home + Vector3(6.0, 0, 0))
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	var e := _until(m, K, func(): return not K.mace.is_empty() and String(K.mace["st"]) == "fly", 0.5)
	_ev("throw leaves", e)
	_on_beat("bul_throw", "peak", e)
	A.step(m, 0.6)
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	e = _until(m, K, func(): return K.mace.is_empty(), 1.0)
	_ev("recall caught", e)
	# LMB hold 0.6 s, let go: the swing's hit
	_fresh(m, P, K, home, T)
	A.step(m, 0.6, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	var hp0 := T.hp
	e = _until(m, K, func(): return T.hp < hp0 - 0.5, 0.5)
	_ev("swing hits", e)
	_on_beat("bul_smash", "peak", e)
	# RMB held: the aegis stands
	_fresh(m, P, K, home, T)
	P.inp["sec_hold"] = true
	K.press_rmb()
	e = _until(m, K, func(): return not K.wall.is_empty(), 0.5, func(): P.inp["sec_hold"] = true)
	_ev("aegis up", e)          # (the arm settles 0.07 s into bul_guard: inside the 0.1 s blend, kept)
	P.inp["sec_hold"] = false
	# Shift: the 360 Smash spin hit
	_fresh(m, P, K, home, T)
	var s0: int = K.spins
	P.do_dash()
	e = _until(m, K, func(): return K.spins > s0, 0.6)
	_ev("spin hits", e)
	_on_beat("bul_whirl", "peak", e)
	# X: the Faultline slam strikes the near cell
	_fresh(m, P, K, home, T)
	HunterKeys.ult_pressed(P)
	e = _until(m, K, func(): return K.ult.phase == "erupt", 1.0)
	_ev("ult slam", e)
	# (the hammer meets the ground where it stops: the clip's settle, not its fastest frame)
	_on_beat("bul_ult_slam", "settle", e)
	A.ok("bjorn anim: bul_ult_slam blends in inside a 30 fps key", fades["bul_ult_slam"] <= TOL,
			"fade %.2f" % fades["bul_ult_slam"])
	await A.done(m)
