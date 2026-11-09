class_name KinWheel
extends RefCounted
## The G flick wheel (docs/decisions/0002): hold G, move the mouse in a direction, release. Four orders:
## up Chase, right Guard, down Return, left Follow. It is a plain overlay: no slow-motion, no pause, the
## game keeps running. State lives on the hunter's input dict (h.inp["wheel"]) because it is local UI;
## the pick becomes an order on the next fixed step (KinCommand.apply_pick).
## Numbers: content/rules/boki_system.json "wheel".

const SEGMENTS := [
	{"id": "chase", "label": "Chase", "dir": Vector2(0, -1)},
	{"id": "guard", "label": "Guard", "dir": Vector2(1, 0)},
	{"id": "return", "label": "Return", "dir": Vector2(0, 1)},
	{"id": "follow", "label": "Follow", "dir": Vector2(-1, 0)},
]

static func rules() -> Dictionary:
	return KinCommand.rules()["wheel"]

static func is_open(h: Hunter) -> bool:
	return h.inp.has("wheel")

## Which of `segments` (default: the orders) a flick of `delta` screen pixels points at (-1 inside the dead zone).
static func pick(delta: Vector2, segments: Array = SEGMENTS) -> int:
	if delta.length() < float(rules()["deadzone_px"]):
		return -1
	var best := 0
	var bd := -2.0
	for i in segments.size():
		var d := delta.normalized().dot(segments[i]["dir"] as Vector2)
		if d > bd:
			bd = d; best = i
	return best

static func open(h: Hunter, mouse: Vector2) -> void:
	h.inp["wheel"] = {"o": mouse, "sel": -1, "t": 0.0}

static func update(h: Hunter, mouse: Vector2, dt: float) -> void:
	var w: Dictionary = h.inp["wheel"]
	w["t"] = float(w["t"]) + dt
	w["sel"] = pick(mouse - (w["o"] as Vector2))

## 0..1 with an ease-out-back pop: how far open a wheel drawn `open_s` seconds ago is.
static func pop(open_s: float) -> float:
	var x := clampf(open_s / float(rules()["pop_s"]), 0.0, 1.0)
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)

## Closes the wheel. Returns the order id picked ("" if you let go inside the dead zone: nothing happens).
static func close(h: Hunter) -> String:
	var w: Dictionary = h.inp.get("wheel", {})
	h.inp.erase("wheel")
	var sel := int(w.get("sel", -1))
	return String(SEGMENTS[sel]["id"]) if sel >= 0 else ""
