extends RefCounted
## --quality-check, the graphics presets (Settings.QUALITY): every preset has every knob; each step down
## the list is no heavier than the one above it; Very Low really is light (no shadows, SSAO, bloom,
## volumetrics, short draw distance, capped render height); the render-height cap scales a tall window
## down and leaves a small one alone; lamps fade on the presets that ask for it; auto-detect names a preset.

var main: Node
var fails := 0

func ok(cond: bool, what: String) -> void:
	print("QUALITY %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	_knobs()
	_order()
	_very_low()
	_render_scale()
	_lamps()
	ok(Settings.QUALITY.has(Settings.detect_quality()), "auto-detect names a preset (%s)" % Settings.detect_quality())
	print("QUALITY DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _knobs() -> void:
	var want: Array = Settings.QUALITY["high"].keys()
	for k in Settings.QUALITY_ORDER:
		ok(Settings.QUALITY[k].keys().size() == want.size() and want.all(func(x): return Settings.QUALITY[k].has(x)),
			"%s has every knob" % k)

## Lighter down the list: render height (0 = native counts as the most), draw distance, grass, effects,
## shadow map, MSAA, lamp distance (0 = their own, the most).
func _order() -> void:
	var most := func(x: float) -> float: return INF if x <= 0.0 else x
	for i in range(1, Settings.QUALITY_ORDER.size()):
		var lo: Dictionary = Settings.QUALITY[Settings.QUALITY_ORDER[i - 1]]
		var hi: Dictionary = Settings.QUALITY[Settings.QUALITY_ORDER[i]]
		var nm := "%s <= %s" % [lo["name"], hi["name"]]
		ok(most.call(float(lo["px"])) <= most.call(float(hi["px"])), nm + " render height")
		ok(most.call(float(lo["light_m"])) <= most.call(float(hi["light_m"])), nm + " lamp distance")
		for k in ["draw", "grass", "fx", "atlas", "msaa", "splits", "clouds"]:
			ok(float(lo[k]) <= float(hi[k]), "%s %s" % [nm, k])
		ok(float(lo["lod"]) >= float(hi["lod"]), nm + " mesh detail")

func _very_low() -> void:
	var Q: Dictionary = Settings.QUALITY["very_low"]
	ok(not Q["shadows"] and not Q["ssao"] and not Q["glow"] and not Q["volfog"] and not Q["shafts"],
		"very low: no shadows, SSAO, bloom, volumetrics or light shafts")
	ok(float(Q["draw"]) <= 0.5 and int(Q["px"]) > 0 and int(Q["px"]) <= 600,
		"very low: short draw distance, render height capped")
	ok(Settings.QUALITY["high"]["px"] == 0 and Settings.QUALITY["high"]["light_m"] == 0.0, "high keeps the full look")

func _render_scale() -> void:
	var root := main.get_tree().root
	var keep_q := String(Settings.v["quality"])
	var keep_size := root.size
	Settings.v["quality"] = "medium"
	root.size = Vector2i(3840, 2160)
	Settings._apply_render_scale()
	ok(absf(root.scaling_3d_scale - 0.5) < 0.01,
		"medium at 2160p renders the 3D at half (%.2f)" % root.scaling_3d_scale)
	root.size = Vector2i(1280, 720)
	Settings._apply_render_scale()
	ok(root.scaling_3d_scale == 1.0, "medium at 720p renders at full size")
	Settings.v["quality"] = "high"
	root.size = Vector2i(3840, 2160)
	Settings._apply_render_scale()
	ok(root.scaling_3d_scale == 1.0, "high renders native at 2160p")
	Settings.v["quality"] = keep_q
	root.size = keep_size
	Settings._apply_render_scale()

func _lamps() -> void:
	var keep_q := String(Settings.v["quality"])
	var l := OmniLight3D.new()
	Settings.v["quality"] = "low"
	main.add_child(l)
	var low_m := float(Settings.QUALITY["low"]["light_m"])
	ok(l.distance_fade_enabled and l.distance_fade_begin == low_m, "low: a lamp fades with distance")
	Settings.v["quality"] = "high"
	Settings._light_quality(l)
	ok(not l.distance_fade_enabled, "high: a lamp without its own fade never fades")
	l.queue_free()
	Settings.v["quality"] = keep_q
