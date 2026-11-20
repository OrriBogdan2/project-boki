extends SceneTree
## Compiles every script listed in the file named by FLEET_SCRIPT_LIST (one path per
## line, relative to res://). Run by tools/check.sh; not part of the game.
##
## It runs in _initialize(), not _init(), because autoloads only exist from
## _initialize() on. `godot --check-only --script x.gd` compiles before autoloads are
## registered, so it reports "Identifier not found" for every script that uses one.
func _initialize() -> void:
	var list_path := OS.get_environment("FLEET_SCRIPT_LIST")
	var list := FileAccess.open(list_path, FileAccess.READ)
	if list == null:
		print("FLEET_PARSE_SETUP cannot open list: ", list_path)
		quit(2)
		return
	var checked := 0
	var bad := 0
	while not list.eof_reached():
		var path := list.get_line().strip_edges()
		if path == "":
			continue
		checked += 1
		var res: Resource = ResourceLoader.load("res://" + path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not (res is Script) or not (res as Script).can_instantiate():
			bad += 1
			print("FLEET_PARSE_BAD ", path)
	print("FLEET_PARSE checked=%d bad=%d" % [checked, bad])
	quit(1 if bad > 0 else 0)
