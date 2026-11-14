class_name KinWildPose
extends RefCounted
## The body language of a wild Boki in a match, as the "pose" meta KinPuppet and BokiRig both read: it startles
## when something hits it (alert), then runs (whine, a timid one) or charges (growl); knocked out (dazed) it
## slumps and sways; while a Hunter scans it (scan) it is lifted and held. Wander is just the walk clip.

const NOTICE_S := 0.35        # s the startle lasts after the first hit, before it bolts or charges

## `since_hit`: s since it first got angry; `timid`: it runs away rather than fights.
static func pose(state: String, angry: bool, timid: bool, scanning: bool, since_hit: float) -> String:
	if state == "dazed":
		return "scan" if scanning else "dazed"
	if state != "wild" or not angry:
		return ""
	if since_hit < NOTICE_S:
		return "alert"
	return "whine" if timid else "growl"
