class_name KMoveClip
extends RefCounted
## Kit-move clip data and sampling (split from HunterAnim, which keeps thin wrappers).

## Keyed full-body moves the archetype kits play for their abilities (state keys "kmove", the move's
## id, and "kmove_t", seconds since it started). Each is anticipation -> a key pose on the hit ->
## follow-through and recovery, keyed to the kit's own hit timing. Channels (all optional, eased
## between keys): p y r (torso pitch, yaw, roll, added), lift (the body up, m), fx fz fy (whole-body
## turns about the hips: forward flip, side flip, spin), sq (squash; negative stretches), legs
## [hl kl hr kr] with lw (their weight), fl / fr (a free hand's place from its shoulder) with hw / rw,
## blade (the greatsword's yaw, pitch, roll, like SWINGS) with bw, rad (the blade's reach), gp (a
## gun's extra pitch), wa / wo (a held weapon's extra pitch, yaw, roll and offset), wg (a 3D model's wings
## flared, 0..1: WardenGlb.Springs).
## A move with "hold": true stays on its last key until another replaces it; with
## "loop": t as well it cycles from t to the last key instead (a recoil wobble, hand over hand). A move with
## "stance": true keys its legs as a planted stance, used only standing (stance_leg_k); with "swing": n the
## weapon swing it starts plays step n of the weapon's SWINGS (one blade or the other, or both).
const KMOVES := {
}
## wf: how far a kit move takes the held weapon with the body (0: it stays on the aim, 1: it turns with the torso)
const KM_CH := ["p", "y", "r", "lift", "fx", "fz", "fy", "sq", "lw", "hw", "rw", "bw", "rad", "gp", "wf", "wg"]

## How much of a kit move's legs to use: all of them, or for a move keyed "stance": true (a throw or a shot
## from a planted stance) none at a run, so the legs keep running while the arms and torso play the move.
static func stance_leg_k(stance: bool, run: float) -> float:
	return 1.0 - clampf(run, 0.0, 1.0) if stance else 1.0

## Two kit-move poses mixed (u = 0: `a`, 1: `b`); a side without a channel counts as the rest pose, and the
## whole-body turns take the short way round.
static func km_mix(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	if a.is_empty() and b.is_empty():
		return {}
	u = u * u * (3.0 - 2.0 * u)
	var out := {}
	for c in KM_CH:
		var va := float(a.get(c, 0.0))
		var vb := float(b.get(c, 0.0))
		out[c] = lerp_angle(va, vb, u) if c in ["fx", "fy", "fz"] else lerpf(va, vb, u)
	var la: Array = a.get("legs", b.get("legs", []))
	var lb: Array = b.get("legs", la)
	if not la.is_empty():
		out["legs"] = [lerpf(la[0], lb[0], u), lerpf(la[1], lb[1], u), lerpf(la[2], lb[2], u), lerpf(la[3], lb[3], u)]
	for c in ["fl", "fr", "blade", "wa", "wo"]:
		if a.has(c) or b.has(c):
			var va2: Vector3 = a.get(c, b.get(c))
			var vb2: Vector3 = b.get(c, a.get(c))
			out[c] = va2.lerp(vb2, u)
	return out

## A kit move's keys, from whichever pair's table has it (scripts/match/kmoves_*.gd); empty if none.
static func km_def(id: String) -> Dictionary:
	for t in [KMOVES, KMovesPair.MOVES, KMovesVV.MOVES, KMovesStone.MOVES, MergeMoves.MOVES, KMovesCare.MOVES,
			KMovesPinBjorn.MOVES, KMovesDJ.MOVES]:
		if (t as Dictionary).has(id):
			return t[id]
	return {}

## Samples the kit move at time `tt`: each channel eased between the keys around it.
static func km_sample(id: String, tt: float) -> Dictionary:
	var mv := km_def(id)
	if mv.is_empty():
		return {}
	var keys: Array = mv["keys"]
	var last: Array = keys[-1]
	if tt >= float(last[0]):
		if not mv.get("hold", false):
			return {}
		tt = _km_held_t(mv, tt, float(last[0]))
	var i := 0
	while i < keys.size() - 2 and tt >= float(keys[i + 1][0]):
		i += 1
	var a: Array = keys[i]; var b: Array = keys[mini(i + 1, keys.size() - 1)]
	var span := maxf(0.001, float(b[0]) - float(a[0]))
	var u := clampf((tt - float(a[0])) / span, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	var pa: Dictionary = a[1]; var pb: Dictionary = b[1]
	var out := {}
	for c in KM_CH:
		var va := float(pa.get(c, 0.0)); var vb := float(pb.get(c, 0.0))
		# a weight that isn't keyed on one side falls off with the other side's pose
		out[c] = lerpf(va, vb, u)
	for c in ["legs"]:
		var la: Array = pa.get(c, []); var lb: Array = pb.get(c, [])
		if la.is_empty() and lb.is_empty(): continue
		if la.is_empty(): la = lb
		if lb.is_empty(): lb = la
		out[c] = [lerpf(la[0], lb[0], u), lerpf(la[1], lb[1], u), lerpf(la[2], lb[2], u), lerpf(la[3], lb[3], u)]
	for c in ["fl", "fr", "blade", "wa", "wo"]:
		var has_a := pa.has(c); var has_b := pb.has(c)
		if not has_a and not has_b: continue
		var va2: Vector3 = pa.get(c, pb.get(c)); var vb2: Vector3 = pb.get(c, pa.get(c))
		out[c] = va2.lerp(vb2, u)
	return out

## Where a held move samples past its last key: the last key, or with "loop" (the time it loops back to)
## round and round from there, for a held move that keeps moving (a recoil wobble, hand over hand).
static func _km_held_t(mv: Dictionary, tt: float, end_t: float) -> float:
	var loop_from := float(mv.get("loop", -1.0))
	if loop_from < 0.0 or loop_from >= end_t:
		return end_t
	return loop_from + fmod(tt - loop_from, end_t - loop_from)
