class_name NodePool
extends RefCounted
## Reuse of nodes that come and go during a fight (ground drops), so nothing is built or freed mid-fight.
## A given-back node stays in the tree, hidden, and is freed with its parent.

var _spare: Array[Node3D] = []

## A spare node, shown again, or a new one from `make` (the caller adds it to the tree).
func take(make: Callable) -> Node3D:
	if _spare.is_empty():
		return make.call()
	var n: Node3D = _spare.pop_back()
	n.visible = true
	n.scale = Vector3.ONE
	n.rotation = Vector3.ZERO
	return n

func give(n: Node3D) -> void:
	n.visible = false
	_spare.append(n)
