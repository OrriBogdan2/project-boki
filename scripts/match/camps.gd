class_name Camps
extends RefCounted
## Fixed monster camps (docs/CAMPS.md, docs/SPAWNS.md, decision 2026-11-11 "no random enemy spawns").
## Every camp spot on the map holds the same monsters in every match: its monsters come from a dice
## seeded by the spot alone (never Match.rng or the match seed), so a player learns where the Small
## Camps and the Great Camps are and what stands in them. A camp's XP is the sum of what its monsters
## pay on their death (KillXp: the last hit's squad and squadmates within 30 m). A cleared camp comes
## back once after rules back_s when nobody is near (rolling sessions ask for it: comeback()).
## Only the host holds camps; clients get the monsters in snapshots. Numbers: content/rules/camps.json.

var m: Match
var cfg: Dictionary
## One per camp spot: {pos, size ("light" | "normal" | "heavy"), comp (monster kinds), mobs, xp, dice, cleared_at}
## cleared_at is -1e9 while the camp stands.
var list: Array = []


func _init(match_node: Match) -> void:
	m = match_node
	cfg = Content.rules("camps")


## The camps of a seed-free spot: its dice (the same on every machine and every match).
static func dice_at(p: Vector3) -> RandomNumberGenerator:
	var d := RandomNumberGenerator.new()
	d.seed = (int(floorf(p.x)) * 73856093) ^ (int(floorf(p.z)) * 19349663)
	return d


## Put every camp of the map up with its monsters.
func spawn_all() -> void:
	if m.net_on and not m.is_host:
		return
	for c in m.world.camp_spots:
		await m._slice()
		var dice := dice_at(c["pos"])
		var comp := _comp(c, dice)
		var cp := {
			"pos": c["pos"],
			"size": String(c.get("kind", "normal")),
			"comp": comp,
			"dice": dice,
			"cleared_at": -1e9,
			"xp": 0.0
		}
		cp["mobs"] = _stand(cp)
		list.append(cp)


## The camps still standing, for a bot or a map that wants a place to fight.
func live() -> Array:
	return list.filter(func(cp): return float(cp["cleared_at"]) <= -1e8)


## The level a bot wants before it takes this camp (rules sizes.lvl).
func want_level(cp: Dictionary) -> int:
	return int(cfg["sizes"][cp["size"]]["lvl"])


## A rolling session starts picked over: `frac` of the camps were cleared up to back_s ago.
## Returns how many.
func picked_over(frac: float, rng: RandomNumberGenerator) -> int:
	var cleared := 0
	for cp in list:
		if rng.randf() < frac:
			for mb in cp["mobs"]:
				if is_instance_valid(mb) and not mb.dead:
					mb.hp = 0.0
					mb.dead = true
					mb.visible = false
			cp["cleared_at"] = -rng.randf_range(0.0, float(cfg["back_s"]))
			cleared += 1
	return cleared


## Cleared camps come back once back_s after the clear, with nobody within back_clear_r.
## Returns how many came back.
func comeback() -> int:
	var back := 0
	for cp in list:
		if not _all_dead(cp):
			continue
		if float(cp["cleared_at"]) <= -1e8:
			cp["cleared_at"] = m.time
			continue
		if m.time - float(cp["cleared_at"]) < float(cfg["back_s"]) or _hunter_near(cp["pos"]):
			continue
		cp["mobs"] = _stand(cp)
		cp["cleared_at"] = -1e9
		back += 1
	return back


# The monsters: the region's table when the camp is in a biome, else the size's own mix.
func _comp(c: Dictionary, dice: RandomNumberGenerator) -> Array:
	var comp: Array = m.biomes.camp_comp(c, dice) if m.biomes else []
	if not comp.is_empty():
		return comp
	match String(c.get("kind", "normal")):
		"heavy":
			return cfg["sizes"]["heavy"]["fixed"].duplicate()
		"light":
			var lr := dice.randf()
			if lr < 0.4:
				return ["skitter", "skitter"]
			return ["spitter", "skitter"] if lr < 0.7 else ["bomber", "skitter"]
	var nr := dice.randf()
	if nr < 0.15 * m.tier + 0.2:
		return ["brute", "skitter", "bomber"]
	if nr < 0.5:
		return ["skitter", "bomber", "spitter"]
	return ["sentinel", "skitter", "skitter"] if nr < 0.75 else ["spitter", "skitter", "bomber"]


## Spawn the camp's monsters, each a dice roll from its centre onto open ground, and total their XP.
func _stand(cp: Dictionary) -> Array:
	cp["xp"] = 0.0
	var p: Vector3 = cp["pos"]
	var dice: RandomNumberGenerator = cp["dice"]
	var spread := float(cfg["spread"])
	var made: Array = []
	for kind in cp["comp"]:
		var q := p
		for _t in 20:
			var cand := p + Vector3(dice.randf_range(-spread, spread), 0, dice.randf_range(-spread, spread))
			if not m.world.is_void(cand.x, cand.z) and not m.world.is_block(cand.x, cand.z):
				q = Vector3(cand.x, m.world.ground_at(cand.x, cand.z), cand.z)
				break
		var mb := m.spawn_mob(String(kind), q)
		if m.biomes:
			m.biomes.dress(mb, dice)
		made.append(mb)
		cp["xp"] += mb.max_hp * KillXp.XP_PER_HP
	return made


func _all_dead(cp: Dictionary) -> bool:
	for mb in cp["mobs"]:
		if is_instance_valid(mb) and not mb.dead:
			return false
	return true


func _hunter_near(p: Vector3) -> bool:
	for h in m.hunters:
		if (
			not h.out
			and not h.extracted
			and Vector2(h.pos.x - p.x, h.pos.z - p.z).length() < float(cfg["back_clear_r"])
		):
			return true
	return false
