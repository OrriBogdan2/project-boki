class_name SocialHttp
extends Node
## Social's carrier on desktop: the /social routes of the matchmaker service (server/matchmaker/mm/social.py).
## It answers Social's store calls (method, args, cb) with the same text the old page store gave, so Social
## parses one shape whatever carries it. The player token lives in user://social.cfg, apart from the save, and
## rides in a header, never the path (the server logs paths).

const DEFAULT_URL := ""  # the deployed HTTPS base (e.g. https://<host>); empty until the service is up
const TOKEN_FILE := "user://social.cfg"
const PLAYER_HEADER := "X-Boki-Player"
const TIMEOUT_S := 8.0  # seconds before a call counts as the store not answering

var base := ""  # "https://host" or "http://host:port", no trailing slash
var _token := ""


## Where the store is: `--social=<url>`, else BOKI_SOCIAL, else DEFAULT_URL in an exported build ("" = none).
static func pick_url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--social="):
			return a.substr(9).trim_suffix("/")
	var env := OS.get_environment("BOKI_SOCIAL")
	if env != "":
		return env.trim_suffix("/")
	return DEFAULT_URL if OS.has_feature("template") else ""


## One store call; cb gets the reply text: a JSON doc or "null", "ok"/"err:<why>", an id or "", rows, a claim or "0".
func ask(method: String, args: Array, cb: Callable) -> void:
	match method:
		"storeInit":
			_hello(cb)
		"dbGet":
			_db({"op": "get", "path": args[0]}, cb, func(r): return JSON.stringify(r))
		"dbSet":
			_db({"op": "set", "path": args[0], "data": JSON.parse_string(args[1])}, cb, func(r): return str(r))
		"dbDel":
			_db({"op": "del", "path": args[0]}, cb, func(r): return str(r))
		"dbAdd":
			_db({"op": "add", "path": args[0], "data": JSON.parse_string(args[1])}, cb, func(r): return str(r))
		"dbQuery":
			_db(
				{"op": "query", "path": args[0], "q": JSON.parse_string(args[1])}, cb, func(r): return JSON.stringify(r)
			)
		"dbClaim":
			_db({"op": "claim", "path": args[0]}, cb, func(r): return "0" if r == null else JSON.stringify(r))


## Lists me in the town room with presence (null leaves it); cb gets the others as [{id, p}] (unchecked).
func hub(room: String, presence, cb: Callable) -> void:
	_post(
		"/social/hub",
		{"room": room, "p": presence},
		func(d: Dictionary) -> void:
			if cb.is_valid():  # the town may be gone by the answer
				cb.call(Social.arr_of(d.get("r")))
	)


func _hello(cb: Callable) -> void:
	var cfg := ConfigFile.new()
	cfg.load(TOKEN_FILE)
	_token = String(cfg.get_value(base, "token", ""))
	_post(
		"/social/hello",
		{},
		func(d: Dictionary) -> void:
			var fresh := Social.txt_of(d.get("token"), "", 128)
			if fresh != "":
				_token = fresh
				cfg.set_value(base, "token", fresh)
				cfg.save(TOKEN_FILE)
			var me := Social.txt_of(d.get("me"))
			cb.call(JSON.stringify({"mode": "db", "me": me, "owner": d.get("owner") == true}) if me != "" else "")
	)


## A store op; cb gets text(answer) when the server answered, "err:<why>" or "" (by op) when it did not.
func _db(body: Dictionary, cb: Callable, text: Callable) -> void:
	var failed := "err:x" if body["op"] in ["set", "del"] else ""
	_post("/social/db", body, func(d: Dictionary): cb.call(text.call(d["r"]) if d.has("r") else failed))


## POSTs body as JSON; done gets the answer (an error answer, or {} when the call failed).
func _post(path: String, body: Dictionary, done: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_S
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "%s: %s" % [PLAYER_HEADER, _token]])
	http.request_completed.connect(
		func(result: int, _code: int, _headers: PackedStringArray, raw: PackedByteArray) -> void:
			http.queue_free()
			var parsed = JSON.parse_string(raw.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS else null
			done.call(Social.dict_of(parsed))
	)
	if http.request(base + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body)) != OK:
		http.queue_free()
		done.call_deferred({})
