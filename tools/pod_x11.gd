extends RefCounted
## --pod-x11: for a GPU box whose X server is gone (rp1 pods 11-17: "X11 Display is not available").
## Start this launch headless (override.cfg: display_server/driver.linuxbsd="headless" in the job tree only),
## and it starts its own Xvfb, then runs the rest of the command line as a child on that display with
## x11 + vulkan (the NVIDIA driver presents to Xvfb), prints the child's output and quits with its code.
## Prints a POD-X11 probe first (Xvfb path, X sockets, GPU) so a failure says why.

func run(main: Node) -> void:
	var user := Array(OS.get_cmdline_user_args()).filter(func(a): return a != "--pod-x11")
	var probe: Array = []
	OS.execute("sh", ["-c", "command -v Xvfb Xorg; ls /tmp/.X11-unix 2>&1; nvidia-smi -L 2>&1 | head -2; echo DISPLAY=$DISPLAY"], probe, true)
	print("POD-X11 probe:\n" + "\n".join(probe))
	var xvfb := -1
	var disp := ":97"
	if FileAccess.file_exists("/tmp/.X11-unix/X0"):
		disp = ":0"   # a live server that only lost DISPLAY
	else:
		xvfb = OS.create_process("Xvfb", [disp, "-screen", "0", "1920x1080x24", "-nolisten", "tcp"])
		OS.delay_msec(2500)
		print("POD-X11 Xvfb pid %d on %s" % [xvfb, disp])
	OS.set_environment("DISPLAY", disp)
	var args: Array = ["--display-driver", "x11", "--rendering-driver", "vulkan",
			"--path", ProjectSettings.globalize_path("res://"), "--"] + user
	print("POD-X11 args: %s" % " ".join(args))
	var out: Array = []
	var rc := OS.execute(OS.get_executable_path(), PackedStringArray(args), out, true)
	print("\n".join(out))
	print("POD-X11 child rc=%d" % rc)
	if xvfb > 0:
		OS.kill(xvfb)
	main.get_tree().quit(rc)
