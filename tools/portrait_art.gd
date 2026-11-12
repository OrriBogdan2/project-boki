extends SceneTree
## Brings the Wardens' painted portraits into the game (Portraits): reads the art pass's sources
## (<name>_portrait.webp or .png, all in one dir) and writes art/portraits/<archetype>.jpg (PORTRAIT_PX square).
## Re-run it when the art pass updates a Warden:
##   godot --headless --script tools/portrait_art.gd -- --src=<dir with the wardens' portraits>
## --only=archer,ostra writes just those archetypes (the others' files stay byte-identical). A missing portrait
## leaves that file alone, and a source that is not square is cut from its centre. The splashes are made at full
## size by tools/splash_art.py.

const OUT := "res://art/portraits/"
const PORTRAIT_PX := 512      # px: the biggest place a portrait shows is the HUD's 112x132 slot (at 2x)
const QUALITY := 0.88         # JPEG quality: no visible banding on the painted gradients
## The art pass names each Warden; the game knows them by archetype id (docs/art/concepts/README.md).
const ART_NAMES := {
	"bulwark": "breaker", "archer": "lisette", "juggernaut": "kael", "thief": "sable", "mage": "ryzz",
	"dolm": "tarek", "ostra": "motley", "ashwick": "cinder", "gunslinger": "vex", "tender": "pip",
	"rimewright": "claire", "dredge": "grimble",
}

func _init() -> void:
	var src := ""
	var only: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--src="):
			src = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
	if src == "":
		printerr("portrait_art: pass --src=<dir>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for ak in ART_NAMES:
		if not only.is_empty() and not only.has(ak):
			continue
		var art: String = ART_NAMES[ak]
		var portrait := src.path_join(art + "_portrait.webp")
		if not FileAccess.file_exists(portrait):
			portrait = src.path_join(art + "_portrait.png")
		if FileAccess.file_exists(portrait):
			_write(portrait, OUT + ak + ".jpg", Vector2i(PORTRAIT_PX, PORTRAIT_PX))
	quit()

func _write(from: String, to: String, px: Vector2i) -> void:
	var img := Image.load_from_file(from)
	if img == null or img.is_empty():
		printerr("portrait_art: can't read %s" % from)
		return
	img.convert(Image.FORMAT_RGB8)
	var keep := Vector2i(mini(img.get_width(), img.get_height() * px.x / px.y),
			mini(img.get_height(), img.get_width() * px.y / px.x))
	img = img.get_region(Rect2i((img.get_size() - keep) / 2, keep))   # centre-cut, never stretched
	img.resize(px.x, px.y, Image.INTERPOLATE_LANCZOS)
	img.save_jpg(ProjectSettings.globalize_path(to), QUALITY)
	print("portrait_art: %s -> %s" % [from.get_file(), to])
