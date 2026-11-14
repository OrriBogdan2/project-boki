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
