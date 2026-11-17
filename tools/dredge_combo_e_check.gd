extends RefCounted
## Grimble's sure-stun combo for --dredge-combo-check: Deep Reach on a foe at full range, then the Anchor Drop
## within 0.5 s of the foe landing at his feet. The foe is stunned every time and the Anchor never moves him.

const RUNS := 10
const MAX_MOVE := 0.3        # m: how far the Anchor may carry him
const E_DELAY := 0.5         # s after the reel ends by which E is pressed (varied per run, 0 .. E_DELAY)

var ak = null
var ok_fn: Callable

func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb

func run() -> void:
	var stunned := 0
	var worst_move := 0.0
	for i in RUNS:
		var res: Array = await _one(i)
		stunned += 1 if bool(res[0]) else 0
		worst_move = maxf(worst_move, float(res[1]))
	ok_fn.call("combo e: reel at full range, then E within 0.5 s stuns the foe, every run", stunned == RUNS,
			"%d / %d runs" % [stunned, RUNS])
	ok_fn.call("combo e: the Anchor never moves him (under 0.3 m)", worst_move < MAX_MOVE, "worst %.2f m" % worst_move)

## One run: the foe walks away as soon as it can; E is pressed `i / RUNS * E_DELAY` s after it lands.
## Returns [stunned by the slam, how far he moved during the E].
func _one(i: int) -> Array:
	var r: Array = ak.setup("dredge", 11.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: DredgeKit = P.ak
	ak.aim_at(P, T.pos)
	ak.tap(m, P)
	var t := 0.0
	while (K.arrivals < 1 or not K.pull.is_empty()) and t < 4.0:
		ak.step(m, ak.DT, func(): T.inp["move"] = Vector2(0, 1))
		t += ak.DT
	var anchors := K.anchors
	var hit_before := ak.dmg(T)
	var gap := float(i) / float(RUNS) * E_DELAY
	ak.step(m, gap, func(): T.inp["move"] = Vector2(0, 1))
	ak.aim_at(P, T.pos)
	var from := P.pos
	K.cd["e"] = 0.0
	P.ak.use_e()
	ak.step(m, 0.5, func(): T.inp["move"] = Vector2(0, 1))
	var moved := P.flat_dist(from)
	var got := K.anchors == anchors + 1 and ak.dmg(T) > hit_before + 20.0 and T.stun_t > 0.5
	await ak.done(m)
	return [got, moved]
