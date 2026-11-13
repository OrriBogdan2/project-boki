class_name Incubator
## The Incubator by the Nesting Nook: where Rare Eggs from boss lairs hatch. It has SLOTS cradles
## round a warm brazier (more bought as an unlock, up to MAX_SLOTS). Every Rare Egg you carry home
## goes into a free cradle, or waits on the shelf beside it (Save.d["rare_eggs"]) until one frees up.
## All the placed eggs warm at once. Each is ready after hatch_secs (content/rules/incubator.json,
## 20 minutes) of play: time in the garden and time in a match both count (Game.apply_result hands
## the match's seconds to tick), time with the game closed does not. Two things warm them
## faster, and they add up: an Ember kin working the "Warm the incubator" job (HomeWork, kind
## "warm"), and Ember Coals from the market, stoked into the brazier (COAL_SECS of extra heat each).
## A ready egg waits until you hatch it there (Care.hatch_rare: a rare kin, three IVs 26 or better):
## Rare Eggs never hatch on their own and never go in the breeding nest.
##
## On the save:
##   Save.d["incubator"]  {slots: n, eggs: [{sp, boss, id, slot, heat (seconds of warmth), slow}], coal: seconds}
##   Save.d["rare_eggs"]  [{sp, boss, rare, id}] waiting on the shelf, next first
##   A wild visitor's egg also carries "visitor" {sp, zone, day} (who left it); an older egg has none.
##   Save.d["items"]["coals"]  Ember Coals not used yet

const SLOTS := 5              # cradles to start with
const MAX_SLOTS := 8
const SLOT_COST := [300, 450, 650]     # gems for the 6th, 7th and 8th
const WARM_BONUS := 1.0       # an Ember kin at the brazier: +1x (twice as fast)
const COAL_BONUS := 1.0       # Ember Coals burning: +1x (with a kin as well, three times as fast)
const COAL_SECS := 240.0      # how long one scoop of Ember Coals burns
const COAL_PRICE := 45

## Seconds of warmth an egg needs at the plain pace.
static func need() -> float:
	return float(Content.rules("incubator")["hatch_secs"])

static func _inc() -> Dictionary:
	return Save.d.get("incubator", {})

## Fills in the incubator and the shelf, upgrades an older layout, and moves an old Rare Egg out of
## the breeding nest.
static func ensure() -> void:
	if not Save.d.has("rare_eggs") or typeof(Save.d["rare_eggs"]) != TYPE_ARRAY:
		Save.d["rare_eggs"] = []
	var inc = Save.d.get("incubator", null)
	if typeof(inc) != TYPE_DICTIONARY:
		inc = {}
	if not inc.has("eggs"):
		# an early one-egg incubator ({sp, boss, ...}) becomes the first cradle
		var old: Dictionary = inc.duplicate()
		inc = {"slots": SLOTS, "eggs": [], "coal": 0.0}
		if old.has("sp"):
			old["slot"] = 0
			inc["eggs"].append(old)
	inc["slots"] = clampi(int(inc.get("slots", SLOTS)), SLOTS, MAX_SLOTS)
	Save.d["incubator"] = inc
	for e in Save.d["rare_eggs"]:
		if not (e as Dictionary).has("id"): e["id"] = _id()
	for e in inc["eggs"]:
		if not e.has("slow"):      # a cradle from before the 20-minute hatch: starts cold
			e["heat"] = 0.0
			e["slow"] = true
			e.erase("m0")
			e.erase("t")
	inc.erase("t")
	migrate()
	settle()

static var _n := 0
## An id for an egg. No global randi(): bringing an egg home must not shift the global random stream.
static func _id() -> String:
	_n += 1
	return "re%d_%d" % [Time.get_ticks_usec(), _n]

## An older save kept its Rare Egg in the breeding nest: it goes into a cradle (or the front of
## the shelf), and the nest is free for pairs again. True if one moved.
static func migrate() -> bool:
	var egg: Dictionary = Save.d.get("egg", {})
	if egg.is_empty() or not egg.get("rare", false):
		return false
	Save.d["egg"] = {}
	(Save.d["rare_eggs"] as Array).push_front({"sp": String(egg.get("sp", "")), "boss": String(egg.get("boss", "")), "rare": true, "id": _id()})
	settle()
	return true

## A Rare Egg brought home: into a free cradle, or onto the shelf to wait.
static func add(sp: String, boss := "", visitor := {}) -> Dictionary:
	ensure()
	var e := {"sp": sp, "boss": boss, "rare": true, "id": _id()}
	if not visitor.is_empty():
		e["visitor"] = visitor
	(Save.d["rare_eggs"] as Array).append(e)
	settle()
	return e

static func slots() -> int:
	return int(_inc().get("slots", SLOTS))

## The eggs in cradles (each knows its "slot").
static func eggs() -> Array:
	return _inc().get("eggs", [])

static func shelf() -> Array:
	return Save.d.get("rare_eggs", [])

static func count() -> int:
	return shelf().size() + eggs().size()

static func free_slots() -> int:
	return maxi(0, slots() - eggs().size())

static func in_slot(i: int) -> Dictionary:
	for e in eggs():
		if int(e.get("slot", -1)) == i: return e
	return {}

static func find(id: String) -> Dictionary:
	for e in eggs():
		if String(e.get("id", "")) == id: return e
	return {}

## Shelf eggs go into free cradles, next first. Returns how many went in.
static func settle() -> int:
	var inc := _inc()
	if inc.is_empty():
		return 0
	var q: Array = Save.d.get("rare_eggs", [])
	var n := 0
	for i in slots():
		if q.is_empty(): break
		if not in_slot(i).is_empty(): continue
		var e: Dictionary = q.pop_front()
		var cradle := {"sp": String(e.get("sp", "")), "boss": String(e.get("boss", "")), "id": String(e.get("id", _id())), "slot": i,
			"heat": 0.0, "slow": true}
		if e.has("visitor"):
			cradle["visitor"] = e["visitor"]
		(inc["eggs"] as Array).append(cradle)
		n += 1
	return n

## Puts a shelf egg first in line (it goes in next).
static func next_up(id: String) -> void:
	var q: Array = shelf()
	for i in q.size():
		if String(q[i].get("id", "")) == id:
			var e = q[i]; q.remove_at(i); q.push_front(e)
			return

# ------------------------------------------------------------------ warming
## 0..1: how warm the egg has got.
static func progress(e: Dictionary) -> float:
	return 0.0 if e.is_empty() else clampf(float(e.get("heat", 0.0)) / need(), 0.0, 1.0)

static func egg_ready(e: Dictionary) -> bool:
	return not e.is_empty() and progress(e) >= 1.0

static func ready_eggs() -> Array:
	return eggs().filter(func(e): return egg_ready(e))

static func any_ready() -> bool:
	return eggs().any(func(e): return egg_ready(e))

## Any egg still warming (so an Ember kin has something to do)?
static func any_warming() -> bool:
	return eggs().any(func(e): return not egg_ready(e))

static func coal_left() -> float:
	return float(_inc().get("coal", 0.0))

## How fast the eggs warm right now: 1x, +1 with an Ember kin at it, +1 with coals burning.
static func rate(warmed := false) -> float:
	return 1.0 + (WARM_BONUS if warmed else 0.0) + (COAL_BONUS if coal_left() > 0.0 else 0.0)

## Play time passing: dt seconds, at rate() for every egg still warming. Coals burn down.
static func tick(dt: float, warmed := false) -> void:
	var inc := _inc()
	if inc.is_empty():
		return
	var r := rate(warmed)
	for e in eggs():
		e["heat"] = minf(need(), float(e.get("heat", 0.0)) + dt * r)
	if coal_left() > 0.0 and any_warming():
		inc["coal"] = maxf(0.0, coal_left() - dt)

## Stokes one scoop of Ember Coals into the brazier. "" if it worked, else why not.
static func stoke() -> String:
	if int(Save.d["items"].get("coals", 0)) <= 0:
		return "No Ember Coals: the market stall sells them"
	if not any_warming():
		return "Nothing's warming right now"
	Save.d["items"]["coals"] = int(Save.d["items"]["coals"]) - 1
	_inc()["coal"] = coal_left() + COAL_SECS
	return ""

## Seconds of warmth left for this egg at the plain rate.
static func secs_left(e: Dictionary) -> float:
	return 0.0 if e.is_empty() else maxf(0.0, need() - float(e.get("heat", 0.0)))

## "Ready to hatch!", or how long it has left.
static func status_text(e: Dictionary) -> String:
	if e.is_empty():
		return "Empty"
	if egg_ready(e):
		return "Ready to hatch!"
	return "~%d min of play left" % int(ceil(secs_left(e) / 60.0 / rate()))

# ------------------------------------------------------------------ hatching and more cradles
## Hatches one ready egg (by id, or the first ready one): a rare kin (Care.hatch_rare), and its
## cradle takes the next egg off the shelf. {} if there's nothing ready.
static func hatch(rng: RandomNumberGenerator, id := "") -> Dictionary:
	var e: Dictionary = find(id) if id != "" else {}
	if e.is_empty():
		var rd := ready_eggs()
		if rd.is_empty(): return {}
		e = rd[0]
	if not egg_ready(e):
		return {}
	var baby := Care.hatch_rare(e, rng)
	(_inc()["eggs"] as Array).erase(e)
	settle()
	return baby

## Gems for the next cradle (-1 when it has them all).
static func slot_cost() -> int:
	var i := slots() - SLOTS
	return int(SLOT_COST[i]) if i < SLOT_COST.size() and slots() < MAX_SLOTS else -1

## Buys one more cradle. "" if it worked, else why not.
static func expand() -> String:
	var c := slot_cost()
	if c < 0: return "The Incubator has all its cradles"
	var locked := FarmUnlocks.cradle_lock(slots() + 1)
	if locked != "": return locked
	if int(Save.d["gems"]) < c and not Game.modding(): return "Not enough gems (%d)" % c
	if not Game.modding(): Save.d["gems"] = int(Save.d["gems"]) - c
	_inc()["slots"] = slots() + 1
	settle()
	return ""

# ------------------------------------------------------------------ names
static func egg_name(e: Dictionary) -> String:
	var sp := String(e.get("sp", ""))
	return "Rare " + (Data.egg_name(sp) if Data.KIN.has(sp) else "Egg")

## The baby's one memory line: a visitor's egg tells who left it, any other where the boss was.
static func born_line(baby: Dictionary, boss: String) -> String:
	var v: Dictionary = (baby.get("lineage", {}) as Dictionary).get("visitor", {})
	if not v.is_empty():
		return GardenVisitor.born_line(v)
	var lair := String(Data.MOBS.get(boss, {}).get("name", "a boss's lair"))
	return "hatched from a Rare Egg you carried home from %s" % lair

static func boss_name(e: Dictionary) -> String:
	if e.has("visitor"):
		return "a wild visitor in %s" % GardenVisitor.zone_name(String(e["visitor"].get("zone", "")))
	return String(Data.MOBS.get(String(e.get("boss", "")), {}).get("name", "a boss's lair"))

## The colour of the kin inside, for the spots on its gold shell.
static func spot_col(e: Dictionary) -> Color:
	var sp := String(e.get("sp", ""))
	return Data.KIN[sp].get("glow", Data.KIN[sp]["color"]) if Data.KIN.has(sp) else Color("fff6c0")
