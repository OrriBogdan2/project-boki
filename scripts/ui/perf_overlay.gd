class_name PerfOverlay
extends Label
## The frame-rate readout in the top right (Settings > Video > Frame rate). "fps" shows the frame rate;
## "full" is the performance overlay: frames per second, frame time and its 1% low,
## draw calls, triangles and objects drawn, nodes, and the costliest sections of the match's step
## (Match.prof, switched on only while this is showing), and the hitch log: the last HITCH_KEEP frames
## over HITCH_MS with what took the time (render and GPU wait, scripts and the step's costliest section,
## physics). Text refreshes REFRESH_S apart; the frame times sit in a fixed ring, so nothing is allocated
## per frame (a hitch line is built only on a hitch).

const REFRESH_S := 0.25      # s between text updates
const RING := 240            # frames kept for the average and the 1% low (about 4 s at 60 fps)
const TOP_SECTIONS := 4      # match step sections listed
const HITCH_MS := 33.0       # ms: a frame this long is a hitch (under 30 fps)
const HITCH_KEEP := 3        # hitches listed, newest first

var _ms := PackedFloat32Array()
var _i := 0
var _n := 0
var _t := 0.0
var _prof := false
var _hitches := PackedStringArray()

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
	if _ms[_i] > HITCH_MS and mode == "full":
		_log_hitch(_ms[_i])
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
	for hl in _hitches:
		lines.append(hl)
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

## What a slow frame went on: the frame's script and physics time, the match step's costliest section, and the
## rest (rendering, waiting on the GPU, a shader compiled on first use).
func _log_hitch(ms: float) -> void:
	var scr := minf(ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var phys := minf(ms - scr, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	var top := " (%s %.1f)" % [Match.prof_top, Match.prof_top_us / 1000.0] if Match.prof_top_us > 0 else ""
	_hitches.insert(0, "hitch %d ms: render %d  script %d%s  physics %d" % [roundi(ms),
		roundi(maxf(0.0, ms - scr - phys)), roundi(scr), top, roundi(phys)])
	if _hitches.size() > HITCH_KEEP:
		_hitches.resize(HITCH_KEEP)
