extends RefCounted
## --match-grade-check: the match's colour grade is data (content/rules/match_grade.json) and reaches the match's
## environment. On the desktop renderer Look.environment multiplies the base saturation by the match's boost and by
## the home's default (DESKTOP_SAT_BOOST) when none is given; the simpler renderer ignores both. The four dark
## Hunters keep a lifted floor and a rim in warden_look.json. Prints PASS/FAIL. Never touches the save.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("MATCHGRADE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	var boost := float(Content.rules("match_grade")["desktop_saturation_boost"])
	ok(
		boost > 0.3 and boost < Look.DESKTOP_SAT_BOOST,
		"the match's boost %.2f is below the home's %.2f" % [boost, Look.DESKTOP_SAT_BOOST]
	)
	var base := Look.environment({}).adjustment_saturation
	var matched := Look.environment({"desktop_boost": boost}).adjustment_saturation
	if Look.full_renderer():
		ok(is_equal_approx(base, 1.14 * Look.DESKTOP_SAT_BOOST), "no boost given: the home's grade %.2f" % base)
		ok(is_equal_approx(matched, 1.14 * boost), "the match's boost reaches the grade: %.2f" % matched)
	else:
		ok(is_equal_approx(base, matched), "the simpler renderer ignores the boost")
	var look: Dictionary = Content.rules("warden_look")
	for id in ["vex", "breaker", "cinder", "ostra"]:
		var text := JSON.stringify(look[id])
		ok(text.contains("dark_lift"), "%s lifts its near-black paint" % id)
	print("MATCHGRADE %s" % ("PASS" if bad == 0 else "FAIL %d" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)
