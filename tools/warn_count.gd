extends SceneTree
## Loads every script under scripts/ and tools/ so Godot prints its GDScript warnings.
## tools/lint_gate.py runs this headless and counts the "(UNUSED_*)" lines per file.


func _init() -> void:
	process_frame.connect(_load_all, CONNECT_ONE_SHOT)


func _load_all() -> void:
	for dir in ["res://scripts", "res://tools"]:
		_load_dir(dir)
	quit()


func _load_dir(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			load(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_load_dir(dir + "/" + d)
