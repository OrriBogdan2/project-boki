class_name HomeAmbience
extends RefCounted
## The garden's ambience (docs/AUDIO.md): one bed for the part of the day on the home clock (Home.day_t:
## morning birds, a quiet midday, evening insects, a night wind) or the rain bed while it rains, and a
## pond loop that comes up as you near water. Beds go through Sfx.amb_layer, so they sit on the Ambience
## bus and follow its volume setting. When the part of the day changes the old bed fades out as the new
## one fades in over BED_FADE_S. At most MAX_LOOPS loops play at once: the pond steps out for a
## crossfade, and a bed waits for a free slot.

const MAX_LOOPS := 2        # loops sounding at once, the garden's whole budget
const BED_FADE_S := 20.0    # s: a bed's crossfade when the time of day changes
const POND_FADE_S := 4.0    # s: the pond coming up or going away
const POND_FULL := 2.0      # tiles from the water at which the pond is at full
const POND_REACH := 9.0     # tiles from the water past which the pond is silent
const POND_EVERY := 0.5     # s between looks for the nearest water
const POND := "pond"

var levels := {}            # bed -> 0..1, what this module has asked Sfx for
var pond_k := 0.0           # 0..1 from the distance to the nearest water
var _pond_t := 0.0

## The bed for a point of the home clock (0..1: 0.25 morning, 0.5 noon, 0.75 dusk).
static func bed_for(day_t: float, raining: bool) -> String:
	if raining:
		return "rain"
	if day_t >= 0.2 and day_t < 0.4:
		return "garden_morning"
	if day_t >= 0.4 and day_t < 0.6:
		return "garden_midday"
	if day_t >= 0.6 and day_t < 0.8:
		return "garden_evening"
	return "garden_night"

## 1 beside the water, 0 beyond POND_REACH tiles; `from` is the player's tile position (x, z).
static func pond_level(d: Dictionary, from: Vector2) -> float:
	var c := FarmWater.nearest(d, from)
	if c.x < 0:
		return 0.0
	var dist := Vector2(c.x + 0.5, c.y + 0.5).distance_to(from)
	return clampf((POND_REACH - dist) / (POND_REACH - POND_FULL), 0.0, 1.0)

func tick(dt: float, day_t: float, raining: bool, d: Dictionary, ppos: Vector3) -> void:
	_pond_t -= dt
	if _pond_t <= 0.0:
		_pond_t = POND_EVERY
		pond_k = pond_level(d, Vector2(ppos.x, ppos.z))
	var bed := bed_for(day_t, raining)
	if levels.is_empty():
		levels[bed] = 1.0                           # arriving: the bed comes up at once (Sfx eases it in)
	var bed_up := float(levels.get(bed, 0.0)) > 0.0
	for n: String in levels.keys():
		if n != bed and n != POND and bed_up:
			_move(n, 0.0, BED_FADE_S, dt)           # the old bed leaves once the new one is up
	_move(bed, 1.0, BED_FADE_S, dt)
	var crossfading := not bed_up or levels.size() > (2 if levels.has(POND) else 1)
	_move(POND, 0.0 if crossfading else pond_k, POND_FADE_S, dt)

func _move(layer: String, target: float, fade_s: float, dt: float) -> void:
	var cur := float(levels.get(layer, 0.0))
	if cur <= 0.0 and target > 0.0 and levels.size() >= MAX_LOOPS:
		return                                      # no free slot yet
	cur = move_toward(cur, target, dt / fade_s)
	Sfx.amb_layer(layer, cur)
	if cur <= 0.0:
		levels.erase(layer)
	else:
		levels[layer] = cur
