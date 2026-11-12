class_name WardenSteps
extends RefCounted
## A Hero's footsteps on the frames his walk and run loops plant a foot, on every loop of the ring (forward, back,
## the sides and the diagonals of tools/art1/hunter_dir_gait.py). Data "loco.plants": {clip: {"L": [s], "R": [s]}},
## the times into each loop a foot touches down, read off the clip by --step-sync-check (which re-reads them and
## fails when a loop is re-baked without them). The loop the blend weighs most is the one heard (the blend space's
## own triangles; off them, the nearest loop): a step sounds when its playback passes a plant. Through a blend the
## feet keep alternating, so two loops planting the same foot a frame apart step once; a loop that takes over looks
## back CATCH of a step for a plant the last one had not reached, so a strafe never drops one. Each step bumps the
## model's meta STEPS, which HunterAnim hands on as `stepped` (Juice.footstep).

const STEPS := "clip_steps"   # root meta: how many feet have planted (HunterAnim.stepped when it changes)
const CATCH := 0.5            # x the clip time from one plant to the next: how far back a new loop looks

var root: Node3D
var tree: AnimationTree
var ring: Array = []          # per loop: [its blend position, its playback parameter, length (s), [[s, foot]]]
var of_point := {}            # blend point index -> its loop in `ring`
var space: AnimationNodeBlendSpace2D
var tris: Array = []          # the blend space's triangles: [[point index, its position] x 3] (it makes them on use)
var cur := -1                 # the loop heard last frame (-1: none)
var last := 0.0               # s into it then
var count := 0                # steps so far
var side := ""                # the foot that stepped last ("" none since he last stood)

func _init(model: Node3D, t: AnimationTree, bs: AnimationNodeBlendSpace2D, plants: Dictionary,
		lib: AnimationLibrary) -> void:
	root = model
	tree = t
	for i in bs.get_blend_point_count():
		var clip := String((bs.get_blend_point_node(i) as AnimationNodeAnimation).animation)
		if not plants.has(clip):
			continue
		var times := []
		for foot in ["L", "R"]:
			for s in plants[clip].get(foot, []):
				times.append([float(s), foot])
		times.sort()
		var param := "parameters/loco/%d/current_position" % i
		of_point[i] = ring.size()
		ring.append([bs.get_blend_point_position(i), param, lib.get_animation(clip).length, times])
	space = bs
	if not ring.is_empty():
		root.set_meta(STEPS, 0)

## After the tree has advanced. `walking`: the ring owns the legs and he is on the ground; `at`: its blend position.
func step(walking: bool, at: Vector2) -> void:
	if not walking or ring.is_empty():
		cur = -1
		side = ""
		return
	var near := _heard(at)
	var loop: Array = ring[near]
	var length: float = loop[2]
	var times: Array = loop[3]
	var t: float = tree.get(loop[1])
	var from := last if near == cur else t - CATCH * length / maxf(times.size(), 1.0)
	cur = near
	last = t
	var window := fposmod(t - from, length)
	var best := []
	for p in times:
		var ago := fposmod(t - float(p[0]), length)
		if ago < window and p[1] != side and (best.is_empty() or ago < float(best[0])):
			best = [ago, p[1]]
	if not best.is_empty():
		side = best[1]
		count += 1
		root.set_meta(STEPS, count)

## The loop in `ring` the blend weighs most at `at`.
func _heard(at: Vector2) -> int:
	if tris.is_empty():
		for k in space.get_triangle_count():
			var tri := []
			for j in 3:
				var i := space.get_triangle_point(k, j)
				tri.append([i, space.get_blend_point_position(i)])
			tris.append(tri)
	for tri in tris:
		var a: Vector2 = tri[0][1]
		var e1: Vector2 = tri[1][1] - a
		var e2: Vector2 = tri[2][1] - a
		var den := e1.cross(e2)
		var u := (at - a).cross(e2) / den
		var v := e1.cross(at - a) / den
		if u < -0.001 or v < -0.001 or u + v > 1.001:
			continue
		var ws := Vector3(1.0 - u - v, u, v)
		var best := -1
		var top := -1.0
		for j in 3:
			var w := ws[j]
			if of_point.has(tri[j][0]) and w > top:
				best = of_point[tri[j][0]]
				top = w
		if best >= 0:
			return best
	var near := 0
	for i in ring.size():
		if at.distance_squared_to(ring[i][0]) < at.distance_squared_to(ring[near][0]):
			near = i
	return near
