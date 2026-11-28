extends RefCounted
## --sable-vfx-check: Sable's Bola and Shadow Knife hit looks: the wrap, the tangle and the knife's stick each play
## their hit frame (content/vfx/thief.json) and put a lit AimKit rim on the ground that everyone sees (a ground ring
## means gameplay: the knife's is the blink's arrival circle, `e.ring_r` 2.7 m, kept while the dagger stays).
## --sable-vfx-perf: the cost of those looks on a real GPU, a 4v4 fight with the wrap, tangle and stick looks (hit
## frame recipe and its rim; the stick leaves a stuck dagger with its arrival ring) fired every SPAM_EVERY frames,
## far more often than a match does, against the same fight with nothing fired (SABLEVFX rows; p95, ms).

const DT := 1.0 / 60.0
const WARM := 30  # frames dropped before timing
const TIMED := 120  # frames timed per block
const ROUNDS := 6  # off/on blocks alternated, so a drifting box loads both sides alike
const REBUILDS := 400  # AimDraw rebuilds timed per side for the rims' own cost
const SPAM_EVERY := 6  # frames between two plays
const MOVES := ["bola_wrap", "bola_tangle", "knife_stick"]

var bad := 0
var main: Node
var m: Match
var pl: Hunter
var spam := false  # _go fires the three moves


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
	main.get_tree().quit(1 if bad > 0 else 0)


func _check() -> void:
	var kit = pl.ak
	var foe: Hunter = m.hunters.filter(func(x): return x.team != pl.team)[0]
	foe.teleport(pl.pos + Vector3(4, 0, 0))
	var hv := HeroVfx.of(m)
	kit._throw_bola()  # the Bola in flight (its stage), as a real throw leaves it
	kit._wrap(foe)
	_ring_ok("bola_wrap", ThiefKit.WRAP_RING_R)
	kit._tangle(null, foe)
	_ring_ok("bola_tangle0", ThiefKit.TANGLE_RING_R)
	var r_data: float = Arch.def("thief")["e"]["ring_r"]
	ok(r_data == 2.7, "the knife's arrival ring is the source's 1.5 bh radius (2.7 m)")
	kit._stick(foe, foe.pos)
	kit._tick_knife()
	_ring_ok("e_ring", r_data)
	for mv: String in MOVES:
		ok(int(hv.plays.get(mv, 0)) >= 1, "%s plays" % mv)
	ok(not (HeroVfx.data("thief")["moves"] as Dictionary).values().any(
			func(rec): return (rec.get("fx", []) as Array).any(func(l): return l["p"] == "ring")),
		"no shockwave ring layer in Sable's looks (the rims are AimKit's)")


func _ring_ok(id: String, r: float) -> void:
	var e := AimKit.entry(pl, id)
	var rim := not e.is_empty() and is_equal_approx(float(e["r"]), r) and bool(e["all"]) and bool(e["soft"])
	ok(rim and not bool(e["tell"]),
		"%s: a soft lit rim of %.1f m everyone sees, no TellCue wind-up" % [id, r])


func _perf() -> void:
	for h in m.hunters:
		h.ctrl = "idle"
	var foes: Array = m.hunters.filter(func(x): return x.team != pl.team)
	for i in foes.size():
		foes[i].teleport(pl.pos + Vector3(6.0 + 2.0 * (i % 2), 0.0, -4.0 + 2.5 * i))
	await _go(WARM, foes)
	var off: Array = []
	var on: Array = []
	var deltas: Array = []
	for r in ROUNDS:
		spam = false
		var o: Array = await _frame_ms(foes)
		spam = true
		var n: Array = await _frame_ms(foes)
		off.append_array(o)
		on.append_array(n)
		deltas.append("%.2f" % (_p95(n) - _p95(o)))
	var row := "SABLEVFX frame ms (%d frames each) off p95 %.2f | on p95 %.2f | delta p95 %.2f (per round: %s)"
	print(row % [off.size(), _p95(off), _p95(on), _p95(on) - _p95(off), ", ".join(deltas)])
	spam = false
	_rims_cost(foes)


## The rims' own CPU cost, free of the box's noise: AimDraw's rebuild (it runs every frame) timed REBUILDS times
## with the wrap, tangle and knife rims up and with them gone (SABLEVFX rims row, microseconds per frame).
func _rims_cost(foes: Array) -> void:
	var kit = pl.ak
	var d := AimKit.layer(m)
	var f: Hunter = foes[0]
	var up := func():
		kit._hit_ring("bola_wrap", f.pos, ThiefKit.WRAP_RING_R)
		kit._hit_ring("bola_tangle0", foes[1].pos, ThiefKit.TANGLE_RING_R)
		kit.knife = {"target": f, "pos": f.pos, "dir": Vector2.RIGHT}
		kit._tick_knife()
	var cost := [0.0, 0.0]
	for r in REBUILDS:
		for side in 2:
			kit.knife = {}
			for id in ["bola_wrap", "bola_tangle0", "e_ring"]:
				AimKit.hide(pl, id)
			var t0 := Time.get_ticks_usec()
			if side == 1:
				up.call()
			d.rebuild()
			cost[side] += float(Time.get_ticks_usec() - t0)
	kit.knife = {}
	var row := "SABLEVFX rims us/frame (%d rebuilds each): off %.1f | on %.1f | delta %.1f"
	print(row % [REBUILDS, cost[0] / REBUILDS, cost[1] / REBUILDS, (cost[1] - cost[0]) / REBUILDS])


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
	var kit = pl.ak
	for i in frames:
		var n := int(m.time / DT)
		if spam and n % SPAM_EVERY == 0:
			var f: Hunter = foes[(n / SPAM_EVERY) % foes.size()]
			match (n / SPAM_EVERY) % 3:
				0:
					kit.vfx("bola_wrap", f.pos)
					kit._hit_ring("bola_wrap", f.pos, ThiefKit.WRAP_RING_R)
				1:
					kit.vfx("bola_tangle", f.pos)
					kit._hit_ring("bola_tangle0", f.pos, ThiefKit.TANGLE_RING_R)
				2:
					kit.vfx("knife_stick", f.pos, null, {"foe": true})
					kit.knife = {"target": f, "pos": f.pos, "dir": Vector2.RIGHT}  # its ring rides it from here
		if not spam:
			kit.knife = {}
		m.step(DT)
		m.cam.snap(pl.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame
