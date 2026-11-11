extends RefCounted
## --garden-whistle-check (scripts/home/base_whistle.gd): on a base_mode farm, tapping the whistle brings your
## partner to you, holding it also brings the nearest other Boki, and trust and mood set how it answers: a
## trusting one reaches you within REACH_SECS on the farm's own steering (HomeBuild.steer, no rendering), a
## trusting one is quicker than a lukewarm one, a sulky one looks over and stays. In a match the whistle does
## nothing (match code never reads it). Never touches the real save.

const DT := 0.25              # s per farm step
const REACH_SECS := 6.0       # s a trusting Boki may take to reach you
const FAR := Vector3(22.0, 0.0, 8.0)      # m from the landing where the called Boki start
const CAST := ["zapple", "burrlet", "cindle"]

var bad := 0
var main: Node
var home

func ok(cond: bool, what: String) -> void:
	print("WHISTLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _save() -> void:
	FarmUnlocks.rules()["base_mode"] = true
	var d := Save.fresh()
	for i in CAST.size():
		var rec := Save.new_kin(CAST[i], "B%d" % i)
		Care.ensure(rec)
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	HomeLayout.new_fs(d, 5)
	Save.d = d

## Boki i stands `at` m from you with this trust and joy; the others wait far off.
func _stand(i: int, at: Vector3, trust: float, joy: float) -> Dictionary:
	var k: Dictionary = home.kins[i]
	k["pos"] = home.world.free_spot_near(HomeLayout.LANDING + at, [], 0.8)
	(k["node"] as Node3D).position = k["pos"]
	k["goal"] = k["pos"]
	k.erase("path")      # a moved Boki walks a fresh route
	k["rec"]["trust"] = trust
	k["rec"]["needs"]["joy"] = joy
	for n in ["food", "energy", "clean"]:
		k["rec"]["needs"][n] = 80.0
	k["nap_t"] = 0.0
	return k

func _dist(k: Dictionary) -> float:
	return Vector2(k["pos"].x - home.ppos.x, k["pos"].z - home.ppos.z).length()

## Steps the farm; the time (s) till Boki k is within 1.8 m of you, or INF.
func _until_close(k: Dictionary, secs: float) -> float:
	var t := 0.0
	while t < secs:
		for o in home.kins:
			o["t"] = 1e9      # nobody wanders off by itself
		home._move_kin(DT)
		t += DT
		if _dist(k) < 1.8:
			return t
	return INF

func _reset() -> void:
	home.ppos = HomeLayout.LANDING + Vector3(0, 0, 1.0)
	home.player.position = home.ppos
	home.day_t = 0.5
	for i in home.kins.size():
		var k: Dictionary = home.kins[i]
		for key in ["called_t", "call_slot", "call_pace", "hold_t"]:
			k.erase(key)
		_stand(i, Vector3(-14.0 - 3.0 * i, 0, 8.0), 90.0, 80.0)

func _partner_run(trust: float, joy: float) -> float:
	_reset()
	var k := _stand(0, FAR, trust, joy)
	var isle: int = home.world.island_of(home.ppos.x, home.ppos.z)
	ok(home.world.island_of(k["pos"].x, k["pos"].z) == isle, "the partner starts on your island")
	var from := _dist(k)
	home.life.whistle.press()
	home.life.whistle.release()
	var t := _until_close(k, REACH_SECS + 4.0)
	print("WHISTLE   %.0f m away, trust %.0f, joy %.0f: arrives in %.2f s" % [from, trust, joy, t])
	return t

func _sulky_run(trust: float, joy: float, what: String) -> void:
	_reset()
	var k := _stand(0, FAR, trust, joy)
	var start: Vector3 = k["pos"]
	home.life.whistle.press()
	home.life.whistle.release()
	ok(not k.has("called_t") and float(k.get("hold_t", 0.0)) > 0.0, "%s looks over and does not run" % what)
	_until_close(k, REACH_SECS)
	var moved := Vector2(k["pos"].x - start.x, k["pos"].z - start.z).length()
	ok(moved < 0.5 and _dist(k) > 4.0, "%s stays put for %.0f s" % [what, REACH_SECS])

func _hold_run() -> void:
	_reset()
	var partner := _stand(0, FAR, 90.0, 80.0)
	var near := _stand(1, Vector3(8.0, 0, 3.0), 90.0, 80.0)
	var far := _stand(2, Vector3(-14.0, 0, 9.0), 90.0, 80.0)
	home.life.whistle.press()
	home._move_kin(DT)
	ok(partner.has("called_t") and not near.has("called_t"), "a tap calls the partner only")
	home.life.whistle.step(0.5)
	ok(near.has("called_t") and not far.has("called_t"), "holding calls the nearest other Boki, not the farther one")
	home.life.whistle.release()
	ok(_until_close(near, REACH_SECS) < INF, "the nearest Boki reaches you")

func _in_a_match() -> void:
	var old: Node = home
	home.queue_free()
	await main.get_tree().process_frame
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true, "arch": "thief",
		"cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	var before: Vector3 = m.player.pos
	var ev := InputEventAction.new()
	ev.action = "whistle"
	ev.pressed = true
	Input.parse_input_event(ev)
	await main.get_tree().process_frame
	ok(not is_instance_valid(old) or old.is_queued_for_deletion(), "no farm exists in a match for the whistle to call")
	ok(m.player.pos == before, "the whistle moves nothing in a match")
	var reads := 0
	for f in DirAccess.get_files_at("res://scripts/match"):
		if f.ends_with(".gd") and FileAccess.get_file_as_string("res://scripts/match/" + f).contains("\"whistle\""):
			reads += 1
	ok(reads == 0, "no match script reads the whistle action")
	m.queue_free()

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(5)
	_save()
	home = await main._hb_home()
	ok(home.life != null and home.kins.size() == CAST.size(), "%d Boki on a base_mode farm" % home.kins.size())
	var trusted := _partner_run(90.0, 80.0)
	ok(trusted <= REACH_SECS, "a trusting, happy partner reaches you in %.2f s (limit %.0f s)" % [trusted, REACH_SECS])
	var lukewarm := _partner_run(35.0, 45.0)
	ok(lukewarm < INF and lukewarm > trusted, "a lukewarm partner still comes, slower (%.2f s)" % lukewarm)
	_sulky_run(90.0, 10.0, "a sulky partner (joy low)")
	_sulky_run(10.0, 80.0, "a partner that does not trust you yet")
	_hold_run()
	await _in_a_match()
	FarmUnlocks.rules()["base_mode"] = false
	await main.get_tree().process_frame
	print("WHISTLE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
