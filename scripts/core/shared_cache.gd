class_name SharedCache
extends RefCounted
## The caches a Mask's preview model fills as it is built (Models' and HeroKit's meshes, a Warden's far inks, its
## clip files) are read and filled by the main thread too, while PreviewBuild runs that build on a worker. A
## Dictionary changed on one thread while another reads it can crash the engine, so those caches are read and
## filled only through here. A miss is made outside the lock: two threads may both make it, the first one stays.

static var _lock := Mutex.new()

## cache[key], or null when it holds none yet.
static func read(cache: Dictionary, key: Variant) -> Variant:
	_lock.lock()
	var held: Variant = cache.get(key)
	_lock.unlock()
	return held

## Stores `made` as cache[key] unless another thread stored one first, and returns the one the cache holds.
static func put(cache: Dictionary, key: Variant, made: Variant) -> Variant:
	_lock.lock()
	if not cache.has(key):
		cache[key] = made
	var held: Variant = cache[key]
	_lock.unlock()
	return held
