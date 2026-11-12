class_name WhistleHint
extends RefCounted
## The one-time nudge toward the garden whistle: once the first-day steps are done, if your partner is far
## away or out of sight for a while, a line on the HUD hint strip (above the key row, never on a Boki)
## says to whistle. It goes when the whistle is used. Once per save: Save.d.tutorial.whistle_hint.
## Tuning and text: content/rules/base_life.json "whistle" (hint_*).

var w: BaseWhistle         # the whistle this teaches
var pill: PanelContainer   # the line on screen, null when there is none
var _away := 0.0           # s the partner has been far or out of sight

func _init(whistle: BaseWhistle) -> void:
	w = whistle

## Per frame: counts the time the partner is apart from you and shows the line once it is long enough.
func tick(d: float) -> void:
	if pill or not _eligible():
		return
	_away = _away + d if _apart() else 0.0
	if _away >= float(w.R["hint_away_s"]):
		_show()

## The whistle was used: the line goes and does not come back.
func used() -> void:
	Save.d["tutorial"]["whistle_hint"] = true
	if pill:
		pill.queue_free()
		pill = null

func _eligible() -> bool:
	return not bool(Save.d["tutorial"].get("whistle_hint", false)) and w.h.visit.is_empty() \
			and not FarmTutorial.active() and Settings.get_v("tips") and not w.partner().is_empty()

func _apart() -> bool:
	var k := w.partner()
	var at: Vector3 = k["pos"]
	var gap := Vector2(at.x - w.h.ppos.x, at.z - w.h.ppos.z).length()
	if gap > float(w.R["hint_far_m"]) or k.has("indoors"):
		return true
	var cam: Camera3D = w.h.cam
	var spot := (k["node"] as Node3D).global_position + Vector3(0, 0.45, 0)
	var screen: Rect2 = w.h.get_viewport().get_visible_rect()
	return cam.is_position_behind(spot) or not screen.has_point(cam.unproject_position(spot))

func _show() -> void:
	Save.d["tutorial"]["whistle_hint"] = true
	pill = UI.glass(6, 12)
	pill.name = "WhistleHint"
	var line := [[Settings.key_cap("whistle"), String(w.R["hint_text"])]]
	pill.add_child(UI.key_hints(line, 14, Color(1, 1, 1, 0.9)))
	w.h.root_ui.add_child(pill)
	Record.hide_in_clean(pill)
	var lift := int(w.R["hint_lift_px"])
	pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, lift)
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
