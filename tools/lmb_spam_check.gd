extends RefCounted
## --lmb-spam-check: mashing LMB never beats playing it as meant (docs/MOVEMENT_FEEL.md "LMB: mash vs hold"). Each
## of the 12 Hunters in the training strip shoots an idle dummy pinned 3 m off for 3 s, and the hits and damage are
## counted through CombatBus.hit_landed (and 1 s after the key comes up: rounds in flight, a draw loosed on the
## release). The 20 Hz clicks (one frame down two up, and two down one up) may beat the best of these by at most one
## shot (the most damage any run landed in one frame):
## - held: the key down the whole 3 s;
## - cycles: hold-and-release cycles of 0.7, 1.0 and 1.3 s (a charge only goes on the release);
## - taps: 50 ms presses in a steady rhythm of 0.2 to 0.6 s (a weapon whose tap is its own move, at its cadence).
## A draw weapon (Lace's bow) looses nothing to the clicks: a release inside its draw_min restarts the draw.

const AKCheck := preload("res://tools/archetype_check.gd")
const RUN_F := 180          # frames (3 s) the key is held or mashed
const TAIL_F := 60          # frames (1 s) counted after it comes up
const DIST := 3.0           # m to the dummy: inside every primary's reach
const CYCLES := [42, 60, 78]      # frames down per hold-and-release cycle, one frame up
const TAP_F := 3            # frames down in a deliberate tap (50 ms)
const TAP_EVERY := [12, 15, 18, 21, 24, 27, 30, 33, 36]      # frames between deliberate taps (0.2-0.6 s)
const CLICKS := [1, 2]      # frames down out of every 3 (20 Hz at 60 fps): a short and a long press

var A: AKCheck
var bad := 0
var _tally := {}

func run(main: Node) -> void:
	A = AKCheck.new()
	A.main = main
	CombatBus.hit_landed.connect(_on_hit)
	print("LMBSPAM %-8s %9s | %-16s | %9s | %5s" % ["hunter", "held", "best (how)", "clicks", "shot"])
	for arch in Arch.ORDER:
		await _hunter(arch)
	print("LMBSPAM DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hunter(arch: String) -> void:
	var held: Dictionary = await _measure(arch, func(f: int) -> bool: return true)
	var best := held
	var how := "held"
	for c in CYCLES:
		var r: Dictionary = await _measure(arch, func(f: int) -> bool: return f % (c + 1) < c)
		if float(r["dmg"]) > float(best["dmg"]):
			best = r
			how = "cycle %.1fs" % (c * A.DT)
	for e in TAP_EVERY:
		var r: Dictionary = await _measure(arch, func(f: int) -> bool: return f % e < TAP_F)
		if float(r["dmg"]) > float(best["dmg"]):
			best = r
			how = "tap /%.1fs" % (e * A.DT)
	var clicks := {"hits": 0, "dmg": -1.0, "shot": 0.0}
	for d in CLICKS:
		var r: Dictionary = await _measure(arch, func(f: int) -> bool: return f % 3 < d)
		if float(r["dmg"]) > float(clicks["dmg"]):
			clicks = r
	var shot := maxf(float(best["shot"]), float(clicks["shot"]))
	var fair: bool = float(clicks["dmg"]) <= float(best["dmg"]) + shot + 0.01
	if bool(held["draw"]) and int(clicks["hits"]) > 0:
		fair = false         # charge weapons ignore early taps (the source): mashing a bow looses no arrows
	print("LMBSPAM %-8s %3d %5.0f | %3d %5.0f %-6s | %3d %5.0f | %5.0f %s" % [HeroTitle.base_name(arch),
			held["hits"], held["dmg"], best["hits"], best["dmg"], how, clicks["hits"], clicks["dmg"], shot,
			"ok" if fair else "FAIL"])
	if not fair:
		bad += 1

## One run: `down` says whether the key is down on frame f of the 3 s. {hits, dmg, shot (the most in one frame)}
func _measure(arch: String, down: Callable) -> Dictionary:
	var r := A.setup(arch, DIST)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var spot: Vector3 = T.pos
	_tally = {"by": P, "on": T, "hits": 0, "dmg": 0.0, "frame": 0.0, "shot": 0.0, "draw": P.wpn.has("draw")}
	for f in RUN_F + TAIL_F:
		P.inp["fire"] = f < RUN_F and down.call(f)
		A.aim_at(P, spot)
		T.hp = T.max_hp      # never dies and never knocked out of reach; damage is summed from the hits
		T.teleport(spot)
		T.vel = Vector3.ZERO
		_tally["frame"] = 0.0
		m.step(A.DT)
		_tally["shot"] = maxf(float(_tally["shot"]), float(_tally["frame"]))
	await A.done(m)
	return _tally.duplicate()

func _on_hit(by: Node, target: Node, amount: float, _tags: Array) -> void:
	if _tally.is_empty() or by != _tally["by"] or target != _tally["on"]:
		return
	_tally["hits"] = int(_tally["hits"]) + 1
	_tally["dmg"] = float(_tally["dmg"]) + amount
	_tally["frame"] = float(_tally["frame"]) + amount
