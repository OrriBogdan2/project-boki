class_name DropCam
extends RefCounted
## The drop's camera (owner item 107): off the ship it pulls far out, tilted over the whole island, and
## turned with your heading so forward stays up the screen. It comes back as you fall and is near the
## play zoom just before the ground. Numbers in content/rules/drop.json ("camera"). No shake (item 50).

static var cfg: Dictionary = DropData.rules["camera"]
static var WIDE_ZOOM: float = cfg["wide_zoom"]
static var NEAR_ZOOM: float = cfg["near_zoom"]
static var PULL_S: float = cfg["pull_s"]
static var EASE_FROM: float = cfg["ease_from"]
static var EASE_TO: float = cfg["ease_to"]
static var WIDE_CHASE: float = cfg["wide_chase"]
static var ISLAND_FOCUS: float = cfg["island_focus"]
const PLATE_ZOOM := 3.5           # CamRig.zoom
const SHIP_ZOOM := 56.0 / 23.0     # about where the ride's camera left off (Match: 56 m back)

## 0..1: how far the camera is pulled out at this moment of h's fall.
static func wide(m: Match, h: Hunter) -> float:
	return out_k(m, h) * high_k(m, h)

## 0..1: the pull-out off the ship.
static func out_k(m: Match, h: Hunter) -> float:
	return smoothstep(0.0, PULL_S, m.time - float(h.get_meta("drop_t", m.time - PULL_S)))

## 0..1: 1 high up, down to 0 as the height falls past ease_from .. ease_to of the sky.
static func high_k(m: Match, h: Hunter) -> float:
	return smoothstep(EASE_TO, EASE_FROM, SkyFall.height_over(m.world, h.pos) / SkyFall.SKY_Y)

## Every frame of a fall, in place of the match's own framing.
static func frame(m: Match, p: Hunter) -> void:
	var cam := m.cam
	var steer: Hunter = p.comet_lead if p.comet_lead else p
	if steer.fall_dir.length() > 0.01:
		cam.yaw_to = atan2(-steer.fall_dir.x, -steer.fall_dir.y)
	var hk := high_k(m, p)
	var z := lerpf(SHIP_ZOOM, lerpf(NEAR_ZOOM, WIDE_ZOOM, hk * hk), out_k(m, p))
	cam.top_to = 0.0
	cam.chase_to = WIDE_CHASE * hk
	cam.zoom_to = z
	cam.zoom = z            # (this curve is the ease: no second one on top)

## Pulled this far out, the overhead names and bars pile up into noise: the HUD leaves them off.
static func plates_off(m: Match) -> bool:
	return m.player != null and m.player.dropping and m.cam.zoom > PLATE_ZOOM

## What the camera follows during a fall: you, leaning to the island's middle while it's pulled out.
static func focus(m: Match, p: Hunter, at: Vector3) -> Vector3:
	if not p.dropping:
		return at
	var mid := Vector3(m.world.w * 0.5, 0.0, m.world.h * 0.5)
	return at.lerp(mid, wide(m, p) * ISLAND_FOCUS)
