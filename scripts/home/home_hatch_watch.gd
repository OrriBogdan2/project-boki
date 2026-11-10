class_name HomeHatchWatch
extends Node
## The home hatch as a small moment (GARDEN.md 6): in the last LEAD_S of the nest egg's wait the egg
## wobbles harder and the Boki nearby walk over to watch (friends of the parents first, then the
## parents, then whoever is closest), then the egg hatches by itself with the usual hatch card.
## It never takes you from anything: the hatch only starts when you are close by with no panel open,
## and any key or click rushes the hatching on. Home calls tick(d) and on_hatch(eh, baby).

const LEAD_S := 20.0        # s before the egg is ready when the wobble builds and the Boki start over
const WATCH_R := 14.0       # m: Boki this close to the nest are asked to come and watch
const MAX_WATCHERS := 5     # Boki at the nest at once, so it stays a ring and not a crowd
const RING_R := 1.7         # m: how far from the egg they stand
const ARRIVE_R := 0.9       # m: this close to its spot counts as arrived
const GATHER_WAIT_S := 10.0 # s after the egg is ready that the hatch waits for the last watcher
const GIVE_UP_S := 30.0     # s after it is ready that a hatch you are not here for is left to you
const NEAR_PLAYER_R := 10.0 # m: you must be this close for the hatch to start by itself
const SKIP_SPEED := 8.0     # how much faster the hatching plays after a key press

var h                                  # the Home screen
var watchers: Array = []               # kin entries standing round the egg
var gathered := 0                      # how many had arrived when the hatch started (for the check)
var _egg_key := ""                     # which egg the state below belongs to
var _called := false                   # the watchers were sent for
var _ready_t := 0.0                    # s since the egg became ready
var _hatching: EggHatch = null

func _init(home) -> void:
	h = home

## Seconds until the nest egg can hatch (0 when ready, -1 with no egg).
func left() -> float:
	var egg: Dictionary = Save.d.get("egg", {})
	if egg.is_empty():
		return -1.0
	if h._egg_ready():
		return 0.0
	return maxf(0.0, float(egg.get("t", 0.0)) - Time.get_unix_time_from_system())

func tick(d: float) -> void:
	if _hatching != null:
		return
	var lf := left()
	var egg: Dictionary = Save.d.get("egg", {})
	var key := "%s%s%s" % [egg.get("a", ""), egg.get("b", ""), egg.get("t", "")]
	if lf < 0.0 or not h.visit.is_empty() or not is_instance_valid(h.nest):
		_release()
		return
	if key != _egg_key:
		_release()
		_egg_key = key
		_ready_t = 0.0
	_wobble(lf)
	if lf > LEAD_S or _hatching != null or _ready_t > GIVE_UP_S:
		return
	if not _called:
		_called = true
		_pick(egg)
	_gather()
	if lf > 0.0:
		return
	_ready_t += d
	var arrived := watchers.filter(func(k): return _arrived(k)).size()
	if arrived < watchers.size() and _ready_t < GATHER_WAIT_S:
		return
	if h.panel_open == "" and not h.building_now and _player_near():
		gathered = arrived
		h._hatch_nest_egg()

## The egg rocks in short bursts that come closer together and stronger as the hatch nears.
func _wobble(lf: float) -> void:
	var k := clampf(1.0 - lf / LEAD_S, 0.0, 1.0)
	var sh: Node3D = h.nest.get_node("Shell")
	var sec := Time.get_ticks_msec() / 1000.0
	var period := lerpf(3.0, 1.2, k)
	var amp := lerpf(0.0, 0.12, k)
	sh.rotation.z = sin(sec * 11.0) * amp * (1.0 if fmod(sec, period) < 0.6 else 0.0)

## Who comes: Boki on the egg's island and close to it, friends of the parents first.
func _pick(egg: Dictionary) -> void:
	var nest_isle: int = h.world.island_of(h.NEST_AT.x, h.NEST_AT.z)
	var parents := [String(egg.get("a", "")), String(egg.get("b", ""))]
	var pool: Array = h.kins.filter(func(k): return _can_watch(k, nest_isle, parents))
	pool.sort_custom(func(x, y):
		var tx := _tier(x, parents)
		var ty := _tier(y, parents)
		return tx < ty or (tx == ty and _dist(x) < _dist(y)))
	watchers = pool.slice(0, MAX_WATCHERS)
	for i in watchers.size():
		var k: Dictionary = watchers[i]
		var a := (float(i) / maxf(1.0, watchers.size() - 1.0) - 0.5) * 2.4 + PI * 0.5      # an arc on the front side
		k["watch"] = h.NEST_AT + Vector3(cos(a), 0.0, sin(a)) * RING_R
		k.erase("chase"); k.erase("task"); k.erase("fetch")
		h._emote(k, "!")

func _can_watch(k: Dictionary, nest_isle: int, parents: Array) -> bool:
	if k.get("busy", false) or k.has("indoors") or k.has("leap") or k.has("job") or k.has("bath") or k.has("called_t"):
		return false
	if h.world.island_of(k["pos"].x, k["pos"].z) != nest_isle:
		return false
	return _dist(k) < WATCH_R or parents.has(String(k["rec"].get("uid", "")))

## 0: a friend of a parent, 1: a parent, 2: anyone else.
func _tier(k: Dictionary, parents: Array) -> int:
	if parents.has(String(k["rec"].get("uid", ""))):
		return 1
	for p in parents:
		if float(Save.kin(p).get("bonds", {}).get(String(k["rec"].get("uid", "")), 0.0)) > 0.0:
			return 0
	return 2

func _dist(k: Dictionary) -> float:
	return Vector2(k["pos"].x - h.NEST_AT.x, k["pos"].z - h.NEST_AT.z).length()

func _arrived(k: Dictionary) -> bool:
	var w: Vector3 = k["watch"]
	return Vector2(k["pos"].x - w.x, k["pos"].z - w.z).length() < ARRIVE_R

## Walk to the spot; once there, hold still and face the egg.
func _gather() -> void:
	for k in watchers:
		if not k.has("watch") or k.has("called_t") or k.has("indoors"):
			continue
		k["goal"] = k["watch"]
		k["t"] = maxf(float(k["t"]), 1.0)
		if _arrived(k):
			k["hold_t"] = 1.0
			var p: Vector3 = k["pos"]
			(k["node"] as Node3D).rotation.y = atan2(-(h.NEST_AT.x - p.x), -(h.NEST_AT.z - p.z))

func _player_near() -> bool:
	return Vector2(h.ppos.x - h.NEST_AT.x, h.ppos.z - h.NEST_AT.z).length() < NEAR_PLAYER_R

func _release() -> void:
	for k in watchers:
		k.erase("watch")
		k["t"] = randf_range(1.0, 3.0)
	watchers.clear()
	_called = false
	_egg_key = ""

## The hatching has begun (Home._hatch_play): watchers cheer and the parents come to the baby.
func on_hatch(eh: EggHatch, baby: Dictionary) -> void:
	_hatching = eh
	eh.popped.connect(func(_kin): _cheer())
	eh.done.connect(func():
		_hatching = null
		_greet(baby)
		_release())

func _cheer() -> void:
	for k in watchers:
		h._emote(k, "♥")

func _greet(baby: Dictionary) -> void:
	var born: Array = baby.get("lineage", {}).get("parents", [])
	var spot: Vector3 = h.NEST_AT + Vector3(0.8, 0.0, 0.6)
	for k in h.kins:
		if born.has(String(k["rec"].get("uid", ""))) and not k.get("busy", false):
			k["goal"] = spot
			k["hold_t"] = 0.0
			h._emote(k, "♥")

func _unhandled_input(event: InputEvent) -> void:
	if _hatching == null or not is_instance_valid(_hatching):
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		_hatching.skip(SKIP_SPEED)
