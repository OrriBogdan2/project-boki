extends RefCounted
## --save-safe-check: a save cut off mid-write never costs the player their save (docs/decisions/0061).
## Runs in its own XDG_DATA_HOME (the tool writes real files there). Lines: SAVESAFE ok|FAIL <what>.
##  1. Two saves, then the file on disk is cut short (the game died while writing it): loading brings
##     back the last whole save, not a fresh one.
##  2. The game died between the two steps of a save (the new copy is whole, the file isn't there):
##     loading brings back the newest save.
##  3. A clean save and load round-trips.

const SLOT := 3               # a slot of its own: never the player's first save

var main: Node
var bad := 0
var n := 0

func ok(cond: bool, what: String, info := "") -> void:
	n += 1
	print("SAVESAFE %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = false
	Save.slot = SLOT
	var p := Save.path_for(SLOT)
	_save_as("Older")
	_save_as("Keeper")
	Save.load_game()
	ok(String(Save.d.get("name", "")) == "Keeper", "a clean save loads back", String(Save.d.get("name", "")))
	var full := FileAccess.get_file_as_string(p)
	_write(p, full.substr(0, full.length() / 2))
	Save.load_game()
	var got := String(Save.d.get("name", ""))
	ok(got in ["Keeper", "Older"], "a save cut short mid-write loads the last whole one", got)
	_save_as("Keeper")
	DirAccess.rename_absolute(ProjectSettings.globalize_path(p), ProjectSettings.globalize_path(p + ".tmp"))
	Save.load_game()
	got = String(Save.d.get("name", ""))
	ok(got == "Keeper", "a save that died between its two steps loads the newest", got)
	Save.no_write = true
	print("SAVESAFE DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _save_as(nm: String) -> void:
	Save.d = Save.fresh()
	Save.d["name"] = nm
	Save.save_game()

func _write(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()
