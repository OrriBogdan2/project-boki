class_name RigPace
extends RefCounted
## How often a seen skinned rig (a Boki's BokiRig, a Warden's WardenGlb.Sync) is stepped. On GL over Metal (the
## Mac's Compatibility renderer) every re-skin is a long render-CPU stall: about 1.3 ms a Boki rig on the M5
## (docs/PERF_PLAN_1111.md). There, below Ultra, a rig steps every EVERY frames with the time it held back, each
## rig on its own frame parity; the rig the camera follows (your own Warden) still steps every frame. Everywhere
## else every rig steps every frame.

const EVERY := 2            # frames between two steps of a rig where re-skinning is dear
const LEAD_M := 1.5         # m (flat) from the camera's focus: a rig this close is the one you play, every frame

var every := 1              # frames between steps for this rig (EVERY where re-skinning is dear)
var held := 0.0             # s the skipped frames held back, stepped at the next step
var _parity := 0

func _init(id: int) -> void:
	_parity = id
	every = EVERY if dear() else 1

## GL over Metal below Ultra.
static func dear() -> bool:
	var metal_gl := OS.get_name() == "macOS" and RenderingServer.get_current_rendering_method() == "gl_compatibility"
	return metal_gl and Settings.quality() != "ultra"

## The time to step the rig by this frame, or 0.0 to leave it as it is. `lead`: always step (the played rig).
func step(dt: float, lead := false) -> float:
	held += dt
	if not lead and (Engine.get_process_frames() + _parity) % every != 0:
		return 0.0
	var t := held
	held = 0.0
	return t

## True when `at` stands where the play camera in `vp` is following, or the view has no play camera (a menu's
## preview: one model, shown up close).
static func is_lead(vp: Viewport, at: Vector3) -> bool:
	var cam := vp.get_camera_3d() as CamRig
	return cam == null or Vector2(at.x - cam.focus.x, at.z - cam.focus.z).length_squared() < LEAD_M * LEAD_M
