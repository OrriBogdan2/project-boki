extends RefCounted
## The scripted pond walk (--clip-check, --pond-shots): a Hunter model walks from the bank down a shallow channel into
## a deep pond and stops to tread water, then swims on and climbs out the far side. Every frame comes from the real
## HomeWater (its depth, speed, sink, tilt and anim_state) into HunterAnim and the Hero's clips, so what is checked
## and filmed is what the farm plays. The model faces -Z and walks toward -Z.

const DT := 1.0 / 30.0
const START_Z := 47.5          # on the bank, a run up before the water
const END_Z := 24.5            # out the far side, dry again
const STOP_Z := 31.5           # m: where it stops to tread water
const TREAD_S := 4.0           # s: treading water
const EDGE_X := 32.5           # the line it walks
const DRY_SPEED := 5.0         # the farm's walk speed (Home.SPEED)
const POND := Rect2i(28, 26, 9, 10)          # the deep pond (tiles x, z; its rim is the shallow edge)
const CHANNEL := Rect2i(32, 36, 1, 6)        # a one-tile shallow channel from the bank to the pond

## What HomeWater asks of its Home: the layout's water tiles (the farm's own pond is too small to film a stroke in).
class Layout:
	var cells := {}
	func L() -> Dictionary:
		return {"water": cells}

## The phase a frame is in: "dry" before the water, "wade", "swim", "tread" (stopped in deep water), "out" after it.
var phase := "dry"

func _layout() -> Layout:
	var lay := Layout.new()
	for rect in [POND, CHANNEL]:
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				lay.cells[HomeLayout.key(x, z)] = true
	return lay

## Walks `m` (driven by `anim`) through the pond; `on_frame` (a coroutine or not) is called after each step with
## {phase, depth, speed, state}. HunterAnim and the Hero's clips are stepped here.
func walk(tree: SceneTree, m: Node3D, sync: Node, anim: HunterAnim, on_frame: Callable) -> void:
	var host := {"fs": false, "hb": _layout(), "fx": null, "ppos": Vector3(EDGE_X, 0, START_Z), "pvy": 0.0,
			"SPEED": DRY_SPEED}
	var water := HomeWater.new(host)
	var pos := Vector3(EDGE_X, 0, START_Z)
	var treaded := 0.0
	var was_swim := false
	while pos.z > END_Z:
		var wdep := water.depth(pos.x, pos.z)
		water.step(wdep, DT, Vector2(0, -1), false)
		var spd := DRY_SPEED * water.speed_mul(wdep, false)
		var treading := water.swimming and pos.z <= STOP_Z and treaded < TREAD_S
		if treading:
			spd = 0.0
			treaded += DT
		pos.z -= spd * DT
		host["ppos"] = pos
		phase = "dry"
		if treading:
			phase = "tread"
		elif wdep == 2:
			phase = "swim"
		elif wdep == 1:
			phase = "wade"
		elif was_swim or treaded > 0.0:
			phase = "out"
		was_swim = was_swim or water.swimming
		var state := {"vel": Vector3(0, 0, -spd), "face": 0.0, "grounded": true, "fired": 99.0}
		state.merge(water.anim_state())
		m.position.y = -water.drop_y()
		m.basis = water.tilt(Basis.from_scale(m.scale), spd)
		anim.update(DT, state)
		sync.call("_process", DT)
		await tree.process_frame
		await on_frame.call({"phase": phase, "depth": wdep, "speed": spd, "state": state})
	m.position.y = 0.0
	m.basis = Basis.from_scale(m.scale)
