extends RefCounted
## --armour-hint-check: the one hint about armour (ArmourHint). The first time the player's damage to
## a rival Hunter fills armour progress, 'Hits on Hunters build armour. XP comes from monster kills.'
## shows next to the armour readout (not in the message lane) and the badge pops; damage to a
## monster says nothing; it shows once per save (also after the save is written
## and read back); the tutorial match and the "tips" setting keep it quiet. Never touches the save file.

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

func _rival(m: Match) -> Hunter:
	for h in m.hunters:
		if h != m.player and h.team != m.player.team:
			return h
	return null

## The player hits `target` through Match.on_damage; returns whether the hint is up next to the
## armour readout, after clearing it.
func _hit(m: Match, target: Ent) -> bool:
	m.hud.set_meta("armor_note", [])
	m.hud.msgs.clear()
	var xp0: float = m.player.armor_xp
	m.on_damage(target, m.player, 20.0, {})
	if target is Hunter:
		ok(m.player.armor_xp > xp0, "the hit filled armour progress (%.1f -> %.1f)" % [xp0, m.player.armor_xp])
	var n: Array = m.hud.get_meta("armor_note", [])
	ok(not m.hud.msgs.texts().has(ArmourHint.TEXT), "the hint is never in the message lane")
	return not n.is_empty() and n[0] == ArmourHint.TEXT

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var seen: Dictionary = Save.d["tutorial"]
	var m := _match(main)
	var foe := _rival(m)
	ok(foe != null, "the match has a rival Hunter")
	if foe == null:
		main.get_tree().quit(1)
		return
	ok(not seen.has(ArmourHint.FLAG), "a fresh save has not seen it")
	m.opts["tutorial"] = true
	ok(not _hit(m, foe) and not seen.has(ArmourHint.FLAG), "no hint in the tutorial match")
	m.opts["tutorial"] = false
	Settings.set_v("tips", false, false)
	ok(not _hit(m, foe) and not seen.has(ArmourHint.FLAG), "no hint with tips turned off")
	Settings.set_v("tips", true, false)
	var mob: Ent = null
	for e in m.mobs:
		if e is Ent and not e is Hunter:
			mob = e
			break
	if mob:
		ok(not _hit(m, mob), "a hit on a monster says nothing")
	ok(_hit(m, foe), "the first hit on a Hunter shows it next to the armour readout")
	ok(float(m.hud.get_meta("armor_pop", 0.0)) > 0.0, "the armour badge pops with it")
	ok(seen.get(ArmourHint.FLAG, false), "the save remembers it")
	# once only: the next hits, a tier-up, then the same save read back in a new match
	ok(not _hit(m, foe), "the second hit does not repeat it")
	m.player.armor_gain(float(Hunter.ARMOR_TIERS[m.player.armor_tier + 1][2]) - m.player.armor_xp)
	m._armor_up(m.player)
	ok(not _hit(m, foe), "nor a hit after a tier-up")
	m.queue_free()
	Save.d = JSON.parse_string(JSON.stringify(Save.d))
	m = _match(main)
	ok(not _hit(m, _rival(m)), "after a save round trip it never shows again")
	m.queue_free()
	print("ARMOUR HINT CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
