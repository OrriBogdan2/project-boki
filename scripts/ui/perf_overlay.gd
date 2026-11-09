class_name PerfOverlay
extends Label
## The frame-rate readout in the top right (Settings > Video > Show frame rate). "fps" shows the frame rate;
## "full" is the performance overlay: frames per second, frame time and its 1% low,
## draw calls, triangles and objects drawn, nodes, and the costliest sections of the match's step
## (Match.prof, switched on only while this is showing). Text refreshes REFRESH_S apart; the frame
## times sit in a fixed ring, so nothing is allocated per frame.

const REFRESH_S := 0.25      # s between text updates
const RING := 240            # frames kept for the average and the 1% low (about 4 s at 60 fps)
const TOP_SECTIONS := 4      # match step sections listed

var _ms := PackedFloat32Array()
var _i := 0
var _n := 0
var _t := 0.0
var _prof := false

func _init() -> void:
	_ms.resize(RING)
	add_theme_font_size_override("font_size", 13)
	add_theme_color_override("font_color", UI.MUTED)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_theme_constant_override("outline_size", 4)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## mode: "" (hidden), "fps" or "full". Called every frame by the Overlay.
func tick(mode: String, delta: float) -> void:
	visible = mode != ""
	if (mode == "full") != _prof:
		_prof = mode == "full"
		Match.prof_on = _prof         # (only toggled here when the overlay switches, so tooling keeps its own)
	if not visible:
		return
	_ms[_i] = delta * 1000.0
	_i = (_i + 1) % RING
	_n = mini(_n + 1, RING)
	_t -= delta
	if _t > 0.0:
		return
	_t = REFRESH_S
	text = "%d fps" % Engine.get_frames_per_second() if mode == "fps" else _full()

func _full() -> String:
	var sum := 0.0
	var worst := _ms.slice(0, _n)
	for x in worst: sum += x
	worst.sort()
	var avg := sum / maxf(1.0, _n)
	var cut := maxi(1, _n / 100)          # the slowest 1% of frames
	var low := 0.0
	for k in cut: low += worst[_n - 1 - k]
	low /= cut
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var tris := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var objs := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var lines := PackedStringArray([
		"%d fps   %.1f ms   1%% low %d fps" % [Engine.get_frames_per_second(), avg, roundi(1000.0 / maxf(low, 0.001))],
		"draws %d   tris %dk   objects %d" % [draws, tris / 1000, objs],
		"script %.1f ms   physics %.1f ms   nodes %d" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]])
	if not Match.prof.is_empty():
		var ks := Match.prof.keys()
		ks.sort_custom(func(a, b): return Match.prof[a] > Match.prof[b])
		var frames := maxf(1.0, REFRESH_S * Engine.get_frames_per_second())
		var top := PackedStringArray()
		for k in ks.slice(0, TOP_SECTIONS):
			top.append("%s %.2f" % [k, Match.prof[k] / 1000.0 / frames])
		lines.append("step ms: " + "  ".join(top))
		Match.prof.clear()
	return "\n".join(lines)
