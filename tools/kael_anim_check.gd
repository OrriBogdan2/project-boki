extends RefCounted
## Kael's clip timing against his kit (briefs/DECISIONS.md 2026-11-07, parity first): for every move the clip's
## strike beat (the blade tip's fastest frame) is measured through WardenClips and set against the kit's own hit
## moment, measured in a match. Runs inside --juggernaut-combo-check (tools/zedran_feel_check.gd). A is
## tools/archetype_check.gd. docs/heroes/juggernaut.md "Animation timing" holds the table this keeps true.

const AKCheck := preload("res://tools/archetype_check.gd")
const DT := 1.0 / 60.0
var A: AKCheck
var beats := {}            # clip -> {len, cock, peak, settle, v (speed per frame)}
var leads := {}            # clip -> its "lead" (s skipped at the start; under zero: the first frame held)
var shown := {}            # kit anim_ids seen in a row
var lane := 0              # each kit row on a fresh strip of ground (a Searing Wave's fire stays)

func run(a) -> void:
	A = a
	await clips()
	await kit()

# ------------------------------------------------------------------ the clips, offline
## Sweeps each kmove clip at 60 Hz through an AnimationPlayer on the clips' library (synchronous, no blend)
## and tracks the blade tip on the hand bone, the way tools/clip_check.gd reads it.
func clips() -> void:
	var id := "juggernaut"
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	A.main.add_child(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var cl: WardenClips = sync.get("clips")
	var tip := sync.get("blade_tip") as Node3D
	var hb := int(sync.get("blade_bone"))
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	cl.tree.active = false
	var glb := cl.tree.get_parent()
	var ap := AnimationPlayer.new()
	glb.add_child(ap)
	ap.root_node = ap.get_path_to(glb)
	ap.add_animation_library("", cl.lib)
	var moves: Dictionary = cl.d.get("kmoves", {})
	var names := moves.keys()
	names.sort()
	for km in names:
		var mv: Dictionary = moves[km]
		var clip := String(mv["clip"])
		var length := cl.lib.get_animation(clip).length
		var pts: Array[Vector3] = []
		var t := 0.0
		ap.play(clip)
		while t < length:
			ap.seek(t, true)
			sk.force_update_all_bone_transforms()
			pts.append(m.to_local(sk.global_transform * (sk.get_bone_global_pose(hb) * tip.position)))
			t += DT
		var v: Array[float] = []
		for i in range(1, pts.size()):
			v.append(pts[i].distance_to(pts[i - 1]) / DT)
		beats[km] = _beats(v, length, pts)
		leads[km] = float(mv.get("lead", 0.0))
		beats[km]["p0"] = pts[0]
		beats[km]["pend"] = pts[pts.size() - 1]
		var b: Dictionary = beats[km]
		print("BEAT %-16s len %.2f cock %.2f peak %.2f settle %.2f vmax %4.1f lead %s  |%s|" % [km, length,
				b["cock"], b["peak"], b["settle"], b["vmax"], str(mv.get("lead", "-")), b["bar"]])
	# a negative lead holds the clip's first frame: it must be the held wind-up's last pose
	for pair in [["jug_lunge_wind", "jug_lunge"], ["jug_wave_wind", "jug_wave"]]:
		var gap := (beats[pair[0]]["pend"] as Vector3).distance_to(beats[pair[1]]["p0"])
		A.ok("kael anim: %s ends where %s starts" % [pair[0], pair[1]], gap < 0.1, "%.2f m apart" % gap)
	m.free()

## From the tip's speed per frame: cock (the last quiet frame before the fastest), peak, settle (quiet for 0.1 s).
func _beats(v: Array[float], length: float, pts: Array[Vector3]) -> Dictionary:
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
	var is_ := v.size()
	var run := 0
	for i in range(ip, v.size()):
		run = run + 1 if v[i] < quiet else 0
		if run >= 6:
			is_ = i - 5
			break
	var bar := ""
	for i in range(0, v.size(), 3):
		bar += str(mini(9, int(9.0 * sqrt(v[i] / maxf(vmax, 0.001)))))
	return {"len": length, "cock": ic * DT, "peak": (ip + 1) * DT, "settle": is_ * DT, "vmax": vmax, "bar": bar}

# ------------------------------------------------------------------ the kit, in a match
func _rig() -> Dictionary:
	var r := A.setup("juggernaut", 2.4)
	var P: Hunter = r[1]
	P.lvl = maxi(P.lvl, 6)
	P.slot_lv["ult"] = 1
	return {"m": r[0], "P": P, "T": r[2], "home": r[4], "K": P.ak}

func _fresh(m: Match, P: Hunter, K: JuggernautKit, home: Vector3, T: Hunter) -> void:
	A.step(m, 2.2)                 # (the Searing Wave's burn ticks for 2 s)
	K.warchain.snap("")
	K.riposte.drop()
	K.res = 0.0
	K.enraged_t = 0.0           # (an Enrage would play jug_roar over the move)
	shown = {}
	P.inp["sec_hold"] = false
	P.inp["fire"] = false
	A.step(m, 0.1)
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.gliding = false
	for s in ["e", "rmb", "x", "air"]:
		K.cd[s] = 0.0
	K.ch_rmb = float(K.rmb_charges())
	P.dashes = 3.0
	P.fire_cd = 0.0
	lane = (lane + 1) % 5
	var at := home + Vector3(0, 0, [0.0, 4.0, -4.0, 8.0, -8.0][lane])
	P.teleport(at)
	T.teleport(at + Vector3(2.4, 0, 0))
	m.step(A.DT)
	A.aim_at(P, T.pos)
	T.hp = T.max_hp

## Steps until `ev` holds (or `limit` s): returns [age of the kit's clip when it did, its anim_id, elapsed].
func _until(m: Match, K: JuggernautKit, ev: Callable, limit: float, each := Callable()) -> Array:
	var t := 0.0
	while t < limit:
		if each.is_valid():
			each.call()
		m.step(A.DT)
		t += A.DT
		if ev.call():
			return [m.time - K.anim_at, K.anim_id, t]
	return [-1.0, K.anim_id, t]

## Steps until T loses hp (a cut to its cap, Kael's blight, is not a hit).
func _hit(m: Match, K: JuggernautKit, T: Hunter, limit: float, each := Callable()) -> Array:
	var hp0 := T.hp
	return _until(m, K, func(): return T.hp < hp0 - 0.5, limit, each)

func _ev(what: String, r: Array) -> void:
	print("EVENT %-22s at %.3f into %s (%.2f s after the press)" % [what, r[0], r[1], r[2]])

## The clip's strike frame (its fastest blade frame, less the lead) sits on the kit's hit, within 0.04 s (a 30 fps key).
func _strike(km: String, r: Array) -> void:
	var b: Dictionary = beats.get(km, {})
	var at := float(b.get("peak", -1.0)) - float(leads.get(km, 0.0))
	A.ok("kael anim: %s strike frame on the kit's hit" % km, r[0] >= 0.0 and r[1] == km and absf(at - r[0]) <= 0.04,
			"clip %.2f - lead %.2f = %.2f vs kit %.3f into %s" % [b.get("peak", -1.0), leads.get(km, 0.0), at, r[0],
			r[1]])

## A held pose shows only under the hold input.
func _hold(km: String, held: bool, what: String) -> void:
	A.ok("kael anim: %s %s" % [km, "shows under the hold" if held else "never shows on a " + what],
			shown.has(km) == held, ", ".join(shown.keys()))

func kit() -> void:
	var g := _rig()
	var m: Match = g["m"]
	var P: Hunter = g["P"]
	var T: Hunter = g["T"]
	var K: JuggernautKit = g["K"]
	var home: Vector3 = g["home"]
	# slash (and the second one, alternating)
	_fresh(m, P, K, home, T)
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	var note := func(): shown[K.anim_id] = true
	var r := _hit(m, K, T, 0.5, note)
	_ev("slash hit", r)
	_strike("jug_slash_r", r)
	A.step(m, 0.3, note)
	_hold("jug_wave_wind", false, "tap")
	T.hp = T.max_hp
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	r = _hit(m, K, T, 0.5)
	_ev("slash 2 hit", r)
	_strike("jug_slash_l", r)
	# wave: held 1.0 s, let go
	_fresh(m, P, K, home, T)
	var held := func(): P.inp["fire"] = true
	held.call()
	A.step(m, 1.0, held)
	shown[K.anim_id] = true
	_hold("jug_wave_wind", true, "")
	P.inp["fire"] = false
	r = _hit(m, K, T, 0.6)
	_ev("wave hit", r)
	_strike("jug_wave", r)
	# slam: a tap
	_fresh(m, P, K, home, T)
	A.tap(m, P)
	r = _hit(m, K, T, 1.0, note)
	_ev("slam hit", r)
	_strike("jug_slam", r)
	_hold("jug_lunge_wind", false, "tap")
	# lunge: held 0.6 s, let go; the travel's end, the hit
	_fresh(m, P, K, home, T)
	T.teleport(P.pos + Vector3(5.0, 0, 0))
	A.aim_at(P, T.pos)
	var hs := func(): P.inp["sec_hold"] = true
	hs.call()
	K.press_rmb()
	A.step(m, 0.6, hs)
	shown[K.anim_id] = true
	_hold("jug_lunge_wind", true, "")
	T.hp = T.max_hp
	P.inp["sec_hold"] = false
	r = _hit(m, K, T, 1.0)
	_ev("lunge hit", r)
	_strike("jug_lunge", r)
	_ev("lunge stops", _until(m, K, func(): return K.lunge.is_empty(), 1.0))
	# air slam: a tap in the air
	_fresh(m, P, K, home, T)
	T.teleport(P.pos + Vector3(1.0, 0, 0))
	P.teleport(P.pos + Vector3(0, 5.0, 0))
	P.grounded = false
	P.vel = Vector3.ZERO
	A.aim_at(P, T.pos)
	A.tap(m, P)
	var ph := {}
	var seen := func():
		var f := String(K.meteor.phase)
		if f != "" and not ph.has(f):
			ph[f] = [m.time - K.anim_at, K.anim_id]
	r = _hit(m, K, T, 1.5, seen)
	seen.call()
	_ev("meteor hit", r)
	_strike("jug_meteor_land", r)
	for f in ["dive", "recover"]:
		print("EVENT meteor %-15s at %.3f into %s" % [f, ph.get(f, [-1.0, "?"])[0], ph.get(f, [-1.0, "?"])[1]])
	var dv: Array = ph.get("dive", [-1.0, "?"])
	A.ok("kael anim: jug_meteor's dive starts on the kit's dive (the hang is the held pose)",
			dv[1] == "jug_meteor" and absf(float(dv[0]) - float(beats["jug_meteor"]["peak"])) <= 0.04,
			"kit dive at %.3f, clip %.2f" % [dv[0], beats["jug_meteor"]["peak"]])
	_ev("meteor free", _until(m, K, func(): return K.meteor.phase == "", 1.0))
	# dash (Rampage)
	_fresh(m, P, K, home, T)
	T.teleport(P.pos + Vector3(5.5, 0, 0))
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	m.step(A.DT)
	var p0 := P.pos
	_ev("dash moves", _until(m, K, func(): return P.pos.distance_to(p0) > 0.05, 0.5))
	r = _hit(m, K, T, 0.6)
	_ev("dash hit", r)
	_strike("jug_dash", r)
	P.inp["move"] = Vector2.ZERO
	_ev("dash stops", _until(m, K, func(): return Vector2(P.vel.x, P.vel.z).length() < 1.0, 0.8))
	# chain: the throw lands, the pull arrives
	_fresh(m, P, K, home, T)
	T.teleport(P.pos + Vector3(7.0, 0, 0))
	A.aim_at(P, T.pos)
	K.use_e()
	_ev("chain hooks", _until(m, K, func(): return K.warchain.hooked(), 1.0))
	A.step(m, 0.1)
	K.use_e()
	var p1 := P.pos
	var t1 := T.pos
	_ev("pull moves", _until(m, K, func(): return P.pos.distance_to(p1) > 0.05 or T.pos.distance_to(t1) > 0.05, 0.5))
	_ev("pull arrives", _until(m, K, func(): return not K.warchain.pulling(), 1.5))
	# Cinder Spin: RMB pressed in the pull
	_fresh(m, P, K, home, T)
	T.teleport(P.pos + Vector3(7.0, 0, 0))
	A.aim_at(P, T.pos)
	K.use_e()
	A.step(m, 0.4)
	K.use_e()
	A.step(m, 0.05)
	T.hp = T.max_hp
	var spins0 := K.spins
	P.inp["sec_hold"] = true
	K.press_rmb()
	print("EVENT %-22s spins +%d, %s at %.3f (the stage runs on the press)" % ["spin on press", K.spins - spins0,
			K.anim_id, m.time - K.anim_at])
	A.step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	# chain lunge: RMB charged while tethered, let go
	_fresh(m, P, K, home, T)
	T.teleport(P.pos + Vector3(7.0, 0, 0))
	A.aim_at(P, T.pos)
	K.use_e()
	A.step(m, 0.4)
	T.hp = T.max_hp
	hs.call()
	K.press_rmb()
	A.step(m, 0.6, hs)
	P.inp["sec_hold"] = false
	_ev("chainlunge hit", _hit(m, K, T, 1.0))
	_ev("chainlunge stops", _until(m, K, func(): return K.lunge.is_empty(), 1.0))
	# haul: the Lunge charging when the pull starts, the slam on the arrival
	_fresh(m, P, K, home, T)
	T.teleport(P.pos + Vector3(7.0, 0, 0))
	A.aim_at(P, T.pos)
	K.use_e()
	A.step(m, 0.4)
	hs.call()
	K.press_rmb()
	A.step(m, 0.2, hs)
	T.hp = T.max_hp
	K.use_e()
	_ev("haul winds", _until(m, K, func(): return not K.haul.is_empty(), 0.3, hs))
	A.ok("kael anim: jug_haul_wind only once the Haul is armed", K.anim_id == "jug_haul_wind" and not K.haul.is_empty())
	r = _hit(m, K, T, 1.5, hs)
	_ev("haul slams", r)
	_strike("jug_haulslam", r)
	P.inp["sec_hold"] = false
	# Gilded Riposte: the guard runs its course, the strike, the recover
	_fresh(m, P, K, home, T)
	T.teleport(P.pos + Vector3(1.5, 0, 0))
	A.aim_at(P, T.pos)
	HunterKeys.ult_pressed(P)
	print("EVENT %-22s %s" % ["ult pressed", K.anim_id])
	_ev("riposte strikes", _until(m, K, func(): return String(K.riposte.st.get("phase", "")) == "strike", 1.0))
	r = _hit(m, K, T, 0.5)
	_ev("riposte hit", r)
	_strike("jug_riposte", r)
	_ev("riposte recovers", _until(m, K, func(): return String(K.riposte.st.get("phase", "")) == "recover", 0.5))
	_ev("riposte done", _until(m, K, func(): return not K.riposte.running(), 1.0))
	A.done(m)
