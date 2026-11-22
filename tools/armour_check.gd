extends RefCounted
## --armour-check: armour matches the source (docs/ARMOUR_PARITY.md). The five tiers carry the
## source's damage reduction (20/25/30/35/35%), durability (2,500 x3, 3,000, 3,500) and level-up
## damage (2,000 / 3,600 / 12,000 / 20,000), the last two scaled to our health by HP_K. A hit is cut
## by the tier's share first; what gets through hurts health and wears durability by the same amount;
## at 0 durability nothing is blocked; fall damage skips armour; a level-up arrives full; the HUD
## tip names the next tier's block. Never touches the save.

const HP_K := 0.14  # our health / the source's: Medium 145 HP against the source's ~1,040
const SRC_DR := [0.20, 0.25, 0.30, 0.35, 0.35]
const SRC_DUR := [2500.0, 2500.0, 2500.0, 3000.0, 3500.0]
const SRC_XP := [0.0, 2000.0, 3600.0, 12000.0, 20000.0]

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("ARMOUR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


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
	var p: Hunter = m.player
	var b: Hunter = m.hunters.filter(func(o): return o.team != p.team)[0]
	b.ctrl = "idle"
	var t_v: Array = Hunter.ARMOR_TIERS

	# (a) the tiers are the source's
	ok(t_v.size() == SRC_DR.size(), "(a) five tiers (%d)" % t_v.size())
	var med := float(Data.CLASSES["medium"]["hp"])
	ok(absf(med / 1040.0 - HP_K) < 0.005, "(a) HP_K fits our Medium health (%.0f / 1,040 = %.3f)" % [med, med / 1040.0])
	for t in mini(t_v.size(), SRC_DR.size()):
		var tn := String(t_v[t][0])
		ok(
			is_equal_approx(float(t_v[t][3]), SRC_DR[t]),
			"(a) %s blocks %.2f (source %.2f)" % [tn, t_v[t][3], SRC_DR[t]]
		)
		ok(
			is_equal_approx(float(t_v[t][4]), round(SRC_DUR[t] * HP_K)),
			"(a) %s holds %.0f (source %.0f x %.2f)" % [tn, t_v[t][4], SRC_DUR[t], HP_K]
		)
		ok(
			is_equal_approx(float(t_v[t][2]), round(SRC_XP[t] * HP_K)),
			"(a) %s is reached at %.0f damage dealt" % [tn, t_v[t][2]]
		)

	# (b) the split at every tier: the tier's share off first, the rest hurts health and durability alike
	for t in t_v.size():
		_bare(b, t)
		var gear := b.gear_stat("armor")
		ok(
			is_equal_approx(b.max_armor, float(t_v[t][4]) + gear),
			"(b) %s: durability %.0f (+%.0f gear)" % [t_v[t][0], b.max_armor, gear]
		)
		var through := b._mitigate(100.0, null, {"src": "shot"})
		var want := _pre(b, 100.0) * (1.0 - float(t_v[t][3]))
		ok(
			absf(through - want) < 0.01,
			"(b) %s: 100 damage, %.1f gets through (want %.1f)" % [t_v[t][0], through, want]
		)
		var worn := b.max_armor - b.armor
		ok(
			absf(worn - through * _wear(b)) < 0.01,
			"(b) %s: durability wears by what got through (%.1f)" % [t_v[t][0], worn]
		)

	# (c) the last of the durability breaks; at 0 nothing is blocked; fall damage skips armour
	_bare(b, 2)
	b.armor = 5.0
	b._mitigate(100.0, null, {"src": "shot"})
	ok(b.armor == 0.0, "(c) a hit bigger than what is left breaks it (%.1f)" % b.armor)
	var bare := b._mitigate(100.0, null, {"src": "shot"})
	ok(absf(bare - _pre(b, 100.0)) < 0.01, "(c) broken armour blocks nothing (%.1f through)" % bare)
	_bare(b, 0)
	var fall := b._mitigate(100.0, null, {"src": "fall"})
	ok(absf(fall - _pre(b, 100.0)) < 0.01 and b.armor == b.max_armor, "(c) fall damage skips armour (%.1f)" % fall)

	# (d) levelling: dealing the source's damage reaches each tier, and a level-up arrives full
	_reset(p)
	p.armor_gain(float(t_v[1][2]) - 1.0)
	ok(p.armor_tier == 0, "(d) one short of Uncommon stays Common")
	p.armor_gain(1.0)
	ok(p.armor_tier == 1, "(d) %.0f damage dealt reaches Uncommon" % t_v[1][2])
	p.armor_gain(float(t_v[3][2]) - p.armor_xp)
	ok(
		p.armor_tier == 3 and is_equal_approx(p.armor, p.max_armor),
		"(d) %s arrives full (%.0f / %.0f)" % [t_v[3][0], p.armor, p.max_armor]
	)
	_reset(p)
	var next := String(ArmorHud.tip(p)[2][0])
	ok(next.ends_with("blocks 25%"), "(d) the HUD tip names the next tier's block: %s" % next)

	m.queue_free()
	print("ARMOUR DONE, failures: %d" % bad)
	main.get_tree().quit()
