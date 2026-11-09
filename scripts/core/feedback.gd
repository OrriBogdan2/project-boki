class_name Feedback
extends RefCounted
## The "Rate this build" card's data (item 189): minutes played per game version, which versions were
## answered or skipped, and the answers not yet delivered. Kept in user://feedback.json, apart from the
## save, so it needs no save migration. Answers go to POST /feedback on the matchmaker; if that fails
## they stay queued and flush() sends them on the next launch. Quick notes (F8, QuickNote) wait in the same
## queue as {"kind": "note"} entries and go out with it: when the rate card sends, on quit, or next launch.

const FILE := "user://feedback.json"
const URL := "http://boki-us-1:8080/feedback"
const MIN_MINUTES := 10.0       # play on a version before the card may show
const KEYS := ["combat", "boki", "onboarding", "look"]
const NOTE_MAX := 200           # characters; the server allows 300
const SHOT_MAX := 5000          # characters of base64 screenshot a note may carry; the server allows 6000
const QUIT_WAIT := 2.0          # seconds a quit or leave waits for queued notes to send

## Where the file lives and how a payload is delivered; checks swap both. poster(body, done: Callable(ok: bool)).
static var path := FILE
static var poster := Callable()
static var _counted_ms := 0     # engine uptime already added to the minutes

static func _load() -> Dictionary:
	var out := {"minutes": {}, "done": [], "queue": []}
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			out.merge(parsed, true)
	return out

static func _save(st: Dictionary) -> void:
	if Save.no_write and path == FILE:
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(st))

## Adds the time since the last call to this version's minutes and returns the total.
static func minutes() -> float:
	var st := _load()
	var now := Time.get_ticks_msec()
	st["minutes"][Net.VERSION] = float(st["minutes"].get(Net.VERSION, 0.0)) + (now - _counted_ms) / 60000.0
	_counted_ms = now
	_save(st)
	return st["minutes"][Net.VERSION]

static func due() -> bool:
	return not _load()["done"].has(Net.VERSION) and minutes() >= MIN_MINUTES

## Marks this version answered (or skipped) so the card never shows again for it.
static func finish() -> void:
	var st := _load()
	if not st["done"].has(Net.VERSION):
		st["done"].append(Net.VERSION)
	_save(st)

## Queues an answer, then tries to deliver the queue.
static func submit(host: Node, scores: Dictionary, note: String) -> void:
	var st := _load()
	var who := "%s (%s)" % [Save.d.get("name", "Hunter"), Save.d.get("profile", {}).get("id", "?")]
	st["queue"].append({"version": Net.VERSION, "player": who.left(64), "scores": scores,
			"note": note.left(NOTE_MAX), "minutes_played": snappedf(minutes(), 0.1)})
	_save(st)
	flush(host)

## Queues a quick note with its context ({hunter, boki, t, pos, preset, fps}) and a small base64 screenshot
## ("" for none). It is only saved here: the rate card, a quit or the next launch send it.
static func add_note(text: String, ctx: Dictionary, shot: String) -> void:
	var st := _load()
	var who := "%s (%s)" % [Save.d.get("name", "Hunter"), Save.d.get("profile", {}).get("id", "?")]
	st["queue"].append({"kind": "note", "version": Net.VERSION, "player": who.left(64), "note": text.left(NOTE_MAX),
			"ctx": ctx, "shot": shot if shot.length() <= SHOT_MAX else ""})
	_save(st)

static func queued() -> int:
	return _load()["queue"].size()

## Sends the oldest queued entry; on success drops it and goes on to the next. `after` runs once the queue
## is empty or a send failed.
static func flush(host: Node, after := Callable()) -> void:
	var st := _load()
	if st["queue"].is_empty():
		if after.is_valid(): after.call()
		return
	var done := func(ok: bool) -> void:
		if not ok:
			if after.is_valid(): after.call()
			return
		var now := _load()
		now["queue"].pop_front()
		_save(now)
		flush(host, after)
	if poster.is_valid():
		poster.call(st["queue"][0], done)
		return
	var req := HTTPRequest.new()
	req.timeout = 8.0
	host.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		req.queue_free()
		# 400 = the server will never take this one; drop it rather than retry forever
		done.call(result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 400)))
	var body := JSON.stringify(st["queue"][0])
	var err := req.request(URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		req.queue_free()
		done.call(false)
