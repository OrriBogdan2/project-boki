class_name HubFirstVisit
extends RefCounted
## The hub's two-beat first visit (briefs/design/GARDEN.md 10, DECISIONS 2026-11-10). Beat one: a marker
## floats over the Waystone, "Step in to travel", until you stand on the ring. Beat two: the first time the
## destination list opens, the first locked zone's card carries one line on how to open it (its two keys;
## the unlock is not a Goals-tracker goal, so the tracker is not used). Nothing blocks movement, each shows
## once per save (Save.d.tutorial.hub_first: marker, line), and neither shows on a skipped tutorial or
## with tips off. Texts and height: content/rules/garden_zones.json "hub_first".

const BOB_M := 0.12        # m the marker rises and falls
const BOB_RATE := 3.0      # rad/s of that bob

var h                      # the Home screen (the hub)
var marker: Label3D = null
var _t := 0.0

func _init(home) -> void:
	h = home
	if wanted("marker"):
		marker = Label3D.new()
		marker.text = String(rules()["marker_text"])
		marker.font_size = 56
		marker.pixel_size = 0.0095
		marker.outline_size = 16
		marker.modulate = UI.GOLD
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.no_depth_test = true
		marker.render_priority = 4
		marker.position = h.hway.node.position + Vector3(0, float(rules()["marker_h"]), 0)
		h.add_child(marker)

static func rules() -> Dictionary:
	return GardenZones.rules()["hub_first"]

## Is beat `id` still to show: not seen, tips on, the tutorial not skipped?
static func wanted(id: String) -> bool:
	return Settings.get_v("tips") and not FarmTutorial.state()["skipped"] \
			and not Save.d["tutorial"].get_or_add("hub_first", {}).has(id)

static func _seen(id: String) -> void:
	Save.d["tutorial"]["hub_first"][id] = true

## Per frame: the marker bobs; standing on the ring retires it for good.
func tick(dt: float) -> void:
	if marker == null:
		return
	var at: Vector3 = h.hway.node.position
	if Vector2(h.ppos.x - at.x, h.ppos.z - at.z).length() < HubWaystone.REACH:
		_seen("marker")
		marker.queue_free()
		marker = null
		return
	_t += dt
	marker.position.y = at.y + float(rules()["marker_h"]) + sin(_t * BOB_RATE) * BOB_M

## The line for the first locked zone's card when the list opens (an empty array when it is not due).
static func card_line(id: String) -> Array:
	if GardenZones.is_open(id) or not wanted("line"):
		return []
	_seen("line")
	return [UI.para(String(rules()["line_text"]), 12, UI.GOLD)]
