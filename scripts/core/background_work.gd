class_name BackgroundWork
extends RefCounted
## Loader-thread reads and worker-pool tasks the game starts and collects later (portrait cuts, Warden .glb reads).
## Whatever is still out when the game quits is finished first: a quit with threads mid-read crashes the engine.

static var _reads := {}       # path -> true while a threaded read is requested and not yet taken
static var _tasks := {}       # worker task id -> true while it is added and not yet joined
static var _hooked := false

## Starts reading `path` on a loader thread (take() collects it).
static func request(path: String) -> void:
	_hook_quit()
	ResourceLoader.load_threaded_request(path)
	_reads[path] = true

## The resource a request() read; waits if it is still reading.
static func take(path: String) -> Resource:
	_reads.erase(path)
	return ResourceLoader.load_threaded_get(path)

## Runs `work` on a worker thread (join() collects it).
static func add_task(work: Callable) -> int:
	_hook_quit()
	var id := WorkerThreadPool.add_task(work)
	_tasks[id] = true
	return id

## Waits for a task from add_task() and releases it.
static func join(id: int) -> void:
	_tasks.erase(id)
	WorkerThreadPool.wait_for_task_completion(id)

## Finishes everything still out (what a quit runs).
static func drain() -> void:
	for id in _tasks.keys():
		join(int(id))
	for path in _reads.keys():
		take(String(path))

static func _hook_quit() -> void:
	if not _hooked:
		_hooked = true
		(Engine.get_main_loop() as SceneTree).root.tree_exiting.connect(drain)
