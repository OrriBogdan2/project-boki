class_name FxPool
extends RefCounted
## A reuse list of one kind of effect mesh (a ring, a ghost, a bolt segment, a beam quad).
## The match builds a few at load; an effect takes one, restyles it, and gives it back when it ends, so
## no fight creates or frees nodes (item 94, "pool and reuse nodes").

var parent: Node3D
var _make: Callable          # () -> MeshInstance3D, the kind's look (mesh and material built once)
var _free: Array[MeshInstance3D] = []
var _made := 0

func _init(into: Node3D, make: Callable, warm: int) -> void:
	parent = into
	_make = make
	for i in warm:
		_free.append(_build())

func _build() -> MeshInstance3D:
	var mi: MeshInstance3D = _make.call()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	_made += 1
	return mi

## A hidden mesh of this kind, shown. When all are out the pool grows by one; the warm counts are
## sized so a fight never gets there.
func take() -> MeshInstance3D:
	var mi: MeshInstance3D = _free.pop_back() if not _free.is_empty() else _build()
	mi.visible = true
	return mi

func give(mi: MeshInstance3D) -> void:
	if not mi.visible:
		return          # already given back (an effect ended twice)
	mi.visible = false
	_free.append(mi)

## How many are out (taken and not yet given back).
func live() -> int:
	return _made - _free.size()
