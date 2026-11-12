class_name SpawnTable
extends RefCounted
## The fixed spawn schedule of a map (docs/design/CLARITY_PASS.md): nothing out there is rolled. Every
## spawn has a place, a first time and (for the timed ones) a respawn interval that are the same in
## every match of the map. Tuning lives in content/rules/spawn_tables.json.
##
## Timed spawns are the Blight's burrows: one nest per eligible island, each clawing out a pack every
## `every` seconds of the session clock. For the last `tele` seconds a ring marks the nest on the
## ground, on the minimap and on the full map, with the seconds left. The rest of the map's spawns
## (camps, wild Boki, rare Boki, Wardens, boss lairs) stand from the start; the statics here give
## them their fixed picks (the n-th camp always holds the same monsters).

const GOLDEN := 2.399963          # radians: the golden angle, an even fan of slots with no dice
const LEAD_IN := 8.0              # s: the ring and countdown before a match event's monster appears
const GLIMMER_AT := 0.5           # share of the session when the Glimmerkin appears
const WARDEN_AT := 0.4            # ... and when the Watcher wakes on the centre island
const EVENT_COL := Color("ffd25a")
static var _rules := {}

var m: Match
var rows: Array = []              # {id, what, pos, n, first, every, fired}
var teles := {}                   # id -> telegraph node
var warn := {}                    # id -> {pos, left, total, col}: what is about to appear
var _glimmer := Vector3.INF       # the Glimmerkin's spot, once worked out (glimmer_spot)

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/spawn_tables.json"))
		_rules = d if d is Dictionary else {}
	return _rules

## A number that is the same for the same map and never depends on the match seed.
static func map_key(w: World) -> int:
	var h := w.w * 7919 + w.h * 104729 + w.islands.size() * 31
	for isl in w.islands:
		h = (h * 31 + int((isl["c"] as Vector2).x * 13.0) + int((isl["c"] as Vector2).y * 17.0)) % 2147483647
	return h

## n of pool's entries, evenly spread through the list (no dice).
static func spread(pool: Array, n: int) -> Array:
	var out: Array = []
	for k in mini(n, pool.size()):
		out.append(pool[(k * pool.size()) / n])
	return out

## The k-th camp's monsters: kind decides the list, k walks through it.
static func camp_comp(kind: String, k: int, tier: int) -> Array:
	var cc: Dictionary = rules()["camp_comps"]
	var pool: Array = (cc.get(kind, cc["normal"]) as Array).duplicate()
	if kind == "normal":
		for _t in tier: pool.append(pool[0])      # harder tiers: more brute camps
	return (pool[k % pool.size()] as Array).duplicate()

## Spot j of n on a ring round a point, for packs that appear together.
static func ring_spot(at: Vector3, j: int, n: int, radius: float) -> Vector3:
	var a := TAU * float(j) / maxf(1.0, float(n))
	return at + Vector3(cos(a), 0, sin(a)) * radius

## Camp monsters standing in a ring on their spot (a block or the void moves one to the middle).
static func spawn_camp(m: Match, p: Vector3, comp: Array) -> Array:
	var made: Array = []
	for j in comp.size():
		var q := ring_spot(p, j, comp.size(), 1.5)
		if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z):
			q = p
		q.y = m.world.ground_at(q.x, q.z)
		var mb := m.spawn_mob(String(comp[j]), q)
		if m.biomes: m.biomes.dress(mb)
		made.append(mb)
	return made

func _init(match_node: Match) -> void:
	m = match_node

# ------------------------------------------------------------------ the burrow nests
## One nest per eligible island, on a map-fixed ground cell clear of camps, drops and lairs.
func build() -> void:
	rows.clear()
	var B: Dictionary = rules()["burrow"]
	var w := m.world
	var picker := SpawnPlan.new(m)
	var r := RandomNumberGenerator.new()
	r.seed = map_key(w)
	var taken: Array = w.camp_spots.map(func(c): return c["pos"]) + w.spawns
	for ii in w.islands.size():
		var isl: Dictionary = w.islands[ii]
		if String(isl.get("role", "")) in B["skip_roles"]:
			continue
		var p := picker.cell_on(ii, r, taken, 4)
		if p == Vector3.INF or (m.lairs and not m.lairs.lair_of(p, 3.0).is_empty()):
			continue
		var t: Dictionary = B["by_danger"][clampi(int(isl.get("danger", 0)), 0, 2)]
		var first := float(t["first"]) + float(rows.size()) * float(B["stagger"])
		rows.append({"id": "burrow:%d" % ii, "what": String(B["what"]), "pos": p, "n": int(t["n"]),
			"first": first, "every": float(t["every"]), "fired": -1})

## The k-th turn of a row (0 is its first spawn) and when it is due, on the session clock.
static func due_at(row: Dictionary, k: int) -> float:
	return float(row["first"]) + float(k) * float(row["every"])

## Every spawn due up to a horizon, soonest first: [[time, row id], ...]. The schedule the test pins.
func schedule(horizon: float) -> Array:
	var out: Array = []
	for row in rows:
		var k := 0
		while due_at(row, k) <= horizon:
			out.append([due_at(row, k), String(row["id"])])
			k += 1
	out.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return out

## Seconds until a row's next spawn.
func next_in(row: Dictionary) -> float:
	return due_at(row, int(row["fired"]) + 1) - m.sess_time()

## The last turn of a row that is due by now (-1 before its first).
func _turn_now(row: Dictionary) -> int:
	return int(floor((m.sess_time() - float(row["first"])) / float(row["every"])))

func tick(blight: BlightDir) -> void:
	var tele: float = float(rules()["burrow"]["tele"])
	for row in rows:
		var left := next_in(row)
		if left <= 0.0:
			# (joined late or the clock jumped: only the turn due now, not the backlog)
			row["fired"] = _turn_now(row)
			unmark(String(row["id"]))
			if blight and _awake(row):    # (a nest nobody is near skips its turn)
				blight.burrow_out(row["pos"], int(row["n"]))
		elif left <= tele and _awake(row):
			mark(String(row["id"]), row["pos"], left, tele, float(rules()["burrow"]["radius"]), Color("ff7a3a"))
		else:
			unmark(String(row["id"]))

func _awake(row: Dictionary) -> bool:
	var reach := float(rules()["burrow"]["awake_range"])
	for h in m.hunters:
		if not h.out and not h.extracted and Vector2(h.pos.x - row["pos"].x, h.pos.z - row["pos"].z).length() < reach:
			return true
	return false

# ------------------------------------------------------------------ the match events
## The Glimmerkin's spot: an island (not the first) and a ground cell on it, fixed by the map (INF if none).
func glimmer_spot() -> Vector3:
	var w := m.world
	if _glimmer == Vector3.INF and w.islands.size() >= 2:
		var r := RandomNumberGenerator.new()
		r.seed = map_key(w) + 61
		_glimmer = SpawnPlan.new(m).cell_on(r.randi_range(1, w.islands.size() - 1), r, [], 1)
	return _glimmer

## The last LEAD_IN seconds before the Glimmerkin and the Watcher: their ring and countdown (every game,
## the host's spawn itself is Match._update_events).
func lead_ins() -> void:
	_lead_in("glimmer", glimmer_spot(), m.at_sess(GLIMMER_AT) - m.time)
	_lead_in("warden", m.world.heart_spot, m.at_sess(WARDEN_AT) - m.time)

func _lead_in(id: String, at: Vector3, left: float) -> void:
	if at != Vector3.INF and left > 0.0 and left <= LEAD_IN:
		mark(id, at, left, LEAD_IN, 2.0, EVENT_COL)
	else:
		unmark(id)

# ------------------------------------------------------------------ the telegraph
## A ring on the ground (and a minimap mark, see warning()) until something appears there:
## `left` seconds to go of a `total` countdown.
func mark(id: String, at: Vector3, left: float, total: float, radius: float, col: Color) -> void:
	if not teles.has(id):
		teles[id] = m.fx.telegraph_circle(at, radius, col)
	m.fx.telegraph_progress(teles[id], 1.0 - left / total)
	warn[id] = {"pos": at, "left": left, "total": total, "col": col}

func unmark(id: String) -> void:
	if teles.has(id):
		m.fx.end_telegraph(teles[id])
		teles.erase(id)
	warn.erase(id)

## What is about to appear: [{pos, left, total, col}] for the minimap and the full map.
func warning() -> Array:
	return warn.values()
