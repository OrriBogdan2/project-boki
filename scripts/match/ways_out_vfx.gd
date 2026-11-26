class_name WaysOutVfx
extends RefCounted
## The far-read look of every way-out seat in a match (WaysOutLook decides the look, SeatBeacon draws it): the
## Heart's two seats (Gate, ring), each live lair's updraft and each outpost's uplink. Built on the first tick,
## when Exits and Lairs exist; one beacon per seat, nothing is created afterwards. Reads once a quarter second.

const TICK_S := 0.25     # how often the seats are read (state changes are slow; the collapse eases every frame)

var m: Match
var _root: Node3D
var _seats: Array = []   # {"b": SeatBeacon, "src": Callable -> reading or null}
var _t := 0.0

func _init(match_node: Match) -> void:
	m = match_node

func tick(dt: float) -> void:
	if m.heart.site == Vector3.INF:
		return
	if _root == null:
		_build()
	_t -= dt
	var read_now := _t <= 0.0
	if read_now:
		_t = TICK_S
	for s in _seats:
		if read_now:
			s["rd"] = (s["src"] as Callable).call()
		var rd = s["rd"]
		(s["b"] as SeatBeacon).node.visible = rd != null
		if rd != null:
			(s["b"] as SeatBeacon).show(rd, dt)

## Built hidden now, if the Heart is placed (WarmUp: the beacons' column shader is among its stand-ins; built on the
## first tick instead, the ride's first frames compiled it, a 274 ms frame on a cold cache). The first tick shows them.
func prebuild() -> void:
	if _root != null or m.heart == null or m.heart.site == Vector3.INF:
		return
	_build()
	for s in _seats: (s["b"] as SeatBeacon).node.visible = false

func _build() -> void:
	_root = Node3D.new()
	_root.name = "WaysOut"
	m.add_child(_root)
	# the readers capture the Match, not this helper: a lambda naming a member holds self, and _seats holds the
	# lambda, a cycle that kept this and its seven beacons (14 materials) alive past the match (--match-repeat-check)
	var mt := m
	_add(mt.heart.gate, Heart.r("gate_r"), func(): return WaysOutLook.early(mt))
	_add(mt.heart.site, Heart.r("final_r"), func(): return WaysOutLook.final(mt))
	if mt.lairs:
		for L in mt.lairs.list:
			_add(L["up"], Lairs.UP_R, func(): return WaysOutLook.lair(mt, L))
	if mt.exits:
		for x in mt.exits.of_kind("outpost"):
			if not x.get("tut", false):
				_add(x["pos"], Exits.OUTPOST_R, func(): return WaysOutLook.uplink(mt, x))

func _add(at: Vector3, radius: float, src: Callable) -> void:
	_seats.append({"b": SeatBeacon.new(_root, at, radius), "src": src, "rd": null})

## The beacon of the seat at this site, for the checks and the shots.
func beacon_at(p: Vector3) -> SeatBeacon:
	for s in _seats:
		if (s["b"] as SeatBeacon).node.position.distance_to(p) < 0.5:
			return s["b"]
	return null
