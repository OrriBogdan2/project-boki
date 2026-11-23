class_name MateLook
extends CanvasLayer
## Hold F1, F2 or F3 (rebindable: Settings > Controls) to swing the camera to your teammate 1, 2 or 3; let go
## and it swings back to you. A name and health card sits at the top while you look. Teammate 3 only exists in
## a 4-player squad, so F3 does nothing in a smaller one.

const ACTIONS := ["mate_look_1", "mate_look_2", "mate_look_3"]
const CARD_TOP := 70.0        # px from the top of the screen
const CARD_W := 260.0         # px wide
const BAR_H := 10.0           # px, the health bar
const DOWNED := Color(0.9, 0.35, 0.3)
const HEALTHY := Color(0.45, 0.85, 0.5)

var m: Match
var looking: Hunter = null    # who the camera is on, null when it's on you
var _stamp := 0               # the frame focus() last ran (the card hides once the camera stops asking)
var card: Control
var name_lbl: Label
var bar: ProgressBar

func _init(match_node: Match) -> void:
	m = match_node
	layer = 5
	card = PanelContainer.new()
	card.position = Vector2(0, CARD_TOP)
	var box := VBoxContainer.new()
	name_lbl = Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(CARD_W, BAR_H)
	box.add_child(name_lbl)
	box.add_child(bar)
	card.add_child(box)
	card.visible = false
	add_child(card)

## Your teammates, in the order the squad was dealt: the ones F1, F2 and F3 look at.
func mates() -> Array:
	var p := m.player
	return m.hunters.filter(func(h: Hunter) -> bool: return h != p and h.team == p.team and not h.gone)

## Which key is held (0..2) and has a teammate to look at, or -1.
func held() -> int:
	if m.paused or Overlay.is_open() or (m.hud and m.hud.map_open()):
		return -1
	var list := mates()
	for i in ACTIONS.size():
		if i < list.size() and Input.is_action_pressed(ACTIONS[i]):
			return i
	return -1

## Where the camera should look this frame: your teammate while a key is held, else `own`.
func focus(own: Vector3, alpha: float) -> Vector3:
	_stamp = Engine.get_process_frames()
	var i := held()
	looking = mates()[i] if i >= 0 else null
	card.visible = looking != null
	if looking == null:
		return own
	name_lbl.text = "%s  %d / %d" % [looking.pname, ceili(looking.hp), ceili(looking.max_hp)]
	bar.max_value = looking.max_hp
	bar.value = looking.hp
	bar.modulate = DOWNED if looking.downed or looking.out else HEALTHY
	card.position.x = (get_viewport().get_visible_rect().size.x - CARD_W) * 0.5
	return looking.render_pos(alpha)

func _process(_d: float) -> void:
	if looking != null and Engine.get_process_frames() - _stamp > 1:
		looking = null
		card.visible = false
