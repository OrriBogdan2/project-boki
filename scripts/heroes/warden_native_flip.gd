class_name WardenNativeFlip
extends RefCounted
## The kit's whole-body flips on a native Hunter (data "flips" in warden_native.json: the kit moves that turn the
## body whole, Sable's Vault cartwheels). Meshy's clips have no flip, so the turn the kit move keys for the rig
## (HunterAnim's "fx" / "fz" turn, "fy" twist and "lift", read at the move's own clock: the press, the push-off, the
## landing crouch and upright at the dash's end) is laid on the dressed model, about the hips, in the plane she
## travels in: her head goes over the way she dashes (a cartwheel when she faces across it, a somersault along it),
## the twist turns her round her own length, and she stands as before once the move is over. Meanwhile the body
## holds the jump clip, not the attack clip a new kit move would start (WardenNative._process).

const PIVOT := HunterAnim.BODY_C  # the rig's whole-body turns go about the hips
const DIR_MIN := 0.1  # a dash way (or ground speed, m/s) shorter than this has no way to flip along

var glb: Node3D
var base: Transform3D  # the dressed model's own transform (Meshy faces +Z, its fit scale)
var ids: Array  # the kit moves that flip
var cur := ""  # the flip turning the body ("" none)
var prev_t := 0.0  # its clock last frame (a clock that goes back is the same move again)
var axis := Vector3.ZERO  # world: the turn's axis, locked at the press (up x the way she dashes)
var angle := 0.0  # rad the body is turned this frame (the check reads it)


func _init(model: Node3D, data: Dictionary) -> void:
	glb = model
	base = model.transform
	ids = data.get("flips", [])


## Whether this frame's kit move is a flip still turning the body: inside its keys, or a held one ("hold": the air
## cartwheel) while the dash or the air lasts.
func owns(s: Dictionary) -> bool:
	var km := String(s.get("kmove", ""))
	if not ids.has(km):
		return false
	var mv := HunterAnim.km_def(km)
	if mv.is_empty():
		return false
	var t := float(s.get("kmove_t", 0.0))
	if t < float(mv["keys"][-1][0]):
		return true
	return bool(mv.get("hold", false)) and (bool(s.get("rolling", false)) or not bool(s.get("grounded", true)))


## Lays this frame's turn on the model (after the clips: it turns the whole drawn body); upright when no flip owns it.
func step(s: Dictionary) -> void:
	if not owns(s):
		if cur != "":
			glb.transform = base
			cur = ""
			angle = 0.0
		return
	var km := String(s.get("kmove", ""))
	var t := float(s.get("kmove_t", 0.0))
	if km != cur or t < prev_t:
		axis = Vector3.UP.cross(_way(s))
	cur = km
	prev_t = t
	var k := HunterAnim.km_sample(km, t)
	angle = maxf(absf(float(k.get("fx", 0.0))), absf(float(k.get("fz", 0.0))))
	var parent := glb.get_parent() as Node3D
	var local := (parent.global_basis.orthonormalized().inverse() * axis).normalized()
	var turn := Basis(local, angle) * Basis(Vector3.UP, float(k.get("fy", 0.0)))
	glb.transform = Transform3D(turn, PIVOT - turn * PIVOT + Vector3(0.0, float(k.get("lift", 0.0)), 0.0)) * base


## The way she dashes, world (flat, unit): the dash's own way, else where she moves (a remote copy), else her front.
func _way(s: Dictionary) -> Vector3:
	var dir: Vector2 = s.get("dash_dir", Vector2.ZERO)
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	if dir.length() < DIR_MIN and Vector2(vel.x, vel.z).length() >= DIR_MIN:
		dir = Vector2(vel.x, vel.z)
	if dir.length() >= DIR_MIN:
		return Vector3(dir.x, 0.0, dir.y).normalized()
	var front := (glb.get_parent() as Node3D).global_basis * Vector3.FORWARD
	return Vector3(front.x, 0.0, front.z).normalized()
