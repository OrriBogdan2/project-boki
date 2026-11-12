class_name HubHints
extends RefCounted
## First-time hints for a new player in the garden hub (briefs/design/GARDEN.md 10): the Waystone's
## ring, the nest corner and a sleeping zone's two keys. Each shows once per save as a line in the
## message lane (never a panel, so nothing blocks), one at a time, when you stand near what it is about.
## The rules and texts are content/rules/garden_zones.json "hub_hints"; seen ones live in
## Save.d["tutorial"]["hub_hints"]. The garden tutorial's own closing hint is not repeated here.

const TIP_COL := Color("f3e6c8")
const TIP_LIFE := 6.0      # s a hint stays in the lane, the same as a match's first-time hint

var h                      # the Home screen (the hub)
var _wait := 0.0           # s until the next hint may show

func _init(home) -> void:
	h = home
	_wait = float(rules()["start_s"])

static func rules() -> Dictionary:
	return GardenZones.rules()["hub_hints"]

## Per frame: shows the first unseen hint whose place you are near, if none is up.
func tick(dt: float) -> void:
	_wait -= dt
	if _wait > 0.0 or h.panel_open != "" or Overlay.is_open() or not Settings.get_v("tips") or Record.clean():
		return
	var seen: Dictionary = Save.d["tutorial"].get_or_add("hub_hints", {})
	for e in rules()["list"]:
		if seen.has(e["id"]) or not _now(e, seen):
			continue
		seen[e["id"]] = true
		_wait = float(rules()["gap_s"])
		var lane := MsgLane.of(h.root_ui)
		lane.top = 100.0
		var text := String(e["text"]).replace("{interact}", Settings.key_cap("interact"))
		lane.push(text, TIP_COL, MsgLane.NORMAL, TIP_LIFE)
		return

func _now(e: Dictionary, seen: Dictionary) -> bool:
	if e.has("needs") and not seen.has(e["needs"]):
		return false
	if bool(e.get("locked", false)) and GardenZones.ids().all(func(id): return GardenZones.is_open(id)):
		return false
	var at: Vector3 = h.hway.node.position if e["at"] == "waystone" else h.NEST_AT
	return Vector2(h.ppos.x - at.x, h.ppos.z - at.z).length() < float(rules()["near_m"])
