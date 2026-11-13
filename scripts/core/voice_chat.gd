class_name VoiceChat
extends RefCounted
## Voice-chat hook for the pre-match lobby. No voice transport ships yet: `transport` is where one
## plugs in (a Callable taking `talking: bool`). Until then holding the talk key only lights the
## local indicator, and the lobby says voice isn't connected.

var transport := Callable()
var sink := Callable()      # where a teammate's voice frame plays: a Callable taking `from: String, frame`
var talking := false

func available() -> bool:
	return transport.is_valid()

## Push-to-talk down (true) or up (false); passed to the transport when there is one.
func set_talking(on: bool) -> void:
	talking = on
	if transport.is_valid():
		transport.call(on)

## A voice frame from teammate `from`; played through `sink` unless you muted them. Returns whether it played.
func receive(from: String, frame: PackedByteArray) -> bool:
	if MuteList.has(from) or not sink.is_valid():
		return false
	sink.call(from, frame)
	return true
