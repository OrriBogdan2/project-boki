class_name LabelSpacing
extends RefCounted
## Keeps the world's Label3Ds from printing over each other. Every frame the labels on screen are
## taken in priority order (damage numbers, monster plates, lair boards; perk orb names are LabelClash's)
## and each one yields to what is above it:
##   LabelSpacing.update(m, cards, delta)   cards: the message lane's rects (they cover the lair boards only)

## A label whose fade is past this has already given way, so it no longer covers what is under it.
const SHOWN_BELOW := 0.5

## Higher-priority groups first.
static func update(m, cards: Array[Rect2], delta: float) -> void:
	if m == null or m.cam == null:
		return
	var covers: Array[Rect2] = []
	_add_numbers(m, covers)
	var plates: Array[Label3D] = []
	for mb in m.mobs:
		var lbl := mb.get_node_or_null("Nameplate") as Label3D if is_instance_valid(mb) else null
		if lbl != null:
			plates.append(lbl)
	yield_group(plates, m.cam, covers, delta)
	var boards: Array[Label3D] = []
	for L in m.lairs.list if m.lairs != null else []:
		var lnodes = L.get("nodes")
		var lbl = lnodes.get("label") if lnodes is Dictionary else null
		if lbl is Label3D and is_instance_valid(lbl):
			boards.append(lbl)
	yield_group(boards, m.cam, covers + cards, delta)

## The floating numbers and words never give way: their boxes are where the rest must keep clear.
static func _add_numbers(m, covers: Array[Rect2]) -> void:
	for n in m.fx.nums:
		var lbl := n["node"] as Label3D
		if lbl.visible and not m.cam.is_position_behind(lbl.global_position):
			covers.append(MsgLane.label_rect(lbl, m.cam))

## Fades each label under `covers`; one still showing then covers the labels after it (list order is priority).
static func yield_group(group: Array[Label3D], cam: Camera3D, covers: Array[Rect2], delta: float) -> void:
	for lbl in group:
		MsgLane.yield_label(lbl, cam, covers, delta)
		var on_screen := lbl.is_visible_in_tree() and not cam.is_position_behind(lbl.global_position)
		if lbl.transparency < SHOWN_BELOW and on_screen:
			covers.append(MsgLane.label_rect(lbl, cam))
