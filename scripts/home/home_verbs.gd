class_name HomeVerbs
extends RefCounted
## Times the player's garden moves at home (HunterVerbs): feed, pat, lift, toss, cheer. The paths that
## already do the feeding, petting, picking up, ball tossing and drill or race cheering call play(), with the Boki
## when there is one to reach for; the owner passes step() to HunterAnim every frame. act_t is what a
## Hero's own clip (warden_anim "act") seeks to; act_box is the Boki's bounds the hands go to.

const GAP := 0.3        # m: a Boki being petted or fed comes up this near (its near side), inside the hands' reach

var act := ""
var t := 0.0
var box := AABB()      # world: the Boki's bounds as the move began (empty: none)

func play(verb: String, boki: Node3D = null) -> void:
	act = verb
	t = 0.0
	box = bounds(boki) if boki != null and boki.is_inside_tree() else AABB()

## Advances the clock; what the owner hands to HunterAnim this frame.
func step(dt: float) -> Dictionary:
	if act == "":
		return {}
	t += dt
	if t >= float(HunterVerbs.LENGTH[act]):
		act = ""
		return {}
	return {"holster": true, "act": act, "act_t": t, "act_box": box}

## Where a Boki stands to be petted or fed from `from`: on the way toward `toward`, its near side GAP away.
static func hold_spot(from: Vector3, toward: Vector3, boki: Node3D) -> Vector3:
	var b := bounds(boki)
	var r := clampf(minf(b.size.x, b.size.z) * 0.5, 0.15, 0.45)
	var to := Vector3(toward.x - from.x, 0.0, toward.z - from.z).normalized()
	return Vector3(from.x, 0.0, from.z) + to * (GAP + r)

## A Boki further off than its hold spot comes up to it (home kin entry `k`).
static func come_in(k: Dictionary, from: Vector3) -> void:
	var at := hold_spot(from, k["pos"], k["node"])
	if Vector2(at.x - from.x, at.z - from.z).length() < Vector2(k["pos"].x - from.x, k["pos"].z - from.z).length():
		k["pos"] = at
		(k["node"] as Node3D).position = at

## The world bounds of a Boki's visible meshes.
static func bounds(n: Node3D) -> AABB:
	var out := AABB()
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree() and mi.mesh != null:
			var ab := mi.global_transform * mi.get_aabb()
			out = ab if out.size == Vector3.ZERO else out.merge(ab)
	return out
