extends RefCounted
## --boki-noblock-check: a Boki out beside its hunter is never in the way (docs/BOKI_IDENTITY.md "Never in
## the way"; the body layer is Kin.bumps). For a small, a medium and a large species, with the Boki held on
## one spot (standing out, the way a summon or a hop-out leaves it):
##   1. the owner walks, dashes and lands from a glide through it exactly as with no Boki there
##   2. the owner's shots fly through it to the rival behind it; a rival's shot still hits it
##   3. a teammate walks through it; a bot on its way to a spot neither stalls nor detours round it
##   4. it cannot shove its owner off a ledge
##   5. a rival still bumps into it: the body is only open to its own team
## Prints PASS/FAIL lines with how far each run differs from the same run without the Boki.

const SPECIES := {"small": "cindle", "medium": "basaltoad", "large": "cairnback"}
const DT := Match.DT
const SLACK := 0.02       # m: a run through the Boki may differ this much from the same run without it
const BUMP_MIN := 0.2     # m: a rival walking into it must be held back at least this much
const AHEAD := 1.3        # m: where the Boki is held in front of a walker
const GLIDE_H := 6.0      # m: the drop the glide landing starts from
const GLIDE_STEPS := 40   # steps the glider is held open before letting go to come down
const LIP := 21           # tiles east of the start where the ground ends (the ledge case)

var bad := 0
var main: Node
var m: Match
var P: Hunter               # the owner
var k: Kin                  # their Boki
var base := Vector3.ZERO    # where every run starts
var pin := Vector3.INF      # where the Boki is held each step (INF: benched, the run without it)

func ok(cond: bool, what: String) -> void:
	print("NOBLOCK %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	Save.no_write = true
	main = main_node
	for body_size in SPECIES:
		_fresh(String(SPECIES[body_size]))
		var tag := "%s %s (r %.2f)" % [body_size, SPECIES[body_size], k.r]
		_owner_moves(tag)
		_shots(tag)
		_others(tag)
		_ledge(tag)
		m.queue_free()
		await main.get_tree().process_frame
	print("NOBLOCK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A match with the owner, a teammate and two rivals parked on a flat strip that ends in a ledge LIP tiles east.
func _fresh(species: String) -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
			"demo_kin": species, "weapon": "rifle", "cls": "medium"})
	m.set_process(false)
	for b in m.breaks:
		b["dead"] = true          # (nothing solid on the strip but the Boki)
	P = m.player
	k = P.kin
	var W: World = m.world
	var hx := floori(P.pos.x)
	var hz := floori(P.pos.z)
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-8, 9):
		for dx in range(-10, LIP + 6):
			if not W.inb(hx + dx, hz + dz):
				continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_VOID if dx >= LIP else World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			W.stairs.erase(i)
			W.walls.erase(i)
			W.props.erase(i)
			W.bush.erase(i)
	base = Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)
	var park := [Vector3(-6, 0, 6), Vector3(-6, 0, -6), Vector3(-7, 0, 0)]
	for h in m.hunters:
		if h != P:
			h.ctrl = "idle"
			_place(h, base + park.pop_back())
	for other in m.kins:
		if other != k:
			other.state = "bench"
	_place(P, base)

## One fixed step with the Boki held at `pin` (the run through it) or benched (the run without it). The
## world keeps spawning mobs: they go, so nothing but the Boki stands on the strip.
func _step() -> void:
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	if pin == Vector3.INF:
		k.state = "bench"
	else:
		k.state = "active"
		k.cmd = "guard"
		k.hold_at = pin
		k.fly = {}
		k.rest_t = 1e9          # it casts nothing: only its body is in play
		k.teleport(pin)
		k.vel = Vector3.ZERO
	m.step(DT)

## `who` stands still at `at` (the Boki benched meanwhile).
func _place(who: Hunter, at: Vector3) -> void:
	var held := pin
	pin = Vector3.INF
	who.teleport(at)
	who.vel = Vector3.ZERO
	who.inp["move"] = Vector2.ZERO
	who.inp["aim"] = at + Vector3(4, 0.9, 0)
	for i in 10:
		_step()
	pin = held

## The same run with the Boki benched and with it held at `spot`; how far apart the two end.
func _gap(run_once: Callable, spot: Vector3) -> float:
	pin = Vector3.INF
	var alone: Vector3 = run_once.call()
	pin = spot
	var through: Vector3 = run_once.call()
	pin = Vector3.INF
	return alone.distance_to(through)

## `who` walks east from the start for `secs`; where they end up.
func _walk(who: Hunter, secs: float) -> Vector3:
	_place(who, base)
	for i in int(secs / DT):
		who.inp["move"] = Vector2(1, 0)
		who.inp["aim"] = who.pos + Vector3(4, 0.9, 0)
		_step()
	who.inp["move"] = Vector2.ZERO
	return who.pos

## `who` dashes east from the start and runs on; where they end up.
func _dash(who: Hunter) -> Vector3:
	_place(who, base)
	who.inp["move"] = Vector2(1, 0)
	who.inp["aim"] = base + Vector3(8, 0.9, 0)
	who.dashes = who.max_dashes()
	who.ex_cd = 0.0
	who.do_dash()
	for i in 45:
		who.inp["move"] = Vector2(1, 0)
		_step()
	who.inp["move"] = Vector2.ZERO
	return who.pos

## `who` drops from GLIDE_H over the start, glides east for GLIDE_STEPS, lets go and comes down, then stands
## half a second; {land: where they touched down, end: where they stand}.
func _glide(who: Hunter) -> Dictionary:
	_place(who, base)
	who.teleport(base + Vector3(0, GLIDE_H, 0))
	var land := Vector3.INF
	for i in 600:
		who.inp["move"] = Vector2(1, 0)
		who.inp["glide"] = i < GLIDE_STEPS
		who.inp["glide_btn"] = i < GLIDE_STEPS
		who.inp["aim"] = who.pos + Vector3(4, 0.9, 0)
		_step()
		if who.grounded and i > 5:
			land = who.pos
			break
	who.inp["move"] = Vector2.ZERO
	for i in 30:
		_step()
	return {"land": land, "end": who.pos}

## `who` fires at `target` (the magazine kept full) until `watch` takes a hit, for up to a second.
func _fire(who: Hunter, target: Ent, watch: Ent) -> void:
	var hp0 := watch.hp
	who.inp["aim"] = target.pos + Vector3(0, 0.9, 0)
	who.inp["aim_y"] = target.pos.y
	for i in 60:
		who.inp["fire"] = true
		who.ammo = int(who.wpn.get("mag", 30))
		_step()
		if watch.hp < hp0:
			break
	who.inp["fire"] = false

func _mate() -> Hunter:
	for h in m.hunters:
		if h != P and h.team == P.team:
			return h
	return null

func _rival() -> Hunter:
	for h in m.hunters:
		if h.team != P.team:
			return h
	return null

# ---------------------------------------------------------------- 1. the owner moves through it
func _owner_moves(tag: String) -> void:
	var walk := _gap(func(): return _walk(P, 1.5), base + Vector3(AHEAD, 0, 0))
	ok(walk <= SLACK, "%s: the owner walks through it (%.3f m off the run without it)" % [tag, walk])
	var dash := _gap(func(): return _dash(P), base + Vector3(2.0, 0, 0))
	ok(dash <= SLACK, "%s: the owner dashes through it (%.3f m off)" % [tag, dash])
	pin = Vector3.INF
	var alone := _glide(P)
	var touched: Vector3 = alone["land"]
	pin = touched
	var through := _glide(P)
	pin = Vector3.INF
	var glide: float = (alone["end"] as Vector3).distance_to(through["end"]) if touched != Vector3.INF else INF
	ok(glide <= SLACK, "%s: the owner lands from a glide on it and stands where they would without it (%.3f m off)"
			% [tag, glide])

# ---------------------------------------------------------------- 2. shots
func _shots(tag: String) -> void:
	var R := _rival()
	_place(P, base)
	_place(R, base + Vector3(7, 0, 0))
	pin = base + Vector3(2.5, 0, 0)
	k.hp = k.max_hp
	var r_hp := R.hp
	_fire(P, R, R)
	ok(R.hp < r_hp and R.last_hit_by == P and k.hp == k.max_hp,
			"%s: the owner's shots fly through it and hit the rival behind (rival -%.0f, Boki -%.0f)"
			% [tag, r_hp - R.hp, k.max_hp - k.hp])
	R.equip("rifle")
	_fire(R, P, k)
	ok(k.hp < k.max_hp and k.last_hit_by == R, "%s: a rival's shot still hits it (Boki -%.0f)" % [tag, k.max_hp - k.hp])
	pin = Vector3.INF
	k.hp = k.max_hp
	_place(R, base + Vector3(-6, 0, -6))

# ---------------------------------------------------------------- 3. a teammate, a bot, a rival
func _others(tag: String) -> void:
	var T := _mate()
	_place(P, base + Vector3(-5, 0, 3))      # (out of their way)
	var spot := base + Vector3(AHEAD, 0, 0)
	var mate_gap := _gap(func(): return _walk(T, 1.5), spot)
	ok(mate_gap <= SLACK, "%s: a teammate walks through it (%.3f m off)" % [tag, mate_gap])
	var bot_gap := _gap(func(): return _bot_walk(T), spot)
	var detoured := int(T.ai.get("hops", 0)) > 0 or float(T.ai.get("detour_t", 0.0)) > 0.0
	ok(bot_gap <= SLACK and not detoured, "%s: a bot walks its line through it, no stall or detour (%.3f m off)"
			% [tag, bot_gap])
	_place(T, base + Vector3(-6, 0, 6))
	var R := _rival()
	var rival_gap := _gap(func(): return _walk(R, 1.5), spot)
	ok(rival_gap >= BUMP_MIN, "%s: a rival still bumps into it (held back %.2f m)" % [tag, rival_gap])
	_place(R, base + Vector3(-6, 0, -6))

## The teammate as a bot, sent to a spot 10 m east with its own mind steering; where it ends up after 1.5 s.
func _bot_walk(T: Hunter) -> Vector3:
	_place(T, base)
	T.ai["think"] = 1e9          # (no new goals: it only walks to this one)
	T.ai["goal"] = base + Vector3(10, 0, 0)
	T.ai["goal_kind"] = "wander"
	T.ai["tgt"] = null
	T.ai["hops"] = 0
	T.ai.erase("detour_t")
	T.ai.erase("wp")
	T.ctrl = "bot"
	for i in int(1.5 / DT):
		_step()
	T.ctrl = "idle"
	T.inp["move"] = Vector2.ZERO
	return T.pos

# ---------------------------------------------------------------- 4. the ledge
func _ledge(tag: String) -> void:
	var lip := base + Vector3(LIP - 1, 0, 0)       # the middle of the last tile, 0.5 m from the drop
	var stand := func() -> Vector3:
		_place(P, lip)
		for i in 60:
			_step()
		return P.pos
	var shoved := _gap(stand, lip + Vector3(-0.4, 0, 0))
	var on_ground := not m.world.is_void(P.pos.x, P.pos.z)
	ok(shoved <= SLACK and on_ground,
			"%s: pressed against its owner at a ledge it moves them %.3f m (still on the ground: %s)"
			% [tag, shoved, on_ground])
	_place(P, base)
