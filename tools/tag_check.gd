extends RefCounted
## --garden-tag-check (GARDEN.md section 4, scripts/home/base_tag.gd): tag, the PlayWith state of base life.
##   1. two friends start tag within MINUTES, it lasts 10-20 s, the pair's bond rises, each gains Speed and one
##      journal line, and the Boki are on the same island and back to roaming after
##   2. a rival of both friends never plays tag with either, over MINUTES with all three roaming
##   3. a rival that wanders close breaks a game up: both players huff and sulk (joy dips, bonds to the rival
##      drop), no state beyond the base life table, and the pair's own bond does not move
## Never touches the real save.

const DT := 0.25             # s per farm step
const MINUTES := 5.0         # min the friends get to start a game
const LONGEST := 20.5        # s: a game lasts at most this (rules play_with 10-20 s)
const SHORTEST := 9.5        # s: and at least this

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("TAG %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(5)
	Content.rules("farm_build")["base_mode"] = true
	await _friends()
	await _rival_never_plays()
	await _squabble()
	Content.rules("farm_build")["base_mode"] = false
	print("TAG DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(sp: String, kname: String) -> Dictionary:
	var k := Save.new_kin(sp, kname)
	k["level"] = 5
	Care.ensure(k)
	for need in ["food", "joy", "energy"]:
		k["needs"][need] = 90.0 if need != "joy" else 80.0
	k["trust"] = 50.0
	k["traits"]["temper"] = 0.1
	return k

## A base with `names` as the roster, all gathered on open ground at 6 m spacing, you away.
func _home(names: Array) -> Dictionary:
	var d := Save.fresh()
	for i in names.size():
		var k := _kin(["zapple", "cindle", "burrlet"][i], names[i])
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	var home = await main._hb_home()
	for f in 600:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	home.day_t = 0.4
	home.ppos = Vector3(-500, 0, -500)
	var at: Vector3 = home.world.random_ground(0)
	for k in home.kins:
		k.erase("indoors")
		k["pos"] = home.world.free_spot_near(at + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), [], 0.8)
		(k["node"] as Node3D).position = k["pos"]
	return {"home": home}

func _drop(home) -> void:
	home.queue_free()
	await main.get_tree().process_frame

func _befriend(a: Dictionary, b: Dictionary, bond: float) -> void:
	for rec in [a, b]:
		rec["bonds"] = {}
	BaseLife.add_bond(a, b, bond)

func _playing(k: Dictionary) -> bool:
	return (k["life"] as Fsm).is_in(BaseLife.S.PLAY_WITH)

func _plays_with(k: Dictionary, other: Dictionary) -> bool:
	return _playing(k) and k["life_at"] == other

func _friends() -> void:
	var home = (await _home(["Pip", "Ash"]))["home"]
	var pip: Dictionary = home.kins[0]
	var ash: Dictionary = home.kins[1]
	var a: Dictionary = pip["rec"]
	var b: Dictionary = ash["rec"]
	_befriend(a, b, 0.6)
	var bond0 := BaseLife.bond(a, b)
	var speed0 := int(a["stats"].get("speed", 0))
	var lines0 := (a.get("journal", []) as Array).size()
	var t := 0.0
	var began := -1.0
	var length := -1.0
	var same_island := true
	while t < MINUTES * 60.0 and length < 0.0:
		home._move_kin(DT)
		t += DT
		if _playing(pip) and _playing(ash):
			if began < 0.0:
				began = t
			same_island = same_island and home.world.island_of(pip["pos"].x, pip["pos"].z) \
				== home.world.island_of(ash["pos"].x, ash["pos"].z)
		elif began >= 0.0:
			length = t - began
	ok(began >= 0.0, "two friends start tag within %.0f min (at %.0f s)" % [MINUTES, began])
	ok(length >= SHORTEST and length <= LONGEST, "the game lasts 10-20 s (%.1f s)" % length)
	ok(same_island, "both stay on the same ground")
	ok(BaseLife.bond(a, b) > bond0 and BaseLife.bond(a, b) == BaseLife.bond(b, a),
		"the pair's bond rises, both ways (%.2f -> %.2f)" % [bond0, BaseLife.bond(a, b)])
	ok(int(a["stats"].get("speed", 0)) > speed0 and int(b["stats"].get("speed", 0)) > 0, "each gains a little Speed")
	var lines: Array = a.get("journal", [])
	ok(lines.size() == lines0 + 1 and "tag" in CareJournal.text(lines.back()), "one journal line")
	ok(not _playing(pip) and not _playing(ash), "both are back to roaming")
	await _drop(home)

func _rival_never_plays() -> void:
	var home = (await _home(["Pip", "Ash", "Bo"]))["home"]
	var pip: Dictionary = home.kins[0]
	var ash: Dictionary = home.kins[1]
	var bo: Dictionary = home.kins[2]
	_befriend(pip["rec"], ash["rec"], 0.8)
	BaseLife.add_bond(pip["rec"], bo["rec"], -0.8)
	BaseLife.add_bond(ash["rec"], bo["rec"], -0.8)
	var games := 0
	var joined := false
	var t := 0.0
	while t < MINUTES * 60.0:
		home._move_kin(DT)
		t += DT
		games += 1 if _playing(pip) and _playing(ash) else 0
		joined = joined or _playing(bo) or _plays_with(pip, bo) or _plays_with(ash, bo)
	ok(games > 0, "the friends still play with a rival about (%d steps)" % games)
	ok(not joined, "a rival never plays tag with either friend")
	await _drop(home)

func _squabble() -> void:
	var home = (await _home(["Pip", "Ash", "Bo"]))["home"]
	var pip: Dictionary = home.kins[0]
	var ash: Dictionary = home.kins[1]
	var bo: Dictionary = home.kins[2]
	_befriend(pip["rec"], ash["rec"], 0.8)
	BaseLife.add_bond(pip["rec"], bo["rec"], -0.8)
	var bond := BaseLife.bond(pip["rec"], ash["rec"])
	var rival_bond := BaseLife.bond(pip["rec"], bo["rec"])
	var joy := Care.need(pip["rec"], "joy")
	BaseTag.start(home.life, pip, ash)
	ok(_playing(pip) and _playing(ash), "a game is on")
	bo["pos"] = pip["pos"] + Vector3(1.5, 0, 0)
	for i in 8:
		home._move_kin(DT)
	var states := BaseLife.NAMES
	ok(not _playing(pip) and not _playing(ash), "the rival's arrival ends the game")
	ok(Care.need(pip["rec"], "joy") < joy and Care.need(ash["rec"], "joy") < joy, "both sulk")
	ok(BaseLife.bond(pip["rec"], bo["rec"]) < rival_bond, "the bond to the rival drops")
	ok(BaseLife.bond(pip["rec"], ash["rec"]) == bond, "the pair's own bond does not move")
	ok(states.has((pip["life"] as Fsm).state_name()), "no state beyond the base life table")
	await _drop(home)
