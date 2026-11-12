extends RefCounted
## --armor-parity-check: the armour rows docs/ARMOUR_PARITY.md fixed to match the source. Each tier
## takes its own share off a hit (20 / 25 / 30 / 35 / 35%) and what gets through wears the durability
## by the same amount; the top two tiers carry more durability (x1.2, x1.4); the progress table keeps
## the source's 2k / 3.6k / 12k / 20k shape; damage taken from a rival fills progress as well as damage
## dealt; nothing refills by itself; a hunter brought back from the dead is on a broken Common piece;
## Grimble's no-bloom scattergun shot wears armour 66% faster (not health). Never touches the save.

const SOURCE_DR := [0.20, 0.25, 0.30, 0.35, 0.35]
const SOURCE_DUR := [2500.0, 2500.0, 2500.0, 3000.0, 3500.0]
const SOURCE_XP := [2000.0, 3600.0, 12000.0, 20000.0]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ARMOR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 31, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var me: Hunter = m.hunters.filter(func(x): return x.team == 0)[0]
	var foe: Hunter = m.hunters.filter(func(x): return x.team != 0)[0]
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	_table()
	_reduction(me, foe)
	_progress(me, foe)
	_no_refill(m, me)
	_revive(m, me)
	_clean_shot(me, foe)
	print("ARMOR DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _table() -> void:
	var T := Hunter.ARMOR_TIERS
	var dr_ok := true
	var dur_ok := true
	var xp_ok := true
	for i in T.size():
		dr_ok = dr_ok and is_equal_approx(float(T[i][3]), SOURCE_DR[i])
		dur_ok = dur_ok and is_equal_approx(float(T[i][4]), SOURCE_DUR[i] / SOURCE_DUR[0])
		if i > 0:
			xp_ok = xp_ok and absf(float(T[i][2]) / float(T[1][2]) - SOURCE_XP[i - 1] / SOURCE_XP[0]) < 0.01
	ok(dr_ok, "reduction by tier is the source's 20/25/30/35/35%")
	ok(dur_ok, "durability by tier is the source's 2,500/2,500/2,500/3,000/3,500 shape")
	ok(xp_ok, "tier progress keeps the source's 2k/3.6k/12k/20k ratios")

## One hit with no armour, one with, on the same hunter: the armoured hit is cut by the tier's share
## and the durability drops by what got through (the kin's wear stat aside).
func _hit(me: Hunter, foe: Hunter, amt: float, opts: Dictionary) -> Array:
	me.max_hp = 1e6
	me.hp = me.max_hp
	me.shield = 0.0
	me.kin_shield = 0.0
	me.inv_t = 0.0
	var hp0 := me.hp
	var a0 := me.armor
	me.hurt(amt, foe, opts.duplicate())
	return [hp0 - me.hp, a0 - me.armor]

func _set_tier(me: Hunter, t: int) -> void:
	me.armor_tier = t
	me.armor_xp = float(Hunter.ARMOR_TIERS[t][2])
	me.refresh_gear()

func _reduction(me: Hunter, foe: Hunter) -> void:
	for t in Hunter.ARMOR_TIERS.size():
		_set_tier(me, t)
		var plates: float = round(me.base_armor * float(Hunter.ARMOR_TIERS[t][4])) + me.gear_stat("armor")
		ok(is_equal_approx(me.max_armor, plates),
				"tier %d plates: %.0f" % [t, me.max_armor])
		me.armor = 0.0
		var bare: Array = _hit(me, foe, 100.0, {"src": "shot"})
		me.armor = me.max_armor
		var worn: Array = _hit(me, foe, 100.0, {"src": "shot"})
		var k := float(worn[0]) / maxf(0.001, float(bare[0]))
		ok(absf(k - (1.0 - SOURCE_DR[t])) < 0.01, "tier %d hit cut to %.2f (source %.2f)" % [t, k, 1.0 - SOURCE_DR[t]])
		ok(float(worn[1]) > 0.0 and float(worn[1]) <= float(worn[0]) + 0.01,
				"tier %d durability worn by what got through" % t)

func _progress(me: Hunter, foe: Hunter) -> void:
	_set_tier(me, 0)
	_hit(me, foe, 50.0, {"src": "shot"})
	ok(me.armor_xp > 0.0, "damage taken from a rival fills armor progress (%.0f)" % me.armor_xp)

func _no_refill(m: Match, me: Hunter) -> void:
	me.armor = me.max_armor * 0.5
	var a0 := me.armor
	for i in int(10.0 / Match.DT): m.step(Match.DT)
	ok(is_equal_approx(me.armor, a0), "armor does not refill out of combat (%.1f -> %.1f in 10s)" % [a0, me.armor])

func _revive(m: Match, me: Hunter) -> void:
	_set_tier(me, 3)
	Life.bring_back(m, me, me.pos, 0.5, false)
	ok(me.armor_tier == 0 and me.armor_xp == 0.0 and me.armor == 0.0, "back from the dead on a broken Common piece")

func _clean_shot(me: Hunter, foe: Hunter) -> void:
	var gun: Dictionary = Data.weapon_stats("shotgun")
	ok(is_equal_approx(float(gun.get("clean_armor_k", 0.0)), 1.66),
			"Grimble's scattergun: +66% armour damage without spread")
	_set_tier(me, 0)
	me.armor = me.max_armor
	var plain: Array = _hit(me, foe, 40.0, {"src": "shot"})
	me.armor = me.max_armor
	var clean: Array = _hit(me, foe, 40.0, {"src": "shot", "armor_k": 1.66})
	ok(absf(float(clean[1]) / float(plain[1]) - 1.66) < 0.01,
			"a no-bloom slug wears 1.66x the armour (%.1f vs %.1f)" % [clean[1], plain[1]])
	ok(absf(float(clean[0]) - float(plain[0])) < 0.01, "and the same health")
