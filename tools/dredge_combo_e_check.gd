extends RefCounted
## Grimble's sure-stun combo for --dredge-combo-check: Deep Reach on a foe at full range, then the Anchor Drop
## within 0.5 s of the foe landing at his feet. The foe is stunned every time and the Anchor never moves him.

const RUNS := 10
const MAX_MOVE := 0.3  # m: how far the Anchor may carry him
const E_DELAY := 0.5  # s after the reel ends by which E is pressed (varied per run, 0 .. E_DELAY)

var ak = null
var ok_fn: Callable


func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb


func run() -> void:
	var stunned := 0
	var worst_move := 0.0
	var why := ""
	for i in RUNS:
		var res: Array = await _one(i)
		stunned += 1 if bool(res[0]) else 0
		worst_move = maxf(worst_move, float(res[1]))
		if not bool(res[0]) and why == "":
			why = " (run %d: %s)" % [i, res[2]]
	ok_fn.call(
		"combo e: reel at full range, then E within 0.5 s stuns the foe, every run",
		stunned == RUNS,
		"%d / %d runs%s" % [stunned, RUNS, why]
	)
	ok_fn.call("combo e: the Anchor never moves him (under 0.3 m)", worst_move < MAX_MOVE, "worst %.2f m" % worst_move)


## One run: a dummy at full Deep Reach range stands still until it is hooked, then walks away as soon as it can;
## E is pressed `i / RUNS * E_DELAY` s after it lands. Returns [stunned by the slam, how far he moved, details].
func _one(i: int) -> Array:
	var r: Array = ak.setup("dredge", 11.0, "", false)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var foe: Hunter = r[2]
	var kit: DredgeKit = p.ak
	var flee := func(): foe.inp["move"] = Vector2(0, 1) if kit.grapples > 0 else Vector2.ZERO
	ak.aim_at(p, foe.pos)
	ak.tap(m, p)
	var t := 0.0
	while (kit.arrivals < 1 or not kit.pull.is_empty()) and t < 4.0:
		ak.step(m, ak.DT, flee)
		t += ak.DT
	var anchors := kit.anchors
	var hit_before: float = ak.dmg(foe)
	var gap := float(i) / float(RUNS) * E_DELAY
	ak.step(m, gap, flee)
	ak.aim_at(p, foe.pos)
	var from := p.pos
	kit.cd["e"] = 0.0
	kit.use_e()
	ak.step(m, 0.5, flee)
	var moved := p.flat_dist(from)
	var took: float = ak.dmg(foe) - hit_before
	var got: bool = kit.grapples == 1 and kit.anchors == anchors + 1 and took > 20.0 and foe.stun_t > 0.5
	var info := (
		"grabs %d arrivals %d anchors +%d took %.0f stun %.2f gap %.2f"
		% [kit.grapples, kit.arrivals, kit.anchors - anchors, took, foe.stun_t, gap]
	)
	await ak.done(m)
	return [got, moved, info]
