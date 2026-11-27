extends RefCounted
## --heal-parity-check: the healing cut (heals given to another Hunter x0.65, self-heal whole), Anti-Heal on top
## (0.65 x 0.3), and Hunter health recovery (0.1% of max every 0.1 s, paused 4 s after a hit). Headless.

const HEAL := 40.0  # hp of the test heal

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("HEALPARITY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


## Steps the Hunter's health recovery for `secs` of match time in 0.05 s frames.
func _run(m: Match, h: Hunter, secs: float) -> void:
	for i in int(secs / 0.05):
		m.time += 0.05
		HealRules.regen_tick(h, 0.05)


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	var others: Array = m.hunters.filter(func(x: Hunter) -> bool: return x != m.player)
	var a: Hunter = m.player
	var b: Hunter = others[0]
	var given_k := float(HealRules.rules()["heal_given_k"])
	ok(is_equal_approx(given_k, 0.65), "the rule: healing given is x0.65 (%.2f)" % given_k)
	b.hp = 10.0
	b.heal(HEAL, a)
	ok(is_equal_approx(b.hp, 10.0 + HEAL * given_k), "a heal on another gives %.1f of %.0f" % [b.hp - 10.0, HEAL])
	b.hp = 10.0
	b.heal(HEAL, b)
	ok(is_equal_approx(b.hp, 10.0 + HEAL), "a heal on yourself is whole (%.1f)" % (b.hp - 10.0))
	b.hp = 10.0
	b.heal(HEAL)
	ok(is_equal_approx(b.hp, 10.0 + HEAL), "a heal from no Hunter (pickup, Boki) is whole")
	b.hp = 10.0
	KitStatus.apply(b, "blt", 3.0)
	b.heal(HEAL, a)
	var both := 10.0 + HEAL * given_k * (1.0 - b.blight_k)
	ok(is_equal_approx(b.hp, both), "Anti-Heal on top: %.1f of %.0f (0.195 x)" % [b.hp - 10.0, HEAL])
	b.blight_t = 0.0
	# health recovery
	b.hurt_at = m.time
	b.regen_acc = 0.0
	b.hp = 100.0
	var tick := b.max_hp * float(HealRules.rules()["regen"]["pct_per_tick"])
	_run(m, b, 3.9)
	ok(is_equal_approx(b.hp, 100.0), "no recovery for the 4 s after a hit (%.2f)" % (b.hp - 100.0))
	_run(m, b, 0.3)
	ok(b.hp > 100.0, "recovery starts once the pause is over (+%.2f)" % (b.hp - 100.0))
	var start := b.hp
	_run(m, b, 2.0)
	var per_s := (b.hp - start) / 2.0 / b.max_hp
	ok(absf(per_s - 0.01) < 0.0006, "about 1%% of max health a second (%.2f%%/s, tick %.2f hp)" % [per_s * 100.0, tick])
	b.hp = b.max_hp - 0.5 * tick
	_run(m, b, 0.5)
	ok(b.hp == b.max_hp, "never past max health")
	b.hp = 100.0
	b.downed = true
	_run(m, b, 1.0)
	ok(is_equal_approx(b.hp, 100.0), "a downed Hunter does not recover")
	b.downed = false
	var fx_before: int = m.fx.get_child_count()
	_run(m, b, 1.0)
	ok(m.fx.get_child_count() == fx_before, "recovery ticks spawn no number or glow")
	print("HEALPARITY done, %d failures" % bad)
	m.queue_free()
	main.get_tree().quit(1 if bad > 0 else 0)
