class_name WardenAirTilt
extends RefCounted
## A Hero's own pitch in the air, handed to HunterAnim's AIR_TILT (one owner: the rig, the clip root WardenClips turns
## by AIR_TILT, and a Boki riding on the torso you see all pitch together). AIR_TILT pitches every body DIVE_PITCH
## nose-down in a plunge and banks it into glider turns; a Hero with clips adds to that: head-down past it in a plunge
## (the glider's dive, the opening skydive) and a little forward under the glider so the legs trail.
## Per Hero in content/rules/warden_anim/<art>.json "air": dive_tilt, glide_tilt (degrees, the whole pitch); a
## "rig_root" Hero already rode the rig's own tip, so its dive_tilt is what it adds and DIVE_PITCH is not taken off.

const DIVE_TILT := 105.0     # deg forward in a plunge: past 90 the head is below the hips
const GLIDE_TILT := 12.0     # deg forward under the glider: the legs trail behind
const META := &"air_pitch"   # root meta, Vector2(rad added in a plunge, rad under the glider), read by HunterAnim


## Sets the model root's META from the Hero's "air" data.
static func hand_over(root: Node3D, air: Dictionary, rig_root: bool) -> void:
	var dive := float(air.get("dive_tilt", DIVE_TILT)) - (0.0 if rig_root else rad_to_deg(HunterAnim.DIVE_PITCH))
	root.set_meta(META, Vector2(deg_to_rad(dive), deg_to_rad(float(air.get("glide_tilt", GLIDE_TILT)))))
