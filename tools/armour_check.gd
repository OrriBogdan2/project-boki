extends RefCounted
## --armour-check: armour matches the source (docs/ARMOUR_PARITY.md). The five tiers carry the
## source's damage reduction (20/25/30/35/35%), durability (2,500 x3, 3,000, 3,500) and level-up
## damage (2,000 / 3,600 / 12,000 / 20,000), the last two scaled to our health by HP_K. A hit is cut
## by the tier's share first; what gets through hurts health and wears durability by the same amount;
## at 0 durability nothing is blocked; fall damage skips armour; a level-up arrives full; the HUD
## tip names the next tier's block. Never touches the save.

const HP_K := 0.14       # our health / the source's: Medium 145 HP against the source's ~1,040
const SRC_DR := [0.20, 0.25, 0.30, 0.35, 0.35]
const SRC_DUR := [2500.0, 2500.0, 2500.0, 3000.0, 3500.0]
const SRC_XP := [0.0, 2000.0, 3600.0, 12000.0, 20000.0]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ARMOUR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## The hit after the target's own flat reduction (a kin's), before armour.
func _pre(h: Hunter, dmg: float) -> float:
	return dmg * (1.0 - h.owner_stat("damage_reduction"))

## How much of what gets through wears durability (1 unless the hunter's kin slows the wear).
func _wear(h: Hunter) -> float:
	return 1.0 - minf(0.6, h.owner_stat("armor") + h.kin_pt("owner_armor"))

func _bare(h: Hunter, tier: int) -> void:
	h.armor_tier = tier
	h.refresh_gear()
	h.armor = h.max_armor
	h.shield = 0.0
	h.kin_shield = 0.0
	h.drink_t = 0.0
	h.kit_t = 0.0

func _reset(h: Hunter) -> void:
	h.armor_tier = 0
	h.armor_xp = 0.0
	h.refresh_gear()
	h.armor = h.max_armor

func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 17, "no_drop": true, "god": false})
	m.set_process(false)
	var P: Hunter = m.player
	var B: Hunter = m.hunters.filter(func(o): return o.team != P.team)[0]
	B.ctrl = "idle"
	var T: Array = Hunter.ARMOR_TIERS

	# (a) the tiers are the source's
	ok(T.size() == SRC_DR.size(), "(a) five tiers (%d)" % T.size())
	var med := float(Data.CLASSES["medium"]["hp"])
	ok(absf(med / 1040.0 - HP_K) < 0.005,
			"(a) HP_K fits our Medium health (%.0f / 1,040 = %.3f)" % [med, med / 1040.0])
	for t in mini(T.size(), SRC_DR.size()):
		var tn := String(T[t][0])
		ok(is_equal_approx(float(T[t][3]), SRC_DR[t]), "(a) %s blocks %.2f (source %.2f)" % [tn, T[t][3], SRC_DR[t]])
		ok(is_equal_approx(float(T[t][4]), round(SRC_DUR[t] * HP_K)),
				"(a) %s holds %.0f (source %.0f x %.2f)" % [tn, T[t][4], SRC_DUR[t], HP_K])
		ok(is_equal_approx(float(T[t][2]), round(SRC_XP[t] * HP_K)),
				"(a) %s is reached at %.0f damage dealt" % [tn, T[t][2]])

	# (b) the split at every tier: the tier's share off first, the rest hurts health and durability alike
	for t in T.size():
		_bare(B, t)
		var gear := B.gear_stat("armor")
		ok(is_equal_approx(B.max_armor, float(T[t][4]) + gear),
				"(b) %s: durability %.0f (+%.0f gear)" % [T[t][0], B.max_armor, gear])
		var through := B._mitigate(100.0, null, {"src": "shot"})
		var want := _pre(B, 100.0) * (1.0 - float(T[t][3]))
		ok(absf(through - want) < 0.01,
				"(b) %s: 100 damage, %.1f gets through (want %.1f)" % [T[t][0], through, want])
		var worn := B.max_armor - B.armor
		ok(absf(worn - through * _wear(B)) < 0.01,
				"(b) %s: durability wears by what got through (%.1f)" % [T[t][0], worn])

	# (c) the last of the durability breaks; at 0 nothing is blocked; fall damage skips armour
	_bare(B, 2)
	B.armor = 5.0
	B._mitigate(100.0, null, {"src": "shot"})
	ok(B.armor == 0.0, "(c) a hit bigger than what is left breaks it (%.1f)" % B.armor)
	var bare := B._mitigate(100.0, null, {"src": "shot"})
	ok(absf(bare - _pre(B, 100.0)) < 0.01, "(c) broken armour blocks nothing (%.1f through)" % bare)
	_bare(B, 0)
	var fall := B._mitigate(100.0, null, {"src": "fall"})
	ok(absf(fall - _pre(B, 100.0)) < 0.01 and B.armor == B.max_armor,
			"(c) fall damage skips armour (%.1f)" % fall)

	# (d) levelling: dealing the source's damage reaches each tier, and a level-up arrives full
	_reset(P)
	P.armor_gain(float(T[1][2]) - 1.0)
	ok(P.armor_tier == 0, "(d) one short of Uncommon stays Common")
	P.armor_gain(1.0)
	ok(P.armor_tier == 1, "(d) %.0f damage dealt reaches Uncommon" % T[1][2])
	P.armor_gain(float(T[3][2]) - P.armor_xp)
	ok(P.armor_tier == 3 and is_equal_approx(P.armor, P.max_armor),
			"(d) %s arrives full (%.0f / %.0f)" % [T[3][0], P.armor, P.max_armor])
	_reset(P)
	var next := String(ArmorHud.tip(P)[2][0])
	ok(next.ends_with("blocks 25%"), "(d) the HUD tip names the next tier's block: %s" % next)

	m.queue_free()
	print("ARMOUR DONE, failures: %d" % bad)
	main.get_tree().quit()
