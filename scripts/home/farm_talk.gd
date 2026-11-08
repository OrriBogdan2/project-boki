class_name FarmTalk
extends RefCounted
## Someone on the farm talking to you (home.gd owns one, for every NPC): an NpcDialogue in the panel slot,
## so you stand still, the tutorial waits (FarmGuide) and Esc closes it, while the camera eases in on the
## speaker's head and back out once they are done.

var h
var box: NpcDialogue = null
var head := Vector3.ZERO     # the speaker's head, where the camera eases to
var _k := 0.0                # 0..1: how far the camera has eased onto the speaker
var _zoom_was := -1.0        # the camera's zoom before the talk (-1: not talking)

func _init(home) -> void:
	h = home

func is_open() -> bool:
	return is_instance_valid(box) and not box.is_queued_for_deletion()

## `model` (the speaker `id`) says `lines` ([{text, mood}]). With `choice`, the last line gets a button
## that runs `on_choice`.
func open(id: String, model: Node3D, lines: Array, choice := "", on_choice := Callable()) -> NpcDialogue:
	h._close_panel()
	box = NpcDialogue.make(id, lines, model)
	if choice != "":
		box.add_choice(choice, on_choice)
	h.panel_host.add_child(box)
	h.panel_open = String(NpcDialogue.speaker(id)["name"])
	h.root_ui.move_child(h.panel_host, -1)
	if h.hub:
		h.hub.visible = false
	box.finished.connect(h._close_panel)
	box.tree_exiting.connect(_ended)
	head = model.global_position + Vector3(0, float(NpcDialogue.speaker(id)["head"]), 0)
	if _zoom_was < 0.0:
		_zoom_was = h.cam.zoom_to
	h.cam.zoom_to = float(NpcDialogue.rules()["cam_zoom"])
	return box

func _ended() -> void:
	if _zoom_was >= 0.0:
		h.cam.zoom_to = _zoom_was
	_zoom_was = -1.0

## The camera's focus: eased from `at` onto the speaker's head while they talk (slid toward the camera by
## cam_lift so they sit above the box), and back once they are done.
func frame(at: Vector3, dt: float) -> Vector3:
	var rules := NpcDialogue.rules()
	var want := 1.0 if is_open() else 0.0
	_k = lerpf(_k, want, 1.0 - exp(-float(rules["cam_ease"]) * dt))
	if _k < 0.001:
		return at
	var lift := Vector3(0, 0, float(rules["cam_lift"])).rotated(Vector3.UP, h.cam.yaw)
	return at.lerp(head + lift, smoothstep(0.0, 1.0, _k))
