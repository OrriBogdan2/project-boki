extends RefCounted
## --status-edge-check: the screen-edge status tint (StatusEdge) follows the local player: nothing at rest, blue when
## stunned or knocked, yellow when untouchable for INV_MIN s or more (a dash's short invulnerability stays clean),
## stun first when both, hidden for a hunter that is out, and the layer's rect shows only while a status runs.
## --status-edge-shots --shots-dir=<dir>: the same moments at match camera on a real GPU, plus the frame time of a
## 4v4 fight with the tint off and on (SEDGE rows; p95 and mean in ms).

const DT := 1.0 / 60.0
const WARM := 30  # frames dropped before timing
const TIMED := 120  # frames timed per block
const ROUNDS := 4  # off/on blocks alternated, so a drifting box loads both sides alike
const PX := Vector2i(1920, 1080)  # the shots' size

var bad := 0
var main: Node
var m: Match
var pl: Hunter
var dir := ""


func ok(cond: bool, what: String) -> void:
	print("SEDGE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(root: Node, mode: String = "check") -> void:
	main = root
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	if mode == "shots":
		main.get_window().size = PX
	m = Match.new()
	main.add_child(m)
	var squad := 4 if mode == "shots" else 1
	await m.start({"teams": 2, "squad": squad, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	pl = m.player
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if mode == "shots":
		await _shots()
	else:
		await _check()
	print("SEDGE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _clear() -> void:
	pl.stun_t = 0.0
	pl.knock_t = 0.0
	pl.inv_t = 0.0
	pl.cloak_t = 0.0
	pl.out = false
	if pl.has_meta("gnd_until"):
		pl.remove_meta("gnd_until")


func _check() -> void:
	_clear()
	ok(StatusEdge.want(pl)[1] == 0.0, "no status, no tint")
	pl.inv_t = 0.14
	ok(StatusEdge.want(pl)[1] == 0.0, "a dash's short invulnerability stays clean")
	pl.inv_t = 1.5
	var w := StatusEdge.want(pl)
	ok(w[0] == StatusEdge.INVULN and w[1] > 0.0, "a revive's 1.5 s is the yellow edge")
	pl.stun_t = 1.0
	w = StatusEdge.want(pl)
	ok(w[0] == StatusEdge.STUN, "stun wins over untouchable")
	pl.stun_t = 0.0
	pl.inv_t = 0.0
	pl.knock_t = 0.5
	ok(StatusEdge.want(pl)[0] == StatusEdge.STUN, "knocked up is the blue edge")
	pl.knock_t = 0.0
	pl.cloak_t = 2.0
	ok(StatusEdge.want(pl)[0] == StatusEdge.CLOAK, "cloaked is the dark blue edge")
	pl.out = true
	ok(StatusEdge.want(pl)[1] == 0.0, "a hunter that is out shows nothing")
	_clear()
	var edge: StatusEdge = m.get_node("StatusEdge")
	edge.set_process(false)  # ticked by hand below
	pl.stun_t = 5.0
	for i in 40:
		edge.tick(pl, DT)
	ok(edge.rect.visible and edge.k > 0.8, "the rect shows and the strength climbs under stun")
	pl.stun_t = 0.0
	for i in 90:
		edge.tick(pl, DT)
	ok(not edge.rect.visible, "it hides again once the stun is over")
	edge.tick(null, DT)
	ok(not edge.rect.visible, "no local player, no tint")


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for h in m.hunters:
		h.ctrl = "idle"
	var foes: Array = m.hunters.filter(func(x): return x.team != pl.team)
	for i in foes.size():
		foes[i].teleport(pl.pos + Vector3(6.0 + 2.0 * (i % 2), 0.0, -4.0 + 2.5 * i))
	await _go(30)
	var cases := {
		"rest": func(): pass,
		"stun": func(): pl.stun_t = 60.0,
		"invuln": func(): pl.inv_t = 60.0,
		"grounded": func(): pl.set_meta("gnd_until", float(m.time) + 60.0),
		"cloak": func(): pl.cloak_t = 60.0,
	}
	for name in cases:
		_clear()
		cases[name].call()
		await _go(40)
		main.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	_clear()
	var off: Array = []
	var on: Array = []
	for r in ROUNDS:
		pl.stun_t = 0.0
		off.append_array(await _frame_ms())
		pl.stun_t = 600.0
		on.append_array(await _frame_ms())
	var row := "SEDGE frame ms (%d frames each) off p95 %.2f mean %.2f | on p95 %.2f mean %.2f | delta p95 %.2f"
	print(row % [off.size(), _p95(off), _mean(off), _p95(on), _mean(on), _p95(on) - _p95(off)])


## The wall time between frames over TIMED frames of the fight, in ms.
func _frame_ms() -> Array:
	await _go(WARM)
	var ts: Array = []
	var last := Time.get_ticks_usec()
	for i in TIMED:
		await _go(1)
		var now := Time.get_ticks_usec()
		ts.append(float(now - last) / 1000.0)
		last = now
	return ts


func _p95(ts: Array) -> float:
	var s := ts.duplicate()
	s.sort()
	return s[int(s.size() * 0.95)]


func _mean(ts: Array) -> float:
	var sum := 0.0
	for t in ts:
		sum += t
	return sum / ts.size()


func _go(frames: int) -> void:
	for i in frames:
		m.step(DT)
		m.cam.snap(pl.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame
