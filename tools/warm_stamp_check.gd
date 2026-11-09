extends RefCounted
## --warm-stamp-check: the warm-up's keys name the same shaders on every launch (two copies of one shader
## code give one key, a different code another), and WarmStamp keeps them only while the engine caches
## do: a saved stamp is read back, and is dropped when the shader cache lost files, when the pipeline
## cache is older than the stamp, or when it was written for another setup.

var bad := 0

func run(main: Node) -> void:
	Save.no_write = true
	var code := "shader_type spatial;\nvoid fragment() { ALBEDO = vec3(0.5); }\n"
	var a := ShaderMaterial.new()
	a.shader = Shader.new()
	a.shader.code = code
	var b := ShaderMaterial.new()
	b.shader = Shader.new()
	b.shader.code = code
	var c := ShaderMaterial.new()
	c.shader = Shader.new()
	c.shader.code = code.replace("0.5", "0.6")
	_ok("one code, one key", WarmUp._mat_key(a) == WarmUp._mat_key(b))
	_ok("another code, another key", WarmUp._mat_key(a) != WarmUp._mat_key(c))
	var lb := Label3D.new()
	lb.material_override = a
	var lb2 := Label3D.new()
	lb2.material_override = b
	_ok("label keys name no instance", WarmUp._key(lb) == WarmUp._key(lb2))
	lb.free()
	lb2.free()
	# a cache to stamp against (the headless run has no real one)
	DirAccess.make_dir_recursive_absolute(WarmStamp.SHADER_CACHE.path_join("check"))
	DirAccess.make_dir_recursive_absolute(WarmStamp.PIPELINE_DIR)
	var cache_file := WarmStamp.SHADER_CACHE.path_join("check/a.cache")
	var pipes := WarmStamp.PIPELINE_DIR.path_join("pipelines.check.cache")
	FileAccess.open(cache_file, FileAccess.WRITE).store_8(1)
	var keys := {WarmUp._mat_key(a): true, "skel:x": true}
	WarmStamp.save(keys)
	FileAccess.open(pipes, FileAccess.WRITE).store_8(1)
	_ok("a stamp reads back", WarmStamp.warm_keys().size() == keys.size())
	_ok("an older pipeline cache is not trusted", not WarmStamp.trusted(1, int(Time.get_unix_time_from_system()) + 60))
	DirAccess.remove_absolute(cache_file)
	_ok("a shader cache that lost files is not trusted", WarmStamp.warm_keys().is_empty())
	FileAccess.open(cache_file, FileAccess.WRITE).store_8(1)
	var st := JSON.parse_string(FileAccess.get_file_as_string(WarmStamp.PATH)) as Dictionary
	st["id"] = "another setup"
	FileAccess.open(WarmStamp.PATH, FileAccess.WRITE).store_string(JSON.stringify(st))
	_ok("another setup's stamp is not read", WarmStamp.warm_keys().is_empty())
	_ok("an empty cache is never trusted", not WarmStamp.trusted(0, 0))
	for p in [cache_file, pipes, WarmStamp.PATH]:
		DirAccess.remove_absolute(p)
	print("WSTAMP DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _ok(what: String, cond: bool) -> void:
	print("WSTAMP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1
