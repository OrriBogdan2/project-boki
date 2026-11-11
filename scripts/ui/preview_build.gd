class_name PreviewBuild
extends RefCounted
## A Mask's model for a preview (the Masks screen's turntable, the ability clips, the Mask moments). A build
## costs tens of ms and the first read of a Warden's .glb far more, so a screen full of previews would stall
## on one frame: here the .glb is read on a loader thread first (WardenGlb.fetch) and at most one preview
## model is built a frame, so the screen fills in over a few frames instead. The Masks a pick screen shows next
## are built once ahead under a load's cover (warm()), so their first preview costs what a later one does.

static var last_frame := -1    # the last frame a preview model (or a Warden's neutral rig) was built in
static var _warm := {}         # Hunter id -> true once warm() has done all its first-preview work

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

## Does ahead, while a load's cover hides the time, the one-off work of the first preview of each Mask a pick
## screen shows next (60-180 ms headless, against about 6 ms for a later one): its procedural body's meshes
## (built and freed) and, once its .glb is read, the rig check that first opens the file (WardenGlb.misfits).
## The .glb starts reading here, so a screen that calls this early (the title) leaves a later one (the hatch,
## the farm) only the check to finish.
static func warm() -> void:
	for id in _due():
		if _warm.has(id) or not Arch.exists(id):
			continue
		WardenGlb.fetch(id)
		WardenGlb.procedural(id, Unmasked.mask_look()).free()
		if WardenGlb.fetched(id):
			WardenGlb.will_dress(id)      # (a .glb Warden's rig check, with its neutral rest)
			_warm[id] = true

## The Masks whose previews come next: the starter pick on a new save, else the worn Mask, the second
## pick's three while it waits and any reveal queued.
static func _due() -> Array:
	if ClassUnlock.needs_starters():
		return ClassUnlock.starters()
	var c := ClassUnlock.state()
	var ids: Array = [Arch.of_save()]
	if ClassUnlock.second_pending():
		ids.append_array(c["second"])
	ids.append_array(c.get("reveal", []))
	return ids
