class_name DayNightSpawns
extends RefCounted
## What the day/night cycle (DayNight) puts on the map. Some Small Camps and Camps stand only at night and some
## only by day (never the Great Camps): which ones is fixed by their spot alone, like the camps' monsters, so
## the same spots are dark camps in every match and every peer can mark them. At each swap the host stands the
## new phase's camps up with fresh monsters and sends the old phase's survivors away. Each night also brings one
## elite at a fixed outer-island spot from the match seed, shown on the full map from the start.
## Only the host spawns; clients get the monsters in snapshots. Numbers: content/rules/day_night.json.

const BOSS_COL := Color("c9a0ff")

var m: Match
var dn: DayNight
var cfg: Dictionary
var spots: Array = []  # camp spots that follow a phase: {pos, kind, mode ("day" | "night")}
var boss: Mob = null
var boss_night := -1  # the night the elite stands for


func _init(match_node: Match, clock: DayNight) -> void:
	m = match_node
	dn = clock
	cfg = clock.cfg


## "night" or "day" when the camp at p stands only in that phase, else "" (always standing).
func camp_mode(p: Vector3, kind: String) -> String:
	if kind == "heavy" or not dn.on():
		return ""
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(floorf(p.x)), int(floorf(p.z)), "day_night"])
	var x := r.randf()
	if x < float(cfg["night_share"]):
		return "night"
	return "day" if x < float(cfg["night_share"]) + float(cfg["day_share"]) else ""


## The camp's monsters at night: one of the size's night mixes, picked by the spot's dice.
func night_comp(kind: String, dice: RandomNumberGenerator) -> Array:
	var mixes: Array = cfg["night_mix"][kind]
	return (mixes[dice.randi_range(0, mixes.size() - 1)] as Array).duplicate()


## The phase-bound camp spots of the map, the same on every peer.
func phase_spots() -> Array:
	if spots.is_empty():
		for c in m.world.camp_spots:
			var mode := camp_mode(c["pos"], String(c.get("kind", "normal")))
			if mode != "":
				spots.append({"pos": c["pos"], "kind": c["kind"], "mode": mode})
	return spots


## Where night n's elite stands: an outer-island wild spot picked from the match seed, the same on every peer.
func boss_spot(n: int) -> Vector3:
	var w := m.world
	var pool: Array = w.wild_spots.filter(func(p): return w.island_of(p.x, p.z) >= 1)
	if pool.is_empty():
		pool = w.wild_spots
	if pool.is_empty():
		return Vector3.INF
	var r := RandomNumberGenerator.new()
	r.seed = hash([m.seed_val, "night_boss", n])
	return pool[r.randi_range(0, pool.size() - 1)]


## The elite's kind for night n (the rules list, cycled).
func boss_kind(n: int) -> String:
	var kinds: Array = cfg["boss"]["kinds"]
	return String(kinds[n % kinds.size()])


func start(night: bool) -> void:
	if night:
		_stand_boss(dn.next_night(m.sess_time()))


## The phase changed: night camps up (day camps away) at dusk, the other way at dawn.
func swap(night: bool) -> void:
	if m.net_on and not m.is_host:
		return
	for cp in m.camps.list:
		var mode := String(cp["mode"])
		if mode == "":
			continue
		if (mode == "night") == night:
			m.camps.wake(cp)
		else:
			m.camps.sleep(cp)
	if night:
		_stand_boss(dn.next_night(m.sess_time()))
	elif boss != null:
		Camps.retreat([boss])
		boss = null


func _stand_boss(n: int) -> void:
	var at := boss_spot(n)
	if at == Vector3.INF or boss_night == n or (m.net_on and not m.is_host):
		return
	boss_night = n
	boss = m.spawn_mob(boss_kind(n), at)
	boss.max_hp *= float(cfg["boss"]["hp_k"])
	boss.hp = boss.max_hp
	boss.rarity = int(cfg["boss"]["rarity"])
	m.ping(at, BOSS_COL)
	if m.player:
		m._announce("A night elite prowls %s" % m.direction_word(m.player.pos, at), BOSS_COL)
