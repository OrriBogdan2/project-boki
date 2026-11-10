extends RefCounted
## --summon-share-check: how much of a 1v1 knock one summon carries (decision 0043, the summon column of
## docs/TTK_MATRIX.md). A Hunter (Vex holding fire at 6 m, Kael tapping slashes at 2 m, as in decision 0042) downs
## a pinned dummy with a Medium Hunter's base health and armour, once alone and then with its Boki burst out of
## the wisp on the first frame, for every species (SAMPLES seeded fights each: a fight swings on the AI's rolls).
## share = the Boki's damage / all the damage of the knock (CombatBus.hit_landed), faster = 1 - knock time with /
## without. Each species' mean share must sit in `knock_band` of content/rules/boki_summon.json.
## Prints SUMMONSHARE <species> <window> <alone s> <with s> <faster %> <share %> rows (tools/ttk_matrix.py reads
## them) and SUMMONSHARE PASS/FAIL.

const DT := 1.0 / 60.0
const HUNTERS := {"gunslinger": 6.0, "juggernaut": 2.0}   # m, as --summon-band-check measures "a Hunter's LMB"
const TAP_FRAMES := 3                                    # Kael: fire held 2 frames of every 3, so each press slashes
const DEF := "medium"                                    # the defender's class: base health, armour 2.2x of it
const SAMPLES := 3
const CAP := 30.0                                        # s: a knock that takes longer fails

var main: Node
var A
var bad := 0

func run(main_node: Node) -> void:
	main = main_node
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	Save.no_write = true
	var band: Array = KinSummon.rules()["knock_band"]
	var alone := {}
	for arch in HUNTERS:
		var r: Array = await _duel(arch, "", 0)
		alone[arch] = r[0]
		ok(r[0] < CAP, "%s alone downs the dummy (%.1f s)" % [arch, r[0]])
		print("SUMMONSHARE alone %s %.2f" % [arch, r[0]])
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--summon-share-only="): only = String(a).substr(20)
	var lo := INF
	var hi := 0.0
	for id in KinLib.kin_ids():
		if only != "" and id != only: continue
		var t_with := 0.0
		var t_alone := 0.0
		var share := 0.0
		var n := 0
		for arch in HUNTERS:
			for s in SAMPLES:
				var r: Array = await _duel(arch, id, s)
				ok(r[0] < CAP, "%s with %s downs the dummy" % [arch, id])
				t_with += r[0]
				t_alone += alone[arch]
				share += r[1]
				n += 1
		share /= n
		var faster := 1.0 - t_with / t_alone
		lo = minf(lo, share)
		hi = maxf(hi, share)
		print("SUMMONSHARE %s %.0f %.2f %.2f %.1f %.1f k_now %.2f" % [id, KinSummon.times(KinLib.kin(id)).x,
			t_alone / n, t_with / n, faster * 100.0, share * 100.0, KinSummon.damage_k(id)])
		ok(share >= float(band[0]) and share <= float(band[1]),
			"%s: the summon carries %.0f%% of the knock (band %.0f-%.0f%%)" % [id, share * 100.0,
			float(band[0]) * 100.0, float(band[1]) * 100.0])
		ok(faster > 0.0, "%s: the knock is faster with it out" % id)
	print("SUMMONSHARE range %.1f-%.1f%%" % [lo * 100.0, hi * 100.0])
	print("SUMMONSHARE %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("SUMMONSHARE FAIL %s" % what)
		bad += 1

## [seconds to down the dummy, the Boki's share of the damage]; `id` "" = the Hunter alone.
func _duel(arch: String, id: String, roll: int) -> Array:
	var r: Array = A.setup(arch, HUNTERS[arch], id)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var spot := T.pos
	var hp := float(Data.CLASSES[DEF]["hp"])
	T.max_hp = hp
	T.hp = hp
	T.max_armor = round(hp * Hunter.ARMOR_DUR)
	T.armor = T.max_armor
	var k: Kin = P.kin
	var dealt := {"boki": 0.0, "all": 0.0}
	var count := func(by: Node, target: Node, amount: float, _tags: Array):
		if target != T: return
		dealt["all"] += amount
		if k and by == k: dealt["boki"] += amount
	CombatBus.hit_landed.connect(count)
	seed(hash(arch) + hash(id) + roll)
	if k:
		k.brain.think_t = 0.0
		KinWisp.set_wisp(k, true)
		k.rng.seed = hash(id) * 31 + roll
		ok(KinSummon.press(P), "%s: Summon bursts it out" % id)
	var t := 0.0
	var n := 0
	while t < CAP and T.hp > 0.0 and not T.downed:
		T.teleport(spot)
		T.vel = Vector3.ZERO
		A.aim_at(P, spot)
		var gap := Vector2(spot.x - P.pos.x, spot.z - P.pos.z)
		P.inp["move"] = gap.normalized() if gap.length() > float(HUNTERS[arch]) + 0.3 else Vector2.ZERO
		P.inp["fire"] = arch == "gunslinger" or n % TAP_FRAMES != TAP_FRAMES - 1
		m.step(DT)
		t += DT
		n += 1
	CombatBus.hit_landed.disconnect(count)
	await A.done(m)
	return [t, dealt["boki"] / maxf(dealt["all"], 0.001)]
