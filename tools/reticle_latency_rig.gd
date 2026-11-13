extends Node
## Runs before every other node's _process (priority -1000): asks the latency tool for this frame's cursor sample.

var tool

func _process(_delta: float) -> void:
	tool.sample()
