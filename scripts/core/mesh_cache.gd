class_name MeshCache
extends RefCounted
## A shared-mesh cache that a build fills by shape (a sphere of this radius, a limb of these lengths, a Hunter's
## beard for its look). Sizes and looks roll per build, so every match added keys no later match asked for, and
## a plain dictionary kept their meshes for the whole session (--match-repeat-check). Every MeshCache is swept
## as a match starts: a key no build has asked for since the start of the match before last goes. A shape every
## match asks for again (a Hunter's own parts) never ages out, so no build redoes it.
## A Mask's preview model is built on a PreviewBuild worker while the main thread fills the same caches, and a
## Dictionary changed on one thread while another reads it can crash the engine, so every access takes _lock.
## A miss is made outside the lock: two threads may both make it, the last put stays. The sweep runs on the main
## thread as a match starts, when no preview build is running.

const IDLE_SWEEPS := 2          # sweeps (match starts) in a row a key went unasked before it goes

static var _all: Array[MeshCache] = []
static var _lock := Mutex.new()

var _meshes := {}               # key -> Mesh
var _idle := {}                 # key -> sweeps in a row since a build last asked for it

func _init() -> void:
	_all.append(self)

func has(key: Variant) -> bool:
	_lock.lock()
	var held := _meshes.has(key)
	_lock.unlock()
	return held

## The cached mesh for key (it must be there: has()), counted as asked for.
func mesh(key: Variant) -> Mesh:
	_lock.lock()
	_idle.erase(key)
	var held: Mesh = _meshes.get(key)
	_lock.unlock()
	return held

func put(key: Variant, m: Mesh) -> void:
	_lock.lock()
	_meshes[key] = m
	_idle.erase(key)
	_lock.unlock()

## Meshes held over every cache (--match-repeat-check reads it).
static func entries() -> int:
	var n := 0
	_lock.lock()
	for c in _all:
		n += c._meshes.size()
	_lock.unlock()
	return n

## Ages every cache's keys by one sweep and drops the ones idle IDLE_SWEEPS times in a row. Returns how many went.
static func sweep() -> int:
	var n := 0
	_lock.lock()
	for c in _all:
		for k in c._meshes.keys():
			var times := int(c._idle.get(k, 0)) + 1
			if times < IDLE_SWEEPS:
				c._idle[k] = times
				continue
			c._meshes.erase(k)
			c._idle.erase(k)
			n += 1
	_lock.unlock()
	return n
