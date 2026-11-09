class_name DashGlide
extends RefCounted
## Owner 11-08 (briefs/DECISIONS.md): a fresh glide press in the air cancels any Hunter's Shift move into the glide at
## once, no minimum time. The dash ends that step and the glider opens at the dash's own velocity (Hunter's handoff
## keeps it). Only the Shift move: an ability's wind-up or recovery stays AirLimits' (item 162b).

## Ends the air dash a fresh glide press found (Hunter calls this as the press comes in). True when it ended one.
static func cancel(h: Hunter) -> bool:
	if h.grounded or h.roll_t <= 0.0 or h.dropping or h.downed or h.shot_down or h.glide_cd > 0.0:
		return false
	h.roll_t = 0.0          # (Hunter hands the burst's last step to the glider, as for any kit-cut dash)
	h.shove = {}
	return true
