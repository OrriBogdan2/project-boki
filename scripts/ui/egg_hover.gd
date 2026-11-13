class_name EggHover
extends RefCounted
## How the hatch-scene eggs answer the pointer (briefs/DECISIONS.md, "show only what's needed right
## now"): the egg under it grows a touch and its rim glows softly, and the hidden black egg also gets
## a small hint beside it. All of it fades in and out in FADE and is gone once you leave the egg or
## pick it; the black egg's card shows only while it is the picked one.

const FADE := 0.15                    # s: a hover glow or the hint fading fully in or out
const GROW := 0.12                    # how much bigger the egg under the pointer gets
const RIM := 3.0                      # extra rim strength at full hover (the toon rest is 0.35)
const RIM_COL := Color("d8ccff")      # a soft lilac edge
const HINT_AT := Vector3(-0.5, 0.6, 0)  # m from the basket: the hint ends just left of the egg
const HINT_TEXT := "A hidden egg  ·  click to look"

var eggs: Array        # the hatch scene's [{holder, egg}]
var hidden_at := -1    # which egg is the hidden one (gets the hint)
var hint: Label
var glow: Array[float] = []

func _init(egg_list: Array, hidden: int, layer: Control) -> void:
	eggs = egg_list
	hidden_at = hidden
	glow.resize(eggs.size())
	glow.fill(0.0)
	hint = UI.label(HINT_TEXT, 13, UI.INK)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	hint.add_theme_constant_override("outline_size", 4)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.modulate.a = 0.0
	hint.visible = false
	layer.add_child(hint)

## One frame of the pick: `hover` is the egg under the pointer (-1: none), `chosen` the picked one.
func update(delta: float, hover: int, chosen: int, cam: Camera3D) -> void:
	var step := delta / FADE
	for i in eggs.size():
		var k := move_toward(glow[i], 1.0 if i == hover else 0.0, step)
		if k != glow[i]:
			glow[i] = k
			_show(i, k)
	var want := 1.0 if hover == hidden_at and chosen != hidden_at else 0.0
	hint.modulate.a = move_toward(hint.modulate.a, want, step)
	hint.visible = hint.modulate.a > 0.0
	if hint.visible:
		var at: Vector3 = (eggs[hidden_at]["holder"] as Node3D).global_position + HINT_AT
		hint.reset_size()
		hint.position = cam.unproject_position(at) - Vector2(hint.size.x, hint.size.y * 0.5)

## Off at once (the pick is over): every egg back to rest and the hint gone for good.
func clear() -> void:
	for i in eggs.size():
		glow[i] = 0.0
		_show(i, 0.0)
	if is_instance_valid(hint):
		hint.queue_free()

func _show(i: int, k: float) -> void:
	(eggs[i]["holder"] as Node3D).scale = Vector3.ONE * (1.0 + GROW * k)
	(eggs[i]["egg"] as EggHatch).set_hover(k, RIM, RIM_COL)
