extends RefCounted
## --hair-check: the hair gallery's own asserts.

func run(main: Node) -> void:
	var hb: int = load("res://tests/hair_gallery.gd").check()
	print("HAIR CHECK DONE, failures: ", hb)
	main.get_tree().quit()
