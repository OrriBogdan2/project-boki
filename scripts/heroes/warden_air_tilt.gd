class_name WardenAirTilt
extends RefCounted
## A Hero's whole body in the air, on top of the clips (WardenClips): it pitches head-down in a plunge (the glider's
## dive, the opening skydive), hangs a little forward under the glider so the legs trail, and banks by the glider's
## steer (WardenGlide.lean). The clips own the limbs; this turns the whole .glb about the hips, the way HunterAnim tips the procedural rig.
## Per Hero in content/rules/warden_anim/<art>.json "air": dive_tilt, glide_tilt, glide_bank (degrees); "rig_root"
## Heroes already ride the rig's own tip, so their data sets what they add to it.

const DIVE_TILT := 105.0     # deg forward in a plunge: past 90 the head is below the hips
const GLIDE_TILT := 12.0     # deg forward under the glider: the legs trail behind
const GLIDE_BANK := 28.0     # deg sideways at full steer
const RATE := 9.0            # 1/s: how fast the body follows (a dive tips over in ~0.3 s)

var glb: Node3D
var rest: Transform3D        # the .glb's own place under the model
var pivot: Vector3           # the hips at rest, in the .glb's space
var dive_tilt := DIVE_TILT
var glide_tilt := GLIDE_TILT
var glide_bank := GLIDE_BANK
var pitch := 0.0             # deg now
var bank := 0.0

func _init(node: Node3D, skel: Skeleton3D, air: Dictionary) -> void:
	glb = node
	rest = glb.transform
	var to_glb := Transform3D()      # (local transforms: the model is often built before it is in the tree)
	var n: Node = skel
	while n != glb and n is Node3D:
		to_glb = (n as Node3D).transform * to_glb
		n = n.get_parent()
	pivot = to_glb * skel.get_bone_global_rest(WardenSkeleton.find(skel, "hips")).origin
	dive_tilt = float(air.get("dive_tilt", DIVE_TILT))
	glide_tilt = float(air.get("glide_tilt", GLIDE_TILT))
	glide_bank = float(air.get("glide_bank", GLIDE_BANK))

## lean: the glider's steer, -1 left .. 1 right, already eased (WardenGlide.lean).
func step(s: Dictionary, lean: float, dt: float) -> void:
	var diving := bool(s.get("diving", false))
	var gliding := bool(s.get("gliding", false))
	var want_pitch := glide_tilt if gliding else 0.0
	if diving:
		want_pitch = dive_tilt
	var want_bank := -lean * glide_bank if gliding else 0.0
	var k := 1.0 - exp(-dt * RATE)
	pitch = lerpf(pitch, want_pitch, k)
	bank = lerpf(bank, want_bank, k)
	if absf(pitch) < 0.05 and absf(bank) < 0.05:
		glb.transform = rest
		return
	# (the model faces -Z: forward tips the head toward -Z; a left lean, a plus bank, tips the head to -X)
	var b := Basis(Vector3.BACK, deg_to_rad(bank)) * Basis(Vector3.RIGHT, -deg_to_rad(pitch))
	glb.transform = rest * Transform3D(b, pivot - b * pivot)
