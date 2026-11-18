class_name VoidSpecks
extends Control
## Blots of void drifting slowly upward over the title's key art ("Void & Masks", UI_STYLE.md on
## ext/agent-briefs): dark violet ink with a faint magenta rim, each on its own slow sway. Drawn as
## two circles per speck from a fixed seed; nothing is allocated per frame.

const COUNT := 26                # specks on screen
const RISE := 0.012              # screen heights per second they drift up
const SWAY_PX := 14.0            # px each speck sways left and right
const SIZE_PX := Vector2(2.5, 9.0)   # smallest and largest radius at 1080p
const INK := Color(0.1, 0.03, 0.16, 0.85)
const RIM := Color(1.0, 0.25, 0.82, 0.22)

var t := 0.0

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	t += minf(delta, 0.1)
	queue_redraw()

func _draw() -> void:
	var k := size.y / 1080.0
	for i in COUNT:
		var x := _h(i * 3 + 1) * size.x + sin(t * (0.2 + 0.3 * _h(i * 3 + 2)) + i) * SWAY_PX * k
		var y := fposmod(_h(i * 3 + 3) - t * RISE * (0.6 + _h(i)), 1.0) * (size.y + 40.0) - 20.0
		var r := lerpf(SIZE_PX.x, SIZE_PX.y, pow(_h(i * 7 + 5), 3.0)) * k
		draw_circle(Vector2(x, y), r + 1.5 * k, RIM)
		draw_circle(Vector2(x, y), r, INK)

## A stable pseudo-random number in 0..1 for an integer key.
static func _h(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + 4.1) * 43758.5453, 1.0)
