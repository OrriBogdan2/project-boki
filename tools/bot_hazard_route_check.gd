extends RefCounted
## --bot-hazard-route-check [--route-t=<s>] [--route-seeds=a,b]: how bots deal with the Hollow Crown's big
## hazard fields (TerrainHazards, docs/decisions/0060-terrain-hazards.md). Bots fill most slots, so one that
## walks into lava and dies breaks a match. Three parts, all on the real map:
##   sim      full autoplay matches (bots only): no bot goes down within a few seconds of standing in a field its
##            Boki or perk does not ward, and none stays in one longer than it takes to walk out
##   leave    a bot dropped deep into each field kind with no ward walks out by the shortest way (the tile
##            search's nearest exit), at a walking pace, alive
##   cross    a bot warded by its Boki, and one by a perk, steer straight over the lava; one with neither
##            goes round it and spends no time in it
## Never touches the save. Prints "ROUTE ..." lines and "ROUTE CHECK DONE, N checks, failures: F".

const PLAIN := "cindle"                  # venom: counters none of the fields
const EMBER := "cindowary"                # counters lava
const LEAVE_KINDS := ["lava", "deep_water", "bramble"]      # the grounds that hurt (ice and static: no standing damage)
const A_TILE := Vector2i(42, 141)         # the lava lake's west chest ...
const B_TILE := Vector2i(85, 158)         # ... and its east islet: causeways cross between them
const EXPOSED_S := 3.0                    # s: a bot down this soon after standing in a field died of it
const MAX_STAY_S := 8.0                   # s: the longest a bot may stay in a field it is not warded against
const LEAVE_SLACK := 1.6                  # x the straight walk out: the allowed time and distance
var main: Node
var m: Match
var tz: TerrainHazards
var n := 0
var fails := 0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("ROUTE %-72s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var secs := 150.0
	var seeds := [5, 6]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--route-t="): secs = float(a.substr(10))
		if a.begins_with("--route-seeds="): seeds = Array(a.substr(14).split(",")).map(func(x): return int(x))
	for sd in seeds:
		await _sim(int(sd), secs)
	await _scenes()
	print("ROUTE CHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

# ------------------------------------------------------------------ sim
## A bots-only match: tallies, per hunter, the time spent in a field it is not warded against.
func _sim(seed_val: int, secs: float) -> void:
	var mm := Match.new()
	main.add_child(mm)
	mm.start({"autoplay": true, "seed": seed_val})
	mm.set_process(false)
	var stay := {}            # hunter -> s in a row in an unwarded field
	var last := {}            # hunter -> m.time it was last in one
	var worst := 0.0
	var episodes := 0
	var deaths := 0
	var warded := 0.0         # s the squad's warded hunters spent in fields (bots that cross)
	var was_down := {}
	while mm.time < secs and not mm.over:
		mm.step(Match.DT)
		var tzm := TerrainHazards.of(mm)
		for h in mm.hunters:
			if h.out or h.extracted or h.remote:
				continue
			if TerrainHazards.harmed(mm, h):
				if not stay.has(h): episodes += 1
				stay[h] = float(stay.get(h, 0.0)) + Match.DT
				last[h] = mm.time
				worst = maxf(worst, float(stay[h]))
			else:
				stay.erase(h)
				if tzm != null and tzm.area_at(h.pos) >= 0:
					warded += Match.DT
			if (h.downed or h.dead) and not was_down.has(h):
				was_down[h] = true
				if last.has(h) and mm.time - float(last[h]) < EXPOSED_S:
					deaths += 1
	var tag := "seed %d, %.0f s" % [seed_val, mm.time]
	ok("sim %s: the map has hazard fields" % tag, TerrainHazards.of(mm) != null)
	ok("sim %s: no bot goes down after standing in a field it is not warded against" % tag, deaths == 0,
		"%d episodes, %d downed" % [episodes, deaths])
	ok("sim %s: a bot never stays in one longer than %.0f s" % [tag, MAX_STAY_S], worst <= MAX_STAY_S,
		"longest %.1f s, warded hunters in fields %.0f s" % [worst, warded])
	mm.queue_free()
	await main.get_tree().process_frame

# ------------------------------------------------------------------ scenes
func _scenes() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 5, "no_drop": true, "demo_kin": PLAIN})
	m.set_process(false)
	tz = TerrainHazards.of(m)
	var bot: Hunter = null
	for h in m.hunters:
		if h != m.player and h.kin is Kin:
			bot = h
			break
	ok("a bot with a Boki to test with", bot != null and tz != null)
	if bot == null or tz == null:
		return
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for kind in LEAVE_KINDS:
		await _leave(bot, kind)
	await _cross(bot)

## Tiles each area cell is from the nearest tile off the field (4-neighbour steps), from its rim in.
func _depth(ai: int) -> Dictionary:
	var cells: Array = tz.areas[ai]["cells"]
	var depth := {}
	var q: Array = []
	for c: Vector2i in cells:
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if tz.cell[m.world.idx(c.x + dv.x, c.y + dv.y)] != ai + 1:
				depth[c] = 1
				q.append(c)
				break
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = c + dv
			if not depth.has(nx) and tz.cell[m.world.idx(nx.x, nx.y)] == ai + 1:
				depth[nx] = int(depth[c]) + 1
				q.append(nx)
	return depth

func _dress(h: Hunter, species: String, perks: Array) -> void:
	var k := h.kin as Kin
	k.species = species
	k.sp = Data.KIN[species]
	h.perks = perks
	h.hp = h.max_hp
	h.vel = Vector3.ZERO
	for f in ["burn_t", "slow_t", "slow_k", "stun_t", "haste_t", "cc_immune_t"]: h.set(f, 0.0)
	h.dr.clear()
	h.ai.erase("wp")
	h.ai.erase("exit")
	tz.state.clear()

## An unwarded bot put deep in a field walks out by the shortest way.
func _leave(bot: Hunter, kind: String) -> void:
	var ai := -1
	var deep := {}
	for k in tz.areas.size():
		if tz.areas[k]["kind"] != kind: continue
		var d := _depth(k)
		if ai < 0 or d.values().max() > deep.values().max():
			ai = k
			deep = d
	ok("%s: a field to be knocked into" % kind, ai >= 0)
	if ai < 0: return
	# water drowns after 6 s: a spot a bot can swim out of in time
	var want: int = mini(int(deep.values().max()), 4 if kind == "deep_water" else 9)
	var at := Vector2i.ZERO
	for c in deep:
		if int(deep[c]) == want:
			at = c
			break
	_dress(bot, PLAIN, [])
	bot.teleport(Vector3(at.x + 0.5, float(tz.areas[ai]["y"]), at.y + 0.5))
	var start := Vector2(bot.pos.x, bot.pos.z)
	var walked := 0.0
	var prev := start
	var t := 0.0
	var limit := float(want) / (bot.base_speed * (0.55 if kind == "deep_water" else 1.0)) * LEAVE_SLACK + 1.5
	while t < limit + 4.0 and TerrainHazards.harmed(m, bot):
		m.step(Match.DT)
		t += Match.DT
		var p := Vector2(bot.pos.x, bot.pos.z)
		walked += p.distance_to(prev)
		prev = p
	await main.get_tree().process_frame
	var info := "%d tiles in, out after %.1f s (limit %.1f), walked %.1f m, hp %.0f/%.0f" % [
		want, t, limit, walked, bot.hp, bot.max_hp]
	var out := not TerrainHazards.harmed(m, bot) and t <= limit
	ok("%s: a knocked-in bot with no ward is out of the field in time" % kind, out, info)
	ok("%s: ... by the shortest way (walked at most %.1fx the way out)" % [kind, LEAVE_SLACK],
		walked <= float(want) * LEAVE_SLACK + 1.0, info)
	ok("%s: ... alive" % kind, not bot.downed and not bot.out and bot.hp > 0.0, info)

## Warded (Boki, perk) bots take the lava's straight way; an unwarded one goes round it.
func _cross(bot: Hunter) -> void:
	var ai := -1
	for k in tz.areas.size():
		if tz.areas[k]["kind"] == "lava":
			ai = k
			break
	var goal := Vector3(B_TILE.x + 0.5, float(tz.areas[ai]["y"]), B_TILE.y + 0.5)
	var ctrl := bot.ctrl
	bot.ctrl = "none"          # steered by this check, not by the bot's own goals
	var perk := TerrainHazards.ward_for("lava")
	for who in [["ember Boki", EMBER, []], ["Emberwalk perk", PLAIN, [perk]], ["no ward", PLAIN, []]]:
		_dress(bot, who[1], who[2])
		bot.teleport(Vector3(A_TILE.x + 0.5, float(tz.areas[ai]["y"]), A_TILE.y + 0.5))
		var in_lava := 0.0
		var t := 0.0
		while t < 120.0 and bot.flat_dist(goal) > 1.5:
			bot.inp["move"] = m.bot_brain._steer(m, bot, goal)
			m.step(Match.DT)
			t += Match.DT
			if tz.area_at(bot.pos) >= 0: in_lava += Match.DT
		await main.get_tree().process_frame
		var warded: bool = who[0] != "no ward"
		var info := "%.0f s, %.1f s on a field, hp %.0f/%.0f" % [t, in_lava, bot.hp, bot.max_hp]
		ok("cross, %s: reaches the islet" % who[0], bot.flat_dist(goal) <= 1.5, info)
		ok("cross, %s: %s" % [who[0], "crosses the lava, unhurt" if warded else "never sets foot on the lava, unhurt"],
			(in_lava > 0.0 if warded else in_lava == 0.0) and bot.hp >= bot.max_hp - 0.5, info)
	bot.ctrl = ctrl
