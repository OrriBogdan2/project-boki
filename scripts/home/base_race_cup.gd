class_name BaseRaceCup
extends RefCounted
## The Grand Dash (PROTOTYPE, docs/GARDEN_GAMES.md): the Dash's loop run for 3 laps (about 60 to 90 s) with your
## one rested Boki and bots in the other lanes. You back your Boki and press the cheer button (boost, then a
## cooldown); pace is the Dash's own (Speed, joy, knacks). Pays like the Dash: dash prize table and weekly cup
## (GardenPrizes), gems by place. Tuning: content/rules/base_race.json "cup". Run is BaseRace.Run (laps > 1).

const BOT_COL := [Color("7a8aa8"), Color("a87a8a"), Color("8aa87a")]

static func rules() -> Dictionary:
	return BaseRace.rules()["cup"]

## Bot rivals that fill the lanes up to four: copies of `mine` with stats scaled by the cup's ratios.
static func bots(mine: Dictionary) -> Array:
	var out: Array = []
	var ratios: Array = rules()["bot_ratios"]
	for i in ratios.size():
		var b := GardenPrizes.rival(mine, float(ratios[i]))
		b["name"] = "Bot %d" % (i + 1)
		b["bot"] = true
		out.append(b)
	return out

## A bare kin entry for a bot (a coloured ball on its lane): {rec, node, pos}.
static func entry(rec: Dictionary, i: int) -> Dictionary:
	var node := Node3D.new()
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	ball.mesh = sm
	ball.material_override = BaseRace.mat(BOT_COL[i % BOT_COL.size()])
	ball.position.y = 0.25
	node.add_child(ball)
	return {"rec": rec, "node": node, "pos": Vector3.ZERO}

## Pays out a finished Grand Dash for your backed Boki: energy, joy, gems by place, the Dash prize table and cup.
## Returns {place, win, gems, prize, backed_won}.
static func settle(run: BaseRace.Run) -> Dictionary:
	var r_v := BaseRace.rules()
	var c_v := rules()
	var order := run.order()
	var mine: Dictionary = run.recs[run.backed]
	var place := order.find(run.backed)
	var backed_won := place == 0
	Care.change(mine, "energy", -float(r_v["energy"]))
	Care.change(mine, "joy", float(r_v["win_joy"]) if backed_won else float(r_v["lose_joy"]) * float(place > 1))
	if backed_won:
		Save.remember(mine, "race", "won the Grand Dash", float(r_v["win_trust"]))
		MinigameHub.record("race", String(mine["name"]))
		ClanBoard.add("cup")
	var gems := int(c_v["gems"][place])
	Save.d["gems"] = int(Save.d["gems"]) + gems
	var foe := GardenPrizes.strongest(run.recs, mine, "dash")
	var prize := GardenPrizes.settle("dash", mine, foe, backed_won)
	return {"place": place, "win": run.recs[order[0]], "gems": gems, "prize": prize, "backed_won": backed_won}
