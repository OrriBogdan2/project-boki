class_name LabelClash
extends RefCounted
## Which world labels win when two land on the same spot (FUN_AUDIT_1111 gap 7).
## Hud._draw_world_labels claims the screen box of every label that must stay readable (damage numbers,
## then nameplates, monster bars, Boki labels); a loot name or a perk orb's name asks first and steps
## aside (the tag is skipped, the orb's Label3D fades) when its box is already claimed. The claimed
## boxes live in one array that keeps its capacity, so a frame allocates nothing.

const CAP := 48                          # boxes kept per frame; claims past this are dropped
const PLATE := Vector2(60.0, 34.0)       # px, half size of a nameplate box around its anchor
const BAR := Vector2(34.0, 22.0)         # px, half size of a monster or Boki bar box
const NUM := Vector2(40.0, 22.0)         # px, half size of a floating damage number

## Boxes claimed this frame, in screen px (last frame's while the Hud's _process runs).
static var boxes: Array[Rect2] = []

static func begin() -> void:
	boxes.clear()

## Claims a box of `half` around `at`.
static func claim(at: Vector2, half: Vector2) -> void:
	if boxes.size() < CAP:
		boxes.append(Rect2(at - half, half * 2.0))

## Whether `r` overlaps a claimed box.
static func blocked(r: Rect2) -> bool:
	for b in boxes:
		if b.intersects(r):
			return true
	return false

## The floating damage numbers claim first, so no tag draws over a number a hit just put there.
static func claim_numbers(fx: Fx, cam: Camera3D) -> void:
	for n in fx.nums:
		var l: Label3D = n["node"]
		if l.visible and not cam.is_position_behind(l.global_position):
			claim(cam.unproject_position(l.global_position), NUM)

## Perk orb names (Label3D) fade while a claimed box covers them, and come back when it clears.
static func fade_orbs(m: Match, delta: float) -> void:
	for o in PerkOrbs.list(m):
		var nm := (o["node"] as Node).get_node_or_null("Bob/Name") as Label3D
		if nm and not o["faded"]:
			MsgLane.yield_label(nm, m.cam, boxes, delta)
