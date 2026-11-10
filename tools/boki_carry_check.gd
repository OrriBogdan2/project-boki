extends RefCounted
## --boki-carry-check: the interact key lifts a Boki at home, you carry it 5 m, and the next press sets it down
## on open ground. It answers by its traits, its trust moves once per cooldown (and not for a sulker), a set-down
## is never inside a wall or off the island, and nothing in the save changes but trust. Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BOKICARRY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _new_save() -> void:
	var d := Save.fresh()
	var first := Save.new_kin("zapple", "Pip")
	first["starter"] = true
	d["roster"].append(first)
	d["active"] = first["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(d)

func _tick(home, secs: float, dt := 0.1) -> void:
	for i in int(round(secs / dt)):
		home._move_kin(dt)

func _calm(home, k: Dictionary) -> void:
	for n in Care.NEEDS:
		k["rec"]["needs"][n] = 80.0
	k["rec"]["needs_t"] = Time.get_unix_time_from_system() + 9999.0
	home.interact = {}

func _stand(home, p: Vector3, face: float) -> void:
	home.ppos = Vector3(p.x, 0.0, p.z)
	home.py = home.world.ground_at(p.x, p.z)
	home.pface = face
	home.player.position = home.ppos + Vector3(0, home.py, 0)

## Ground a Boki can stand on: not void, not a wall tile.
func _open(world: World, p: Vector3) -> bool:
	var i := world.idx(int(floor(p.x)), int(floor(p.z)))
	return world.kind[i] == World.T_GROUND and not world.is_void(p.x, p.z) and not world.is_block(p.x, p.z)

func _without_trust(d: Dictionary) -> String:
	var c: Dictionary = d.duplicate(true)
	for r in c["roster"]:
		r["trust"] = 0.0
		r["traits"] = {}     # this check sets traits itself, and _calm re-stamps needs_t
		r["needs_t"] = 0.0
	return var_to_str(c)

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_new_save()
	var home = await main._hb_home()
	var world: World = home.world
	var k: Dictionary = home.kins[0]
	var rec: Dictionary = k["rec"]
	var carry: KinCarry = home.carry
	_calm(home, k)
	rec["traits"] = {"bravery": 0.5, "temper": 0.3, "curiosity": 0.5, "loyalty": 0.3}
	rec["trust"] = 20.0
	_stand(home, k["pos"] + Vector3(1.0, 0, 0), PI / 2.0)
	var before := _without_trust(Save.d)
	ok(KinCarry.mood_of(rec) == "wiggle", "a curious, even-tempered Boki wiggles (%s)" % KinCarry.mood_of(rec))
	ok(KinWants.action(rec, false) == "lift" and KinWants.line(rec, true).begins_with("Lift"),
		"with nothing wanted the interact key lifts it (\"%s\")" % KinWants.line(rec, true))
	# ------------------------------------------------ lift
	home._kin_act(k)
	ok(carry.state == KinCarry.S.LIFT and k["busy"] and carry.pose() == "lift", "pressing interact starts the lift")
	ok(rec["trust"] > 20.0 and absf(rec["trust"] - 20.6) < 0.001,
		"a gentle Boki trusts you a little more (%.2f)" % rec["trust"])
	_tick(home, 0.6)
	ok(carry.state == KinCarry.S.CARRIED and carry.pose() == "carry", "then it is carried")
	ok(String(k["node"].get_meta("kstate", "")) == "carried", "its rig is told it is carried")
	home._find_interact()
	ok(home.interact.get("kind", "") == "set_down", "while carried the interact key means set down")
	ok(home._label_for(home.interact).begins_with("Set "),
		"and the prompt says so (\"%s\")" % home._label_for(home.interact))
	# ------------------------------------------------ carry 5 m
	var start: Vector3 = home.ppos
	var dir := Vector3(0, 0, 1)
	for dirc in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var good := true
		for s in range(1, 13):
			var q: Vector3 = start + dirc * 0.5 * s
			if world.is_void(q.x, q.z) or world.is_block(q.x, q.z):
				good = false
				break
		if good:
			dir = dirc
			break
	var moved := 0.0
	for i in 25:
		var nxt: Vector3 = home.ppos + dir * 0.2
		_stand(home, nxt, atan2(-dir.x, -dir.z))
		moved += 0.2
		home._move_kin(0.1)
	var held: Vector3 = k["node"].position
	var want_at: Vector3 = Vector3(home.ppos.x, home.py + KinCarry.HOLD_UP, home.ppos.z)
	ok(moved >= 4.99 and home.ppos.distance_to(start) >= 4.99, "carried %.1f m" % home.ppos.distance_to(start))
	var off := Vector2(held.x - want_at.x, held.z - want_at.z).length()
	ok(off < KinCarry.HOLD_FWD + 0.05 and absf(held.y - want_at.y) < 0.05, "the Boki rode with you the whole way")
	ok(Vector2(k["pos"].x - home.ppos.x, k["pos"].z - home.ppos.z).length() < 0.05,
		"and the farm thinks it is where you are")
	# ------------------------------------------------ set down
	home._use(home.interact)
	ok(carry.state == KinCarry.S.SET and carry.pose() == "set", "pressing again starts the set-down")
	_tick(home, 0.6)
	ok(carry.state == KinCarry.S.FREE and not k["busy"] and carry.pose() == "", "and it is free again")
	var sp: Vector3 = k["pos"]
	ok(Vector2(sp.x - home.ppos.x, sp.z - home.ppos.z).length() < 2.5,
		"set down beside you (%.1f m)" % Vector2(sp.x - home.ppos.x, sp.z - home.ppos.z).length())
	ok(_open(world, sp), "on open ground")
	ok(k["node"].position.distance_to(sp) < 0.05 and String(k["node"].get_meta("kstate", "")) == "",
		"its node is on the ground and out of the carried pose")
	ok(float(k.get("joy_t", 0.0)) > 0.0, "it answers with a happy bounce")
	# ------------------------------------------------ trust once per cooldown
	var t1: float = rec["trust"]
	_tick(home, 2.0)
	home._kin_act(k)
	_tick(home, 1.0)
	ok(carry.state == KinCarry.S.CARRIED and rec["trust"] == t1,
		"a second lift inside the cooldown leaves trust alone (%.2f)" % rec["trust"])
	home._use({"kind": "set_down"})
	_tick(home, 0.6)
	_tick(home, KinCarry.COOLDOWN, 1.0)
	home._kin_act(k)
	ok(absf(rec["trust"] - (t1 + KinCarry.TRUST_STEP)) < 0.001,
		"after the cooldown it nudges once more (%.2f)" % rec["trust"])
	_tick(home, 0.6)
	home._use({"kind": "set_down"})
	_tick(home, 0.6)
	# a sulker gets no nudge
	rec["traits"] = {"bravery": 0.5, "temper": 0.95, "curiosity": 0.2, "loyalty": 0.1}
	rec["trust"] = 10.0
	_tick(home, KinCarry.COOLDOWN + 2.0, 1.0)
	_calm(home, k)
	_stand(home, k["pos"] + Vector3(1.0, 0, 0), PI / 2.0)
	home._kin_act(k)
	ok(KinCarry.mood_of(rec) == "sulk" and rec["trust"] == 10.0,
		"a hot-tempered Boki that doesn't know you sulks and trust stays put")
	_tick(home, 0.6)
	home._use({"kind": "set_down"})
	_tick(home, 0.6)
	ok(float(k.get("hold_t", 0.0)) > 0.0 and k["busy"] == false, "the sulker stands apart a moment, then carries on")
	# ------------------------------------------------ never inside a wall
	var found := false
	var wallbad := 0
	var tried := 0
	var cells: Array = []
	var isle := world.island_of(home.ppos.x, home.ppos.z)
	for z in range(1, world.h - 1):
		for x in range(1, world.w - 1):
			if world.island[world.idx(x, z)] == isle and world.kind[world.idx(x, z)] == World.T_GROUND:
				for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if world.kind[world.idx(x + dd.x, z + dd.y)] == World.T_BLOCK:
						cells.append([x, z, dd])
	var stride := maxi(1, cells.size() / 40)
	for i in range(0, cells.size(), stride):
		var c: Array = cells[i]
		var dd: Vector2i = c[2]
		_calm(home, k)
		_stand(home, Vector3(c[0] + 0.5 + dd.x * 0.3, 0, c[1] + 0.5 + dd.y * 0.3), atan2(-dd.x, -dd.y))
		k["pos"] = home.ppos + Vector3(-dd.x * 1.5, 0, -dd.y * 1.5)
		k["node"].position = k["pos"]
		if not carry.lift(home, k):
			continue
		found = true
		_tick(home, 0.6)
		carry.set_down(home)
		_tick(home, 0.6)
		var q: Vector3 = k["pos"]
		tried += 1
		if not _open(world, q) or world.occupy(q.x, q.z, 0.3, q.y, false) != 0.0 or world.island_of(q.x, q.z) != isle:
			wallbad += 1
	ok(found and tried >= 10 and wallbad == 0,
		"set down facing a wall %d times: never inside it, never off the island (%d bad)" % [tried, wallbad])
	# ------------------------------------------------ the machine and the save
	ok(carry.refused == 0, "the state machine turned down no change (%d)" % carry.refused)
	var after := _without_trust(Save.d)
	ok(after == before, "the save is unchanged but for trust")
	ok(not k.has("carry_ok") or not Save.d["roster"][0].has("carry_ok"), "the cooldown stamp is runtime only")
	home.queue_free()
	await main.get_tree().process_frame
	print("BOKICARRY DONE, failures: %d" % bad)
	main.get_tree().quit()
