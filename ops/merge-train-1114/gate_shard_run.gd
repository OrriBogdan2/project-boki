extends RefCounted
## --gate-shard-run=--a-check,--b-check [--par=4] [--cap=300]: one jobq job runs a shard of the gate.
## Each flag runs as its own godot process (temp XDG_DATA_HOME, `timeout` cap), `par` at a time, and prints
## "GS <flag> <rc> <script_errors> <secs>". gate-shard injects this file and its registry line into the trees it
## gates (the jobq app can only start the game, so a shard has to start inside it); it is never committed to a tree.
## On a non-Linux worker every flag prints "lost" (gate-shard re-runs it).

var _flags: PackedStringArray
var _next := 0
var _mutex := Mutex.new()
var _cap := "300"
var _wrapper := ""


func run(main: Node) -> void:
	var par := 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gate-shard-run="):
			_flags = a.trim_prefix("--gate-shard-run=").split(",", false)
		elif a.begins_with("--par="):
			par = int(a.trim_prefix("--par="))
		elif a.begins_with("--cap="):
			_cap = a.trim_prefix("--cap=")
	if OS.get_name() != "Linux":  # mac/Windows workers take --needs any jobs too, but have no `timeout` or XDG isolation
		for f in _flags:
			print("GS %s lost 0 0" % f)
		main.get_tree().quit(0)
		return
	# a wrapper file, since OS.execute re-parses an `sh -c` string ("redirection unexpected")
	_wrapper = "/tmp/gs_run_%d.sh" % OS.get_process_id()
	var w := FileAccess.open(_wrapper, FileAccess.WRITE)
	w.store_string('XDG_DATA_HOME="$1" timeout -k 10 "$2" "$3" --headless --path "$4" -- "$5" > "$6" 2>&1\n')
	w.close()
	var threads: Array[Thread] = []
	for i in par:
		var t := Thread.new()
		t.start(_work)
		threads.append(t)
	for t in threads:
		t.wait_to_finish()
	DirAccess.remove_absolute(_wrapper)
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
		var log_path := home + ".log"
		# output goes to a file, not a pipe: a check that leaves a child behind (--online-feel-check's udp_delay.py) kept the
		# pipe open, so a piped execute never returned and the whole shard hung until its job cap
		var args := [_wrapper, home, _cap, OS.get_executable_path(), tree, _flags[idx], log_path]
		var t0 := Time.get_ticks_msec()
		var rc := OS.execute("sh", args)
		var secs := (Time.get_ticks_msec() - t0) / 1000
		var errs := FileAccess.get_file_as_string(log_path).count("SCRIPT ERROR")
		OS.execute("rm", ["-rf", home, log_path])
		_mutex.lock()  # one line at a time: two threads printing at once once made a "GS" line with no flag
		print("GS %s %d %d %d" % [_flags[idx], rc, errs, secs])
		_mutex.unlock()
