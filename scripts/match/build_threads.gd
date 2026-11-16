class_name BuildThreads
extends RefCounted
## A step of the match build spread over the worker thread pool: start() runs `job` for each of `n` indices
## and wait() collects their returns, by index. Under the loading screen a frame draws between checks, so
## the spinner keeps turning; a one-go build (no screen) blocks until the pool is done. Jobs only read the
## world (its grids and the layout) and build into data of their own, which is the caller's again once
## wait() returns.

var results: Array = []
var _world: World
var _gid := -1
var _lock := Mutex.new()

static func start(world: World, job: Callable, n: int) -> BuildThreads:
	var bt := BuildThreads.new()
	bt._world = world
	bt.results.resize(n)
	if n > 0:
		bt._gid = WorkerThreadPool.add_group_task(bt._run.bind(job), n, -1, true, "match build")
	return bt

func _run(i: int, job: Callable) -> void:
	var r: Variant = job.call(i)
	_lock.lock()
	results[i] = r
	_lock.unlock()

## Every job's return, by index, once they are all done.
func wait() -> Array:
	if _gid < 0:
		return results
	if _world.stage_cb.is_valid() and _world.is_inside_tree():
		while not WorkerThreadPool.is_group_task_completed(_gid):
			await _world.get_tree().process_frame
			PerfLog.frame_drawn()
	WorkerThreadPool.wait_for_group_task_completion(_gid)
	return results
