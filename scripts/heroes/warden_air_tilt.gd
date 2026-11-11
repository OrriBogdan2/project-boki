class_name WardenAirTilt
extends RefCounted
## A Hero's whole body in the air, on top of the clips (WardenClips): it pitches head-down in a plunge (the glider's
## dive, the opening skydive), hangs a little forward under the glider so the legs trail, and banks into the glider's
## turns. The clips own the limbs; this turns the whole .glb about the hips, the way HunterAnim tips the procedural rig.
## Per Hero in content/rules/warden_anim/<art>.json "air": dive_tilt, glide_tilt, glide_bank (degrees); "rig_root"
## Heroes already ride the rig's own tip, so their data sets what they add to it.

const DIVE_TILT := 105.0     # deg forward in a plunge: past 90 the head is below the hips
const GLIDE_TILT := 12.0     # deg forward under the glider: the legs trail behind
const GLIDE_BANK := 28.0     # deg sideways at TURN_FULL
const TURN_FULL := 4.0       # rad/s of turning that banks the whole GLIDE_BANK (the glider turns ~7 at cruise)
const RATE := 9.0            # 1/s: how fast the body follows (a dive tips over in ~0.3 s)
const TURN_SMOOTH := 10.0    # 1/s: the turn rate is smoothed over a few frames

var glb: Node3D
var rest: Transform3D        # the .glb's own place under the model
var pivot: Vector3           # the hips at rest, in the .glb's space
var dive_tilt := DIVE_TILT
var glide_tilt := GLIDE_TILT
var glide_bank := GLIDE_BANK
var pitch := 0.0             # deg now
var bank := 0.0
var turn := 0.0              # rad/s, smoothed
var face_was := NAN

func _init(node: Node3D, skel: Skeleton3D, air: Dictionary) -> void:
	glb = node
	rest = glb.transform
	var to_glb := glb.global_transform.affine_inverse() * skel.global_transform
	pivot = to_glb * skel.get_bone_global_rest(WardenSkeleton.find(skel, "hips")).origin
	dive_tilt = float(air.get("dive_tilt", DIVE_TILT))
	glide_tilt = float(air.get("glide_tilt", GLIDE_TILT))
	glide_bank = float(air.get("glide_bank", GLIDE_BANK))

func step(s: Dictionary, dt: float) -> void:
	var face := float(s.get("face", 0.0))
	var rate := wrapf(face - face_was, -PI, PI) / dt if not is_nan(face_was) and dt > 0.0 else 0.0
	face_was = face
	turn = lerpf(turn, rate, 1.0 - exp(-dt * TURN_SMOOTH))
	var diving := bool(s.get("diving", false))
	var gliding := bool(s.get("gliding", false))
	var want_pitch := glide_tilt if gliding else 0.0
	if diving:
		want_pitch = dive_tilt
	var want_bank := clampf(turn / TURN_FULL, -1.0, 1.0) * glide_bank if gliding else 0.0
	var k := 1.0 - exp(-dt * RATE)
	pitch = lerpf(pitch, want_pitch, k)
	bank = lerpf(bank, want_bank, k)
	if absf(pitch) < 0.05 and absf(bank) < 0.05:
		glb.transform = rest
		return
	# (the model faces -Z: forward tips the head toward -Z, a left turn, face growing, leans the head to -X)
	var b := Basis(Vector3.BACK, deg_to_rad(bank)) * Basis(Vector3.RIGHT, -deg_to_rad(pitch))
	glb.transform = rest * Transform3D(b, pivot - b * pivot)
