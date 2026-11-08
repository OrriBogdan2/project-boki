extends RefCounted
## --warm-twice: runs the rest of the command line twice in a row as child processes sharing this user dir,
## so the second run is a player's second launch (WarmStamp and the engine's shader and pipeline caches
## written by the first). Prints the first run's LOAD and HITCH lines, then the second run's whole output,
## and quits with the second run's code. A jobq worker starts from an empty user dir, so this is how a
## benchmark sees a launch after the first.

func run(main: Node) -> void:
	var user := Array(OS.get_cmdline_user_args()).filter(func(a): return a != "--warm-twice")
	# the engine options this run started with (the engine keeps some out of get_cmdline_args)
	var args: Array = Array(OS.get_cmdline_args())
	if DisplayServer.get_name() == "headless" and not "--headless" in args:
		args.append("--headless")
	if not "--rendering-driver" in args:
		args += ["--rendering-driver", RenderingServer.get_current_rendering_driver_name()]
	if not "--path" in args:
		args += ["--path", ProjectSettings.globalize_path("res://")]
	args += ["--"] + user
	print("WARM-TWICE args: %s" % " ".join(args))
	var rc := 0
	for pass_i in 2:
		var out: Array = []
		rc = OS.execute(OS.get_executable_path(), PackedStringArray(args), out, true)
		var text := "\n".join(out)
		print("WARM-TWICE launch %d rc=%d" % [pass_i + 1, rc])
		if pass_i == 0:
			for line in text.split("\n"):
				if line.begins_with("LOAD") or line.begins_with("HITCH") or line.contains("warm-up ms"):
					print("  first: " + line)
		else:
			print(text)
	main.get_tree().quit(rc)
