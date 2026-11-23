extends RefCounted
## --bench-garden --bench-isolate: where a garden part's frame goes. On the part just measured (Boki out, UI shown)
## the same scene is timed again with one cost removed at a time: the Boki hidden (no draw, no rig step), their rigs
## paused (no animation, still drawn), their shadows off, and the 10 Hz-and-up kin script (Home._move_kin) timed
## alone. "BENCH isolate" lines: frame p50 / p95 ms and the saving against the untouched scene.

const DT := 1.0 / 60.0
const WARM := 20
const FRAMES := 180
const MODES := ["as is", "no shadows", "rigs paused", "boki hidden"]

var main: Node


func _init(main_node: Node) -> void:
	main = main_node


func run(part: String) -> void:
	var home = main.current
	var base := 0.0
	for mode in MODES:
		_apply(home, mode, true)
		var w := await _sample()
		_apply(home, mode, false)
		if mode == "as is":
			base = w[0]
		print(
			"BENCH isolate %s %s: p50 %.1f ms, p95 %.1f ms, saves %.1f ms of p50" % [part, mode, w[0], w[1], base - w[0]]
		)
	var t0 := Time.get_ticks_usec()
	for i in 60:
		home._move_kin(DT)
	print("BENCH isolate %s kin script: %.2f ms a frame (Home._move_kin)" % [part, (Time.get_ticks_usec() - t0) / 60000.0])


func _sample() -> Array:
	for i in WARM:
		await main.get_tree().process_frame
	var fl: Array = []
	var last := Time.get_ticks_usec()
	for i in FRAMES:
		await main.get_tree().process_frame
		var now := Time.get_ticks_usec()
		fl.append((now - last) / 1000.0)
		last = now
	fl.sort()
	return [fl[int((fl.size() - 1) * 0.5)], fl[int((fl.size() - 1) * 0.95)]]


func _apply(home, mode: String, on: bool) -> void:
	for k in home.kins:
		var n := k["node"] as Node3D
		match mode:
			"boki hidden":
				n.visible = not on
			"rigs paused":
				n.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
			"no shadows":
				for mi in n.find_children("*", "GeometryInstance3D", true, false):
					var g := mi as GeometryInstance3D
					if on:
						g.set_meta("was_cast", g.cast_shadow)
						g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					elif g.has_meta("was_cast"):
						g.cast_shadow = g.get_meta("was_cast")
