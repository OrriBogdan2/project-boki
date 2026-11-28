class_name OnFree
extends RefCounted
## Runs a callable when a node is freed, and cuts the cycles its helpers make. A RefCounted helper whose parts point
## back at it (a kit and its DashFlow, Lairs and its LairsLock, the Heart and its sound) is never freed by its count,
## so every match left a few hundred objects behind (--match-repeat-check). The helper calls cut_with(its node, self):
## once that node is freed, every part's field that points back up the helper's tree is set to null, and the counts
## free the lot. Only those back fields change, so data the parts share (a kin's specs, a cache) is never touched.

const MAX_DEPTH := 3            # helper -> part -> part's part: deep enough for every helper the check found

var _f: Callable

## Calls f when `owner` is freed (this object rides in its metadata, so it goes with it). No owner: never.
static func call_on(owner: Object, f: Callable) -> void:
	if owner == null:             # a check's bare helper has no node
		return
	var held: Array = owner.get_meta(&"_on_free", [])
	held.append(OnFree.new(f))
	owner.set_meta(&"_on_free", held)

## Cuts the cycles under `helper` when `owner` is freed.
static func cut_with(owner: Object, helper: RefCounted) -> void:
	call_on(owner, func() -> void: cut_cycles(helper))

## Sets to null every field (in `root` and the parts it holds) that points back to an object above it on the way down.
static func cut_cycles(root: RefCounted) -> void:
	_cut(root, [root], {})

static func _cut(o: Object, path: Array, seen: Dictionary) -> void:
	for pr in o.get_property_list():
		if not (pr["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v = o.get(pr["name"])
		if typeof(v) == TYPE_CALLABLE:
			var t: Object = (v as Callable).get_object()
			if t != null and path.has(t):
				o.set(pr["name"], Callable())
			continue
		var parts: Array = []
		if v is Array:
			parts = v
		elif v is Dictionary:
			parts = (v as Dictionary).values()
		elif typeof(v) == TYPE_OBJECT and is_instance_valid(v):
			if path.has(v):
				o.set(pr["name"], null)
				continue
			parts = [v]
		for x in parts:
			if typeof(x) != TYPE_OBJECT or not is_instance_valid(x) or not (x is RefCounted) or x is Resource:
				continue
			var id: int = (x as Object).get_instance_id()
			if seen.has(id) or path.size() > MAX_DEPTH or path.has(x):
				continue
			seen[id] = true
			path.append(x)
			_cut(x, path, seen)
			path.pop_back()

func _init(f: Callable) -> void:
	_f = f

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _f.is_valid():
		_f.call()
