extends RefCounted
## --fusion-band-check: a Fusion is an event, but never more than a Hunter's ultimate
## (DECISIONS Boki; docs/FUSION_BAND.md).
## Every built Fusion is measured: each form with its own file (content/merge_forms), and each fallback merge per Boki
## type that gives it (its rider and dash come from the type). It is worn on the training strip by Vex (rifle held)
## and Kael (slashes tapped), their mean being its figure; every Hunter ultimate (R) is cast by its own Hunter on the
## same strip. Two idle dummies stand side by side ahead. Over WINDOW_S seconds each run is set against the same
## Hunter's LMB alone, so only what the Fusion or the ultimate adds counts:
##   burst      the most added damage in any one second (the Fusion's run releases it with X as soon as it may)
##   sustained  added damage per second over the window (the Fusion worn from the moment it is live, no release;
##              the ultimate as cast)
##   ehp        extra raw damage the Hunter soaks under a steady stream before it goes down (shell, damage
##              reduction, shields, heals, untouchable time)
## Each must sit in the band content/rules/merge_forms.json `band` takes from the ultimates: at most their maximum,
## at least lo_k of their median. Its length and rests are read too: a timeout rests the Boki timeout_rest_s, a
## release rest_s with the afterglow, and the timeout longer.
## Prints the table as FUSIONBAND lines and "FUSIONBAND PASS/FAIL (n fail)".

const DT := 1.0 / 60.0
const WINDOW_S := 6.0
const DIST := 2.0                # m: the first dummy ahead, in reach of melee and rifle alike
const SIDE := 2.0                # m: the second dummy beside the first
const CARRIERS := ["gunslinger", "juggernaut"]   # Vex and Kael: who wears each Fusion
const TAP_FRAMES := 3            # a tapped LMB is held 2 frames of every 3, so each press is a swing
const TAPPED := ["juggernaut", "archer", "bulwark", "dolm"]   # swings and charged draws: tapped; streams and guns: held
const RECAST_S := 0.5            # s: R pressed again this often, for ultimates with a second stage
const HIT := 1.0                 # hp per frame thrown at the Hunter for its effective health (60 dps: two Hunters' LMB)
const EHP_CAP_S := 20.0          # s: the most an effective-health run lasts

var main: Node
var A                            # the archetype check's training strip (setup / aim_at / done)
var bad := 0
var base_cache := {}             # "arch|species|what" -> the Hunter's own figures without it (the same for every mode)

func run(main_node: Node) -> void:
	main = main_node
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var ults := {}
	print("FUSIONBAND %-22s burst  sust   ehp" % "ultimates")
	for arch in Arch.ids():
		if Arch.def(arch).has("x"):
			ults[arch] = await _measure(arch, "", "ult")
			_row("%s %s" % [arch, Arch.def(arch)["x"]["name"]], ults[arch])
	var band := _band(ults.values())
	print("FUSIONBAND band lo %s" % _fmt(band[0]))
	print("FUSIONBAND band hi %s" % _fmt(band[1]))
	var built := _built()
	for tag in built:
		var f := await _fusion(tag, built[tag])
		for key in band[0]:
			var v := float(f[key])
			ok(v >= float(band[0][key]) - 0.5 and v <= float(band[1][key]) + 0.5,
				"%s %s %.0f inside %.0f..%.0f" % [tag, key, v, band[0][key], band[1][key]])
		ok(is_equal_approx(f["rest_t"], MergeRelease.timeout_rest_s()), "%s timeout rests %.0f s" % [tag, f["rest_t"]])
		var release_ok: bool = is_equal_approx(f["rest_r"], MergeRelease.rest_s()) and f["glow"] > 0.0
		ok(release_ok, "%s release rests %.0f s with the afterglow" % [tag, f["rest_r"]])
		ok(f["rest_t"] > f["rest_r"], "%s releasing beats running out" % tag)
	print("FUSIONBAND %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## One Fusion's figures, worn by each carrier (their mean), with its length and rests; printed as a table row.
func _fusion(merge_id: String, sp: String) -> Dictionary:
	var f := {"burst": 0.0, "sust": 0.0, "ehp": 0.0}
	for arch in CARRIERS:
		var fused := await _measure(arch, sp, "fused")
		var release := await _measure(arch, sp, "release")
		f["burst"] += release["burst"] / CARRIERS.size()
		f["sust"] += fused["sust"] / CARRIERS.size()
		f["ehp"] += fused["ehp"] / CARRIERS.size()
	var timeout := await _ending(CARRIERS[0], sp, false)
	var released := await _ending(CARRIERS[0], sp, true)
	f.merge({"len": timeout["len"], "rest_t": timeout["rest"], "rest_r": released["rest"], "glow": released["glow"]})
	_row("%s (%s)" % [merge_id, sp], f)
	var ends := [f["len"], f["rest_t"], f["rest_r"], f["glow"]]
	print("FUSIONBAND   length %.1f s  timeout rest %.1f s  release rest %.1f s + afterglow %.1f s" % ends)
	return f

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("FUSIONBAND FAIL %s" % what)
		bad += 1

func _fmt(r: Dictionary) -> String:
	return "%5.0f  %5.1f  %5.0f" % [r["burst"], r["sust"], r["ehp"]]

func _row(what: String, r: Dictionary) -> void:
	print("FUSIONBAND %-22s %s" % [what, _fmt(r)])

## Every built Fusion -> the first live species that gives it: a form with its own file by merge id; a fallback by
## "merge/type", since its rider and dash come from the Boki's type (a merge no live Boki gives is not built).
func _built() -> Dictionary:
	var out := {}
	for sp in KinLib.kin_ids():
		var ms := KinLib.merge_of(String(sp))
		if ms == null:
			continue
		var tag := ms.id
		if Content.merge_form(ms.id).is_empty():
			tag = "%s/%s" % [ms.id, KinLib.kin(String(sp)).theme]
		if not out.has(tag):
			out[tag] = String(sp)
	return out

## [low, high] per figure: low is band.lo_k of the ultimates' median, high their maximum.
func _band(rows: Array) -> Array:
	var lo_k: Dictionary = MergeForm.data()["band"]["lo_k"]
	var lo := {}
	var hi := {}
	for key in ["burst", "sust", "ehp"]:
		var vals: Array = rows.map(func(r): return float(r[key]))
		vals.sort()
		var mid := (float(vals[(vals.size() - 1) / 2]) + float(vals[vals.size() / 2])) * 0.5
		lo[key] = mid * float(lo_k[key])
		hi[key] = vals.max()
	return [lo, hi]

## One Hunter's figures with `mode` ("ult": cast R; "fused": wear the Boki's Fusion, no release; "release": fuse and
## release at once) against the same Hunter's LMB alone: {burst, sust, ehp} (no ehp for "release").
func _measure(arch: String, sp: String, mode: String) -> Dictionary:
	if not base_cache.has("%s|%s|dealt" % [arch, sp]):
		base_cache["%s|%s|dealt" % [arch, sp]] = await _dealt(arch, sp, "")
		base_cache["%s|%s|soak" % [arch, sp]] = await _soak(arch, sp, "")
	var base: Array = base_cache["%s|%s|dealt" % [arch, sp]]
	var run_d := await _dealt(arch, sp, mode)
	var added: Array = []
	for i in base.size():
		added.append(float(run_d[i]) - float(base[i]))
	var sec := int(round(1.0 / DT))
	var burst := 0.0
	for i in range(sec, added.size()):
		burst = maxf(burst, float(added[i]) - float(added[i - sec]))
	var out := {"burst": burst, "sust": float(added[-1]) / WINDOW_S}
	if mode != "release":
		out["ehp"] = await _soak(arch, sp, mode) - float(base_cache["%s|%s|soak" % [arch, sp]])
	return out

## Starts `mode` on P (nothing for "") and steps until it is on: the ultimate cast, the Fusion live.
func _start(m: Match, P: Hunter, mode: String) -> void:
	match mode:
		"ult":
			HunterKeys.ult_pressed(P)
		"fused", "release":
			A.merge_now(P)
			while KinMerge.active(P) and String(P.merge_st["phase"]) != "live":
				m.step(DT)

func _setup(arch: String, sp: String) -> Array:
	var r: Array = A.setup(arch, DIST, sp, true)
	r[3].teleport(r[2].pos + Vector3(0, 0, SIDE))      # beside the first, not behind it: foes seldom stand in a line
	for T in [r[2], r[3]]:
		T.max_hp = float(Data.CLASSES["medium"]["hp"])      # a real Hunter's health: some burns hit a share of it
		T.hp = T.max_hp
	seed(hash(arch + sp))
	return r

## Cumulative damage on the two pinned dummies every frame of the window, LMB on all through
## (both refilled every frame).
func _dealt(arch: String, sp: String, mode: String) -> Array:
	var r: Array = _setup(arch, sp)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var dummies: Array = [r[2], r[3]]
	var spots: Array = dummies.map(func(T): return T.pos)
	var spot: Vector3 = spots[0]
	_start(m, P, mode)
	var out: Array = []
	var sum := 0.0
	var frames := int(round(WINDOW_S / DT))
	for n in frames:
		for i in 2:
			dummies[i].teleport(spots[i])
			dummies[i].vel = Vector3.ZERO
		A.aim_at(P, spot)
		P.inp["fire"] = arch not in TAPPED or n % TAP_FRAMES != TAP_FRAMES - 1
		if mode == "ult" and n % int(round(RECAST_S / DT)) == 0 and n > 0:
			HunterKeys.ult_pressed(P)
		if mode == "release" and KinMerge.active(P):
			KinMerge.press(P)
		m.step(DT)
		for T in dummies:
			sum += T.max_hp - T.hp
			T.hp = T.max_hp
		out.append(sum)
	await A.done(m)
	return out

## Raw damage the Hunter takes (HIT a frame, from no one) before it goes down, with `mode` on.
func _soak(arch: String, sp: String, mode: String) -> float:
	var r: Array = _setup(arch, sp)
	var m: Match = r[0]
	var P: Hunter = r[1]
	_start(m, P, mode)
	var taken := 0.0
	var t := 0.0
	while t < EHP_CAP_S:
		P.hurt(HIT, null, {"src": "shot"})      # (no attacker: a stun or freeze on the dummy must not stop the stream)
		taken += HIT
		if P.downed or P.dead or P.out or P.hp <= 0.0:
			break          # (read before the step: training brings a dead Hunter back at once)
		m.step(DT)
		t += DT
	await A.done(m)
	return taken

## How the Fusion ends: {len: seconds live, rest: the Boki's rest after it, glow: the Hunter's afterglow seconds}.
func _ending(arch: String, sp: String, release: bool) -> Dictionary:
	var r: Array = _setup(arch, sp)
	var m: Match = r[0]
	var P: Hunter = r[1]
	_start(m, P, "fused")
	var t := 0.0
	var glow := 0.0
	while KinMerge.active(P) and t < 60.0:
		if release:
			KinMerge.press(P)
		m.step(DT)
		t += DT
		glow = maxf(glow, float(P.get_meta("afterglow_t", 0.0)))
	var out := {"len": t, "rest": P.merge_cd, "glow": glow}
	await A.done(m)
	return out
