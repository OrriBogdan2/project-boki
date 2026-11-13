class_name WaysOutVfx
extends RefCounted
## The far-read look of every way-out seat in a match (WaysOutLook decides the look, SeatBeacon draws it): the
## Heart's two seats (Gate, ring), each live lair's updraft and each outpost's uplink. Built on the first tick,
## when Exits and Lairs exist; one beacon per seat, nothing is created afterwards. Reads once a quarter second.
## A seat's reader is a bound static WaysOutLook call, not a lambda: a lambda reading `m` would hold this object
## and make a cycle that leaks every beacon's materials at exit.

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

func _build() -> void:
	_root = Node3D.new()
	_root.name = "WaysOut"
	m.add_child(_root)
	_add(m.heart.gate, Heart.r("gate_r"), WaysOutLook.early.bind(m))
	_add(m.heart.site, Heart.r("final_r"), WaysOutLook.final.bind(m))
	if m.lairs:
		for L in m.lairs.list:
			_add(L["up"], Lairs.UP_R, WaysOutLook.lair.bind(m, L))
	if m.exits:
		for x in m.exits.of_kind("outpost"):
			if not x.get("tut", false):
				_add(x["pos"], Exits.OUTPOST_R, WaysOutLook.uplink.bind(m, x))

func _add(at: Vector3, radius: float, src: Callable) -> void:
	_seats.append({"b": SeatBeacon.new(_root, at, radius), "src": src, "rd": null})

## The beacon of the seat at this site, for the checks and the shots.
func beacon_at(p: Vector3) -> SeatBeacon:
	for s in _seats:
		if (s["b"] as SeatBeacon).node.position.distance_to(p) < 0.5:
			return s["b"]
	return null
