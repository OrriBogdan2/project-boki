extends RefCounted
## --splash-gallery-check: the painted art behind the title and the loading screen (SplashGallery).
##   1. every piece in content/rules/splash_gallery.json loads and is mipmapped; the paintings are 2560x1440, a
##      Boki cutout is no taller than the 1440 px screen it is made for; every full-size Hunter splash is in it
##   2. at 1920x1080, 2560x1440, 2560x1080 and 1280x800 a piece draws whole, centred and unstretched; a painting
##      fills a 16:9 window and a cutout never draws past its own pixels on a 1440p screen
##   3. it holds a piece HOLD s, crossfades over FADE s into the next in the gallery's order, then lets the old
##      one go; the title shows it
##   4. the boot splash is a 2560x1440 canvas the boot screen fits to the window (stretch mode Keep), and the
##      ink's logo is the same file filling the window the same way, so the hand-off doesn't jump
## With --shots-dir=<dir> (a renderer; --res=WxH sizes the window): the title on Kael's splash and on a Boki,
## the loading screen as Kael, and 100% crops of the title's art: the old 960x540 size against the new.
## Prints GALLERY lines and "GALLERY DONE, failures: n".

const PAINTING_PX := Vector2(2560, 1440)
const CUTOUT_PX := Vector2(800, 800)       # px: the Bokidex hero cutouts
const OLD_PX := Vector2i(960, 540)         # px: the splashes' size before they were made full size
const BOOT_MIN_W := 1920
const STRETCH_KEEP := 1                    # application/boot_splash/stretch_mode: fit the window, shape kept
const FRAMES := [Vector2(1920, 1080), Vector2(2560, 1440), Vector2(2560, 1080), Vector2(1280, 800)]
const STEP := 0.1                          # s: one stepped frame of the gallery
const SHOT_ART := "res://art/portraits/juggernaut_splash.jpg"
const SHOT_BOKI := "res://art/gallery/boki/vespyx.webp"
const CROP_AT := Vector2(0.68, 0.25)       # where the crops centre, as a share of the window (Kael's face)
const CROP_PX := Vector2i(640, 360)
const MENU_IN_S := 2.0                     # s: the title's menu slides in before the first shot

var main: Node
var bad := 0
var shots := ""
var res := Vector2i.ZERO

func ok(cond: bool, what: String) -> void:
	print("GALLERY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			shots = a.substr(12)
		elif a.begins_with("--res="):
			var wh := a.substr(6).split("x")
			res = Vector2i(int(wh[0]), int(wh[1]))
	_pieces()
	_drawing()
	await _rotation()
	await _title()
	_boot_splash()
	if shots != "":
		await _shots()
	print("GALLERY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ 1. the pieces
func _pieces() -> void:
	var files := SplashGallery.files()
	ok(files.size() >= 30, "the gallery has %d pieces" % files.size())
	for path in files:
		var tex := load(path) as Texture2D
		var px := tex.get_size() if tex else Vector2.ZERO
		var cutout := px.x == px.y and px.y > 0.0 and px.y <= SplashGallery.ART_H
		var mipmapped := FileAccess.get_file_as_string(path + ".import").contains("mipmaps/generate=true")
		var what := "a Boki cutout" if cutout else "a painting"
		var line := "%s: %s, %dx%d, mipmapped" % [path.get_file(), what, px.x, px.y]
		ok((cutout or px == PAINTING_PX) and mipmapped, line)
	for ak in Arch.ids():
		var splash := Portraits.art_path(ak, true)
		var full := (load(splash) as Texture2D).get_size() == PAINTING_PX
		ok(not full or files.has(splash), "%s: a full-size splash is in the gallery (%s)" % [ak, full])

# ------------------------------------------------------------------ 2. how a piece is drawn
func _drawing() -> void:
	for frame: Vector2 in FRAMES:
		for px: Vector2 in [PAINTING_PX, Vector2(OLD_PX), CUTOUT_PX]:
			var r := SplashGallery.rect_for(px, frame)
			var whole := Rect2(Vector2.ZERO, frame).grow(0.5).encloses(r)
			var centred := r.get_center().distance_to(frame * 0.5) < 0.5
			var kept := is_equal_approx(r.size.x / r.size.y, px.x / px.y)
			ok(whole and centred and kept, "%s in %s: whole, centred, unstretched (%s)" % [px, frame, r.size])
	for px: Vector2 in [PAINTING_PX, Vector2(OLD_PX)]:
		var fills := SplashGallery.rect_for(px, FRAMES[0]).size == FRAMES[0]
		ok(fills and SplashGallery.rect_for(px, FRAMES[1]).size == FRAMES[1], "a %s painting fills 16:9 windows" % px)
	var at_1440 := SplashGallery.rect_for(CUTOUT_PX, FRAMES[1]).size
	var at_1080 := SplashGallery.rect_for(CUTOUT_PX, FRAMES[0]).size
	ok(at_1440 == CUTOUT_PX and at_1080 == CUTOUT_PX * 0.75, "a cutout: its own pixels at 1440p, 3/4 at 1080p")

# ------------------------------------------------------------------ 3. the rotation
func _rotation() -> void:
	var files := SplashGallery.files()
	var g := SplashGallery.new(files[0])
	main.add_child(g)
	g.set_process(false)
	var first: WeakRef = weakref(g.shown)
	await _advance(g, SplashGallery.HOLD - STEP * 2.0)
	ok(g.coming == null and g.shown.resource_path == files[0], "the first piece holds for %.0f s" % SplashGallery.HOLD)
	await _advance(g, STEP * 3.0)
	while g.coming == null and g.held < SplashGallery.HOLD + 5.0:
		await _advance(g, STEP)
	ok(g.coming != null and g.coming.resource_path == files[1], "then the next piece in order fades in")
	await _advance(g, SplashGallery.FADE * 0.5)
	ok(absf(g.mix - 0.5) < 0.1, "the crossfade takes %.1f s (half way: %.2f)" % [SplashGallery.FADE, g.mix])
	await _advance(g, SplashGallery.FADE * 0.5 + STEP)
	ok(g.coming == null and g.shown.resource_path == files[1], "the next piece is up when the crossfade ends")
	ok(first.get_ref() == null, "the piece before it is let go")
	g.queue_free()

## Steps the gallery `secs` in STEP frames, a rendered frame each (a read ahead finishes meanwhile).
func _advance(g: SplashGallery, secs: float) -> void:
	for i in roundi(secs / STEP):
		g._process(STEP)
		await main.get_tree().process_frame

func _title() -> void:
	main.show_screen("title", {})
	for i in 6:
		await main.get_tree().process_frame
	var g := _gallery_in(main.screen_node())
	ok(g != null and SplashGallery.files().has(g.shown.resource_path), "the title shows the gallery")

func _gallery_in(screen: Node) -> SplashGallery:
	for n in screen.find_children("*", "Control", true, false):
		if n is SplashGallery:
			return n
	return null

# ------------------------------------------------------------------ 4. the boot splash
func _boot_splash() -> void:
	var path := String(ProjectSettings.get_setting("application/boot_splash/image"))
	var tex := load(path) as Texture2D
	ok(tex != null and tex.get_width() >= BOOT_MIN_W, "the boot splash is %s wide" % (tex.get_width() if tex else 0))
	var mode := int(ProjectSettings.get_setting("application/boot_splash/stretch_mode"))
	ok(mode == STRETCH_KEEP, "the boot screen fits it to the window, shape kept (stretch mode %d)" % mode)
	var logo: TextureRect = (main.get("fade") as ScreenFade).logo
	var same_file := logo.texture.resource_path == path
	var fills := logo.anchor_right == 1.0 and logo.anchor_bottom == 1.0 and logo.offset_right == 0.0
	ok(same_file and fills and logo.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
			"the ink's logo is the boot splash, filling the window the same way")

# ------------------------------------------------------------------ shots
func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(shots)
	if res != Vector2i.ZERO:
		DisplayServer.window_set_size(res)
		main.get_window().size = res
	main.fade.reveal(0.05)      # (the boot splash would cover the shots)
	var g := _gallery_in(main.screen_node())
	g.set_process(false)
	g.show_now(SHOT_ART)
	await main.get_tree().create_timer(MENU_IN_S).timeout
	var after := await _grab("title_painting")
	ok(after.get_size() == res or res == Vector2i.ZERO, "the window is %s (asked %s)" % [after.get_size(), res])
	var old := Image.new()
	old.copy_from(g.shown.get_image())
	old.resize(OLD_PX.x, OLD_PX.y, Image.INTERPOLATE_LANCZOS)
	g.shown = ImageTexture.create_from_image(old)
	g.queue_redraw()
	_crops(await _grab("title_painting_old_size"), after)
	g.show_now(SHOT_BOKI)
	await _grab("title_boki")
	var ld: Node = load("res://scripts/ui/loading.gd").new()
	ld.setup({"teams": 10, "squad": 3, "tier": 0, "arch": "juggernaut", "seed": 7})
	main.add_child(ld)
	await _grab("loading")
	ld.queue_free()

## Saves the window as <dir>/<W>x<H>_<file>.png and returns it.
func _grab(file: String) -> Image:
	for i in 20:
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	img.save_png("%s/%dx%d_%s.png" % [shots, img.get_width(), img.get_height(), file])
	return img

## The same 100% crop of the old-size and the full-size art, side by side (old on the left).
func _crops(before: Image, after: Image) -> void:
	var sz := Vector2(after.get_size())
	var at := Vector2i((sz * CROP_AT).round()) - CROP_PX / 2
	at = at.clamp(Vector2i.ZERO, after.get_size() - CROP_PX)
	var pair := Image.create(CROP_PX.x * 2, CROP_PX.y, false, after.get_format())
	pair.blit_rect(before, Rect2i(at, CROP_PX), Vector2i.ZERO)
	pair.blit_rect(after, Rect2i(at, CROP_PX), Vector2i(CROP_PX.x, 0))
	pair.save_png("%s/%dx%d_crop_old_vs_new.png" % [shots, sz.x, sz.y])
