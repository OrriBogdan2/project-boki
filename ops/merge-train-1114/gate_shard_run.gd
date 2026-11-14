extends RefCounted
## --gate-shard-run=--a-check,--b-check [--par=4] [--cap=300]: one jobq job runs a shard of the gate.
## Each flag runs as its own godot process (temp XDG_DATA_HOME, `timeout` cap), `par` at a time, and prints
## "GS <flag> <rc> <script_errors> <secs>". gate-shard injects this file and its registry line into the trees it
## gates (the jobq app can only start the game, so a shard has to start inside it); it is never committed to a tree.

var _flags: PackedStringArray
var _next := 0
var _mutex := Mutex.new()
var _cap := "300"


func run(main: Node) -> void:
	var par := 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gate-shard-run="):
			_flags = a.trim_prefix("--gate-shard-run=").split(",", false)
		elif a.begins_with("--par="):
			par = int(a.trim_prefix("--par="))
		elif a.begins_with("--cap="):
			_cap = a.trim_prefix("--cap=")
	var threads: Array[Thread] = []
	for i in par:
		var t := Thread.new()
		t.start(_work)
		threads.append(t)
	for t in threads:
		t.wait_to_finish()
	main.get_tree().quit(0)


func _work() -> void:
	var tree := ProjectSettings.globalize_path("res://").rstrip("/")
	while true:
		_mutex.lock()
		var idx := _next
		_next += 1
		_mutex.unlock()
		if idx >= _flags.size():
			return
		var home := "/tmp/gs_%d_%d" % [OS.get_process_id(), idx]
		var args := ["XDG_DATA_HOME=" + home, "timeout", _cap, OS.get_executable_path()]
		args.append_array(["--headless", "--path", tree, "--", _flags[idx]])
		var out: Array = []
		var t0 := Time.get_ticks_msec()
		var rc := OS.execute("env", args, out, true)
		OS.execute("rm", ["-rf", home])
		var secs := (Time.get_ticks_msec() - t0) / 1000
		print("GS %s %d %d %d" % [_flags[idx], rc, "".join(out).count("SCRIPT ERROR"), secs])
