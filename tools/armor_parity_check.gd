extends RefCounted
## --armor-parity-check: the armour rows docs/ARMOUR_PARITY.md fixed to match the source. Each tier
## takes its own share off a hit (20 / 25 / 30 / 35 / 35%) and what gets through wears the durability
## by the same amount; the top two tiers carry more durability (x1.2, x1.4); the progress table keeps
## the source's 2k / 3.6k / 12k / 20k scaled by base health (content/rules/armor_xp.json); damage dealt
## to and taken from a rival fills progress, monsters, Boki and downed rivals build none and no level XP
## comes with it; a scripted duel at the TTK matrix's damage reaches the tier the source would; nothing
## refills by itself; a hunter brought back from the dead is on a broken Common piece; Grimble's no-bloom
## scattergun shot wears armour 66% faster (not health). Never touches the save.

const SOURCE_DR := [0.20, 0.25, 0.30, 0.35, 0.35]
const SOURCE_DUR := [2500.0, 2500.0, 2500.0, 3000.0, 3500.0]
const SOURCE_XP := [2000.0, 3600.0, 12000.0, 20000.0]
const SOURCE_HP := 1030.0        # the source's median base health (docs/SUPERVIVE_DATA.md section 5)
const DOWN_DMG := 145.0          # damage after armour that downs the TTK matrix's Medium dummy (docs/TTK_MATRIX.md)

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
	_rates(m, me, foe)
	_duel(m, me, foe)
	_no_refill(m, me)
	_revive(m, me)
	print("ARMOR DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _table() -> void:
	var T := Hunter.ARMOR_TIERS
	var dr_ok := true
	var dur_ok := true
	var xp_ok := ArmorXp.thresholds.size() == T.size() and float(ArmorXp.thresholds[0]) == 0.0
	var k := float(Data.CLASSES["medium"]["hp"]) / SOURCE_HP      # Medium health over the source's median
	for i in T.size():
		dr_ok = dr_ok and is_equal_approx(float(T[i][2]), SOURCE_DR[i])
		dur_ok = dur_ok and is_equal_approx(float(T[i][3]), SOURCE_DUR[i] / SOURCE_DUR[0])
		if i > 0:
			xp_ok = xp_ok and is_equal_approx(float(ArmorXp.thresholds[i]), round(SOURCE_XP[i - 1] * k))
	ok(dr_ok, "reduction by tier is the source's 20/25/30/35/35%")
	ok(dur_ok, "durability by tier is the source's 2,500/2,500/2,500/3,000/3,500 shape")
	ok(xp_ok, "tier progress is the source's 2k/3.6k/12k/20k at our health scale: %s" % [ArmorXp.thresholds])
	ok(is_equal_approx(ArmorXp.knock, round(1000.0 * k)),
			"a knock adds 1,000 source points scaled (%.0f)" % ArmorXp.knock)

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
	me.armor_xp = float(ArmorXp.thresholds[t])
	me.refresh_gear()

func _reduction(me: Hunter, foe: Hunter) -> void:
	for t in Hunter.ARMOR_TIERS.size():
		_set_tier(me, t)
		var plates: float = round(me.base_armor * float(Hunter.ARMOR_TIERS[t][3])) + me.gear_stat("armor")
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

## What fills progress: a rival Hunter's damage, dealt or taken, point for point; a monster, a Boki or a
## downed rival none; and none of it is level XP.
func _rates(m: Match, me: Hunter, foe: Hunter) -> void:
	_set_tier(me, 0)
	_set_tier(foe, 0)
	me.xp = 0.0
	m.on_damage(foe, me, 40.0, {"src": "shot"})
	ok(is_equal_approx(me.armor_xp, 40.0) and is_equal_approx(foe.armor_xp, 40.0),
			"40 damage to a rival: 40 progress dealt (%.0f) and 40 taken (%.0f)" % [me.armor_xp, foe.armor_xp])
	var mob: Mob = m.spawn_mob("skitter", me.pos + Vector3(3, 0, 0))
	m.on_damage(mob, me, 40.0, {"src": "shot"})
	ok(is_equal_approx(me.armor_xp, 40.0), "40 damage to a monster builds none (%.0f)" % me.armor_xp)
	m.mobs.erase(mob)
	mob.queue_free()
	ok(foe.kin != null, "the rival has a Boki to hit")
	if foe.kin:
		m.on_damage(foe.kin, me, 40.0, {"src": "shot"})
		ok(is_equal_approx(me.armor_xp, 40.0), "40 damage to a rival's Boki builds none (%.0f)" % me.armor_xp)
	foe.downed = true
	m.on_damage(foe, me, 40.0, {"src": "shot"})
	foe.downed = false
	ok(is_equal_approx(me.armor_xp, 40.0), "40 damage to a downed rival builds none (%.0f)" % me.armor_xp)
	ok(me.xp == 0.0 and me.lvl == 1, "none of it is level XP (%.1f)" % me.xp)

## A scripted duel: both Hunters land the damage that downs the TTK matrix's Medium dummy, duel after
## duel; after each, ours stands on the tier the source's thresholds give for the same duels there.
func _duel(m: Match, me: Hunter, foe: Hunter) -> void:
	_set_tier(me, 0)
	_set_tier(foe, 0)
	for duel in range(1, 11):
		m.on_damage(foe, me, DOWN_DMG, {"src": "shot"})
		m.on_damage(me, foe, DOWN_DMG, {"src": "shot"})
		var source_pts := 2.0 * SOURCE_HP * float(duel)
		var want := 0
		for t in SOURCE_XP:
			if source_pts >= t: want += 1
		var pts := 2.0 * DOWN_DMG * float(duel)
		ok(me.armor_tier == want and foe.armor_tier == want,
				"duel %d (%.0f dealt + taken): tier %d, source %d" % [duel, pts, me.armor_tier, want])

func _no_refill(m: Match, me: Hunter) -> void:
	me.armor = me.max_armor * 0.5
	var a0 := me.armor
	for i in int(10.0 / Match.DT): m.step(Match.DT)
	ok(is_equal_approx(me.armor, a0), "armor does not refill out of combat (%.1f -> %.1f in 10s)" % [a0, me.armor])

func _revive(m: Match, me: Hunter) -> void:
	_set_tier(me, 3)
	Life.bring_back(m, me, me.pos, 0.5, false)
	ok(me.armor_tier == 0 and me.armor_xp == 0.0 and me.armor == 0.0, "back from the dead on a broken Common piece")
