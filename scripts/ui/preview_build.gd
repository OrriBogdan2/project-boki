class_name PreviewBuild
extends RefCounted
## A Mask's model for a preview (the Masks screen's turntable, the ability clips, the Mask moments). A build
## costs tens of ms and the first read of a Warden's .glb far more, so a screen full of previews would stall
## on one frame: here the .glb is read on a loader thread first (WardenGlb.fetch) and at most one preview
## model is built a frame, so the screen fills in over a few frames instead.

static var last_frame := -1    # the last frame a preview model (or a Warden's neutral rig) was built in

## Whether the caller may build `hunter_id`'s preview model now: once its .glb is read, at most once a frame.
## A Warden whose neutral rig isn't measured yet spends this frame's turn on that.
static func turn(hunter_id: String) -> bool:
	if not WardenGlb.fetched(hunter_id) or Engine.get_process_frames() == last_frame:
		return false
	last_frame = Engine.get_process_frames()
	if not WardenGlb.has_rest(hunter_id):
		WardenGlb.neutral_rest(hunter_id)
		return false
	return true

## The Mask's model as a preview shows it: the Hunter in the player's Mask look, without its team ring.
static func model(hunter_id: String) -> Node3D:
	var m := Models.hunter(Arch.weight(hunter_id), Data.TEAM_COLORS[0], Arch.signature(hunter_id), "",
			Unmasked.mask_look(), hunter_id)
	var ring := m.get_node_or_null("TeamRing")
	if ring:
		(ring as Node3D).visible = false
	return m
