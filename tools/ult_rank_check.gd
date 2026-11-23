extends RefCounted
## --ult-rank-check: the hero ultimate ranks with R (docs/decisions/0022-ult-ranks.md).
##   1. every Hunter's X numbers at R ranks 2 and 3 (x.per_rank, the source's R tiers; Gil has none and keeps its base)
##   2. R rank 3 opens at level 10 and the player picks it: a point at 10 can go into R or anywhere else
##   3. a bot at 10 with every slot at rank 2 takes R rank 3 by itself
##   4. the R hover line reads "Rank n / 3" and the next rank's numbers
## Runs a real match headless. Never touches the save.

## hero -> {key: [rank 2, rank 3]} (cooldown is HeroUlt.cooldown, the rest x_def())
const WANT := {
	"juggernaut": {"cooldown": [32.0, 28.0], "dmg": [48.6, 54.2]},
	"rimewright": {"cooldown": [70.0, 60.0], "dmg": [25.2, 25.2]},
	"ashwick": {"cooldown": [24.0, 24.0], "trail_dps": [4.5, 5.625]},
	"gunslinger": {"cooldown": [38.0, 34.0], "dmg": [28.8, 33.6], "tick_dmg": [4.2, 4.9]},
	"dredge": {"cooldown": [18.0, 15.0], "dmg": [4.8, 5.6]},
	"mage": {"cooldown": [37.0, 32.0], "dmg": [13.5, 13.5]},
	"archer": {"cooldown": [55.0, 50.0], "dmg": [19.8, 21.6], "final_dmg": [25.63, 27.96]},
	"bulwark": {"cooldown": [36.0, 32.0], "strike_dmg": [4.8, 5.6], "dmg": [21.6, 25.2]},
	"thief": {"cooldown": [21.5, 19.0], "dmg": [4.95, 5.4], "rim_dmg": [3.41, 3.72]},
	"dolm": {"cooldown": [40.0, 35.0], "time": [9.5, 12.0]},
	"ostra": {"cooldown": [65.0, 60.0], "time": [3.5, 3.5]},
	"tender": {"cooldown": [42.0, 38.0], "heal_ps": [6.625, 7.95]},
	"gil": {"cooldown": [90.0, 90.0], "dmg": [18.0, 18.0]},
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
	await m.start(
		{
			"teams": 2,
			"squad": 1,
			"tier": 0,
			"length": 1e9,
			"seed": 22,
			"no_drop": true,
			"arch": "thief",
			"cls": Arch.weight("thief"),
			"weapon": Arch.signature("thief")
		}
	)
	var p_v: Hunter = m.player
	p_v.ctrl = "local"
	var bot: Hunter = null
	for o in m.hunters:
		if o != p_v:
			o.ctrl = "idle"
			bot = o
	ok(WANT.size() == Arch.ids().size(), "every Hunter has a row (%d of %d)" % [WANT.size(), Arch.ids().size()])
	for id in WANT:
		_numbers(p_v, String(id))
	p_v.reclass(Arch.weight("thief"), "thief")
	_player_picks(p_v)
	_bot_rank3(bot)
	print("ULTRANK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## 1: the hero's X at R ranks 2 and 3 against the table; rank 1 is the JSON's own number.
func _numbers(p_v: Hunter, id: String) -> void:
	p_v.reclass(Arch.weight(id), id)
	var base: Dictionary = Arch.def(id)["x"]
	var got := []
	var good := p_v.arch == id
	for r in [1, 2, 3]:
		p_v.slot_lv["ult"] = r
		for key in WANT[id]:
			var v := HeroUlt.cooldown(p_v.ak) if key == "cooldown" else float(p_v.ak.x_def()[key])
			var want := float(base[key]) if r == 1 else float(WANT[id][key][r - 2])
			got.append("%s%d %.2f" % [key, r, v])
			good = good and is_equal_approx(v, want)
	ok(good, "%s ranks 1-3: %s" % [id, ", ".join(got)])


## 2: rank 3 waits for level 10, and the point there is the player's to place.
func _player_picks(p_v: Hunter) -> void:
	p_v.slot_lv = {"sec": 2, "dash": 2, "kin": 1, "ult": 2}
	p_v.lvl = 9
	p_v.skill_pts = 1
	ok(not p_v.can_level("ult"), "R rank 3 is shut at level 9")
	p_v.gain_xp(float(Hunter.XP_TO[9]) - p_v.xp + 1.0)
	ok(
		p_v.lvl == 10 and p_v.skill_pts == 2 and int(p_v.slot_lv["ult"]) == 2,
		"level 10: the player's points wait for a choice (R %d, %d points)" % [int(p_v.slot_lv["ult"]), p_v.skill_pts]
	)
	ok(p_v.can_level("ult") and p_v.can_level("kin"), "level 10: R and E can both take the point")
	ok(
		p_v.rank_text("r").begins_with("Rank 2 / 3") and p_v.rank_text("r").contains("19s"),
		"R hover: rank 2 of 3, next rank's numbers (%s)" % p_v.rank_text("r")
	)
	p_v.level_slot("kin")
	ok(int(p_v.slot_lv["ult"]) == 2 and int(p_v.slot_lv["kin"]) == 2, "a point put into E leaves R at rank 2")
	var cd2 := HeroUlt.cooldown(p_v.ak)
	p_v.level_slot("ult")
	ok(
		int(p_v.slot_lv["ult"]) == 3 and p_v.skill_pts == 0 and not p_v.can_level("ult"),
		"the player picked R rank 3, the cap"
	)
	ok(
		HeroUlt.cooldown(p_v.ak) < cd2 and int(HeroUlt.slot_info(p_v.ak)["level"]) == 3,
		"rank 3 rests less (%.1fs -> %.1fs) and the X tile reads rank 3" % [cd2, HeroUlt.cooldown(p_v.ak)]
	)


## 3: a bot spends rank 3 itself once every slot is at rank 2.
func _bot_rank3(bot: Hunter) -> void:
	if bot == null:
		ok(false, "a bot in the match")
		return
	bot.gain_xp(float(Hunter.XP_TO[8]) - bot.xp + 1.0)
	ok(bot.lvl == 9 and int(bot.slot_lv["ult"]) == 2, "a bot at 9 has R rank 2 (%s)" % str(bot.slot_lv))
	bot.gain_xp(float(Hunter.XP_TO[9]) - bot.xp + 1.0)
	ok(
		bot.lvl == 10 and int(bot.slot_lv["ult"]) == 3 and bot.skill_pts == 0,
		"a bot at 10 takes R rank 3 (%s)" % str(bot.slot_lv)
	)
