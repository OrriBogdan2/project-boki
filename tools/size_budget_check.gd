extends RefCounted
## --size-budget-check: runs tools/size_budget.py --check (export dry run per platform vs
## tests/size_budget.json; docs/SIZE_BUDGET.md) so the suite covers the build size too.

func run(m: Node) -> void:
	var out := []
	var script := ProjectSettings.globalize_path("res://tools/size_budget.py")
	var rc := OS.execute("python3", ["-I", script, "--check"], out, true)
	print("SIZEBUDGET %s" % "\nSIZEBUDGET ".join(String(out[0]).strip_edges().split("\n")))
	m.get_tree().quit(1 if rc != 0 else 0)
