class_name BackgroundWork
extends RefCounted
## Loader-thread reads and worker-pool tasks the game starts and collects later (portrait cuts, Warden .glb reads).
## Whatever is still out when the game quits is finished first: a quit with threads mid-read crashes the engine.

static var _reads := {}       # path -> true while a threaded read is requested and not yet taken
static var _queue: Array[String] = []   # read_ahead() paths not requested yet, in order
static var _tasks := {}       # worker task id -> true while it is added and not yet joined
static var _hooked := false

## Whether a model (.glb) may be read on a loader thread: only on the Compatibility renderer, which queues a loader
## thread's material setup for the render thread. Headless, the dummy texture store is not thread-safe. On a
## RenderingDevice renderer (Vulkan, D3D12, Metal) Godot 4.6 sets a new material's shader right on the loader thread
## (material_create_from_shader), racing the main thread's materials: a heap crash as a match builds, or an endless
## material_set_shader loop at quit (docs/DEBT.md, model read-ahead). Callers that only read ahead then load on
## first use.
static func can_read_ahead() -> bool:
	return DisplayServer.get_name() != "headless" and RenderingServer.get_rendering_device() == null

## Starts reading `path` on a loader thread (take() collects it).
static func request(path: String) -> void:
	_hook_quit()
	ResourceLoader.load_threaded_request(path)
	_reads[path] = true

## Queues `path` to read on a loader thread once the reads queued before it are done: one at a time, a frame
## apart. With a match's ~32 .glb reads out at once, the main thread's build stalled until they were all done and
## the GL driver uploaded their textures and meshes in one frame (M5 GL 592 ms, item 33).
static func read_ahead(path: String) -> void:
	if _reads.has(path) or path in _queue:
		return
	_queue.append(path)
	var tree := Engine.get_main_loop() as SceneTree
	if not tree.process_frame.is_connected(_next_read):
		tree.process_frame.connect(_next_read)
	_next_read()

## Whether `path` is queued or requested and not taken yet.
static func asked(path: String) -> bool:
	return _reads.has(path) or path in _queue

## Whether `path` can be taken without waiting: not queued or still reading.
static func done(path: String) -> bool:
	var reading := ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
	return not reading and not path in _queue

## The resource a request() or read_ahead() read; waits if it is still reading, and reads it now (on the main
## thread) if it is not requested yet.
static func take(path: String) -> Resource:
	_queue.erase(path)
	if not _reads.has(path):
		return load(path)
	_reads.erase(path)
	return ResourceLoader.load_threaded_get(path)

## Each frame: starts the next queued read once no read_ahead() read is still going.
static func _next_read() -> void:
	for p in _reads:
		if ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
	if _queue.is_empty():
		(Engine.get_main_loop() as SceneTree).process_frame.disconnect(_next_read)
		return
	request(_queue.pop_front())

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
	_queue.clear()
	for id in _tasks.keys():
		join(int(id))
	for path in _reads.keys():
		take(String(path))

static func _hook_quit() -> void:
	if not _hooked:
		_hooked = true
		(Engine.get_main_loop() as SceneTree).root.tree_exiting.connect(drain)
