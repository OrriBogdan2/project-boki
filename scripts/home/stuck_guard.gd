class_name StuckGuard
extends RefCounted
## The safety net under build mode's room rules (BuildClearance, HomeBuild.keeps_paths): you or a Boki found
## inside something solid, or on ground shut off from the house door, steps out to the nearest open spot you
## can walk to from the door. free_all runs right after the layout changes; tick checks every CHECK_S and moves
## a body found stuck on STRIKES checks in a row, so it is out within CHECK_S * (STRIKES + 1) = 1.5 s.

const CHECK_S := 0.5          # s between checks
const STRIKES := 2            # checks in a row a body must be stuck before it is moved (a passing state isn't)
const SEARCH_TILES := 12      # tiles searched outward for somewhere to step to
const BOKI_R := 0.35          # m, the room a Boki needs to stand (World._fits)
const PLAYER_R := 0.38        # m, the player's body
const PLAYER_KEY := "player"
const SKIP_FLAGS := ["indoors", "leap", "bath", "going_in", "exiting"]      # a Boki somewhere on purpose

var h
var _t := 0.0
var _strikes := {}            # uid (or PLAYER_KEY) -> checks in a row it was found stuck
var _reach := PackedByteArray()
var _reach_isles := {}        # island index -> true: islands with ground reached from the door
var _reach_ver := -1
var _fresh := false           # the reach map was rebuilt during this check (chopping or a trough can open or shut
                              # ground without a layout change, so a cached miss is rebuilt before it counts)

func _init(home) -> void:
	h = home

## Every frame: checks everyone each CHECK_S and frees whoever has been stuck for STRIKES checks.
func tick(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = CHECK_S
	if not h.visit.is_empty():
		return
	_begin()
	if _player_free() and _strike(PLAYER_KEY, stuck(h.ppos)):
		_move_player()
	for k in h.kins:
		if _kin_free(k) and _strike(String(k["rec"]["uid"]), stuck(k["pos"])):
			_move_kin(k)

## Moves you and any Boki boxed in to the nearest open ground you can walk to, at once (the layout just changed).
func free_all() -> void:
	_begin()
	if _player_free() and stuck(h.ppos):
		_move_player()
	for k in h.kins:
		if _kin_free(k) and stuck(k["pos"]):
			_move_kin(k)

## Is a body standing at p stuck: inside something solid, or on ground cut off from the house door?
func stuck(p: Vector3) -> bool:
	var w: World = h.world
	var x := int(floor(p.x))
	var z := int(floor(p.z))
	if not w.inb(x, z):
		return false
	var i := w.idx(x, z)
	if w.kind[i] == World.T_BLOCK:
		return true
	if w.kind[i] != World.T_GROUND or _reach[i] == 1 or not _reach_isles.has(w.island[i]):
		return false
	if not _fresh:
		_rebuild()
		return stuck(p)
	return true

## Frees whoever is boxed in where they stand now (you wedged on every side), whatever the reach map says.
func free_player() -> void:
	_begin()
	_move_player()

## The nearest tile centre (out to SEARCH_TILES) you can walk to from the door with room for a body r wide.
func open_spot(p: Vector3, r: float) -> Vector3:
	var w: World = h.world
	var cx := int(floor(p.x))
	var cz := int(floor(p.z))
	for ring in range(0, SEARCH_TILES + 1):
		var best := Vector3.INF
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var c := Vector3(cx + dx + 0.5, p.y, cz + dz + 0.5)
				if _open(c, r) and (best == Vector3.INF or c.distance_to(p) < best.distance_to(p)):
					best = c
		if best != Vector3.INF:
			return best
	return p

func _open(c: Vector3, r: float) -> bool:
	var w: World = h.world
	var x := int(floor(c.x))
	var z := int(floor(c.z))
	if not w.inb(x, z):
		return false
	var i := w.idx(x, z)
	return w.kind[i] == World.T_GROUND and _reach[i] == 1 and w._fits(c.x, c.z, r)

func _begin() -> void:
	_fresh = false
	if _reach_ver != h.hb.ver or _reach.is_empty():
		_rebuild()

func _rebuild() -> void:
	_fresh = true
	_reach_ver = h.hb.ver
	_reach = h.hb._reach([], [])
	_reach_isles.clear()
	var w: World = h.world
	for i in _reach.size():
		if _reach[i] == 1:
			_reach_isles[w.island[i]] = true

## Counts one more check stuck (or clears the count) and says when it has reached STRIKES.
func _strike(key: String, is_stuck: bool) -> bool:
	if not is_stuck:
		_strikes.erase(key)
		return false
	_strikes[key] = int(_strikes.get(key, 0)) + 1
	if int(_strikes[key]) < STRIKES:
		return false
	_strikes.erase(key)
	return true

func _player_free() -> bool:
	return h.py <= h._ground_h(h.ppos.x, h.ppos.z) + 0.001 and not h.gliding

func _kin_free(k: Dictionary) -> bool:
	if is_same(h.carry.k, k) or not (k["node"] as Node3D).visible:
		return false
	return SKIP_FLAGS.all(func(f): return not k.has(f))

func _move_player() -> void:
	var to := open_spot(h.ppos, PLAYER_R)
	h.ppos = Vector3(to.x, h.ppos.y, to.z)
	if h.player:
		h.player.position = h.ppos

func _move_kin(k: Dictionary) -> void:
	var to := open_spot(k["pos"], BOKI_R)
	k["pos"] = to
	k["goal"] = Vector3.INF
	(k["node"] as Node3D).position = to
