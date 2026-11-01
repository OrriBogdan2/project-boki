extends Node
## Game settings. They belong to the player, not to a save file, so every save shares them
## (user://settings.cfg). Changing one applies it right away.

signal changed(key: String)

const PATH := "user://settings.cfg"
const DEFAULTS := {
	# audio
	"master": 0.8, "music": 0.7, "sfx": 1.0, "ambience": 0.8, "mute_unfocused": false,
	# video
	"fullscreen": false, "vsync": true, "max_fps": 0, "msaa": 4, "video_v": 2, "shadows": true, "ui_scale": 1.0, "show_fps": false,
	"quality": "auto", "quality_found": "",
	# gameplay
	"shake": 1.0, "cam_lead": 1.0, "cam_style": "supervive", "cam_follow": "supervive", "dash_hold": false, "damage_numbers": true, "tips": true, "cast_on_press": true, "crouch_toggle": false, "mod_mode": false, "kin_auto": false, "kin_chatter": "normal", "bot_diff": "auto",
	# accessibility
	"reduce_flashes": false, "hud_opacity": 1.0,
	# demo / recording (Settings > Demo): for filming a match, offline only (online matches use the host's rules)
	"demo_weather": "random", "demo_blight": true, "demo_fresh": "normal", "rec_level": 0,
	# controls: action -> list of "key:<physical keycode>" / "mouse:<button>"
	"keys": {}, "keys_v": 2,
}
## Graphics presets (Video → Quality). High is the game's full look; Low and Medium trade detail for
## speed, Ultra pushes draw distance, shadows and level of detail further. A preset sets the plain
## settings (msaa, shadows) and these knobs, which the renderer and the world builder read through q():
##   scale: 3D render scale  ·  lod: mesh LOD threshold (pixels of error allowed)  ·  grass: share of grass
##   tufts and flowers kept  ·  draw: how far small scatter, undergrowth and motes are drawn (x)  ·
##   shadow_k: shadow distance (x)  ·  splits: shadow cascades  ·  soft: soft-shadow filter quality  ·
##   ssao, glow: the desktop renderer's ambient occlusion and bloom  ·  clouds: drifting cloud layers
##   over the sea  ·  shafts: light shafts into the void  ·  fx: particle amounts (x)
const QUALITY := {
	"low": {"name": "Low", "msaa": 0, "shadows": false, "scale": 0.8, "lod": 4.0, "grass": 0.4, "draw": 0.6, "shadow_k": 0.7, "splits": 1, "soft": 0,
		"ssao": false, "glow": false, "clouds": 0, "shafts": false, "fx": 0.45, "volfog": false},
	"medium": {"name": "Medium", "msaa": 2, "shadows": true, "scale": 1.0, "lod": 2.0, "grass": 0.7, "draw": 0.8, "shadow_k": 0.8, "splits": 2, "soft": 1,
		"ssao": false, "glow": true, "clouds": 1, "shafts": true, "fx": 0.7, "volfog": false},
	"high": {"name": "High", "msaa": 4, "shadows": true, "scale": 1.0, "lod": 1.0, "grass": 1.0, "draw": 1.0, "shadow_k": 1.0, "splits": 4, "soft": 3,
		"ssao": true, "glow": true, "clouds": 2, "shafts": true, "fx": 1.0, "volfog": true},
	"ultra": {"name": "Ultra", "msaa": 4, "shadows": true, "scale": 1.0, "lod": 0.5, "grass": 1.0, "draw": 1.6, "shadow_k": 1.35, "splits": 4, "soft": 4,
		"ssao": true, "glow": true, "clouds": 2, "shafts": true, "fx": 1.0, "volfog": true},
}
const QUALITY_ORDER := ["low", "medium", "high", "ultra"]

## The preset in effect: the player's pick, or what auto-detect found for this machine.
func quality() -> String:
	var qv := String(v.get("quality", "auto"))
	if QUALITY.has(qv):
		return qv
	var found := String(v.get("quality_found", ""))
	return found if QUALITY.has(found) else detect_quality()

## A knob of the preset in effect (see QUALITY).
func q(key: String):
	return QUALITY[quality()].get(key, QUALITY["high"][key])

## A first guess from the graphics adapter: software renderers get Low, integrated GPUs and browsers
## Medium, discrete GPUs High. The first expedition's loading screen then measures real frames and
## steps it down if they come in slow (see note_benchmark).
func detect_quality() -> String:
	if OS.has_feature("web"):
		return "medium"
	if DisplayServer.get_name() == "headless":
		return "high"
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU: return "high"
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU, RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU: return "medium"
		RenderingDevice.DEVICE_TYPE_CPU: return "low"
	var nm := RenderingServer.get_video_adapter_name().to_lower()
	if nm.contains("llvmpipe") or nm.contains("swiftshader") or nm.contains("software"): return "low"
	if nm.contains("intel") or nm.contains("integrated") or nm.contains("vega") and nm.contains("graphics"): return "medium"
	return "high"

## Auto quality only: frame times measured while the first expedition loads (ms, the world on screen
## from the skyship). Too slow for 60 fps steps the preset down once and remembers it.
func note_benchmark(ms: float) -> void:
	if String(v.get("quality", "auto")) != "auto" or String(v.get("quality_found", "")) != "":
		return
	var cur := quality()
	var i := QUALITY_ORDER.find(cur)
	if ms > 20.0 and i > 0:
		cur = QUALITY_ORDER[i - 1]
		if ms > 34.0 and i > 1: cur = QUALITY_ORDER[i - 2]
	v["quality_found"] = cur
	apply("quality")
	save()
	print("Quality: auto picked %s (load benchmark %.1f ms a frame)" % [cur, ms])

## Bumped when the default kit changes enough that old custom bindings would be nonsense.
const KEYS_V := 3

## Rebindable actions, in the order the controls list shows them.
const ACTIONS := [
	["up", "Move up"], ["down", "Move down"], ["left", "Move left"], ["right", "Move right"],
	["fire", "Weapon attack"], ["secondary", "Archetype ability (right click)"], ["dash", "Archetype dash"], ["jump", "Jump (hold to glide)"], ["glide", "Glide (hold in the air)"], ["crouch", "Sneak"],
	["gear1", "Glove active"], ["signature", "Archetype utility (E)"], ["kin_ability", "Boki ability (hops out, casts, hops back)"], ["throw", "Send / recall Boki"], ["ultimate", "Archetype ultimate (bonded when bond is full)"], ["base", "Base to a teammate (squads)"],
	["interact", "Use, tame, revive, pet"], ["tonic", "Heal (tonic, or armor kit when health is full)"], ["armor_kit", "Repair armor (armor kit)"], ["scores", "Scoreboard"], ["emote", "Emote wheel (hold, in a match)"],
	["map", "Full map (click to ping)"], ["pass_lead", "Pass the drop lead"], ["separate", "Separate from the drop"],
	["play", "Play fetch with a Boki"], ["talk", "Talk to a Boki"], ["details", "A Boki's details"], ["inventory", "Inventory"],
	["build", "Build mode at home / decorate indoors"], ["rotate", "Turn a piece (build mode)"],
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
		for pair in [["volume", "master"], ["music", "music"], ["shake", "shake"], ["cam_lead", "cam_lead"]]:
			if old.has(pair[0]): v[pair[1]] = float(old[pair[0]])
	if not cf.has_section_key("s", "keys_v") and String(v.get("cam_follow", "")) == "standard":
		v["cam_follow"] = "supervive"     # the new Supervive-style cursor lean becomes everyone's default once
	if int(v.get("keys_v", 1)) < KEYS_V or not cf.has_section_key("s", "keys_v"):
		v["keys"] = {}          # the kit changed (archetypes: E utility, C kin ability, G send/recall): start from the new defaults
		v["keys_v"] = KEYS_V
	if int(v.get("video_v", 1)) < 2 or not cf.has_section_key("s", "video_v"):
		# crisper by default: 4x MSAA on desktop (the browser build stays on 2x)
		if int(v.get("msaa", 2)) == 2 or not cf.has_section_key("s", "msaa"): v["msaa"] = 2 if OS.has_feature("web") else 4
		v["video_v"] = 2
	# a first run (or the first since presets came in) takes the preset's anti-aliasing and shadows
	_quality_basics = not cf.has_section_key("s", "quality")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			v["quality"] = a.substr(10); _quality_basics = true      # tooling: try a preset without saving it
	if not cf.has_section_key("s", "crouch_toggle") and OS.has_feature("web"):
		v["crouch_toggle"] = true      # browsers close the tab on Ctrl+W, so don't make people hold Ctrl
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_apply_ui_scale)

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
## level of detail, shadow filtering, and the lights and environments already in the scene. The
## world's own detail (grass, draw distance, cloud layers, particles) follows from the next expedition.
func _apply_quality() -> void:
	var Q: Dictionary = QUALITY[quality()]
	if _started or _quality_basics:
		_quality_basics = false
		v["msaa"] = int(Q["msaa"]) if not OS.has_feature("web") else mini(int(Q["msaa"]), 2)
		v["shadows"] = bool(Q["shadows"])
		apply("msaa"); apply("shadows")
	var root := get_tree().root
	root.scaling_3d_scale = float(Q["scale"])
	root.mesh_lod_threshold = float(Q["lod"])
	RenderingServer.directional_soft_shadow_filter_set_quality(int(Q["soft"]))
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

## Replaces an action's main binding with this key or mouse button.
func rebind(action: String, ev: InputEvent) -> void:
	var list := _events_to_list(InputMap.action_get_events(action))
	var s := ""
	if ev is InputEventKey: s = "key:%d" % (ev as InputEventKey).physical_keycode
	elif ev is InputEventMouseButton: s = "mouse:%d" % (ev as InputEventMouseButton).button_index
	if s == "":
		return
	# keep any second binding (the arrow keys for moving), replace the first
	if list.size() > 0: list[0] = s
	else: list.append(s)
	_bind(action, list)
	var keys: Dictionary = v["keys"]
	keys[action] = list
	save()
	changed.emit("keys")

func binding_text(action: String) -> String:
	var names: Array = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			names.append(OS.get_keycode_string((e as InputEventKey).physical_keycode))
		elif e is InputEventMouseButton:
			names.append({1: "LMB", 2: "RMB", 3: "MMB", 4: "Wheel up", 5: "Wheel down", 8: "Mouse 4", 9: "Mouse 5"}.get((e as InputEventMouseButton).button_index, "Mouse %d" % (e as InputEventMouseButton).button_index))
	return " / ".join(names) if names.size() > 0 else "unbound"

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
