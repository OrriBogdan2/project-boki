class_name InteractGate
extends RefCounted
## The interact key in the world, minus the press that just closed a panel. A talk box (or any panel) that
## closes on interact does it in the key's input event; the world reads the same press later that frame by
## polling, sees the panel gone, and uses it: Hob's chat would close and open again. So the world asks here:
## while a panel is up the key is disarmed, and it arms again only once the world is free AND the key is up.
## The press that closed something (even held down for a while) never counts; the next fresh press does.
## (One gate for every scene that polls interact: the farm, a house inside, the town.)
##
##   InteractGate.track(free)               # once a frame, with whether the world is free for the key
##   if InteractGate.pressed(): use()       # instead of Input.is_action_just_pressed("interact")

static var _armed := true


## Records whether the world is free for interact this frame (call it once a frame, before reading the key).
static func track(free: bool) -> void:
	if not free:
		_armed = false
	elif not Input.is_action_pressed("interact"):
		_armed = true


## A fresh interact press: just pressed, and the key was let go since the last panel closed.
static func pressed() -> bool:
	return _armed and Input.is_action_just_pressed("interact")


## Back to armed (a scene starting fresh, a check).
static func reset() -> void:
	_armed = true
