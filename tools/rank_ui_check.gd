extends RefCounted
## --rank-ui-check: choosing which ability to rank.
##   1. every level-up banks one point; all of them can go into E until it's maxed, the others untouched
##   2. the ranks take effect (the kit's rank, power and cooldown follow E's rank)
##   3. bots still spend their points on their own
##   4. the bar shows tier pips and a gold "+" on every slot that can rank, with a click target over it;
##      clicking the "+" spends the point; with no points left the "+" and its click target go away
##   5. a new point shows the ALT+key hint for a few seconds
## Runs a real match headless with the real HUD. Never touches the save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("RANKUI %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true,
		"arch": "gunslinger", "cls": Arch.weight("gunslinger"), "weapon": Arch.signature("gunslinger")})
	var P: Hunter = m.player
	P.ctrl = "local"
	var bot: Hunter = null
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
			o.teleport(P.pos + Vector3(40, 0, 40))
			bot = o
	_max_e_first(P)
	_bot_ranks(bot)
	await _bar(m, P)
	print("RANKUI DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## 1 + 2: three level-ups' points all go into E; RMB and dash stay locked; E's rank drives the kit.
func _max_e_first(P: Hunter) -> void:
	var e_max := int(Hunter.SLOT_MAX["kin"])
	var pow1 := P.ak.power("kin") if P.ak.rank("kin") == 1 else -1.0
	var cd1 := P.ak.cd_k("kin")
	P.gain_xp(float(Hunter.XP_TO[e_max - 1]) - P.xp + 1.0)
	ok(P.lvl == e_max and P.skill_pts == e_max, "level %d banks %d points (%d)" % [e_max, e_max, P.skill_pts])
	for i in e_max:
		P.level_slot("kin")
	ok(int(P.slot_lv["kin"]) == e_max and P.skill_pts == 0, "every point went into E: rank %d of %d" % [
		int(P.slot_lv["kin"]), e_max])
	ok(int(P.slot_lv["sec"]) == 0 and int(P.slot_lv["dash"]) == 0, "RMB and dash untouched (E-max first)")
	ok(not P.can_level("kin"), "E can't rank past its max")
	ok(P.ak.rank("kin") == e_max, "the kit reads E at rank %d" % P.ak.rank("kin"))
	ok(pow1 < 0.0 or P.ak.power("kin") > pow1, "E hits harder at max rank (%.2f -> %.2f)" % [pow1, P.ak.power("kin")])
	# a sourced rank_cd row may keep E's cooldown flat (Vex: her E upgrades are damage only)
	var want_cd: float = P.ak.rank_k("rank_cd", "kin", P.rank_cd_k("kin"))
	ok(is_equal_approx(P.ak.cd_k("kin"), want_cd) and P.ak.cd_k("kin") <= cd1,
		"E's recharge at max rank follows the kit's rank table (%.2f -> %.2f)" % [cd1, P.ak.cd_k("kin")])

## 3: a bot's points are spent the moment it levels.
func _bot_ranks(bot: Hunter) -> void:
	if bot == null:
		ok(false, "a bot in the match")
		return
	bot.gain_xp(float(Hunter.XP_TO[4]) - bot.xp + 1.0)
	var spent := 0
	for s in Hunter.SLOTS:
		spent += int(bot.slot_lv[s])
	ok(bot.skill_pts == 0 and spent == bot.lvl, "a bot at level %d spent its points by itself (%s)" % [
		bot.lvl, str(bot.slot_lv)])

## 4 + 5: the "+" and its click target on the real bar.
func _bar(m: Match, P: Hunter) -> void:
	var clicks: Array = m.hud.ui_extra.filter(func(n): return n is RankClick)
	ok(clicks.size() == Hunter.SLOTS.size(), "one click target per ranked slot (%d)" % clicks.size())
	P.gain_xp(float(Hunter.XP_TO[P.lvl]) - P.xp + 1.0)
	P.level_slot("dash")
	await _frames(3)
	P.gain_xp(float(Hunter.XP_TO[P.lvl]) - P.xp + 1.0)
	await m.hud.panels.draw      # the slots are drawn on HudPanels, REDRAW_HZ times a second
	await _frames(3)
	ok(P.skill_pts == 1 and P.can_level("sec") and P.can_level("dash"), "a new point that RMB or dash can take")
	ok(RankMarks.spot("sec").has_area() and RankMarks.spot("dash").has_area(),
		"locked RMB and rank-1 dash both take a click")
	ok(not RankMarks.spot("kin").has_area(), "maxed E shows no +")
	ok(RankMarks._hint_until > m.time, "the new point shows the ALT+key hint for a while")
	var rc: RankClick = null
	for n in clicks:
		if (n as RankClick).slot == "sec":
			rc = n
	ok(rc != null and rc.visible and rc.get_global_rect().is_equal_approx(RankMarks.spot("sec")),
		"the RMB click target sits on its +")
	if rc == null:
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	rc._gui_input(click)
	ok(int(P.slot_lv["sec"]) == 1 and P.skill_pts == 0, "clicking the + spent the point on RMB")
	await m.hud.panels.draw
	await _frames(3)
	ok(not RankMarks.spot("sec").has_area() and not rc.visible, "no points left: the + and its target are gone")

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame
