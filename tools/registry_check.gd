extends RefCounted
## --registry-check: the check registry holds together (tools/checks/*.gd, AGENTS.md section 2).
## No flag is in two files, every entry is [script, meta name, arg] and its script exists, and every area file on
## disk is in CheckRegistry._areas() (a new area file must be listed there).

var fails := 0


func run(main: Node) -> void:
	var checks := CheckRegistry.all()
	ok(CheckRegistry._dupes.is_empty(), "no flag is registered twice", str(CheckRegistry._dupes))
	var listed: Array = []
	for area: GDScript in CheckRegistry._areas():
		listed.append(area.resource_path.get_file())
	for f in DirAccess.get_files_at("res://tools/checks"):
		if f.ends_with(".gd"):
			ok(f in listed, "tools/checks/%s is listed in CheckRegistry._areas()" % f)
	for flag: String in checks:
		var e: Array = checks[flag]
		var good := e.size() == 3 and e[0] is String and e[1] is String
		if good and not CheckRegistry.CHECKS.has(flag):  # (two old entries name scripts that are not in the repo)
			good = ResourceLoader.exists(e[0])
		ok(good, "%s: [script, meta, arg] (new entries: an existing script)" % flag, str(e))
	ok(
		(
			CheckRegistry.get_entry("--registry-check").size() == 3
			and CheckRegistry.get_entry("--no-such-flag").is_empty()
		),
		"get_entry finds a registered flag and returns [] for an unknown one"
	)
	print("REGISTRY: %d checks, %d failures" % [checks.size(), fails])
	main.get_tree().quit(1 if fails > 0 else 0)


func ok(cond: bool, what: String, extra := "") -> void:
	if not cond:
		fails += 1
		printerr("REGISTRY FAIL: %s %s" % [what, extra])
