extends RefCounted
## --unref-check: every .gd and .tscn in the project is named by some other file, through its path,
## its file name, its uid or its class_name (code comments count, docs/*.md do not). Entry points that
## nothing names on purpose (F6 galleries, `godot -s` tools, paths built from strings) are listed in
## tools/unref_allow.txt with a reason. A new file that fails: wire it in, delete it, or list it.
## Not transitive: a scene only another dead file names still passes (docs/CODE_HEALTH.md).

const ALLOW := "res://tools/unref_allow.txt"
const TEXT_EXT := ["gd", "tscn", "tres", "gdshader", "cfg", "godot", "json", "py", "sh", "yml", "txt"]
const TARGET_EXT := ["gd", "tscn"]

var _texts := {}      # res path -> its text, for every file that may name a script or scene
var _targets: Array[String] = []

func run(main: Node) -> void:
	var t0 := Time.get_ticks_msec()
	_walk("res://")
	var named := _named()
	var allow := _allowed()
	var bad := 0
	for t in _targets:
		if named.has(t) or allow.has(t):
			continue
		print("UNREF FAIL %s: nothing names it (wire it in, delete it, or list it in %s)" % [t, ALLOW])
		bad += 1
	for a in allow:
		if not FileAccess.file_exists(a):
			print("UNREF FAIL %s: listed in %s but gone (drop the line)" % [a, ALLOW])
			bad += 1
	print("UNREF DONE, %d files, %d ms, failures: %d" % [_targets.size(), Time.get_ticks_msec() - t0, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _walk(dir: String) -> void:
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_walk(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		var path := dir.path_join(f)
		var ext := f.get_extension()
		if ext in TARGET_EXT:
			_targets.append(path)
		if ext in TEXT_EXT and path != ALLOW:
			_texts[path] = FileAccess.get_file_as_string(path)

## Every target some other file names: res path -> true.
func _named() -> Dictionary:
	var by_path := {}
	var by_file := {}
	var by_uid := {}
	var by_class := {}
	var cls_rx := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	var scene_uid_rx := RegEx.create_from_string("^\\[gd_scene[^\\]]*uid=\"(uid://\\w+)\"")
	for t in _targets:
		by_path[t] = t
		by_file[t.get_file()] = by_file.get(t.get_file(), []) + [t]
		var uid := FileAccess.get_file_as_string(t + ".uid").strip_edges() if FileAccess.file_exists(t + ".uid") else ""
		var m := scene_uid_rx.search(String(_texts.get(t, "")))
		if m: uid = m.get_string(1)
		if uid != "": by_uid[uid] = t
		m = cls_rx.search(String(_texts.get(t, "")))
		if m: by_class[m.get_string(1)] = t
	var path_rx := RegEx.create_from_string("[\\w./:-]+\\.(?:gd|tscn)\\b")
	var uid_rx := RegEx.create_from_string("uid://\\w+")
	var word_rx := RegEx.create_from_string("\\b[A-Z]\\w+\\b")
	var named := {}
	for f in _texts:
		var text: String = _texts[f]
		var hits: Array = []
		for m in path_rx.search_all(text):
			var p := "res://" + m.get_string().trim_prefix("res://").trim_prefix("./")
			hits += [by_path[p]] if by_path.has(p) else by_file.get(p.get_file(), [])
		for m in uid_rx.search_all(text):
			if by_uid.has(m.get_string()): hits.append(by_uid[m.get_string()])
		if f.get_extension() == "gd" or f.get_extension() == "tscn":
			for m in word_rx.search_all(text):
				if by_class.has(m.get_string()): hits.append(by_class[m.get_string()])
		for h in hits:
			if h != f: named[h] = true
	return named

## The allowlist's paths as res paths (one per line; text after # is the reason).
func _allowed() -> Dictionary:
	var out := {}
	for line in FileAccess.get_file_as_string(ALLOW).split("\n"):
		var p := line.get_slice("#", 0).strip_edges()
		if p != "": out["res://" + p] = true
	return out
