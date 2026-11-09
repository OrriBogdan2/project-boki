class_name ShadowPolicy
extends RefCounted
## Which meshes cast shadows (item 94). Most of the world is small procedural parts (props, kit
## bits, chests, monster limbs, Boki ears and tails), and each caster is one more draw in every
## shadow cascade: on the owner's PC shadows were ~1,240 of ~2,000 fight draws. So a mesh casts
## only when it's big enough to throw a shadow you'd notice; Hunters and each Boki's body cast at
## any size, and effects (rings, telegraphs, decals, particles) never do.
## The builders call this where meshes are made: Models.part (props, kit and monster parts), the
## Models.hunter / Models.kin builders (keep), Fx (everything it spawns), World's prop batches.

## The smallest caster per quality preset, in metres along a mesh's longest side (after its own
## scale). Every preset uses this table; none turns the small parts back on. Low starts with
## shadows off, but a player can switch them on by hand, and then this applies too.
const MIN_SIZE := {"low": 2.0, "medium": 1.6, "high": 1.3, "ultra": 1.0}

## > 0 while a Hunter is being built (Models.hunter): its parts cast at any size.
static var keep := 0

static var _lim := 0.0
static var _lim_frame := -1

static func min_size() -> float:
	var f := Engine.get_process_frames()
	if f != _lim_frame:
		_lim_frame = f
		_lim = float(MIN_SIZE.get(Settings.quality(), MIN_SIZE["high"]))
	return _lim

## The longest side of a mesh instance's box, with its own scale (not its parents').
static func size_of(gi: GeometryInstance3D) -> float:
	var s := gi.get_aabb().size * gi.scale.abs()
	return maxf(s.x, maxf(s.y, s.z))

## Does a mesh this big cast?
static func casts(sz: float) -> bool:
	return keep > 0 or sz >= min_size()

## One freshly made mesh: off when it's small (and no Hunter is being built).
static func judge(gi: GeometryInstance3D) -> void:
	if keep <= 0 and size_of(gi) < min_size():
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Everything under `n` stops casting (effects, decals, rings, telegraphs).
static func off(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ch in n.get_children():
		off(ch)

## Each mesh under `n` judged by its size in `n`'s space (`k` = the scale it will be shown at).
static func judge_tree(n: Node, k := 1.0) -> void:
	var lim := min_size()
	for gi in n.find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		var s := _size_in(n, g) * k
		if s < lim:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n is GeometryInstance3D and size_of(n as GeometryInstance3D) * k < lim:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A Boki: the body (its biggest mesh) casts, the bits (eyes, ears, tails, spikes, leaves) don't.
static func boki(root: Node) -> void:
	var best: GeometryInstance3D = null
	var best_v := -1.0
	var all := root.find_children("*", "GeometryInstance3D", true, false)
	for gi in all:
		var g := gi as GeometryInstance3D
		if not g.visible or not (g is MeshInstance3D):
			continue
		var s := g.get_aabb().size * _scale_in(root, g)
		var v := s.x * s.y * s.z
		if v > best_v:
			best_v = v
			best = g
	for gi in all:
		if gi != best:
			(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if best:
		best.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

static func _scale_in(root: Node, g: Node3D) -> Vector3:
	var s := Vector3.ONE
	var n: Node = g
	while n and n != root:
		if n is Node3D: s *= (n as Node3D).scale.abs()
		n = n.get_parent()
	return s

static func _size_in(root: Node, g: GeometryInstance3D) -> float:
	var s := g.get_aabb().size * _scale_in(root, g)
	return maxf(s.x, maxf(s.y, s.z))

## Scatter items ([Transform3D, Color]) of one mesh split into [big enough to cast, too small].
static func split_instances(items: Array, mesh: Mesh) -> Array:
	var lim := min_size()
	var ms := mesh.get_aabb().size
	var big: Array = []
	var small: Array = []
	for it in items:
		var s := ms * (it[0] as Transform3D).basis.get_scale().abs()
		if maxf(s.x, maxf(s.y, s.z)) >= lim: big.append(it)
		else: small.append(it)
	return [big, small]

## Particle systems never cast, wherever they're made (kits, exits, landmarks, monsters): one hook on
## the tree, set once.
static func watch_particles(tree: SceneTree) -> void:
	if tree and not tree.node_added.is_connected(_on_added):
		tree.node_added.connect(_on_added)

static func _on_added(n: Node) -> void:
	if n is CPUParticles3D or n is GPUParticles3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
