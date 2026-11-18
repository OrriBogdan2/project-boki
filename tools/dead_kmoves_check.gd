extends RefCounted
## --dead-kmoves-check: per Hunter's warden_anim json, every kmove it maps must be played by a kit or shared code,
## and every move a kit plays (play("xxx_...") of a keyed move) must be mapped. The motion tables (kmoves_*.gd)
## and the demo lists only define or list moves, they never play them. Clips stay in the GLBs (art).
## Never touches the save.

const ANIM_DIR := "res://content/rules/warden_anim/"
const SCRIPTS := "res://scripts"
## Keyed-move prefixes of the Hunters' kits (kit play() calls of these must be mapped).
const PREFIXES := ["arc_", "pin_", "bul_", "gunslinger_", "mage_", "thf_", "breah_",
	"ostra_", "tm_", "as_", "dr_",
	"mm_", "jug_"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		bad += 1
		print("FAIL ", what)

func _scripts(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and not f.begins_with("kmoves_") and f != "arena_demo.gd":
			out.append(FileAccess.get_file_as_string(dir.path_join(f)))
	for d in DirAccess.get_directories_at(dir):
		_scripts(dir.path_join(d), out)

func run(main: Node) -> void:
	Save.no_write = true
	var srcs: Array = []
	_scripts(SCRIPTS, srcs)
	var text := "\n".join(srcs)
	var mapped := {}
	for f in DirAccess.get_files_at(ANIM_DIR):
		if not f.ends_with(".json"):
			continue
		var kmoves: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ANIM_DIR + f)).get("kmoves", {})
		for k in kmoves:
			mapped[k] = true
			ok(text.contains('"%s"' % k), "%s maps %s, which nothing plays" % [f, k])
	var re := RegEx.create_from_string('\\bplay\\("([a-z0-9_]+)"')
	for m in re.search_all(text):
		var mv := m.get_string(1)
		for p in PREFIXES:
			if mv.begins_with(p):
				ok(mapped.has(mv), "played move %s has no mapping" % mv)
	print("DEAD_KMOVES_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
