class_name MarkerDir
extends RefCounted
## Where a world marker is, seen from the screen: its pin is drawn only inside the play box (clear of
## the tutorial panel at the top and the hotbar at the bottom) and above the hunter's feet. Anywhere
## else (behind the camera, off the box, or under the hunter, unless it is right there) it gets an
## edge arrow instead.

const PIN_UP := 2.6        # m above the spot that the pin floats
const BOX_TOP := 0.22      # of the screen height: pins stay below the tutorial panel
const BOX_BOT := 0.62      # of the screen height: pins (and their label under them) stay above the hotbar
const BOX_SIDE := 40.0     # px kept clear at the left and right
const NEAR := 3.0          # m: a marker this close is where you stand: its pin and ring, never an arrow

## The play box (Rect2) a pin may be drawn in, for a screen size.
static func box(sz: Vector2) -> Rect2:
	return Rect2(Vector2(BOX_SIDE, sz.y * BOX_TOP), Vector2(sz.x - BOX_SIDE * 2.0, sz.y * (BOX_BOT - BOX_TOP)))

## Vector2.ZERO when the pin for `at` shows on screen, else the unit screen direction to point an arrow.
## `me` is the hunter's feet: a marker lower on screen than them is under the hunter or the HUD.
static func off_dir(cam: Camera3D, sz: Vector2, at: Vector3, me: Vector3) -> Vector2:
	var tp := cam.unproject_position(at + Vector3(0, PIN_UP, 0))
	var behind := cam.is_position_behind(at)
	var below := not behind and cam.unproject_position(at).y > cam.unproject_position(me).y
	var near := Vector2(at.x - me.x, at.z - me.z).length() < NEAR
	if near or (not behind and not below and box(sz).has_point(tp)):
		return Vector2.ZERO
	var d := (tp - sz * 0.5) if not behind else (sz * 0.5 - tp)
	return d.normalized() if d.length() > 0.1 else Vector2.UP

const EDGE_SIDE := 70.0      # px the edge arrow's anchor stays in from the right
const EDGE_LEFT := 290.0     # px from the left: past the squad column (its 210 px and margin) and the arrow's tip
const EDGE_UP := 0.24        # of the screen height: its anchor ranges this far above the centre line (0.47)
const EDGE_DOWN := 0.12      # and this far below it: the arrow's tip stays above the prompt row (height - 222 px)

## Where the edge arrow for screen direction `d` is anchored: the edge of the play area round the middle.
static func edge_point(sz: Vector2, d: Vector2) -> Vector2:
	var mid := Vector2(sz.x * 0.5, sz.y * 0.47)
	var hx := (mid.x - EDGE_LEFT) if d.x < 0.0 else (sz.x - EDGE_SIDE - mid.x)
	var hy := sz.y * (EDGE_UP if d.y < 0.0 else EDGE_DOWN)
	return mid + d * minf(hx / maxf(0.001, absf(d.x)), hy / maxf(0.001, absf(d.y)))
