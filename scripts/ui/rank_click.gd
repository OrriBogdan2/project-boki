class_name RankClick
extends Control
## A click target over one slot's gold "+" (RankMarks): a left click spends a skill point on that
## ability, as Alt + its key does. It follows the spot RankMarks drew this frame and hides when the
## slot can't rank. It sits in Hud.ui_extra, so the cursor over it shows the pointer and never fires.

var hud
var slot := ""

## One click target per ranked slot on the HUD's layer.
static func attach(H) -> void:
	for s in Hunter.SLOTS:
		var rc := RankClick.new()
		rc.hud = H
		rc.slot = s
		rc.visible = false
		rc.mouse_filter = Control.MOUSE_FILTER_STOP
		rc.z_index = 90
		H.add_child(rc)
		H.ui_extra.append(rc)

func _process(_dt: float) -> void:
	var at := RankMarks.spot(slot)
	visible = at.has_area()
	if visible:
		position = at.position
		size = at.size

func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	accept_event()
	var p: Hunter = hud.m.player
	if p != null and p.is_local():
		p.level_slot(slot)
