extends Node
## Game settings. They belong to the player, not to a save file, so every save shares them
## (user://settings.cfg). Changing one applies it right away.

signal changed(key: String)

const PATH := "user://settings.cfg"
const DEFAULTS := {
	# audio
	"master": 0.8, "music": 0.7, "sfx": 1.0, "ambience": 0.8, "mute_unfocused": false,
	# video
	"fullscreen": false, "vsync": true, "max_fps": 0, "msaa": 4, "video_v": 4, "shadows": true, "ui_scale": 1.0, "show_fps": 0,
	"quality": "auto", "quality_found": "",
	# gameplay
	"damage_numbers": true, "tips": true, "lobby_enabled": true, "kin_chatter": "normal", "mod_mode": false, "bot_diff": "auto",
	# Warden id -> "procedural": that Warden keeps its procedural model instead of its 3D one (WardenGlb)
	"warden_models": {},
	# how keys behave (Controls)
	"cast_on_press": true, "dash_to_cursor": false, "crouch_toggle": false,
	# the aiming reticle (Reticle): shape and colour ids, size factor, opacity, dark outline
	"reticle_shape": "default", "reticle_size": 1.0, "reticle_col": "white", "reticle_alpha": 1.0,
	"reticle_outline": true,
	# camera
	"depth_cues": true, "cam_style": "supervive", "cam_follow": "supervive", "cam_lead": 1.0,
	# sounds
	"reset_cue": "a",
	# accessibility
	"screen_shake": 0.3, "reduce_flashes": false,
	# demo / recording (Settings > Demo): for filming a match, offline only (online matches use the host's rules)
	"demo_weather": "random", "demo_blight": true, "demo_fresh": "normal", "demo_all_masks": false, "rec_level": 0,
	# controls: action -> list of "key:<physical keycode>" / "mouse:<button>"
	"keys": {}, "keys_v": 2, "keys2_v": 0, "keys3_v": 0, "keys4_v": 0, "keys5_v": 0,
}
## Settings that no longer exist (docs/SETTINGS_AUDIT.md). They are dropped from the settings file
## the first time it's written after they went.
const REMOVED := ["dash_hold", "kin_auto", "hud_opacity", "shake"]

## Graphics presets (Video → Quality). High is the game's full look; Very Low, Low and Medium trade
## detail for speed, Ultra pushes draw distance, shadows and level of detail further. A preset sets the
## plain settings (msaa, shadows) and these knobs, which the renderer and the world builder read through q():
##   px: tallest 3D render in pixels (0: native); a bigger window renders the 3D smaller and FSR scales it
##   up (see _apply_render_scale), so a retina or 4K screen doesn't cost 2-4x the pixels  ·  lod: mesh LOD
##   threshold (pixels of error allowed)  ·  grass: share of grass and flowers kept  ·  draw: draw distance
##   of scatter and props (x)  ·  shadow_k: shadow distance (x)  ·  splits: shadow cascades  ·  atlas: sun
##   shadow map size  ·  soft: soft-shadow filter quality  ·  ssao, glow: the desktop renderer's ambient
##   occlusion and bloom  ·  clouds: drifting cloud layers  ·  shafts: light shafts  ·  fx: particle amount
##   (x)  ·  volfog: volumetric fog  ·  light_m: lamps and glows fade out this far from the camera (m, 0: their own)
const QUALITY := {
	"very_low": {"name": "Very Low", "msaa": 0, "shadows": false, "px": 540, "lod": 8.0, "grass": 0.15, "draw": 0.45,
		"shadow_k": 0.6, "splits": 1, "atlas": 1024, "soft": 0, "ssao": false, "glow": false, "clouds": 0,
		"shafts": false, "fx": 0.25, "volfog": false, "light_m": 40.0, "anim_lod": true},
	"low": {"name": "Low", "msaa": 0, "shadows": false, "px": 720, "lod": 4.0, "grass": 0.4, "draw": 0.6,
		"shadow_k": 0.7, "splits": 1, "atlas": 2048, "soft": 0, "ssao": false, "glow": false, "clouds": 0,
		"shafts": false, "fx": 0.45, "volfog": false, "light_m": 50.0, "anim_lod": true},
	"medium": {"name": "Medium", "msaa": 2, "shadows": true, "px": 1080, "lod": 2.0, "grass": 0.7, "draw": 0.8,
		"shadow_k": 0.8, "splits": 2, "atlas": 2048, "soft": 1, "ssao": false, "glow": true, "clouds": 1,
		"shafts": true, "fx": 0.7, "volfog": false, "light_m": 70.0, "anim_lod": true},
	"high": {"name": "High", "msaa": 4, "shadows": true, "px": 0, "lod": 1.0, "grass": 1.0, "draw": 1.0,
		"shadow_k": 1.0, "splits": 4, "atlas": 4096, "soft": 3, "ssao": true, "glow": true, "clouds": 2,
		"shafts": true, "fx": 1.0, "volfog": true, "light_m": 0.0, "anim_lod": true},
	"ultra": {"name": "Ultra", "msaa": 4, "shadows": true, "px": 0, "lod": 0.5, "grass": 1.0, "draw": 1.6,
		"shadow_k": 1.35, "splits": 4, "atlas": 4096, "soft": 4, "ssao": true, "glow": true, "clouds": 2,
		"shafts": true, "fx": 1.0, "volfog": true, "light_m": 0.0, "anim_lod": false},
}
const QUALITY_ORDER := ["very_low", "low", "medium", "high", "ultra"]

## The preset in effect: the player's pick, or what auto-detect found for this machine.
func quality() -> String:
	var qv := String(v.get("quality", "auto"))
	if QUALITY.has(qv):
		return qv
	var found := String(v.get("quality_found", ""))
	return found if QUALITY.has(found) else detect_quality()

## Settings > Video > Frame rate: "" hidden, "fps" the rate alone, "full" the performance overlay
## (show_fps was a toggle before, so a saved true is the plain rate).
func fps_mode() -> String:
	match int(v.get("show_fps", 0)):
		0: return ""
		1: return "fps"
	return "full"

## Very Low or Low: the presets that also thin out what isn't a knob (title-screen grass, storm streaks).
func lite() -> bool:
	return QUALITY_ORDER.find(quality()) <= QUALITY_ORDER.find("low")

## A knob of the preset in effect (see QUALITY).
func q(key: String):
	return QUALITY[quality()].get(key, QUALITY["high"][key])

## A first guess from the graphics adapter: software renderers get Very Low, integrated PC graphics
## (Intel, AMD APUs) Low, everything else Medium (the default the game is tuned to hold 60 fps at, Apple
## silicon included: its render-height cap keeps a retina screen cheap). High and Ultra are a pick in
## Settings > Video. The first expedition's loading screen then measures real frames and steps it down
## if they come in slow (see note_benchmark).
func detect_quality() -> String:
	if OS.has_feature("web"):
		return "medium"
	if DisplayServer.get_name() == "headless":
		return "high"
	var nm := RenderingServer.get_video_adapter_name().to_lower()
	if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_CPU:
		return "very_low"
	if nm.contains("llvmpipe") or nm.contains("swiftshader") or nm.contains("software"): return "very_low"
	if nm.contains("apple"):
		return "medium"
	if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		return "low"
	if nm.contains("intel") and not nm.contains("arc"): return "low"
	return "medium"

## Auto quality only: frame times measured while the first expedition loads (ms, the world on screen
## from the skyship). Too slow for 60 fps steps the preset down once (twice when far too slow) and
## remembers it.
const BENCH_SLOW_MS := 20.0     # ms a frame: slower than this steps the preset down one
const BENCH_FAR_MS := 45.0      # ms a frame: slower than this steps it down two
func note_benchmark(ms: float) -> void:
	if String(v.get("quality", "auto")) != "auto" or String(v.get("quality_found", "")) != "":
		return
	var cur := quality()
	var i := QUALITY_ORDER.find(cur)
	if ms > BENCH_SLOW_MS and i > 0:
		cur = QUALITY_ORDER[i - 1]
		if ms > BENCH_FAR_MS and i > 1: cur = QUALITY_ORDER[i - 2]
	v["quality_found"] = cur
	apply("quality")
	save()
	print("Quality: auto picked %s (load benchmark %.1f ms a frame)" % [cur, ms])

## Bumped when the default kit changes enough that old custom bindings would be nonsense.
const KEYS_V := 3

## Rebindable actions, in the order the controls list shows them.
const ACTIONS := [
	["up", "Move up"], ["down", "Move down"], ["left", "Move left"], ["right", "Move right"],
	["fire", "Weapon attack"], ["secondary", "Hunter ability (right click)"], ["dash", "Hunter dash"], ["jump", "Jump (hold to glide)"], ["glide", "Glide (hold in the air)"], ["crouch", "Sneak"],
	["gear1", "Glove 1"], ["gear2", "Glove 2 (in a match; V plays fetch at home)"], ["signature", "Hunter utility (E)"],
	["throw", "Boki: tap to send out or call back, hold for the order wheel"],
	["hunter_ult", "Hunter ultimate"], ["ultimate", "Fuse with your Boki (needs a full bond meter)"],
	["base", "Base to a teammate (squads)"], ["interact", "Use, scan, revive, pet"],
	["util1", "Utility belt slot 1 (a tonic to start)"], ["util2", "Utility belt slot 2 (an armor kit to start)"],
	["util3", "Utility belt slot 3"], ["util4", "Utility belt slot 4"], ["scores", "Scoreboard"],
	["emote", "Emote wheel (hold, in a match)"],
	["ping", "Ping for your squad: a spot, an enemy or loot (on the map too)"],
	["map", "Full map (click to ping)"], ["pass_lead", "Pass the drop lead"], ["separate", "Separate from the drop"],
	["play", "Play fetch with a Boki"], ["talk", "Talk to a Boki"], ["details", "A Boki's details"], ["inventory", "Inventory"],
	["build", "Build mode at home / decorate indoors"], ["hero", "Relics: change your Relic (at home and in practice areas)"], ["rotate", "Turn a piece (build mode)"],
	["store", "Put a piece away (build mode)"],
	["record", "Recording mode (again: hide the HUD)"], ["record_orbit", "Recording: slow camera orbit"],
]

var v: Dictionary = {}
var _defaults_keys := {}
var _dirty := false
var _started := false       # the bindings the game ships with, for "reset"
var _quality_basics := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	v = DEFAULTS.duplicate(true)
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS:
			if cf.has_section_key("s", k):
				v[k] = cf.get_value("s", k)
	else:
		# older saves kept a few settings inside the save file
		var old: Dictionary = Save.d.get("settings", {})
		for pair in [["volume", "master"], ["music", "music"], ["cam_lead", "cam_lead"]]:
			if old.has(pair[0]): v[pair[1]] = float(old[pair[0]])
	if not cf.has_section_key("s", "keys_v") and String(v.get("cam_follow", "")) == "standard":
		v["cam_follow"] = "supervive"     # the new Supervive-style cursor lean becomes everyone's default once
	if int(v.get("keys_v", 1)) < KEYS_V or not cf.has_section_key("s", "keys_v"):
		v["keys"] = {}          # the kit changed (archetypes: E utility, C kin ability, G send/recall): start from the new defaults
		v["keys_v"] = KEYS_V
	KeyMigrate.run(v)
	_migrate_belt_keys()
	if int(v.get("video_v", 1)) < 2 or not cf.has_section_key("s", "video_v"):
		# crisper by default: 4x MSAA on desktop (the browser build stays on 2x)
		if int(v.get("msaa", 2)) == 2 or not cf.has_section_key("s", "msaa"): v["msaa"] = 2 if OS.has_feature("web") else 4
		v["video_v"] = 2
	if int(v.get("video_v", 2)) < 3:
		# Medium became the default (item 94): an automatic pick of High or Ultra steps down once; a hand pick stays
		if String(v.get("quality", "auto")) == "auto" and String(v.get("quality_found", "")) in ["high", "ultra"]:
			v["quality_found"] = "medium"
		v["video_v"] = 3
	if int(v.get("video_v", 3)) < 4:
		# Very Low and render-height caps came in: what auto found before (at full retina/4K resolution) is measured again
		if String(v.get("quality", "auto")) == "auto": v["quality_found"] = ""
		v["video_v"] = 4
	if v.get("show_fps") is bool: v["show_fps"] = int(v["show_fps"])      # (a toggle before the performance overlay)
	# a first run (or the first since presets came in) takes the preset's anti-aliasing and shadows
	_quality_basics = not cf.has_section_key("s", "quality")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			v["quality"] = a.substr(10); _quality_basics = true      # tooling: try a preset without saving it
	if REMOVED.any(func(k): return cf.has_section_key("s", k)):
		save.call_deferred()
	if not cf.has_section_key("s", "crouch_toggle") and OS.has_feature("web"):
		v["crouch_toggle"] = true      # browsers close the tab on Ctrl+W, so don't make people hold Ctrl
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_apply_ui_scale)
	get_tree().root.size_changed.connect(_apply_render_scale)

## The heal and armor-kit keys became belt slots 1 and 2 (ext/equal): custom bindings move across.
func _migrate_belt_keys() -> void:
	var ks: Dictionary = v["keys"]
	for pair in [["tonic", "util1"], ["armor_kit", "util2"]]:
		if ks.has(pair[0]):
			if not ks.has(pair[1]): ks[pair[1]] = ks[pair[0]]
			ks.erase(pair[0])

## Called by Game once the input actions exist, so saved key bindings can replace them.
func apply_all() -> void:
	for a in ACTIONS:
		_defaults_keys[a[0]] = _events_to_list(InputMap.action_get_events(a[0]))
	for k in v:
		apply(k)
	_started = true

## Seconds bots leave a fresh lander alone (Bot.fresh) with Settings > Demo > "Bots leave you be after
## landing" on Longer.
const DEMO_FRESH_T := 60.0

## Settings > Demo applied to an offline match's options as it starts (Game.show_screen): the raid
## condition kept clear (RaidLook.pick reads opts["raid"]), the Blight off (BlightDir.enabled reads
## opts["blight"]), bots holding off fresh landers for longer (Bot.fresh reads opts["fresh_t"]). Options a
## tool or demo flag already set win. Returns the same dictionary.
func demo_opts(o: Dictionary) -> Dictionary:
	if String(get_v("demo_weather")) == "clear" and not o.has("raid"):
		o["raid"] = "clear"
	if not bool(get_v("demo_blight")) and not o.has("blight"):
		o["blight"] = false
	if String(get_v("demo_fresh")) == "long" and not o.has("fresh_t"):
		o["fresh_t"] = DEMO_FRESH_T
	return o

func get_v(k: String):
	return v.get(k, DEFAULTS.get(k))

func set_v(k: String, val, write := true) -> void:
	v[k] = val
	apply(k)
	if write:
		save()
	else:
		# dragging a slider: write once things settle instead of on every step
		_dirty = true
		get_tree().create_timer(0.6).timeout.connect(func():
			if _dirty:
				_dirty = false
				save())
	changed.emit(k)

func save() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)          # keeps the other sections (the last save slot)
	for k in REMOVED:
		if cf.has_section_key("s", k):
			cf.erase_section_key("s", k)
	for k in v:
		cf.set_value("s", k, v[k])
	cf.save(PATH)

func reset_all() -> void:
	v = DEFAULTS.duplicate(true)
	for a in _defaults_keys:
		_bind(a, _defaults_keys[a])
	for k in v:
		apply(k)
	save()
	changed.emit("")

func apply(k: String) -> void:
	match k:
		"master": AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(v[k]), 0.0001)))
		"music": Sfx.set_bus("Music", float(v[k]))
		"sfx": Sfx.set_bus("SFX", float(v[k]))
		"ambience": Sfx.set_bus("Ambience", float(v[k]))
		"fullscreen":
			# browsers only allow fullscreen from a click, so the web build doesn't restore it at startup
			if OS.has_feature("web") and not _started:
				v[k] = false
				return
			var want := DisplayServer.WINDOW_MODE_FULLSCREEN if v[k] else DisplayServer.WINDOW_MODE_WINDOWED
			if DisplayServer.window_get_mode() != want:
				DisplayServer.window_set_mode(want)
		"vsync":
			if not OS.has_feature("web"):
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v[k] else DisplayServer.VSYNC_DISABLED)
		"max_fps": Engine.max_fps = int(v[k])
		"msaa":
			var m := int(v[k])
			get_tree().root.msaa_3d = Viewport.MSAA_4X if m >= 4 else (Viewport.MSAA_2X if m >= 2 else Viewport.MSAA_DISABLED)
		"shadows":
			for n in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
				(n as DirectionalLight3D).shadow_enabled = bool(v[k]) and _casts(n as DirectionalLight3D)
		"quality", "quality_found":
			_apply_quality()
		"ui_scale": _apply_ui_scale()
		"rec_level":
			# recording mode picked in Settings > Demo carries over to the next launch (--record overrides)
			if not _started and not Array(OS.get_cmdline_user_args()).any(func(x): return String(x).begins_with("--record")):
				Record.set_level(int(v[k]))
		"keys":
			# kin throw moved off right click when heroes got secondaries
			if v[k].has("throw") and (v[k]["throw"] as Array).has("mouse:2") and not v[k].has("secondary"):
				v[k].erase("throw")
			for a in v[k]:
				_bind(a, v[k][a])

## The interface is laid out for a 1280x720 window and scales with the window both ways: smaller
## windows (a laptop browser with its toolbars) shrink it so nothing ends up off screen, and big
## ones (1440p, 4K) grow it so it reads at the same size it was designed at instead of shrinking
## to a postage stamp in the corner.
func _apply_ui_scale() -> void:
	var win := Vector2(get_tree().root.size)
	if win.x < 10.0 or win.y < 10.0:
		return
	var user := clampf(float(v.get("ui_scale", 1.0)), 0.75, 1.5)
	var fit := minf(win.y / 720.0, win.x / 1240.0)
	var f := user * fit
	# never let the user's own size setting push the layout past the window either
	f = minf(f, minf(win.y / 640.0, win.x / 1100.0))
	if absf(get_tree().root.content_scale_factor - f) > 0.001:
		get_tree().root.content_scale_factor = f

## Lights made later (every screen builds its own) follow the shadow setting too.
func _on_node_added(n: Node) -> void:
	if n is DirectionalLight3D:
		var dl := n as DirectionalLight3D
		_casts(dl)
		if not bool(v.get("shadows", true)):
			dl.shadow_enabled = false
		elif dl.shadow_enabled:
			_shadow_quality(dl)
	elif n is OmniLight3D or n is SpotLight3D:
		_light_quality(n as Light3D)
	elif n is WorldEnvironment and (n as WorldEnvironment).environment:
		_env_quality((n as WorldEnvironment).environment)

func _casts(dl: DirectionalLight3D) -> bool:
	if not dl.has_meta("casts"):
		dl.set_meta("casts", dl.shadow_enabled)
	return bool(dl.get_meta("casts"))

## The preset's shadow distance and cascades on a light that casts shadows (its own distance is
## the High one).
func _shadow_quality(dl: DirectionalLight3D) -> void:
	if not dl.has_meta("dist0"):
		dl.set_meta("dist0", dl.directional_shadow_max_distance)
		dl.set_meta("mode0", dl.directional_shadow_mode)
	dl.directional_shadow_max_distance = float(dl.get_meta("dist0")) * float(q("shadow_k"))
	var splits := int(q("splits"))
	var mode0 := int(dl.get_meta("mode0"))
	if mode0 == DirectionalLight3D.SHADOW_ORTHOGONAL or splits <= 1:
		dl.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if splits <= 1 else mode0
	else:
		dl.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if splits == 2 else mode0

const LIGHT_FADE_M := 8.0       # m over which a far lamp dims out (Settings q("light_m"))

## Lamps and glows past the preset's light_m fade out (the engine then skips them); a light's own
## shorter fade stays.
func _light_quality(l: Light3D) -> void:
	if not l.has_meta("fade0"):
		l.set_meta("fade0", l.distance_fade_begin if l.distance_fade_enabled else 0.0)
	var own := float(l.get_meta("fade0"))
	var m := float(q("light_m"))
	l.distance_fade_enabled = own > 0.0 or m > 0.0
	l.distance_fade_begin = minf(own, m) if own > 0.0 and m > 0.0 else maxf(own, m)
	l.distance_fade_length = LIGHT_FADE_M


## The 3D renders at most q("px") pixels tall (0: the window's own height); the desktop renderer
## scales it up with FSR, which keeps edges sharp, the browser/compatibility one bilinearly. The HUD
## always draws at the window's full size.
func _apply_render_scale() -> void:
	var root := get_tree().root
	var px := int(q("px"))
	var h := maxi(1, root.size.y)
	root.scaling_3d_scale = clampf(float(px) / h, 0.25, 1.0) if px > 0 else 1.0
	var fsr := RenderingServer.get_current_rendering_method() != "gl_compatibility" and root.scaling_3d_scale < 0.999
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if fsr else Viewport.SCALING_3D_MODE_BILINEAR

func _env_quality(e: Environment) -> void:
	if not e.has_meta("ssao0"):
		e.set_meta("ssao0", e.ssao_enabled)
		e.set_meta("glow0", e.glow_enabled)
	e.ssao_enabled = bool(e.get_meta("ssao0")) and bool(q("ssao"))
	e.glow_enabled = bool(e.get_meta("glow0")) and bool(q("glow"))
	if e.volumetric_fog_enabled or e.has_meta("vfog0"):
		# volumetric light in the haze (the expedition's dusk) only on the presets that can afford it
		if not e.has_meta("vfog0"): e.set_meta("vfog0", e.volumetric_fog_enabled)
		e.volumetric_fog_enabled = bool(e.get_meta("vfog0")) and bool(q("volfog"))

## Applies the preset in effect: its anti-aliasing and shadows (as if picked by hand), render scale,
## level of detail, shadow map size and filtering, lamp fade, and the lights and environments already in the scene. The
## world's own detail (grass, draw distance, cloud layers, particles) follows from the next expedition.
func _apply_quality() -> void:
	var Q: Dictionary = QUALITY[quality()]
	if _started or _quality_basics:
		_quality_basics = false
		v["msaa"] = int(Q["msaa"]) if not OS.has_feature("web") else mini(int(Q["msaa"]), 2)
		v["shadows"] = bool(Q["shadows"])
		apply("msaa"); apply("shadows")
	var root := get_tree().root
	_apply_render_scale()
	root.mesh_lod_threshold = float(Q["lod"])
	RenderingServer.directional_soft_shadow_filter_set_quality(int(Q["soft"]))
	RenderingServer.directional_shadow_atlas_set_size(int(Q["atlas"]), true)
	for n in root.find_children("*", "Light3D", true, false):
		if n is OmniLight3D or n is SpotLight3D: _light_quality(n as Light3D)
	for n in root.find_children("*", "DirectionalLight3D", true, false):
		if (n as DirectionalLight3D).shadow_enabled: _shadow_quality(n as DirectionalLight3D)
	for n in root.find_children("*", "WorldEnvironment", true, false):
		if (n as WorldEnvironment).environment: _env_quality((n as WorldEnvironment).environment)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and bool(v.get("mute_unfocused", false)):
		AudioServer.set_bus_mute(0, true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		AudioServer.set_bus_mute(0, false)

# ------------------------------------------------------------------ key bindings
func _events_to_list(evs: Array) -> Array:
	var out: Array = []
	for e in evs:
		if e is InputEventKey:
			out.append("key:%d" % (e as InputEventKey).physical_keycode)
		elif e is InputEventMouseButton:
			out.append("mouse:%d" % (e as InputEventMouseButton).button_index)
	return out

func _bind(action: String, list: Array) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for s in list:
		var parts := String(s).split(":")
		if parts.size() != 2:
			continue
		if parts[0] == "key":
			var e := InputEventKey.new(); e.physical_keycode = int(parts[1])
			InputMap.action_add_event(action, e)
		elif parts[0] == "mouse":
			var m := InputEventMouseButton.new(); m.button_index = int(parts[1])
			InputMap.action_add_event(action, m)

## The saved form of a key or mouse button ("key:69", "mouse:2"), or "" for anything else.
func ev_code(ev: InputEvent) -> String:
	if ev is InputEventKey: return "key:%d" % (ev as InputEventKey).physical_keycode
	if ev is InputEventMouseButton: return "mouse:%d" % (ev as InputEventMouseButton).button_index
	return ""

## An action's two binding slots, [primary, secondary] ("" when a slot is empty).
func slots(action: String) -> Array:
	var list := _events_to_list(InputMap.action_get_events(action))
	var saved: Array = v["keys"].get(action, [])
	# (an empty primary is kept in the save as "", which InputMap can't hold)
	if saved.size() >= 2 and String(saved[0]) == "": list.push_front("")
	while list.size() < 2: list.append("")
	return [String(list[0]), String(list[1])]

func _set_slots(action: String, sl: Array) -> void:
	var list: Array = [String(sl[0]), String(sl[1])]
	if list[1] == "": list.resize(1)
	if list.size() == 1 and list[0] == "": list = []
	_bind(action, list)
	var keys: Dictionary = v["keys"]
	keys[action] = list
	save()
	changed.emit("keys")

## Sets one binding slot of an action (0 primary, 1 secondary) to this key or mouse button.
func rebind(action: String, ev: InputEvent, slot := 0) -> void:
	var s := ev_code(ev)
	if s == "":
		return
	var sl := slots(action)
	sl[slot] = s
	if sl[1 - slot] == s: sl[1 - slot] = ""
	_set_slots(action, sl)

## Empties one binding slot.
func clear_bind(action: String, slot: int) -> void:
	var sl := slots(action)
	sl[slot] = ""
	_set_slots(action, sl)

## Other rebindable actions already using this key or button: [[action, slot], ...].
func conflicts(ev: InputEvent, except := "") -> Array:
	var s := ev_code(ev)
	var out: Array = []
	if s == "":
		return out
	for a in ACTIONS:
		if a[0] == except: continue
		var sl := slots(a[0])
		for i in 2:
			if sl[i] == s and not _shared_ok(a[0], except): out.append([a[0], i])
	return out

## Pairs of actions that share keys on purpose (they never apply in the same place: at home vs in a match).
const SHARED_OK := [["build", "base"], ["rotate", "hunter_ult"], ["play", "gear2"], ["store", "ultimate"]]
func _shared_ok(a: String, b: String) -> bool:
	for p in SHARED_OK:
		if (p[0] == a and p[1] == b) or (p[0] == b and p[1] == a): return true
	return false

## Gives `action` this key in `slot`, and the action that had it (other, other_slot) gets what
## `action` had there.
func swap_bind(action: String, slot: int, ev: InputEvent, other: String, other_slot: int) -> void:
	var mine := slots(action)
	var theirs := slots(other)
	theirs[other_slot] = mine[slot]
	mine[slot] = ev_code(ev)
	_set_slots(other, theirs)
	_set_slots(action, mine)

func code_text(s: String) -> String:
	var parts := s.split(":")
	if parts.size() != 2: return ""
	if parts[0] == "key": return OS.get_keycode_string(int(parts[1]))
	return {1: "LMB", 2: "RMB", 3: "MMB", 4: "Wheel up", 5: "Wheel down", 8: "Mouse 4", 9: "Mouse 5"}.get(int(parts[1]), "Mouse %s" % parts[1])

func binding_text(action: String) -> String:
	var names: Array = []
	for c in slots(action):
		if c != "": names.append(code_text(c))
	return " / ".join(names) if names.size() > 0 else "unbound"

## Both bindings, short ("R / X"), where a prompt has room for them.
func key_caps(action: String) -> String:
	var out: Array = []
	for c in slots(action):
		if c == "": continue
		var t := code_text(c)
		t = {"Mouse 4": "M4", "Mouse 5": "M5"}.get(t, t)
		out.append(t.to_upper() if c.begins_with("key:") else t)
	return " / ".join(out) if out.size() > 0 else "?"

## The first binding of an action, short, for HUD key caps ("E", "LMB").
func key_cap(action: String) -> String:
	var evs := InputMap.action_get_events(action)
	if evs.is_empty():
		return "?"
	var e: InputEvent = evs[0]
	if e is InputEventKey:
		return OS.get_keycode_string((e as InputEventKey).physical_keycode).to_upper()
	if e is InputEventMouseButton:
		return {1: "LMB", 2: "RMB", 3: "MMB", 8: "M4", 9: "M5"}.get((e as InputEventMouseButton).button_index, "M%d" % (e as InputEventMouseButton).button_index)
	return "?"
