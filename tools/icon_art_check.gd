extends RefCounted
## --icon-art-check: the painted icons in art/icons (Icons.art). Every hunter ability slot has its own icon
## id and a painted icon, the 11 weapons with no glyph and every status and combat mark have one, every
## Boki ability, Fusion and shaping item resolves to its painted icon, each icon is a mipmapped 128 px
## texture, and no file in art/icons is left unused.

const SLOTS := ["dash", "rmb", "e", "x"]
const STATUSES := [
	"status_stunned",
	"status_rooted",
	"status_grounded",
	"status_dazed",
	"status_slowed",
	"status_burning",
	"status_weakened",
	"status_shielded",
	"status_guarded"
]
const MARKS := ["mark_static", "mark_thief", "mark_daze"]
## The weapons the vector set has no glyph for (docs/art/ICONS_PROPS_INVENTORY.md); the rest keep their glyphs.
const WEAPONS := [
	"quill_rifle",
	"coilcaster",
	"longbow",
	"flamethrower",
	"tower_shield",
	"rubble_fists",
	"tether_lantern",
	"hoar_fan",
	"lantern_crook",
	"spellstaff",
	"swordfish"
]
const SIZE := 128  # px: the icon masters

var bad := 0
var used := {}  # icon id -> true, for the unused-file sweep


func ok(cond: bool, what: String) -> void:
	print("ICONART %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	_hunters()
	_named("status", STATUSES)
	_named("combat mark", MARKS)
	_boki()
	_unused()
	print("ICONART DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _has(id: String) -> bool:
	used[id] = true
	var tex := Icons.art(id) as CanvasTexture
	if tex == null:
		return false
	var img := tex.diffuse_texture.get_image()
	return img.get_width() == SIZE and img.has_mipmaps()


func _missing(ids: Array) -> Array:
	return ids.filter(func(id): return not _has(String(id)))


func _hunters() -> void:
	var ids: Array = []
	for a in Arch.ids():
		for s in SLOTS:
			ids.append(String(Arch.def(a)[s]["icon"]))
	var unique := {}
	for id in ids:
		unique[id] = true
	ok(unique.size() == ids.size(), "%d hunter ability slots, each with its own icon id" % ids.size())
	var gone := _missing(ids)
	ok(gone.is_empty(), "every hunter ability slot has a painted icon %s" % [gone])
	gone = _missing(WEAPONS)
	ok(gone.is_empty(), "every weapon with no glyph has a painted icon %s" % [gone])


func _named(what: String, ids: Array) -> void:
	var gone := _missing(ids)
	ok(gone.is_empty(), "every %s has a painted icon %s" % [what, gone])


func _boki() -> void:
	var wrong: Array = []
	for id in KinLib.lib()["abilities"]:
		if KinText.icon(KinLib.ability(id)) != "boki_" + id or not _has("boki_" + id):
			wrong.append(id)
	ok(wrong.is_empty(), "every Boki ability draws its painted icon %s" % [wrong])
	wrong = []
	for id in KinLib.lib()["merges"]:
		if KinText.merge_icon(KinLib.merge(id)) != "merge_" + id or not _has("merge_" + id):
			wrong.append(id)
	ok(wrong.is_empty(), "every Fusion draws its painted icon %s" % [wrong])
	wrong = []
	for id in GardenItems.ids():
		if ItemPages.icon_of(id) != "garden_" + id or not _has("garden_" + id):
			wrong.append(id)
	ok(wrong.is_empty(), "every shaping item draws its painted icon %s" % [wrong])


func _unused() -> void:
	var spare: Array = []
	for f in DirAccess.get_files_at(Icons.ART_DIR):
		if f.ends_with(".png") and not used.has(f.get_basename()):
			spare.append(f)
	ok(spare.is_empty(), "no painted icon is left unused %s" % [spare])
