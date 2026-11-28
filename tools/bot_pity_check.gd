extends RefCounted
## --bot-pity-check: a bot's aim error grows with the share of health its target has lost (Bot.pity_k,
## reference tuning), by its difficulty's PITY: none on a full-health target, the most on a nearly downed
## one, nothing extra at Expert. Prints BOTPITY lines.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("BOTPITY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	var t := Hunter.new()
	var mob := Ent.new()  # a monster or guard: pity is for a hurt player only
	mob.max_hp = 100.0
	mob.hp = 0.0
	t.max_hp = 100.0
	for diff in Data.BOT_ORDER:
		var a := {"diff": Data.BOT_DIFF[diff]}
		var pity := float(Bot.PITY.get(String(Data.BOT_DIFF[diff]["name"]), -1.0))
		ok(pity >= 0.0, "%s has a pity row (%.2f)" % [diff, pity])
		t.hp = 100.0
		var full := Bot.pity_k(a, t)
		t.hp = 50.0
		var half := Bot.pity_k(a, t)
		t.hp = 0.0
		var low := Bot.pity_k(a, t)
		ok(is_equal_approx(full, 1.0), "%s: a full-health target gets the plain error (x%.2f)" % [diff, full])
		ok(is_equal_approx(half, 1.0 + pity * 0.5), "%s: half health lost: x%.2f" % [diff, half])
		ok(is_equal_approx(Bot.pity_k(a, mob), 1.0), "%s: a hurt monster gets the plain error" % diff)
		ok(is_equal_approx(low, 1.0 + pity), "%s: all health lost: x%.2f" % [diff, low])
	ok(is_equal_approx(float(Bot.PITY["Expert"]), 0.0), "an Expert bot shows no pity")
	ok(float(Bot.PITY["Easy"]) > float(Bot.PITY["Hard"]), "an Easy bot shows more pity than a Hard one")
	t.free()
	mob.free()
	main.get_tree().quit(1 if bad > 0 else 0)
