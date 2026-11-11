class_name Camps
extends RefCounted
## Monster camps you can plan a route around (docs/CAMPS.md). A map with named camps (content/maps/<id>.json
## regions[].camps, placed by HandLayout) gives each one a fixed monster set, a tier (the monsters' rarity),
## a fixed respawn timer and a reward that fits its region. Maps without named camps keep the rolled sets
## and only refill them in a rolling session.
## Once your squad has seen a camp (SpawnPlan.team_sees) its icon shows on your map (CampMap): its reward and
## tier, and once it is cleared the countdown to its return. The host spawns, clears and refills; a clear goes to
## every peer as the "camp" event and each counts the same timer down.

const KIND := ["", "light", "normal", "heavy"]      # tier -> the camp spot's kind (World.camp_spots)
const TIER_RARITY := [0, 0, 1, 2]                   # tier -> BiomeRun.RARITY index of its monsters
const SPREAD := 1.8          # m: how far round its spot a camp's monsters stand
const PASS_T := 0.25         # s between clear and scouting passes (not every frame)
const ROLL_RESPAWN := 240.0  # s: an unnamed camp in a rolling session comes back after this
## What a cleared camp leaves, by reward id: the map icon and colour, and the gear slot (Gear.SLOTS) if gear.
const REWARDS := {
	"armor": {"icon": "fortify", "col": Color("9fd0ff"), "slot": "armor"},
	"glove": {"icon": "haymaker", "col": Color("ff9a4a"), "slot": "glove"},
	"boots": {"icon": "dash", "col": Color("8fe0a0"), "slot": "boots"},
	"relic": {"icon": "brightshield", "col": Color("c8a0ff"), "slot": "passive"},
	"treasure": {"icon": "gem", "col": Color("ffd36a")},
	"seed": {"icon": "seed", "col": Color("b6ff6a")},
}

var m: Match
## {i, id, name, region, pos, spot, tier, set, respawn, reward, mobs, up, cleared_at, seen (by your squad)}
var list: Array = []
var refills := 0             # camps the host has filled again after a clear (sims, checks)
var _pass_t := 0.0

func _init(match_node: Match) -> void:
	m = match_node
	for c in m.world.camp_spots:
		var cd: Dictionary = c.get("def", {})
		list.append({
			"i": list.size(),
			"id": String(cd.get("id", "")),
			"name": String(cd.get("name", "")),
			"region": String(c.get("region", "")),
			"pos": c["pos"],
			"spot": c,
			"tier": int(cd.get("tier", KIND.find(String(c.get("kind", "normal"))))),
			"set": cd.get("set", []),
			"respawn": float(cd.get("respawn", ROLL_RESPAWN if m.rolling else 0.0)),
			"reward": String(cd.get("reward", "")),
			"mobs": [],
			"up": true,
			"cleared_at": -1.0,
			"seen": false,
		})

## The host fills every camp at the start of the match (spread over frames under the loading screen).
func spawn_all() -> void:
	if m.net_on and not m.is_host:
		return
	for c in list:
		await m._slice()
		if (c["set"] as Array).is_empty():
			c["set"] = _rolled_set(c["spot"])
		_fill(c)

## An unnamed camp's monsters: by its kind, or from its biome region's table.
func _rolled_set(spot: Dictionary) -> Array:
	var biome_set: Array = m.biomes.camp_comp(spot) if m.biomes else []
	if not biome_set.is_empty():
		return biome_set
	var roll := m.rng.randf()
	match String(spot.get("kind", "normal")):
		"heavy":
			return ["brute", "spitter", "skitter", "sentinel"]
		"light":
			if roll < 0.4:
				return ["skitter", "skitter"]
			return ["spitter", "skitter"] if roll < 0.7 else ["bomber", "skitter"]
	if roll < 0.15 * m.tier + 0.2:
		return ["brute", "skitter", "bomber"]
	if roll < 0.5:
		return ["skitter", "bomber", "spitter"]
	return ["sentinel", "skitter", "skitter"] if roll < 0.75 else ["spitter", "skitter", "bomber"]

func _fill(c: Dictionary) -> void:
	var p: Vector3 = c["pos"]
	var rarity: int = TIER_RARITY[int(c["tier"])] if c["id"] != "" else -1
	var made: Array = []
	for kind in c["set"]:
		var q := p
		for _try in 20:
			var cand := p + Vector3(m.rng.randf_range(-SPREAD, SPREAD), 0, m.rng.randf_range(-SPREAD, SPREAD))
			if not m.world.is_void(cand.x, cand.z) and not m.world.is_block(cand.x, cand.z):
				q = Vector3(cand.x, m.world.ground_at(cand.x, cand.z), cand.z)
				break
		var mb := m.spawn_mob(String(kind), q)
		if m.biomes:
			m.biomes.dress(mb, rarity)
		made.append(mb)
	c["mobs"] = made
	c["up"] = true

## Seconds until a cleared camp is back (0 while it is up; INF if it never comes back).
func left(c: Dictionary) -> float:
	if c["up"]:
		return 0.0
	if float(c["respawn"]) <= 0.0:
		return INF
	return maxf(0.0, float(c["cleared_at"]) + float(c["respawn"]) - m.time)

func tick(dt: float) -> void:
	_pass_t -= dt
	if _pass_t > 0.0:
		return
	_pass_t = PASS_T
	var host := not m.net_on or m.is_host
	for c in list:
		if c["up"] and host and _all_dead(c):
			_clear(c, m.time)
		elif not c["up"] and left(c) <= 0.0:
			if host:
				_fill(c)
				refills += 1
			else:
				c["up"] = true
	_scout()

func _all_dead(c: Dictionary) -> bool:
	for mb in c["mobs"]:
		if is_instance_valid(mb) and not mb.dead:
			return false
	return not (c["mobs"] as Array).is_empty()

## Cleared at match time `at` (Rolling also clears camps "some time ago" before anyone lands).
func _clear(c: Dictionary, at: float, pay := true) -> void:
	c["up"] = false
	c["cleared_at"] = at
	if pay:
		_reward(c)
	if m.net_on and m.is_host:
		m.net_event(["camp", int(c["i"]), snappedf(at, 0.01)])

## Rolling: the camp was cleared a while before this match's hunters arrived (its monsters gone, no reward).
func clear_earlier(c: Dictionary, at: float) -> void:
	for mb in c["mobs"]:
		if is_instance_valid(mb) and not mb.dead:
			mb.hp = 0.0
			mb.dead = true
			mb.visible = false
	_clear(c, at, false)

## A peer hears a camp was cleared.
func net_in(x: Array) -> void:
	var i := int(x[1])
	if i >= 0 and i < list.size():
		list[i]["up"] = false
		list[i]["cleared_at"] = float(x[2])

func _reward(c: Dictionary) -> void:
	var at: Vector3 = c["pos"] + Vector3(0, 0.6, 0)
	var tier := int(c["tier"])
	var reward: String = c["reward"]
	match reward:
		"":
			return
		"treasure":
			m.spawn_val(Loot.valuable(Loot.roll_valuable(m.rng, tier - 1)), at)
		"seed":
			for _n in tier:
				m.drop("seed", at, 1, Data.pick_seed())
		_:
			var slot := Gear.SLOTS.find(String(REWARDS[reward]["slot"]))
			var gear := GearDrops.roll_gear(m.rng, tier - 1, tier - 1, slot)
			m.spawn_gear(String(gear["id"]), int(gear["rar"]), at)

## Your squad learns the camps it gets eyes on (only your own squad's knowledge is ever drawn).
func _scout() -> void:
	if m.player == null:
		return
	var team := m.player.team
	var squad := m.hunters.filter(func(h): return h.team == team and not h.out and not h.extracted and not h.riding)
	for c in list:
		if not c["seen"] and SpawnPlan.team_sees(m, squad, c["pos"]):
			c["seen"] = true
