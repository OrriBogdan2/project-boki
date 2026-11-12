class_name Muzzle
extends RefCounted
## Where a Hunter's rounds leave the drawn weapon. content/archetypes/<id>.json "muzzle" maps an ability slot (lmb,
## rmb, e, r, x, or a kit's own like lmb_l) to the model's anchor empties, the first one found wins; "default" covers
## the rest, and every .glb has weapon_muzzle on its weapon, so the point scales with the drawn Hunter.
## What stays gameplay: the round keeps its height (the shot bands), its direction and the end of its flight. Only
## its start moves, to where the camera sees the muzzle: the point of the view ray through it at the round's height.

const MIN_FLIGHT := 0.5      # m: a round that would fly less than this from its muzzle keeps its own start

## The world point of `slot`'s muzzle on h's model; Vector3.INF on a model without it (the procedural one, headless).
static func point(h: Hunter, slot: String) -> Vector3:
	if h.model == null or not h.model.is_inside_tree():
		return Vector3.INF
	var table: Dictionary = Arch.def(h.arch).get("muzzle", {})
	for n in table.get(slot, table.get("default", ["weapon_muzzle"])):
		var an := WardenGlb.anchor(h.model, String(n))
		if an != null:
			return an.global_position
	return Vector3.INF

## Every muzzle `slot` can leave from: its own point, plus its _l and _r hands (Sparkle's finger bolts alternate).
static func points(h: Hunter, slot: String) -> Array:
	var table: Dictionary = Arch.def(h.arch).get("muzzle", {})
	var out := []
	for s in [slot, slot + "_l", slot + "_r"]:
		var p := point(h, s)
		if p != Vector3.INF and (s == slot or table.has(s)):
			out.append(p)
	return out

## Where a round at `at` starts from the `slot` muzzle: the point of the camera's view ray through it at the round's
## own height; `at` itself on a model without the muzzle.
static func start(h: Hunter, slot: String, at: Vector3) -> Vector3:
	var w := point(h, slot)
	if w == Vector3.INF or h.m.cam == null:
		return at
	var view: Vector3 = h.m.cam.view_dir()
	var s := w + view * ((at.y - w.y) / view.y)
	return Vector3(s.x, at.y, s.z)

## A round of h's leaving `at` with velocity `v2` for `life` s, moved to the `slot` muzzle: [start, velocity, life].
## It keeps its height, its speed and the point where its flight ends (a slowing round, one with "decel", keeps its line and life) (the cursor, the range), so the reach and the
## hit stay what they were: from the muzzle it flies the straight line to that point.
static func leave(h: Hunter, slot: String, at: Vector3, v2: Vector2, life: float, brakes := false) -> Array:
	var s := start(h, slot, at)
	if s == at or v2.length() < 0.1 or brakes:
		return [s, v2, life]
	var end := Vector2(at.x, at.z) + v2 * life
	var way := end - Vector2(s.x, s.z)
	if way.length() < MIN_FLIGHT or way.dot(v2) <= 0.0:
		return [at, v2, life]
	return [s, way.normalized() * v2.length(), way.length() / v2.length()]

## How far a round starting at `at` is from the point `w` on screen: w's distance from the view ray through `at`.
static func off_screen(h: Hunter, at: Vector3, w: Vector3) -> float:
	var view: Vector3 = h.m.cam.view_dir()
	var d := w - at
	return (d - view * d.dot(view)).length()
