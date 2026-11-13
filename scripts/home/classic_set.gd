class_name ClassicSet
extends RefCounted
## A classic island's fixed house, market stall, Nesting Nook (with its Incubator) and Burrow: a save from
## before the farm-start update has them where they always stood. With the garden on they are the hub's
## (HubLayout.holds, DECISIONS 2026-11-10): the classic island builds none of them and they stand at Home.FAR.

const HOUSE := Vector3(38.0, 0, 26.5)
const STALL := Vector3(30.5, 0, 33.0)

## Does the hub hold this classic island's set?
static func held(h) -> bool:
	return HubLayout.holds(HomeLayout.of(h._d()), "house")

## Where the set stands and the tiles it blocks (all of it at FAR when the hub holds it).
static func place(h) -> void:
	if held(h):
		h.spots["house"] = h.FAR
		h.spots["stall"] = h.FAR
		h.NEST_AT = h.FAR
		h.INCUB_AT = h.FAR
		h.BURROW_AT = h.FAR
		return
	h.spots["house"] = HOUSE
	h.world.set_block_rect(36, 25, 40, 27)
	h.spots["stall"] = STALL
	h.world.set_block_rect(29, 32, 31, 33)

## The house, the stall, the Nook and (on your own island) the Burrow, unless the hub holds them.
static func build(h) -> void:
	if held(h):
		return
	var house := Models.house()
	house.position = HOUSE
	h.add_child(house)
	h.house_node = house
	var stall := StallModels.build(Stalls.level())
	stall.position = STALL
	stall.rotation.y = PI * 0.5
	h.add_child(stall)
	var nook := Models.nesting_nook()      # where two close Boki leave an egg
	nook.position = h.NEST_AT
	h.add_child(nook)
	_label(h, "Nesting Nook", Color("ffc0d0"), h.NEST_AT + Vector3(0, 2.95, -0.7))
	if not h.visit.is_empty():
		return
	h.burrow_node = KinBurrow.model(KinBox.boxed().size())
	h.burrow_node.position = h.BURROW_AT
	h.burrow_node.scale = Vector3.ONE * 0.8
	h.add_child(h.burrow_node)
	_label(h, "Boki Burrow", Color("d9c8ff"), h.BURROW_AT + Vector3(0, 1.85, 0.3))

static func _label(h, text: String, col: Color, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UI.big
	l.font_size = 40
	l.pixel_size = 0.008
	l.outline_size = 10
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at
	h.add_child(l)
