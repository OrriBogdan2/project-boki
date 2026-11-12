class_name AimReach
extends RefCounted

## The range preview of a ground-target slot (a zone or strike placed at the cursor): a faint ring at the slot's
## max range round the caster and the landing disc at the cursor, clamped to that range so it stops where the
## cast lands. Drawn through AimKit only. A slot is ground-targeted when its data has "ground": {range, r (key
## paths in the slot def, e.g. "lance.range"), recast (true: only its recast lands at the cursor)}.
## Shown while the key is held to aim (Quick cast off: Match.aim_hold) and inside a kit's own aim hold (ring()).

const RING_ALPHA := 0.45   # the max-range ring is faint: it frames the aim, the disc is the read
const RING_LW := 0.04      # m, thinner than a telegraph rim (AimShapes.LW)

## [max range, landing radius] in m from the slot's "ground" keys; ZERO when the slot is not ground-targeted.
static func of(k: ArchKit, slot: String) -> Vector2:
	var sd: Dictionary = k.d.get(slot, {})
	var gs: Dictionary = sd.get("ground", {})
	if gs.is_empty():
		return Vector2.ZERO
	return Vector2(_num(sd, String(gs.get("range", ""))), _num(sd, String(gs.get("r", ""))))

## Does a press now place at the cursor? (Brimseed's recast pops the seed; Hearthlight's recast is the throw.)
static func live(k: ArchKit, slot: String) -> bool:
	var up := (slot == "e" and k.e_recastable()) or (slot == "x" and k.ult_running())
	return up == bool(k.d[slot]["ground"].get("recast", false))

## Quick cast off: the key holds to aim, unless the kit aims that slot on its own hold ("aim_max" in its data).
static func holds(k: ArchKit, slot: String) -> bool:
	return k != null and of(k, slot) != Vector2.ZERO and not k.d[slot].has("aim_max") and live(k, slot)

## The held-key preview: the range ring and the landing disc at the clamped cursor.
static func preview(k: ArchKit, slot: String) -> void:
	var g := of(k, slot)
	if g == Vector2.ZERO or not live(k, slot):
		return
	ring(k, slot)
	if g.y > 0.0:
		AimKit.circle(k.h, slot + "_spot", {"range": g.x, "r": g.y, "ticks": true})

## The max-range ring alone, for a kit whose own aim hold already draws its landing mark.
static func ring(k: ArchKit, slot: String) -> void:
	AimKit.circle(k.h, slot + "_reach", {"self": true, "r": of(k, slot).x, "alpha": RING_ALPHA, "lw": RING_LW})

static func _num(sd: Dictionary, path: String) -> float:
	var v: Variant = sd
	for key in path.split("."):
		v = (v as Dictionary).get(key, 0.0) if v is Dictionary else 0.0
	return float(v)
