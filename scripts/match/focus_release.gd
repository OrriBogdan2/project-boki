class_name FocusRelease
extends RefCounted
## The window lost focus mid-hold (alt-tab, a popup, the OS taking focus): the button's release may never reach the
## game, so every held match key is let go here. An aimed cast is dropped, not loosed, and so is a bow draw (as the
## pause menu does), so nothing goes off at a cursor you can't see. Match._notification calls it.

## The match keys a hold acts on (Match._gather_input polls each of them every frame).
const HELD := [
	"fire",
	"secondary",
	"signature",
	"hunter_ult",
	"ultimate",
	"dash",
	"jump",
	"glide",
	"crouch",
	"scout",
	"interact",
	"up",
	"down",
	"left",
	"right"
]


static func release_all(m: Match) -> void:
	m.aim_hold = ""
	if m.player:
		m.player.draw_t = -1.0
	for a in HELD:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			Input.action_release(a)
