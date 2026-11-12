class_name TrainMap
extends RefCounted
## The sky train on the minimap and the full map: the loop as a thin line, each halt as a small icon
## (named on the full map), the train as a marker that follows its arc position, and at the halt
## nearest you "Next train: 0:24". Both maps call draw(); there is no second renderer. On the minimap
## the loop is `detail` (MapDetail "train"): it shows by itself only while it is within NEAR_R of you.

const GOLD := Color("f2c84a")
const INK := Color("f3eee2")
const HALT_NAME := Color("ffe2b0")
const NEAR_R := 34.0        # m: the ground minimap's view radius; the loop matters once it is this close
const STEP := 3.0           # m between the loop's drawn points
const LINE_W := 1.5         # px
const UNDER_ALPHA := 0.3    # the line's alpha where it runs under a bridge
const LINE_ALPHA := 0.75
const HALT_R := 3.0         # px: half the side of a halt's square

var _for: SkyTrain = null
var _line := PackedVector2Array()
var _under: Array[bool] = []
var _halts: Array = []      # [{name: String, pos: Vector2, s: float (the route's station arc)}]

## Seconds as "0:24", counting up to the next whole second.
static func clock(secs: float) -> String:
	var t := int(ceilf(maxf(0.0, secs)))
	return "%d:%02d" % [t / 60, t % 60]

## The map line for a halt's countdown: "Next train: 0:24", or that the train is there.
static func eta_text(secs: float) -> String:
	if secs <= 0.0:
		return "Train at the halt"
	return "Next train: %s" % clock(secs)

## The halts, in route order, with their map positions.
func halts(st: SkyTrain) -> Array:
	_sync(st)
	return _halts

## The train's place on the map: its engine, at the schedule's arc position.
func marker(st: SkyTrain) -> Vector2:
	var p := st.world.train_at(st.head_s)
	return Vector2(p.x, p.z)

## The index in halts() of the halt nearest a map point (-1 with none).
func nearest_halt(st: SkyTrain, at: Vector2) -> int:
	_sync(st)
	var best := -1
	var best_d := INF
	for i in _halts.size():
		var d := at.distance_squared_to(_halts[i]["pos"])
		if d < best_d:
			best_d = d
			best = i
	return best

## Is any of the loop within NEAR_R of this hunter?
func near(st: SkyTrain, me: Hunter) -> bool:
	if me == null:
		return false
	_sync(st)
	var at := Vector2(me.pos.x, me.pos.z)
	for p in _line:
		if at.distance_squared_to(p) <= NEAR_R * NEAR_R:
			return true
	return false

## Draws the loop, its halts and the train into `inner` (screen) showing `view` (world) at `k` px per m.
## `named`: halt names (the full map); the nearest halt always carries its countdown. `hud` is the Hud.
func draw(hud, st: SkyTrain, inner: Rect2, view: Rect2, k: float, named: bool) -> void:
	_sync(st)
	var to_screen := func(p: Vector2) -> Vector2:
		return inner.position + (p - view.position) * k
	_draw_line(hud, inner, to_screen)
	_draw_halts(hud, st, inner, to_screen, named)
	_draw_train(hud, st, inner, to_screen)

func _draw_line(hud, inner: Rect2, to_screen: Callable) -> void:
	var n := _line.size()
	for i in n:
		var a: Vector2 = to_screen.call(_line[i])
		var b: Vector2 = to_screen.call(_line[(i + 1) % n])
		if hud._mm_has(inner, a) and hud._mm_has(inner, b):
			hud.c.draw_line(a, b, Color(GOLD, UNDER_ALPHA if _under[i] else LINE_ALPHA), LINE_W, true)

func _draw_halts(hud, st: SkyTrain, inner: Rect2, to_screen: Callable, named: bool) -> void:
	var me = hud.m.player
	var mine := -1
	if me != null:
		mine = nearest_halt(st, Vector2(me.pos.x, me.pos.z))
	for i in _halts.size():
		var pv: Vector2 = to_screen.call(_halts[i]["pos"])
		if not hud._mm_has(inner, pv, 6.0):
			continue
		var halo := Vector2.ONE * (HALT_R + 1.0)
		hud.c.draw_rect(Rect2(pv - halo, halo * 2.0), Color(0, 0, 0, 0.6))
		var half := Vector2.ONE * HALT_R
		hud.c.draw_rect(Rect2(pv - half, half * 2.0), GOLD)
		var y := 15.0
		if named:
			hud._ctext(pv + Vector2(0, y), _halts[i]["name"], 10, HALT_NAME, hud.big)
			y += 12.0
		if i == mine:
			var secs := st.halt_eta(_halts[i]["s"])
			hud._ctext(pv + Vector2(0, y), eta_text(secs), 10, GOLD, hud.big)

## One marker for the train (a chevron on its heading) and a dot for each car behind it.
func _draw_train(hud, st: SkyTrain, inner: Rect2, to_screen: Callable) -> void:
	var cars: Array = st.car_positions()
	for i in range(cars.size() - 1, 0, -1):
		var pv: Vector2 = to_screen.call(cars[i])
		if hud._mm_has(inner, pv, 3.0):
			hud.c.draw_circle(pv, 2.6, Color(0, 0, 0, 0.6))
			hud.c.draw_circle(pv, 1.8, GOLD)
	var at: Vector2 = to_screen.call(marker(st))
	if not hud._mm_has(inner, at, 4.0):
		return
	var ahead: Vector3 = st.world.train_at(st.head_s + 2.0) - st.world.train_at(st.head_s - 2.0)
	var f := Vector2(ahead.x, ahead.z).normalized()
	var side := Vector2(-f.y, f.x)
	var tri := PackedVector2Array([at + f * 6.0, at - f * 4.0 + side * 4.0, at - f * 4.0 - side * 4.0])
	hud.c.draw_colored_polygon(tri, Color(0, 0, 0, 0.7))
	var inner_tri := PackedVector2Array([at + f * 4.0, at - f * 2.5 + side * 2.5, at - f * 2.5 - side * 2.5])
	hud.c.draw_colored_polygon(inner_tri, INK)

## Rebuilds the cached loop and halts when the train is a new one (a new match).
func _sync(st: SkyTrain) -> void:
	if _for == st:
		return
	_for = st
	_line = PackedVector2Array()
	_under = []
	var s := 0.0
	while s < st.loop_len:
		var p := st.world.train_at(s)
		_line.append(Vector2(p.x, p.z))
		_under.append(p.y < -1.0)
		s += STEP
	_halts = []
	var route: Dictionary = st.world.train_route
	var names: Array = route["names"]
	for i in route["stations"].size():
		var p := st.world.train_at(float(route["stations"][i]))
		_halts.append({"name": String(names[i]) if i < names.size() else "Halt %d" % (i + 1),
				"pos": Vector2(p.x, p.z), "s": float(route["stations"][i])})
