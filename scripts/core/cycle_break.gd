class_name CycleBreak
extends RefCounted
## Frees what reference cycles keep. A RefCounted helper that holds its owner and is held by it (a Lairs and its
## LairsLock, a Hunter's locomotion and the hooks bound to it, a kit and its state) is never freed by its count, so
## every match left a few hundred of them behind (--match-repeat-check). A node that owns such helpers calls
## watch(self): once it leaves the tree to be freed, every RefCounted it holds, and every one those hold, is
## cut loose (set to null, arrays and dictionaries cleared), so the counts free them.

const MAX_DEPTH := 6

## Cuts `root`'s helpers loose after it leaves the tree (and `extra`, nodes it owns that the tree frees with it).
static func watch(root: Node, extra: Array = []) -> void:
	root.tree_exited.connect(func() -> void: _later(root, extra), CONNECT_ONE_SHOT)

static func _later(root: Node, extra: Array) -> void:
	# a node that is only moved is not queued for deletion: keep watching it
	if not root.is_queued_for_deletion():
		watch(root, extra)
		return
	# hold the helpers now and cut them after the frees of this frame (a draw or a timer may still read them)
	var held: Array = []
	for n in [root] + extra:
		if is_instance_valid(n):
			for pr in (n as Node).get_property_list():
				if pr["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
					var v = (n as Node).get(pr["name"])
					if _held(v):
						held.append(v)
	(func() -> void:
		var seen := {}
		for v in held:
			_cut(v, 0, seen)).call_deferred()

static func _held(v: Variant) -> bool:
	if typeof(v) == TYPE_OBJECT and not is_instance_valid(v):
		return false
	return (v is RefCounted and not (v is Resource)) or v is Array or v is Dictionary

static func _cut(v: Variant, depth: int, seen: Dictionary) -> void:
	if depth > MAX_DEPTH:
		return
	if v is RefCounted and not (v is Resource):
		var id: int = (v as Object).get_instance_id()
		if seen.has(id):
			return
		seen[id] = true
		for pr in (v as Object).get_property_list():
			if not (pr["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var x = (v as Object).get(pr["name"])
			if _held(x):
				_cut(x, depth + 1, seen)
				if x is RefCounted:
					(v as Object).set(pr["name"], null)
	elif v is Array:
		for x in v:
			if _held(x):
				_cut(x, depth + 1, seen)
		if (v as Array).any(func(x): return _held(x) and x is RefCounted):
			(v as Array).clear()
	elif v is Dictionary:
		for k in v:
			if _held(v[k]):
				_cut(v[k], depth + 1, seen)
