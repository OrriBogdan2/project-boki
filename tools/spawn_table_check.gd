extends RefCounted
## --spawn-table-check: nothing spawns by dice (docs/design/CLARITY_PASS.md). Two seeds of the same
## map give the same camps, Shrublings, wild and rare Boki, Wardens, boss lair and burrow schedule; a
## nest is telegraphed (ring, minimap warning, countdown) before its pack claws out, exactly on time,
## at its fixed place; and a cleared rolling camp is telegraphed before it comes back. Never touches
## the save.

const SNAP := Vector3(0.1, 0.1, 0.1)
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SPAWNTABLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _match(main: Node, seed_v: int, extra := {}) -> Match:
	var m := Match.new()
	main.add_child(m)
	var o := {"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": seed_v, "no_drop": true, "raid": "clear"}
	o.merge(extra, true)
	m.start(o)
	m.set_process(false)
	return m

## What the map spawns at the start, as comparable lists: monsters, wild Boki, live spawn points, schedule.
func _snapshot(m: Match) -> Array:
	var mobs := m.mobs.filter(func(x): return not x is Shrubling)
	var wild := m.kins.filter(func(k): return k.is_wild())
	return [
		mobs.map(func(x): return "%s@%s" % [x.mkind, str(x.pos.snapped(SNAP))]),
		wild.map(func(k): return "%s L%d@%s" % [k.species, int(k.rec.get("level", 0)), str(k.home.snapped(SNAP))]),
		m.spawn_plan.active_ids() if m.spawn_plan else [],
		m.spawn_table.schedule(900.0),
	]

func _odd(a: Array, b: Array) -> Array:
	return a.filter(func(x): return not b.has(x)) + b.filter(func(x): return not a.has(x))

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var a := _match(main, 8101)
	var b := _match(main, 8102)
	var sa := _snapshot(a)
	var sb := _snapshot(b)
	ok(not a.spawn_table.rows.is_empty(), "the map has burrow nests (%d)" % a.spawn_table.rows.size())
	var odd := _odd(sa[0], sb[0])
	ok(odd.is_empty(), "the same monsters in the same places for two seeds (%d, odd: %s)" % [sa[0].size(), str(odd)])
	odd = _odd(sa[1], sb[1])
	ok(odd.is_empty(), "the same wild and rare Boki, level and place (%d, odd: %s)" % [sa[1].size(), str(odd)])
	ok(sa[2] == sb[2], "the same boss lair, vaults and caches are live")
	ok(sa[3] == sb[3] and not sa[3].is_empty(), "the same burrow schedule (%d spawns in 15 min)" % sa[3].size())
	var shr_a := a.mobs.filter(func(x): return x is Shrubling).map(func(x): return str(x.pos.snapped(SNAP)))
	var shr_b := b.mobs.filter(func(x): return x is Shrubling).map(func(x): return str(x.pos.snapped(SNAP)))
	ok(shr_a == shr_b and not shr_a.is_empty(), "the same %d Shrublings hide in the same grass" % shr_a.size())
	ok(float(sa[3][0][0]) >= 60.0, "the first nest turn is %ds in: nothing claws out on landing" % int(sa[3][0][0]))
	b.queue_free()
	_telegraph(a)
	_camp_telegraph(main)
	print("SPAWNTABLE DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _run(m: Match, secs: float) -> void:
	for i in int(secs / Match.DT):
		m.step(Match.DT)

func _ring_at(m: Match, pos: Vector3) -> Array:
	return m.spawn_table.warning().filter(func(w): return w["pos"] == pos)

## One nest: a ring and a countdown for tele seconds, then its pack exactly at due time.
func _telegraph(m: Match) -> void:
	var T: SpawnTable = m.spawn_table
	var B: BlightDir = m.blight
	for o in m.hunters:
		o.ctrl = "idle"
	var row: Dictionary = T.rows[0]
	var tele: float = float(SpawnTable.rules()["burrow"]["tele"])
	for mb in m.mobs:
		if mb is Blight and mb.mkind == "bl_skitter":
			mb.burrow()
	m.player.teleport(m.world.free_spot_near(row["pos"] + Vector3(14, 0, 0), [], 1.0, 0.5, 8.0))
	m.time = SpawnTable.due_at(row, 0) - tele - 2.0 - m.sess_t0      # (the clock jumps to just before the ring)
	_run(m, 1.0)
	ok(_ring_at(m, row["pos"]).is_empty(), "no ring before the countdown")
	var n0 := B.spawned
	_run(m, 2.0)
	var warn := _ring_at(m, row["pos"])
	ok(warn.size() == 1 and float(warn[0]["left"]) <= tele, "the nest shows a countdown (%s)" % str(warn))
	ok(T.teles.has(String(row["id"])) and B.spawned == n0, "a ring is on the ground and nothing is out yet")
	_run(m, tele)
	ok(B.spawned - n0 >= int(row["n"]), "the pack claws out when the countdown ends (%d)" % (B.spawned - n0))
	var near := m.mobs.filter(func(x): return x is Blight and not x.dead and x.flat_dist(row["pos"]) < 8.0)
	ok(near.size() >= int(row["n"]), "... at the nest (%d within 8 tiles)" % near.size())
	ok(_ring_at(m, row["pos"]).is_empty(), "the ring is gone once it has spawned")
	m.queue_free()

## A rolling session's cleared camp: a ring for the last CAMP_TELE seconds, then the same monsters again.
func _camp_telegraph(main: Node) -> void:
	var m := _match(main, 8103, {"rolling": true})
	var R: Rolling = m.rolling
	var cp: Dictionary = R.camps[0]
	var far: Vector3 = m.world.spawns[0]
	for sp in m.world.spawns:
		if sp.distance_to(cp["pos"]) > far.distance_to(cp["pos"]):
			far = sp
	for h in m.hunters:
		h.ctrl = "idle"
		h.teleport(far)
	for mb in cp["mobs"]:
		mb.hp = 0.0
		mb.dead = true
		mb.visible = false
	cp["cleared_at"] = m.time
	m.time += Rolling.CAMP_RESPAWN - Rolling.CAMP_TELE + 1.0
	R._camp_respawns()
	var empty: bool = cp["mobs"].all(func(x): return x.dead)
	ok(_ring_at(m, cp["pos"]).size() == 1 and empty, "a cleared camp shows a ring before it returns, empty meanwhile")
	m.time += Rolling.CAMP_TELE
	R._camp_respawns()
	var back: Array = cp["mobs"].map(func(x): return x.mkind)
	var alive: bool = cp["mobs"].all(func(x): return not x.dead)
	ok(_ring_at(m, cp["pos"]).is_empty() and back == cp["comp"] and alive, "then the same monsters (%s)" % str(back))
	m.queue_free()
