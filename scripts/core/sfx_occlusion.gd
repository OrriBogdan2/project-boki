class_name SfxOcclusion
extends RefCounted
## Is the terrain between a sound and the listener? One heightmap line test per sound, cached for
## CACHE_MS (about 10 Hz), so a 30-Hunter fight costs a few dozen short walks a second. Sfx sends a
## blocked sound through the muffled bus (low-pass plus a small gain drop). The map is set by the match.

const STEP := 1.0          # m between samples along the line
const EAR_H := 0.7         # m above the ground: a voice at the feet and chest, the listener mid-body
const CACHE_MS := 100      # a result is reused this long (a source in the same 1 m cell, same listener cell)
const KEEP := 256          # cached results kept before the old ones are dropped
const NEAR := 3.5          # m: closer than this is never blocked (your own Hunter, a mate beside you)

var world: World
var cache := {}            # cell key -> [time ms, blocked]

## True when the ground, or a block tile, rises above the line from the sound to the listener.
func blocked(src: Vector3, listener: Vector3) -> bool:
	if not is_instance_valid(world):
		return false
	var d := Vector2(listener.x - src.x, listener.z - src.z)
	var dist := d.length()
	if dist < NEAR:
		return false
	var now := Time.get_ticks_msec()
	var key := Vector4i(floori(src.x), floori(src.z), floori(listener.x), floori(listener.z))
	var hit: Array = cache.get(key, [])
	if not hit.is_empty() and now - int(hit[0]) < CACHE_MS:
		return hit[1]
	if cache.size() > KEEP:
		cache.clear()
	var res := _line_blocked(src, listener, dist)
	cache[key] = [now, res]
	return res

func _line_blocked(src: Vector3, listener: Vector3, dist: float) -> bool:
	var y0 := _ear(src)
	var y1 := _ear(listener)
	var n := ceili(dist / STEP)
	for i in range(1, n):
		var t := float(i) / n
		var x := lerpf(src.x, listener.x, t)
		var z := lerpf(src.z, listener.z, t)
		var top := world.ground_at(x, z)
		if world.is_block(x, z):
			top += World.BLOCK_H
		if top > lerpf(y0, y1, t):
			return true
	return false

func _ear(p: Vector3) -> float:
	return world.ground_at(p.x, p.z) + EAR_H
