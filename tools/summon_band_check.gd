extends RefCounted
## --summon-band-check: what one summon adds to a fight (DECISIONS 2026-11-09, decision 0042). Every species is
## summoned (SAMPLES times, averaged) out of its wisp on the training strip beside an idle, armourless dummy 4 m
## ahead and runs its own AI for its window (KinSummon); the damage it deals there is set against one Hunter's LMB
## on the same dummy over the same seconds: Vex holding her rifle, Kael tapping slashes, their mean being "a
## Hunter's LMB". Each species' share must sit in the band in content/rules/boki_summon.json, near its own aim
## inside it: the top for the shortest windows, the bottom for the longest (short and strong, long and
## supporting). Prints the table, with the dmg_k each species would need to land on its aim.
## Prints SUMMONBAND PASS/FAIL.

const DT := 1.0 / 60.0
const VEX := "gunslinger"
const KAEL := "juggernaut"
const LMB_DIST := {VEX: 6.0, KAEL: 2.0}   # m: Vex at mid range; Kael in reach on body hits (no tip spacing)
const KIN_DIST := 4.0                      # m: the dummy ahead of the Hunter while the Boki is out
const DUMMY_HP := 1e6
const SAMPLES := 6                         # summons per species, averaged: one fight swings on its AI's rolls
const TAP_FRAMES := 3                      # Kael: fire held 2 frames of every 3, so each press is a slash

var main: Node
var A                                      # the archetype check's training strip (setup / step / aim_at)
var bad := 0
var lmb := {}                              # "arch|secs" -> damage over those seconds

func run(main_node: Node) -> void:
	main = main_node
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var band: Array = KinSummon.rules()["band"]
	var span := _window_span()
	print("SUMMONBAND species        role/size        window  dealt  vex   kael  share  target  k_now  k_fit")
	var rows: Array = []
	await _lmb_run(VEX, span)
	await _lmb_run(KAEL, span)
	for id in KinLib.kin_ids():
		var ks := KinLib.kin(id)
		var secs := KinSummon.times(ks).x
		var dealt := 0.0
		for i in SAMPLES:
			dealt += await _summoned(id, i) / SAMPLES
		var vex: float = lmb["%s|%s" % [VEX, secs]]
		var kael: float = lmb["%s|%s" % [KAEL, secs]]
		var ref := (vex + kael) * 0.5
		var share := dealt / ref
		var target := target_share(secs, span, KinSummon.rules()["aim"])
		var k_now := KinSummon.damage_k(id)
		var row := {"id": id, "secs": secs, "share": share, "target": target}
		rows.append(row)
		print("SUMMONBAND %-16s %-16s %5.0f s %6.0f %5.0f %5.0f %5.0f%% %6.0f%%  %5.2f  %5.2f" % [id,
			"%s/%s" % [ks.ai.get("role", "?"), ks.size], secs, dealt, vex, kael,
			share * 100.0, target * 100.0, k_now, k_now * target / maxf(share, 0.001)])
		ok(share >= float(band[0]) and share <= float(band[1]),
			"%s: %.0f%% of a Hunter's LMB is in the band" % [id, share * 100.0])
		ok(absf(share - target) <= float(KinSummon.rules()["band_tol"]),
			"%s: within tolerance of its %.0f%% target" % [id, target * 100.0])
	_identity(rows, span)
	print("SUMMONBAND %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("SUMMONBAND FAIL %s" % what)
		bad += 1

## The shortest and longest windows in the table.
static func _window_span() -> Vector2:
	var lo := INF
	var hi := 0.0
	for row in KinSummon.rules()["table"].values():
		for cell in (row as Dictionary).values():
			lo = minf(lo, float(cell[0]))
			hi = maxf(hi, float(cell[0]))
	return Vector2(lo, hi)

## A species' target share: the aim's top for the shortest window, its bottom for the longest.
static func target_share(secs: float, span: Vector2, aim: Array) -> float:
	return lerpf(float(aim[1]), float(aim[0]), inverse_lerp(span.x, span.y, secs))

## Short and strong stays above long and supporting: the shortest third out-shares the longest third.
func _identity(rows: Array, span: Vector2) -> void:
	var cut := (span.y - span.x) / 3.0
	var short_r := rows.filter(func(r): return float(r["secs"]) <= span.x + cut)
	var long_r := rows.filter(func(r): return float(r["secs"]) >= span.y - cut)
	var avg := func(rs: Array) -> float:
		return rs.reduce(func(s, r): return s + float(r["share"]), 0.0) / maxf(1.0, rs.size())
	ok(not short_r.is_empty() and not long_r.is_empty() and avg.call(short_r) > avg.call(long_r),
		"short windows out-share long ones (%.0f%% vs %.0f%%)" % [avg.call(short_r) * 100.0, avg.call(long_r) * 100.0])

func _dummy(T: Hunter) -> void:
	T.max_hp = DUMMY_HP
	T.hp = DUMMY_HP

## Held where it stands: knock-backs and pulls would walk it out of reach and measure the chase, not the hits.
func _pin(T: Hunter, spot: Vector3) -> void:
	T.teleport(spot)
	T.vel = Vector3.ZERO

## Damage the species' Boki deals on the dummy across one summon window (`roll`: which seeded fight).
func _summoned(id: String, roll: int) -> float:
	var r: Array = A.setup(VEX, KIN_DIST, id)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var spot := T.pos
	_dummy(T)
	var k: Kin = P.kin
	k.brain.think_t = 0.0
	KinWisp.set_wisp(k, true)
	seed(hash(id) + roll)
	ok(KinSummon.press(P), "%s: Summon bursts it out" % id)
	while k.summon.left > 0.0:
		_pin(T, spot)
		m.step(DT)
	var dealt := DUMMY_HP - T.hp
	await A.done(m)
	return dealt

## One Hunter's LMB on the dummy (Vex holds, Kael taps): one run as long as the longest window, the damage read
## at every window length on the way ("arch|secs" -> damage in lmb).
func _lmb_run(arch: String, span: Vector2) -> void:
	var r: Array = A.setup(arch, LMB_DIST[arch])
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var spot := T.pos
	_dummy(T)
	seed(hash(arch))
	var n := 0
	while n * DT < span.y + DT * 0.5:
		_pin(T, spot)
		A.aim_at(P, spot)
		var gap := Vector2(spot.x - P.pos.x, spot.z - P.pos.z)
		var drifted := gap.length() > float(LMB_DIST[arch]) + 0.3
		P.inp["move"] = gap.normalized() if drifted else Vector2.ZERO   # pushed off: steps back into range
		P.inp["fire"] = arch == VEX or n % TAP_FRAMES != TAP_FRAMES - 1
		m.step(DT)
		n += 1
		var whole := roundf(n * DT)
		if absf(n * DT - whole) < DT * 0.5:
			lmb["%s|%s" % [arch, whole]] = DUMMY_HP - T.hp
	await A.done(m)
