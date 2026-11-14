extends Node
## The first autoload, tooling only: ends a check run that died on a script error.
## A script error stops the coroutine a check runs in, so its quit() is never reached and the game sat idle
## until the gate's 1200 s timeout (docs/GATE_SPEED_1111.md). In a check run (--check, --simtest, any
## --<name>-check) this quits with code 1 once a script error is in the log and both QUIET_S and QUIET_FRAMES
## pass without another line. Such a run was red already (its log has the error); now it is red in a minute.
## A second game a check starts (CheckChild) is not watched: it is quiet by design and ends with its host.
## It is the first autoload so that the errors of every later autoload and of the main scene's scripts reach it.

const QUIET_S := 60.0        # s without a line after a script error; a check that still runs keeps printing
const QUIET_FRAMES := 600    # and frames: on a busy box the seconds alone pass while the check still works
const CHILD_FLAG := "--check-child"   # the user arg of a check's second game

## Counts script errors and stamps every line. The engine may call it from any thread.
class Tap extends Logger:
	var lock := Mutex.new()
	var errors := 0
	var last_ms := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		lock.lock()
		if error_type == ERROR_TYPE_SCRIPT:
			errors += 1
		last_ms = Time.get_ticks_msec()
		lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		lock.lock()
		last_ms = Time.get_ticks_msec()
		lock.unlock()

var tap: Tap = null
var seen_ms := 0
var quiet_frames := 0

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if watches(OS.get_cmdline_user_args()):
		tap = Tap.new()
		OS.add_logger(tap)

func _ready() -> void:
	set_process(tap != null)

func _exit_tree() -> void:
	if tap != null:
		OS.remove_logger(tap)

func _process(_delta: float) -> void:
	tap.lock.lock()
	var errors := tap.errors
	var last_ms := tap.last_ms
	tap.lock.unlock()
	quiet_frames = quiet_frames + 1 if last_ms == seen_ms else 0
	seen_ms = last_ms
	if errors > 0 and quiet_frames >= QUIET_FRAMES and Time.get_ticks_msec() - last_ms > QUIET_S * 1000.0:
		print("WATCHDOG quit: a script error, then %d s and %d frames without a line (the check's coroutine is dead)"
				% [QUIET_S, quiet_frames])
		get_tree().quit(1)

## True when the user args are a check run to watch: a check flag, and not a check's second game.
static func watches(args: Array) -> bool:
	return args.any(is_check_flag) and not CHILD_FLAG in args

## True for the flags that start a check run: --check, --simtest and every --<name>-check[=...].
static func is_check_flag(arg: String) -> bool:
	return arg == "--check" or arg == "--simtest" or arg.get_slice("=", 0).ends_with("-check")
