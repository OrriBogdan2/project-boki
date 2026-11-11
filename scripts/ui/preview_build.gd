class_name PreviewBuild
extends RefCounted
## A Mask's model for a preview (the Masks screen's turntable, the ability clips, the Mask moments). Building one
## costs tens of ms (the first of a Warden over 100: its gear meshes are made cold), so a screen full of previews
## would stall on one frame. The .glb is read on a loader thread first (WardenGlb.fetch) and the model is built on
## a worker thread: a caller asks with turn() each frame until it says yes, then model() hands over the finished
## one. Where nothing can run off the main thread (headless: the dummy renderer isn't thread-safe) the same calls
## build on the main thread, at most one a frame.

static var last_frame := -1    # the last frame the main thread spent on a preview model (or a Warden's neutral rig)

static var _lock := Mutex.new()
static var _queue: Array = []        # Warden ids waiting for the worker, in the order asked
static var _pending := {}            # id -> true while a model of it is queued or being built
static var _built := {}              # id -> finished models nobody has taken yet
static var _running := false         # the worker is alive and looking at the queue
static var _task := -1               # the worker's id (BackgroundWork.join)

## Whether the caller may take `hunter_id`'s preview model now. Off the main thread this asks for one when none is
## on its way; on it, once the .glb is read, at most once a frame (a Warden whose neutral rig isn't measured yet
## spends this frame's turn on that).
static func turn(hunter_id: String) -> bool:
	if not BackgroundWork.can_read_ahead():
		return _prepared(hunter_id)
	_lock.lock()
	var ready: bool = not (_built.get(hunter_id, []) as Array).is_empty()
	var on_its_way: bool = _pending.has(hunter_id)
	_lock.unlock()
	if not ready and not on_its_way and _prepared(hunter_id):
		_ask(hunter_id)
	return ready

## The Mask's model as a preview shows it: the Hunter in the player's Mask look, without its team ring. The one
## turn() found finished, else built here and now.
static func model(hunter_id: String) -> Node3D:
	_lock.lock()
	var ready: Array = _built.get(hunter_id, [])
	var done = ready.pop_front() if not ready.is_empty() else null
	_lock.unlock()
	return done if done != null else _hunter(hunter_id)

## The main-thread half of a build: the .glb read, the neutral rig and the .glb's bones checked, one Warden a frame.
static func _prepared(hunter_id: String) -> bool:
	if not WardenGlb.fetched(hunter_id) or Engine.get_process_frames() == last_frame:
		return false
	last_frame = Engine.get_process_frames()
	if not WardenGlb.has_rest(hunter_id):
		_lock.lock()
		var idle := not _running      # (measuring builds with no .glb on: a worker build would see that too)
		_lock.unlock()
		if idle:
			WardenGlb.neutral_rest(hunter_id)
		return false
	return true

static func _hunter(hunter_id: String) -> Node3D:
	var m := Models.hunter(Arch.weight(hunter_id), Data.TEAM_COLORS[0], Arch.signature(hunter_id), "",
			Unmasked.mask_look(), hunter_id)
	var ring := m.get_node_or_null("TeamRing")
	if ring:
		(ring as Node3D).visible = false
	return m

static func _ask(hunter_id: String) -> void:
	WardenGlb.will_dress(hunter_id)       # (reads the .glb's bones now: the worker only reads what is known)
	_lock.lock()
	_queue.append(hunter_id)
	_pending[hunter_id] = true
	var start := not _running
	_running = true
	_lock.unlock()
	if start:
		if _task >= 0:
			BackgroundWork.join(_task)
		_task = BackgroundWork.add_task(func(): _work())

## The worker: builds what is asked, one model at a time, then ends.
static func _work() -> void:
	while true:
		_lock.lock()
		if _queue.is_empty():
			_running = false
			_lock.unlock()
			return
		var hunter_id: String = _queue.pop_front()
		_lock.unlock()
		var m := _hunter(hunter_id)
		_lock.lock()
		if not _built.has(hunter_id):
			_built[hunter_id] = []
		(_built[hunter_id] as Array).append(m)
		_pending.erase(hunter_id)
		_lock.unlock()
