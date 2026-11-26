extends RefCounted
## --anti-heal-check: Anti-Heal (blight) leaves 30% of every heal (content/rules/combat.json
## anti_heal_cut 0.7), and a heal with no Anti-Heal on is whole. Headless; never touches the save.

const HEAL := 20.0   # hp of the test heal

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ANTIHEAL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	var h: Hunter = m.hunters.filter(func(x: Hunter) -> bool: return x != m.player)[0]
	var cut := InCombat.anti_heal_cut()
	ok(is_equal_approx(cut, 0.7), "the rule: Anti-Heal cuts 70%% of a heal (%.2f)" % cut)
	h.hp = 10.0
	h.heal(HEAL)
	ok(is_equal_approx(h.hp, 10.0 + HEAL), "no Anti-Heal: the heal is whole (%.1f)" % h.hp)
	KitStatus.apply(h, "blt", 3.0)
	var applied := h.blight_t > 0.0 and is_equal_approx(h.blight_k, cut)
	ok(applied, "Anti-Heal applied with the rule's cut (%.2f)" % h.blight_k)
	h.hp = 10.0
	h.heal(HEAL)
	ok(is_equal_approx(h.hp, 10.0 + HEAL * 0.3), "under Anti-Heal a %.0f heal gives %.1f (30%%)" % [HEAL, h.hp - 10.0])
	h.blight_t = 0.0
	h.hp = 10.0
	h.heal(HEAL)
	ok(is_equal_approx(h.hp, 10.0 + HEAL), "Anti-Heal over: the heal is whole again")
	print("ANTIHEAL done, %d failures" % bad)
	m.queue_free()
	main.get_tree().quit(1 if bad > 0 else 0)
