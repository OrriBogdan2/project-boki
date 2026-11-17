class_name InteractGate
extends RefCounted
## The interact key in the world, minus the press that just closed a panel. A talk box (or any panel) that
## closes on interact does it in the key's input event; the world reads the same press later that frame by
## polling, sees the panel gone, and uses it: Hob's chat would close and open again. So the world asks here:
## a press counts only when the world was free on the frame before it, i.e. it is a fresh press, not the one
## that closed something. (The same gate holds back the key for every panel, not just the talk box.)
##
##   InteractGate.track(idle)               # once a frame, with whether the world is free for the key
##   if InteractGate.pressed(): use()       # instead of Input.is_action_just_pressed("interact") and _free_before

static var _free_now := true
static var _free_before := true


## Records whether the world is free for interact this frame (call it once a frame, before reading the key).
static func track(free: bool) -> void:
	_free_before = _free_now
	_free_now = free


## A fresh interact press: just pressed, and the world was already free on the frame before.
static func pressed() -> bool:
	return Input.is_action_just_pressed("interact") and _free_before
