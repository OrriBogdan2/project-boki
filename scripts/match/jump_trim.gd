class_name JumpTrim
extends RefCounted
## A jump taken faster across the ground than HunterMove.jump_trim_in.x (a dash-jump) sheds the excess over ~0.3 s
## to a speed between jump_trim_to's ends, by how fast it left ([game data]: a critically damped spring at rate
## jump_trim_k). A dash-jump is a short quick hop, never a long sprint through the air. Only a jump arms it;
## landing, a dash, a mantle or the glider opening ends it. The match hunter and the farm avatar each hold one.

var target := -1.0  # m/s the trim settles at (-1: off)
var _rate := 0.0  # m/s^2, the spring's own speed, carried between steps


## Arms the trim for a jump leaving the ground at horizontal velocity `hv`.
func start(hv: Vector2) -> void:
	var s := hv.length()
	var lo := HunterMove.jump_trim_in
	var to := HunterMove.jump_trim_to
	target = -1.0
	_rate = 0.0
	if s > lo.x:
		target = minf(lerpf(to.x, to.y, clampf((s - lo.x) / (lo.y - lo.x), 0.0, 1.0)), s)


## `hv` after one step's trim. `airborne` false (on the ground, gliding, dashing, mantling) ends it.
func step(hv: Vector2, airborne: bool, dt: float) -> Vector2:
	if target < 0.0:
		return hv
	var s := hv.length()
	if not airborne or s <= target:
		target = -1.0
		return hv
	var w := sqrt(HunterMove.jump_trim_k)
	var e := exp(-w * dt)
	var x := s - target
	var c := (x * w + _rate) * dt
	_rate = (_rate - c * w) * e
	return hv * ((target + (x + c) * e) / s)
