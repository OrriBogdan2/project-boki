extends RefCounted
## --pet-block-check: a Boki standing between you and a boulder never steals the interact key.
##   1. the Boki in front of the boulder, interact pressed: the boulder is the target, it gets mined, no petting
##   2. while the pickaxe swings the Boki steps out of the way between you and the boulder
##   3. with no work in reach the same press still pets it
## --pet-block-shots --shots-dir=<dir>: the same scene played live, every frame saved to <dir>/frames (needs a GPU).
## Never touches the real save.

const STEP := 0.05            # s: one simulated frame
const WORK_SECONDS := 8.0     # s: more than three swings
const IN_FRONT := 0.15        # m: the Boki stands this far from you, towards the boulder (its body overlaps you)
const OFF_LANE := 0.1         # m: and this far to the side of the straight line
const FILM_AHEAD := 0.55      # m: in the clip it stands clear of your body, so it shows (still nearer than the boulder)
const FILM_SIDE := 0.35

var bad := 0
var main: Node
var home = null
var frames := 0
var frames_dir := ""

func ok(cond: bool, what: String) -> void:
	print("PETBLOCK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node, mode := "check") -> void:
	main = m
	Save.no_write = true
	await _new_home()
	var pet: Dictionary = home.kins[0]
	var rock := _rock_to_mine(pet)
	ok(rock >= 0, "there is a boulder to mine")
	if rock >= 0:
		if mode == "shots":
			await _mine_live(rock, pet)
		else:
			_mine(rock, pet)
			_pet_without_work(pet)
	print("PETBLOCK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _new_home() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["level"] = 5
	k["starter"] = true
	Care.ensure(k)
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	Save.d = d
	HomeLayout.ensure(d)
	home = await main._hb_home()
	home._close_panel()
	home.talk_cd = 1.0e9
	HomeGather.give_tool("pickaxe")

func _put(k: Dictionary, at: Vector3) -> void:
	k["pos"] = at
	k["goal"] = at
	k["t"] = 999.0
	(k["node"] as Node3D).position = at

func _stand(at: Vector3) -> void:
	home.ppos = at
	home.player.position = at

## A boulder the player can stand beside and reach with nothing else in the way (the Boki far off),
## where the Boki has open ground to step aside onto.
func _rock_to_mine(pet: Dictionary) -> int:
	_put(pet, HomeLayout.LANDING + Vector3(30, 0, 30))
	for i in home.hb.wild_t:
		if home.hb.wild_t[i] != "rock":
			continue
		var b: Vector3 = home.hg.beside(i, HomeLayout.LANDING)
		if b == Vector3.INF:
			continue
		_stand(b)
		home._find_interact()
		if int(home.interact.get("i", -1)) == i and _room_to_side(i):
			return i
	return -1

## Open ground from the Boki's spot out to where it steps aside (not a nook against a wall or another rock).
func _room_to_side(rock: int) -> bool:
	for side in [OFF_LANE, OFF_LANE + 0.6, OFF_LANE + 1.2]:
		var at := _in_front(rock, IN_FRONT, side)
		if home.world.occupy(at.x, at.z, 0.3, 0.0, true) != 0.0 or home.world.is_void(at.x, at.z):
			return false
	return true

func _rock_center(i: int) -> Vector3:
	var w: World = home.world
	return Vector3(i % w.w + 0.5, 0, i / w.w + 0.5)

## The Boki in front of you, between you and the boulder.
func _block(rock: int, pet: Dictionary, ahead := IN_FRONT, side := OFF_LANE) -> void:
	_put(pet, _in_front(rock, ahead, side))
	pet["hold_t"] = 0.0
	pet.erase("joy_t")

func _in_front(rock: int, ahead: float, side: float) -> Vector3:
	var to_rock: Vector3 = (_rock_center(rock) - home.ppos).normalized()
	return home.ppos + to_rock * ahead + Vector3(-to_rock.z, 0, to_rock.x) * side

func _lane_gap(rock: int, pet: Dictionary) -> float:
	var p2 := Vector2(home.ppos.x, home.ppos.z)
	var c := _rock_center(rock)
	var a := Vector2(pet["pos"].x, pet["pos"].z)
	return a.distance_to(Geometry2D.get_closest_point_to_segment(a, p2, Vector2(c.x, c.z)))

func _mine(rock: int, pet: Dictionary) -> void:
	_block(rock, pet)
	pet["rec"]["needs"]["joy"] = 50.0
	var needs0: Dictionary = pet["rec"]["needs"].duplicate()
	var stone0 := Work.mat("stone")
	home._find_interact()
	var got: String = home.interact.get("kind", "")
	ok(got == "wild" and int(home.interact.get("i", -1)) == rock,
			"the Boki %.2f m away in front: interact targets the boulder (got %s)" % [IN_FRONT, got])
	home.tw.test_hold = true
	home._use(home.interact)
	ok(home.hg.busy() and home.tw.tool == "pickaxe", "the press swings the pickaxe")
	var gap := INF
	for s in int(WORK_SECONDS / STEP):
		home._separate_kin(STEP)
		home.hg.tick(STEP)
		if s == int(1.0 / STEP):
			gap = _lane_gap(rock, pet)
		if not home.hg.busy():
			break
	home.tw.test_hold = false
	ok(not home.hb.wild_t.has(rock) and Work.mat("stone") > stone0,
			"the boulder was mined: +%d stone" % (Work.mat("stone") - stone0))
	ok(float(pet.get("hold_t", 0.0)) == 0.0 and not pet.has("joy_t") and pet["rec"]["needs"] == needs0,
			"no petting or care happened (needs %s)" % str(pet["rec"]["needs"]))
	ok(gap >= home._kin_r(pet) + home.WORK_CLEAR - 0.05,
			"a second in, the Boki is out of the swing: %.2f m from the line to the boulder" % gap)

func _pet_without_work(pet: Dictionary) -> void:
	var spot := _open_ground(pet)
	ok(spot != Vector3.INF, "there is open ground with no work in reach")
	if spot == Vector3.INF:
		return
	_stand(spot)
	_put(pet, spot + Vector3(0.5, 0, 0))
	home._find_interact()
	var got: String = home.interact.get("kind", "")
	ok(got == "kin", "no work in reach: interact targets the Boki (got %s)" % got)
	home._use(home.interact)
	ok(float(pet.get("hold_t", 0.0)) > 0.0, "and the press pets it")

## A spot near the landing where interact finds nothing while the Boki is away.
func _open_ground(pet: Dictionary) -> Vector3:
	_put(pet, HomeLayout.LANDING + Vector3(30, 0, 30))
	for r in range(2, 12):
		for a in 8:
			var p: Vector3 = HomeLayout.LANDING + Vector3.FORWARD.rotated(Vector3.UP, a * TAU / 8.0) * r
			if home.world.occupy(p.x, p.z, 0.4, 0.0, true) != 0.0:
				continue
			_stand(p)
			home._find_interact()
			if home.interact.is_empty():
				return p
	return Vector3.INF

## Live, for the clip: the Boki in front of the boulder, you press, it gets mined, the Boki makes room.
func _mine_live(rock: int, pet: Dictionary) -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			frames_dir = String(a).substr(12) + "/frames"
	DirAccess.make_dir_recursive_absolute(frames_dir)
	var start := Time.get_ticks_msec()
	var c := _rock_center(rock)
	Settings.set_v("cam_style", "low", false)
	home.cam.zoom_to = 0.45
	home.cam.zoom = 0.45
	home.cam.snap(home.ppos.lerp(c, 0.5))
	if main.fade:
		main.fade.reveal(0.05)
	_block(rock, pet, FILM_AHEAD, FILM_SIDE)
	await _film(1.2)
	_block(rock, pet, FILM_AHEAD, FILM_SIDE)
	home._find_interact()
	ok(home.interact.get("kind") == "wild", "live: interact targets the boulder")
	home.tw.test_hold = true
	home._use(home.interact)
	var t0 := Time.get_ticks_msec()
	while home.hg.busy() and Time.get_ticks_msec() - t0 < WORK_SECONDS * 1000.0:
		await _film(0.0)
	home.tw.test_hold = false
	ok(not home.hb.wild_t.has(rock) and float(pet.get("hold_t", 0.0)) == 0.0, "live: mined, no petting")
	await _film(1.5)
	print("PETBLOCK %d frames in %.2f s" % [frames, (Time.get_ticks_msec() - start) / 1000.0])

## Plays on for `seconds` (at least one frame), saving every frame.
func _film(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while true:
		await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_jpg("%s/%05d.jpg" % [frames_dir, frames], 0.9)
		frames += 1
		if Time.get_ticks_msec() - t0 >= seconds * 1000.0:
			return
