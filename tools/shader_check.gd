extends RefCounted
## --shader-check (docs/CODE_HEALTH.md, Shaders): every shader compiles and every uniform name the game sets
## exists. A bad name in set_shader_parameter is silently ignored by Godot (no error, the look just stays at
## the default), so drift between a shader and the code or data that drives it only shows up in review shots.
## Compiles headless (the dummy renderer runs the same shader parser as both real renderers):
##   1. every .gdshader in the project, reloaded uncached so its errors land in this check's logger;
##   2. every shader written as a """shader_type ...""" string in scripts/, and every KitShaders kind;
## then checks uniform names against the compiled shaders:
##   3. each set_shader_parameter("name") and KitShaders.param(_, "name") in scripts/ names a uniform of
##      some shader (KitShaders.param: of a KitShaders kind);
##   4. WardenGlb's shared looks and every content/rules/warden_look.json section name a uniform of the
##      shader WardenGlb sets them on.
## Names built at run time (set_shader_parameter(k, ...) over other dicts) are not covered.

const SCAN_SKIP := [".godot", ".git", "docs", "builds"]      # res:// folders with no game shaders
const STRING_SHADER := "\"\"\"\\s*(shader_type [\\s\\S]*?)\"\"\""
const KIT_KIND := "(?m)^\\t\\t\"(\\w+)\":$"      # the kinds in KitShaders._code's match
const SET_NAME := "set_shader_parameter\\(\\s*\"(\\w+)\""
const KIT_NAME := "KitShaders\\.param\\([^,()]+,\\s*\"(\\w+)\""
## a warden_look.json halo key WardenGlb reads itself (the node it sits on), not a uniform
const LOOK_NOT_UNIFORM := ["anchor"]

## Counts the errors printed while a shader compiles (SHADER ERROR lines and "Shader compilation failed").
class ErrorTap extends Logger:
	var errors := 0
	var last := ""

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		errors += 1
		if last == "":
			last = code if rationale == "" else rationale

var fails := 0
var tap := ErrorTap.new()
var all_uniforms := {}      # every uniform name of every compiled shader
var kit_uniforms := {}      # every uniform of every KitShaders kind

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("SHADER FAIL %s" % what)
		fails += 1

func run(main: Node) -> void:
	OS.add_logger(tap)
	var paths: Array[String] = []
	_find(paths, "res://", ".gdshader")
	for path in paths:
		_compile(ResourceLoader.load(path, "Shader", ResourceLoader.CACHE_MODE_IGNORE) as Shader, path)
	var scripts: Array[String] = []
	_find(scripts, "res://scripts", ".gd")
	var strings := _string_shaders(scripts)
	_kit_kinds()
	_names(scripts)
	_warden_look()
	OS.remove_logger(tap)
	print("SHADER compiled %d files, %d script strings, %d KitShaders uniforms" % [paths.size(), strings,
			kit_uniforms.size()])
	print("SHADER DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _find(out: Array[String], dir: String, ext: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with(".") and not dir.path_join(sub).trim_prefix("res://") in SCAN_SKIP:
			_find(out, dir.path_join(sub), ext)
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == ext.trim_prefix("."):
			out.append(dir.path_join(f))

## Compiles one shader and returns its uniform names (failing the check on any compile error).
func _compile(sh: Shader, what: String) -> Dictionary:
	var before := tap.errors
	tap.last = ""
	var names := {}
	if sh == null:
		ok(false, "%s does not load" % what)
		return names
	for u in sh.get_shader_uniform_list():
		names[String(u["name"])] = true
	all_uniforms.merge(names)
	ok(tap.errors == before, "%s does not compile: %s" % [what, tap.last])
	ok(sh.code.strip_edges() != "", "%s is empty" % what)
	return names

func _string_shaders(scripts: Array[String]) -> int:
	var re := RegEx.create_from_string(STRING_SHADER)
	var n := 0
	for path in scripts:
		if path.ends_with("kit_shaders.gd"):
			continue      # its strings are pieces; _kit_kinds compiles the assembled kinds
		var src := FileAccess.get_file_as_string(path)
		if not src.contains("shader_type "):
			continue
		for m in re.search_all(src):
			var sh := Shader.new()
			sh.code = m.get_string(1)
			_compile(sh, "%s (string shader %d)" % [path, n])
			n += 1
	return n

func _kit_kinds() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/arch/kits/kit_shaders.gd")
	var kinds := RegEx.create_from_string(KIT_KIND).search_all(src)
	ok(kinds.size() > 5, "KitShaders kinds found (%d)" % kinds.size())
	for m in kinds:
		var body := KitShaders.mat(m.get_string(1), Color.WHITE, true)
		for pass_mat in [body, body.next_pass]:
			var sh := Shader.new()      # compiled afresh: KitShaders caches its shaders, maybe from before the tap
			sh.code = (pass_mat as ShaderMaterial).shader.code
			kit_uniforms.merge(_compile(sh, "KitShaders " + m.get_string(1)))

func _names(scripts: Array[String]) -> void:
	var set_re := RegEx.create_from_string(SET_NAME)
	var kit_re := RegEx.create_from_string(KIT_NAME)
	for path in scripts:
		var src := FileAccess.get_file_as_string(path)
		for m in set_re.search_all(src):
			ok(all_uniforms.has(m.get_string(1)), "%s sets \"%s\", a uniform no shader has" % [path, m.get_string(1)])
		for m in kit_re.search_all(src):
			ok(kit_uniforms.has(m.get_string(1)), "%s KitShaders.param \"%s\": no KitShaders kind has it" % [path,
					m.get_string(1)])

## WardenGlb sets these dicts' keys as uniforms by name: hero_toon (Models.HERO) for the shared looks and a
## look's painted and per-slot keys, outline (Models.OUTLINE) for ink and glow_shell, the card, flame and halo
## slots their own shader.
func _warden_look() -> void:
	var toon := _uniforms(Models.HERO)
	var ink := _uniforms(Models.OUTLINE)
	var card := _uniforms(WardenGlb.CARD)
	var flame := _uniforms(WardenGlb.FLAME)
	var halo := _uniforms(WardenGlb.HALO)
	_keys(WardenGlb.PAINTED, toon, "WardenGlb.PAINTED")
	_keys(WardenGlb.FAR_LOOK, toon, "WardenGlb.FAR_LOOK")
	_keys(WardenGlb.ICE, toon, "WardenGlb.ICE")
	_keys(WardenGlb.GLOW_SHELL, ink, "WardenGlb.GLOW_SHELL")
	var looks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/warden_look.json"))
	ok(looks != null, "content/rules/warden_look.json parses")
	for art in (looks if looks else {}):
		var own = looks[art]
		if not own is Dictionary:
			continue
		var at := "warden_look.json %s." % art
		_keys(own.get("painted", {}), toon, at + "painted")
		_keys(own.get("ink", {}), ink, at + "ink")
		_keys(own.get("glow_shell", {}), ink, at + "glow_shell")
		for slot in own.get("slots", {}):
			var pool := toon
			if slot == "card":
				pool = card
			elif String(slot).begins_with("flame-"):
				pool = flame
			_keys(own["slots"][slot], pool, at + "slots." + slot)
		for h in own.get("halos", []):
			_keys(h, halo, at + "halos")

func _uniforms(sh: Shader) -> Dictionary:
	var names := {}
	for u in sh.get_shader_uniform_list():
		names[String(u["name"])] = true
	return names

func _keys(d: Dictionary, uniforms: Dictionary, what: String) -> void:
	for k in d:
		var known := uniforms.has(String(k)) or String(k) in LOOK_NOT_UNIFORM
		ok(known, "%s \"%s\" is not a uniform of its shader" % [what, k])
