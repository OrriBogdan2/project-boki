class_name GlideDivePose
extends RefCounted
## The body in the glider's dive (GlideDive): the canopy folds, the hunter tucks head first with the arms swept back
## along the sides and the legs straight together, and on release or at the cancel height he pulls out: the chest
## comes up, arms fling out and legs swing forward while the glider unfurls, then the glide pose takes over. How
## quickly and how far depends on the body: light hunters snap in and out, heavy ones swing slower and less.
## HunterAnim lays this over its skydive pose (dive_k); heroes with hand-keyed clips hand over to that rig while
## `on_rig` (WardenClips "procedural" "dive_on"), so the clips' glide never shows in a plunge.

const IN_RATE := 16.0       # 1/s the tuck eases in: about 80% of it 0.1 s after the plunge starts
const OUT_RATE := {"light": 7.0, "medium": 5.5, "heavy": 4.0}     # 1/s the pull-out eases off, by body weight
const FLARE := {"light": 1.0, "medium": 0.8, "heavy": 0.55}       # how wide the pull-out throws the arms and legs
const TIP := 1.25           # rad past the skydive's 1.15: head 47 degrees under level
const LEG_H := -0.05        # rad: hip angle of a straight, trailing leg
const LEG_K := -0.15        # rad: knee angle of the same
const ARM_BACK := Vector3(0.04, -0.5, 0.1)      # m, hand from its shoulder: swept back along the body
const ARM_FLARE := Vector3(0.34, 0.8, -0.1)     # m, added at the peak of the pull-out (mirrored for the left)
const LEG_FLARE := 0.6      # rad: the legs swing forward by this at the peak
const REST_K := 0.1         # below this the pose hands back to the glide

var k := 0.0                # 0..1 how tucked he is
var flare := 0.0            # 0..1 pull-out swing: zero while diving, peaks halfway through the recovery
var cls := "medium"         # light, medium or heavy

## One frame: the tuck follows `on` (plunging now); touching the ground drops it at once, so the landing
## recovery starts from the land pose, not a dive.
func step(on: bool, grounded: bool, dt: float) -> void:
	if grounded:
		k = 0.0
	else:
		k = move_toward(k, 1.0 if on else 0.0, rate(on) * dt)
	flare = 0.0 if on else 4.0 * k * (1.0 - k) * float(FLARE[cls])

## Whether the dive's rig pose is up: in the plunge and through the pull-out.
func on_rig() -> bool:
	return k > REST_K

## Ease rate (1/s) for the tuck and for the skydive weight (dive_k) so the folded canopy moves with it: quick in,
## the body's own rate out, and `rest` when no glide dive is showing.
func rate(on: bool, rest := 6.0) -> float:
	if on:
		return IN_RATE
	return float(OUT_RATE[cls]) if k > 0.0 else rest

## The hip angle (rad) of both legs: straight back in the plunge, swinging forward in the pull-out.
func leg_h() -> float:
	return LEG_H + flare * LEG_FLARE

## The rig tip (rad) the plunge adds past the skydive, and the pull-out takes back.
func tip() -> float:
	return TIP * k - flare * 0.35

## Where the hand goes from its shoulder: -1 left, 1 right.
func hand(side: float) -> Vector3:
	var back := Vector3(-side * ARM_BACK.x, ARM_BACK.y, ARM_BACK.z)
	return back + Vector3(side * ARM_FLARE.x, ARM_FLARE.y, ARM_FLARE.z) * flare
