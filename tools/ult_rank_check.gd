extends RefCounted
## --ult-rank-check: the hero ultimate ranks with R (docs/decisions/0022-ult-ranks.md).
##   1. every Hunter's X numbers at R ranks 2 and 3 (x.per_rank, the source's R tiers; tender the shared step)
##   2. R rank 3 opens at level 10 and the player picks it: a point at 10 can go into R or anywhere else
##   3. a bot at 10 with every slot at rank 2 takes R rank 3 by itself
##   4. the R hover line reads "Rank n / 3" and the next rank's numbers
## Runs a real match headless. Never touches the save.

## hero -> {key: [rank 2, rank 3]} (cooldown is HeroUlt.cooldown, the rest x_def())
const WANT := {
	"juggernaut": {"cooldown": [32.0, 28.0], "dmg": [73.0, 103.0]},
	"rimewright": {"cooldown": [70.0, 60.0], "dmg": [56.0, 56.0]},
	"ashwick": {"cooldown": [24.0, 24.0], "trail_dps": [4.5, 5.625]},
	"gunslinger": {"cooldown": [38.0, 34.0], "dmg": [28.8, 33.6], "tick_dmg": [3.6, 4.2]},
	"dredge": {"cooldown": [18.0, 15.0], "dmg": [4.8, 5.6]},
	"mage": {"cooldown": [37.0, 32.0], "dmg": [33.0, 33.0]},
	"archer": {"cooldown": [55.0, 50.0], "dmg": [19.8, 21.6], "final_dmg": [27.5, 30.0]},
	"bulwark": {"cooldown": [36.0, 32.0], "strike_dmg": [4.8, 5.6], "dmg": [21.6, 25.2]},
	"thief": {"cooldown": [21.5, 19.0], "dmg": [4.4, 4.8], "rim_dmg": [2.2, 2.4]},
	"dolm": {"cooldown": [40.0, 35.0], "time": [9.5, 12.0]},
	"ostra": {"cooldown": [65.0, 60.0], "time": [3.5, 3.5]},
	"tender": {"cooldown": [41.4, 36.8]},
}

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ULTRANK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 22, "no_drop": true,
		"arch": "thief", "cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	var P: Hunter = m.player
	P.ctrl = "local"
	var bot: Hunter = null
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
			bot = o
	ok(WANT.size() == Arch.ids().size(), "every Hunter has a row (%d of %d)" % [WANT.size(), Arch.ids().size()])
	for id in WANT:
		_numbers(P, String(id))
	P.reclass(Arch.weight("thief"), "thief")
	_player_picks(P)
	_bot_rank3(bot)
	print("ULTRANK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## 1: the hero's X at R ranks 2 and 3 against the table; rank 1 is the JSON's own number.
func _numbers(P: Hunter, id: String) -> void:
	P.reclass(Arch.weight(id), id)
	var base: Dictionary = Arch.def(id)["x"]
	var got := []
	var good := P.arch == id
	for r in [1, 2, 3]:
		P.slot_lv["ult"] = r
		for key in WANT[id]:
			var v := HeroUlt.cooldown(P.ak) if key == "cooldown" else float(P.ak.x_def()[key])
			var want := float(base[key]) if r == 1 else float(WANT[id][key][r - 2])
			got.append("%s%d %.2f" % [key, r, v])
			good = good and is_equal_approx(v, want)
	ok(good, "%s ranks 1-3: %s" % [id, ", ".join(got)])

## 2: rank 3 waits for level 10, and the point there is the player's to place.
func _player_picks(P: Hunter) -> void:
	P.slot_lv = {"sec": 2, "dash": 2, "kin": 1, "ult": 2}
	P.lvl = 9
	P.skill_pts = 1
	ok(not P.can_level("ult"), "R rank 3 is shut at level 9")
	P.gain_xp(float(Hunter.XP_TO[9]) - P.xp + 1.0)
	ok(P.lvl == 10 and P.skill_pts == 2 and int(P.slot_lv["ult"]) == 2,
			"level 10: the player's points wait for a choice (R %d, %d points)" % [int(P.slot_lv["ult"]), P.skill_pts])
	ok(P.can_level("ult") and P.can_level("kin"), "level 10: R and E can both take the point")
	ok(P.rank_text("r").begins_with("Rank 2 / 3") and P.rank_text("r").contains("19s"),
			"R hover: rank 2 of 3, next rank's numbers (%s)" % P.rank_text("r"))
	P.level_slot("kin")
	ok(int(P.slot_lv["ult"]) == 2 and int(P.slot_lv["kin"]) == 2, "a point put into E leaves R at rank 2")
	var cd2 := HeroUlt.cooldown(P.ak)
	P.level_slot("ult")
	ok(int(P.slot_lv["ult"]) == 3 and P.skill_pts == 0 and not P.can_level("ult"),
			"the player picked R rank 3, the cap")
	ok(HeroUlt.cooldown(P.ak) < cd2 and int(HeroUlt.slot_info(P.ak)["level"]) == 3,
			"rank 3 rests less (%.1fs -> %.1fs) and the X tile reads rank 3" % [cd2, HeroUlt.cooldown(P.ak)])

## 3: a bot spends rank 3 itself once every slot is at rank 2.
func _bot_rank3(bot: Hunter) -> void:
	if bot == null:
		ok(false, "a bot in the match")
		return
	bot.gain_xp(float(Hunter.XP_TO[8]) - bot.xp + 1.0)
	ok(bot.lvl == 9 and int(bot.slot_lv["ult"]) == 2, "a bot at 9 has R rank 2 (%s)" % str(bot.slot_lv))
	bot.gain_xp(float(Hunter.XP_TO[9]) - bot.xp + 1.0)
	ok(bot.lvl == 10 and int(bot.slot_lv["ult"]) == 3 and bot.skill_pts == 0,
			"a bot at 10 takes R rank 3 (%s)" % str(bot.slot_lv))
