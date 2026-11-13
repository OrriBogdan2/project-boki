class_name CheckClock
extends RefCounted
## A check's stopwatch for time budgets and wait caps: the wall clock minus the time this thread sat ready
## to run without a CPU (Linux: /proc/self/schedstat). On a free box that is the wall clock. On a loaded box
## (the gate runs six checks beside other work) "loads in under 10 s" or "wait 8 s for the model" no longer
## fails for the box's sake. Sleeps, timers and disk waits still count. Other systems: the plain wall clock.

## Microseconds since engine start, less the time the box kept the main thread of process `pid` (this game
## when 0) off a CPU. With a check's second game as `pid`: a cap on how long that game may take to answer.
static func own_usec(pid := 0) -> int:
	var f := FileAccess.open("/proc/%s/schedstat" % ("self" if pid == 0 else str(pid)), FileAccess.READ)
	var waited_ns := 0 if f == null else int(f.get_line().get_slice(" ", 1))
	return Time.get_ticks_usec() - int(waited_ns / 1000.0)

## The same in milliseconds.
static func own_msec(pid := 0) -> int:
	return int(own_usec(pid) / 1000.0)
