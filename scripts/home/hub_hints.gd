class_name HubHints
extends RefCounted
## First-time hints for a new player in the garden hub (briefs/design/GARDEN.md 10): the Waystone's
## ring, the nest corner, a sleeping zone's two keys and, by the first egg placed in the Incubator, that
## it grows while you play (its look says when it is ready, with no message). Each shows once per save
## as a line in the message lane (never a panel, so nothing blocks), one at a time, when you stand near
## what it is about.
## The rules and texts are content/rules/garden_zones.json "hub_hints"; seen ones live in
## Save.d["tutorial"]["hub_hints"]. The garden tutorial's own closing hint is not repeated here.
## A Wayseed has two more, both once per save: a line on a run the first time one goes into your pack
## (seed_in_bag), and a pulse of the Waystone on your first arrival here holding one.

const TIP_COL := Color("f3e6c8")
const TIP_LIFE := 6.0      # s a hint stays in the lane, the same as a match's first-time hint

var h                      # the Home screen (the hub)
var _wait := 0.0           # s until the next hint may show
var _pulse := 0.0          # s of the Waystone's Wayseed pulse left

func _init(home) -> void:
	h = home
	_wait = float(rules()["start_s"])

static func rules() -> Dictionary:
	return GardenZones.rules()["hub_hints"]

## The first Wayseed in your pack on a run says what it is (`hud` is the match's).
static func seed_in_bag(hud) -> void:
	var seen: Dictionary = Save.d["tutorial"]
	if seen.get("wayseed_tip", false) or hud == null or not Settings.get_v("tips") or Record.clean():
		return
	seen["wayseed_tip"] = true
	hud.tip(String(rules()["wayseed_text"]))

## Per frame: shows the first unseen hint whose place you are near, if none is up.
func tick(dt: float) -> void:
	if _pulse > 0.0:
		_pulse_step(dt)
	_wait -= dt
	if _wait > 0.0 or h.panel_open != "" or Overlay.is_open() or not Settings.get_v("tips") or Record.clean():
		return
	var seen: Dictionary = Save.d["tutorial"].get_or_add("hub_hints", {})
	if not seen.has("seed_pulse") and _holds_seed():
		seen["seed_pulse"] = true
		_pulse = float(rules()["pulse_s"])
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
	var at: Vector3 = h.NEST_AT
	if e["at"] == "waystone":
		at = h.hway.node.position
	elif e["at"] == "egg":
		at = h.INCUB_AT
	if Vector2(h.ppos.x - at.x, h.ppos.z - at.z).length() >= float(rules()["near_m"]):
		return false
	return e["at"] != "egg" or not Incubator.eggs().is_empty()      # the egg's line waits for its first egg

func _holds_seed() -> bool:
	var items: Dictionary = Save.d["items"]
	return GardenZones.ids().any(func(id): return int(items.get(GardenZones.wayseed(id), 0)) > 0)

## The Waystone breathes for pulse_s, then settles back to its size.
func _pulse_step(dt: float) -> void:
	_pulse = maxf(_pulse - dt, 0.0)
	if not is_instance_valid(h.hway.node):
		return
	var t: float = float(rules()["pulse_s"]) - _pulse
	var swing := float(rules()["pulse_amp"]) * sin(TAU * float(rules()["pulse_hz"]) * t) if _pulse > 0.0 else 0.0
	h.hway.node.scale = Vector3.ONE * (1.0 + swing)
