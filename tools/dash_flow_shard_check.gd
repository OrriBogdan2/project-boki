extends RefCounted
## One shard of --dash-flow-check (the registry's --dash-flow-<n>-check flags): the whole check over the
## comma list of Hunters it is given, so each shard stays under the gate's 300 s cap.


func run(main: Node, heroes: String) -> void:
	await load("res://tools/dash_flow_check.gd").new().run_heroes(main, heroes.split(","))
