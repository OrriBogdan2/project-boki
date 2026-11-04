class_name MaskPutOn
extends Control
## The put-on beat over a viewer's stage: the mask lifts to your face, a soft flash, and the Warden takes
## over (the viewer swaps models when `swapped` fires). No rays, rings or shake: a quiet moment.

signal swapped
signal done

const LIFT_AT := 0.5         # s: the mask starts to rise
const FLASH_AT := 1.1        # s: it reaches the face and the flash peaks (the swap happens here)
const END_AT := 1.5          # s: the flash has faded
const MASK_W := 46.0         # px: half the mask's width

var col := Color.WHITE
var face_at: Callable        # () -> Vector2: where your face is on the stage, in px
var t := 0.0
var _swapped := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	t += dt
	if not _swapped and t >= FLASH_AT:
		_swapped = true
		swapped.emit()
	if t >= END_AT:
		done.emit()
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var face: Vector2 = face_at.call()
	var k := ease(clampf((t - LIFT_AT) / (FLASH_AT - LIFT_AT), 0.0, 1.0), -2.0)
	if t < FLASH_AT:
		var at := face + Vector2(0.0, size.y * 0.35 * (1.0 - k))
		_mask(at, col, minf(1.0, (t - 0.2) / 0.3))
	var flash := 0.7 * clampf(1.0 - absf(t - FLASH_AT) / 0.3, 0.0, 1.0)      # up in 0.3 s, down in 0.3 s
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash))

## A plain mask: an oval in the Warden's colour with two eye slits.
func _mask(at: Vector2, tint: Color, alpha: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(at + Vector2(cos(a) * MASK_W * 0.8, sin(a) * MASK_W))
	draw_colored_polygon(pts, Color(tint.lightened(0.1), maxf(alpha, 0.0)))
	for sx in [-1.0, 1.0]:
		var eye := at + Vector2(sx * MASK_W * 0.28, -MASK_W * 0.1)
		draw_line(eye - Vector2(8.0, 0.0), eye + Vector2(8.0, 0.0), Color(0.05, 0.04, 0.08, alpha), 4.0, true)
