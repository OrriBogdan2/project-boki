class_name Record
extends RefCounted
## Recording mode, for filming the game (F10, rebindable in Settings > Controls; the switch is also in
## Settings > Gameplay; `--record` starts in it). Purely visual: nothing in gameplay or networking
## reads it, so a match plays the same with it on or off.
##   level 0  off
##   level 1  clean: debug, perf and test text, tips, hint banners and dev toasts hidden; the player
##            HUD stays, and the camera follows more smoothly (gentle damping, no zoom pops, little shake)
##   level 2  cinema: no HUD at all (a second press, or Shift+F10 straight from anywhere), and F9
##            turns a slow orbit of the camera on and off
## Built nodes register with hide_in_clean(node) or hide_in_cinema(node); the HUDs drawn every frame
## ask clean() / cinema() before drawing the parts that go.

static var level := 0
static var orbit := false          # the slow cinematic orbit (cinema only)
static var orbit_yaw := 0.0        # how far the camera has orbited round the player (radians)
static var arena_pick := ""        # --arena=<archetype>: the arena hook (see main.gd)

const GROUP_CLEAN := "rec_hide_clean"
const GROUP_CINEMA := "rec_hide_cinema"
const ORBIT_SPEED := 0.14          # rad/s: a full turn in about 45 s
const NAMES := ["Off", "Clean HUD", "No HUD"]

static func clean() -> bool:
	return level >= 1

static func cinema() -> bool:
	return level >= 2

static func set_level(n: int) -> void:
	level = clampi(n, 0, 2)
	if level < 2:
		orbit = false

## F10: off -> clean -> no HUD -> off.
static func cycle() -> void:
	set_level((level + 1) % 3)

## Shift+F10: straight to no HUD (or back to the clean HUD from it).
static func toggle_cinema() -> void:
	set_level(1 if level == 2 else 2)

## F9 (no HUD only): the slow orbit on or off.
static func toggle_orbit() -> void:
	if cinema():
		orbit = not orbit

static func hide_in_clean(n: Node) -> void:
	if n and not n.is_in_group(GROUP_CLEAN):
		n.add_to_group(GROUP_CLEAN)

static func hide_in_cinema(n: Node) -> void:
	if n and not n.is_in_group(GROUP_CINEMA):
		n.add_to_group(GROUP_CINEMA)

## Every frame (Overlay._process): the registered nodes hidden or shown back as they were.
static func tick(tree: SceneTree, delta: float) -> void:
	if tree == null:
		return
	for n in tree.get_nodes_in_group(GROUP_CLEAN):
		_show(n, not clean())
	for n in tree.get_nodes_in_group(GROUP_CINEMA):
		_show(n, not cinema())
	if cinema() and orbit:
		orbit_yaw = wrapf(orbit_yaw + delta * ORBIT_SPEED, -PI, PI)
	elif not cinema():
		orbit_yaw = lerp_angle(orbit_yaw, 0.0, minf(1.0, delta * 1.5))

static func _show(n: Node, on: bool) -> void:
	if not ("visible" in n):
		return
	if not on:
		if not n.has_meta("rec_was"):
			n.set_meta("rec_was", n.visible)
		n.visible = false
	elif n.has_meta("rec_was"):
		n.visible = bool(n.get_meta("rec_was"))
		n.remove_meta("rec_was")

## Camera follow rates in recording mode: [across, up/down, cursor lean, zoom, shake share].
static func cam_rates() -> Array:
	return [4.0, 2.0, 0.45, 0.9, 0.25] if clean() else [8.0, 3.5, 1.0, 2.5, 1.0]
