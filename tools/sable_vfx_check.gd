extends RefCounted
## --sable-vfx-check: Sable's Bola and Shadow Knife hit looks (content/vfx/thief.json): the wrap, the tangle and the
## knife's stick each carry a hollow lit ring (a ground ring means gameplay: the knife's is the blink's arrival
## circle, `e.ring_r`, sent as the move's `r`), and the moves play.
## --sable-vfx-perf: the cost of those looks on a real GPU, a 4v4 fight with the three moves fired every
## SPAM_EVERY frames (far more often than a match does) with their recipes off and on (SABLEVFX rows; p95, ms).

const DT := 1.0 / 60.0
const WARM := 30  # frames dropped before timing
const TIMED := 120  # frames timed per block
const ROUNDS := 4  # off/on blocks alternated, so a drifting box loads both sides alike
const SPAM_EVERY := 6  # frames between two plays
const MOVES := ["bola_wrap", "bola_tangle", "knife_stick"]

var bad := 0
var main: Node
var m: Match
var pl: Hunter


func ok(cond: bool, what: String) -> void:
	print("SABLEVFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(root: Node, mode: String = "check") -> void:
	main = root
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	await m.start(
		{
			"teams": 2,
			"squad": 4 if mode == "perf" else 1,
			"tier": 0,
			"length": 1e9,
			"seed": 4242,
			"arch": "thief",
			"cls": Arch.weight("thief"),
			"weapon": Arch.signature("thief")
		}
	)
	m.set_process(false)
	pl = m.player
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if mode == "perf":
		await _perf()
	else:
		_check()
	print("SABLEVFX DONE, failures: %d" % bad)


func _check() -> void:
	var moves: Dictionary = HeroVfx.data("thief")["moves"]
	for mv: String in MOVES:
		var rings: Array = (moves[mv]["fx"] as Array).filter(
			func(l): return l["p"] == "ring" and l.get("hollow", false)
		)
		ok(rings.size() == 1, "%s has one hollow ring" % mv)
	var r_data: float = Arch.def("thief")["e"]["ring_r"]
	ok(moves["knife_stick"]["fx"].any(func(l): return str(l.get("size")) == "r"), "the stick ring takes the move's r")
	ok(r_data == 2.7, "the knife's arrival ring is the source's 1.5 bh radius (2.7 m)")
	var hv := HeroVfx.of(m)
	for mv: String in MOVES:
		hv.play(pl, mv, pl.pos + Vector3(3, 0, 0), Vector2.RIGHT, {"foe": true, "r": r_data})
		ok(int(hv.plays.get(mv, 0)) == 1, "%s plays" % mv)


func _perf() -> void:
	for h in m.hunters:
		h.ctrl = "idle"
	var foes: Array = m.hunters.filter(func(x): return x.team != pl.team)
	for i in foes.size():
		foes[i].teleport(pl.pos + Vector3(6.0 + 2.0 * (i % 2), 0.0, -4.0 + 2.5 * i))
	await _go(WARM, foes)
	var moves: Dictionary = HeroVfx.data("thief")["moves"]
	var kept := {}
	for mv: String in MOVES:
		kept[mv] = moves[mv]
	var off: Array = []
	var on: Array = []
	for r in ROUNDS:
		for mv: String in MOVES:
			moves[mv] = {}
		off.append_array(await _frame_ms(foes))
		for mv: String in MOVES:
			moves[mv] = kept[mv]
		on.append_array(await _frame_ms(foes))
	var row := "SABLEVFX frame ms (%d frames each) off p95 %.2f | on p95 %.2f | delta p95 %.2f"
	print(row % [off.size(), _p95(off), _p95(on), _p95(on) - _p95(off)])


func _frame_ms(foes: Array) -> Array:
	await _go(WARM, foes)
	var ts: Array = []
	var last := Time.get_ticks_usec()
	for i in TIMED:
		await _go(1, foes)
		var now := Time.get_ticks_usec()
		ts.append(float(now - last) / 1000.0)
		last = now
	return ts


func _p95(ts: Array) -> float:
	var s := ts.duplicate()
	s.sort()
	return s[int(s.size() * 0.95)]


func _go(frames: int, foes: Array) -> void:
	var hv := HeroVfx.of(m)
	for i in frames:
		if int(m.time / DT) % SPAM_EVERY == 0:
			var f: Hunter = foes[int(m.time / DT / SPAM_EVERY) % foes.size()]
			hv.play(
				pl, MOVES[int(m.time / DT / SPAM_EVERY) % MOVES.size()], f.pos, Vector2.RIGHT, {"foe": true, "r": 2.7}
			)
		m.step(DT)
		m.cam.snap(pl.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame
