class_name WarmStamp
extends RefCounted
## What an earlier launch's warm-up (WarmUp) already drew, kept in PATH, so a later launch on the same
## machine, build and graphics settings skips the stand-ins whose shaders the engine's disk caches still
## hold, so the warm-up is done once. The keys are WarmUp._key strings,
## which name shaders by their code, so they mean the same thing on every launch.
##
## Trusted only when the engine caches really kept them:
## - Compatibility (OpenGL): the shader cache (user://shader_cache) saves every compiled variant as it
##   compiles and loads all of a shader's variants with it. Trusted while it holds at least the files it
##   held when the stamp was written (drivers without program binaries write none: never trusted).
## - Forward+ / Mobile on Vulkan or D3D12: the same, and the pipeline cache (user://vulkan/pipelines.*)
##   was written after the stamp (it is saved on quit, so a crash before that leaves the stamp untrusted).
## - Metal: never. Godot 4.6's Metal driver keeps no pipeline cache, so the warm-up is drawn every launch.

const PATH := "user://warm_stamp.json"
const SHADER_CACHE := "user://shader_cache"
const PIPELINE_DIR := "user://vulkan"
const MAX_KEYS := 6000      # keys: a stamp is a few hundred; far more means keys stopped repeating

## The keys a trusted stamp says are warm ({} when there is none, it is for another setup or the
## caches lost them). --no-warm-stamp ignores it.
static func warm_keys() -> Dictionary:
	if "--no-warm-stamp" in OS.get_cmdline_user_args() or not FileAccess.file_exists(PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY or String(d.get("id", "")) != setup_id():
		PerfLog.note("warm stamp: for another setup (%s, now %s)" % [str(d.get("parts", []) if d is Dictionary else []),
				str(_setup_parts())])
		return {}
	if not trusted(int(d.get("files", 0)), int(d.get("unix", 0))):
		PerfLog.note("warm stamp: caches lost it (shader cache %d files, stamp saw %d; pipeline cache %d, stamp %d)"
				% [_cache_files(SHADER_CACHE), int(d.get("files", 0)), _newest_pipeline_cache(), int(d.get("unix", 0))])
		return {}
	var out := {}
	for k in d.get("keys", []):
		out[String(k)] = true
	return out

## Writes the stamp after a finished warm-up: `drawn` is every key it has drawn (or had warm).
static func save(drawn: Dictionary) -> void:
	if drawn.is_empty() or drawn.size() > MAX_KEYS or _driver() == "metal":
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"id": setup_id(), "parts": _setup_parts(), "files": _cache_files(SHADER_CACHE),
			"unix": int(Time.get_unix_time_from_system()), "keys": drawn.keys()}))
	f.close()

## Whether the engine caches hold what a stamp written at `unix` with `files` cache files saw.
static func trusted(files: int, unix: int) -> bool:
	var drv := _driver()
	if drv == "metal" or files <= 0 or _cache_files(SHADER_CACHE) < files:
		return false
	if drv == "opengl3":
		return true
	return _newest_pipeline_cache() >= unix

## What a stamp is for: the engine and game build, the renderer and GPU, and the graphics settings
## that change which shaders a match compiles.
static func setup_id() -> String:
	return str(_setup_parts()).md5_text()

static func _setup_parts() -> Array:
	var parts: Array = [Engine.get_version_info().get("hash", ""), Net.VERSION,
		RenderingServer.get_current_rendering_method(), _driver(), RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version()]
	parts.append(Settings.quality())
	for k in ["shadows", "msaa", "warden_models"]:
		parts.append(str(Settings.get_v(k)))
	return parts

static func _driver() -> String:
	return RenderingServer.get_current_rendering_driver_name()

static func _cache_files(dir: String) -> int:
	var n := 0
	var da := DirAccess.open(dir)
	if da == null:
		return 0
	n += da.get_files().size()
	for sub in da.get_directories():
		n += _cache_files(dir.path_join(sub))
	return n

static func _newest_pipeline_cache() -> int:
	var best := 0
	var da := DirAccess.open(PIPELINE_DIR)
	if da == null:
		return 0
	for f in da.get_files():
		if f.begins_with("pipelines.") and f.ends_with(".cache"):
			best = maxi(best, FileAccess.get_modified_time(PIPELINE_DIR.path_join(f)))
	return best
