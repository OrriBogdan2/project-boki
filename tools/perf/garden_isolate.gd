extends RefCounted
## --bench-garden --bench-isolate: where a garden part's frame goes. On the part just measured (Boki out) the same
## scene is timed again, the screen UI shown as a player has it, with one cost changed at a time: the screen UI
## hidden ("no ui"), the crowd easing of RigPace off ("every frame": every rig steps every frame, the way it was),
## the Boki's shadows off, their rigs paused (no animation, still drawn), the Boki hidden. "as is" is timed several
## times so a drifting machine shows. "BENCH isolate" lines: frame p50 / p95 ms and the saving against the first
## "as is". The kin script (Home._move_kin) is timed alone.

const DT := 1.0 / 60.0
const WARM := 20
const FRAMES := 300
const MODES := [
	"as is", "no ui", "as is", "no ui", "every frame", "as is", "every frame", "no shadows", "rigs paused", "boki hidden"
]

var main: Node
var _crowd_from := RigPace.crowd_from


func _init(main_node: Node) -> void:
	main = main_node


func run(part: String, ui_was: Array) -> void:
	var home = main.current
	for u in ui_was:  # the player sees the screen UI: every mode but "no ui" is timed with it
		u[0].visible = u[1]
	var base := 0.0
	for mode in MODES:
		_apply(home, mode, true, ui_was)
		var w := await _sample()
		_apply(home, mode, false, ui_was)
		if base == 0.0:
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


func _apply(home, mode: String, on: bool, ui_was: Array) -> void:
	if mode == "no ui":
		for u in ui_was:
			u[0].visible = u[1] and not on
	for k in home.kins:
		var n := k["node"] as Node3D
		match mode:
			"boki hidden":
				n.visible = not on
			"rigs paused":
				n.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
			"every frame":  # what the home did before RigPace.crowd_from: every rig steps every frame
				RigPace.crowd_from = 999 if on else _crowd_from
			"no shadows":
				for mi in n.find_children("*", "GeometryInstance3D", true, false):
					var g := mi as GeometryInstance3D
					if on:
						g.set_meta("was_cast", g.cast_shadow)
						g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					elif g.has_meta("was_cast"):
						g.cast_shadow = g.get_meta("was_cast")
