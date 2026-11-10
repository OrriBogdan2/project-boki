extends RefCounted
## --first-hints-check: the one-time match hints in a real first expedition (MatchHints, FirstTimeHint,
## content/rules/hints.json). A fresh save lands in a match with bots; the check drives each moment (a ledge
## over the void, gear, a key, a skill point, 40 s of open ground, a jump into a tall wall, a fight, an
## outpost, the way out) and asserts
##   1. each hint shows once, within a second of its moment, and not before it
##   2. never in the first 2 s of a fight (a foe close or targeting you)
##   3. never more than one hint line on screen
##   4. after a save round-trip, a second expedition shows none of them again
## and prints a table: hint, trigger, result.

const MOMENT_S := 1.2         # s a hint may take to show after its moment starts
const SETTLE_S := 3.0         # s of quiet between moments (the last line leaves, the gap passes)
const FIGHT_M := 9.0          # m: a foe this close, or one targeting you, is a fight
const WALL_MOMENT_S := 2.0    # s: the jump up to the wall, then the hint's 0.3 s of hanging on it
const TAP_S := 0.1           # s the jump key is down
const OUTPOST_CLEAR_M := 25.0  # m the wall keeps from outposts (the outpost moments put the player there)
const WALL_UPS := 6           # terraces (0.8 m each): a wall too tall for the ledge rise from a jump's apex
const QUIET_TIME := 12.0      # s on the match clock for the moments that are not about time

var bad := 0
var main: Node
var m: Match
var p: Hunter
var shown: Array = []         # [{id, t (match time), fight_age (-1: no fight)}] in order of appearance
var max_on_screen := 0
var _pin := QUIET_TIME     # the match clock is held here (s) so the time hints wait for their moment; -1 lets it run
var _anchor := Vector3.INF      # the fight moment holds the player here (a knock could throw them off)
var _on: Array = []           # hint ids on screen last step
var _clock := 0.0         # s played (the match clock is pinned)
var _fight_t0 := -1.0
var _rows: Array = []

func ok(cond: bool, what: String) -> void:
	print("FHC %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	_expedition(true)
	_second_expedition()
	_table()
	print("FHC DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _start() -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 1, "tier": 0, "length": 1500.0, "seed": 7, "demo_kin": "cindle", "no_drop": true})
	m.set_process(false)
	p = m.player
	for i in 4000:      # the ship, the jump, the drop
		if p.riding and m.time > 1.0:
			m.ship_jump(p, true)
		_step()
		if not p.riding and not p.dropping and p.grounded:
			break
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	_clear_ground()
	shown.clear()
	max_on_screen = 0

func _clear_ground() -> void:
	for wp in m.wpicks:
		(wp["node"] as Node).queue_free()
	m.wpicks.clear()
	p.chest_keys = 0

## One match step: the player is kept alive, and what the HUD shows of the hints is logged.
func _step() -> void:
	p.hp = p.max_hp
	if _anchor != Vector3.INF and p.pos.distance_to(_anchor) > 0.5:
		p.teleport(_anchor)
		p.vel = Vector3.ZERO
	if _pin >= 0.0:
		m.time = _pin
	m.step(Match.DT)
	if m.hud:
		m.hud.msgs._process(Match.DT)      # the lane ages its lines as in play (the check steps the match by hand)
	_clock += Match.DT
	_log()

func _log() -> void:
	var lines: Array[String] = m.hud.msgs.texts() if m.hud else []
	var foe := m.mobs.any(func(mb): return not mb.dead and (p.flat_dist(mb) < FIGHT_M or mb.tgt == p))
	if not foe:
		_fight_t0 = -1.0
	elif _fight_t0 < 0.0:
		_fight_t0 = _clock
	var on: Array = []
	for id in FirstTimeHint.ids("match"):
		var line := FirstTimeHint.text(String(id))
		if lines.any(func(l): return l.contains(line)):
			on.append(id)
	if on.size() > max_on_screen:
		max_on_screen = maxi(max_on_screen, on.size())
	for id in on:
		if not id in _on:
			shown.append({"id": id, "t": _clock, "fight_age": _clock - _fight_t0 if _fight_t0 >= 0.0 else -1.0})
	_on = on

func _secs(s: float) -> void:
	for i in int(s / Match.DT):
		_step()

## Quiet between moments: nothing due, the lane empties.
func _settle() -> void:
	_clear_ground()
	_secs(SETTLE_S)
	m.hud.msgs.clear()

## Runs `setup`, then up to MOMENT_S of play. Returns the hint ids that showed, in order.
func _moment(setup: Callable, secs := MOMENT_S) -> Array:
	_settle()
	var n0 := shown.size()
	setup.call()
	_secs(secs)
	return shown.slice(n0).map(func(s): return s["id"])

func _expedition(first: bool) -> void:
	_pin = QUIET_TIME
	_start()
	_rows.clear()
	var quiet := _moment(func(): pass, 5.0)
	_check("start", "landed, nothing due", quiet, "")
	_check("exdash", "in the air over the void", _moment(_over_void), "exdash")
	_check("pickup", "gear 3 m away", _moment(_drop_gear), "pickup")
	_check("key", "a chest key picked up", _moment(func(): p.chest_keys = 1), "key")
	_check("rank", "a level-up skill point", _moment(func(): p.gain_xp(float(Hunter.XP_TO[1]))), "rank")
	_check("crouch", "match time 41 s on open ground", _moment(func(): _pin = 41.0), "crouch")
	_check("orders", "Boki sent 14 m out", _moment(_send_boki), "orders")
	var wall := _wall_moment(false)
	_check("wallkick", "jumped into a 6-terrace wall, no second press", wall, "wallkick")
	var again := _wall_moment(false)
	_check("wallkick-after", "same again: never twice", again, "")
	Save.d["tutorial"]["hints"].erase("wallkick")
	var own := _wall_moment(true)
	_check("wallkick-own", "it kicked off the wall itself: no hint", own, "")
	ok(FirstTimeHint.seen("wallkick"), "a kick on its own marks the hint seen")
	_check("utility", "foe close: nothing for 2 s, then the line", _fight(), "utility")
	_outposts()
	_check("goexit", "151 s, no outpost close", _moment(_far_from_outposts_late, 0.0), "goexit")
	_check("after", "everything seen: quiet", _moment(func(): pass, 5.0), "")
	var all: Array = FirstTimeHint.ids("match")
	ok(all.all(func(id): return FirstTimeHint.seen(String(id))), "every match hint is marked seen in the save")
	var ids: Array = shown.map(func(s): return s["id"])
	var early := shown.filter(func(h): return h["fight_age"] >= 0.0 and h["fight_age"] < 2.0)
	ok(early.is_empty(), "no hint in the first 2 s of a fight (%s)" % str(early.map(func(h): return h["id"])))
	ok(max_on_screen <= 1, "never more than one hint on screen (max %d)" % max_on_screen)
	ok(_unique(ids), "each hint showed once (%s)" % ",".join(ids))

func _unique(a: Array) -> bool:
	var seen := {}
	for x in a:
		if seen.has(x):
			return false
		seen[x] = true
	return true

## Compares what showed with `want` ("a,b" in order, "" for nothing) and notes a table row.
func _check(id: String, trigger: String, got: Array, want: String) -> void:
	var got_s := ",".join(got)
	var good := got_s == want
	ok(good, "%s: %s -> '%s' (want '%s')" % [id, trigger, got_s, want])
	var result := "MISS: got '%s'" % got_s
	if good:
		result = "shows once, at its moment" if want != "" else "quiet"
	_rows.append([id, trigger, result])

func _over_void() -> void:
	var w: World = m.world
	var found := Vector3.INF
	for r in range(6, 70, 2):
		for a in 16:
			var q := p.pos + Vector3(cos(a * TAU / 16.0), 0, sin(a * TAU / 16.0)) * r
			if w.inb(int(q.x), int(q.z)) and w.is_void(q.x, q.z):
				found = q
				break
		if found != Vector3.INF:
			break
	ok(found != Vector3.INF, "a void tile is near the landing")
	var back := p.pos
	p.teleport(Vector3(found.x, p.pos.y + 30.0, found.z))
	p.vel = Vector3.ZERO
	p.grounded = false
	_secs(0.7)
	p.teleport(back)
	p.vel = Vector3.ZERO

## The player jumps into a tall wall (_jump_wall) and holds the keys into it for WALL_MOMENT_S, then lets go.
func _wall_moment(kicked: bool) -> Array:
	var got := _moment(_jump_wall.bind(kicked), WALL_MOMENT_S)
	p.inp["move"] = Vector2.ZERO
	return got

## Raises a WALL_UPS-terrace block on open ground, stands the player 1 m off its face and jumps them into it.
func _jump_wall(kick: bool) -> void:
	var w: World = m.world
	var at := Vector2.INF
	for x0 in range(5, w.w - 8, 3):      # a scan of the map; no random draws, so the match plays on as before
		for z0 in range(4, w.h - 5, 3):
			if at == Vector2.INF and _flat_for_wall(x0, z0):
				var lv := int(w.level[w.idx(x0, z0)])
				for dz in range(-2, 3):
					for dx in range(1, 4):
						w.level[w.idx(x0 + dx, z0 + dz)] = lv + WALL_UPS
				at = Vector2(x0 + 1.0 - p.r - 1.0, z0 + 0.5)
				p.teleport(Vector3(at.x, lv * World.LEVEL, at.y))
	ok(at != Vector2.INF, "flat ground for a wall")
	p.vel = Vector3.ZERO
	p.last_gy = p.pos.y
	p.wall_moves.land()
	p.inp["move"] = Vector2(1, 0)
	p.inp["jump"] = true      # one tap: a held jump would climb the wall
	_secs(TAP_S)
	p.inp["jump"] = false
	if kick:
		p.stats["wall_kicks"] = 1

## Open ground, one level, 5 tiles either side of (x0, z0) along x and 4 along z: room for a wall and a run-up.
func _flat_for_wall(x0: int, z0: int) -> bool:
	var w: World = m.world
	var lv := int(w.level[w.idx(x0, z0)]) if w.inb(x0, z0) else -1
	for dz in range(-4, 5):
		for dx in range(-5, 8):
			var i := w.idx(x0 + dx, z0 + dz)
			if not w.inb(x0 + dx, z0 + dz) or w.kind[i] != World.T_GROUND or int(w.level[i]) != lv:
				return false
			if w.stairs.has(i) or w.walls.has(i) or w.sheer.has(i):
				return false
	var site := Vector2(x0 + 1.0, z0 + 0.5)
	var clear := true
	for x in m.exits.of_kind("outpost"):
		clear = clear and site.distance_to(Vector2(x["pos"].x, x["pos"].z)) > OUTPOST_CLEAR_M
	return lv >= 0 and clear

func _send_boki() -> void:
	p.kin.cmd = "chase"
	p.kin.teleport(p.pos + Vector3(14, 0, 0))

## A foe 7 m away: hints stay quiet for 2 s, then the other-ability line comes.
func _fight() -> Array:
	_settle()
	var n0 := shown.size()
	var mb := m.spawn_mob("skitter", p.pos)
	mb.hp = 1e6      # it stays for the whole window
	mb.max_hp = 1e6
	mb.teleport(p.pos + Vector3(7, 0, 0))
	p.kin.state = "active"
	_anchor = p.pos
	_secs(1.9)
	ok(shown.size() == n0, "nothing in the first 2 s of the fight")
	_secs(8.0)
	_anchor = Vector3.INF
	mb.hp = 0.0
	return shown.slice(n0).map(func(s): return s["id"])

func _outposts() -> void:
	var out: Array = m.exits.of_kind("outpost")
	ok(not out.is_empty(), "the map has outposts")
	var x: Dictionary = out[0]
	_check("uplink-early", "next to an outpost not open yet", _moment(_beside.bind(x, 60.0)), "")
	var late := maxf(151.0, float(x["open_at"]) + 1.0)      # past go-to-exit time: an outpost in reach keeps it quiet
	_check("uplink", "next to an idle outpost", _moment(_beside.bind(x, late)), "uplink")
	_check("defend", "own uplink charging", _moment(_charge.bind(x), 8.0), "defend")      # foes come: 2 s quiet first

func _drop_gear() -> void:
	m.spawn_gear(String(Gear.ALL.keys()[0]), 1, p.pos + Vector3(3, 0, 0))

func _charge(x: Dictionary) -> void:
	x["state"] = "charging"
	x["team"] = p.team

func _beside(x: Dictionary, at_time: float) -> void:
	_pin = at_time
	p.teleport(x["pos"] + Vector3(3, 0.5, 0))
	p.vel = Vector3.ZERO

## 151 s in, with the outposts moved out of sight (restored after).
func _far_from_outposts_late() -> void:
	var outs: Array = m.exits.of_kind("outpost")
	var home: Array = outs.map(func(x): return x["pos"])
	for x in outs:
		x["pos"] = Vector3(-9000, 0, -9000)
	_secs(MOMENT_S)
	for i in outs.size():
		outs[i]["pos"] = home[i]

## A second expedition on the saved-and-reloaded save: the same moments show nothing.
func _second_expedition() -> void:
	Save.d = JSON.parse_string(JSON.stringify(Save.d))
	var kept := FirstTimeHint.ids("match").all(func(id): return FirstTimeHint.seen(String(id)))
	ok(kept, "the seen hints survive the save round-trip")
	_start()
	_pin = 41.0
	m.spawn_mob("skitter", p.pos + Vector3(5, 0, 0))
	p.chest_keys = 1
	p.gain_xp(float(Hunter.XP_TO[1]))
	m.spawn_gear(String(Gear.ALL.keys()[0]), 1, p.pos + Vector3(2, 0, 0))
	_over_void()
	_secs(10.0)
	ok(shown.is_empty(), "after a reload none of them shows again (%s)" % str(shown.map(func(s): return s["id"])))

func _table() -> void:
	print("FHC TABLE hint | trigger | result")
	for r in _rows:
		print("FHC TABLE %s | %s | %s" % [r[0], r[1], r[2]])
