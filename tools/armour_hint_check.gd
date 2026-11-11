extends RefCounted
## --armour-hint-check: the one hint about armour. The first tier-up says hitting other Hunters
## upgrades it; a hit on a Hunter that earned no level XP says it shorter if the first has not shown;
## each shows once per save (also after the save is written and read back); the tutorial match and the
## "tips" setting keep it quiet. Never touches the save file.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ARMOURHINT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _match(main: Node) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true,
		"arch": "thief", "cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	return m

func _tier_up(m: Match) -> Array:
	m.hud.msgs.clear()
	m.player.armor_gain(float(Hunter.ARMOR_TIERS[m.player.armor_tier + 1][2]) - m.player.armor_xp)
	m._armor_up(m.player)
	return m.hud.msgs.texts()

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var seen: Dictionary = Save.d["tutorial"]
	var m := _match(main)
	ok(not seen.has(ArmourHint.FLAG), "a fresh save has not seen it")
	# in the tutorial match: nothing, and the flag stays free for later
	m.opts["tutorial"] = true
	ok(not _tier_up(m).has(ArmourHint.TIER_UP) and not seen.has(ArmourHint.FLAG), "no hint in the tutorial match")
	m.opts["tutorial"] = false
	Settings.set_v("tips", false, false)
	ok(not _tier_up(m).has(ArmourHint.TIER_UP), "no hint with tips turned off")
	Settings.set_v("tips", true, false)
	# the first tier-up outside the tutorial
	var lane := _tier_up(m)
	ok(lane.has(ArmourHint.TIER_UP), "the first tier-up says it (%s)" % str(lane))
	ok(float(m.hud.get_meta("armor_pop", 0.0)) > 0.0, "the armour badge pops with it")
	ok(not _tier_up(m).has(ArmourHint.TIER_UP), "the next tier-up does not repeat it")
	ArmourHint.hit(m, m.player, m.player.xp)
	ok(not m.hud.msgs.texts().has(ArmourHint.HIT), "a hit with no XP gain stays quiet once it has shown")
	m.queue_free()
	# the same save, written and read back
	Save.d = JSON.parse_string(JSON.stringify(Save.d))
	m = _match(main)
	ok(not _tier_up(m).has(ArmourHint.TIER_UP), "after a save round trip it never shows again")
	m.queue_free()
	# the short form, on its own
	Save.d = Save.fresh()
	m = _match(main)
	m.hud.msgs.clear()
	ArmourHint.hit(m, m.player, m.player.xp - 1.0)
	ok(m.hud.msgs.count() == 0, "a hit that earned level XP says nothing")
	ArmourHint.hit(m, m.player, m.player.xp)
	ok(m.hud.msgs.texts().has(ArmourHint.HIT), "a first hit with no XP gain says the short line")
	ok(not _tier_up(m).has(ArmourHint.TIER_UP), "and the tier-up line is then not repeated")
	m.queue_free()
	print("ARMOUR HINT CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
