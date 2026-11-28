extends RefCounted
## --marks-ab-shots [--tell-soft]: frame time of a 4v4 fight (Neve the local player) while her Ice Spear landing and
## detonation play every PERIOD frames and Nightwell's tell circle stays up on the ground (MARKS rows: p95 and mean in
## ms). Run the same file on two trees (before, after) and compare; --tell-soft draws the tell as the new soft circle.

const DT := 1.0 / 60.0
const WARM := 30  # frames dropped before timing
const TIMED := 480  # frames timed
const PERIOD := 90  # frames between spear landings
const BURST_AFTER := 60  # frames from a landing to its detonation
const TELL_R := 5.0  # m, Nightwell's radius

var main: Node
var m: Match
var pl: Hunter


func run(root: Node) -> void:
	main = root
	Save.no_write = true
	var soft := "--tell-soft" in OS.get_cmdline_user_args()
	m = Match.new()
	main.add_child(m)
	var opts := {"teams": 2, "squad": 4, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	opts.merge({"cls": Arch.weight("rimewright"), "arch": "rimewright", "weapon": Arch.signature("rimewright")})
	await m.start(opts)
	m.set_process(false)
	pl = m.player
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for h in m.hunters:
		h.ctrl = "idle"
	var ts := await _frame_ms(soft)
	print("MARKS frame ms (%d frames, soft tell %s) p95 %.2f mean %.2f" % [ts.size(), soft, _p95(ts), _mean(ts)])
	main.get_tree().quit(0)


func _frame_ms(soft: bool) -> Array:
	var ts: Array = []
	var last := Time.get_ticks_usec()
	for i in WARM + TIMED:
		var at := pl.pos + Vector3(6.0, 0.0, 0.0)
		var dir := Vector2(1.0, 0.0)
		if i % PERIOD == 0:
			HeroVfx.of(m).play(pl, "spear_land", at, dir, {"r": 2.2})
		if i % PERIOD == BURST_AFTER:
			HeroVfx.of(m).play(pl, "spear_burst", at, dir, {"r": 2.7})
		var p := {"at": at, "r": TELL_R, "fill": float(i % PERIOD) / PERIOD, "all": true, "ticks": true, "soft": soft}
		AimKit.circle(pl, "marks_ab", p)
		m.step(DT)
		m.cam.snap(pl.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame
		var now := Time.get_ticks_usec()
		if i >= WARM:
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
