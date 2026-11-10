class_name VoiceChat
extends RefCounted
## Voice-chat hook for the pre-match lobby. No voice transport ships yet: `transport` is where one
## plugs in (a Callable taking `talking: bool`). Until then holding the talk key only lights the
## local indicator, and the lobby says voice isn't connected.

var transport := Callable()
var talking := false

func available() -> bool:
	return transport.is_valid()

## Push-to-talk down (true) or up (false); passed to the transport when there is one.
func set_talking(on: bool) -> void:
	talking = on
	if transport.is_valid():
		transport.call(on)
