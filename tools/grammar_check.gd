extends RefCounted
## Parses every kin grammar file (docs/KIN_GRAMMAR.md) and prints structural errors.
## --grammar-check=<root> checks another folder (e.g. res://tests/grammar_fixtures/broken).


func run(main: Node) -> void:
	var root := "res://content"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--grammar-check="):
			root = a.substr(16)
	var bad := KinGrammar.check(root)
	main.get_tree().quit(1 if bad > 0 else 0)
