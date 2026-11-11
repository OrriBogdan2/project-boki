extends RefCounted
## --rock-feet-check: Tenzo's feet on his own rocks, through the real match path (Match.step, Hunter.render,
## HunterAnim, FootPlant, the .glb's Sync with legs_rigid). He stands on a Stone Row rock, walks along a cast Basalt
## Spine ridge and steps between rocks whose bases differ (a stair's rise, a terrace), while a twin of his model on
## flat ground plays his exact animation state (Hunter.anim_s) unplanted. Per grounded frame, the weight-bearing
## ankle's height over the surface under it (the rock's top he stands on, StoneStand) is held against the twin's
## over its ground: within GAP. Also
## prints how far the soles sit above the craggy crown's mesh (RockLook) for the report; not asserted. Never
## touches the save.

const DT := 1.0 / 60.0
const GAP := 0.04              # m: the most a planted foot may float over or sink into the surface it stands on
const DOWN := 0.02             # m: the twin's lower ankle within this of its lowest nearby is the weight-bearing foot
const STRIDE := 10             # frames either side looked at for that lowest (about a stride)
const SETTLE := 30             # frames before measuring a stand (planting eases in at FootPlant.RATE)
const WALK_T := 2.0            # s: the most each stand or walk is measured
const STAIR := 0.25            # m: a stair's rise between two rocks' bases (within FootPlant's reach)
const TERRACE := World.LEVEL   # m: a terrace between two rocks' bases (a climb, beyond the reach)
const FRAMES := 3              # the fewest weight-bearing frames a stand or walk must score
const JUMP := 0.1              # m: the most the drawn body may rise or fall in one frame while he walks on the ground

var A
var bad := 0
var m: Match
var P: Hunter
var twin: Node3D               # his model's twin on the flat strip, posed by twin_anim from his anim_s
var twin_anim: HunterAnim
var home := Vector3.ZERO

func ok(cond: bool, what: String) -> void:
	print("ROCKFEET %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("dolm", 14.0)
	m = r[0]
	P = r[1]
	home = r[4]
	(r[2] as Hunter).teleport(home + Vector3(0, 0, -40))      # (the target dummy: out of the way)
	var look := PlayerLook.neutral()
	twin = Models.hunter(Arch.weight("dolm"), Data.TEAM_COLORS[0], Arch.signature("dolm"), "", look, "dolm")
	twin.set_meta("anim_seed", int(P.model.get_meta("anim_seed", P.model.get_instance_id())))
	m.add_child(twin)
	twin_anim = HunterAnim.new(twin)
	ok(bool(WardenClips.data("tarek").get("legs_rigid", false)), "Tenzo's warden_anim map has legs_rigid")
	_stand_row()
	_ridge_walk()
	_steps()
	print("ROCK_FEET_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Stone Row ahead; he stands on its middle rock, still.
func _stand_row() -> void:
	A.aim_at(P, home + Vector3(6, 0, 0))
	P.ak.cd["e"] = 0.0
	P.ak.use_e()
	_rise(0.6)
	var row := _rocks()
	row.sort_custom(func(a, b): return _mid(a).x < _mid(b).x)
	var mid: Dictionary = row[row.size() / 2]
	_place(_mid(mid) + Vector3(0, float(mid["top"]), 0))
	_score("stand on a Stone Row rock", Vector2.ZERO, SETTLE)

## Basalt Spine across his aim; he walks its length from one end rock to the other, steering along the arc.
func _ridge_walk() -> void:
	_clear()
	A.aim_at(P, home + Vector3(6, 0, -5))
	P.ak.cd["x"] = 0.0
	P.lvl = 6
	P.inp["x_down"] = false
	HunterKeys.ult_pressed(P)
	_rise(1.0)
	var ridge := _rocks()
	ridge.sort_custom(func(a, b): return _mid(a).x < _mid(b).x)
	ok(ridge.size() >= 9, "Basalt Spine stands (%d rocks)" % ridge.size())
	var first: Dictionary = ridge[1]
	_place(_mid(first) + Vector3(0, float(first["top"]), 0))
	var last := _mid(ridge[-2]).x
	_score("walk along the Basalt Spine ridge", func(): return _along(ridge), SETTLE, func(): return P.pos.x > last)

## Five rocks end to end, the last four a stair's rise (then a terrace) above the first; he walks from the first
## onto the last and back.
func _steps() -> void:
	for rise in [STAIR, TERRACE]:
		_clear()
		var at := home + Vector3(3, 0, 0)
		for i in 5:
			var base := at + Vector3(1.3 * i, rise * mini(i, 1), 0)
			HeroZones.rock(m, P, base, Vector2(0, 1), "rf.%d" % i, 1.3, 99.0, 45.0, false)
		_rise(0.4)
		_place(at + Vector3(-0.2, HeroZones.ROCK_TOP, 0))
		var end := at.x + 5.0
		_score("step up onto a rock %.2f m higher" % rise, Vector2(1, 0), SETTLE, func(): return P.pos.x > end, true)
		_score("step down onto a rock %.2f m lower" % rise, Vector2(-1, 0), 0, func(): return P.pos.x < at.x)

## Steps frames (after `settle` unscored), moving both along the move `how` gives (a Vector2, or a Callable
## returning one), until `stop` returns true (at most WALK_T), and asserts the weight-bearing foot's gap over the
## surface it stands on. A foot out over a drop (past FootPlant's reach) stands on nothing and is not scored.
## step: also asserts the step is smooth: the drawn body never pops up or down and FootPlant plants every grounded
## frame he is not landing (Hunter.step_vis, StoneStand.stand). Prints the crown mesh's gap too.
func _score(what: String, how: Variant, settle: int, stop := Callable(), step := false) -> void:
	for f in settle:
		_frame(Vector2.ZERO)
	var seen: Array = []          # per grounded frame: [twin's lower ankle height, his miss]
	var crown := [INF, -INF]       # the crown's mesh under the planted ankle: nearest and farthest, m
	var jump := 0.0               # the drawn body's biggest move up or down in a grounded frame
	var unplanted := 0            # grounded frames FootPlant left alone
	var was := P.position.y
	for f in int(WALK_T / DT):
		if stop.is_valid() and stop.call():
			break
		_frame(_move(how))
		var grounded := P.grounded and P.pos.y - P.ground() <= 0.01
		if grounded:
			jump = maxf(jump, absf(P.position.y - was))
			unplanted += 1 if P.anim.feet.weight < 0.01 and P.anim.air_k < 0.01 else 0
		was = P.position.y
		if not grounded:
			continue
		var t_ank := _ankles(twin)
		var low := 0 if (t_ank[0] as Vector3).y < (t_ank[1] as Vector3).y else 1
		var clip: float = (t_ank[low] as Vector3).y - home.y
		var ank: Vector3 = _ankles(P.model)[low]
		var under := _surface(ank)
		if under - P.pos.y <= -FootPlant.REACH_DOWN or under - P.pos.y >= FootPlant.REACH_UP:
			continue
		seen.append([clip, absf(ank.y - under - clip)])
		var c := _crown_gap(ank) - clip
		crown = [minf(crown[0], c), maxf(crown[1], c)]
	var worst := 0.0
	var scored := 0
	for i in seen.size():
		var lowest := INF
		for j in range(maxi(0, i - STRIDE), mini(seen.size(), i + STRIDE + 1)):
			lowest = minf(lowest, float(seen[j][0]))
		if float(seen[i][0]) < lowest + DOWN:
			worst = maxf(worst, float(seen[i][1]))
			scored += 1
	ok(scored >= FRAMES and worst < GAP, "%s: planted foot %.3f m off the surface (limit %.2f, %d frames)"
		% [what, worst, GAP, scored])
	if step:
		ok(jump < JUMP and unplanted == 0, "%s: the body eases up, no pop (%.3f m in a frame, limit %.2f), feet planted"
			% [what, jump, JUMP] + " throughout (%d frames not)" % unplanted)
	print("ROCKFEET info %s: the crags' mesh lies %+.2f..%+.2f m under the foot (not asserted)"
		% [what, crown[0], crown[1]])

func _move(how: Variant) -> Vector2:
	return (how as Callable).call() if how is Callable else how as Vector2

## Toward the next ridge rock's middle past him, so the walk follows the arc.
func _along(ridge: Array) -> Vector2:
	for w in ridge:
		var to := _mid(w) - P.pos
		if to.x > 0.6:
			return Vector2(to.x, to.z).normalized()
	return Vector2(1, 0)

## One frame: the match, him rendered (HunterAnim, FootPlant, Sync), then his twin posed from the same state.
func _frame(move: Vector2) -> void:
	P.inp["move"] = move
	m.step(DT)
	P.render(DT, 1.0)
	twin.global_transform = Transform3D(P.model.global_basis, Vector3(P.position.x, home.y, P.position.z + 8.0))
	twin_anim.update(DT, P.anim_s)
	for body in [P.model, twin]:
		var sync: Node = (body as Node3D).get_node("Warden/Sync")
		sync.set_process(false)
		sync.call("_process", DT)

## Both ankles (the shins' ends) of a body in world space.
func _ankles(body: Node3D) -> Array:
	var sk := WardenGlb.skeleton(body.get_node("Warden"))
	var sync: Node = body.get_node("Warden/Sync")
	var legs: PackedInt32Array = sync.get("leg_bones")
	return [sk.global_transform * FootPlant.ankle(sk, legs[0], legs[1]),
		sk.global_transform * FootPlant.ankle(sk, legs[2], legs[3])]

## The surface under p he stands on: a rock's top within his step of the body (StoneStand), else the terrain.
func _surface(p: Vector3) -> float:
	return StoneStand.top_under(m.world.dyn_walls, Vector3(p.x, P.pos.y, p.z), 0.0, m.world.ground_at(p.x, p.z))

## How far p sits above the crown's mesh (or the terrain) under it.
func _crown_gap(p: Vector3) -> float:
	var g := m.world.ground_at(p.x, p.z)
	for w in _rocks():
		for mm in (w["node"] as Node3D).find_children("*", "MeshInstance3D", true, false):
			if not (mm as Node).get_parent().name.begins_with("Col"):
				continue
			var xf := (mm as MeshInstance3D).global_transform
			var inv := xf.affine_inverse()
			var faces := (mm as MeshInstance3D).mesh.get_faces()
			for t in range(0, faces.size(), 3):
				var hit = Geometry3D.ray_intersects_triangle(inv * (p + Vector3(0, 3, 0)), inv.basis * Vector3.DOWN,
					faces[t], faces[t + 1], faces[t + 2])
				if hit != null:
					g = maxf(g, (xf * (hit as Vector3)).y)
	return p.y - g

func _rocks() -> Array:
	return m.verbs.walls.filter(func(w): return w.has("top") and is_instance_valid(w.get("node")))

func _mid(w: Dictionary) -> Vector3:
	var c: Vector2 = ((w["a"] as Vector2) + (w["b"] as Vector2)) * 0.5
	return Vector3(c.x, float(w["y"]), c.y)

## Lets the rocks rise: the match steps `secs` and the rise tweens (scene-tree driven, idle here) are run to the end.
func _rise(secs: float) -> void:
	for f in int(secs / DT):
		_frame(Vector2.ZERO)
	for tw in m.get_tree().get_processed_tweens():
		tw.custom_step(1.0)

func _clear() -> void:
	for w in _rocks():
		HeroZones.remove_rock(m, w, false)

## Him at `at`, still, on the ground there.
func _place(at: Vector3) -> void:
	P.teleport(at)
	P.vel = Vector3.ZERO
	P.grounded = true
