extends RefCounted
## --watchdog-check: a check run that dies on a script error ends by itself (tools/check_watchdog.gd).
## Starts this game a second time as --watchdog-check=die: that run raises a script error in its check
## coroutine, so it never reaches its quit(). The watchdog must end it with exit code 1 and say so, long
## before the child's own cap. Also which flags count as a check run, and that a check's second game
## (CheckChild) is left alone. And the gate's skip list (CheckRegistry.COVERED) names registered flags of one script.
## And CheckClock, the stopwatch for time budgets, stays behind the wall clock.
## Lines: WATCHDOG ok|FAIL <what>.

const Watchdog := preload("res://tools/check_watchdog.gd")
const DIE_FLAG := "--watchdog-check=die"
const CHILD_CAP_S := 600.0   # s: the child quits with code 3 by itself then, should the watchdog not act

var bad := 0

func ok(cond: bool, what: String, info := "") -> void:
	print("WATCHDOG %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var tree := main.get_tree()
	if DIE_FLAG in OS.get_cmdline_user_args():
		tree.create_timer(CHILD_CAP_S).timeout.connect(tree.quit.bind(3))
		var none := {}
		print(none["a script error on purpose"])
		return
	for flag in ["--check", "--simtest", "--feed-check", "--online-displace-check=100", DIE_FLAG]:
		ok(Watchdog.is_check_flag(flag), "%s starts a check run" % flag)
	for flag in ["--shot=a.png", "--record", "--checkpoint", "--dn-port=7930", "--nofog"]:
		ok(not Watchdog.is_check_flag(flag), "%s does not" % flag)
	ok(Watchdog.watches(["--nofog", "--feed-check"]), "a check run is watched")
	ok(not Watchdog.watches(["--displace-net-check=guest", Watchdog.CHILD_FLAG]), "a check's second game is not")
	for flag: String in CheckRegistry.COVERED:
		var script: String = CheckRegistry.CHECKS.get(flag, [""])[0]
		var covers: Array = CheckRegistry.COVERED[flag]
		ok(script != "" and not covers.is_empty() and covers.all(func(c: String) -> bool:
			return not CheckRegistry.COVERED.has(c) and CheckRegistry.CHECKS.get(c, [""])[0] == script),
			"%s is covered by run flags of its own script" % flag, str(covers))
	var own := CheckClock.own_usec()
	ok(own > 0 and own <= Time.get_ticks_usec(), "the check clock never runs ahead of the wall clock")
	var out: Array = []
	var t0 := Time.get_ticks_msec()
	var rc := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--", DIE_FLAG]), out, true)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var text := "\n".join(out)
	ok(text.contains("SCRIPT " + "ERROR"), "the child run dies on its script error")
	ok(rc == 1, "the watchdog ends it with exit code 1", "code %d after %.0f s" % [rc, secs])
	ok(text.contains("WATCHDOG quit"), "and says so in the log")
	ok(secs < CHILD_CAP_S, "before the child's own %d s cap" % CHILD_CAP_S, "%.0f s" % secs)
	print("WATCHDOG DONE, failures: %d" % bad)
	tree.quit(1 if bad > 0 else 0)
