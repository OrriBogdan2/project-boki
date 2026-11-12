extends "res://tools/archetype_check.gd"
## The parity pass (the owner's 18:45 request, briefs-s2/PARITY_BRIEF.md) for Hem, Sparkle and Breah: each LMB's
## tracking (the aim and the body follow the cursor during the attack, also while walking), its timing and cadence,
## its range and projectile speed against the source (game data, then the footage at 5 fps), and each move's beats.
## Runs from each hero's combo check (--archer-combo-check, --mage-combo-check, --dolm-combo-check), which adds n
## and fails.
## The source numbers are in the "Parity pass" table of docs/heroes/<id>.md.

const TRACK_DEG := 15.0          # deg: the body faces the cursor within this 0.1 s after the cursor moves
const SHOT_DEG := 5.0            # deg: a shot leaves along the aim it was fired on

## The body's facing against the aim now, in degrees.
func face_err(P: Hunter) -> float:
	var ad := P.aim_dir()
	return rad_to_deg(absf(angle_difference(P.face, atan2(-ad.x, -ad.y))))

## The newest shot of P's (its sid), or -1.
func last_sid(m: Match, P: Hunter) -> int:
	var last := -1
	for s in m.shots:
		if s["by"] == P:
			last = maxi(last, int(s["sid"]))
	return last

func shot_of(m: Match, sid: int) -> Dictionary:
	for s in m.shots:
		if int(s["sid"]) == sid:
			return s
	return {}

## A move's beats: the time of its first posed key (the action) and of its last (back to rest).
func beats(id: String) -> Vector2:
	var keys: Array = HunterAnim.km_def(id).get("keys", [])
	if keys.size() < 2:
		return Vector2(-1, -1)
	return Vector2(float(keys[1][0]), float(keys[-1][0]))

func _at_angle(P: Hunter, home: Vector3, deg: float, dist := 8.0) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(P.pos.x + cos(a) * dist, home.y, P.pos.z + sin(a) * dist)

## Walking speed over `secs` with `each` run per step.
func _speed(m: Match, P: Hunter, secs: float, each: Callable) -> float:
	var a := P.pos
	step(m, secs, each)
	return Vector2(P.pos.x - a.x, P.pos.z - a.z).length() / secs

# ------------------------------------------------------------------ Hem: the bow
func pin() -> void:
	var r := setup("archer", 7.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[4]
	var K: ArcherKit = P.ak
	P.equip("longbow", 0)
	step(m, 0.3)
	P.inp["move"] = Vector2(0, 1)
	var east := func():
		aim_at(P, _at_angle(P, home, 0.0))
	var run_v := _speed(m, P, 0.4, east)
	P.inp["fire"] = true
	var draw_v := _speed(m, P, 0.4, east)
	ok("parity pin: drawing she walks slower (footage f111-116), about 0.7 of her run",
		draw_v < run_v * 0.8 and draw_v > run_v * 0.55, "%.1f of %.1f m/s" % [draw_v, run_v])
	var north := func():
		aim_at(P, _at_angle(P, home, -90.0))
	step(m, 0.1, north)
	ok("parity pin: mid-draw the body turns to a moved cursor at once (the source turns throughout)",
		face_err(P) < TRACK_DEG and P.draw_t > 0.0, "%.0f deg" % face_err(P))
	step(m, 0.5, north)             # (past the 0.35 s perfect window, before Supercharged: the plain release move)
	var n0 := last_sid(m, P)
	P.inp["fire"] = false
	m.step(DT)
	var s := shot_of(m, last_sid(m, P))
	var v: Vector2 = s.get("vel", Vector2.ZERO)
	var err := rad_to_deg(absf(v.angle_to(Vector2(0, -1))))
	ok("parity pin: the arrow leaves along the new aim, while walking", last_sid(m, P) > n0 and err < SHOT_DEG,
		"%.1f deg" % err)
	m.step(DT)                     # (the kit plays the release move on its next tick)
	var loose := K.anim_id
	var b := beats(loose)
	ok("parity pin: the release is a snap (string hand back within 0.1s, settled by 0.45s; footage: 1 frame)",
		loose in ["arc_loose", "arc_super"] and b.x <= 0.1 and b.y <= 0.45, "%s %.2f / %.2f" % [loose, b.x, b.y])
	P.inp["fire"] = true
	var t := 0.0
	while P.draw_t < 0.0 and t < 2.0:
		north.call()
		m.step(DT)
		t += DT
	ok("parity pin: the next draw starts about 0.5s after the release (card: 0.5s)", t > 0.4 and t < 0.62,
		"%.2f s" % t)
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	_pin_audit(m, P, r[2], r[3], K, home)
	await done(m)

## The audit (Nov 3 23:40): cooldowns from the data, the Heavy Shot stops on the first foe, and an early-release
## wall pin pays a share of the wall hit.
func _pin_audit(m: Match, P: Hunter, T: Hunter, T2: Hunter, K: ArcherKit, home: Vector3) -> void:
	var pd: Dictionary = K.rmb_def()["pin"]
	ok("audit pin: cooldowns from the data (Phase Walk 9.5s, Rain of Arrows 15s, Virideth's Fury 60s)",
		float(K.dash_def()["cd"]) == 9.5 and float(K.e_def()["cooldown"]) == 15.0
		and float(K.x_def()["cooldown"]) == 60.0)
	ok("audit pin: no knock heal and no instant Focus draw in the kit data",
		not K.res_def().has("knock_heal") and not pd.has("pierce"))
	fresh(T)
	fresh(T2)
	P.teleport(home)
	T.teleport(home + Vector3(5, 0, 0))
	T2.teleport(home + Vector3(7, 0, 0))
	T.inv_t = 0.0
	T2.inv_t = 0.0
	step(m, 0.2)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	aim_at(P, T.pos)
	P.inp["sec_hold"] = true
	K.press_rmb()
	var hold := func():
		P.inp["sec_hold"] = true
		aim_at(P, T.pos)
	step(m, 1.2, hold)
	P.inp["sec_hold"] = false
	step(m, 0.6)
	ok("audit pin: the Heavy Shot stops on the first foe (data: one target, a knockback; no pierce)",
		dmg(T) > 10.0 and dmg(T2) == 0.0, "%.0f / %.0f" % [dmg(T), dmg(T2)])

# ------------------------------------------------------------------ Sparkle: the finger bolts
func vireo() -> void:
	var r := setup("mage", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[4]
	var K: MageKit = P.ak
	step(m, 0.3)
	P.inp["move"] = Vector2(0, 1)
	P.inp["fire"] = true
	var sweep_deg := 0.0
	var seen := last_sid(m, P)
	var fired: Array = []          # [time, sid, the aim's direction that step]
	var worst := 0.0
	var worst_face := 0.0
	var anims := {}
	var t := 0.0
	while t < 2.5:
		sweep_deg += 60.0 * DT       # the cursor sweeps round her at 60 deg/s while she walks
		aim_at(P, _at_angle(P, home, sweep_deg))
		var ad := P.aim_dir()
		m.step(DT)
		t += DT
		if t > 0.1:
			worst_face = maxf(worst_face, face_err(P))
		var sid := last_sid(m, P)
		if sid > seen:
			seen = sid
			var v: Vector2 = shot_of(m, sid).get("vel", Vector2.ZERO)
			worst = maxf(worst, rad_to_deg(absf(v.angle_to(ad))))
			fired.append([t, sid, v.length()])
			anims[K.anim_id] = true
	var gap := float(fired[1][0]) - float(fired[0][0]) if fired.size() >= 2 else 0.0
	ok("parity vireo: held, one bolt every 0.648s (item 116), also while walking",
		absf(gap - 0.648) < 0.05 and fired.size() >= 3,
		"%d bolts, gap %.2f s" % [fired.size(), gap])
	ok("parity vireo: each bolt leaves along the cursor of its step, the body facing it (cursor sweeping 60 deg/s)",
		worst < SHOT_DEG and worst_face < TRACK_DEG, "shot %.1f deg, face %.1f deg" % [worst, worst_face])
	var spd := float(fired[0][2]) if not fired.is_empty() else 0.0
	ok("parity vireo: a fast bolt, about 18 body heights a second (footage: max range in about 0.4s)",
		spd > 28.0 and spd < 40.0, "%.1f m/s" % spd)
	var bl := beats("mage_lmb_l")
	var br := beats("mage_lmb_r")
	ok("parity vireo: alternating hands, each a quick fling (out by 0.1s, settled well inside the 0.8s cadence)",
		anims.has("mage_lmb_l") and anims.has("mage_lmb_r") and bl.x <= 0.1 and br.x <= 0.1 and bl.y <= 0.4
		and br.y <= 0.4, "%s, %.2f / %.2f" % [str(anims.keys()), bl.x, bl.y])
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	await done(m)

# ------------------------------------------------------------------ Breah: boulder and punch
func breah() -> void:
	var r := setup("dolm", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[4]
	var K: DolmKit = P.ak
	step(m, 0.3)
	# taps as fast as the hand goes: the boulder cadence
	var times: Array = []
	var speed := 0.0
	var b0 := K.boulders
	var t := 0.0
	while t < 2.0:
		aim_at(P, _at_angle(P, home, 0.0))
		P.inp["fire"] = int(t / DT) % 2 == 0
		m.step(DT)
		t += DT
		if K.boulders > b0 + times.size():
			times.append(t)
			speed = (shot_of(m, last_sid(m, P)).get("vel", Vector2.ZERO) as Vector2).length()
	P.inp["fire"] = false
	var gap := float(times[1]) - float(times[0]) if times.size() >= 2 else 0.0
	ok("parity breah: tapped, a boulder every 0.6s (card 0.6s; footage 1 per 2-3 frames)", absf(gap - 0.6) < 0.05,
		"%d boulders, gap %.2f s" % [times.size(), gap])
	ok("parity breah: the boulder is slow and readable (footage about 10-12 body heights a second)",
		speed > 17.0 and speed < 23.0, "%.1f m/s" % speed)
	var tb := beats("breah_throw")
	ok("parity breah: the throw is a quick side hurl with no long wind-up (out by 0.15s)", tb.x <= 0.15,
		"%.2f s" % tb.x)
	step(m, 0.8)
	# the punch: hold, sweep the cursor 90 deg, let go
	P.inp["fire"] = true
	step(m, 0.45, func(): aim_at(P, _at_angle(P, home, 0.0)))
	var north := func(): aim_at(P, _at_angle(P, home, -90.0))
	step(m, 0.1, north)
	var lane := AimKit.entry(P, "punch")
	var ld: Vector2 = lane.get("dir", Vector2.ZERO)
	ok("parity breah: the punch lane and her body follow the cursor during the hold (source: the lane points at it)",
		ld.angle_to(Vector2(0, -1)) < deg_to_rad(SHOT_DEG) and face_err(P) < TRACK_DEG,
		"lane %.1f deg, face %.1f deg" % [rad_to_deg(absf(ld.angle_to(Vector2(0, -1)))), face_err(P)])
	step(m, 0.2, north)
	var p0 := K.punches
	var z0 := P.pos.z
	P.inp["fire"] = false
	m.step(DT)
	ok("parity breah: let go after about 0.75s (footage 0118-0121), the punch goes on that step", K.punches == p0 + 1)
	step(m, 0.3)
	var stepped := z0 - P.pos.z
	ok("parity breah: the punch steps her about half a body height along the new aim (footage 0121)",
		stepped > 0.4 and stepped < 1.4, "%.2f m" % stepped)
	var bp := beats("breah_punch")
	ok("parity breah: the punch drives out at once from the cocked pose (out by 0.06s)", bp.x <= 0.06, "%.2f s" % bp.x)
	_tarek_audit(m, P, K, home)
	await done(m)

## The audit (Nov 3 23:40): cooldowns from the data, the hunter viewer's moves, and Molten Guard only from a
## punch into your OWN rocks (an ally Tarek's rocks still fly, no shield).
func _tarek_audit(m: Match, P: Hunter, K: DolmKit, home: Vector3) -> void:
	var view: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/hunter_viewer.json"))
	var dv: Dictionary = (view.get("moves", view) as Dictionary).get("dolm", {})
	ok("audit tarek: cooldowns from the data (Volcano Crusher 11s, Rockwave 12.5s)",
		float(K.rmb_def()["cooldown"]) == 11.0 and float(K.e_def()["cooldown"]) == 12.5)
	ok("audit tarek: the hunter viewer plays his own RMB and X moves",
		dv.get("rmb", []) == ["breah_crouch", "breah_slam"] and dv.get("x", []) == ["breah_spine_aim", "breah_spine"],
		str(dv))
	P.teleport(home)
	aim_at(P, home + Vector3(8, 0, 0))
	step(m, 0.3)
	K.cd["e"] = 0.0
	K.use_e()
	step(m, 0.5)
	var at := home + Vector3(0, 0, -8)
	var ally: Hunter = m.make_hunter("A", P.team, "medium", "Ally", "idle", {}, at, {"arch": "none"})
	for w in K.my_rocks():
		w["by"] = ally
	K.shield_stacks = 0
	P.shield = 0.0
	P.fire_cd = 0.0
	P.inp["fire"] = true
	step(m, 0.6, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	step(m, 0.2)
	ok("audit tarek: a punch into an ally's rocks launches them but gives no Molten Guard (data: your Rocks)",
		K.last_sweep >= 1 and K.shield_stacks == 0, "swept %d stacks %d" % [K.last_sweep, K.shield_stacks])
	ally.queue_free()
	m.hunters.erase(ally)
