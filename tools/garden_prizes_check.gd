extends RefCounted
## --garden-prizes-check (GARDEN_MODERN.md 4.4): the garden games' prize tables and weekly cups in
## content/rules/garden_prizes.json. Tables sum to 100 and name real items; the first win of a day adds its
## item once; a simulated Crown run (Sprout, Bloom, Crown) grants exactly one ribbon and the cup prize, a
## second Crown the same week grants none, the next week grants again; weak rivals and losses behave; the
## ribbon shows on the model and the card. Never touches the real save.

const DAY := 86400.0
const WEEK := 604800.0

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("GARDENPRIZES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_tables()
	_first_win()
	_cup()
	_visible()
	print("GARDENPRIZES DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _boki(power: int) -> Dictionary:
	var rec := Save.new_kin("cindle", "T-%d" % power)
	rec["stats"] = {"power": power, "guard": power, "speed": power, "focus": power}
	return rec

func _tables() -> void:
	ok(GardenPrizes.ids().size() == 8, "eight games: dash, shove, seek, volley, show, echo, relay, lantern")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for id in GardenPrizes.ids():
		var g := GardenPrizes.game(id)
		var real := true
		for e in g["table"]:
			real = real and (Data.CROPS.has(e["id"]) if e["kind"] == "snack" else GardenItems.has(e["id"]))
		ok(GardenPrizes.table_total(id) == 100 and real, "%s: table sums to 100 and names real items and snacks" % id)
		ok(GardenItems.has(g["first"]) and GardenItems.has(g["cup_prize"]), "%s: first-win item, cup prize exist" % id)
		var seen := {}
		for i in 600:
			seen[GardenPrizes.roll(id, rng)["id"]] = true
		ok(seen.size() == (g["table"] as Array).size(), "%s: every table entry can be rolled" % id)
	var rounds: Array = GardenPrizes.rules()["cup"]["rounds"]
	ok(rounds.size() == 3 and rounds[2]["name"] == "Crown", "the cup is three rounds ending in the Crown")

func _first_win() -> void:
	var me := _boki(20)
	var foe := _boki(5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var a := GardenPrizes.settle("dash", me, foe, true, 10.0 * DAY, rng)
	var b := GardenPrizes.settle("dash", me, foe, true, 10.0 * DAY + 60.0, rng)
	var c := GardenPrizes.settle("dash", me, foe, true, 11.0 * DAY, rng)
	var guaranteed: bool = a["items"].size() == 2 and a["items"][1]["id"] == "zipseed"
	ok(a["first"] and guaranteed, "first win of a day: roll + guaranteed item")
	ok(not b["first"] and b["items"].size() == 1, "second win the same day: only the roll")
	ok(c["first"], "the next day's first win pays again")
	var other := GardenPrizes.settle("shove", me, foe, true, 10.0 * DAY, rng)
	ok(other["first"], "first win is per game")

func _cup() -> void:
	Save.d = Save.fresh()
	var me := _boki(20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var t := 100.0 * WEEK
	var weak := _boki(5)
	var weak_win := GardenPrizes.settle("shove", me, weak, true, t, rng)
	ok(weak_win["round"] == "", "a win over a much weaker rival is no round")
	var bag_before := int(Save.d["items"].get("keepstone", 0))
	var names: Array = []
	for foe_power in [19, 21, 23]:
		var res := GardenPrizes.settle("shove", me, _boki(foe_power), true, t, rng)
		names.append(res["round"])
	ok(names == ["Sprout", "Bloom", "Crown"], "Sprout, Bloom, Crown in a row (got %s)" % str(names))
	ok(GardenPrizes.ribbon_count(me, "shove") == 1, "the Crown grants exactly one Stump Shove ribbon")
	ok(int(Save.d["items"].get("keepstone", 0)) == bag_before + 1, "the Crown grants a Keepstone, the cup prize")
	var again: Array = []
	for foe_power in [19, 21, 23]:
		again.append(GardenPrizes.settle("shove", me, _boki(foe_power), true, t + DAY, rng))
	var ribbons := GardenPrizes.ribbon_count(me, "shove")
	ok(ribbons == 1 and not again[2]["ribbon"], "a second Crown the same week: no ribbon")
	ok(int(Save.d["items"].get("keepstone", 0)) == bag_before + 1, "...and no second cup prize")
	var later: Array = []
	for foe_power in [19, 21, 23]:
		later.append(GardenPrizes.settle("shove", me, _boki(foe_power), true, t + WEEK, rng))
	ok(GardenPrizes.ribbon_count(me, "shove") == 2 and later[2]["ribbon"], "the next week's Crown grants again")
	_echo_crown(rng, t + 5.0 * WEEK)
	_loss_and_games(rng, t + 3.0 * WEEK)

## Echo Steps' first Crown also gives Chimegrass; the next one does not.
func _echo_crown(rng: RandomNumberGenerator, t: float) -> void:
	var me := _boki(20)
	for week in 2:
		for foe_power in [19, 21, 23]:
			GardenPrizes.settle("echo", me, _boki(foe_power), true, t + week * WEEK, rng)
		ok(int(Save.d["items"].get("chimegrass", 0)) == 1, "Echo Steps Crown %d: Chimegrass once in all" % (week + 1))
	ok(GardenPrizes.ribbon_count(me, "echo") == 2, "...and the Echo Steps Cup Ribbon each time")

func _loss_and_games(rng: RandomNumberGenerator, t: float) -> void:
	var me := _boki(20)
	GardenPrizes.settle("seek", me, _boki(22), true, t, rng)
	ok(GardenPrizes.stage(me, "seek") == 1, "one cup win moves the run to Bloom")
	ok(GardenPrizes.stage(me, "dash") == 0, "each game has its own cup")
	var lost := GardenPrizes.settle("seek", me, _boki(22), false, t, rng)
	ok(lost["reset"] and GardenPrizes.stage(me, "seek") == 0, "a loss starts the run over")
	var other := _boki(20)
	GardenPrizes.settle("volley", other, _boki(30), true, t, rng)
	ok(GardenPrizes.stage(other, "volley") == 1 and GardenPrizes.stage(me, "volley") == 0, "cup runs are per Boki")
	var strong := _boki(30)
	ok(GardenPrizes.strongest([me, strong, other], me) == strong, "the Dash judges against its strongest rival")

func _visible() -> void:
	var rec := _boki(20)
	rec["ribbons"] = {"dash": {"n": 1, "week": 5}}
	var body := Node3D.new()
	PrizeBoard.dress(body, rec)
	var rosette := body.get_child_count() == 2 and body.get_child(0).name == "CupRibbon0"
	ok(rosette, "a ribbon is a rosette on the model")
	body.free()
	var v := VBoxContainer.new()
	PrizeBoard.add_ribbons(v, rec)
	ok(v.get_child_count() == 1, "the card has one row for the one ribbon")
	v.free()
	var board := VBoxContainer.new()
	PrizeBoard.fill(board, rec)
	ok(board.get_child_count() == 4 * GardenPrizes.ids().size(),
			"the board lists table, first-win item and cup for each game")
	board.free()
	var rows := GardenPrizes.rows({"game": "dash", "items": [{"kind": "snack", "id": "puffcorn"}], "first": true,
			"round": "", "ribbon": true, "reset": false})
	ok(rows.size() == 2, "a Crown result card shows the prize and the ribbon")
