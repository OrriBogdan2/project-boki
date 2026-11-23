extends Logger
## Counts the script errors the engine logs while it is installed (OS.add_logger): a check turns "rc 0 with
## a thousand SCRIPT ERROR lines in the log" into a failed row.

var count := 0
var first := ""

func _log_error(_fn: String, file: String, line: int, _code: String, rationale: String, _notify: bool,
		error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	count += 1
	if first == "":
		first = "%s:%d %s" % [file, line, rationale]
