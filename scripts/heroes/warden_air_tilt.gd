class_name WardenAirTilt
extends RefCounted
## A Hero's whole body in the air, on top of the clips (WardenClips) and of HunterAnim's AIR_TILT (the glider's bank and
## the dive's DIVE_PITCH, which WardenClips._air_tilt turns the clip's root by): this adds each Hero's own pitch, head-down
## past AIR_TILT's in a plunge (the glider's dive, the opening skydive) and a little forward under the glider so the legs
## trail. It turns the whole .glb about the hips. The bank is AIR_TILT's alone (one owner, no double bank).
## Per Hero in content/rules/warden_anim/<art>.json "air": dive_tilt, glide_tilt (degrees, the whole pitch); a "rig_root"
## Hero already rode the rig's own tip, so its dive_tilt is what it adds and AIR_TILT's pitch is not taken off it.

const DIVE_TILT := 105.0     # deg forward in a plunge: past 90 the head is below the hips
const GLIDE_TILT := 12.0     # deg forward under the glider: the legs trail behind
const RATE := 9.0            # 1/s: how fast the body follows (a dive tips over in ~0.3 s)

var glb: Node3D
var rest: Transform3D        # the .glb's own place under the model
var pivot: Vector3           # the hips at rest, in the .glb's space
var dive_tilt := DIVE_TILT   # deg this adds in a plunge (AIR_TILT's DIVE_PITCH taken off unless "rig_root")
var glide_tilt := GLIDE_TILT
var pitch := 0.0             # deg now

func _init(node: Node3D, skel: Skeleton3D, air: Dictionary, rig_root := false) -> void:
	glb = node
	rest = glb.transform
	var to_glb := glb.global_transform.affine_inverse() * skel.global_transform
	pivot = to_glb * skel.get_bone_global_rest(WardenSkeleton.find(skel, "hips")).origin
	dive_tilt = float(air.get("dive_tilt", DIVE_TILT)) - (0.0 if rig_root else rad_to_deg(HunterAnim.DIVE_PITCH))
	glide_tilt = float(air.get("glide_tilt", GLIDE_TILT))

func step(s: Dictionary, dt: float) -> void:
	var want := glide_tilt if bool(s.get("gliding", false)) else 0.0
	if bool(s.get("diving", false)):
		want = dive_tilt
	pitch = lerpf(pitch, want, 1.0 - exp(-dt * RATE))
	if absf(pitch) < 0.05:
		glb.transform = rest
		return
	# (the model faces -Z: forward tips the head toward -Z)
	var b := Basis(Vector3.RIGHT, -deg_to_rad(pitch))
	glb.transform = rest * Transform3D(b, pivot - b * pivot)
