extends RefCounted
## The scattergun's burst for --dredge-combo-check (docs/heroes/dredge.md): the first volley of a
## burst flies straight down the aim line, the next ones fan out, a short pause keeps the fan, and after the
## 0.7 s reset beat the next volley is aimed again.

const SHORT_PAUSE := 0.3            # s off the trigger, under the reset beat (rate 0.5 + 0.2)
const LONG_PAUSE := 1.0             # s off the trigger, past the reset beat

var ak = null
var ok_fn: Callable

func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb

func ok(label: String, cond: bool, info := "") -> void:
	ok_fn.call(label, cond, info)

func run() -> void:
	var r: Array = ak.setup("dredge", 9.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	T.teleport(P.pos + Vector3(0, 0, 9.0))
	var spreads: Array = []         # per volley: the widest slug's angle off the aim line, in degrees
	spreads.append_array(_hold(m, P, 3))
	_release(m, P, SHORT_PAUSE)
	spreads.append_array(_hold(m, P, 1))
	_release(m, P, LONG_PAUSE)
	spreads.append_array(_hold(m, P, 1))
	var info := str(spreads)
	ok("gun: the first volley of a burst flies straight down the aim line", spreads[0] < 0.5, info)
	ok("gun: the volleys after it fan out", spreads[1] > 10.0 and spreads[2] > spreads[1], info)
	ok("gun: a short pause keeps the fan", spreads[3] > 10.0, info)
	ok("gun: after a pause past the reset beat the next volley is aimed again", spreads[4] < 0.5, info)
	await ak.done(m)

## Holds fire on the east until `count` new volleys leave; returns each one's widest angle off the aim line.
func _hold(m: Match, P: Hunter, count: int) -> Array:
	var out: Array = []
	var seen := P.shot_n
	var t := 0.0
	while out.size() < count and t < 3.0:
		ak.aim_at(P, P.pos + Vector3(2.0, 0, 0))
		P.inp["fire"] = true
		m.step(ak.DT)
		t += ak.DT
		if P.shot_n != seen:
			seen = P.shot_n
			out.append(_widest(m, P, "%s_%d" % [P.nid, P.shot_n]))
	P.inp["fire"] = false
	return out

func _release(m: Match, P: Hunter, secs: float) -> void:
	P.inp["fire"] = false
	ak.step(m, secs)

func _widest(m: Match, P: Hunter, pg: String) -> float:
	var aim := P.aim_dir()
	var widest := 0.0
	for sd in m.shots:
		if sd["by"] == P and String((sd["x"] as Dictionary).get("pg", "")) == pg:
			widest = maxf(widest, absf(rad_to_deg(aim.angle_to(sd["vel"] as Vector2))))
	return widest
