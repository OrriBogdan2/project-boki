class_name MeshCache
extends RefCounted
## A shared-mesh cache that a build fills by shape (a sphere of this radius, a limb of these lengths, a Hunter's
## beard for its look). Sizes and looks roll per build, so every match added keys no later match asked for, and
## a plain dictionary kept their meshes for the whole session (--match-repeat-check). Every MeshCache is swept
## as a match starts: a key no build has asked for since the start of the match before last goes. A shape every
## match asks for again (a Hunter's own parts) never ages out, so no build redoes it.

const IDLE_SWEEPS := 2          # sweeps (match starts) in a row a key went unasked before it goes

static var _all: Array[MeshCache] = []

var _meshes := {}               # key -> Mesh
var _idle := {}                 # key -> sweeps in a row since a build last asked for it

func _init() -> void:
	_all.append(self)

func has(key: Variant) -> bool:
	return _meshes.has(key)

## The cached mesh for key (it must be there: has()), counted as asked for.
func mesh(key: Variant) -> Mesh:
	_idle.erase(key)
	return _meshes[key]

func put(key: Variant, m: Mesh) -> void:
	_meshes[key] = m
	_idle.erase(key)

## Meshes held over every cache (--match-repeat-check reads it).
static func entries() -> int:
	var n := 0
	for c in _all:
		n += c._meshes.size()
	return n

## Ages every cache's keys by one sweep and drops the ones idle IDLE_SWEEPS times in a row. Returns how many went.
static func sweep() -> int:
	var n := 0
	for c in _all:
		for k in c._meshes.keys():
			var times := int(c._idle.get(k, 0)) + 1
			if times < IDLE_SWEEPS:
				c._idle[k] = times
				continue
			c._meshes.erase(k)
			c._idle.erase(k)
			n += 1
	return n
