extends RefCounted
## Kael's clip timing against his kit (briefs/DECISIONS.md 2026-11-07, parity first): for every move the clip's
## strike beat (the blade tip's fastest frame) is measured through WardenClips and set against the kit's own hit
## moment, measured in a match. Runs inside --juggernaut-combo-check (tools/zedran_feel_check.gd). A is
## tools/archetype_check.gd. docs/heroes/juggernaut.md "Animation timing" holds the table this keeps true.

const AKCheck := preload("res://tools/archetype_check.gd")
const DT := 1.0 / 60.0
const RUN_BASE_STEPS := 3.3  # footfalls/s at base size (= 3.0 as drawn at match_hunter_scale 1.10)
var a_v: AKCheck
var beats := {}  # clip -> {len, cock, peak, settle, v (speed per frame)}
var leads := {}  # clip -> its "lead" (s skipped at the start; under zero: the first frame held)
var maps := {}  # clip -> its "time" map ([[kit s, clip s]...]; replaces rate/lead/scale)
var speeds := {}  # clip -> [its "rate", its "scale"] (clip s per kit s, before and after the lead)
var shown := {}  # kit anim_ids seen in a row
var lane := 0  # each kit row on a fresh strip of ground (a Searing Wave's fire stays)
var run_steps := 0  # footfalls in one loop of the forward run clip
var wind_still := 0.0  # s into jug_lunge_wind where its pose holds (its hold_from)


func run(a) -> void:
	a_v = a
	clips()
	kit()


# ------------------------------------------------------------------ the clips, offline
## Sweeps each kmove clip at 60 Hz through an AnimationPlayer on the clips' library (synchronous, no blend)
## and tracks the blade tip on the hand bone, the way tools/clip_check.gd reads it.
func clips() -> void:
	var id := "juggernaut"
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	a_v.main.add_child(m)
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
		if mv.has("time"):
			maps[km] = mv["time"]
		speeds[km] = [float(mv.get("rate", 1.0)), float(mv.get("scale", 1.0))]
		if km == "jug_lunge_wind":
			wind_still = float(mv["hold_from"])
		beats[km]["p0"] = pts[0]
		beats[km]["pend"] = pts[pts.size() - 1]
		var b: Dictionary = beats[km]
		print(
			(
				"BEAT %-16s len %.2f cock %.2f peak %.2f settle %.2f vmax %4.1f lead %s  |%s|"
				% [km, length, b["cock"], b["peak"], b["settle"], b["vmax"], str(mv.get("lead", "-")), b["bar"]]
			)
		)
	# a negative lead holds the clip's first frame: it must be the held wind-up's last pose
	for pair in [["jug_lunge_wind", "jug_lunge"], ["jug_wave_wind", "jug_wave"]]:
		var gap := (beats[pair[0]]["pend"] as Vector3).distance_to(beats[pair[1]]["p0"])
		a_v.ok("kael anim: %s ends where %s starts" % [pair[0], pair[1]], gap < 0.1, "%.2f m apart" % gap)
	run_steps = _footfalls(ap, sk, String(cl.d["loco"]["run"]["f"]))
	m.free()


## Footfalls in one loop of a run clip: each ankle's low point near the ground counts once (a plant). The rig has
## no foot bone, so the ankle is the shin's far end, a thigh's length down its line (WardenSkeleton.CARRY_ON).
func _footfalls(ap: AnimationPlayer, sk: Skeleton3D, clip: String) -> int:
	var length := ap.get_animation(clip).length
	var steps := 0
	ap.play(clip)
	for side in ["L", "R"]:
		var bi := sk.find_bone("shin." + side)
		var shin := sk.get_bone_rest(bi).origin.length()
		var ys: Array[float] = []
		var t := 0.0
		while t < length:
			ap.seek(t, true)
			sk.force_update_all_bone_transforms()
			var pose := sk.get_bone_global_pose(bi)
			ys.append((pose.origin + pose.basis.y.normalized() * shin).y)
			t += DT
		var lo: float = ys.min()
		var span := float(ys.max()) - lo
		# (a plant: the ankle drops into the lowest 30% of its swing after lifting above 60%; two laps for the wrap)
		var up := false
		for i in ys.size() * 2:
			var y := ys[i % ys.size()]
			if y > lo + span * 0.6:
				up = true
			elif up and y < lo + span * 0.3:
				up = false
				if i >= ys.size():
					steps += 1
	print("RUN %s len %.2f footfalls %d" % [clip, length, steps])
	return steps


## From the tip's speed per frame: cock (the last quiet frame before the fastest), peak, settle (quiet for 0.1 s).
func _beats(v: Array[float], length: float, _pts: Array[Vector3]) -> Dictionary:
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
	var is_v := v.size()
	var run_v := 0
	for i in range(ip, v.size()):
		run_v = run_v + 1 if v[i] < quiet else 0
		if run_v >= 6:
			is_v = i - 5
			break
	var bar := ""
	for i in range(0, v.size(), 3):
		bar += str(mini(9, int(9.0 * sqrt(v[i] / maxf(vmax, 0.001)))))
	return {"len": length, "cock": ic * DT, "peak": (ip + 1) * DT, "settle": is_v * DT, "vmax": vmax, "bar": bar}


# ------------------------------------------------------------------ the kit, in a match
func _rig() -> Dictionary:
	var r := a_v.setup("juggernaut", 2.4)
	var p: Hunter = r[1]
	p.lvl = maxi(p.lvl, 6)
	p.slot_lv["ult"] = 1
	return {"m": r[0], "P": p, "T": r[2], "home": r[4], "K": p.ak}


func _fresh(m: Match, p: Hunter, k: JuggernautKit, home: Vector3, t: Hunter) -> void:
	a_v.step(m, 2.2)  # (the Searing Wave's burn ticks for 2 s)
	k.warchain.snap(true)
	k.riposte.drop()
	k.res = 0.0
	k.enraged_t = 0.0  # (an Enrage would play jug_roar over the move)
	shown = {}
	p.inp["sec_hold"] = false
	p.inp["fire"] = false
	a_v.step(m, 0.1)
	p.teleport(home)
	p.vel = Vector3.ZERO
	p.gliding = false
	for s in ["e", "rmb", "x", "air"]:
		k.cd[s] = 0.0
	k.ch_rmb = float(k.rmb_charges())
	p.dashes = 3.0
	p.fire_cd = 0.0
	lane = (lane + 1) % 5
	var at := home + Vector3(0, 0, [0.0, 4.0, -4.0, 8.0, -8.0][lane])
	p.teleport(at)
	t.teleport(at + Vector3(2.4, 0, 0))
	m.step(a_v.DT)
	a_v.aim_at(p, t.pos)
	t.hp = t.max_hp


## Steps until `ev` holds (or `limit` s): returns [age of the kit's clip when it did, its anim_id, elapsed].
func _until(m: Match, k: JuggernautKit, ev: Callable, limit: float, each := Callable()) -> Array:
	var t := 0.0
	while t < limit:
		if each.is_valid():
			each.call()
		m.step(a_v.DT)
		t += a_v.DT
		if ev.call():
			return [m.time - k.anim_at, k.anim_id, t]
	return [-1.0, k.anim_id, t]


## Steps until T loses hp (a cut to its cap, Kael's blight, is not a hit).
func _hit(m: Match, k: JuggernautKit, t: Hunter, limit: float, each := Callable()) -> Array:
	var hp0 := t.hp
	return _until(m, k, func(): return t.hp < hp0 - 0.5, limit, each)


func _ev(what: String, r: Array) -> void:
	print("EVENT %-22s at %.3f into %s (%.2f s after the press)" % [what, r[0], r[1], r[2]])


## A clip time on the kit's move clock (WardenClips._move_clip: clip t = (kit t x rate + lead) x scale).
func _kit_t(km: String, clip_t: float) -> float:
	if maps.has(km):  # a "time" map: the kit second whose clip second it is (the map's inverse)
		var pts: Array = maps[km]
		for i in range(1, pts.size()):
			if clip_t <= float(pts[i][1]):
				return lerpf(
					float(pts[i - 1][0]), float(pts[i][0]), inverse_lerp(float(pts[i - 1][1]), float(pts[i][1]), clip_t)
				)
		return float(pts[-1][0])
	var rs: Array = speeds.get(km, [1.0, 1.0])
	return (clip_t / float(rs[1]) - float(leads.get(km, 0.0))) / float(rs[0])


## The clip's strike frame (its fastest blade frame, on the kit's clock) sits on the kit's hit, within 0.04 s
## (a 30 fps key).
func _strike(km: String, r: Array) -> void:
	var b: Dictionary = beats.get(km, {})
	var at := _kit_t(km, float(b.get("peak", -1.0)))
	a_v.ok(
		"kael anim: %s strike frame on the kit's hit" % km,
		r[0] >= 0.0 and r[1] == km and absf(at - r[0]) <= 0.04,
		(
			"clip %.2f (lead %.2f, rate/scale %s) = %.3f vs kit %.3f into %s"
			% [b.get("peak", -1.0), leads.get(km, 0.0), str(speeds.get(km, [])), at, r[0], r[1]]
		)
	)


## A held pose shows only under the hold input.
func _hold(km: String, held: bool, what: String) -> void:
	a_v.ok(
		"kael anim: %s %s" % [km, "shows under the hold" if held else "never shows on a " + what],
		shown.has(km) == held,
		", ".join(shown.keys())
	)


## Running flat out: WardenGait (main) sets the clip rate from the move speed over the run clip's foot speed, so the
## planted feet stay put. The source's cadence (briefs/hero-ref/juggernaut.md "Cadence", ~4.5 footfalls/s) is not
## chased any more (that was `loco.cadence`, retired for the gait layer): this asserts the gait layer's rate is in
## charge and the run is no slower than the clip as keyed (3.0 footfalls/s), and prints the footfalls against 4.5.
func _run(m: Match, p: Hunter, k: JuggernautKit, home: Vector3, t: Hunter) -> void:
	_fresh(m, p, k, home, t)
	t.teleport(home + Vector3(0, 0, 30.0))
	var go := func(): p.inp["move"] = Vector2(0, -1)
	a_v.step(m, 1.2, go)
	var cl := p.model.get_node("Warden/Sync").get("clips") as WardenClips
	var spd := Vector2(p.vel.x, p.vel.z).length()
	# (headless, the visual never poses: feed the clips the run the kit just made, for a second so the blend settles)
	for i in 60:
		cl._loco({"vel": p.vel, "face": p.face}, DT)
	var rate := float(cl.tree.get("parameters/loco_rate/scale"))
	var length := cl.lib.get_animation(String(cl.d["loco"]["run"]["f"])).length
	var per_s := rate * run_steps / length
	print("RUN at %.2f m/s: clip rate %.2f, %.2f footfalls/s (%.2f Hz stride)" % [spd, rate, per_s, per_s * 0.5])
	var foot: Array = cl.d["loco"].get("foot_mps", [1.0, 1.0])
	# (foot_mps is at the model's own scale: a match draws Kael bigger, so the gait layer divides that out)
	var body_k := float(cl.root.get_meta("look_scale", cl.root.scale.y)) / absf(cl.root.scale.y)
	# (the floor is at Kael's base size: drawn body.match_k bigger, the planted feet take longer strides, so the
	# footfalls drop by match_k; 3.0/s as drawn at the old match_hunter_scale 1.10 = 3.3/s at base size)
	var base_s := per_s * Arch.match_k(p.arch)
	a_v.ok(
		"kael anim: running, the clip rate is the gait layer's (speed over foot speed) and no slower than keyed",
		absf(rate - spd * body_k / float(foot[1])) <= 0.05 and base_s >= RUN_BASE_STEPS,
		"rate %.2f, %.2f/s (%.2f/s at base size) at %.2f m/s" % [rate, per_s, base_s, spd]
	)
	p.inp["move"] = Vector2.ZERO


func kit() -> void:
	var g := _rig()
	var m: Match = g["m"]
	var p: Hunter = g["P"]
	var t: Hunter = g["T"]
	var k: JuggernautKit = g["K"]
	var home: Vector3 = g["home"]
	# slash (and the second one, alternating)
	_fresh(m, p, k, home, t)
	p.inp["fire"] = true
	m.step(a_v.DT)
	p.inp["fire"] = false
	var note := func(): shown[k.anim_id] = true
	var r := _hit(m, k, t, 0.5, note)
	_ev("slash hit", r)
	_strike("jug_slash_r", r)
	a_v.step(m, 0.3, note)
	_hold("jug_wave_wind", false, "tap")
	t.hp = t.max_hp
	p.inp["fire"] = true
	m.step(a_v.DT)
	p.inp["fire"] = false
	r = _hit(m, k, t, 0.5)
	_ev("slash 2 hit", r)
	_strike("jug_slash_l", r)
	# wave: held 1.0 s, let go
	_fresh(m, p, k, home, t)
	var held := func(): p.inp["fire"] = true
	held.call()
	a_v.step(m, 1.0, held)
	shown[k.anim_id] = true
	_hold("jug_wave_wind", true, "")
	p.inp["fire"] = false
	r = _hit(m, k, t, 0.6)
	_ev("wave hit", r)
	_strike("jug_wave", r)
	# slam: a tap
	_fresh(m, p, k, home, t)
	a_v.tap(m, p)
	r = _hit(m, k, t, 1.0, note)
	_ev("slam hit", r)
	_strike("jug_slam", r)
	_hold("jug_lunge_wind", false, "tap")
	# lunge: held 0.6 s, let go; the travel's end, the hit
	_fresh(m, p, k, home, t)
	t.teleport(p.pos + Vector3(5.0, 0, 0))
	a_v.aim_at(p, t.pos)
	var hs := func(): p.inp["sec_hold"] = true
	hs.call()
	k.press_rmb()
	a_v.step(m, 0.6, hs)
	shown[k.anim_id] = true
	_hold("jug_lunge_wind", true, "")
	t.hp = t.max_hp
	p.inp["sec_hold"] = false
	r = _hit(m, k, t, 1.0)
	_ev("lunge hit", r)
	_strike("jug_lunge", r)
	_ev("lunge stops", _until(m, k, func(): return k.lunge.is_empty(), 1.0))
	# the perfect release (owner): let go in the first window, at full charge, the cocked pose already still
	var sd := k.rmb_def()
	var still_at := float(sd["hold"]) + wind_still
	a_v.ok(
		"kael anim: jug_lunge_wind is held still by the first perfect window",
		still_at <= k.rmb_charge_full(),
		"still at %.2f s of hold, window at %.2f s" % [still_at, k.rmb_charge_full()]
	)
	_fresh(m, p, k, home, t)
	t.teleport(p.pos + Vector3(5.0, 0, 0))
	a_v.aim_at(p, t.pos)
	var perfects0 := k.perfects
	hs.call()
	k.press_rmb()
	a_v.step(m, k.rmb_charge_full() + 0.05, hs)
	t.hp = t.max_hp
	p.inp["sec_hold"] = false
	r = _hit(m, k, t, 1.0)
	_ev("perfect lunge hit", r)
	a_v.ok("kael anim: a release in the window is a perfect Lunge", k.perfects == perfects0 + 1)
	_strike("jug_lunge", r)
	# air slam: a tap in the air
	_fresh(m, p, k, home, t)
	t.teleport(p.pos + Vector3(1.0, 0, 0))
	p.teleport(p.pos + Vector3(0, 5.0, 0))
	p.grounded = false
	p.vel = Vector3.ZERO
	a_v.aim_at(p, t.pos)
	a_v.tap(m, p)
	var ph := {}
	var seen := func():
		var f := String(k.meteor.phase)
		if f != "" and not ph.has(f):
			ph[f] = [m.time - k.anim_at, k.anim_id]
	r = _hit(m, k, t, 1.5, seen)
	seen.call()
	_ev("meteor hit", r)
	_strike("jug_meteor_land", r)
	for f in ["dive", "recover"]:
		print("EVENT meteor %-15s at %.3f into %s" % [f, ph.get(f, [-1.0, "?"])[0], ph.get(f, [-1.0, "?"])[1]])
	var dv: Array = ph.get("dive", [-1.0, "?"])
	var dive_clip := _kit_t("jug_meteor", float(beats["jug_meteor"]["peak"]))
	a_v.ok(
		"kael anim: jug_meteor's dive starts on the kit's dive (the hang is the held pose)",
		dv[1] == "jug_meteor" and absf(float(dv[0]) - dive_clip) <= 0.04,
		"kit dive at %.3f, clip %.2f on the kit clock %.3f" % [dv[0], beats["jug_meteor"]["peak"], dive_clip]
	)
	_ev("meteor free", _until(m, k, func(): return k.meteor.phase == "", 1.0))
	# dash (Rampage)
	_fresh(m, p, k, home, t)
	t.teleport(p.pos + Vector3(5.5, 0, 0))
	p.inp["move"] = Vector2(1, 0)
	p.do_dash()
	m.step(a_v.DT)
	var p0 := p.pos
	_ev("dash moves", _until(m, k, func(): return p.pos.distance_to(p0) > 0.05, 0.5))
	r = _hit(m, k, t, 0.6)
	_ev("dash hit", r)
	_strike("jug_dash", r)
	p.inp["move"] = Vector2.ZERO
	_ev("dash stops", _until(m, k, func(): return Vector2(p.vel.x, p.vel.z).length() < 1.0, 0.8))
	# chain: the throw lands, the pull arrives
	_fresh(m, p, k, home, t)
	t.teleport(p.pos + Vector3(7.0, 0, 0))
	a_v.aim_at(p, t.pos)
	k.use_e()
	_ev("chain hooks", _until(m, k, func(): return k.warchain.hooked(), 1.0))
	a_v.step(m, 0.1)
	k.use_e()
	var p1 := p.pos
	var t1 := t.pos
	_ev("pull moves", _until(m, k, func(): return p.pos.distance_to(p1) > 0.05 or t.pos.distance_to(t1) > 0.05, 0.5))
	_ev("pull arrives", _until(m, k, func(): return not k.warchain.pulling(), 1.5))
	# Cinder Spin: RMB pressed in the pull
	_fresh(m, p, k, home, t)
	t.teleport(p.pos + Vector3(7.0, 0, 0))
	a_v.aim_at(p, t.pos)
	k.use_e()
	a_v.step(m, 0.4)
	k.use_e()
	a_v.step(m, 0.05)
	t.hp = t.max_hp
	var spins0 := k.spins
	p.inp["sec_hold"] = true
	k.press_rmb()
	print(
		(
			"EVENT %-22s spins +%d, %s at %.3f (the stage runs on the press)"
			% ["spin on press", k.spins - spins0, k.anim_id, m.time - k.anim_at]
		)
	)
	a_v.step(m, 0.3, func(): p.inp["sec_hold"] = true)
	p.inp["sec_hold"] = false
	# chain lunge: RMB charged while tethered, let go
	_fresh(m, p, k, home, t)
	t.teleport(p.pos + Vector3(7.0, 0, 0))
	a_v.aim_at(p, t.pos)
	k.use_e()
	a_v.step(m, 0.4)
	t.hp = t.max_hp
	hs.call()
	k.press_rmb()
	a_v.step(m, 0.6, hs)
	p.inp["sec_hold"] = false
	_ev("chainlunge hit", _hit(m, k, t, 1.0))
	_ev("chainlunge stops", _until(m, k, func(): return k.lunge.is_empty(), 1.0))
	# haul: the Lunge charging when the pull starts, the slam on the arrival
	_fresh(m, p, k, home, t)
	t.teleport(p.pos + Vector3(7.0, 0, 0))
	a_v.aim_at(p, t.pos)
	k.use_e()
	a_v.step(m, 0.4)
	hs.call()
	k.press_rmb()
	a_v.step(m, 0.2, hs)
	t.hp = t.max_hp
	k.use_e()
	_ev("haul winds", _until(m, k, func(): return not k.haul.is_empty(), 0.3, hs))
	a_v.ok(
		"kael anim: jug_haul_wind only once the Haul is armed", k.anim_id == "jug_haul_wind" and not k.haul.is_empty()
	)
	r = _hit(m, k, t, 1.5, hs)
	_ev("haul slams", r)
	_strike("jug_haulslam", r)
	p.inp["sec_hold"] = false
	# Gilded Riposte: the guard runs its course, the strike, the recover
	_fresh(m, p, k, home, t)
	t.teleport(p.pos + Vector3(1.5, 0, 0))
	a_v.aim_at(p, t.pos)
	HunterKeys.ult_pressed(p)
	print("EVENT %-22s %s" % ["ult pressed", k.anim_id])
	var rd := k.riposte.data()
	var guard := _until(m, k, func(): return String(k.riposte.st.get("phase", "")) == "strike", 1.0)
	_ev("riposte strikes", guard)
	r = _hit(m, k, t, 0.5)
	_ev("riposte hit", r)
	# (the kit hands the body to jug_ult_recover on the hit's own frame: the hit is r[2] s into the strike)
	_strike("jug_riposte", [r[2], "jug_riposte"])
	var done := _until(m, k, func(): return not k.riposte.running(), 1.0)
	_ev("riposte done", done)
	# guard .65 / strike .1 / recover .35 (the source's Retaliation), each within a 60 Hz step and a half
	var phases := [
		["guard", guard[2], rd["guard"]], ["strike", r[2], rd["strike_t"]], ["recover", done[2], rd["recover"]]
	]
	for row in phases:
		a_v.ok(
			"kael anim: riposte %s runs %.2f s" % [row[0], row[2]],
			absf(float(row[1]) - float(row[2])) <= 0.025,
			"%.3f s" % row[1]
		)
	var rl := _kit_t("jug_ult_recover", float(beats["jug_ult_recover"]["len"]))
	# (the recover is jug_ult_recover's own clip; its tail past the hand-off plays out under the blend to the legs)
	a_v.ok(
		"kael anim: jug_ult_recover ends within the hand-off blend",
		float(done[2]) <= rl + a_v.DT * 0.5 and rl - float(done[2]) <= WardenClips.FADE_LOCO,
		"clip %.2f vs kit %.3f" % [rl, done[2]]
	)
	_run(m, p, k, home, t)
	a_v.done(m)
