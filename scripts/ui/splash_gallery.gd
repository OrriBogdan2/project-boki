class_name SplashGallery
extends Control
## The painted art behind the title and the loading screen (content/rules/splash_gallery.json): one piece at a
## time, whole, centred and never stretched, held still and then crossfading slowly into the next. A piece is
## drawn at its own pixels on a screen ART_H high, shrunk to fit: the 2560x1440 paintings fill a 16:9 window
## and a Boki cutout stands in the middle at its own size. The next piece is read on a loader thread while one
## shows, and a piece that has gone is let go (nothing is kept for the session).

const RULES_PATH := "res://content/rules/splash_gallery.json"
const HOLD := 8.0          # s a piece shows before the next one fades in
const FADE := 2.5          # s of crossfade into the next: slow, so a change never reads as a cut
const ART_H := 1440.0      # px: the screen height the art is made for; no piece draws bigger than that share

static var _files := PackedStringArray()

var shown: Texture2D       # the piece on screen
var coming: Texture2D      # the next piece while it fades in, else null
var mix := 0.0             # 0..1 through the crossfade into `coming`
var held := 0.0            # s the shown piece has been up
var next_i := 0            # the gallery index of the piece after `shown`
var _reading := ""         # the next piece's file once its read has started

## Starts on `first` (any art file), or on a random piece of the gallery when it is "".
func _init(first := "") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var order := files()
	show_now(first if first != "" else order[randi() % order.size()])

func _process(delta: float) -> void:
	delta = minf(delta, 0.1)   # a hitch never skips the crossfade
	if coming == null:
		if _reading == "":
			_read_next()
		held += delta
		if held >= HOLD:
			coming = _take_next()   # null while it is still being read: this one holds a little longer
		return
	mix = minf(1.0, mix + delta / FADE)
	if mix >= 1.0:
		shown = coming
		coming = null
		mix = 0.0
		held = 0.0
	queue_redraw()

func _exit_tree() -> void:
	_drop_read()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ScreenFade.INK)
	var shown_at := rect_for(shown.get_size(), size)
	if coming == null:
		draw_texture_rect(shown, shown_at, false)
		return
	var coming_at := rect_for(coming.get_size(), size)
	# a smaller piece (a Boki cutout) doesn't hide the one before it, so that one fades out as it comes in
	var under := 1.0 if coming_at.encloses(shown_at) else 1.0 - mix
	draw_texture_rect(shown, shown_at, false, Color(1, 1, 1, under))
	draw_texture_rect(coming, coming_at, false, Color(1, 1, 1, mix))

## The gallery's art files, in the order they are shown.
static func files() -> PackedStringArray:
	if _files.is_empty():
		var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		for piece in rules["art"]:
			_files.append(String(piece["file"]))
	return _files

## Where a piece of `px` pixels is drawn in a frame of `frame`: whole, centred, its shape kept.
static func rect_for(px: Vector2, frame: Vector2) -> Rect2:
	var k := minf(minf(frame.x / px.x, frame.y / px.y), frame.y / ART_H)
	return Rect2((frame - px * k) * 0.5, px * k)

## Shows `path` at once (no crossfade) and goes on round the gallery from the piece after it, or from a
## random piece when `path` is not in the gallery.
func show_now(path: String) -> void:
	_drop_read()
	shown = load(path)
	coming = null
	mix = 0.0
	held = 0.0
	var at := files().find(path)
	next_i = at + 1 if at >= 0 else randi() % files().size()
	queue_redraw()

func _read_next() -> void:
	_reading = files()[next_i % files().size()]
	next_i += 1
	if BackgroundWork.can_read_ahead():
		BackgroundWork.request(_reading)

## The next piece once its read is done (null until then; a file that fails to load is skipped).
func _take_next() -> Texture2D:
	var ahead := BackgroundWork.can_read_ahead()
	if ahead and ResourceLoader.load_threaded_get_status(_reading) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return null
	var tex := (BackgroundWork.take(_reading) if ahead else load(_reading)) as Texture2D
	_reading = ""
	return tex

## Collects a read still under way, so its texture goes with this screen instead of waiting for the quit.
func _drop_read() -> void:
	if _reading != "" and BackgroundWork.can_read_ahead():
		BackgroundWork.take(_reading)
	_reading = ""
