class_name MeshCache
extends RefCounted
## A shared-mesh cache that a build fills by shape (a sphere of this radius, a limb of these lengths, a Hunter's
## beard for its look). Sizes and looks roll per build, so every match added keys no later match asked for, and
## a plain dictionary kept their meshes for the whole session (--match-repeat-check). Every MeshCache is swept
## as a match starts: a key no build has asked for since the start of the match before last goes. A shape every
## match asks for again (a Hunter's own parts) never ages out, so no build redoes it.

const IDLE_SWEEPS := 2          # sweeps (match starts) in a row a key went unasked before it goes

static var _all: Array[MeshCache] = []
static var _lock := Mutex.new()  # PreviewBuild fills these on a worker thread while the main thread reads and sweeps them

var _meshes := {}               # key -> Mesh
var _idle := {}                 # key -> sweeps in a row since a build last asked for it

func _init() -> void:
	_all.append(self)

func has(key: Variant) -> bool:
	_lock.lock()
	var found := _meshes.has(key)
	_lock.unlock()
	return found

## The cached mesh for key (it must be there: has()), counted as asked for.
func mesh(key: Variant) -> Mesh:
	_lock.lock()
	_idle.erase(key)
	var m: Mesh = _meshes[key]
	_lock.unlock()
	return m

func put(key: Variant, m: Mesh) -> void:
	_lock.lock()
	_meshes[key] = m
	_idle.erase(key)
	_lock.unlock()

## The cached mesh for key counted as asked for, or null: one locked step, so a sweep can't land between has() and mesh().
func read(key: Variant) -> Mesh:
	_lock.lock()
	var m: Mesh = _meshes.get(key)
	if m != null:
		_idle.erase(key)
	_lock.unlock()
	return m

## Stores m under key unless another thread stored one first; returns the mesh the cache holds. A miss is built outside
## the lock, so two threads may both build it: the first one stays.
func keep(key: Variant, m: Mesh) -> Mesh:
	_lock.lock()
	if not _meshes.has(key):
		_meshes[key] = m
	_idle.erase(key)
	var held: Mesh = _meshes[key]
	_lock.unlock()
	return held

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
