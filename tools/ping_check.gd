extends RefCounted
## --ping-check: the ping key (PingInput), middle mouse by default.
##   1. keys: middle mouse is on "ping" (rebindable), G alone on the Boki key; old saved bindings with
##      middle mouse on the Boki key move it to ping
##   2. in the world: pointing at an enemy hunter gives a red "Enemy" ping, at loot a "Loot" ping, at bare
##      ground a plain spot under the cursor; a bot teammate gets each one as its ping goal; the ping key
##      itself (through Match._gather_input) places one; a ping from the net keeps its kind
##   3. the drop: on the planning map a ping lands on the map point; dropping, it lands on the ground
##      under the cursor, and the bot teammate takes it
## Never touches the save.

var bad := 0
var m: Match
var main: Node

func ok(cond: bool, what: String) -> void:
	print("PING %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	_keys()
	_migration()
	await _world()
	await _drop()
	print("PING CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _has_mouse(action: String, b: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == b:
			return true
	return false

# ------------------------------------------------------------------ 1. keys
func _keys() -> void:
	ok(_has_mouse("ping", MOUSE_BUTTON_MIDDLE), "middle mouse pings")
	ok(not _has_mouse("throw", MOUSE_BUTTON_MIDDLE) and Settings.key_cap("throw") == "G", "G alone sends the Boki")
	ok(Settings.ACTIONS.any(func(a): return a[0] == "ping"), "ping is in the rebindable list")

func _migration() -> void:
	var g := "key:%d" % KEY_G
	var mmb := "mouse:%d" % MOUSE_BUTTON_MIDDLE
	var steps := {"keys2_v": 1, "keys3_v": 1, "keys4_v": 1}
	var both := {"keys": {"throw": [g, mmb]}}
	both.merge(steps)
	KeyMigrate.run(both)
	ok(both["keys"]["throw"] == [g] and not both["keys"].has("ping"), "saved [G, MMB] on throw: G stays, MMB pings")
	var only := {"keys": {"throw": [mmb]}}
	only.merge(steps)
	KeyMigrate.run(only)
	ok(not only["keys"].has("throw"), "saved MMB alone on throw: throw goes back to G")
	var taken := {"keys": {"emote": [mmb]}}
	taken.merge(steps)
	KeyMigrate.run(taken)
	ok(taken["keys"]["ping"] == [] and taken["keys"]["emote"] == [mmb],
		"MMB custom-bound elsewhere: ping starts unbound")
	var twice := both.duplicate(true)
	KeyMigrate.run(twice)
	ok(twice == both and int(both["keys5_v"]) == 1, "the step runs once")

# ------------------------------------------------------------------ 2. the world
func _start(extra: Dictionary) -> void:
	if m:
		m.queue_free()
		await main.get_tree().process_frame
	m = Match.new()
	main.add_child(m)
	var o := {"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242}
	o.merge(extra, true)
	await m.start(o)
	m.set_process(false)

func _mate() -> Hunter:
	for h in m.hunters:
		if h != m.player and h.team == m.player.team and h.ctrl == "bot":
			return h
	return null

func _my_ping() -> Dictionary:
	return m.my_ping()

func _screen(at: Vector3) -> Vector2:
	return m.cam.unproject_position(at)

func _world() -> void:
	await _start({"no_drop": true})
	var P := m.player
	var mate := _mate()
	ok(mate != null, "a bot teammate")
	var foe: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	for h in m.hunters:
		if h.team != P.team:
			h.ctrl = "idle"      # (the bot teammate stays a bot: only bots take squad pings as goals)
	var spot := m.world.free_spot_near(P.pos + Vector3(5, 0, 0), [], 1.0, 0.5, 8.0)
	foe.teleport(spot)
	foe.unseen = false
	foe.visible = true
	m.cam.snap(P.pos)
	var kind := PingInput.place_world(m, _screen(foe.pos + Vector3(0, 0.9, 0)))
	var pg := _my_ping()
	ok(kind == "enemy" and pg.get("kind") == "enemy", "on an enemy: an enemy ping (%s)" % kind)
	ok((pg["col"] as Color).is_equal_approx(PingInput.ENEMY_COL), "it is red")
	ok(PingInput.label(pg, P) == "Enemy", "one word over it: %s" % PingInput.label(pg, P))
	ok(_goal_is(mate, pg), "the bot teammate takes it as its ping goal")
	# loot: a deathbox, its owner moved away
	var box := Life.drop_box(m, foe, "test")
	foe.teleport(m.world.free_spot_near(P.pos + Vector3(-30, 0, -30), [], 1.0, 0.5, 20.0))
	kind = PingInput.place_world(m, _screen(box["pos"] + Vector3(0, 0.5, 0)))
	pg = _my_ping()
	ok(kind == "loot" and PingInput.label(pg, P) == "Loot", "on a deathbox: a loot ping (%s)" % kind)
	ok(Vector2(pg["pos"].x, pg["pos"].z).distance_to(Vector2(box["pos"].x, box["pos"].z)) < 0.1, "on the box")
	# bare ground, away from anything
	_clear_near(P.pos + Vector3(0, 0, 6))
	var ground: Vector3 = P.pos + Vector3(0, 0, 6)
	ground.y = m.world.ground_at(ground.x, ground.z)
	kind = PingInput.place_world(m, _screen(ground))
	pg = _my_ping()
	var off := Vector2(pg["pos"].x - ground.x, pg["pos"].z - ground.z).length()
	ok(kind == "spot" and pg.get("kind") == "", "on the ground: a plain spot (%s)" % kind)
	ok(off < 0.6, "under the cursor (%.2f m off)" % off)
	ok(PingInput.label(pg, P) == "Your ping" and _goal_is(mate, pg), "your own spot, and the bot takes it")
	# the key itself
	m.unping(P, true)
	Input.action_press("ping")
	m._gather_input()
	Input.action_release("ping")
	ok(not _my_ping().is_empty(), "the ping key places a ping")
	# a ping from the net keeps its kind
	m.squad_ping(mate, P.pos, true, "loot")
	var theirs: Array = m.pings.filter(func(q): return q.get("by") == mate)
	ok(theirs.size() == 1 and theirs[0]["kind"] == "loot", "a ping from the net keeps its kind")

## Wpicks, boxes, chests and crates near `at` move far off, so a plain ground ping is not taken for loot.
func _clear_near(at: Vector3) -> void:
	for list in [m.wpicks, m.boxes, m.chests, m.breaks]:
		for e in list:
			if Vector2(e["pos"].x - at.x, e["pos"].z - at.z).length() < 6.0:
				e["pos"] = e["pos"] + Vector3(500, 0, 500)

func _goal_is(b: Hunter, pg: Dictionary) -> bool:
	var goal: Dictionary = b.ai.get("ping_goal", {})
	return not goal.is_empty() and (goal["pos"] as Vector3).distance_to(pg["pos"]) < 0.01

# ------------------------------------------------------------------ 3. the drop
func _drop() -> void:
	await _start({})
	var P := m.player
	var mate := _mate()
	for i in 3:
		m.step(Match.DT)
		await main.get_tree().process_frame
	ok(m.skydrop != null and m.skydrop.planning and m.hud.map_open(), "planning: the map is up")
	var fm: FullMap = m.hud.full_map
	if fm.rect.size.x < 10.0:
		fm.rect = Rect2(Vector2(340, 76), Vector2(600, 600))      # (no frame drawn yet: the layout it would have)
	var at := fm.rect.get_center() + Vector2(40, -30)
	var want := fm.to_world(at)
	PingInput.place_map(m, at)
	var pg := _my_ping()
	ok(not pg.is_empty() and Vector2(pg["pos"].x - want.x, pg["pos"].z - want.z).length() < 0.5,
		"on the map: the ping lands on the map point")
	PingInput.place_map(m, fm.rect.position - Vector2(30, 30))
	ok(_my_ping() == pg, "off the map: nothing moves")
	m.skydrop.planning = false
	m.ship_jump(P, true)
	for i in 30:
		m.step(Match.DT)
	ok(P.dropping, "dropping")
	m.cam.snap(P.pos)
	var sp := m.cam.unproject_position(P.pos)
	var kind := PingInput.place_world(m, sp + Vector2(60, 40))
	pg = _my_ping()
	ok(kind == "spot" and not pg.is_empty(), "dropping: a ping under the cursor (%s)" % kind)
	var gy := m.world.ground_at(pg["pos"].x, pg["pos"].z)
	ok(m.world.is_void(pg["pos"].x, pg["pos"].z) or absf(pg["pos"].y - gy) < 0.01, "on the ground, not in the air")
	ok(mate == null or _goal_is(mate, pg), "the bot teammate takes the landing spot")
	m.queue_free()
