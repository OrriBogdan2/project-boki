extends RefCounted
## --check: every script under res://scripts loads and can be instantiated.

func run(main: Node) -> void:
	var CheckT = load("res://tools/check.gd")
	var bad := 0
	for f in CheckT.new()._scan("res://scripts"):
		var sc = load(f)
		if sc == null or not sc.can_instantiate():
			print("FAIL ", f)
			bad += 1
	print("CHECK DONE, failures: ", bad)
	main.get_tree().quit()
