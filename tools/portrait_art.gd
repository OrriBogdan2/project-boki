extends SceneTree
## Brings the Wardens' painted portraits and splashes into the game (Portraits): reads the art pass's
## 2K sources (docs/art/gen/wardens_r3 and wardens_r2 on ext/imagegen, newest of each, in one dir:
## <name>_portrait.webp and <name>_splash.webp) and
## writes art/portraits/<archetype>.jpg (PORTRAIT_PX square) and <archetype>_splash.jpg (SPLASH_W wide).
## Re-run it when the art pass updates a Warden:
##   godot --headless --script tools/portrait_art.gd -- --src=<dir with the wardens' PNGs>
## --only=archer,ostra writes just those archetypes (the others' files stay byte-identical). A source may be
## <name>_portrait.webp or .png and <name>_splash.webp or .png (the owner-made art is PNG, 16:9 splashes).

const OUT := "res://art/portraits/"
const PORTRAIT_PX := 512      # px: the biggest place a portrait shows is the HUD's 112x132 slot (at 2x)
const SPLASH_W := 960         # px: the kit card's banner is 862 px wide
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
		_write(portrait, OUT + ak + ".jpg", Vector2i(PORTRAIT_PX, PORTRAIT_PX))
		var splash := src.path_join(art + "_splash.webp")
		if not FileAccess.file_exists(splash):
			splash = src.path_join(art + "_splash.png")
		if FileAccess.file_exists(splash):
			_write(splash, OUT + ak + "_splash.jpg", Vector2i(SPLASH_W, SPLASH_W * 9 / 16))
	quit()

func _write(from: String, to: String, px: Vector2i) -> void:
	var img := Image.load_from_file(from)
	if img == null or img.is_empty():
		printerr("portrait_art: can't read %s" % from)
		return
	img.convert(Image.FORMAT_RGB8)
	img.resize(px.x, px.y, Image.INTERPOLATE_LANCZOS)
	img.save_jpg(ProjectSettings.globalize_path(to), QUALITY)
	print("portrait_art: %s -> %s" % [from.get_file(), to])
