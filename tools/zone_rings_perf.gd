extends RefCounted
## --zone-rings-perf --shots-dir=<dir> (real GPU): the frame time of a 4v4 fight (Meeko and Albert on one side, in
## view) casting Hearthlight and Mending Ground, with the old looks (a flat 0.16 rim band, the old motes) and the new
## (a lit rim line, rising motes) alternated block by block so a drifting box loads both sides alike. Prints
## `ZRING frame ms ... delta p95` (docs/VFX_SWEEP_1126.md: a PR may raise p95 by at most 0.3 ms) and writes the stills
## <dir>/zring_<old|new>_<n>.png of the same moment.

const DT := 1.0 / 60.0
const WARM := 20  # frames dropped before timing
const TIMED := 330  # frames timed per block: Albert's 1 s fall and most of its 4 s zone, Meeko's light up
const ROUNDS := 3  # old/new blocks alternated
const PX := Vector2i(1920, 1080)  # the stills' size

var main: Node
var m: Match
var pl: Hunter
var meeko: Hunter
var albert: Hunter
var dir := ""
var _new: Dictionary = {}  # the data as shipped, put back by _looks(true)


func run(root: Node) -> void:
	main = root
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	main.get_window().size = PX
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	pl = m.player
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for h in m.hunters:
		h.ctrl = "idle"
	var kin := Save.new_kin("zapple", "Pip")
	meeko = m.make_hunter("ZM", pl.team, "medium", "Meeko", "idle", kin, pl.pos, {"arch": "tender"})
	albert = m.make_hunter("ZA", pl.team, "heavy", "Albert", "idle", kin, pl.pos, {"arch": "bulwark"})
	var foes: Array = m.hunters.filter(func(x): return x.team != pl.team)
	for i in 2:
		foes.append(m.make_hunter("ZF%d" % i, 1 - pl.team, "medium", "Foe", "idle", kin, pl.pos, {"arch": "archer"}))
	for i in foes.size():
		foes[i].teleport(pl.pos + Vector3(7.0 + 2.0 * (i % 2), 0.0, -5.0 + 3.0 * i))
	meeko.teleport(pl.pos + Vector3(-2.0, 0, 3.5))
	albert.teleport(pl.pos + Vector3(2.5, 0, 3.5))
	DirAccess.make_dir_recursive_absolute(dir)
	_new = {
		"disc": HeroVfx.data("tender")["hearth_disc"].duplicate(),
		"mb": HeroVfx.data("bulwark")["moves"].duplicate(true)
	}
	var old: Array = []
	var now: Array = []
	for r in ROUNDS:
		for is_new in [false, true]:
			_looks(is_new)
			var ts := await _block(is_new, r)
			(now if is_new else old).append_array(ts)
	_looks(true)
	var row := "ZRING frame ms (%d frames each) old p95 %.2f mean %.2f | new p95 %.2f mean %.2f | delta p95 %.2f"
	print(row % [old.size(), _p95(old), _mean(old), _p95(now), _mean(now), _p95(now) - _p95(old)])
	print("ZRING live motes %d of cap %d" % [HeroVfx.of(m).live_n, HeroVfx.MAX_LIVE])
	main.get_tree().quit(0)


## The old looks (before ext/vfx-meeko-albert-rings) when `is_new` is false, else the shipped data.
func _looks(is_new: bool) -> void:
	var tdisc: Dictionary = HeroVfx.data("tender")["hearth_disc"]
	var moves: Dictionary = HeroVfx.data("bulwark")["moves"]
	tdisc.merge(_new["disc"] if is_new else {"rim_w": 0.16, "lit": 0.0}, true)
	for mv in ["mend_fall", "mend_zone"]:
		var fx: Array = (_new["mb"][mv]["fx"] as Array).duplicate(true)
		if not is_new:
			if mv == "mend_fall":
				fx.resize(2)
			else:
				fx[0].merge({"n": 16, "speed": 1.0, "spread": 0.3, "grav": -0.8, "life": 1.0, "size": 0.06}, true)
				fx[1].merge({"n": 4, "size": 0.12}, true)
				fx[0].erase("stretch")
				fx[0].erase("drag")
		moves[mv]["fx"] = fx


func _block(is_new: bool, round_i: int) -> Array:
	for h: Hunter in [meeko, albert]:
		h.ak.cd["e"] = 0.0
		h.ak.cast_e()
	await _go(WARM)
	var ts: Array = []
	var last := Time.get_ticks_usec()
	for i in TIMED:
		await _go(1)
		var now := Time.get_ticks_usec()
		ts.append(float(now - last) / 1000.0)
		last = now
		if round_i == 0 and (i == 40 or i == 200):
			var img := main.get_viewport().get_texture().get_image()
			img.save_png(dir.path_join("zring_%s_%d.png" % ["new" if is_new else "old", i]))
	if albert.ak.has_method("cancel_hold"):
		albert.ak.cancel_hold()
	await _go(10)
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
