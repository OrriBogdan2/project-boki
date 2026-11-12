class_name Muzzle
extends RefCounted
## Where a Hunter's rounds leave the drawn weapon. content/archetypes/<id>.json "muzzle" maps an ability slot (lmb,
## rmb, e, r, x, or a kit's own like lmb_l) to the model's anchor empties, the first one found wins; "default" covers
## the rest, and every .glb has weapon_muzzle on its weapon, so the point scales with the drawn Hunter.
## Only the look moves: a round keeps its gameplay start, height, aim, speed and reach. The look starts where the
## camera sees the muzzle (the point of the view ray through it at the round's height) and eases onto the round.

const BLEND_M := 3.0          # m of flight a look takes to ease from the muzzle onto its round's line

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

## The point of the camera's view ray through the `slot` muzzle at the round's own height `at.y`; `at` itself on a
## model without the muzzle.
static func start(h: Hunter, slot: String, at: Vector3) -> Vector3:
	var w := point(h, slot)
	if w == Vector3.INF or h.m.cam == null:
		return at
	var view: Vector3 = h.m.cam.view_dir()
	var s := w + view * ((at.y - w.y) / view.y)
	return Vector3(s.x, at.y, s.z)

## How far the drawn round starts from the muzzle's view-ray point: the muzzle's offset from the round's gameplay
## start, `at`. Zero on a model without the muzzle.
static func offset(h: Hunter, slot: String, at: Vector3) -> Vector3:
	var s := start(h, slot, at)
	return s - at if s != at else Vector3.ZERO

## Another game's round copied from the "s" event (decision 0061): its look leaves the shooter's weapon as this game
## draws that Hunter, the offset from this game's copy of its model and this game's camera.
static func copied(m: Match, s: Dictionary, nid: String, slot: String) -> void:
	var by: Variant = m.ents_by_id.get(nid)
	if by is Hunter and slot != "":
		s["vis"] = offset(by as Hunter, slot, s["start"])

## Where a round's look is drawn: its place `p` plus the offset it left the muzzle with (s["vis"]), eased out over
## BLEND_M m of flight, so the look leaves the drawn weapon and joins the round's own line. Only looks move: the
## round (its start, aim, speed, reach and hits) is the match's.
static func drawn(s: Dictionary, p: Vector3) -> Vector3:
	var vis: Variant = s.get("vis")
	if vis == null:
		return p
	var start_at: Vector3 = s["start"]
	var flown := Vector2(p.x - start_at.x, p.z - start_at.z).length()
	return p + (vis as Vector3) * maxf(0.0, 1.0 - flown / BLEND_M)

## How far a round starting at `at` is from the point `w` on screen: w's distance from the view ray through `at`.
static func off_screen(h: Hunter, at: Vector3, w: Vector3) -> float:
	var view: Vector3 = h.m.cam.view_dir()
	var d := w - at
	return (d - view * d.dot(view)).length()
