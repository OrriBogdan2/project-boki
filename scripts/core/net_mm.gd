class_name NetMatchmaker
extends Node
## HTTP client for the matchmaker (server/matchmaker): one JSON request per call. The party member secret
## rides in the X-Boki-Member header, never in the path, because the server logs paths.

const DEFAULT_PORT := 8080
const TIMEOUT_S := 8.0           # seconds before a request counts as a network failure
const MEMBER_HEADER := "X-Boki-Member"
const METHODS := {"GET": HTTPClient.METHOD_GET, "POST": HTTPClient.METHOD_POST, "DELETE": HTTPClient.METHOD_DELETE}

var addr := ""                   # "host:port" of the matchmaker
var member := ""                 # the secret from creating or joining a party
## Replaces the network when valid: (method, path, member, body) -> {"status": int, ...answer}. The check's fake server.
var transport := Callable()

## The matchmaker address: `--matchmaker=host:port` when given, else the host of `--server=` on the default port.
static func pick_addr(matchmaker_arg: String, server_addr: String) -> String:
	if matchmaker_arg != "":
		return matchmaker_arg
	if server_addr == "":
		return ""
	return "%s:%d" % [server_addr.rsplit(":", true, 1)[0], DEFAULT_PORT]

## One request. The answer is the JSON body plus "status"; a failed connection answers status 0, error "network".
func send(method: String, path: String, body := {}) -> Dictionary:
	if transport.is_valid():
		return await transport.call(method, path, member, body)
	if addr == "":
		return _failed()
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_S
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if member != "":
		headers.append("%s: %s" % [MEMBER_HEADER, member])
	var payload := JSON.stringify(body) if method == "POST" else ""
	if http.request("http://%s%s" % [addr, path], headers, METHODS[method], payload) != OK:
		http.queue_free()
		return _failed()
	var done: Array = await http.request_completed
	http.queue_free()
	if done[0] != HTTPRequest.RESULT_SUCCESS:
		return _failed()
	var parsed = JSON.parse_string((done[3] as PackedByteArray).get_string_from_utf8())
	var out: Dictionary = parsed if parsed is Dictionary else {}
	out["status"] = done[1]
	return out

func _failed() -> Dictionary:
	return {"status": 0, "error": "network"}
