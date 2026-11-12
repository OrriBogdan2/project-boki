class_name WardenSteps
extends RefCounted
## When a Hero's walk and run put a foot down. Each loop's plant times (s into the clip: the sole touches down) are
## measured from the posed clip by tools/step_sync_check.gd (--write keeps content/anim/warden_steps.json); here
## the loop with the most weight in the loco blend leads, and a step fires on the update its playhead crosses one
## of its plants. WardenClips puts it on the root (WardenClips.STEP), HunterAnim.stepped reads it, Juice.footstep
## sounds it. A hand-off to another loop (a blend, a turn, a strafe) neither doubles a step nor drops one: no step
## sooner than GAP_MIN of the lead's shortest gap between plants, and a plant the new lead passed since the last
## step, no more than CATCH_UP of that gap ago, is played on the hand-off.

const PATH := "res://content/anim/warden_steps.json"
const GAP_MIN := 0.6     # x the lead loop's shortest plant gap: a step sooner than this is the one just played
const CATCH_UP := 0.5    # x the same: how late a hand-off may still play a plant the old lead did not reach

static var _table := {}

var loops := {}          # blend point -> {at: its place, len: s, plants: [s], short, long: s between plants}
var places: Array = []   # every blend point's place (the idle too)
var tris: Array = []     # the blend space's triangles, [a, b, c] blend points (Godot builds them deferred)
var space: AnimationNodeBlendSpace2D
var since := INF         # clip s the lead loops have played since the last step
var lead := -1           # the blend point leading on the last update
var gap := 0.0           # clip s between the last step and the one before (tools/step_sync_check.gd)

## The measured plants: {art: {clip: [s, ...]}}; `reread` after the file was rewritten.
static func table(reread := false) -> Dictionary:
	if (reread or _table.is_empty()) and FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_table = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _table

func _init(bs: AnimationNodeBlendSpace2D, lib: AnimationLibrary, art: String) -> void:
	space = bs
	var mine: Dictionary = table().get(art, {})
	for i in bs.get_blend_point_count():
		places.append(bs.get_blend_point_position(i))
		var clip := String((bs.get_blend_point_node(i) as AnimationNodeAnimation).animation)
		var plants: Array = mine.get(clip, [])
		if plants.is_empty() or not lib.has_animation(clip):
			continue
		var length := lib.get_animation(clip).length
		var gaps: Array = []
		for k in plants.size():
			var g := fposmod(float(plants[(k + 1) % plants.size()]) - float(plants[k]), length)
			gaps.append(g if g > 0.0 else length)
		loops[i] = {"at": places[i], "len": length, "plants": plants, "short": gaps.min(), "long": gaps.max()}

## Whether a foot came down on this update (after the tree advanced). `at`: the loco blend position; `on`: the
## loops are what the body shows (no move, air or crouch over them).
func tick(tree: AnimationTree, at: Vector2, on: bool) -> bool:
	var was_lead := lead
	lead = _heaviest(at)
	if lead < 0:
		return false
	var lp: Dictionary = loops[lead]
	var key := "parameters/loco/%d/" % lead
	var moved := float(tree.get(key + "current_delta"))
	since += moved
	if not on or moved <= 0.0:
		return false
	var length := float(lp["len"])
	var now := fposmod(float(tree.get(key + "current_position")), length)
	var ago := INF       # clip s since the lead's last plant
	for t in lp["plants"]:
		ago = minf(ago, fposmod(now - float(t), length))
	var owed := since >= GAP_MIN * float(lp["short"])
	if owed and (ago < moved or (lead != was_lead and since - ago >= GAP_MIN * float(lp["short"])
			and ago <= CATCH_UP * float(lp["short"]))):
		gap = since
		since = 0.0
		return true
	return false

## The loop the blend weighs most at `at` (Godot's interpolated BlendSpace2D: the triangle `at` lies in, else the
## nearest edge), or -1 when only the idle has weight.
func _heaviest(at: Vector2) -> int:
	if tris.is_empty():
		for t in space.get_triangle_count():
			tris.append([0, 1, 2].map(func(k: int) -> int: return space.get_triangle_point(t, k)))
	var w := {}
	for t in tris:
		var a: Vector2 = places[t[0]]
		var u: Vector2 = places[t[1]] - a
		var v: Vector2 = places[t[2]] - a
		var p := at - a
		var den := u.cross(v)
		if absf(den) < 1e-6:
			continue
		var wb := p.cross(v) / den
		var wc := u.cross(p) / den
		if wb >= -1e-4 and wc >= -1e-4 and wb + wc <= 1.0001:
			w = {t[0]: 1.0 - wb - wc, t[1]: wb, t[2]: wc}
			break
	if w.is_empty():
		var near := INF
		for t in tris:
			for e in 3:
				var a: Vector2 = places[t[e]]
				var b: Vector2 = places[t[(e + 1) % 3]]
				var on_edge := Geometry2D.get_closest_point_to_segment(at, a, b)
				if on_edge.distance_squared_to(at) < near:
					near = on_edge.distance_squared_to(at)
					var k := (on_edge - a).length() / maxf((b - a).length(), 1e-6)
					w = {t[e]: 1.0 - k, t[(e + 1) % 3]: k}
	var best := -1
	for i in w:
		if loops.has(i) and (best < 0 or float(w[i]) > float(w[best])):
			best = i
	return best
