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
	_shadows_and_aa()
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

## The shadow ladder (2 cascades Medium, 1 Low, none Very Low), the render scale of Low and Very Low,
## MSAA off below High with FXAA on Medium and Low, and the physics catch-up cap.
func _shadows_and_aa() -> void:
	var Q: Dictionary = Settings.QUALITY
	ok(int(Q["medium"]["splits"]) == 2 and int(Q["low"]["splits"]) == 1 and not Q["very_low"]["shadows"],
		"shadows: 2 cascades medium, 1 low, none very low")
	ok(float(Q["medium"]["shadow_k"]) < 1.0 and float(Q["low"]["shadow_k"]) < float(Q["medium"]["shadow_k"]),
		"shadow distance shorter at medium than high, shorter again at low")
	ok(float(Q["low"]["scale"]) == 0.77 and float(Q["very_low"]["scale"]) == 0.5, "render scale 0.77 low, 0.5 very low")
	var fxaa: bool = Q["medium"]["fxaa"] and Q["low"]["fxaa"]
	ok(int(Settings.DEFAULTS["msaa"]) == 0 and int(Q["medium"]["msaa"]) == 0 and fxaa,
		"MSAA off by default; medium and low use FXAA")
	var root := main.get_tree().root
	var keep_q := String(Settings.v["quality"])
	var keep_m = Settings.v["msaa"]
	Settings.v["quality"] = "low"
	root.size = Vector2i(1920, 1080)
	Settings._apply_render_scale()
	ok(absf(root.scaling_3d_scale - 0.77) < 0.01, "low at 1080p renders at 0.77 (%.2f)" % root.scaling_3d_scale)
	Settings.v["msaa"] = 0
	Settings.apply("msaa")
	ok(root.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA, "low with MSAA off turns FXAA on")
	Settings.v["quality"] = "very_low"
	Settings.apply("msaa")
	ok(root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "very low: no anti-aliasing pass")
	Settings.v["quality"] = "medium"
	Settings.v["msaa"] = 2
	Settings.v["video_v"] = 4
	Settings._video_v5()
	ok(int(Settings.v["msaa"]) == 0 and int(Settings.v["video_v"]) == 5, "video_v 5: Medium's saved 2x MSAA turns off")
	Settings.v["quality"] = keep_q
	Settings.v["msaa"] = keep_m
	Settings._apply_quality()
