extends RefCounted
## --garden-rivals-check (GARDEN.md sections 4 and 5, scripts/home/base_rival.gd): rivals from the garden games.
##   1. a Boki that loses to the same Boki twice marks it a rival (one journal line, the bond drops under
##      rival_at); one loss, a loss to someone else, or a win in between does not
##   2. winning the rematch settles it (one journal line, bond back to strangers); the first winner winning
##      again does not; three shared good days settle it too, a sulky day does not count
##   3. the grudge survives a JSON save and load, and a save without the key plays on (no migration needed)
##   4. on the base: rivals pick a nap spot and toys away from each other, glare when they pass, the loser walks
##      to the Games board and waits (Ask), E accepts and starts that game with the pair, the result settles it
## Never touches the real save.

const DT := 0.25                 # s per farm step
const ASK_SECS := 90.0           # s the loser may take to reach the board
const PLAY_S := 60.0             # s the rematch may take

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("RIVALS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	var rules: Dictionary = BaseRival.rules()
	var chance: float = rules["ask_chance"]
	_marking()
	_ending()
	_saving()
	rules["ask_chance"] = 1.0
	await _on_base()
	rules["ask_chance"] = chance
	print("RIVALS DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(sp: String, kname: String) -> Dictionary:
	var k := Save.new_kin(sp, kname)
	k["level"] = 5
	Care.ensure(k)
	for need in ["food", "joy", "energy"]:
		k["needs"][need] = 90.0 if need != "joy" else 80.0
	k["trust"] = 50.0
	return k

func _lines(rec: Dictionary) -> int:
	return (rec.get("journal", []) as Array).size()

func _rival(a: Dictionary, b: Dictionary) -> bool:
	return bool(a.get("grudge", {}).get(String(b["uid"]), {}).get("rival", false))

func _marking() -> void:
	var a := _kin("zapple", "Pip")
	var b := _kin("cindle", "Ash")
	var c := _kin("zapple", "Bo")
	BaseRival.result("shove", b, a)
	ok(not _rival(a, b) and _lines(a) == 0, "one loss is no rivalry")
	BaseRival.result("seek", c, a)
	BaseRival.result("shove", a, b)
	BaseRival.result("shove", b, a)
	ok(not _rival(a, b), "a loss to someone else or a win in between clears the count")
	BaseRival.result("volley", b, a)
	ok(_rival(a, b) and _rival(b, a), "the second loss to the same Boki marks a rivalry, both ways")
	var rival_at := float(Content.rules("base_life")["rival_at"])
	ok(BaseLife.bond(a, b) <= rival_at and BaseLife.bond(a, b) == BaseLife.bond(b, a),
		"the bond drops to rival (%.2f) so the usual stares apply" % BaseLife.bond(a, b))
	ok(_lines(a) == 1 and _lines(b) == 0 and "rival" in CareJournal.text(a["journal"][0]),
		"one journal line when it starts")
	BaseRival.result("race", b, a)
	ok(_lines(a) == 1, "losing again while rivals adds no second line")

func _ending() -> void:
	var a := _kin("zapple", "Pip")
	var b := _kin("cindle", "Ash")
	BaseRival.result("shove", b, a)
	BaseRival.result("shove", b, a)
	BaseRival.result("shove", b, a)
	ok(_rival(a, b), "the first winner winning again leaves it as it was")
	BaseRival.result("seek", a, b)
	ok(not _rival(a, b) and not _rival(b, a) and BaseLife.bond(a, b) == 0.0,
		"winning the rematch settles it, back to strangers")
	ok(_lines(a) == 2 and "settled" in CareJournal.text(a["journal"][1]), "one journal line when it ends")
	BaseRival.result("shove", b, a)
	BaseRival.result("shove", b, a)
	ok(_rival(a, b), "they can fall out again")
	a["needs"]["joy"] = 30.0
	for i in 3:
		BaseRival.day([a, b])
	ok(_rival(a, b), "days when one is glum do not count")
	a["needs"]["joy"] = 80.0
	BaseRival.day([a, b])
	BaseRival.day([a, b])
	ok(_rival(a, b), "two shared good days are not enough")
	BaseRival.day([a, b])
	var before := _lines(a)
	ok(not _rival(a, b) and not _rival(b, a) and before == 4, "three shared good days settle it (journal %d)" % before)

func _saving() -> void:
	var a := _kin("zapple", "Pip")
	var b := _kin("cindle", "Ash")
	BaseRival.result("shove", b, a)
	BaseRival.result("shove", b, a)
	var a2: Dictionary = JSON.parse_string(JSON.stringify(a))
	var b2: Dictionary = JSON.parse_string(JSON.stringify(b))
	ok(_rival(a2, b2) and BaseLife.bond(a2, b2) <= -0.5, "the rivalry survives a save and a load")
	BaseRival.result("shove", a2, b2)
	ok(not _rival(a2, b2), "and settles after it")
	var old := _kin("zapple", "Old")
	old.erase("grudge")
	BaseRival.result("shove", b2, old)
	ok(int(old["grudge"][String(b2["uid"])]["lost"]) == 1, "a save without the key plays on (no migration)")

func _on_base() -> void:
	var rules: Dictionary = FarmUnlocks.rules()
	var d := Save.fresh()
	for i in 3:
		var k := _kin(["zapple", "cindle", "zapple"][i], ["Pip", "Ash", "Bo"][i])
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in 600:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	home.day_t = 0.4
	home.ppos = Vector3(-500, 0, -500)
	var board: Node3D = home.hboard.board
	var pip: Dictionary = home.kins[0]
	var ash: Dictionary = home.kins[1]
	var bo: Dictionary = home.kins[2]
	for k in home.kins:
		k.erase("indoors")
		k["pos"] = board.position + Vector3(6, 0, 6)
		(k["node"] as Node3D).position = k["pos"]
	_apart(home, pip, ash, bo)
	await _ask(home, pip, ash)
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame

## Rivals keep apart for a nap or a toy, and glare when they pass; a stranger is not avoided.
func _apart(home, pip: Dictionary, ash: Dictionary, bo: Dictionary) -> void:
	BaseRival.result("shove", ash["rec"], pip["rec"])
	BaseRival.result("shove", ash["rec"], pip["rec"])
	ash["pos"] = pip["pos"] + Vector3(1.0, 0, 0)
	var spot := BaseRival.nap_spot(home, pip)
	var gap := float(BaseRival.rules()["gap"])
	ok(spot != Vector3.INF and Vector2(spot.x - ash["pos"].x, spot.z - ash["pos"].z).length() >= gap,
		"a rival close by: the nap spot is at least %.0f m from it" % gap)
	ok(BaseRival.nap_spot(home, bo) == Vector3.INF, "a stranger is not avoided")
	ok(BaseRival.rival_near(home, pip, ash["pos"]) and not BaseRival.rival_near(home, bo, ash["pos"]),
		"a toy where its rival stands is skipped, a stranger's is not")
	for k in home.kins:
		k["emote_t"] = 0.0
	pip["glare_t"] = 0.0
	BaseRival.glare(home, pip, DT)
	ok((pip["emote"] as Label3D).text == "#" and float(pip["glare_t"]) > 0.0,
		"rivals that pass glare, then wait out the cooldown")
	ash["pos"] = pip["pos"] + Vector3(30, 0, 0)

## The loser walks to the board and waits; E accepts; the rematch is the game it lost, played by the pair.
func _ask(home, pip: Dictionary, ash: Dictionary) -> void:
	var board: BaseBoard = home.hboard
	for k in home.kins:
		k["pos"] = board.board.position + Vector3(3, 0, 3)
		(k["node"] as Node3D).position = k["pos"]
		k["goal"] = k["pos"]
	var t := 0.0
	while t < ASK_SECS and BaseRival.waiting(home).is_empty():
		home._move_kin(DT)
		t += DT
	var k := BaseRival.waiting(home)
	ok(not k.is_empty() and k == pip, "the loser walked to the Games board and waits there (%.0f s)" % t)
	home.ppos = board.board.position + Vector3(0, 0, 1.0)
	ok(board.label().begins_with("Accept Pip"), "the board offers the rematch")
	board.use()
	var game: BaseShove = home.hshove
	ok(game.running() and game.pair == [pip, ash], "E starts the game it lost (Stump Shove) with the pair")
	ok((pip["life"] as Fsm).is_in(BaseLife.S.ROAM), "the loser stops waiting")
	var t2 := 0.0
	while game.running() and t2 < PLAY_S:
		game.tick(0.1)
		t2 += 0.1
	var won: bool = Save.d["game_board"]["shove"]["last"] == "Pip"
	ok(t2 < PLAY_S and _rival(pip["rec"], ash["rec"]) != won,
		"the rematch settles it when the loser wins (won %s)" % won)
	board.tick(0.1)
	ok(home.hrace.pair_force.is_empty(), "the pair is spent after the game")
